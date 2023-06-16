public with sharing class UploadFileFromContentDocument {
    private static final String HTTP_POST_METHOD = 'POST';
    private static final String HEADER_CONTENT_TYPE = 'Content-Type';
    private static final String HEADER_AUTHORIZATION = 'Authorization';
    private static final String HEADER_APPLICATION_ENCODED = 'application/x-www-form-urlencoded';
    private static final String HEADER_APPLICATION_JSON = 'application/json';
    private static final String TOKEN_URL_STRING = 'https://api.box.com/oauth2/token';
    private static final String UPLOAD_FILE_URL = 'https://upload.box.com/api/2.0/files/content?parent_id={0}';
    private static final String BOUNDARY = 'BoxForSalesforceUp1oadb0und@ry';

    public class BoxRequest {
        @InvocableVariable(label='Salesforce - ContentDocument Id')
        public String contentDocumentId;

        @InvocableVariable(label='Box - Folder Id')
        public String boxFolderId;

        @InvocableVariable(label='Box - File Name Override')
        public String boxFileNameOverride;
        
        @InvocableVariable(label='Box - Client Id')
        public String boxClientId;
        
        @InvocableVariable(label='Box - Client Secret')
        public String boxClientSecret;
        
        @InvocableVariable(label='Box - Subject Type')
        public String boxSubjectType;

        @InvocableVariable(label='Box - Subject Id')
        public String boxSubjectId;
    }


    public class BoxResult {
        @InvocableVariable(label='Box - File Id')
        public String boxFileId;

        @InvocableVariable(label='Box - Parent Folder Id')
        public String boxParentFolderId;

        @InvocableVariable(label='Box - Status')
        public Integer boxStatus;

        @InvocableVariable(label='Box - Code')
        public String boxCode;

        @InvocableVariable(label='Box - RequestId')
        public String boxRequestId;

        @InvocableVariable(label='Box - Message')
        public String boxMessage;

        @InvocableVariable(label='Box - Context')
        public String boxContext;
    }

    @InvocableMethod(label='Upload ContentDocument' category='Box' callout=true)
    public static List<BoxResult> uploadContentDocument(List<BoxRequest> boxRequestList) {
        List<BoxResult> boxResultList = new List<BoxResult>();
        for(BoxRequest boxRequest: boxRequestList) {
            BoxResult boxResult = new BoxResult();

            String folderId = boxRequest.boxFolderId;
            if(String.isEmpty(folderId)) {
                box__FRUP__c frup = [
                    SELECT box__Folder_ID__c, box__Record_ID__c, box__Box_user__c 
                        FROM box__FRUP__c 
                            WHERE box__Record_ID__c = :recordId LIMIT 1];
                folderId = frup.box__Folder_ID__c;
            }
            
            // Get the latest version from the CDL by ContentDocumentId
            ContentDocumentLink cdl = [
                SELECT Id, 
                    ContentDocumentId,
                    ContentDocument.LatestPublishedVersion.VersionData, 
                    ContentDocument.LatestPublishedVersion.Title, 
                    ContentDocument.LatestPublishedVersion.FileExtension 
                        FROM ContentDocumentLink 
                        WHERE ContentDocumentId = :boxRequest.contentDocumentId LIMIT 1];
            System.debug('Found content document link: ' +  cdl);

            ContentVersion contentVersion = cdl.ContentDocument.LatestPublishedVersion;
            System.debug('Found content version: ' + contentVersion);
            String fileName = boxRequest.boxFileNameOverride;
            
            if(String.isEmpty(fileName) ) {
                fileName = String.format('{0}.{1}', new String[] { contentVersion.Title, contentVersion.FileExtension });
            }
            System.debug('Using file name: ' + fileName);

            Blob fileBody = contentVersion.VersionData;
            Blob bodyBlob = buildMultipartFileBody(fileBody, fileName);

            // Create Client Credentials Grant map
            Map<String, String> clientCredentialsGrantMap = new Map<String, String>();
            clientCredentialsGrantMap.put('client_id', boxRequest.boxClientId);
            clientCredentialsGrantMap.put('client_secret', boxRequest.boxClientSecret);
            clientCredentialsGrantMap.put('grant_type', 'client_credentials');
            clientCredentialsGrantMap.put('box_subject_type', boxRequest.boxSubjectType);
            clientCredentialsGrantMap.put('box_subject_id', boxRequest.boxSubjectId);


            // Get parent access token from Client Credentials Grant Auth
            String encodedUrl = urlEncode(clientCredentialsGrantMap);  
            String accessToken = getAccessToken(encodedUrl);

            // Create Box Upload request
            HttpRequest httpRequest = new HttpRequest();
            httpRequest.setMethod(HTTP_POST_METHOD);
            httpRequest.setHeader(HEADER_AUTHORIZATION, 'Bearer ' + accessToken);
            httpRequest.setHeader(HEADER_CONTENT_TYPE, 'multipart/form-data; boundary=' + BOUNDARY);
            String uploadEndpoint = String.format(UPLOAD_FILE_URL, new String[] { boxRequest.boxFolderId });
            httpRequest.setEndpoint(uploadEndpoint);
            httpRequest.setBodyAsBlob(bodyBlob);

            // Send request and parse response
            Http http = new Http();
            HttpResponse httpResponse = http.send(httpRequest);

            System.debug('Found response: ' + httpResponse.getBody());
            FileUploadResponse uploadResponse = FileUploadResponse.parse(httpResponse.getBody());
            
            Integer statusCode = uploadResponse.status;
            System.debug('Found status code: ' + statusCode);

            // If status code is populated, then the upload callout failed. Else, it will return a fileId
            if(statusCode != null) {
                boxResult.boxStatus = statusCode;
                boxResult.boxCode = uploadResponse.code;
                boxResult.boxRequestId = uploadResponse.request_id;
                boxResult.boxMessage = uploadResponse.message;
                boxResult.boxContext = uploadResponse.context_info.message;
            } else {
                boxResult.boxFileId = uploadResponse.entries[0].id;
                boxResult.boxParentFolderId = uploadResponse.entries[0].parent.id;
            }
            boxResultList.add(boxResult);
        }
        return boxResultList;
    }

    private static Blob buildMultipartFileBody(Blob fileBody, String fileName) {
        String header =
            '--' +
            BOUNDARY +
            '\nContent-Disposition: form-data; name="file"; filename="' +
            fileName +
            '";\nContent-Type: application/octet-stream';
        String footer = '--' + BOUNDARY + '--';
        String headerEncoded = EncodingUtil.base64Encode(Blob.valueOf(header + '\r\n\r\n'));
        String footerEncoded;
        
        while (headerEncoded.endsWith('=')) {
            header += ' ';
            headerEncoded = EncodingUtil.base64Encode(Blob.valueOf(header + '\r\n\r\n'));
        }

        String bodyEncoded = EncodingUtil.base64Encode(fileBody);
        String last4Bytes = bodyEncoded.substring(bodyEncoded.length() - 4, bodyEncoded.length());

        if (last4Bytes.endsWith('==')) {
            last4Bytes = last4Bytes.substring(0, 2) + '0K';
            bodyEncoded = bodyEncoded.substring(0, bodyEncoded.length() - 4) + last4Bytes;
            footerEncoded = EncodingUtil.base64Encode(Blob.valueOf(footer));
        } else if (last4Bytes.endsWith('=')) {
            last4Bytes = last4Bytes.substring(0, 3) + 'N';
            bodyEncoded = bodyEncoded.substring(0, bodyEncoded.length() - 4) + last4Bytes;
            footer = '\n' + footer;
            footerEncoded = EncodingUtil.base64Encode(Blob.valueOf(footer));
        } else {
            footer = '\r\n' + footer;
            footerEncoded = EncodingUtil.base64Encode(Blob.valueOf(footer));
        }
        Blob bodyBlob = EncodingUtil.base64Decode(headerEncoded + bodyEncoded + footerEncoded);

        return bodyBlob;
    }

    private static String getAccessToken(String encodedUrl) {
        HttpRequest httpRequest = new HttpRequest();
        httpRequest.setMethod(HTTP_POST_METHOD);
        httpRequest.setEndpoint(TOKEN_URL_STRING);
        httpRequest.setHeader(HEADER_CONTENT_TYPE, HEADER_APPLICATION_ENCODED);
        httpRequest.setBody(encodedUrl);

        Http http = new Http();
        HttpResponse response = http.send(httpRequest);
        String body = response.getBody();

        AuthenticationResponse authResponse = AuthenticationResponse.parse(body);
        
        return authResponse.access_token;
    }

    private static String urlEncode(Map<String, String> urlParameterMap) {
      String result = '';
      for(String key : urlParameterMap.keySet()) {
          result += EncodingUtil.urlEncode(key, 'UTF-8') + '=' + EncodingUtil.urlEncode(urlParameterMap.get(key), 'UTF-8') + '&';
      }
      return result.removeEnd('&');    
    }
}

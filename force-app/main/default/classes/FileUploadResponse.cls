public class FileUploadResponse {
    public String type;
	public String code;
	public ContextInfo context_info;
	public String help_url;
	public String message;
	public String request_id;
	public Integer status;

	public class ContextInfo {
		public String message;
	}

	public class PathCollection {
		public Integer total_count;
		public List<BoxItem> entries;
	}

	public class SharedLink {
		public String url;
		public String download_url;
		public String vanity_url;
		public String vanity_name;
		public String access;
		public String effective_access;
		public String effective_permission;
		public String unshared_at;
		public Boolean is_password_enabled;
		public Permissions permissions;
		public Integer download_count;
		public Integer preview_count;
	}

	public List<BoxItem> entries;
	public Integer total_count;

	public class FileVersion {
		public String id;
		public String type;
		public String sha1;
	}

	public class Permissions {
		public Boolean can_download;
		public Boolean can_preview;
		public Boolean can_edit;
	}

	public class BoxFolder {
		public String id;
		public Integer etag;
		public String type;
		public Integer sequence_id;
		public String name;
	}

	public class BoxUser {
		public String id;
		public String type;
		public String name;
		public String login;
	}

	public class BoxItem {
		public String id;
		public Integer etag;
		public String type;
		public Integer sequence_id;
		public String name;
		public String sha1;
		public FileVersion file_version;
		public String description;
		public Integer size;
		public PathCollection path_collection;
		public String created_at;
		public String modified_at;
		public String trashed_at;
		public String purged_at;
		public String content_created_at;
		public String content_modified_at;
		public BoxUser created_by;
		public BoxUser modified_by;
		public BoxUser owned_by;
		public SharedLink shared_link;
		public BoxFolder parent;
		public String item_status;
	}

	
	public static FileUploadResponse parse(String json) {
		return (FileUploadResponse) System.JSON.deserialize(json, FileUploadResponse.class);
	}
}
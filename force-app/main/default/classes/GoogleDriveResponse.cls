public class GoogleDriveResponse {
    @AuraEnabled
    public Boolean status;        // Indicates success or failure
    @AuraEnabled
    public String message;        // Message related to the response
    @AuraEnabled
    public String jsonResponse;   // The raw JSON response from the Google Drive API
    @AuraEnabled
    public String fileId;         // The ID of the created file in Google Drive

    // Constructor for responses without file ID
    public GoogleDriveResponse(Boolean status, String message) {
        this.status = status;
        this.message = message;
    }

    // Constructor for responses with JSON response and file ID
    public GoogleDriveResponse(Boolean status, String message, String jsonResponse, String fileId) {
        this.status = status;
        this.message = message;
        this.jsonResponse = jsonResponse;
        this.fileId = fileId;
    }

    // Constructor for responses with JSON response without file ID
    public GoogleDriveResponse(Boolean status, String message, String jsonResponse) {
        this.status = status;
        this.message = message;
        this.jsonResponse = jsonResponse;
    }
}
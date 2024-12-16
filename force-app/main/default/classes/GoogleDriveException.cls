public class GoogleDriveException extends Exception {
    @AuraEnabled
    public Boolean success { get; set; }
    @AuraEnabled
    public String message { get; set; }
    
    public GoogleDriveException(Boolean success, String message) {
        this.success = success;
        this.message = message;
    }
}
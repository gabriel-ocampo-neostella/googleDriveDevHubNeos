public class GoogleDriveException extends Exception {
    @AuraEnabled
    public Boolean success { get; set; }
    @AuraEnabled
    public String message { get; set; }
    // Constructor
    public GoogleDriveException(Boolean success, String message) {
        this.success = success;
        this.message = message; 
    }
    
    
    
    public override String getMessage() {
        return this.message;
    }
}
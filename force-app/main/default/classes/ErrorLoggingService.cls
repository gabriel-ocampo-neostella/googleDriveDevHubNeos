public with sharing class ErrorLoggingService {
    public static void logError(String errorType, String severity, String message, String stackTrace, String componentContext) {
        try {
            sfgoogledrive__Error_Log__c log = new sfgoogledrive__Error_Log__c(
                Error_Type__c = errorType,
                Severity__c = severity,
                Timestamp__c = System.now(),
                Message__c = message,
                Stack_Trace__c = stackTrace,
                Component_Context__c = componentContext,
                User__c = UserInfo.getUserId()
            );
            insert log;
        } catch (Exception e) {
            // Fallback logging or send admin notification in case of logging failure
            System.debug('Failed to log error: ' + e.getMessage());
        }
    }

    public static void logApexError(Exception ex, String componentContext) {
        logError('Apex', 'Error', ex.getMessage(), ex.getStackTraceString(), componentContext);
    }

}
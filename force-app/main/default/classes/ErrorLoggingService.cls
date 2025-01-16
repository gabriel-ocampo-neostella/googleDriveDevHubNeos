public with sharing class ErrorLoggingService {
    
     public static void logError(String errorType, String severity, Exception e, String componentContext) {
        system.debug('start method ErrorLoggingService-logError');       
        sfgoogledrive__DriveErrorLogEvent__e errorEvent = new sfgoogledrive__DriveErrorLogEvent__e(
            sfgoogledrive__Error_Type__c = errorType,
            sfgoogledrive__Severity__c = severity,
            Message__c = e.getMessage(),
            sfgoogledrive__Stack_Trace__c = e.getStackTraceString(),
            sfgoogledrive__Component_Context__c = componentContext
        );
        EventBus.publish(errorEvent); 
    }
    
    public static void logError(String errorType, String severity, String message, String componentContext) {
        system.debug('start method ErrorLoggingService-logError');       
        sfgoogledrive__DriveErrorLogEvent__e errorEvent = new sfgoogledrive__DriveErrorLogEvent__e(
            sfgoogledrive__Error_Type__c = errorType,
            sfgoogledrive__Severity__c = severity,
            Message__c = message,
            sfgoogledrive__Component_Context__c = componentContext
        );
        EventBus.publish(errorEvent); 
    }  
}
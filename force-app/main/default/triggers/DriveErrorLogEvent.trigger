trigger DriveErrorLogEvent on sfgoogledrive__DriveErrorLogEvent__e (after insert) {

    
    
    System.debug(' DriveErrorLogEvent - trigger');
    List<sfgoogledrive__Drive_Error_Log__c> logs = new List<sfgoogledrive__Drive_Error_Log__c>();
    
    for (sfgoogledrive__DriveErrorLogEvent__e event : Trigger.New) {
        logs.add(new sfgoogledrive__Drive_Error_Log__c(
            Error_Type__c = event.sfgoogledrive__Error_Type__c,
            Severity__c = event.sfgoogledrive__Severity__c,
            Timestamp__c = System.now(),
            Message__c = event.sfgoogledrive__message__c,
            Stack_Trace__c = event.sfgoogledrive__Stack_Trace__c,
            Component_Context__c = event.sfgoogledrive__Component_Context__c,
            User__c = UserInfo.getUserId()
        ));
    }
    insert logs;
}
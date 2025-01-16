@isTest
private class ErrorLoggingServiceTest {
    @isTest
    static void testLogErrorWithException() {
        // Arrange
        String errorType = 'Apex';
        String severity = 'Critical';
        String componentContext = 'ErrorLoggingServiceTest';
        Exception testException = new DmlException('Test DML Exception');

        Test.startTest();
        ErrorLoggingService.logError(errorType, severity, testException, componentContext);
        Test.stopTest();
    }

    @isTest
    static void testLogErrorWithMessage() {
        // Arrange
        String errorType = 'Apex';
        String severity = 'Warning';
        String message = 'Test warning message';
        String componentContext = 'ErrorLoggingServiceTest';
        Test.startTest();
        ErrorLoggingService.logError(errorType, severity, message, componentContext);
        Test.stopTest();
    }
}
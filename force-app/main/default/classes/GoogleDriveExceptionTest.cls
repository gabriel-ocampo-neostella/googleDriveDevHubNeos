@isTest
public class GoogleDriveExceptionTest {
    
    @IsTest
    private static void testGoogleDriveException() {
        try {
            throw new GoogleDriveException(false, 'Test exception message');
        } catch (GoogleDriveException ex) {
            System.assertEquals('Test exception message', ex.getMessage());
            
        }
    }
    
}
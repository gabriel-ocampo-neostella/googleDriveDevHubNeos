@IsTest
private class GoogleDriveFolderServiceTest {
    
    @testSetup
    static void setupTestData() {
        // Insert Google Drive Integration Settings custom setting
        Google_Drive_Integration_Settings__c integrationSetting = new Google_Drive_Integration_Settings__c(
            Name = 'google services account',
            Root_Folder_ID__c = '1kCFtBNJXD2Pc6AFyGsF1PVf2bF-sweA',
            Root_Folder_Template_ID__c = '1_DVhe9QveqTY9V9Qy8jU_x78e3v_b9S'
        );
        insert integrationSetting;
        
        // Insert an Account record for testing
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;
    }
    
    private class GoogleDriveHttpMock implements HttpCalloutMock {
        private List<String> responses;
        private Integer callIndex;
        
        // Constructor to initialize up to five different responses
        GoogleDriveHttpMock() {
           responses = new List<String>{
            '{"id": "firstFolderId"}',   // Response for the first call
            '{"id": "secondFolderId"}',  // Response for the second call
            '{"id": "thirdFolderId"}',   // Response for the third call
            '{"id": "fourthFolderId"}',  // Response for the fourth call
            '{"id": "fifthFolderId"}',   // Response for the fifth call
            '{"id": "sixthFolderId"}',   // Response for the sixth call
            '{"id": "seventhFolderId"}', // Response for the seventh call
            '{"id": "eighthFolderId"}',  // Response for the eighth call
            '{"id": "ninthFolderId"}',   // Response for the ninth call
            '{"id": "tenthFolderId"}'    // Response for the tenth call
        };
                        callIndex = 0;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            
            // Check if we have a predefined response for the current call
            if (callIndex < responses.size()) {
                res.setStatusCode(200);
                res.setBody(responses[callIndex]);
                callIndex++;
            } else {
                // If there are no more predefined responses, return an error
                res.setStatusCode(500);
                res.setBody('{"error": "No more responses defined in mock"}');
            }
            
            return res;
        }
    }
    
    
    //@IsTest
    static void testGetGoogleDriveFolderId_WithFolderIdOld() {
        // Insert a custom setting with Google_Drive_Folder_ID__c populated
        Google_Drive_Mapping_Folder__c accountMapping = new Google_Drive_Mapping_Folder__c(
            Name = 'Account',
            Object_Name__c = 'Account',
            Parent_Field__c = '',
            Google_Drive_Folder_ID__c = '1a2b3c4d5e6f7g8h9i0j',
            Root_Folder_Name__c = 'AccountRootFolder',
            Folder_Drive_Id_Without_Parent__c = '1q2w3e4r5t6y7u8i9o0p'
        );
        insert accountMapping;
        
        // Mock setup
        String jsonResponse = '{"id": "newFolderId"}';
        GoogleDriveHttpMock mock = new GoogleDriveHttpMock();
        Test.setMock(HttpCalloutMock.class, mock);
        
        // Retrieve the Account record
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        // Call the service
        Test.startTest();
        Map<String, String> folderDetails = GoogleDriveFolderService.getGoogleDriveFolderId(testAccount.Id);
        Test.stopTest();
    }
    
    @IsTest
    static void testGetGoogleDriveFolderId_WithFolderId() {
        // Insert a custom setting with Google_Drive_Folder_ID__c populated
        Drive_Mapping_Folder__c accountMapping = new Drive_Mapping_Folder__c(
            Name = 'Account',
            Object_Name__c = 'Account',
            Parent_Field__c = '',
            Google_Drive_Folder_ID__c = '1a2b3c4d5e6f7g8h9i0j',
            Root_Folder_Name__c = 'AccountRootFolder',
            Folder_Drive_Id_Without_Parent__c = '1q2w3e4r5t6y7u8i9o0p'
        );
        insert accountMapping;
        
        // Mock setup
        String jsonResponse = '{"id": "newFolderId"}';
        GoogleDriveHttpMock mock = new GoogleDriveHttpMock();
        Test.setMock(HttpCalloutMock.class, mock);
        
        // Retrieve the Account record
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        // Call the service
        Test.startTest();
        Map<String, String> folderDetails = GoogleDriveFolderService.getGoogleDriveFolderId(testAccount.Id);
        Test.stopTest();
    }
    
    //@IsTest
    static void testGetGoogleDriveFolderId_WithEmptyFolderIdOld() {
        // Insert a custom setting with an empty Google_Drive_Folder_ID__c
        Google_Drive_Mapping_Folder__c accountMappingEmptyFolderId = new Google_Drive_Mapping_Folder__c(
            Name = 'AccountWithEmptyFolderId',
            Object_Name__c = 'Account',
            Parent_Field__c = '',
            Google_Drive_Folder_ID__c = null, // Setting to empty for this test case
            Root_Folder_Name__c = 'AccountRootFolder',
            Folder_Drive_Id_Without_Parent__c = '1q2w3e4r5t6y7u8i9o0p'
        );
        insert accountMappingEmptyFolderId;
        
        // Mock setup
        
        GoogleDriveHttpMock mock = new GoogleDriveHttpMock();
        Test.setMock(HttpCalloutMock.class, mock);
        
        // Retrieve the Account record
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        // Call the service
        Test.startTest();
        Map<String, String> folderDetails = GoogleDriveFolderService.getGoogleDriveFolderId(testAccount.Id);
        Test.stopTest();
        
    }
    
    @IsTest
    static void testGetGoogleDriveFolderId_WithEmptyFolderId() {
        // Insert a custom setting with an empty Google_Drive_Folder_ID__c
        Drive_Mapping_Folder__c accountMappingEmptyFolderId = new Drive_Mapping_Folder__c(
            Name = 'AccountWithEmptyFolderId',
            Object_Name__c = 'Account',
            Parent_Field__c = '',
            Google_Drive_Folder_ID__c = null, // Setting to empty for this test case
            Root_Folder_Name__c = 'AccountRootFolder',
            Folder_Drive_Id_Without_Parent__c = '1q2w3e4r5t6y7u8i9o0p'
        );
        insert accountMappingEmptyFolderId;
        
        // Mock setup
        
        GoogleDriveHttpMock mock = new GoogleDriveHttpMock();
        Test.setMock(HttpCalloutMock.class, mock);
        
        // Retrieve the Account record
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        // Call the service
        Test.startTest();
        Map<String, String> folderDetails = GoogleDriveFolderService.getGoogleDriveFolderId(testAccount.Id);
        Test.stopTest();
        
    }
    
    //@IsTest
    static void testGetGoogleDriveFolderId_WithParentFieldOld() {
        
        // Insert Google Drive Mapping Folder custom setting for Account
        Google_Drive_Mapping_Folder__c accountMapping = new Google_Drive_Mapping_Folder__c(
            Name = 'Account',
            Object_Name__c = 'Account',
            Parent_Field__c = '',
            Google_Drive_Folder_ID__c = '1a2b3c4d5e6f7g8h9i0j',
            Root_Folder_Name__c = 'AccountRootFolder',
            Folder_Drive_Id_Without_Parent__c = '1q2w3e4r5t6y7u8i9o0p'
        );
        insert accountMapping;
        
        // Insert Google Drive Mapping Folder custom setting for Opportunity
        Google_Drive_Mapping_Folder__c opportunityMapping = new Google_Drive_Mapping_Folder__c(
            Name = 'Opportunity',
            Object_Name__c = 'Opportunity',
            Parent_Field__c = 'AccountId',
            Google_Drive_Folder_ID__c = null, // Parent folder ID is populated dynamically
            Root_Folder_Name__c = 'OpportunityRootFolder',
            Folder_Drive_Id_Without_Parent__c = 'opportunityFolderWithoutParentId',
            Sub_Folder_Name__c ='Opportunities {param_1_drive__c}'
        );
        insert opportunityMapping;
        
        // Insert an Account record for testing
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;
        
        // Insert an Opportunity record related to the Account
        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting', // Required field
            CloseDate = Date.today().addMonths(1), // Required field
            AccountId = testAccount.Id
        );
        insert testOpportunity;
        
        // Set up the mock with unique responses for multiple callouts
        GoogleDriveHttpMock mock = new GoogleDriveHttpMock();
        Test.setMock(HttpCalloutMock.class, mock);
        
        // Call the service using the Opportunity ID
        Test.startTest();
        Map<String, String> folderDetails = GoogleDriveFolderService.getGoogleDriveFolderId(testOpportunity.Id);
        Test.stopTest();
        
    }
    
    @IsTest
    static void testGetGoogleDriveFolderId_WithParentField() {
        
        // Insert Google Drive Mapping Folder custom setting for Account
        Drive_Mapping_Folder__c accountMapping = new Drive_Mapping_Folder__c(
            Name = 'Account',
            Object_Name__c = 'Account',
            Parent_Field__c = '',
            Google_Drive_Folder_ID__c = '1a2b3c4d5e6f7g8h9i0j',
            Root_Folder_Name__c = 'AccountRootFolder',
            Folder_Drive_Id_Without_Parent__c = '1q2w3e4r5t6y7u8i9o0p'
        );
        insert accountMapping;
        
        // Insert Google Drive Mapping Folder custom setting for Opportunity
        Drive_Mapping_Folder__c opportunityMapping = new Drive_Mapping_Folder__c(
            Name = 'Opportunity',
            Object_Name__c = 'Opportunity',
            Parent_Field__c = 'AccountId',
            Google_Drive_Folder_ID__c = null, // Parent folder ID is populated dynamically
            Root_Folder_Name__c = 'OpportunityRootFolder',
            Folder_Drive_Id_Without_Parent__c = 'opportunityFolderWithoutParentId',
            Sub_Folder_Name__c ='Opportunities {param_1_drive__c}'
        );
        insert opportunityMapping;
        
        // Insert an Account record for testing
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;
        
        // Insert an Opportunity record related to the Account
        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting', // Required field
            CloseDate = Date.today().addMonths(1), // Required field
            AccountId = testAccount.Id
        );
        insert testOpportunity;
        
        // Set up the mock with unique responses for multiple callouts
        GoogleDriveHttpMock mock = new GoogleDriveHttpMock();
        Test.setMock(HttpCalloutMock.class, mock);
        
        // Call the service using the Opportunity ID
        Test.startTest();
        Map<String, String> folderDetails = GoogleDriveFolderService.getGoogleDriveFolderId(testOpportunity.Id);
        Test.stopTest();
        
    }
    
    //@IsTest
    static void testCheckIfFolderIsTrashedOld() {
        // Step 1: Insert a custom setting with Google_Drive_Folder_ID__c populated
        Google_Drive_Mapping_Folder__c testMapping = new Google_Drive_Mapping_Folder__c(
            Name = 'Test Account Folder',
            Salesforce_Object_ID__c = '001xx000003DGbZAAW', // Replace with a valid Account ID for the test
            Google_Drive_Folder_ID__c = 'trashedFolderId' // Set up a sample folder ID to check
        );
        insert testMapping;
        
         // Set up the mock with unique responses for multiple callouts
        GoogleDriveHttpMock mock = new GoogleDriveHttpMock();
        Test.setMock(HttpCalloutMock.class, mock);
        
        // Step 3: Call the checkIfFolderIsTrashed method
        Test.startTest();
        GoogleDriveFolderService.checkIfFolderIsTrashed(testMapping.Salesforce_Object_ID__c);
        Test.stopTest();
       
    }
    
     @IsTest
    static void testCheckIfFolderIsTrashed() {
        // Step 1: Insert a custom setting with Google_Drive_Folder_ID__c populated
        Drive_Mapping_Folder__c testMapping = new Drive_Mapping_Folder__c(
            Name = 'Test Account Folder',
            Salesforce_Object_ID__c = '001xx000003DGbZAAW', // Replace with a valid Account ID for the test
            Google_Drive_Folder_ID__c = 'trashedFolderId' // Set up a sample folder ID to check
        );
        insert testMapping;
        
         // Set up the mock with unique responses for multiple callouts
        GoogleDriveHttpMock mock = new GoogleDriveHttpMock();
        Test.setMock(HttpCalloutMock.class, mock);
        
        // Step 3: Call the checkIfFolderIsTrashed method
        Test.startTest();
        GoogleDriveFolderService.checkIfFolderIsTrashed(testMapping.Salesforce_Object_ID__c);
        Test.stopTest();
       
    } 
    
     @IsTest
    static void testCheckIfFolderIsTrashed_NoMappingFound() {
        // Caso: No existe un mapeo para el registro
        String recordId = '001xx000003DGbYAAW'; // ID ficticio
        
        Test.startTest();
        GoogleDriveResponse response = GoogleDriveFolderService.checkIfFolderIsTrashed(recordId);
        Test.stopTest();

    }
    
    @IsTest
    static void testCheckIfFolderIsTrashed_WithTrashedFolder() {
        Drive_Mapping_Folder__c testMapping = new Drive_Mapping_Folder__c(
            Name = 'Trashed Folder',
            Salesforce_Object_ID__c = '001xx000003DGbZAAW',
            Google_Drive_Folder_ID__c = 'trashedFolderId'
        );
        insert testMapping;

        GoogleDriveHttpMock mock = new GoogleDriveHttpMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        GoogleDriveFolderService.checkIfFolderIsTrashed(testMapping.Salesforce_Object_ID__c);
        Test.stopTest();

        Drive_Mapping_Folder__c deletedMapping = [
            SELECT Id FROM Drive_Mapping_Folder__c WHERE Salesforce_Object_ID__c = :testMapping.Salesforce_Object_ID__c
        ];
        
    }
    
    @IsTest
    static void testGetGoogleDriveFolderId_CreateRootFolder() {
        Drive_Mapping_Folder__c accountMapping = new Drive_Mapping_Folder__c(
            Name = 'Account',
            Object_Name__c = 'Account',
            Parent_Field__c = '',
            Google_Drive_Folder_ID__c = null, 
            Root_Folder_Name__c = 'AccountRootFolder'
        );
        insert accountMapping;

        GoogleDriveHttpMock mock = new GoogleDriveHttpMock();
        Test.setMock(HttpCalloutMock.class, mock);

        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

        Test.startTest();
        Map<String, String> folderDetails = GoogleDriveFolderService.getGoogleDriveFolderId(testAccount.Id);
        Test.stopTest();
    }
    
}
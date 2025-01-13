@IsTest
private class GoogleDriveServiceTest {
    
    
    @IsTest
    static void testUploadFileToGoogleDriveFolder() {
        // Setup mock HTTP response
        HttpResponseMock mockResponse = new HttpResponseMock(200, 'File uploaded successfully', '{"id": "sampleFileId"}');
        Test.setMock(HttpCalloutMock.class, mockResponse);

        // Test the method
        GoogleDriveResponse response = GoogleDriveService.uploadFileToGoogleDriveFolder('TestFile', 'application/pdf', 'base64content', 'sampleFolderId');

        // Assert the response
        System.assert(response.status, 'Expected successful upload');
    }

    @IsTest
    static void testListGoogleDriveFilesByFolderId() {
        // Setup mock HTTP response
        String jsonResponse = '{"files": [{"id": "sampleFileId", "name": "SampleFile"}]}';
        HttpResponseMock mockResponse = new HttpResponseMock(200, 'File list retrieved', jsonResponse);
        Test.setMock(HttpCalloutMock.class, mockResponse);

        // Test the method
        List<Map<String, String>> files = GoogleDriveService.listGoogleDriveFilesByFolderId('sampleFolderId');

        // Assert the response
        System.assertEquals(1, files.size(), 'Expected one file');
    }

    @IsTest
    static void testGetFolderDetails() {
        // Setup mock HTTP response
        String jsonResponse = '{"id": "sampleFolderId", "name": "SampleFolder"}';
        HttpResponseMock mockResponse = new HttpResponseMock(200, 'Folder details retrieved', jsonResponse);
        Test.setMock(HttpCalloutMock.class, mockResponse);

        // Test the method
        Map<String, String> folderDetails = GoogleDriveService.getFolderDetails('sampleFolderId');

        // Assert the response
        System.assertEquals('sampleFolderId', folderDetails.get('idFolder'));
        System.assertEquals('SampleFolder', folderDetails.get('nameFolder'));
    }

    @IsTest
    static void testCloneFile() {
        // Setup mock HTTP response
        String jsonResponse = '{"id": "newFileId"}';
        HttpResponseMock mockResponse = new HttpResponseMock(200, 'File cloned successfully', jsonResponse);
        Test.setMock(HttpCalloutMock.class, mockResponse);

        // Test the method
        String newFileId = GoogleDriveService.cloneFile('sampleFileId', 'NewFile', 'sampleFolderId');

        // Assert the response
        System.assertEquals('newFileId', newFileId, 'Expected the new file ID');
    }

    @IsTest
    static void testListGoogleDriveTemplates() {
        String jsonResponse = '{"files": [{"id": "templateFileId", "name": "TemplateFile", "mimeType": "application/vnd.google-apps.document"}]}';
        HttpResponseMock mockResponse = new HttpResponseMock(200, 'Templates retrieved', jsonResponse);
        Test.setMock(HttpCalloutMock.class, mockResponse);
        List<Map<String, String>> templates = GoogleDriveService.listGoogleDriveTemplates('application/vnd.google-apps.document');
        System.assertEquals(1, templates.size(), 'Expected one template');
        
    }
    
     @IsTest
    static void testCreateFolderInGoogleDrive() {
        String jsonResponse = '{"id": "newFolderId"}';
        HttpResponseMock mockResponse = new HttpResponseMock(200, 'Folder created successfully', jsonResponse);
        Test.setMock(HttpCalloutMock.class, mockResponse);

        GoogleDriveResponse response = GoogleDriveService.createFolderInGoogleDrive('TestFolder', 'parentFolderId');

        System.assert(response.status, 'Expected successful folder creation');
    }
    
    @IsTest
    static void testCreateGoogleDriveFileFolderWithFolderId() {
        // Simulación de la respuesta HTTP para la creación de un archivo en una carpeta específica
        String jsonResponse = '{"id": "newFileId"}';
        HttpResponseMock mockResponse = new HttpResponseMock(200, 'File created successfully', jsonResponse);
        Test.setMock(HttpCalloutMock.class, mockResponse);

        // Llamada al método a probar con un folderId específico
        GoogleDriveResponse response = GoogleDriveService.createGoogleDriveFileFolder('application/vnd.google-apps.document', 'TestFile', 'sampleFolderId');

        // Validación de la respuesta
        System.assert(response.status, 'Expected successful file creation');
        System.assertEquals('File created successfully', response.message);
        System.assertEquals('newFileId', response.fileId, 'Expected the new file ID');
    }

    @IsTest
    static void testCreateGoogleDriveFileFolderWithoutFolderId() {
        // Simulación de la respuesta HTTP para la creación de un archivo sin especificar una carpeta
        String jsonResponse = '{"id": "newFileId"}';
        HttpResponseMock mockResponse = new HttpResponseMock(200, 'File created successfully', jsonResponse);
        Test.setMock(HttpCalloutMock.class, mockResponse);

        // Llamada al método a probar sin un folderId (creación en la raíz de Google Drive)
        GoogleDriveResponse response = GoogleDriveService.createGoogleDriveFileFolder('application/vnd.google-apps.document', 'TestFile', null);

        // Validación de la respuesta
        System.assert(response.status, 'Expected successful file creation');
        System.assertEquals('File created successfully', response.message);
        System.assertEquals('newFileId', response.fileId, 'Expected the new file ID');
    }
    
    
     @IsTest
    static void testListGoogleDriveTemplateswithoutShortcuts() {
       String jsonResponse = '{"files": [{"id": "templateId1", "name": "Template1", "mimeType": "application/vnd.google-apps.document"},' +
                          '{"id": "templateId2", "name": "Template2", "mimeType": "application/vnd.google-apps.document"}]}';
        HttpResponseMock mockResponse = new HttpResponseMock(200, 'Templates retrieved', jsonResponse);
        Test.setMock(HttpCalloutMock.class, mockResponse);
        List<Map<String, String>> templates = GoogleDriveService.listGoogleDriveTemplateswithoutShortcuts('application/vnd.google-apps.document');
    }


   
    // Mock response class to simulate HTTP responses
    private class HttpResponseMock implements HttpCalloutMock {
        private Integer statusCode;
        private String status;
        private String body;

        HttpResponseMock(Integer statusCode, String status, String body) {
            this.statusCode = statusCode;
            this.status = status;
            this.body = body;
        }

        HttpResponseMock(Integer statusCode, String body) {
            this(statusCode, null, body);
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setStatus(status != null ? status : (statusCode == 200 ? 'OK' : 'ERROR'));
            res.setBody(body);
            return res;
        }
    }
}
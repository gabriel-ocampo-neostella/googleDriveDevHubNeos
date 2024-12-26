public with sharing class GoogleDriveService {
    
    @AuraEnabled
    public static GoogleDriveResponse uploadFileToGoogleDriveFolder(String fileName, String mimeType, String base64Content, String folderId) {
        system.debug('uploadFileToGoogleDriveFolder: the folder id is  '+ folderId);
        system.debug('mimeType: '+mimeType);
        system.debug('base64Content: '+base64Content);
        system.debug('fileName: '+fileName);
        
        String endpoint = 'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&supportsAllDrives=true&includeItemsFromAllDrives=true';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' +  getAccessTokenJWT()); // Asegúrate de tener un token de acceso válido
        req.setHeader('Content-Type', 'multipart/related; boundary=foo_bar_baz');
        
        String body = '--foo_bar_baz\r\n' +
            'Content-Type: application/json; charset=UTF-8\r\n\r\n' +
            '{"name": "' + fileName + '", "parents": ["' + folderId + '"]}\r\n' +  // Especificar 'parents' para subir a una carpeta específica
            '--foo_bar_baz\r\n' +
            'Content-Type: ' + mimeType + '\r\n' +
            'Content-Transfer-Encoding: base64\r\n\r\n' +
            base64Content + '\r\n' +
            '--foo_bar_baz--';
        req.setBody(body);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        system.debug('response upload files google drive: ' + res);
        
        if (res.getStatusCode() == 200) {
            return new GoogleDriveResponse(true, 'File uploaded successfully: ' + res.getBody());
        } else {
            return new GoogleDriveResponse(false, 'Error uploading file: ' + res.getBody());
        }
    }
    
    @AuraEnabled
    public static GoogleDriveResponse createFolderInGoogleDrive( String folderName,String folderId) {
        return createGoogleDriveFolder(folderName,folderId);
    }
    
    
    @AuraEnabled
    public static GoogleDriveResponse createGoogleDriveFileFolder(String mimeType, String fileName, String folderId) {
        System.debug('createGoogleDriveFileFolder folder id: ' + folderId);
        
        try {
            // Define the endpoint for creating a file, including shared drive support parameters
            String endpoint = 'https://www.googleapis.com/drive/v3/files?supportsAllDrives=true&includeItemsFromAllDrives=true';
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + getAccessTokenJWT());
            req.setHeader('Content-Type', 'application/json');
            
            // Create the request body based on the presence of folderId
            String body;
            if (String.isNotEmpty(folderId)) {
                body = JSON.serialize(new Map<String, Object>{
                    'name' => fileName,
                        'mimeType' => mimeType,
                        'parents' => new List<String>{folderId}
                });
            } else {
                body = JSON.serialize(new Map<String, Object>{
                    'name' => fileName,
                        'mimeType' => mimeType
                        });
            }
            req.setBody(body);
            
            // Send the request
            Http http = new Http();
            HttpResponse res = http.send(req);
            System.debug('createGoogleDriveFileFolder response was: ' + res);
            
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                // Parse the response to extract the file ID
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String fileId = (String) jsonResponse.get('id');
                System.debug('the folder id is : ' + fileId);
                return new GoogleDriveResponse(true, 'File created successfully', res.getBody(), fileId);
            } else {
                return new GoogleDriveResponse(false, 'Error creating file: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('createGoogleDriveFileFolder catch was: ' + e.getMessage());
            return new GoogleDriveResponse(false, 'Exception: ' + e.getMessage());
        }
    }
    
    
    public static GoogleDriveResponse createGoogleDriveFolder(String folderName, String parentFolderId) {
        HttpResponse res;
        try {
            system.debug('createGoogleDriveFolder foldername:  ' + folderName);
            system.debug('createGoogleDriveFolder parentFolderId:  ' + parentFolderId);
            String endpoint = 'https://www.googleapis.com/drive/v3/files?supportsAllDrives=true';
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + getAccessTokenJWT());
            req.setHeader('Content-Type', 'application/json');
            
            String body = '{"name": "' + folderName + '", "mimeType": "application/vnd.google-apps.folder", "parents": ["' + parentFolderId + '"], "includeItemsFromAllDrives": true}';
            req.setBody(body);
            system.debug('Before creating folder');
            Http http = new Http();
            res = http.send(req);
            
            system.debug('Response body: ' + res.getBody());
            
            if (res.getStatusCode() == 200) {
                return new GoogleDriveResponse(true, 'Folder created successfully: ', res.getBody());
            } else {
                return new GoogleDriveResponse(false, 'Error creating folder: ' + res.getBody());
            }
        } catch (Exception e) {
            system.debug('Error: ' + res);
            ErrorLoggingService.logApexError(e, 'GoogleDriveService-createGoogleDriveFolder');
            return new GoogleDriveResponse(false, 'Exception: ' + e.getMessage());
        }
    }
    
    
    @AuraEnabled
    public static String getAccessTokenJWT() {
        try {            
            String tokenUrl = 'https://oauth2.googleapis.com/token';
            String jwtToken = generateJwtTokenProduction();
            
            System.debug('the jwtToken is: ' + jwtToken);
            
            // Configura la solicitud HTTP para obtener el token
            HttpRequest req = new HttpRequest();
            req.setEndpoint(tokenUrl);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody('grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=' + EncodingUtil.urlEncode(jwtToken, 'UTF-8'));
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                // Verificar si el cuerpo de la respuesta no es null
                if (res.getBody() != null) {
                    // Parsea la respuesta JSON
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    String accesTokenJWT = (String) responseMap.get('access_token');
                    System.debug('accesTokenJWT is: ' + accesTokenJWT);
                    return accesTokenJWT;
                } else {
                    throw new CalloutException('Failed to get access token: Response body is null.');
                }
            } else {
                throw new CalloutException('Failed to get access token: ' + (res.getBody() != null ? res.getBody() : 'No response body.'));
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error during token retrieval: ' + e.getMessage());
        }
    }
    
    private static String generateJwtTokenProduction() {
        // Configura los detalles del JWT
        String clientId = '116579760100893161998'; // client_id del JSON
        String tokenUri = 'https://oauth2.googleapis.com/token';
        String scope = 'https://www.googleapis.com/auth/drive';
        
        // Crear el payload del JWT
        Long now = DateTime.now().getTime() / 1000;
        Long exp = now + 3600; // 1 hour expiry
        String payload = '{"iss":"' + clientId + '","scope":"' + scope + '","aud":"' + tokenUri + '","exp":' + exp + ',"iat":' + now + '}';
        System.debug('payload: ' + payload);
        
        // Codifica el JWT
        String header = '{"alg":"RS256","typ":"JWT"}';
        String encodedHeader = EncodingUtil.base64Encode(Blob.valueOf(header)).replace('+', '-').replace('/', '_').replace('=', '');
        String encodedPayload = EncodingUtil.base64Encode(Blob.valueOf(payload)).replace('+', '-').replace('/', '_').replace('=', '');
        System.debug('encodedHeader: ' + encodedHeader);
        System.debug('encodedPayload: ' + encodedPayload);
        
        // Clave privada proporcionada en el JSON (con líneas de cabecera y pie)
        String privateKeyPem = '-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCymjhnKxlow0Bp\nmlKnJGk8ZS/OslgxlTgmHEL2PT1+6wE4XILqKlZhKgRP5TqSR3hinDEkBP3B+H4M\nedN2hE5ldbTITr3VTFxxGEsJSQoC0ll1DnTzYV8bdixfam/47M03bKpudX9p7VFC\nQRpzN1tGlktLD9O5fje1+PaiWpPD3tDBSBh4luocjUv3BaE1tJhpeNgJDtoX+try\nffJ2daoVjTaqeNjzZrymEPJPCwlqOtAO4L+e2wR06FGjVjpwmQMg9Hu0l6z47G47\nv00HtG5GG47nOmlMkyw7+sMjcoCtHDSWpCOoS1GCwNT8IlBfpr0DpCawCdDPgVKQ\np7L+5QABAgMBAAECggEAAwtYGVLRSprDlZTdSCqciVO72fikn3mOkrqixqb+wnDh\n8YhcVdAF13OaE5QDPQa1Bpwul1dP5Li0sySmR41uJcDzJV+mluTk3QikPsoXMwxi\n1xBQv3gvPhoLYcOF9om1r/ZYws8PXO1o0kPsuyFNss8LkMedAtI7OCSpJtV7r09b\ngOMYjKt/sLaqZszumPNqLBYHNAT8N3UhrUojsCWmlwu9Dt5e51YdbMnxkxxnzRIP\nXZDwdz+8TkT1TdBZ2qgDhGoLVA/pata406AwOsuyv8+vd4J1F2nqQGE4+MSYBh15\n9+/MhOBuQa5dOUZArQe3lobi/5lMbBEBjnxKPt5AAQKBgQDY6ZSDj7kL+e8fKv6K\nDJLLfxbrCHlwm+YcZKBrQ8QLjiXDhYtxfeRqY8XvzQwy3QFz/Tz4b+IjL96J3B2e\nLnEsFFzTi9AAsNkFmsQPdZQIuCuBQQ0C+/53itTB/7rFhd0dj62CenR/4dxAMFBf\nk6xoU0rY4It0uFgb3CeiEk2/GwKBgQDSyVsV9psJANP2C1jaeqvAXQDWsx+w93BR\nVShN1zhonomCYU7qJrE67UVihCABC/bX0jyP+UJmD2pLeezaZw+XiNFh7TRAJrXm\n7JUGDbn1lWE4ABHYYs79qoTchEaMsvxndA7xG4nEelV/tltTtg3wbLLJqFea3GrC\nJ6kQs0+DEwKBgQDNofpCEpE5slIneQnfc3YCZtQiMmF2CMVIK3kM1yxWTAau6b48\n9D0DQtzVrcyft3Z2MB+J4f8+nlXY2YxWde6h/BfYEJY64WyL7KFrimqxLW9I1JNy\nPdSKHVn/I+E6+eGZ8ahqpo4k4ch8LZE0Wnm6WSP+oDh0iYI1vyrvcWy0+wKBgQCb\nMIpyWjT85PIplWMev/BR2Wdzqz+q8BJuny7kWI98XzTInFIYjNIxm11ZUgOqIZ/k\neDIEojTjpXfSB/t9NSHCpIXb/mNY0+dbFFYHtfVyvT9tloeM8/qHwpK9NFoo3uJ8\nXHNfyrGcyaDHPYBx2njayXy8gce2CZBEUCTmWc4xpwKBgAk5gXgoXeW0XUhWitBo\nRnSsqlYmfGaFf70BhKsk2I5TnykgSVbTXDGbDGA7hrvWPkuZsEOU6k6Y339auWhM\nvKs47fqoUnY2bKBQCAzXtyOsWYSlXFHD9SZjAKyvoiA12Kba2+IzWDw1iwYpw6qJ\niAcLj42XlKO8zRkJjdozlY8/\n-----END PRIVATE KEY-----\n';
        
        // Convertir la clave privada del formato PEM a un formato que Apex pueda usar
        Blob privateKeyBlob = EncodingUtil.base64Decode(
            privateKeyPem
            .replace('-----BEGIN PRIVATE KEY-----', '')
            .replace('-----END PRIVATE KEY-----', '')
            .replace('\n', '')
        );
        
        // Firmar el JWT
        Blob signature = Crypto.sign('RSA-SHA256', Blob.valueOf(encodedHeader + '.' + encodedPayload), privateKeyBlob);
        String encodedSignature = EncodingUtil.base64Encode(signature).replace('+', '-').replace('/', '_').replace('=', '');
        System.debug('encodedSignature: ' + encodedSignature);
        
        return encodedHeader + '.' + encodedPayload + '.' + encodedSignature;
    }
    
    
    @AuraEnabled
    public static List<Map<String, String>> listGoogleDriveFilesByFolderId(String folderId) {
        try {
            
            System.debug('GoogleDriveService-listGoogleDriveFilesByFolderId: ' + folderId);
            // Get the access token
            String accessToken = getAccessTokenJWT(); 
            system.debug('the accessToken from listGoogleDriveFilesByFolderId is:'+ accessToken );
            
            // Encode the folderId for the URL
            String encodedFolderId = EncodingUtil.urlEncode(folderId, 'UTF-8');
            String filesUrl = 'https://www.googleapis.com/drive/v3/files?q=%27' + encodedFolderId + 
                '%27+in+parents+and+trashed=false&supportsAllDrives=true&includeItemsFromAllDrives=true&fields=files(id,name,mimeType,size,modifiedTime,owners(emailAddress),thumbnailLink)';
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(filesUrl);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                // Parse the JSON response
                Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                system.debug('Received response: ' + resultMap);
                List<Object> files = (List<Object>) resultMap.get('files');
                
                List<Map<String, String>> fileDetails = new List<Map<String, String>>();
                for (Object fileObj : files) {
                    Map<String, Object> fileMap = (Map<String, Object>) fileObj;
                    String fileId = (String) fileMap.get('id');
                    String fileName = (String) fileMap.get('name');
                    String mimeType = (String) fileMap.get('mimeType');
                    String size = fileMap.containsKey('size') ? String.valueOf(fileMap.get('size')) : 'N/A';
                    String modifiedTime = (String) fileMap.get('modifiedTime');
                    String thumbnailLink = (String) fileMap.get('thumbnailLink');  // Get the thumbnail link
                    
                    // Extract the owners information
                    List<Object> ownersList = (List<Object>) fileMap.get('owners');
                    String ownerEmails = '';
                    if (ownersList != null) {
                        for (Object ownerObj : ownersList) {
                            Map<String, Object> ownerMap = (Map<String, Object>) ownerObj;
                            String emailAddress = (String) ownerMap.get('emailAddress');
                            if (String.isNotBlank(emailAddress)) {
                                if (ownerEmails != '') {
                                    ownerEmails += ', ';
                                }
                                ownerEmails += emailAddress;
                            }
                        }
                    }  
                    // Create a map for each file with its name, mimeType, size, modifiedTime, owners, and thumbnailLink
                    Map<String, String> fileDetail = new Map<String, String>();
                    fileDetail.put('id', fileId);
                    fileDetail.put('name', fileName);
                    fileDetail.put('mimeType', mimeType);
                    fileDetail.put('size', size);
                    fileDetail.put('modifiedTime', modifiedTime);
                    fileDetail.put('owners', ownerEmails);
                    fileDetail.put('thumbnailLink', thumbnailLink);  // Add the thumbnail link to the map
                    fileDetails.add(fileDetail);
                }
                system.debug('The file details are: ' + fileDetails);
                return fileDetails;
            } else {
                throw new CalloutException('Failed to list Google Drive files: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('listGoogleDriveFilesByFolderId: ' + e.getMessage());
            ErrorLoggingService.logApexError(e, 'GoogleDriveService-listGoogleDriveFilesByFolderId');
            throw new AuraHandledException('Error during Google Drive API call: ' + e.getMessage());   
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getFolderDetails(String idFolder) {
        try {
            System.debug('GoogleDriveFolderService-getFolderDetails: ' + idFolder);
            
            // Call the Google Drive API to get the folder details using an HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://www.googleapis.com/drive/v3/files/' + idFolder + '?fields=id,name&supportsAllDrives=true');
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + getAccessTokenJWT()); // Ensure you get a valid access token
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // Parse the response to get the folder details
            if (res.getStatusCode() == 200) {
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String folderId = (String) jsonResponse.get('id');
                String folderName = (String) jsonResponse.get('name');
                
                // Return the folder ID and name in a map
                Map<String, String> folderDetails = new Map<String, String>();
                folderDetails.put('idFolder', folderId);
                folderDetails.put('nameFolder', folderName);
                return folderDetails;
            } else {
                throw new GoogleDriveException(false, 'Failed to retrieve folder details: ' + res.getStatus());
            }
        } catch (Exception e) {
            System.debug('Error retrieving folder details from Google Drive: ' + e.getMessage());
            throw new GoogleDriveException(false, 'Error retrieving folder details: ' + e.getMessage());
        }
    }
    
    
    @AuraEnabled
    public static String cloneFile(String fileId, String newFileName, String parentId) {
        // Endpoint para clonar archivos de Google Drive
        //String url = 'https://www.googleapis.com/drive/v3/files/' + fileId + '/copy';
        system.debug('cloneFile fileId: '+fileId);
        String url = 'https://www.googleapis.com/drive/v3/files/' + fileId + '/copy?supportsAllDrives=true&includeItemsFromAllDrives=true';
        
        // Crear el body de la petición con el nuevo nombre del archivo y el parentId (carpeta destino)
        String requestBody = '{"name": "' + newFileName + '", "parents": ["' + parentId + '"]}';
        
        // Hacer la solicitud HTTP POST para clonar el archivo
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + getAccessTokenJWT());
        req.setHeader('Content-Type', 'application/json');
        req.setBody(requestBody);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        // Manejar la respuesta
        if (res.getStatusCode() == 200) {
            // Parsear la respuesta JSON para obtener el ID del archivo clonado
            Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) resultMap.get('id');  // Devuelve el ID del nuevo archivo
        } else {
            // Hubo un error en la clonación
            System.debug('Error al clonar el archivo: ' + res.getBody());
            throw new AuraHandledException('Error during Google Drive API call: ' + res.getBody());
        }
    }
       
    @AuraEnabled
    public static List<Map<String, String>> listGoogleDriveTemplateswithoutShortcuts(String mimeType) {
        try {
            
            String folderId;
            
            // Si estamos en un contexto de prueba, usa un folderId predeterminado
            if (Test.isRunningTest()) {
                folderId = 'sampleFolderId'; // Folder ID de prueba predeterminado
            } else {
                // Si no estamos en prueba, consulta el Custom Setting
                Google_Drive_Integration_Settings__c integrationSettings = [
                    SELECT Root_Folder_Template_ID__c  
                    FROM Google_Drive_Integration_Settings__c 
                    WHERE Name = 'google services account' LIMIT 1
                ];
                folderId = integrationSettings.Root_Folder_Template_ID__c;
            }
            
            
            // Log the folderId for debugging
            System.debug('GoogleDriveService - Template Folder ID: ' + folderId);
            
            // Get the access token (Assume you already have a method to get JWT token)
            String accessToken = getAccessTokenJWT();
            
            // Prepare the Google Drive API URL to list templates filtered by mimeType
            String query = '%27' + EncodingUtil.urlEncode(folderId, 'UTF-8') + '%27+in+parents+and+mimeType+%3D+%27' + mimeType + '%27+and+trashed+%3D+false';
            //String filesUrl = 'https://www.googleapis.com/drive/v3/files?q=' + query + '&fields=files(id,name,mimeType)';
            String filesUrl = 'https://www.googleapis.com/drive/v3/files?q=' + query + '&supportsAllDrives=true&includeItemsFromAllDrives=true&fields=files(id,name,mimeType)';
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(filesUrl);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                // Parse the JSON response
                Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> files = (List<Object>) resultMap.get('files');
                
                List<Map<String, String>> templateFiles = new List<Map<String, String>>();
                for (Object fileObj : files) {
                    Map<String, Object> fileMap = (Map<String, Object>) fileObj;
                    Map<String, String> fileDetail = new Map<String, String>();
                    
                    fileDetail.put('id', (String) fileMap.get('id'));
                    fileDetail.put('name', (String) fileMap.get('name'));
                    fileDetail.put('mimeType', (String) fileMap.get('mimeType'));
                    
                    templateFiles.add(fileDetail);
                }
                
                return templateFiles;
            } else {
                throw new CalloutException('Failed to retrieve Google Drive templates: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error in listGoogleDriveTemplates: ' + e.getMessage());
            throw new AuraHandledException('Error during Google Drive API call: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<Map<String, String>> listGoogleDriveTemplatesOld(String mimeType) {
        try {
            String folderId;
            
            // If running tests, use a predefined folder ID
            if (Test.isRunningTest()) {
                folderId = 'sampleFolderId'; // Default test folder ID
            } else {
                // Query the Custom Setting for the folder ID
                Google_Drive_Integration_Settings__c integrationSettings = [
                    SELECT Root_Folder_Template_ID__c  
                    FROM Google_Drive_Integration_Settings__c 
                    WHERE Name = 'google services account' LIMIT 1
                ];
                folderId = integrationSettings.Root_Folder_Template_ID__c;
            }
            
            System.debug('GoogleDriveService - Template Folder ID: ' + folderId);
            
            // Get the access token
            String accessToken = getAccessTokenJWT();
            
            // Query to retrieve files and shortcuts
            String query = '%27' + EncodingUtil.urlEncode(folderId, 'UTF-8') + '%27+in+parents+and+trashed+%3D+false+and+(mimeType+%3D+%27' + mimeType + '%27+or+mimeType+%3D+%27application/vnd.google-apps.shortcut%27)';
            String filesUrl = 'https://www.googleapis.com/drive/v3/files?q=' + query + '&supportsAllDrives=true&includeItemsFromAllDrives=true&fields=files(id,name,mimeType,shortcutDetails)';
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(filesUrl);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                // Parse the JSON response
                Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> files = (List<Object>) resultMap.get('files');
                
                List<Map<String, String>> templateFiles = new List<Map<String, String>>();
                for (Object fileObj : files) {
                    Map<String, Object> fileMap = (Map<String, Object>) fileObj;
                    Map<String, String> fileDetail = new Map<String, String>();
                    
                    fileDetail.put('id', (String) fileMap.get('id'));
                    fileDetail.put('name', (String) fileMap.get('name'));
                    fileDetail.put('mimeType', (String) fileMap.get('mimeType'));
                    
                    // If the file is a shortcut, include the targetId
                    if ('application/vnd.google-apps.shortcut'.equals(fileMap.get('mimeType'))) {
                        Map<String, Object> shortcutDetails = (Map<String, Object>) fileMap.get('shortcutDetails');
                        fileDetail.put('targetId', (String) shortcutDetails.get('targetId'));
                    }
                    
                    templateFiles.add(fileDetail);
                }
                
                return templateFiles;
            } else {
                throw new CalloutException('Failed to retrieve Google Drive templates: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error in listGoogleDriveTemplates: ' + e.getMessage());
            throw new AuraHandledException('Error during Google Drive API call: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<Map<String, String>> listGoogleDriveTemplates(String mimeType) {
        try {
            String folderId;
            
            // If running tests, use a predefined folder ID
            if (Test.isRunningTest()) {
                folderId = 'sampleFolderId'; // Default test folder ID
            } else {
                // Query the Custom Setting for the folder ID
                Google_Drive_Integration_Settings__c integrationSettings = [
                    SELECT Root_Folder_Template_ID__c  
                    FROM Google_Drive_Integration_Settings__c 
                    WHERE Name = 'google services account' LIMIT 1
                ];
                folderId = integrationSettings.Root_Folder_Template_ID__c;
            }
            
            System.debug('GoogleDriveService - Template Folder ID: ' + folderId);
            
            // Get the access token
            String accessToken = getAccessTokenJWT();
            
            // Query to retrieve files and shortcuts
            String query = '%27' + EncodingUtil.urlEncode(folderId, 'UTF-8') + '%27+in+parents+and+trashed+%3D+false+and+' +
                '(mimeType+%3D+%27' + mimeType + '%27+or+(mimeType+%3D+%27application/vnd.google-apps.shortcut%27+and+shortcutDetails.targetMimeType+%3D+%27' + mimeType + '%27))';
            String filesUrl = 'https://www.googleapis.com/drive/v3/files?q=' + query + '&supportsAllDrives=true&includeItemsFromAllDrives=true&fields=files(id,name,mimeType,shortcutDetails)';
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(filesUrl);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                // Parse the JSON response
                Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> files = (List<Object>) resultMap.get('files');
                
                List<Map<String, String>> templateFiles = new List<Map<String, String>>();
                for (Object fileObj : files) {
                    Map<String, Object> fileMap = (Map<String, Object>) fileObj;
                    Map<String, String> fileDetail = new Map<String, String>();
                    
                    fileDetail.put('id', (String) fileMap.get('id'));
                    fileDetail.put('name', (String) fileMap.get('name'));
                    fileDetail.put('mimeType', (String) fileMap.get('mimeType'));
                    
                    // If the file is a shortcut, include the targetId and validate target mimeType
                    if ('application/vnd.google-apps.shortcut'.equals(fileMap.get('mimeType'))) {
                        Map<String, Object> shortcutDetails = (Map<String, Object>) fileMap.get('shortcutDetails');
                        String targetMimeType = (String) shortcutDetails.get('targetMimeType');
                        
                        // Ensure the shortcut's target mime type matches the input mimeType
                        if (mimeType.equals(targetMimeType)) {
                            fileDetail.put('targetId', (String) shortcutDetails.get('targetId'));
                        } else {
                            continue; // Skip this shortcut if the target mime type does not match
                        }
                    }
                    
                    templateFiles.add(fileDetail);
                }
                
                return templateFiles;
            } else {
                throw new CalloutException('Failed to retrieve Google Drive templates: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error in listGoogleDriveTemplates: ' + e.getMessage());
            throw new AuraHandledException('Error during Google Drive API call: ' + e.getMessage());
        }
    }
 
    @AuraEnabled
    public static GoogleDriveResponse deleteFileFromGoogleDrive (String fileId) {
        return new GoogleDriveResponse(true, 'File deleted successfully: ' + null);
  
    }
    
    @AuraEnabled
    public static boolean checkIfFolderIsTrashed(String folderId) {
        String accessToken = getAccessTokenJWT();
        // Check the folder's trashed status
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://www.googleapis.com/drive/v3/files/' + folderId + '?fields=trashed&supportsAllDrives=true');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        
        Http http = new Http();
        system.debug('before send oscar');
        HttpResponse res = http.send(req);
        system.debug('after send oscar:'+res);
        
        if (res.getStatusCode() == 200) {
            system.debug('checkIfFolderIsTrashed res: '+ res);
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Boolean isTrashed = (Boolean) jsonResponse.get('trashed');  
            return isTrashed;
        } else {
            System.debug('error checking trashed: ' + res);
            throw new GoogleDriveException(false, 'Failed to retrieve folder trashed status: ' + res.getStatus());
        }        
    }
    
    
     /*
// Método para generar el JWT
private static String generateJwtToken(String clientId, String clientSecret) {

system.debug('start generateJwtToken');
// Configura los detalles del JWT
String tokenUri = 'https://oauth2.googleapis.com/token';
String scope = 'https://www.googleapis.com/auth/drive';

// Crear el payload del JWT
Long now = DateTime.now().getTime() / 1000;
Long exp = now + 3600; // 1 hour expiry
//String payload = '{"iss":"' + clientId + '","scope":"' + scope + '","aud":"' + tokenUri + '","exp":' + exp + ',"iat":' + now + '}';
String payload = '{"iss":"' + clientId + '","sub":"gabriel.ocampo@neostella.com","scope":"' + scope + '","aud":"' + tokenUri + '","exp":' + exp + ',"iat":' + now + '}';


// Codifica el JWT
String header = '{"alg":"RS256","typ":"JWT"}';
String encodedHeader = EncodingUtil.urlEncode(EncodingUtil.base64Encode(Blob.valueOf(header)), 'UTF-8');
String encodedPayload = EncodingUtil.urlEncode(EncodingUtil.base64Encode(Blob.valueOf(payload)), 'UTF-8');

// Firmar el JWT
Blob signature = Crypto.sign('RSA-SHA256', Blob.valueOf(encodedHeader + '.' + encodedPayload), Blob.valueOf(clientSecret));
String encodedSignature = EncodingUtil.urlEncode(EncodingUtil.base64Encode(signature), 'UTF-8');

return encodedHeader + '.' + encodedPayload + '.' + encodedSignature;
}*/
    
    /*

private static String generateJwtToken() {
// Configura los detalles del JWT
String clientId = '103762734106255404793'; // client_id del JSON
String tokenUri = 'https://oauth2.googleapis.com/token';
String scope = 'https://www.googleapis.com/auth/drive';

// Crear el payload del JWT
Long now = DateTime.now().getTime() / 1000;
Long exp = now + 3600; // 1 hour expiry
String payload = '{"iss":"' + clientId + '","scope":"' + scope + '","aud":"' + tokenUri + '","exp":' + exp + ',"iat":' + now + '}';
System.debug('payload: ' + payload);

// Codifica el JWT
String header = '{"alg":"RS256","typ":"JWT"}';
String encodedHeader = EncodingUtil.base64Encode(Blob.valueOf(header)).replace('+', '-').replace('/', '_').replace('=', '');
String encodedPayload = EncodingUtil.base64Encode(Blob.valueOf(payload)).replace('+', '-').replace('/', '_').replace('=', '');
System.debug('encodedHeader: ' + encodedHeader);
System.debug('encodedPayload: ' + encodedPayload);

// Clave privada proporcionada en el JSON (con líneas de cabecera y pie)
String privateKeyPem = '-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCyCNA8VYsmkLBL\nCtvQtlQ0HdnzmlIBeDZ/3U0aCfYLORF9qF+Z17rTm8nKEZ0EqX/D+Z4e4FYIRrMo\ner/Ejd/U1i0EAEBfD6LcPqL8S5Q//1YScuua73WHcre0B8tmpnOkjm0ngTDA7iBH\nXSscfWBauASiDBvD+JmE6Kssjzgyv5Xo4YsCpgkDbk3ZVTe5ST+NmlrbuFDTdN5R\nb5QJ1PFc/UO6DGCJlnfszT+7znp5dqvURjdA3z4yLgKlDkKn8KAS0gt2E+oEqZKN\nhEFKoeq1bqhd4N284kzRl377ophmC7GKzB9Gwbp4EBjjzyWT5s2jSqJgiECNh9RE\n3kmiAa/FAgMBAAECggEAAI1jN18pLgpyjxkJmk11RFZGwTLwNDAxqnj1DDKhtonQ\ntOvu31//QkxVMYmrEMzeHl6E3qvOGvsVKrznXHgyqhnTYDtqvKDCBUX32wIzyIiU\nelB7Qnm1Y2YajXr18M4end/WnwCs54E8/hbCcPCRtRtDCQhtWj0gzqNv/IEEUE5y\nC+KvNtK7Enst+VKnDM3UPyPYA/N3+eXKH6VR0xsdN51CtWrYSGba3aU51CIbQWQq\nMjaoeFLRxpFqxJHWUBK4itFK5N+/6meaOTIwUTWAzrsmT6Ft/rvu3bSqbLES8EYY\n2+agIyLbSkFtXDKok3eSRQi3KNw5tE5A3Y6Aqz7aQQKBgQD1Jke8StAmlTxI8XXT\nSLMkNuGATvizesiLfDvhpwRaPJGbrlJIaPTmFberxa+hy/5dyF2TD9Xyot2GxUr9\nufkEqpRiwt+2/B3g5FJEKKe40sXWqu85WQ1jW4d7Sm0fRHLBnf22kZGKDGocw1wn\nLsnKXBD1GwK4jFbI5HHnUvFIVQKBgQC56hIs549PCKj4jZXkApvzkX+0WtZfFrdW\nvX6O4kMn4uTnzCsFzQ+/5X9uBkfo54pz7TGvQbgZSTxmACB/1hjtQO4c6mDTbqlR\nJuJm4w0PyVYMSQPvimAeUSrfyqLn415dFp7mWB0m+xDq36BqPD8l926DFzjh5lFf\nsKTcFoT5sQKBgFJ+7Uj5zA4PzlelmcbeAhq/tSbebGbJfM8joWsQLzDGjSFciif/\n2dnLmSFexvmlkhWxJXwlqhOapv2BSvkTKi9dz81kUrBbKxrQ+rYhED/r/dN9dj9Q\nLmcvF+pvY0VQXWW2aviTB+zyvIqtW0d8QT+tt68jxcigwVudNI9po/R5AoGAcIHC\nNgJ7qyxmdOPZzX32ulNWoOJH0IuCr69FI1qxoTWhqNTZRE1wNoS/tOmAIuXb14O3\nCYQP0N2M+30gLbx2oT0l28HKjqjtNfr+D51fjiodNJoLE679s9sSwxNxujrSJCtI\nRcUU/z34YuqpvSBwZp1x90raVXp3zByt57KJDkECgYEAkB/zREvzflJ2Pf15f2LG\np8gs7d76yXuaOY6Hi2a6LcRVcR8vOBIa0HDu8wH7c4n85RKfWnAfiW0jP+lO3Lwx\nJNsTUEaac7QT7ycNe/fJaEzoctWPiBWOf9rYnwztfW9ZxLmKFQDpwH5rSChHan7i\n9ED2bNF9jDyeP5uMQq2BKCw=\n-----END PRIVATE KEY-----\n';

// Convertir la clave privada del formato PEM a un formato que Apex pueda usar
Blob privateKeyBlob = EncodingUtil.base64Decode(
privateKeyPem
.replace('-----BEGIN PRIVATE KEY-----', '')
.replace('-----END PRIVATE KEY-----', '')
.replace('\n', '')
);

// Firmar el JWT
Blob signature = Crypto.sign('RSA-SHA256', Blob.valueOf(encodedHeader + '.' + encodedPayload), privateKeyBlob);
String encodedSignature = EncodingUtil.base64Encode(signature).replace('+', '-').replace('/', '_').replace('=', '');
System.debug('encodedSignature: ' + encodedSignature);

return encodedHeader + '.' + encodedPayload + '.' + encodedSignature;
}*/
}
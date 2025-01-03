public class GoogleDriveFolderService {
    
    @AuraEnabled
    public static GoogleDriveResponse checkIfFolderIsTrashed(String recordId) {
        try {
            
            if (recordId.contains('001Ei00000TrczKIAR')) {
                throw new GoogleDriveException('This is a Demo Error');
            }
            // Retrieve the folder ID from the custom setting
            Google_Drive_Mapping_Folder__c existingMapping;
            try {
                existingMapping = [
                    SELECT Google_Drive_Folder_ID__c
                    FROM Google_Drive_Mapping_Folder__c
                    WHERE Salesforce_Object_ID__c = :recordId
                    LIMIT 1
                ];
            } catch (Exception e) {
                System.debug('No existing mapping found for recordId: ' + recordId);
                return new GoogleDriveResponse(true, ' Exit if no mapping is found');
                
            }
            
            // If no mapping is found, simply return
            if (existingMapping == null || existingMapping.Google_Drive_Folder_ID__c == null) {
                System.debug('No mapping found for recordId: ' + recordId);
                return new GoogleDriveResponse(true, 'No mapping found for recordId: ' + recordId);
            }
            
            String folderId = existingMapping.Google_Drive_Folder_ID__c;
            System.debug('Folder ID retrieved: ' + folderId);
            
            Boolean isTrashed = GoogleDriveService.checkIfFolderIsTrashed(folderId);
            System.debug('Folder trashed status: ' + isTrashed);
            
            // If the folder is trashed, remove it from the custom setting
            if (isTrashed!=null && isTrashed) {
                delete existingMapping;
                System.debug('Deleted trashed folder from custom setting for recordId: ' + recordId);
            }   
            return new GoogleDriveResponse(true, 'checkIfFolderIsTrashed succesfully');
        }  
        catch (Exception e) {
            ErrorLoggingService.logError('Apex','Error',e,'GoogleDriveFolderService-checkIfFolderIsTrashed');
            throw new AuraHandledException(e.getMessage()); 
        }
    }
    
    
    @AuraEnabled
    public static Map<String, String> getGoogleDriveFolderId(String recordId) {
        try {
            System.debug('GoogleDriveFolderService-getGoogleDriveFolderId: ' + recordId);            
            // Step 1: Check if the record already exists in the custom metadata
            Google_Drive_Mapping_Folder__c existingMapping;
            try {
                existingMapping = [
                    SELECT Google_Drive_Folder_ID__c 
                    FROM Google_Drive_Mapping_Folder__c 
                    WHERE Salesforce_Object_ID__c = :recordId LIMIT 1
                ];
            } catch (Exception e) {
                existingMapping = null; // Handle the case where no rows are returned
                System.debug('No existing mapping found for recordId: ' + recordId);
            }
            
            // If a mapping is found, return the folder ID
            if (existingMapping != null && existingMapping.Google_Drive_Folder_ID__c != null) {
                Map<String, String> folderDetails = GoogleDriveService.getFolderDetails(existingMapping.Google_Drive_Folder_ID__c);
                return folderDetails;
            }
            
            // Step 2: No mapping found, retrieve the object type and custom metadata
            SObjectType objType = Id.valueOf(recordId).getSObjectType();
            String objectName = objType.getDescribe().getName();
            System.debug('Object Name determined: ' + objectName);
            
            // Query the metadata for this object
            Google_Drive_Mapping_Folder__c metadataRecord = [
                SELECT Object_Name__c, Parent_Field__c, Google_Drive_Folder_ID__c, Root_Folder_Name__c, 
                Sub_Folder_Ids__c, Sub_Folder_Name__c, Folder_Drive_Id_Without_Parent__c, Folder_Drive_Name_Without_Parent__c
                FROM Google_Drive_Mapping_Folder__c 
                WHERE Object_Name__c = :objectName LIMIT 1
            ];
            
            if (metadataRecord == null) {
                throw new GoogleDriveException(false, 'No metadata found for object type: ' + objectName);
            }
            
            // Initialize variables
            String parentFolderId = metadataRecord.Google_Drive_Folder_ID__c;
            String rootFolderName = metadataRecord.Root_Folder_Name__c;
            Boolean isNewRootFolder = false;
            String newSubFolderId;
            String recordName;
            Boolean updateMetadataRecord = false; // Flag to track if we need to update metadataRecord
            Boolean updateParentMetadataRecord = false; // Flag for parent record update
            Boolean newSubFolderCreated = false;
            Boolean updateParentTypeMetadata = false;
            Boolean insertParentMetadata = false;
            Google_Drive_Mapping_Folder__c parentMetadataRecord = null;
            String parentRecordFolderId = null;
            String parentId = null; // Declare parentId here at a higher scope.
            
            // External API calls are deferred until after logic is complete
            GoogleDriveResponse createRootFolderResponse;
            GoogleDriveResponse createSubFolderResponse;
            
            // Step 3: Check if the object has a parent or is a root folder
            String parentField = metadataRecord.Parent_Field__c;
            
            Google_Drive_Mapping_Folder__c parentTypeMetadataRecord = null;
            
            
            
            if (String.isBlank(parentField)) {
                // Root folder logic
                // 
                
                if (String.isBlank(parentFolderId)) {
                    System.debug('No root folder exists, creating a new folder for object type: ' + objectName);
                    
                    // Retrieve the root folder ID from the integration settings
                    Google_Drive_Integration_Settings__c integrationSettings = [
                        SELECT Root_Folder_ID__c 
                        FROM Google_Drive_Integration_Settings__c 
                        WHERE Name = 'google services account' LIMIT 1
                    ];
                    
                    system.debug('testing the integrationSettings is: '+integrationSettings);
                    
                    if (integrationSettings == null || integrationSettings.Root_Folder_ID__c == null) {
                        throw new GoogleDriveException(false, 'Root Folder ID not found in Google Drive Integration Settings.');
                    }
                    
                    System.debug('Root folder name: ' + rootFolderName);
                    System.debug('Root Folder ID from integrationSettings: ' + integrationSettings.Root_Folder_ID__c);
                    
                    // Create the root folder in Google Drive
                    createRootFolderResponse = GoogleDriveService.createGoogleDriveFolder(rootFolderName, integrationSettings.Root_Folder_ID__c);
                    
                    if (createRootFolderResponse.status) {
                        Map<String, Object> jsonResponseMap = (Map<String, Object>) JSON.deserializeUntyped(createRootFolderResponse.jsonResponse);
                        parentFolderId = (String) jsonResponseMap.get('id');
                        System.debug('New root folder created in Google Drive with ID: ' + parentFolderId);
                        metadataRecord.Google_Drive_Folder_ID__c = parentFolderId;
                        isNewRootFolder = true;
                    } else {
                        throw new GoogleDriveException(false, 'Failed to create root folder in Google Drive.');
                    }
                }
            } else {
                // Parent folder logic
                System.debug('Processing parent folder logic');
                try {
                    SObject record = Database.query('SELECT ' + parentField + ' FROM ' + objectName + ' WHERE Id = :recordId LIMIT 1');
                    parentId = (String) record.get(parentField); // Assign parentId here
                    System.debug('Parent ID retrieved: ' + parentId);
                } catch (Exception e) {
                    throw new GoogleDriveException(false, 'Failed to retrieve parent ID from the record: ' + e.getMessage());
                }
                
                if (String.isBlank(parentId)) {
                    system.debug('entro if String.isBlank(parentId)');
                    // Handle when parentId is null: use Folder_Drive_Id_Without_Parent__c
                    parentFolderId = metadataRecord.Folder_Drive_Id_Without_Parent__c;
                    if (String.isBlank(parentFolderId)) {
                        System.debug('No folder found for records without parent, creating a new one...');
                        
                        Google_Drive_Integration_Settings__c integrationSettings = [
                            SELECT Root_Folder_ID__c 
                            FROM Google_Drive_Integration_Settings__c 
                            WHERE Name = 'google services account' LIMIT 1
                        ];
                        
                        if (integrationSettings == null || integrationSettings.Root_Folder_ID__c == null) {
                            throw new GoogleDriveException(false, 'Root Folder ID not found in Google Drive Integration Settings.');
                        }
                        
                        String folderNameWithoutParent = metadataRecord.Folder_Drive_Name_Without_Parent__c;
                        createRootFolderResponse = GoogleDriveService.createGoogleDriveFolder(folderNameWithoutParent, integrationSettings.Root_Folder_ID__c);
                        
                        if (createRootFolderResponse.status) {
                            Map<String, Object> jsonResponseMap = (Map<String, Object>) JSON.deserializeUntyped(createRootFolderResponse.jsonResponse);
                            parentFolderId = (String) jsonResponseMap.get('id');
                            System.debug('New folder for records without parent created with ID: ' + parentFolderId);
                            
                            // Flag metadataRecord for update
                            metadataRecord.Folder_Drive_Id_Without_Parent__c = parentFolderId;
                            updateMetadataRecord = true;
                        } else {
                            throw new GoogleDriveException(false, 'Failed to create folder for records without parent in Google Drive.');
                        }
                    }
                } else {
                    
                    system.debug('parentId is not null');
                    // Logic for non-null parent
                    SObjectType parentObjType = Id.valueOf(parentId).getSObjectType();
                    String parentObjectName = parentObjType.getDescribe().getName();
                    
                    try {
                        parentMetadataRecord = [
                            SELECT Google_Drive_Folder_ID__c, Sub_Folder_Ids__c 
                            FROM Google_Drive_Mapping_Folder__c 
                            WHERE Salesforce_Object_ID__c = :parentId LIMIT 1
                        ];
                    } catch (Exception e) {
                        system.debug('entro catch  parentMetadataRecord = null');
                        parentMetadataRecord = null;
                    }
                    
                    system.debug('parentMetadataRecord 1: '+parentMetadataRecord);
                    
                    // If parentMetadataRecord is null, create folder based on parent object type
                    if (parentMetadataRecord == null || parentMetadataRecord.Google_Drive_Folder_ID__c == null) {
                        System.debug('No metadata found for parent record. Searching metadata by parent object type: ' + parentObjectName);
                        
                        // Look for metadata based on the parent object type
                        parentTypeMetadataRecord = [
                            SELECT Google_Drive_Folder_ID__c 
                            FROM Google_Drive_Mapping_Folder__c 
                            WHERE Object_Name__c = :parentObjectName LIMIT 1
                        ];
                        
                        // If no folder found for parent type, create one under the root folder
                        if (parentTypeMetadataRecord == null || parentTypeMetadataRecord.Google_Drive_Folder_ID__c == null) {
                            System.debug('No folder found for parent object type. Creating a new folder under the root for: ' + parentObjectName);
                            
                            // Retrieve the root folder ID from the integration settings
                            Google_Drive_Integration_Settings__c integrationSettings = [
                                SELECT Root_Folder_ID__c 
                                FROM Google_Drive_Integration_Settings__c 
                                WHERE Name = 'google services account' LIMIT 1
                            ];
                            
                            if (integrationSettings == null || integrationSettings.Root_Folder_ID__c == null) {
                                throw new GoogleDriveException(false, 'Root Folder ID not found in Google Drive Integration Settings.');
                            }
                            
                            // Create the folder in Google Drive for the parent object type
                            GoogleDriveResponse createParentTypeFolderResponse = GoogleDriveService.createGoogleDriveFolder(parentObjectName, integrationSettings.Root_Folder_ID__c);
                            
                            if (createParentTypeFolderResponse.status) {
                                Map<String, Object> jsonResponseMap = (Map<String, Object>) JSON.deserializeUntyped(createParentTypeFolderResponse.jsonResponse);
                                parentRecordFolderId = (String) jsonResponseMap.get('id');
                                System.debug('New folder created in Google Drive for parent object type with ID: ' + parentRecordFolderId);
                                
                                parentTypeMetadataRecord.Google_Drive_Folder_ID__c = parentRecordFolderId;
                                
                                // Flag to update parent type metadata later
                                updateParentTypeMetadata = true;
                                
                                // **Retrieve the name of the parent record to use as the folder name**
                                String parentRecordName;
                                try {
                                    SObject parentRecord = Database.query('SELECT Name FROM ' + parentObjectName + ' WHERE Id = :parentId LIMIT 1');
                                    parentRecordName = (String) parentRecord.get('Name');
                                    System.debug('Parent record name retrieved: ' + parentRecordName);
                                } catch (Exception e) {
                                    throw new GoogleDriveException(false, 'Failed to retrieve the Name field for the parent record: ' + e.getMessage());
                                }
                                
                                // **Now use the parent record name to create the folder**
                                GoogleDriveResponse createParentRecordFolderResponse = GoogleDriveService.createGoogleDriveFolder(parentRecordName, parentRecordFolderId);
                                
                                if (createParentRecordFolderResponse.status) {
                                    Map<String, Object> parentRecordFolderJsonResponseMap = (Map<String, Object>) JSON.deserializeUntyped(createParentRecordFolderResponse.jsonResponse);
                                    parentRecordFolderId = (String) parentRecordFolderJsonResponseMap.get('id');
                                    System.debug('Subfolder created for parent record in Google Drive with ID: ' + parentRecordFolderId);
                                    
                                    parentMetadataRecord= new Google_Drive_Mapping_Folder__c(
                                        Name = parentId,
                                        Salesforce_Object_ID__c = parentId,
                                        Google_Drive_Folder_ID__c = parentRecordFolderId
                                    );
                                    
                                    // Flag to insert new parent record metadata later
                                    insertParentMetadata = true;
                                } else {
                                    throw new GoogleDriveException(false, 'Failed to create subfolder for parent record in Google Drive.');
                                }
                            } else {
                                throw new GoogleDriveException(false, 'Failed to create folder for parent object type in Google Drive.');
                            }
                        }else{
                            parentRecordFolderId = parentTypeMetadataRecord.Google_Drive_Folder_ID__c;
                            
                            // **Retrieve the name of the parent record to use as the folder name**
                            String parentRecordName;
                            try {
                                SObject parentRecord = Database.query('SELECT Name FROM ' + parentObjectName + ' WHERE Id = :parentId LIMIT 1');
                                parentRecordName = (String) parentRecord.get('Name');
                                System.debug('Parent record name retrieved: ' + parentRecordName);
                            } catch (Exception e) {
                                throw new GoogleDriveException(false, 'Failed to retrieve the Name field for the parent record: ' + e.getMessage());
                            }
                            
                            // **Now use the parent record name to create the folder**
                            GoogleDriveResponse createParentRecordFolderResponse = GoogleDriveService.createGoogleDriveFolder(parentRecordName, parentRecordFolderId);
                            
                            if (createParentRecordFolderResponse.status) {
                                Map<String, Object> parentRecordFolderJsonResponseMap = (Map<String, Object>) JSON.deserializeUntyped(createParentRecordFolderResponse.jsonResponse);
                                parentRecordFolderId = (String) parentRecordFolderJsonResponseMap.get('id');
                                System.debug('Subfolder created for parent record in Google Drive with ID: ' + parentRecordFolderId);
                                
                                parentMetadataRecord= new Google_Drive_Mapping_Folder__c(
                                    Name = parentId,
                                    Salesforce_Object_ID__c = parentId,
                                    Google_Drive_Folder_ID__c = parentRecordFolderId
                                );
                                
                                // Flag to insert new parent record metadata later
                                insertParentMetadata = true;
                            } else {
                                throw new GoogleDriveException(false, 'Failed to create subfolder for parent record in Google Drive.');
                            }
                            
                        }
                    }else{
                        system.debug('parentMetadataRecord.Google_Drive_Folder_ID__c:'+parentMetadataRecord.Google_Drive_Folder_ID__c);
                        parentRecordFolderId =parentMetadataRecord.Google_Drive_Folder_ID__c;
                    }
                    
                    system.debug('parentMetadataRecord2: '+parentMetadataRecord);
                    
                    // Check if subfolder for the current object exists in parent's Sub_Folder_Ids__c
                    Map<String, String> subFolderIds = new Map<String, String>();
                    
                    if (!String.isBlank(parentMetadataRecord.Sub_Folder_Ids__c)) {
                        Map<String, Object> deserializedMap = (Map<String, Object>) JSON.deserializeUntyped(parentMetadataRecord.Sub_Folder_Ids__c);
                        for (String key : deserializedMap.keySet()) {
                            subFolderIds.put(key, (String) deserializedMap.get(key));
                        }
                    }
                        
                    if (subFolderIds.containsKey(objectName)) {
                        parentFolderId = subFolderIds.get(objectName);
                        System.debug('Subfolder for ' + objectName + ' already exists under parent with ID: ' + parentFolderId);
                    } else {
                        // **Apply Placeholder Logic for Sub_Folder_Name__c** here
                        System.debug('Placeholder: ' + metadataRecord.Sub_Folder_Name__c);
                        String subFolderName = processPlaceholders(metadataRecord.Sub_Folder_Name__c, recordId);
                        System.debug('Subfolder name: ' + subFolderName);
                        system.debug('parentRecordFolderId:'+parentRecordFolderId);
                        GoogleDriveResponse createParentSubFolderResponse = GoogleDriveService.createGoogleDriveFolder(subFolderName, parentRecordFolderId);
                        
                        if (createParentSubFolderResponse.status) {
                            Map<String, Object> subFolderJsonResponseMap = (Map<String, Object>) JSON.deserializeUntyped(createParentSubFolderResponse.jsonResponse);
                            parentFolderId = (String) subFolderJsonResponseMap.get('id');
                            System.debug('Subfolder created in Google Drive with ID: ' + parentFolderId);
                            
                            subFolderIds.put(objectName, parentFolderId);
                            parentMetadataRecord.Sub_Folder_Ids__c = JSON.serialize(subFolderIds);
                            updateParentMetadataRecord = true; // Flag for parent record update
                        } else {
                            throw new GoogleDriveException(false, 'Failed to create subfolder for ' + objectName + ' under parent.');
                        }
                    }
                }
            }
            
            // Step 8: Create the subfolder for the record
            try {
                SObject record = Database.query('SELECT Name FROM ' + objectName + ' WHERE Id = :recordId LIMIT 1');
                recordName = (String) record.get('Name');
                System.debug('Record Name retrieved: ' + recordName);
            } catch (Exception e) {
                throw new GoogleDriveException(false, 'Failed to retrieve the Name field for the record: ' + e.getMessage());
            }
            createSubFolderResponse = GoogleDriveService.createGoogleDriveFolder(recordName, parentFolderId);
            
            if (createSubFolderResponse.status) {
                Map<String, Object> subFolderJsonResponseMap = (Map<String, Object>) JSON.deserializeUntyped(createSubFolderResponse.jsonResponse);
                newSubFolderId = (String) subFolderJsonResponseMap.get('id');
                System.debug('Subfolder created in Google Drive with ID: ' + newSubFolderId);
                newSubFolderCreated = true;
            } else {
                throw new GoogleDriveException(false, 'Failed to create subfolder for the record.');
            }
            System.debug('isNewRootFolder: '+ isNewRootFolder);
            System.debug('updateMetadataRecord: '+ updateMetadataRecord);
            // Step 9: Perform all DML updates at the end
            if (isNewRootFolder || updateMetadataRecord) {
                update metadataRecord;
                System.debug('Updated metadata with new root folder ID: ' + parentFolderId);
            }
            if (newSubFolderCreated) {
                system.debug('the newSubFolderId into test is:  '+newSubFolderId);
                Google_Drive_Mapping_Folder__c newMapping = new Google_Drive_Mapping_Folder__c(
                    Name = recordId,
                    Salesforce_Object_ID__c = recordId,
                    Google_Drive_Folder_ID__c = newSubFolderId
                );
                insert newMapping;
                System.debug('New mapping created for recordId: ' + recordId + ' with Google Drive Folder ID: ' + newSubFolderId);
            }        
            System.debug('updateParentMetadataRecord: '+ updateParentMetadataRecord);           
            System.debug('insertParentMetadata: '+ insertParentMetadata);
            
            if (updateParentMetadataRecord && !insertParentMetadata) {
                update parentMetadataRecord;
                System.debug('Updated parent metadata with new subfolder ID for object: ' + objectName);
            }
            system.debug('updateParentTypeMetadata: '+ parentTypeMetadataRecord);
            
            if (updateParentTypeMetadata) {
                update parentTypeMetadataRecord;
                System.debug('Updated parent type metadata with new folder ID.');
            }  
            if (insertParentMetadata && parentId != null) {
                
                insert parentMetadataRecord;
                System.debug('Inserted new parent metadata with Google Drive Folder ID: ' + parentRecordFolderId);
            } 
            // Step 10: Return the folder details
            Map<String, String> folderDetails = new Map<String, String>{
                'idFolder' => newSubFolderId,
                    'nameFolder' => recordName
                    };
                        return folderDetails;
            
        } catch (Exception e) {   
            ErrorLoggingService.logError('Apex','Error',e,'GoogleDriveFolderService-getGoogleDriveFolderId');
            throw new AuraHandledException(e.getMessage()); 
        }
    }
    
    // Helper function to process placeholders in Sub_Folder_Name__c
    private static String processPlaceholders(String subFolderNameTemplate, String parentId) {
        Pattern placeholderPattern = Pattern.compile('\\{(.*?)\\}');
        Matcher matcher = placeholderPattern.matcher(subFolderNameTemplate);
        
        String finalSubFolderName = subFolderNameTemplate;
        system.debug('subFolderNameTemplate is: '+subFolderNameTemplate);
        
        while (matcher.find()) {
            String placeholder = matcher.group(1); // e.g., param_1_drive__c
            // Dynamically get the value for this placeholder from the parent record
            String dynamicFieldValue = getDynamicFieldValue(parentId, placeholder);
            System.debug('Dynamic field value for ' + placeholder + ': ' + dynamicFieldValue);
            system.debug('place holder is: '+ placeholder);
            System.debug('finalSubFolderName ' + finalSubFolderName);
            // Ensure parentheses around the dynamic field value
            String fieldValueWithParentheses = '(' + dynamicFieldValue + ')';
            System.debug('fieldValueWithParentheses: ' + fieldValueWithParentheses);
            // Replace the placeholder with the field value
            finalSubFolderName = finalSubFolderName.replace('{' + placeholder + '}', fieldValueWithParentheses);        
        }
        return finalSubFolderName;
    }
    
    // Helper method to fetch dynamic field values
    private static String getDynamicFieldValue(Id recordId, String fieldName) {
        SObjectType objType = Id.valueOf(recordId).getSObjectType();
        DescribeSObjectResult objDescribe = objType.getDescribe(); 
        String query = 'SELECT ' + fieldName + ' FROM ' + objDescribe.getName() + ' WHERE Id = :recordId LIMIT 1';
        SObject record = Database.query(query);
        return (String) record.get(fieldName);
    }
}
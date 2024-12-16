import { LightningElement, api, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import USER_ID_FIELD from '@salesforce/user/Id';
import deleteFileFromGoogleDrive from '@salesforce/apex/GoogleDriveService.deleteFileFromGoogleDrive';
import createFolderInGoogleDrive from '@salesforce/apex/GoogleDriveService.createFolderInGoogleDrive';       // Import the Apex method
import listGoogleDriveFilesByFolderId from '@salesforce/apex/GoogleDriveService.listGoogleDriveFilesByFolderId';
import getGoogleDriveFolderId from '@salesforce/apex/GoogleDriveFolderService.getGoogleDriveFolderId';
import checkIfFolderIsTrashed from '@salesforce/apex/GoogleDriveFolderService.checkIfFolderIsTrashed';

import uploadFileToGoogleDriveFolder from '@salesforce/apex/GoogleDriveService.uploadFileToGoogleDriveFolder';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'; // Importa ShowToastEvent


import customIcons from '@salesforce/resourceUrl/customIcons'; // Import the static resource

const FIELDS = ['User.Name'];

export default class RecordGoogleDriveFilesV2 extends LightningElement {
    @api recordId; // ID del registro del objeto (por ejemplo, Account)
    @track googleDriveFiles = [];
    @track isShowModal = true;
    @track message = ''; // Mensaje para mostrar errores u otra información

    @track breadcrumbs = []; // Para almacenar la ruta de navegación
    @track folderIdStack = []; // Para almacenar el historial de carpetas
    @track lastBreadcrumbIndex = -1; // Índice del último breadcrumb

    fileContent;
    fileName;
    mimeType;

    @track isModalOpen = false; // to control modal visibility
    @track newFileName = ''; // to hold the new file name
    @track isCreateDisabled = true; // to control create button state


    @track isDocsModalOpen = false; // to control Docs modal visibility
    @track newDocsFileName = ''; // to hold the new Docs file name
    @track isCreateDocsDisabled = true; // to control create button state for Docs

    @track isSlidesModalOpen = false; // to control Slides modal visibility
    @track isCreateSlidesDisabled = true; // to control create button state for Slides

    @track isCreateFolderModalOpen = false; // Control the visibility of the create folder modal
    @track newFolderName = ''; // Holds the name of the new folder
    @track isCreateFolderDisabled = true; // Controls the create folder button state


    // Define the full URL for the custom SVG icon
    customIconsUrl = `${customIcons}#custom-google-drive`;


    @track isUploadModalOpen = false;
    @track isFileSelected = false;
    @track selectedFileName = '';
    @track uploadProgress = 0;
    @track isUploadDisabled = true;


    @track sortedBy = 'formattedSize';
    @track sortedDirection = 'asc';



    @track isSizeAscending = true; // Default sorting order
    @track sizeSortIcon = 'utility:arrowup'; // Default sort icon (ascending)

    @track nameSortIcon = 'utility:arrowup'; // Default sort icon for Name
    @track modifiedSortIcon = 'utility:arrowup'; // Default sort icon for Last Modified
    @track isNameAscending = true; // Default sorting order for Name
    @track isModifiedAscending = true; // Default sorting order for Last Modified



    @track sortedColumn = null;
    @track isAscending = true;
    @track hoveredColumn = null;

    // Visibility classes for hover states
    @track nameSortVisibleClass = 'slds-hidden';
    @track modifiedSortVisibleClass = 'slds-hidden';
    @track sizeSortVisibleClass = 'slds-hidden';

    // Selected class for styling the sorted column with blue color
    @track nameSortSelectedClass = '';
    @track modifiedSortSelectedClass = '';
    @track sizeSortSelectedClass = '';

    @track isDocumentWizardOpen = false;
    @track currentFolderId = ''; // Assume the current folder ID is available

    @track selectedMimeType = 'application/vnd.google-apps.document'; // Default mimeType for Google Docs


    connectedCallback() {
        if (this.recordId) {
            // Llama al nuevo método para verificar si la carpeta está en "trashed"
            checkIfFolderIsTrashed({ recordId: this.recordId })
                .then(() => {
                    // Después de verificar, llama al método normal para obtener o crear la carpeta
                    this.getGoogleDriveFolderId();
                })
                .catch((error) => {
                    console.error('Error checking if folder is trashed:', error);
                    this.message = 'Error checking Google Drive folder status.';
                });
        } else {
            this.message = 'No record ID provided.';
        }
    }

    renderedCallback() {
        // When the Google Sheets modal is open, set focus to the file name input
        if (this.isModalOpen) {
            const inputField = this.template.querySelector('lightning-input[data-id="fileNameInput"]');
            if (inputField) {
                inputField.focus();
            }
        }

        // When the Google Docs modal is open, set focus to the file name input
        if (this.isDocsModalOpen) {
            const inputField = this.template.querySelector('lightning-input[data-id="fileNameInputDocs"]');
            if (inputField) {
                inputField.focus();
            }
        }

        // When the Google Slides modal is open, set focus to the file name input
        if (this.isSlidesModalOpen) {
            const inputField = this.template.querySelector('lightning-input[data-id="fileNameInputSlides"]');
            if (inputField) {
                inputField.focus();
            }
        }


        // When the Google Slides modal is open, set focus to the file name input
        if (this.isCreateFolderModalOpen) {
            const inputField = this.template.querySelector('lightning-input[data-id="folderNameInput"]');
            if (inputField) {
                inputField.focus();
            }
        }


    }




    // Handle column hover (show/hide icons)
    handleMouseOver(event) {
        const column = event.currentTarget.dataset.column;
        this.updateHoverIcons(column, true);
    }

    handleMouseOut(event) {
        const column = event.currentTarget.dataset.column;
        this.updateHoverIcons(column, false);
    }

    get nameSortClasses() {
        return `${this.nameSortVisibleClass} ${this.nameSortSelectedClass}`;
    }


    // En tu lógica donde se actualiza el nameSortVisibleClass
    updateHoverIcons(column, isHovered) {
        if (column === 'name') {
            // Añadimos la clase de margen directamente al valor de nameSortVisibleClass
            this.nameSortVisibleClass = isHovered || this.sortedColumn === 'name'
                ? 'slds-m-left_xx-small icon-hover-effect'
                : 'slds-hidden';
        } else if (column === 'modifiedTime') {
            this.modifiedSortVisibleClass = isHovered || this.sortedColumn === 'modifiedTime'
                ? 'slds-m-left_xx-small icon-hover-effect'
                : 'slds-hidden';
        } else if (column === 'size') {
            this.sizeSortVisibleClass = isHovered || this.sortedColumn === 'size'
                ? 'slds-m-left_xx-small icon-hover-effect'
                : 'slds-hidden';
        }
    }



    getGoogleDriveFolderId() {
        // Call the Apex method to get the Google Drive folder ID and name
        getGoogleDriveFolderId({ recordId: this.recordId })
            .then((folderDetails) => {
                // Check if the response contains the folder details
                if (folderDetails && folderDetails.idFolder && folderDetails.nameFolder) {
                    // Update breadcrumbs with the folder name and ID
                    this.breadcrumbs = [{ name: folderDetails.nameFolder, id: folderDetails.idFolder }];
                    this.folderIdStack = [folderDetails.idFolder]; // Initialize the folder history with the root folder ID

                    // Fetch and display the files within the folder
                    this.listFilesFromGoogleDrive(folderDetails.idFolder);

                    // Set a message indicating the folder ID
                    this.message = 'The folder ID is: ' + folderDetails.idFolder;
                } else {
                    // Set a message if no folder details are found
                    this.message = 'No Google Drive folder ID found for this record.';
                }
            })
            .catch((error) => {
                // Log and set an error message in case of failure
                console.error('Error retrieving Google Drive folder details:', error);
                this.message = 'Error retrieving Google Drive folder details.';
            });
    }



    listFilesFromGoogleDrive(folderId) {
        // Call the Apex method to list files in the Google Drive folder
        listGoogleDriveFilesByFolderId({ folderId })
            .then((files) => {
                // Map the response to add relevant properties and format size and modified date
                this.googleDriveFiles = files.map(file => ({
                    ...file,
                    isFolder: file.mimeType === 'application/vnd.google-apps.folder',
                    isGoogleDoc: file.mimeType === 'application/vnd.google-apps.document',
                    isGoogleSheet: file.mimeType === 'application/vnd.google-apps.spreadsheet',
                    isGoogleSlide: file.mimeType === 'application/vnd.google-apps.presentation',
                    isPDF: file.mimeType === 'application/pdf',
                    formattedSize: file.size !== 'N/A' ? this.formatFileSize(file.size) : 'N/A',
                    formattedModifiedTime: this.formatDate(file.modifiedTime),
                    owners: file.owners,
                }));
                this.updateBreadcrumbs(folderId); // Update breadcrumbs
            })
            .catch((error) => {
                this.message = 'Error listing Google Drive files.';
                console.error('Error listing Google Drive files:', error);
            });
    }

    formatFileSize(size) {
        const units = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
        let i = 0;
        let sizeInUnits = parseFloat(size);
        while (sizeInUnits >= 1024 && i < units.length - 1) {
            sizeInUnits /= 1024;
            i++;
        }
        return `${sizeInUnits.toFixed(2)} ${units[i]}`;
    }





    // Handle sorting for each column
    handleSortOld(event) {
        const column = event.currentTarget.dataset.column;

        if (this.sortedColumn === column) {
            this.isAscending = !this.isAscending;
        } else {
            this.sortedColumn = column;
            this.isAscending = true;
        }

        // Update icons based on sorted column
        this.updateSortIcons();

        // Perform sorting
        if (column === 'name') {
            this.googleDriveFiles.sort((a, b) => {
                const nameA = a.name.toLowerCase();
                const nameB = b.name.toLowerCase();
                return this.isAscending ? (nameA < nameB ? -1 : 1) : (nameA > nameB ? -1 : 1);
            });
        } else if (column === 'modifiedTime') {
            this.googleDriveFiles.sort((a, b) => {
                const dateA = new Date(a.modifiedTime);
                const dateB = new Date(b.modifiedTime);
                return this.isAscending ? dateA - dateB : dateB - dateA;
            });
        } else if (column === 'size') {
            this.googleDriveFiles.sort((a, b) => {
                const sizeA = parseFloat(a.size) || 0;
                const sizeB = parseFloat(b.size) || 0;
                return this.isAscending ? sizeA - sizeB : sizeB - sizeA;
            });
        }
    }

    handleSort(event) {
        const column = event.currentTarget.dataset.column;

        if (this.sortedColumn === column) {
            this.isAscending = !this.isAscending;
        } else {
            this.sortedColumn = column;
            this.isAscending = true;
        }

        // Update sort icons
        this.updateSortIcons();

        // Sort folders first, then files, and apply column-specific sorting
        this.googleDriveFiles.sort((a, b) => {
            // Prioritize folders over files
            if (a.isFolder !== b.isFolder) {
                return a.isFolder ? -1 : 1; // Folders come first
            }

            // Column-specific sorting
            if (column === 'name') {
                const nameA = a.name.toLowerCase();
                const nameB = b.name.toLowerCase();
                return this.isAscending ? (nameA < nameB ? -1 : 1) : (nameA > nameB ? -1 : 1);
            } else if (column === 'modifiedTime') {
                const dateA = new Date(a.modifiedTime);
                const dateB = new Date(b.modifiedTime);
                return this.isAscending ? dateA - dateB : dateB - dateA;
            } else if (column === 'size') {
                const sizeA = parseFloat(a.size) || 0;
                const sizeB = parseFloat(b.size) || 0;
                return this.isAscending ? sizeA - sizeB : sizeB - sizeA;
            }
        });
    }


    // Update sort icons based on the sorted column
    updateSortIcons() {
        // Reset all icons
        this.nameSortIcon = 'utility:arrowup';
        this.modifiedSortIcon = 'utility:arrowup';
        this.sizeSortIcon = 'utility:arrowup';

        // Reset visibility classes
        this.nameSortVisibleClass = 'slds-hidden';
        this.modifiedSortVisibleClass = 'slds-hidden';
        this.sizeSortVisibleClass = 'slds-hidden';

        // Set the correct icon and visibility for the sorted column
        if (this.sortedColumn === 'name') {
            this.nameSortIcon = this.isAscending ? 'utility:arrowup' : 'utility:arrowdown';
            this.nameSortVisibleClass = 'icon-hover-effect';
        } else if (this.sortedColumn === 'modifiedTime') {
            this.modifiedSortIcon = this.isAscending ? 'utility:arrowup' : 'utility:arrowdown';
            this.modifiedSortVisibleClass = 'icon-hover-effect';
        } else if (this.sortedColumn === 'size') {
            this.sizeSortIcon = this.isAscending ? 'utility:arrowup' : 'utility:arrowdown';
            this.sizeSortVisibleClass = 'icon-hover-effect';
        }
    }


    // Handle row actions like open or delete
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        switch (actionName) {
            case 'open':
                if (row.isFolder) {
                    this.handleFolderClick(row.id, row.name);
                } else {
                    this.handleOpenFile(row.id);
                }
                break;
            case 'delete':
                this.handleDeleteFile(row.id);
                break;
            default:
                break;
        }
    }


    formatDate(dateStr) {
        const date = new Date(dateStr);

        // Define month names to get the short format
        const months = [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];

        // Extract the month, day, and year
        const day = date.getDate();
        const month = months[date.getMonth()];
        const year = date.getFullYear();

        // Return the formatted date as "Sep 12, 2024"
        return `${month} ${day}, ${year}`;
    }

    handleCloseClick() {
        this.isShowModal = false;
    }

    handleOpenFile(event) {
        const fileId = event.target.dataset.id;
        const url = `https://drive.google.com/file/d/${fileId}/view`;
        window.open(url, '_blank');
    }





    async handleUploadFileOld() {
        try {
            const folderId = this.folderIdStack[this.folderIdStack.length - 1];
            console.log('folder id: ' + folderId);
            const result = await uploadFileToGoogleDriveFolder({
                fileName: this.fileName,
                mimeType: this.mimeType,
                base64Content: this.fileContent,
                folderId: folderId
            });
            this.responseMessage = result.message;
            this.showToast('Success', 'File uploaded successfully!', 'success');
            this.listFilesFromGoogleDrive(folderId); // Refresh the file list
        } catch (error) {
            this.responseMessage = 'Error: ' + error.body.message;
        }
    }


    handleFolderClickOld(event) {
        const folderId = event.target.dataset.id;
        if (folderId) {
            this.listFilesFromGoogleDrive(folderId);
            // Actualiza los breadcrumbs
            const index = this.breadcrumbs.findIndex(b => b.id === folderId);
            if (index >= 0) {
                this.breadcrumbs = this.breadcrumbs.slice(0, index + 1);
                this.folderIdStack = this.folderIdStack.slice(0, index + 1);
            }
        }
    }

    handleFolderClick(fileId, fileName) {
        if (fileId) {
            this.listFilesFromGoogleDrive(fileId);
            // Pass the folder ID and the actual folder name
            this.updateBreadcrumbs(fileId, fileName);
        }
    }

    handleBreadcrumbClick(event) {
        const folderId = event.target.dataset.id;
        const index = this.breadcrumbs.findIndex(b => b.id === folderId);
        if (index >= 0) {
            // Slice breadcrumbs up to the clicked one
            this.breadcrumbs = this.breadcrumbs.slice(0, index + 1);
            this.folderIdStack = this.folderIdStack.slice(0, index + 1);
            this.listFilesFromGoogleDrive(folderId);
        }
    }

    handleFileClick(event) {
        const fileId = event.target.dataset.id;
        const fileName = event.target.dataset.name;
        const isFolder = event.target.dataset.isFolder === 'true';

        if (isFolder) {
            // If it's a folder, handle folder click
            this.handleFolderClick(fileId, fileName);
        } else {
            // If it's a file, open the file
            this.handleOpenFile(event);
        }
    }


    updateBreadcrumbsOld(folderId, folderName) {
        // Check if the breadcrumb with this folderId already exists
        const existingIndex = this.breadcrumbs.findIndex(breadcrumb => breadcrumb.id === folderId);

        if (existingIndex !== -1) {
            // If it exists, trim the breadcrumbs up to the existing one
            this.breadcrumbs = this.breadcrumbs.slice(0, existingIndex + 1);
            this.folderIdStack = this.folderIdStack.slice(0, existingIndex + 1);
        } else {
            // Add the new breadcrumb with the actual folder name
            const newBreadcrumb = { id: folderId, name: folderName || 'Unnamed Folder', isLast: false };
            this.breadcrumbs = [...this.breadcrumbs, newBreadcrumb];
            this.folderIdStack.push(folderId);
        }

        // Update separator keys and mark the last breadcrumb
        this.breadcrumbs = this.breadcrumbs.map((breadcrumb, index) => {
            return { ...breadcrumb, separatorKey: `separator-${index}`, isLast: index === this.breadcrumbs.length - 1 };
        });

        // Update the last breadcrumb index
        this.lastBreadcrumbIndex = this.breadcrumbs.length - 1;
    }

    updateBreadcrumbs(folderId, folderName) {
        // Check if the breadcrumb with this folderId already exists
        const existingIndex = this.breadcrumbs.findIndex(breadcrumb => breadcrumb.id === folderId);

        if (existingIndex !== -1) {
            // If it exists, trim the breadcrumbs up to the existing one
            this.breadcrumbs = this.breadcrumbs.slice(0, existingIndex + 1);
            this.folderIdStack = this.folderIdStack.slice(0, existingIndex + 1);
        } else {
            // Add the new breadcrumb with the actual folder name and check if it's the last one
            const newBreadcrumb = {
                id: folderId,
                name: folderName || 'Unnamed Folder',
                isLast: false,
                className: 'breadcrumb-button slds-text-heading_medium' // Default class with slds-text-heading_medium
            };
            this.breadcrumbs = [...this.breadcrumbs, newBreadcrumb];
            this.folderIdStack.push(folderId);
        }

        // Update separator keys and mark the last breadcrumb
        this.breadcrumbs = this.breadcrumbs.map((breadcrumb, index) => {
            const isLast = index === this.breadcrumbs.length - 1;
            return {
                ...breadcrumb,
                separatorKey: `separator-${index}`,
                isLast,
                className: isLast ? 'breadcrumb-button slds-text-heading_medium slds-text-title_bold' : 'breadcrumb-button slds-text-heading_medium' // Add the className based on isLast
            };
        });

        // Update the last breadcrumb index
        this.lastBreadcrumbIndex = this.breadcrumbs.length - 1;
    }


    async handleDeleteFile(event) {
        const fileId = event.target.dataset.id; // Get the file ID from the data-id attribute
        try {
            const result = await deleteFileFromGoogleDrive({ fileId });
            this.showToast('Success', result.message, 'success');
            const currentFolderId = this.folderIdStack[this.folderIdStack.length - 1];
            this.listFilesFromGoogleDrive(currentFolderId);
        } catch (error) {
            this.responseMessage = 'Error deleting file: ' + error.body.message;
        }
    }

    async handleCreateTextFile() {
        const currentFolderId = this.folderIdStack[this.folderIdStack.length - 1];

        try {
            // Crear el archivo
            const createResult = await createTextFileInGoogleDriveFolder({ folderId: currentFolderId });

            if (createResult.status) {
                // Esperar a que la lista se actualice llamando al método Apex directamente
                const files = await listGoogleDriveFilesByFolderId({ folderId: currentFolderId });

                // Mapea la respuesta para agregar la propiedad isFolder y formatear el tamaño y la fecha modificada
                this.googleDriveFiles = files.map(file => ({
                    ...file,
                    isFolder: file.mimeType === 'application/vnd.google-apps.folder',
                    formattedSize: file.size !== 'N/A' ? this.formatFileSize(file.size) : 'N/A',
                    formattedModifiedTime: this.formatDate(file.modifiedTime)
                }));

                // Actualiza las migas de pan
                // this.updateBreadcrumbs(currentFolderId);

                // Mostrar el mensaje de éxito solo después de que la lista se haya actualizado
                this.showToast('Success', 'File created and list updated successfully!', 'success');
            } else {
                this.responseMessage = 'Error creating text file: ' + createResult.message;
                this.showToast('Error', 'Failed to create file.', 'error');
            }
        } catch (error) {
            this.responseMessage = 'Error creating text file: ' + error.body.message;
            this.showToast('Error', 'Failed to create file.', 'error');
        }
    }

    async handleCreateDocsFile() {
        const currentFolderId = this.folderIdStack[this.folderIdStack.length - 1];
        try {
            const createResult = await createDocsInGoogleDriveFolder({ folderId: currentFolderId });
            if (createResult.status) {
                // Mostrar el mensaje de éxito solo después de que la lista se haya actualizado
                this.showToast('Success', 'File created and list updated successfully!', 'success');
                // Esperar a que la lista se actualice llamando al método Apex directamente
                const files = await listGoogleDriveFilesByFolderId({ folderId: currentFolderId });

                // Mapea la respuesta para agregar la propiedad isFolder y formatear el tamaño y la fecha modificada
                this.googleDriveFiles = files.map(file => ({
                    ...file,
                    isFolder: file.mimeType === 'application/vnd.google-apps.folder',
                    formattedSize: file.size !== 'N/A' ? this.formatFileSize(file.size) : 'N/A',
                    formattedModifiedTime: this.formatDate(file.modifiedTime)
                }));

                // Actualiza las migas de pan
                // this.updateBreadcrumbs(currentFolderId);

            } else {

                this.responseMessage = 'Error creating text file: ' + createResult.message;
                this.showToast('Error', 'Failed to create file.', 'error');
            }
        } catch (error) {
            this.responseMessage = 'Error creating text file: ' + error.body.message;
            this.showToast('Error', 'Failed to create file.', 'error');
        }
    }

    async handleCreateSheetsFile() {
        const currentFolderId = this.folderIdStack[this.folderIdStack.length - 1];
        try {
            const createResult = await createSheetsFileInGoogleDrive({ folderId: currentFolderId });
            if (createResult.status) {

                // Esperar a que la lista se actualice llamando al método Apex directamente
                const files = await listGoogleDriveFilesByFolderId({ folderId: currentFolderId });

                // Mapea la respuesta para agregar la propiedad isFolder y formatear el tamaño y la fecha modificada
                this.googleDriveFiles = files.map(file => ({
                    ...file,
                    isFolder: file.mimeType === 'application/vnd.google-apps.folder',
                    formattedSize: file.size !== 'N/A' ? this.formatFileSize(file.size) : 'N/A',
                    formattedModifiedTime: this.formatDate(file.modifiedTime)
                }));

                // Mostrar el mensaje de éxito solo después de que la lista se haya actualizado
                this.showToast('Success', 'File created and list updated successfully!', 'success');

                // Actualiza las migas de pan
                // this.updateBreadcrumbs(currentFolderId);

            } else {

                this.responseMessage = 'Error creating text file: ' + createResult.message;
                this.showToast('Error', 'Failed to create file.', 'error');
            }
        } catch (error) {
            this.responseMessage = 'Error creating text file: ' + error.body.message;
            this.showToast('Error', 'Failed to create file.', 'error');
        }
    }

    // Create a new Sheets file and refresh the file list
    async createNewSheetsFile() {
        // Get the file name input field element
        const inputField = this.template.querySelector('lightning-input[data-id="fileNameInput"]');

        // Check if the file name is empty and display an error if it is
        if (!this.newFileName.trim()) {
            inputField.setCustomValidity('Please enter a file name.');
            inputField.reportValidity();
            return; // Stop execution if the file name is not valid
        } else {
            inputField.setCustomValidity('');
            inputField.reportValidity();
        }

        // Get the current folder ID from the folder stack to use as the parent folder
        const currentFolderId = this.folderIdStack[this.folderIdStack.length - 1];
        try {
            // Call the Apex method to create a new Sheets file with the specified file name and folder ID
            const createResult = await createSheetsFileInGoogleDrive({
                folderId: currentFolderId,
                fileName: this.newFileName // Pass the file name parameter
            });

            if (createResult.status) {



                // Extract the file ID from the response
                const fileId = createResult.fileId;


                // After successfully creating the file, update the file list
                const files = await listGoogleDriveFilesByFolderId({ folderId: currentFolderId });

                // Map the response to add the isFolder property and format size and modified time
                this.googleDriveFiles = files.map(file => ({
                    ...file,
                    isFolder: file.mimeType === 'application/vnd.google-apps.folder',
                    isGoogleDoc: file.mimeType === 'application/vnd.google-apps.document',
                    isGoogleSheet: file.mimeType === 'application/vnd.google-apps.spreadsheet',
                    isGoogleSlide: file.mimeType === 'application/vnd.google-apps.presentation',
                    isPDF: file.mimeType === 'application/pdf',
                    formattedSize: file.size !== 'N/A' ? this.formatFileSize(file.size) : 'N/A',
                    formattedModifiedTime: this.formatDate(file.modifiedTime)
                }));

                // Display a success message after the list has been updated
                this.showToast('Success', 'File created and list updated successfully!', 'success');
                this.closeModal(); // Close the modal after successful creation
                // Open the newly created Google Sheets document in a new window

                if (fileId) {
                    const fileUrl = `https://drive.google.com/file/d/${fileId}/view`;
                    window.open(fileUrl, '_blank');
                }

            } else {
                // Handle the error response if file creation fails
                this.responseMessage = 'Error creating Sheets file: ' + createResult.message;
                this.showToast('Error', 'Failed to create file in createNewSheetsFile.', 'error');
            }
        } catch (error) {
            // Handle any errors thrown during the file creation process
            this.responseMessage = 'Error creating Sheets file: ' + (error.body ? error.body.message : error.message);
            this.showToast('Error', 'Failed to create file catch.', 'error');
        }
    }


    async handleCreateSlidesFile() {
        const currentFolderId = this.folderIdStack[this.folderIdStack.length - 1];
        try {
            const createResult = await createSlidesInGoogleDriveFolder({ folderId: currentFolderId });
            if (createResult.status) {

                // Esperar a que la lista se actualice llamando al método Apex directamente
                const files = await listGoogleDriveFilesByFolderId({ folderId: currentFolderId });

                // Mapea la respuesta para agregar la propiedad isFolder y formatear el tamaño y la fecha modificada
                this.googleDriveFiles = files.map(file => ({
                    ...file,
                    isFolder: file.mimeType === 'application/vnd.google-apps.folder',
                    formattedSize: file.size !== 'N/A' ? this.formatFileSize(file.size) : 'N/A',
                    formattedModifiedTime: this.formatDate(file.modifiedTime)
                }));

                // Mostrar el mensaje de éxito solo después de que la lista se haya actualizado
                this.showToast('Success', 'File created and list updated successfully!', 'success');

                // Actualiza las migas de pan
                // this.updateBreadcrumbs(currentFolderId);

            } else {

                this.responseMessage = 'Error creating slide file: ' + createResult.message;
                this.showToast('Error', 'Failed to create file.', 'error');
            }
        } catch (error) {
            this.responseMessage = 'Error creating text file: ' + error.body.message;
            this.showToast('Error', 'Failed to create file.', 'error');
        }
    }

    handleRefreshFiles() {
        const currentFolderId = this.folderIdStack[this.folderIdStack.length - 1];
        if (currentFolderId) {
            this.listFilesFromGoogleDrive(currentFolderId);
        } else {
            this.responseMessage = 'No folder ID available to refresh files.';
        }
    }



    // Show the modal to create a new Sheets file
    showCreateFileModal() {
        this.isModalOpen = true;
    }

    // Close the modal
    closeModal() {
        this.isModalOpen = false;
        this.newFileName = ''; // clear the file name input
        this.isCreateDisabled = true; // disable the create button
    }

    // Show the modal to create a new Docs file
    showCreateDocsModal() {
        this.isDocsModalOpen = true;
    }

    // Close the Docs modal
    closeDocsModal() {
        this.isDocsModalOpen = false;
        this.newDocsFileName = ''; // clear the file name input
        this.isCreateDocsDisabled = true; // disable the create button
    }

    // Show the modal to create a new folder
    showCreateFolderModal() {
        this.isCreateFolderModalOpen = true;
    }

    // Close the modal
    closeCreateFolderModal() {
        this.isCreateFolderModalOpen = false;
        this.newFolderName = ''; // Clear the folder name input
        this.isCreateFolderDisabled = true; // Disable the create button
    }

    // Create a new folder and refresh the file list
    async createNewFolder() {
        const currentFolderId = this.folderIdStack[this.folderIdStack.length - 1]; // Get the current folder ID

        try {
            // Call the Apex method to create a new folder with the specified name and parent folder ID
            const createResult = await createFolderInGoogleDrive({
                folderId: currentFolderId,
                folderName: this.newFolderName
            });

            if (createResult.status) {
                // After successfully creating the folder, update the file list
                this.listFilesFromGoogleDrive(currentFolderId);

                // Display a success message after the list has been updated
                this.showToast('Success', 'Folder created successfully!', 'success');
                this.closeCreateFolderModal(); // Close the modal after successful creation
            } else {
                // Handle the error response if folder creation fails
                this.showToast('Error', 'Failed to create folder: ' + createResult.message, 'error');
            }
        } catch (error) {
            // Handle any errors thrown during the folder creation process
            this.showToast('Error', 'Failed to create folder: ' + (error.body ? error.body.message : error.message), 'error');
        }
    }

    async handleCreateFolder() {
        const currentFolderId = this.folderIdStack[this.folderIdStack.length - 1];
        try {
            const createResult = await createFolderInGoogleDrive();
            if (createResult.status) {

                // Esperar a que la lista se actualice llamando al método Apex directamente
                const files = await listGoogleDriveFilesByFolderId({ folderId: currentFolderId });

                // Mapea la respuesta para agregar la propiedad isFolder y formatear el tamaño y la fecha modificada
                this.googleDriveFiles = files.map(file => ({
                    ...file,
                    isFolder: file.mimeType === 'application/vnd.google-apps.folder',
                    formattedSize: file.size !== 'N/A' ? this.formatFileSize(file.size) : 'N/A',
                    formattedModifiedTime: this.formatDate(file.modifiedTime)
                }));

                // Mostrar el mensaje de éxito solo después de que la lista se haya actualizado
                this.showToast('Success', 'File created and list updated successfully!', 'success');

                // Actualiza las migas de pan
                // this.updateBreadcrumbs(currentFolderId);

            } else {

                this.responseMessage = 'Error creating text file: ' + createResult.message;
                this.showToast('Error', 'Failed to create file.', 'error');
            }
        } catch (error) {
            this.responseMessage = 'Error creating text file: ' + error.body.message;
            this.showToast('Error', 'Failed to create file.', 'error');
        }
    }


    // Handle changes in the folder name input field
    handleFolderNameChange(event) {
        this.newFolderName = event.target.value;

        // Enable the Create button only if the folder name is not empty
        this.isCreateFolderDisabled = this.newFolderName.trim() === '';

        // Validate the input and show the error message if the input is empty
        const inputField = this.template.querySelector('lightning-input[data-id="folderNameInput"]');
        if (this.newFolderName.trim() === '') {
            inputField.setCustomValidity('Please enter a folder name.');
        } else {
            inputField.setCustomValidity('');
        }
        inputField.reportValidity();
    }

    // Handle changes in the file name input field
    handleFileNameChange(event) {
        this.newFileName = event.target.value;

        // Enable the Create button only if the file name is not empty
        this.isCreateDisabled = this.newFileName.trim() === '';

        // Validate the input and show the error message if the input is empty
        const inputField = this.template.querySelector('lightning-input[data-id="fileNameInput"]');
        if (this.newFileName.trim() === '') {
            inputField.setCustomValidity('Please enter a file name.');
        } else {
            inputField.setCustomValidity('');
        }
        inputField.reportValidity();
    }


    // Handle changes in the file name input field for Docs
    handleDocsFileNameChange(event) {
        this.newDocsFileName = event.target.value;

        // Enable the Create button only if the file name is not empty
        this.isCreateDocsDisabled = this.newDocsFileName.trim() === '';

        // Validate the input and show the error message if the input is empty
        const inputField = this.template.querySelector('lightning-input[data-id="fileNameInputDocs"]');
        if (this.newDocsFileName.trim() === '') {
            inputField.setCustomValidity('Please enter a file name.');
        } else {
            inputField.setCustomValidity('');
        }
        inputField.reportValidity();
    }

    // Create a new Docs file and refresh the file list
    async createNewDocsFile() {
        const inputField = this.template.querySelector('lightning-input[data-id="fileNameInputDocs"]');

        if (!this.newDocsFileName.trim()) {
            inputField.setCustomValidity('Please enter a file name.');
            inputField.reportValidity();
            return;
        } else {
            inputField.setCustomValidity('');
            inputField.reportValidity();
        }

        const currentFolderId = this.folderIdStack[this.folderIdStack.length - 1];
        try {
            createDocsInGoogleDriveFolder
            const createResult = await createDocsInGoogleDriveFolder({
                folderId: currentFolderId,
                fileName: this.newDocsFileName
            });

            if (createResult.status) {
                // Extract the file ID from the response
                const fileId = createResult.fileId;
                const files = await listGoogleDriveFilesByFolderId({ folderId: currentFolderId });
                this.googleDriveFiles = files.map(file => ({
                    ...file,
                    isFolder: file.mimeType === 'application/vnd.google-apps.folder',
                    isGoogleDoc: file.mimeType === 'application/vnd.google-apps.document',
                    isGoogleSheet: file.mimeType === 'application/vnd.google-apps.spreadsheet',
                    isGoogleSlide: file.mimeType === 'application/vnd.google-apps.presentation',
                    isPDF: file.mimeType === 'application/pdf',
                    formattedSize: file.size !== 'N/A' ? this.formatFileSize(file.size) : 'N/A',
                    formattedModifiedTime: this.formatDate(file.modifiedTime)
                }));
                this.showToast('Success', 'Docs file created and list updated successfully!', 'success');
                this.closeDocsModal();
                // Open the newly created document in a new window
                if (fileId) {
                    const fileUrl = `https://docs.google.com/document/d/${fileId}/edit`;
                    window.open(fileUrl, '_blank');
                }
            } else {
                this.responseMessage = 'Error creating Docs file: ' + createResult.message;
                this.showToast('Error', 'Failed to create file.', 'error');
            }
        } catch (error) {
            this.responseMessage = 'Error creating Docs file: ' + (error.body ? error.body.message : error.message);
            this.showToast('Error', 'Failed to create file.', 'error');
        }
    }


    // Show the modal to create a new Slides file
    showCreateSlidesModal() {
        this.isSlidesModalOpen = true;
    }

    // Close the Slides modal
    closeSlidesModal() {
        this.isSlidesModalOpen = false;
        this.newSlidesFileName = ''; // clear the file name input
        this.isCreateSlidesDisabled = true; // disable the create button
    }

    // Handle changes in the file name input field for Slides
    handleSlidesFileNameChange(event) {
        this.newSlidesFileName = event.target.value;

        // Enable the Create button only if the file name is not empty
        this.isCreateSlidesDisabled = this.newSlidesFileName.trim() === '';

        // Validate the input and show the error message if the input is empty
        const inputField = this.template.querySelector('lightning-input[data-id="fileNameInputSlides"]');
        if (this.newSlidesFileName.trim() === '') {
            inputField.setCustomValidity('Please enter a file name.');
        } else {
            inputField.setCustomValidity('');
        }
        inputField.reportValidity();
    }


    // Create a new Slides file and refresh the file list
    async createNewSlidesFile() {
        const inputField = this.template.querySelector('lightning-input[data-id="fileNameInputSlides"]');

        if (!this.newSlidesFileName.trim()) {
            inputField.setCustomValidity('Please enter a file name.');
            inputField.reportValidity();
            return;
        } else {
            inputField.setCustomValidity('');
            inputField.reportValidity();
        }

        const currentFolderId = this.folderIdStack[this.folderIdStack.length - 1];
        try {
            const createResult = await createSlidesInGoogleDriveFolder({
                folderId: currentFolderId,
                fileName: this.newSlidesFileName
            });

            if (createResult.status) {
                // Extract the file ID from the response
                const fileId = createResult.fileId;
                const files = await listGoogleDriveFilesByFolderId({ folderId: currentFolderId });
                this.googleDriveFiles = files.map(file => ({
                    ...file,
                    isFolder: file.mimeType === 'application/vnd.google-apps.folder',
                    isGoogleDoc: file.mimeType === 'application/vnd.google-apps.document',
                    isGoogleSheet: file.mimeType === 'application/vnd.google-apps.spreadsheet',
                    isGoogleSlide: file.mimeType === 'application/vnd.google-apps.presentation',
                    isPDF: file.mimeType === 'application/pdf',
                    formattedSize: file.size !== 'N/A' ? this.formatFileSize(file.size) : 'N/A',
                    formattedModifiedTime: this.formatDate(file.modifiedTime)
                }));
                this.showToast('Success', 'Slides file created and list updated successfully!', 'success');
                this.closeSlidesModal();
                // Open the newly created Google Slides document in a new window
                if (fileId) {
                    const fileUrl = `https://drive.google.com/file/d/${fileId}/view`;
                    window.open(fileUrl, '_blank');
                }

            } else {
                this.responseMessage = 'Error creating Slides file: ' + createResult.message;
                this.showToast('Error', 'Failed to create file.', 'error');
            }
        } catch (error) {
            this.responseMessage = 'Error creating Slides file: ' + (error.body ? error.body.message : error.message);
            this.showToast('Error', 'Failed to create file.', 'error');
        }
    }

    // Handle click on Google Drive icon to open the last folder in the stack in a new tab
    handleOpenGoogleDrive() {
        // Get the last folder ID from the stack
        const currentFolderId = this.folderIdStack.length > 0
            ? this.folderIdStack[this.folderIdStack.length - 1]
            : null;

        if (currentFolderId) {
            // Construct the Google Drive URL with the folder ID
            const driveUrl = `https://drive.google.com/drive/folders/${currentFolderId}`;
            // Open the folder in a new browser tab
            window.open(driveUrl, '_blank');
        } else {
            this.message = 'Unable to open Google Drive folder: Folder ID not found.';
        }
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            this.selectedFileName = file.name;
            this.fileName = file.name;
            this.mimeType = file.type;
            this.isFileSelected = true;
            this.isUploadDisabled = false;

            // Read the file content as base64
            const reader = new FileReader();
            reader.onload = () => {
                const base64 = reader.result.split(',')[1];
                this.fileContent = base64;
                this.uploadProgress = 0; // Reset progress
                console.log('Base64 file content:', this.fileContent); // Agregar log para verificar el contenido base64
            };
            reader.readAsDataURL(file);
        }
    }


    async handleUploadFile() {
        try {
            // Show upload progress
            this.uploadProgress = 10; // Start at 10% to indicate upload started

            const folderId = this.folderIdStack[this.folderIdStack.length - 1];
            console.log('folder id: ' + folderId);

            // Call Apex method to upload the file
            const result = await uploadFileToGoogleDriveFolder({
                fileName: this.fileName,
                mimeType: this.mimeType,
                base64Content: this.fileContent,
                folderId: folderId
            });

            this.uploadProgress = 100; // Set progress to 100% on success
            this.responseMessage = result.message;
            this.showToast('Success', 'File uploaded successfully!', 'success');

            // Refresh the file list
            this.listFilesFromGoogleDrive(folderId);
            this.closeUploadModal();
        } catch (error) {
            this.uploadProgress = 0; // Reset progress on error
            this.responseMessage = 'Error: ' + (error.body ? error.body.message : error.message);
            this.showToast('Error', 'Error uploading file', 'error');
        }
    }

    handleUploadFinishedOld(event) {
        // Retrieve the list of uploaded files
        const uploadedFiles = event.detail.files;

        if (uploadedFiles.length > 0) {
            this.showToast('Success', `${uploadedFiles.length} file(s) uploaded successfully.`, 'success');

            // After file upload, refresh the list of files
            const currentFolderId = this.folderIdStack[this.folderIdStack.length - 1];
            this.listFilesFromGoogleDrive(currentFolderId);
        } else {
            this.showToast('Error', 'No files were uploaded.', 'error');
        }

        // Close the modal after upload
        this.closeUploadModal();
    }

    async handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;

        if (uploadedFiles.length > 0) {
            // Get the current folder ID from the stack
            const folderId = this.folderIdStack[this.folderIdStack.length - 1];
            console.log('Folder ID: ' + folderId);

            for (const file of uploadedFiles) {
                console.log('Processing file: ', file.name);

                // Get the documentId to fetch the file's contents in Apex or if you need to process it here
                const fileDocumentId = file.documentId;

                try {
                    // Get the file details using FileReader to read as Base64
                    const fileBlob = await this.getFileContent(fileDocumentId);
                    const base64Content = fileBlob.base64;
                    const mimeType = fileBlob.type;

                    console.log('Base64 Content:', base64Content);
                    console.log('MIME Type:', mimeType);

                    // Call the Apex method to upload the file to Google Drive
                    const result = await uploadFileToGoogleDriveFolder({
                        fileName: file.name,
                        mimeType: mimeType,
                        base64Content: base64Content,
                        folderId: folderId
                    });

                    if (result.status) {
                        this.showToast('Success', `File "${file.name}" uploaded to Google Drive successfully.`, 'success');
                    } else {
                        this.showToast('Error', `Failed to upload file "${file.name}" to Google Drive.`, 'error');
                    }
                } catch (error) {
                    console.error('Error uploading file to Google Drive: ', error);
                    this.showToast('Error', `Error uploading file "${file.name}" to Google Drive.`, 'error');
                }
            }

            // Refresh the file list after uploading all files
            this.listFilesFromGoogleDrive(folderId);
        } else {
            this.showToast('Error', 'No files were uploaded.', 'error');
        }

        // Close the modal after uploading files
        this.closeUploadModal();
    }

    // Helper method to retrieve file content as Base64
    getFileContent(documentId) {
        return new Promise((resolve, reject) => {
            const fileReader = new FileReader();
            fileReader.onload = () => {
                const base64Content = fileReader.result.split(',')[1];
                const mimeType = fileReader.result.match(/:(.*?);/)[1];
                resolve({ base64: base64Content, type: mimeType });
            };
            fileReader.onerror = (error) => reject(error);
            fileReader.readAsDataURL(documentId);
        });
    }



    openUploadModal() {
        this.isUploadModalOpen = true;
    }

    closeUploadModal() {
        this.isUploadModalOpen = false;
        this.isFileSelected = false;
        this.uploadProgress = 0;
        this.fileContent = null;
        this.fileName = '';
        this.mimeType = '';
        this.isUploadDisabled = true;
    }





    // Handle sorting by File Name
    handleSortByName() {
        this.isNameAscending = !this.isNameAscending;

        this.googleDriveFiles.sort((a, b) => {
            const nameA = a.name.toLowerCase();
            const nameB = b.name.toLowerCase();

            if (nameA < nameB) {
                return this.isNameAscending ? -1 : 1;
            }
            if (nameA > nameB) {
                return this.isNameAscending ? 1 : -1;
            }
            return 0;
        });

        // Update the sort icon based on the current sort order
        this.nameSortIcon = this.isNameAscending ? 'utility:arrowup' : 'utility:arrowdown';
    }

    // Handle sorting by Last Modified
    handleSortByLastModified() {
        this.isModifiedAscending = !this.isModifiedAscending;

        this.googleDriveFiles.sort((a, b) => {
            const dateA = new Date(a.modifiedTime);
            const dateB = new Date(b.modifiedTime);

            return this.isModifiedAscending ? dateA - dateB : dateB - dateA;
        });

        // Update the sort icon based on the current sort order
        this.modifiedSortIcon = this.isModifiedAscending ? 'utility:arrowup' : 'utility:arrowdown';
    }

    // Method to handle sorting by file size
    handleSortBySize() {
        // Toggle the sorting order
        this.isSizeAscending = !this.isSizeAscending;

        // Sort the googleDriveFiles array by file size
        this.googleDriveFiles.sort((a, b) => {
            const sizeA = parseFloat(a.size) || 0;
            const sizeB = parseFloat(b.size) || 0;


            // Determine sorting order based on isSizeAscending
            return this.isSizeAscending ? sizeA - sizeB : sizeB - sizeA;
        });

        // Update the sort icon based on the current sort order
        this.sizeSortIcon = this.isSizeAscending ? 'utility:arrowup' : 'utility:arrowdown';
    }

    // Method to open the DocumentWizard modal
    openDocumentWizard() {
        // Set current folder ID based on where the user is (e.g., from breadcrumbs or folder stack)
        this.currentFolderId = this.folderIdStack[this.folderIdStack.length - 1];
        this.isDocumentWizardOpen = true;
        this.selectedMimeType = 'application/vnd.google-apps.document';
    }

    // Method to open the DocumentWizard modal
    openDocumentspreadsheetWizard() {
        // Set current folder ID based on where the user is (e.g., from breadcrumbs or folder stack)
        this.currentFolderId = this.folderIdStack[this.folderIdStack.length - 1];
        this.isDocumentWizardOpen = true;
        this.selectedMimeType = 'application/vnd.google-apps.spreadsheet';
    }

    // Method to open the DocumentWizard modal
    openDocumentpresentationWizard() {
        // Set current folder ID based on where the user is (e.g., from breadcrumbs or folder stack)
        this.currentFolderId = this.folderIdStack[this.folderIdStack.length - 1];
        this.isDocumentWizardOpen = true;
        this.selectedMimeType = 'application/vnd.google-apps.presentation';
    }

    // Method to close the DocumentWizard modal
    closeDocumentWizard() {
        this.isDocumentWizardOpen = false;
    }

    // Method to handle the document creation event from the child component
    handleDocumentCreated(event) {
        const fileId = event.detail.fileId; // Retrieve the fileId from the event detail
        const fileUrl = `https://drive.google.com/file/d/${fileId}/view`;

        // Construct the edit URL based on the mimeType
        let editUrl = '';
        if (this.selectedMimeType === 'application/vnd.google-apps.document') {
            editUrl = `https://docs.google.com/document/d/${fileId}/edit`; // For Google Docs
        } else if (this.selectedMimeType === 'application/vnd.google-apps.spreadsheet') {
            editUrl = `https://docs.google.com/spreadsheets/d/${fileId}/edit`; // For Google Sheets
        } else if (this.selectedMimeType === 'application/vnd.google-apps.presentation') {
            editUrl = `https://docs.google.com/presentation/d/${fileId}/edit`; // For Google Slides
        } else if (this.selectedMimeType === 'application/vnd.google-apps.drawing') {
            editUrl = `https://docs.google.com/drawings/d/${fileId}/edit`; // For Google Drawings
        }

        // Open the newly created document in a new tab
        window.open(editUrl, '_blank');

        // Refresh the file list after creation
        const currentFolderId = this.folderIdStack[this.folderIdStack.length - 1];
        this.listFilesFromGoogleDrive(currentFolderId);

        // Close the modal
        this.closeDocumentWizard();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant, // Puede ser 'success', 'error', 'warning', etc.
            })
        );
    }
}
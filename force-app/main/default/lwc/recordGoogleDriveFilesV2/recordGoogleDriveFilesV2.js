import { LightningElement, api, track, wire } from 'lwc';
import createFolderInGoogleDrive from '@salesforce/apex/GoogleDriveService.createFolderInGoogleDrive';       // Import the Apex method
import listGoogleDriveFilesByFolderId from '@salesforce/apex/GoogleDriveService.listGoogleDriveFilesByFolderId';
import getGoogleDriveFolderId from '@salesforce/apex/GoogleDriveFolderService.getGoogleDriveFolderId';
import checkIfFolderIsTrashed from '@salesforce/apex/GoogleDriveFolderService.checkIfFolderIsTrashed';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'; // Importa ShowToastEvent
import customIcons from '@salesforce/resourceUrl/customIcons'; // Import the static resource



const FIELDS = ['User.Name'];

export default class RecordGoogleDriveFilesV2 extends LightningElement {
    @api recordId;
    @track googleDriveFiles = [];
    @track isShowModal = true;
    @track message = '';

    @track breadcrumbs = [];
    @track folderIdStack = [];
    @track lastBreadcrumbIndex = -1;

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
    @track errorMessages = [];


    connectedCallback() {
        if (this.recordId) {
            checkIfFolderIsTrashed({ recordId: this.recordId })
                .then((response) => {
                    if (response.status) {
                        this.getGoogleDriveFolderId();
                    } else {
                        this.errorMessages = [...this.errorMessages, response.message];
                    }
                })
                .catch((error) => {
                    let message = 'An unexpected error occurred.';
                    if (error.body && error.body.message) {
                        message = error.body.message;
                    }
                    this.showToast('Error', message, 'error');
                });
        } else {
            this.message = 'No record ID provided.';
        }
    }

    renderedCallback() {
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
                    this.errorMessages = [...this.errorMessages, folderDetails.message];
                }
            })
            .catch((error) => {
                let message = 'An unexpected error occurred.';
                if (error.body && error.body.message) {
                    message = error.body.message;
                }
                this.showToast('Error', message, 'error');
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
                let message = 'An unexpected error occurred.';
                if (error.body && error.body.message) {
                    message = error.body.message;
                }
                this.showToast('Error', message, 'error');
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

    handleOpenFile(event) {
        const fileId = event.target.dataset.id;
        const url = `https://drive.google.com/file/d/${fileId}/view`;
        window.open(url, '_blank');
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


    handleRefreshFiles() {
        const currentFolderId = this.folderIdStack[this.folderIdStack.length - 1];
        if (currentFolderId) {
            this.listFilesFromGoogleDrive(currentFolderId);
        } else {
            this.responseMessage = 'No folder ID available to refresh files.';
        }
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
            let message = 'An unexpected error occurred.';
            if (error.body && error.body.message) {
                message = error.body.message;
            }
            this.showToast('Error', message, 'error');
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

    // Open the upload modal (calls the method from the child component)
    openUploadModal() {
        this.currentFolderId = this.folderIdStack[this.folderIdStack.length - 1];
        this.template.querySelector('c-upload-files').openUploadModal();
    }

    // Handle file uploaded event
    handleFileUploaded() {
        // Refresh the file list after a file is uploaded
        this.listFilesFromGoogleDrive(this.currentFolderId);
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
                variant: variant,
                mode: 'sticky' // Mantiene el Toast visible hasta que el usuario lo cierre manualmente
            })
        );
    }
}
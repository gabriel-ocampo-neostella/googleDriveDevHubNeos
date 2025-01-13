import { LightningElement, api, track } from 'lwc';
import uploadFileToGoogleDriveFolder from '@salesforce/apex/GoogleDriveService.uploadFileToGoogleDriveFolder';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class UploadFiles extends LightningElement {
    @api folderId; // Current folder ID where the file will be uploaded
    @track isUploadModalOpen = false;
    @track isFileSelected = false;
    @track selectedFileName = '';
    @track uploadProgress = 0;
    @track isUploadDisabled = true;
    fileContent;
    fileName;
    mimeType;

    @api openUploadModal() {
        this.isUploadModalOpen = true;
    }

    closeUploadModal() {
        this.isUploadModalOpen = false;
        this.resetFileSelection();
    }

    resetFileSelection() {
        this.isFileSelected = false;
        this.uploadProgress = 0;
        this.fileContent = null;
        this.fileName = '';
        this.mimeType = '';
        this.isUploadDisabled = true;
    }

    handleFileChangeOld(event) {
        const file = event.target.files[0];
        if (file) {
            this.selectedFileName = file.name;
            this.fileName = file.name;
            this.mimeType = file.type;
            this.isFileSelected = true;
            this.isUploadDisabled = false;

            const reader = new FileReader();
            reader.onload = () => {
                const base64 = reader.result.split(',')[1];
                this.fileContent = base64;
                this.uploadProgress = 0;
            };
            reader.readAsDataURL(file);
        }
    }


    handleFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            const maxSize = 10 * 1024 * 1024; // 10 MB in bytes
            if (file.size > maxSize) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'File Too Large',
                    message: 'The selected file exceeds the 10 MB size limit. Please choose a smaller file.',
                    variant: 'error'
                }));
                this.resetFileSelection();
                return;
            }

            this.selectedFileName = file.name;
            this.fileName = file.name;
            this.mimeType = file.type;
            this.isFileSelected = true;
            this.isUploadDisabled = false;

            const reader = new FileReader();
            reader.onload = () => {
                const base64 = reader.result.split(',')[1];
                this.fileContent = base64;
                this.uploadProgress = 0;
            };
            reader.readAsDataURL(file);
        }
    }

    async handleUploadFile() {
        try {
            this.uploadProgress = 10;

            const result = await uploadFileToGoogleDriveFolder({
                fileName: this.fileName,
                mimeType: this.mimeType,
                base64Content: this.fileContent,
                folderId: this.folderId,
            });

            this.uploadProgress = 100;
            this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'File uploaded successfully!', variant: 'success', mode: 'sticky' }));

            this.closeUploadModal();

            // Notify parent to refresh files
            this.dispatchEvent(new CustomEvent('fileuploaded'));
        } catch (error) {
            this.uploadProgress = 0;
            this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Error uploading file', variant: 'error' }));
        }
    }
}

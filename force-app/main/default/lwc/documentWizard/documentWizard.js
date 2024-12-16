import { LightningElement, track, api } from 'lwc';
import listGoogleDriveTemplates from '@salesforce/apex/GoogleDriveService.listGoogleDriveTemplates';
import createGoogleDriveFileFolder from '@salesforce/apex/GoogleDriveService.createGoogleDriveFileFolder';
import cloneFile from '@salesforce/apex/GoogleDriveService.cloneFile';


export default class DocumentWizard extends LightningElement {
    @api folderId; // Parent will pass this value
    @api mimeType; // mimeType passed from the parent component

    @track isStepOne = true;
    @track isStepTwoNewDocument = false;
    @track isStepTwoTemplate = false;
    @track isStepThreeNaming = false;

    @track newDocumentName = '';
    @track isCreateDisabled = true; // Disable "Create" button if no document name

    @track clonedDocumentName = '';
    @track selectedTemplateId = '';
    @track isCloneDisabled = true; // Disable "Create" button if no cloned document name in step 3
    @track isTemplateDisabled = true; // Initially, the Next button is disabled in Step 2 (template selection)
    @track templateFiles = []; // Assume templates are fetched from Google Drive

    @track isSelectDisabled = true; // Initially, the Next button is disabled
    @track createNewDocumentClass = 'unselected-card';
    @track createFromTemplateClass = 'unselected-card';

    @track isLoading = false; // Track loading state for spinner
    @track isCloneLoading = false; // Track loading state for cloning spinner





    renderedCallback() {
        // Enfocar el campo de texto cuando se llega al paso 2A o al paso 3
        if (this.isStepTwoNewDocument) {
            const inputField = this.template.querySelector("[data-id='newDocumentInput']");
            if (inputField) {
                inputField.focus();
            }
        }
        if (this.isStepThreeNaming) {
            const inputField = this.template.querySelector("[data-id='clonedDocumentInput']");
            if (inputField) {
                inputField.focus(); // Enfoca el campo para el nombre del archivo clonado
            }
        }
    }

    // Handle card click to select an option
    handleCardClick(event) {
        const selectedCard = event.currentTarget.dataset.id;

        if (selectedCard === 'newDocument') {
            this.createNewDocumentClass = 'selected-card';
            this.createFromTemplateClass = 'unselected-card';
        } else if (selectedCard === 'fromTemplate') {
            this.createNewDocumentClass = 'unselected-card';
            this.createFromTemplateClass = 'selected-card';
        }

        this.isSelectDisabled = false; // Enable the Next button once a card is selected
    }

    // Handle the Next step
    handleNextStep() {
        if (this.createNewDocumentClass === 'selected-card') {
            this.isStepOne = false;
            this.isStepTwoNewDocument = true;
        } else if (this.createFromTemplateClass === 'selected-card') {
            this.isStepOne = false;
            this.isStepTwoTemplate = true;

            // Fetch the templates from Google Drive
            listGoogleDriveTemplates({ mimeType: this.mimeType })
                .then(result => {
                    this.templateFiles = result;
                })
                .catch(error => {
                    console.error('Error fetching Google Drive templates: ', error);
                });
        }
    }

    // Handle cancel action to close the modal
    handleCancel() {
        // Logic to close the modal (e.g., dispatch an event to the parent component)
        this.dispatchEvent(new CustomEvent('closemodal'));
    }

    // Go back to step one from any step
    goBackToStepOne() {
        this.isStepOne = true;
        this.isStepTwoNewDocument = false;
        this.isStepTwoTemplate = false;
        this.isTemplateDisabled = true;
    }

    // Step 2A: Handle Document Name input change
    handleDocumentNameChange(event) {
        this.newDocumentName = event.target.value;
        this.isCreateDisabled = this.newDocumentName === ''; // Disable "Create" if name is empty
    }

    // Step 2A: Create New Document
    async createNewDocument() {
        this.isLoading = true; // Show the spinner and disable the button
        try {
            // Call Apex to create the new document with the provided mimeType
            const response = await createGoogleDriveFileFolder({
                mimeType: this.mimeType,
                fileName: this.newDocumentName,
                folderId: this.folderId
            });

            // Emit event to the parent component to refresh the file list and close the modal
            this.dispatchEvent(new CustomEvent('documentcreated', { detail: { fileId: response.fileId } }));

            // Reset the wizard
            this.resetWizard();
        } catch (error) {
            console.error('Error creating the document:', error);
        } finally {
            this.isLoading = false; // Hide the spinner after the operation is complete
        }
    }

    // Step 2B: Select Template
    selectTemplateOld(event) {
        this.selectedTemplateId = event.target.value;
        this.isTemplateDisabled = false; // Enable the Next button when a template is selected
    }

    // Step 2B: Select Template
    selectTemplate(event) {
        const selectedTemplate = this.templateFiles.find(file => file.id === event.target.value);

        // If the selected template is a shortcut, use its targetId; otherwise, use its id
        this.selectedTemplateId = selectedTemplate.targetId || selectedTemplate.id;
        this.isTemplateDisabled = false; // Enable the Next button when a template is selected
    }


    // Step 2B: Proceed to Step 3 (Name the Cloned Document)
    goToNamingStep() {
        this.isStepTwoTemplate = false;
        this.isStepThreeNaming = true;
    }

    // Step 3: Handle Cloned Document Name input change
    handleClonedDocumentNameChange(event) {
        this.clonedDocumentName = event.target.value;
        this.isCloneDisabled = this.clonedDocumentName === ''; // Disable "Create" if name is empty
    }

    // Step 3: Clone the document
    async cloneDocument() {
        this.isCloneLoading = true; // Show the spinner and disable the button
        try {
            // Call Apex to clone the file and pass the folderId (parentId)
            const fileId = await cloneFile({
                fileId: this.selectedTemplateId,
                newFileName: this.clonedDocumentName,
                parentId: this.folderId
            });

            // Emit event to the parent component to refresh the file list and close the modal
            this.dispatchEvent(new CustomEvent('documentcreated', { detail: { fileId } }));

            // Reset the wizard
            this.resetWizard();
        } catch (error) {
            console.error('Error cloning the document:', error);
        } finally {
            this.isCloneLoading = false; // Hide the spinner after the operation is complete
        }
    }

    goBackToTemplateStep() {
        this.isStepTwoTemplate = true;
        this.isStepThreeNaming = false;

    }

    // Utility method to reset the wizard after an action
    resetWizard() {
        this.isStepOne = true;
        this.isStepTwoNewDocument = false;
        this.isStepTwoTemplate = false;
        this.isStepThreeNaming = false;
        this.newDocumentName = '';
        this.clonedDocumentName = '';
        this.isTemplateDisabled = true; // Reset the template selection
        this.isCreateDisabled = true; // Reset the "Create" button disabled state
        this.isCloneDisabled = true; // Reset the "Create" button disabled state for cloning
        this.isLoading = false; // Reset the loading state
        this.isCloneLoading = false;
    }
}
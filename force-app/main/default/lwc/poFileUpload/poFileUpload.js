import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import createLineItemsAndStartProcessing from '@salesforce/apex/POLineItemController.createLineItemsAndStartProcessing';
import getExistingLineItems from '@salesforce/apex/POLineItemController.getExistingLineItems';

const LOADING_MESSAGES = [
    'Reading document…',
    'Locating key fields…',
    'Extracting line items…',
    'Almost done…'
];

export default class PoFileExtractor extends LightningElement {
    @api recordId;

    showManualReviewModal = false;
    selectedRecordId;

    uploadedFiles = [];
    isLoading = false;
    loadingMessage = LOADING_MESSAGES[0];
    acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg'];
    loadingTimer;

    existingItemsRaw = [];
    isLoadingExisting = true;
    wiredExistingResult;

    @wire(getExistingLineItems, { opportunityId: '$recordId' })
    wiredItems(result) {
        this.wiredExistingResult = result;
        this.isLoadingExisting = !result.data && !result.error;
        if (result.data) {
            this.existingItemsRaw = result.data;
        } else if (result.error) {
            console.error('Error loading existing PO Line Items:', result.error);
        }
    }

    isMissing(value) {

        if (!value) {
            return true;
        }

        const val = value.trim().toLowerCase();

        return val.includes('not found')
            || val.includes('not mentioned')
            || val.includes('not available');

    }

    get isProcessDisabled() {
        return this.uploadedFiles.length === 0 || this.isLoading;
    }

    get hasFiles() {
        return this.uploadedFiles.length > 0;
    }

    get fileCountLabel() {
        return `${this.uploadedFiles.length} file${this.uploadedFiles.length > 1 ? 's' : ''} ready`;
    }

    get existingItemsCount() {
        return this.existingItemsRaw.length;
    }

    get hasExistingItems() {
        return this.existingItemsRaw.length > 0;
    }

    get existingItems() {

        return this.existingItemsRaw.map(item => {

            // Show Approval Status if available, otherwise show Processing Status
            const displayStatus =
                item.Approval_Status__c &&
                    item.Approval_Status__c !== 'None'
                    ? item.Approval_Status__c
                    : item.Status__c;

            // Show Review button only until the record is submitted for approval
            const showManualReview =
                item.Status__c === 'Manual Review Required' &&
                (
                    !item.Approval_Status__c ||
                    item.Approval_Status__c === 'None'
                );

            return {

                ...item,

                displayStatus,

                showManualReview,

                recordUrl: '/' + item.Id,

                formattedDate:
                    item.CreatedDate
                        ? new Date(item.CreatedDate).toLocaleDateString()
                        : '',

                badgeClass:
                    'badge ' + this.getBadgeClass(displayStatus)

            };

        });

    }

    handleManualReview(event) {

        this.selectedRecordId = event.currentTarget.dataset.id;

        this.showManualReviewModal = true;

    }

    handleModalClose() {

        this.showManualReviewModal = false;

        this.selectedRecordId = null;

    }

    handleReviewSuccess() {

        this.showManualReviewModal = false;
        this.selectedRecordId = null;

        refreshApex(this.wiredExistingResult)
            .catch(error => {
                console.error(error);
            });

    }

    getBadgeClass(status) {

        switch (status) {

            case 'Completed':
                return 'badge-completed';

            case 'Failed':
                return 'badge-failed';

            case 'Processing':
                return 'badge-processing';

            case 'Manual Review Required':
                return 'badge-review';

            case 'Submit for Approval':
                return 'badge-approval';

            default:
                return 'badge-queued';

        }

    }

    handleUploadFinished(event) {
        try {
            const files = event.detail.files;
            if (!files || files.length === 0) {
                this.showToast('Warning', 'No files were uploaded. Try again.', 'warning');
                return;
            }
            const newFiles = files.map((f) => ({ documentId: f.documentId, name: f.name }));
            this.uploadedFiles = [...this.uploadedFiles, ...newFiles];
            this.showToast('Success', `${files.length} file(s) uploaded successfully.`, 'success');
        } catch (err) {
            console.error('Upload handler error:', err);
            this.showToast('Error', 'Something went wrong reading the uploaded files.', 'error');
        }
    }

    handleProcessFiles() {
        if (this.uploadedFiles.length === 0) {
            this.showToast('Warning', 'Please upload at least one file first.', 'warning');
            return;
        }
        if (!this.recordId) {
            this.showToast('Error', 'Opportunity record context not found.', 'error');
            return;
        }

        this.isLoading = true;
        this.startLoadingMessageCycle();

        const docIds = this.uploadedFiles.map((f) => f.documentId);

        createLineItemsAndStartProcessing({
            opportunityId: this.recordId,
            contentDocumentIds: docIds
        })
            .then((result) => {
                this.stopLoadingMessageCycle();
                this.isLoading = false;
                this.showToast(
                    'Success',
                    `Processing started for ${result.length} file(s). Results will appear on the right shortly.`,
                    'success'
                );
                this.uploadedFiles = [];
                return refreshApex(this.wiredExistingResult);
            })
            .catch((error) => {
                this.stopLoadingMessageCycle();
                this.isLoading = false;
                console.error('Process Files error:', JSON.stringify(error));
                const message =
                    error?.body?.message || error?.message || 'Something went wrong while processing files.';
                this.showToast('Error', message, 'error');
            });
    }

    startLoadingMessageCycle() {
        let i = 0;
        this.loadingMessage = LOADING_MESSAGES[0];
        this.loadingTimer = setInterval(() => {
            i = (i + 1) % LOADING_MESSAGES.length;
            this.loadingMessage = LOADING_MESSAGES[i];
        }, 1400);
    }

    stopLoadingMessageCycle() {
        if (this.loadingTimer) {
            clearInterval(this.loadingTimer);
            this.loadingTimer = null;
        }
    }

    handleRemoveFile(event) {
        const idToRemove = event.currentTarget.dataset.id;
        this.uploadedFiles = this.uploadedFiles.filter((f) => f.documentId !== idToRemove);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant,
                mode: variant === 'error' ? 'sticky' : 'dismissable'
            })
        );
    }
}
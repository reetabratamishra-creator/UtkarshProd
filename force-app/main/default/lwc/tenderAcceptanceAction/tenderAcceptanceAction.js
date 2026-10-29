import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi'; // ADDED
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';

import getTenderInfo from '@salesforce/apex/TenderAcceptanceController.getTenderInfo';
import updateTenderChoice from '@salesforce/apex/TenderAcceptanceController.updateTenderChoice';
import getTenderUserChoices from '@salesforce/apex/TenderAcceptanceController.getTenderUserChoices';
import getAddressBookDetails from '@salesforce/apex/TenderHODController.getAddressBookDetails';
import getProjectOwners from '@salesforce/apex/TenderHODController.getProjectOwners';
import acceptParticipationDirect from '@salesforce/apex/TenderHODController.acceptParticipationDirect';

import HOD_COMMENTS from '@salesforce/schema/Tender__c.HOD_Comments__c';
import TENDER_STAGE from '@salesforce/schema/Tender__c.Tender_Stage__c';

const FIELDS = [TENDER_STAGE, HOD_COMMENTS]; // UPDATED — removed undefined imports


const ACCEPT_LABEL = 'Accept and participate';

const REJECTION_LABELS = [
    'Reject and Create Project',
    'Reject and Close'
];

const HOD_TRIGGER_VALUE = 'Review and resend for participation';

export default class TenderAcceptanceAction extends LightningElement {
    @api recordId;

    // Data
    showAcceptSection = false;
    pendingChoice = null;
    authorityId;
    authorityName;
    hodChoice;
    wiredTenderResult;
    choiceOptions = [];
    addressBookName;
    contactName;
    // UI
    acceptNotes = '';

    isProcessing = false;
    showModal = false;

    addressBookColumns = [
    { label: 'Name', fieldName: 'Name' },
    { label: 'Address', fieldName: 'Street__c' }, // ADJUST to real field names
    { label: 'City', fieldName: 'City__c' },
    { label: 'State', fieldName: 'State__c' },
    { label: 'Pincode', fieldName: 'PIN__c' }
];
addressBookData = [];

projectOwnerOptions = [];
selectedProjectOwnerId;

@wire(getProjectOwners, { tenderId: '$recordId', userListChoice: 'tender' })
wiredProjectOwners({ data, error }) {
    if (data) {
        this.projectOwnerOptions = data.map(o => ({ label: o.label, value: o.value }));
        console.log(JSON.stringify(data))
    } else if (error) {
        this.showToast('Error', this.reduceError(error), 'error');
    }
}

handleProjectOwnerChange(event) {
    this.selectedProjectOwnerId = event.detail.value;
}

get isResendScenario() {
    console.log(this.hodChoice);
    return this.hodChoice === HOD_TRIGGER_VALUE || this.hodChoice === 'Update Account Details';
}

@wire(getAddressBookDetails, { tenderId: '$recordId' })
wiredAddressBook({ data, error }) {
    if (data) {
        this.addressBookData = data;
    } else if (error) {
        this.showToast('Error', this.reduceError(error), 'error');
    }
}

get hasAddressBookData() {
    return this.addressBookData && this.addressBookData.length > 0;
}
    
    

    @wire(getTenderUserChoices)
wiredChoices({ data, error }) {
    if (data) {
        this.choiceOptions = data.map(value => ({
            label: value,
            value: value
        }));
    } else if (error) {
        this.showToast(
            'Error',
            this.reduceError(error),
            'error'
        );
    }
}
    // Rejection UI
    showRejectionReason = false;
    selectedChoice = null;
    rejectionReason = '';

    @wire(getRecord, {
    recordId: '$recordId',
    fields: FIELDS
})
tender;

    @wire(getTenderInfo, { recordId: '$recordId' })
    wiredTender(result) {
        this.wiredTenderResult = result;

        const { data, error } = result;

        if (data) {
            this.authorityId = data.authorityId;
            this.authorityName = data.authorityName;
            this.hodChoice = data.hodChoice;
             this.contactName = data.contactName;
            
        } else if (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        }
    }

        get showHodChoice() {
        return this.hodChoice && this.hodChoice.trim() !== '';
    }

    get contactDisplay() {
        return this.contactName || '-';
    }

    
    handleAcceptNotesChange(event) {
        this.acceptNotes = event.target.value;
    }

    get hodCommentList() {
        const raw = getFieldValue(this.tender.data, HOD_COMMENTS);
        if (!raw) return [];
        return raw
            .split('\n')
            .filter(c => c.trim() !== '')
            .map((text, i) => ({ key: `hod-${i}-${text}`, text }));
    }

    get addressBookDisplay() {
        return this.addressBookName || '-';
    }

    get displayedChoiceOptions() {
    let options = this.choiceOptions;

    if (
        (this.hodChoice === HOD_TRIGGER_VALUE || this.hodChoice === 'Update Account Details')&&
        this.choiceOptions.length > 0
    ) {
        options = [this.choiceOptions[0]];
    }

    return options.map(opt => ({
        ...opt,
        variant: this.selectedChoice === opt.value ? 'brand' : 'neutral'
    }));
    }

    get isButtonsDisabled() {
        return this.isProcessing;
    }

    handleDynamicChoiceClick(event) {
    this.showModal = false;

    const value = event.target.dataset.value;
    this.selectedChoice = value;
    const opt = this.choiceOptions.find(o => o.value === value);

    if (!opt) {
        return;
    }

    // Reset sections
    this.showAcceptSection = false;
    this.showRejectionReason = false;
    this.rejectionReason = '';
    this.pendingChoice = null;

    // Accept
    if (opt.label === ACCEPT_LABEL) {
        this.pendingChoice = value;
        this.showAcceptSection = true;
        return;
    }

    // Reject
    if (REJECTION_LABELS.includes(opt.label)) {
        this.selectedChoice = value;
        this.showRejectionReason = true;
        return;
    }

    // Other choices
    this.submitChoice(value);
}

handleAcceptSubmit() {
    if (!this.authorityId) {
        this.showModal = true;
        return;
    }
    const notesInput = this.template.querySelector('lightning-textarea');
    if (!notesInput.checkValidity()) {
        notesInput.reportValidity();
        return;
    }

    if (this.isResendScenario && !this.selectedProjectOwnerId) {
        this.showToast('Missing info', 'Please select a Project Owner.', 'warning');
        return;
    }

    this.showModal = false;

    if (this.isResendScenario) {
        this.submitDirectAccept();
    } else {
        this.submitChoice(this.pendingChoice, this.acceptNotes);
    }
}

submitDirectAccept() {
    this.isProcessing = true;

    acceptParticipationDirect({
        tenderId: this.recordId,
        projectOwnerId: this.selectedProjectOwnerId,
        notes: this.acceptNotes
    })
        .then(() => {
            this.showToast('Success', 'Accepted and Opportunity created.', 'success');
            this.showAcceptSection = false;
            this.pendingChoice = null;
            this.acceptNotes = '';
            this.selectedProjectOwnerId = null;
            return refreshApex(this.wiredTenderResult);
        })
        .then(() => {
            this.dispatchEvent(new CloseActionScreenEvent());
            setTimeout(() => {
                window.location.href = '/' + this.recordId;
            }, 500);
        })
        .catch((error) => {
            this.showToast('Error', this.reduceError(error), 'error');
        })
        .finally(() => {
            this.isProcessing = false;
        });
}

    handleCancelModal() {
        this.showModal = false;
    }

    handleReasonChange(event) {
        this.rejectionReason = event.target.value;
    }

    handleRejectCancel() {
         this.showAcceptSection = false;
        this.showRejectionReason = false;
        this.selectedChoice = null;
        this.rejectionReason = '';
    }

    handleRejectSubmit() {
        if (!this.rejectionReason.trim()) {
            this.showToast(
                'Error',
                'Please enter a rejection reason.',
                'error'
            );
            return;
        }

        this.submitChoice(
            this.selectedChoice,
            this.rejectionReason
            
        );
    }

    submitChoice(choiceValue, rejectionReason = null) {
        if (!choiceValue) {
            this.showToast(
                'Error',
                'Choice value not loaded yet, please try again.',
                'error'
            );
            return;
        }

        this.isProcessing = true;

        updateTenderChoice({
            tenderId: this.recordId,
            choice: choiceValue,
            rejectionReason: rejectionReason
        })
            .then(() => {
                this.showToast(
                    'Success',
                    `Updated: ${choiceValue}`,
                    'success'
                );

                this.showAcceptSection = false;
                this.pendingChoice = null;

                this.showRejectionReason = false;
                this.selectedChoice = null;
                this.rejectionReason = '';
                this.acceptNotes = '';

                return refreshApex(this.wiredTenderResult);
            })
            .then(() => {
                //this.dispatchEvent(new RefreshEvent());
                this.dispatchEvent(new CloseActionScreenEvent());
                setTimeout(() => {
                window.location.href = '/' + this.recordId;
            }, 500);
            })
            .catch(error => {
                this.showToast(
                    'Error',
                    this.reduceError(error),
                    'error'
                );
            })
            .finally(() => {
                this.isProcessing = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    reduceError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }

        if (error?.message) {
            return error.message;
        }

        return 'Unknown error';
    }
}
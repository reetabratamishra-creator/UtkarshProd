import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getTenderInfo from '@salesforce/apex/TenderAcceptanceController.getTenderInfo';
import getContactsForAccount from '@salesforce/apex/TenderAcceptanceController.getContactsForAccount';
import createContact from '@salesforce/apex/TenderAcceptanceController.createContact';
import updateTenderChoice from '@salesforce/apex/TenderAcceptanceController.updateTenderChoice';

// ---- Config: adjust these to match your picklist values / trigger value ----
const CHOICE_SEND_FOR_PARTICIPATION = 'Send for Tender Participation';
const CHOICE_REJECT_CREATE_PROJECT = 'Reject and create project';
const CHOICE_REJECT_CLOSE = 'Reject and close';
const HOD_TRIGGER_VALUE = 'X'; // <-- swap this out for the real value later
const NEW_CONTACT_OPTION = '__NEW_CONTACT__';
// -----------------------------------------------------------------------------

export default class TenderAcceptanceActions extends LightningElement {
    @api recordId;

    // data from Apex
    authorityId;
    authorityName;
    wiredTenderResult;

    // ui state
    isProcessing = false;
    showModal = false;
    modalStep = ''; // 'account' | 'contact' | 'noAccount'
    hasAutoTriggered = false;

    // contact step state
    contactOptions = [];
    selectedContactValue;
    showCreateForm = false;
    newContact = { firstName: '', lastName: '', email: '', phone: '' };

    @wire(getTenderInfo, { recordId: '$recordId' })
    wiredTender(result) {
        this.wiredTenderResult = result;
        const { data, error } = result;
        if (data) {
            this.authorityId = data.authorityId;
            this.authorityName = data.authorityName;

            // Auto-trigger Button A's flow if HOD_choice__c matches the trigger value
            if (!this.hasAutoTriggered && data.hodChoice === HOD_TRIGGER_VALUE) {
                this.hasAutoTriggered = true;
                this.startAcceptanceFlow();
            }
        } else if (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        }
    }

    // ---------- Button visibility / disabled state ----------
    get isButtonsDisabled() {
        // "not all at once": while modal is open or a call is in flight, disable everything
        return this.showModal || this.isProcessing;
    }

    // ---------- Button click handlers ----------
    handleButtonAClick() {
        this.startAcceptanceFlow();
    }

    handleButtonRejectProjectClick() {
        this.submitSimpleChoice(CHOICE_REJECT_CREATE_PROJECT);
    }

    handleButtonRejectCloseClick() {
        this.submitSimpleChoice(CHOICE_REJECT_CLOSE);
    }

    // ---------- Button A flow ----------
    startAcceptanceFlow() {
        if (!this.authorityId) {
            this.modalStep = 'noAccount';
            this.showModal = true;
            return;
        }
        this.modalStep = 'account';
        this.showModal = true;
    }

    handleAccountContinue() {
        this.isProcessing = true;
        this.modalStep = 'contact';
        this.selectedContactValue = undefined;
        this.showCreateForm = false;
        this.newContact = { firstName: '', lastName: '', email: '', phone: '' };

        getContactsForAccount({ accountId: this.authorityId })
            .then((contacts) => {
                const options = contacts.map((c) => ({
                    label: `${c.Name}${c.Email ? ' (' + c.Email + ')' : ''}`,
                    value: c.Id
                }));
                options.push({ label: '+ Create New Contact', value: NEW_CONTACT_OPTION });
                this.contactOptions = options;
            })
            .catch((error) => {
                this.showToast('Error', this.reduceError(error), 'error');
            })
            .finally(() => {
                this.isProcessing = false;
            });
    }

    handleContactSelectionChange(event) {
        this.selectedContactValue = event.detail.value;
        this.showCreateForm = this.selectedContactValue === NEW_CONTACT_OPTION;
    }

    handleNewContactFieldChange(event) {
        const field = event.target.dataset.field;
        this.newContact = { ...this.newContact, [field]: event.target.value };
    }

    handleConfirmContact() {
        if (!this.selectedContactValue) {
            this.showToast('Missing info', 'Please select a contact or choose to create a new one.', 'warning');
            return;
        }

        if (this.showCreateForm) {
            if (!this.newContact.lastName) {
                this.showToast('Missing info', 'Last Name is required to create a new Contact.', 'warning');
                return;
            }
            this.isProcessing = true;
            createContact({
                firstName: this.newContact.firstName,
                lastName: this.newContact.lastName,
                email: this.newContact.email,
                phone: this.newContact.phone,
                accountId: this.authorityId
            })
                .then((newContactId) => this.finalizeAcceptance(newContactId))
                .catch((error) => {
                    this.isProcessing = false;
                    this.showToast('Error', this.reduceError(error), 'error');
                });
        } else {
            this.finalizeAcceptance(this.selectedContactValue);
        }
    }

    finalizeAcceptance(contactId) {
        this.isProcessing = true;
        updateTenderChoice({
            tenderId: this.recordId,
            choice: CHOICE_SEND_FOR_PARTICIPATION,
            contactId: contactId
        })
            .then(() => {
                this.showToast('Success', 'Tender sent for participation.', 'success');
                this.closeModal();
                return refreshApex(this.wiredTenderResult);
            })
            .catch((error) => {
                this.showToast('Error', this.reduceError(error), 'error');
            })
            .finally(() => {
                this.isProcessing = false;
            });
    }

    // ---------- Button 2 / 3: simple status updates, no popup ----------
    submitSimpleChoice(choiceValue) {
        this.isProcessing = true;
        updateTenderChoice({
            tenderId: this.recordId,
            choice: choiceValue,
            contactId: null
        })
            .then(() => {
                this.showToast('Success', `Updated: ${choiceValue}`, 'success');
                return refreshApex(this.wiredTenderResult);
            })
            .catch((error) => {
                this.showToast('Error', this.reduceError(error), 'error');
            })
            .finally(() => {
                this.isProcessing = false;
            });
    }

    // ---------- Modal helpers ----------
    closeModal() {
        this.showModal = false;
        this.modalStep = '';
        this.selectedContactValue = undefined;
        this.showCreateForm = false;
    }

    handleCancelModal() {
        this.closeModal();
    }

    get isStepAccount() {
        return this.modalStep === 'account';
    }
    get isStepContact() {
        return this.modalStep === 'contact';
    }
    get isStepNoAccount() {
        return this.modalStep === 'noAccount';
    }

    // ---------- Utilities ----------
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'Unknown error';
    }
}
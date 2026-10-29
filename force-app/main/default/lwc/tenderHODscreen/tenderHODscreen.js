import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import getProjectOwners from '@salesforce/apex/TenderHODController.getProjectOwners';
import processChoice from '@salesforce/apex/TenderHODController.processChoice';
 import getTenderAccount from '@salesforce/apex/TenderHODController.getTenderAccount';
import TENDER_USER_CHOICE from '@salesforce/schema/Tender__c.Tender_User_Choice__c';
import HOD_COMMENTS from '@salesforce/schema/Tender__c.HOD_Comments__c';       // ADDED
import TENDER_USER_COMMENTS from '@salesforce/schema/Tender__c.Comments__c';
import getAddressBookDetails from '@salesforce/apex/TenderHODController.getAddressBookDetails';

import TENDER_STAGE from '@salesforce/schema/Tender__c.Tender_Stage__c';
const FIELDS = [TENDER_USER_CHOICE, TENDER_STAGE, HOD_COMMENTS, TENDER_USER_COMMENTS]; 





export default class TenderHODscreen extends LightningElement {

    addressBookColumns = [
    { label: 'Name', fieldName: 'Name' },
    { label: 'Address', fieldName: 'Street__c' },
    { label: 'City', fieldName: 'City__c' },
    { label: 'State', fieldName: 'State__c' },
    { label: 'Pincode', fieldName: 'PIN__c' }
];


   



    userListchoice;
    accountDetails;
    @api recordId;
    submitDisabled = false;
    secondStep = false;
    showDetails = false;  
    rejectReason = '';
    selectedAction;
    projectOwnerOptions = [];
    selectedProjectOwner;

  
        addressBookData = [];

    @wire(getAddressBookDetails, { tenderId: '$recordId' })
    wiredAddressBook({ data }) {
        if (data) this.addressBookData = data;
    }
    

    @wire(getRecord, {
        recordId: '$recordId',
        fields: FIELDS
    })
    tender;

    get tenderUserChoice() {
        return getFieldValue(this.tender.data, TENDER_USER_CHOICE);
    }

    handleReason(event) {
        this.rejectReason = event.target.value;
    }
    
    @wire(getTenderAccount, { tenderId: '$recordId' })
    wiredAccount({ data }) {
        if (data) this.accountDetails = data;
    }

    get showAccountDetails() {
        return this.tenderUserChoice === 'Accept and participate' && this.accountDetails;
    }

    get hodCommentList() {
    const raw = getFieldValue(this.tender.data, HOD_COMMENTS);
    if (!raw) return [];
    return raw
        .split('\n')
        .filter(c => c.trim() !== '')
        .map((text, i) => ({ key: `hod-${i}-${text}`, text }));
}

get tenderUserCommentList() {
    const raw = getFieldValue(this.tender.data, TENDER_USER_COMMENTS);
    if (!raw) return [];
    return raw
        .split('\n')
        .filter(c => c.trim() !== '')
        .map((text, i) => ({ key: `tu-${i}-${text}`, text }));
}


    handleButtonClick(event) {

        const value = event.target.dataset.value;

        // ---------- Initial Screen ----------
        if (!this.secondStep) {

            if (value === 'REJECT') {
                this.secondStep = true;
                this.selectedAction = null;
                return;
            }

            if (value === 'APPROVE') {
                this.showDetails = true;

                switch (this.tenderUserChoice) {

                    case 'Accept and participate':
                        this.selectedAction = 'APPROVE_PARTICIPATION';
                        this.userListchoice='tender';
                        this.loadProjectOwners();
                        break;

                    case 'Reject and Create Project':
                        this.selectedAction = 'CREATE_PROJECT';
                        this.userListchoice='project';
                        this.loadProjectOwners();
                        break;

                    case 'Reject and Close':
                        this.selectedAction = 'CLOSE_TENDER';
                        break;
                }

                return;
            }
        }

        // ---------- Second Screen ----------
        this.selectedAction = value;
        this.showDetails = true;
        if (value === 'CREATE_PROJECT') {
            this.userListchoice='project';
            this.loadProjectOwners();
        }
    }

    handleSubmit() {
        const notesInput = this.template.querySelector('lightning-textarea');

    if (!notesInput.checkValidity()) {
        notesInput.reportValidity();
        return;
    }
        this.save();
    }


    loadProjectOwners() {
    getProjectOwners({ tenderId: this.recordId, userListChoice:this.userListchoice })
        .then(result => {
            this.projectOwnerOptions = result;
        })
        .catch(error => {
            console.error(error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Unable to load project owners.',
                    variant: 'error'
                })
            );
        });
    }


        handleProjectOwner(event) {
            this.selectedProjectOwner = event.detail.value;
        }

    get isSubmitDisabled() {

    if (this.submitDisabled) {
        return true;
    }

    if (!this.selectedAction) {
        return true;
    }

    if (
        (
            this.selectedAction === 'CREATE_PROJECT' ||
            this.selectedAction === 'APPROVE_PARTICIPATION'
        ) &&
        !this.selectedProjectOwner
    ) {
        return true;
    }

    return false;
    }

    get showProjectOwner() {
    return this.selectedAction === 'CREATE_PROJECT'||this.selectedAction === 'APPROVE_PARTICIPATION';
    }

    get displayedButtons() {

        let buttons = [];

        // ---------- Initial ----------
        if (!this.secondStep) {

            buttons = [
                {
                    label: 'Approve',
                    value: 'APPROVE'
                },
                {
                    label: 'Reject',
                    value: 'REJECT'
                }
            ];
        }

        // ---------- Tender User = Accept and participate ----------
        else if (this.tenderUserChoice === 'Accept and participate') {

            buttons = [
                {
                    label: 'Reject and Create Project',
                    value: 'CREATE_PROJECT'
                },
                {
                    label: 'Reject and Close',
                    value: 'CLOSE_TENDER'
                },
                /*{
                    label: 'Update Account Details',
                    value: 'UPDATE_ACCOUNT'
                }*/
            ];
        }

        // ---------- Tender User = Reject and Create Project ----------
        else if (this.tenderUserChoice === 'Reject and Create Project') {

            buttons = [
                {
                    label: 'Reject and Close',
                    value: 'CLOSE_TENDER'
                },
                {
                    label: 'Accept and Participate',
                    value: 'SEND_BACK_TO_PARTICIPATE'
                }
            ];
        }

        // ---------- Tender User = Reject and Close ----------
        else {

            buttons = [
                {
                    label: 'Reject and Create Project',
                    value: 'CREATE_PROJECT'
                },
                {
                    label: 'Accept and Participate',
                    value: 'SEND_BACK_TO_PARTICIPATE'
                }
            ];
        }

        return buttons.map(button => ({
            ...button,
            variant: (button.value === 'APPROVE' && this.selectedAction) || this.selectedAction === button.value ? 'brand' : 'neutral'
        }));
    }

    save() {

    this.submitDisabled = true;

        processChoice({
            tenderId: this.recordId,
            action: this.selectedAction,
            rejectReason: this.rejectReason,
            projectOwnerId: this.selectedProjectOwner
        })
        .then(() => {

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Tender processed successfully.',
                    variant: 'success'
                })
            );
            //this.dispatchEvent(new RefreshEvent());
            this.dispatchEvent(new CloseActionScreenEvent());
             setTimeout(() => {
                window.location.href = '/' + this.recordId;
            }, 500);

            // Refresh the record page
            

        })
        .catch(error => {

            this.submitDisabled = false;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Something went wrong.',
                    variant: 'error'
                })
            );

        });

    }
}
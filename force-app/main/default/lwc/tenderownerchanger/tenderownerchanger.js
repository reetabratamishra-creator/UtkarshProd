import { LightningElement, api, track } from 'lwc';

import getTenderOwnerDetails from '@salesforce/apex/TenderOwnerChangeController.getTenderOwnerDetails';
import getDepartmentUsers from '@salesforce/apex/TenderOwnerChangeController.getDepartmentUsers';
import updateOwner from '@salesforce/apex/TenderOwnerChangeController.updateOwner';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';

export default class TenderOwnerChanger extends LightningElement {

    @track ownerOptions = [];

    department;      // auto-derived from the Tender record - read only
    currentOwnerId;  // owner the record has today
    selectedOwner;   // owner chosen in the UI

    isLoading = false;
    hasLoadError = false;

    _recordId;

    @api
    set recordId(value) {
        this._recordId = value;

        if (value) {
            this.initialize();
        }
    }

    get recordId() {
        return this._recordId;
    }

    async initialize() {

        this.isLoading = true;
        this.hasLoadError = false;

        try {

            const tenderInfo = await getTenderOwnerDetails({
                tenderId: this._recordId
            });

            this.department = tenderInfo.department;
            this.currentOwnerId = tenderInfo.ownerId;

            const users = await getDepartmentUsers({
                department: this.department
            });

            this.ownerOptions = users;

            // Preselect the current owner if they're still a valid option
            const ownerExists = users.find(
                (item) => item.value === this.currentOwnerId
            );
            this.selectedOwner = ownerExists ? this.currentOwnerId : null;

        } catch (error) {

            this.hasLoadError = true;
            this.showError(error);

        } finally {

            this.isLoading = false;

        }
    }

    //==========================
    // Getters
    //==========================

    get hasUsers() {
        return this.ownerOptions.length > 0;
    }

   get disableSave() {
    return !this.selectedOwner;
}

    //==========================
    // Handlers
    //==========================

    handleOwnerChange(event) {
        this.selectedOwner = event.detail.value;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleSave() {

        this.isLoading = true;

        try {

            await updateOwner({
                tenderId: this._recordId,
                ownerId: this.selectedOwner
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Owner changed successfully.',
                    variant: 'success'
                })
            );

            this.dispatchEvent(new RefreshEvent());

            this.dispatchEvent(new CloseActionScreenEvent());

        } catch (error) {

            this.showError(error);

        } finally {

            this.isLoading = false;

        }
    }

    //==========================
    // Helper
    //==========================

    showError(error) {

        let message = 'Unknown Error';

        if (error?.body?.message) {
            message = error.body.message;
        } else if (error?.message) {
            message = error.message;
        }

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: message,
                variant: 'error'
            })
        );
    }
}
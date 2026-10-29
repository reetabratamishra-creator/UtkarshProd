import { LightningElement, api, track } from 'lwc';

import getDepartments from '@salesforce/apex/TenderDepartmentController.getDepartments';
import getDepartmentUsers from '@salesforce/apex/TenderDepartmentController.getDepartmentUsers';
import getTenderDetails from '@salesforce/apex/TenderDepartmentController.getTenderDetails';
import updateDepartmentAndOwner from '@salesforce/apex/TenderDepartmentController.updateDepartmentAndOwner';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';

export default class TenderDepartmentChanger extends LightningElement {


    @track departmentOptions = [];
    @track ownerOptions = [];

    selectedDepartment;
    selectedOwner;
    currentOwner;

    isLoading = false;

    currentStep = 1;

    _recordId;

@api
set recordId(value) {
    this._recordId = value;

    console.log('Record Id Received : ', value);

    if (value) {
        this.initialize();
    }
}

get recordId() {
    return this._recordId;
}

    async initialize() {

        this.isLoading = true;

        try {

            const [deptOptions, tender] = await Promise.all([
                getDepartments(),
                getTenderDetails({
                    tenderId: this._recordId
                })
            ]);

            this.departmentOptions = deptOptions;

            this.selectedDepartment = tender.department;
            this.currentOwner = tender.ownerId;

        } catch (error) {

            this.showError(error);

        } finally {

            this.isLoading = false;

        }
    }

    //==========================
    // Getters
    //==========================

    get showDepartmentStep() {
        return this.currentStep === 1;
    }

    get showOwnerStep() {
        return this.currentStep === 2;
    }

    get disableNext() {
        return !this.selectedDepartment;
    }

    get disableFinish() {
        return !this.selectedOwner;
    }

    get hasUsers() {
        return this.ownerOptions.length > 0;
    }

    //==========================
    // Handlers
    //==========================

    handleDepartmentChange(event) {

        this.selectedDepartment = event.detail.value;

    }

    handleOwnerChange(event) {

        this.selectedOwner = event.detail.value;

    }

    async handleNext() {

        this.isLoading = true;

        try {

            console.log('Selected Department : ', this.selectedDepartment);

            const users = await getDepartmentUsers({

                department: this.selectedDepartment

            });

            this.ownerOptions = users;

            this.selectedOwner = null;

            // Preselect current owner if present

            if (this.currentOwner) {

                const ownerExists = users.find(
                    item => item.value === this.currentOwner
                );

                if (ownerExists) {
                    this.selectedOwner = this.currentOwner;
                }

            }

            this.currentStep = 2;

        } catch (error) {

            this.showError(error);

        } finally {

            this.isLoading = false;

        }

    }

    handlePrevious() {

        this.currentStep = 1;

    }

    async handleFinish() {

        this.isLoading = true;

        try {

            await updateDepartmentAndOwner({

    tenderId: this._recordId,
    department: this.selectedDepartment,
    ownerId: this.selectedOwner

});

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Department and Owner changed successfully.',
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
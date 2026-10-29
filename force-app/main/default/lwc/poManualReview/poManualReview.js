import { LightningElement, api } from 'lwc';
import getReviewDetails from '@salesforce/apex/POManualReviewController.getReviewDetails';
import saveReview from '@salesforce/apex/POManualReviewController.saveReview';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PoManualReview extends LightningElement {

    @api recordId;

    isOpen = true;
    isLoading = true;

    poNumber;
    poDate;
    amount;

    disablePoNumber = true;
    disablePoDate = true;
    disableAmount = true;

    reviewCompleted = false;

    connectedCallback() {
        this.loadRecord();
    }

    loadRecord() {

        this.isLoading = true;

        getReviewDetails({
            recordId: this.recordId
        })
        .then(result => {

            this.poNumber = result.poNumber;
            this.poDate = result.poDate;
            this.amount = result.amount;

            this.disablePoNumber = !result.canEditPoNumber;
            this.disablePoDate = !result.canEditPoDate;
            this.disableAmount = !result.canEditAmount;

            this.reviewCompleted = result.reviewCompleted;

            this.isLoading = false;

        })
        .catch(error => {

            this.isLoading = false;

            this.showToast(
                'Error',
                error.body.message,
                'error'
            );

            this.closeModal();

        });

    }

    get saveDisabled() {

        return this.reviewCompleted;

    }

    handlePoNumber(event) {

        this.poNumber = event.target.value;

    }

    handlePoDate(event) {

        this.poDate = event.target.value;

    }

    handleAmount(event) {

        this.amount = event.target.value;

    }

    saveRecord() {

        this.isLoading = true;

        saveReview({

            recordId: this.recordId,

            poNumber: this.poNumber,

            poDate: this.poDate,

            amount: this.amount ? Number(this.amount) : null

        })
        .then(() => {

            this.isLoading = false;

            this.showToast(
                'Success',
                'Purchase Order details updated successfully.',
                'success'
            );

            /*
             Notify Parent
            */

            this.dispatchEvent(

                new CustomEvent('success')

            );

            this.closeModal();

        })
        .catch(error => {

            this.isLoading = false;

            this.showToast(
                'Error',
                error.body.message,
                'error'
            );

        });

    }

    closeModal() {

        this.dispatchEvent(

            new CustomEvent('close')

        );

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

}
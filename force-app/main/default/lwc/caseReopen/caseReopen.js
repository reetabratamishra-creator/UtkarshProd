import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import getCaseInfo from '@salesforce/apex/CaseReopenController.getCaseInfo';
import reopenCase from '@salesforce/apex/CaseReopenController.reopenCase';

export default class CaseReopen extends LightningElement {
    @api recordId;

    caseInfo;
    loading = true;
    saving = false;
    errorMessage;

    @wire(getCaseInfo, { caseId: '$recordId' })
    wiredCase({ data, error }) {
        this.loading = false;
        if (data) {
            this.caseInfo = data;
            this.errorMessage = undefined;
        } else if (error) {
            this.caseInfo = undefined;
            this.errorMessage = this.reduceError(error);
        }
    }

    get disableSubmit() {
        return this.loading || this.saving || !this.caseInfo;
    }

    handleReopen() {
        this.saving = true;
        this.loading = true;
        this.errorMessage = undefined;

        reopenCase({ caseId: this.recordId })
            .then((caseNumber) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Case Reopened',
                        message: 'Case ' + caseNumber + ' has been reopened.',
                        variant: 'success'
                    })
                );
                notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch((error) => {
                this.errorMessage = this.reduceError(error);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: this.errorMessage,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.saving = false;
                this.loading = false;
            });
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    reduceError(error) {
        return (
            error?.body?.message ||
            error?.message ||
            'Unexpected error. Please contact your administrator.'
        );
    }
}
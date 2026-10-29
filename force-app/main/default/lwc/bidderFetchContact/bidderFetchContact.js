import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { RefreshEvent } from 'lightning/refresh';
import fetchContactDetails from '@salesforce/apex/BidderContactLookupService.fetchContactDetails';

export default class BidderFetchContact extends LightningElement {
    @api recordId;
    loading = true;
    resultMessage = '';
    hasFetched = false; // guard so the callout only fires once

    renderedCallback() {
        // recordId is injected by the Quick Action framework AFTER
        // connectedCallback runs, so we wait for it here instead and
        // fire the fetch exactly once as soon as it's actually available.
        if (!this.hasFetched && this.recordId) {
            this.hasFetched = true;
            this.runFetch();
        }
    }

    runFetch() {
        fetchContactDetails({ bidderId: this.recordId })
            .then((message) => {
                this.resultMessage = message;
                this.loading = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Fetch Contact Details',
                        message: message,
                        variant: 'success'
                    })
                );
                this.dispatchEvent(new RefreshEvent());
            })
            .catch((error) => {
                this.loading = false;
                this.resultMessage = 'Failed: ' + (error.body ? error.body.message : error.message);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Fetch Contact Details Failed',
                        message: this.resultMessage,
                        variant: 'error'
                    })
                );
            });
    }

    get isSuccess() {
        return this.resultMessage && !this.resultMessage.startsWith('Failed')
               && !this.resultMessage.startsWith('Bidder record not found');
    }

    get statusIconClass() {
        return this.isSuccess
            ? 'bcl-status-icon bcl-status-icon_success'
            : 'bcl-status-icon bcl-status-icon_error';
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
    get statusPanelClass() {
    return this.isSuccess ? 'bcl-status-panel bcl-status-panel_success' : 'bcl-status-panel bcl-status-panel_error';
}

get statusLabel() {
    return this.isSuccess ? 'Success' : 'Attention needed';
}
}
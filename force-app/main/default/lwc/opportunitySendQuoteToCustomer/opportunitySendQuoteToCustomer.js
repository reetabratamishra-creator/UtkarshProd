import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import SYNCED_QUOTE_ID from '@salesforce/schema/Opportunity.SyncedQuoteId';
import sendQuoteToCustomer from '@salesforce/apex/OpportunityQuoteController.sendQuoteToCustomer';

export default class OpportunitySendQuoteToCustomer extends LightningElement {
    @api recordId;

    isSending = false;

    @wire(getRecord, { recordId: '$recordId', fields: [SYNCED_QUOTE_ID] })
    opportunity;

    get showButton() {
        return !!getFieldValue(this.opportunity.data, SYNCED_QUOTE_ID);
    }

    async handleSend() {
        if (this.isSending) {
            return;
        }

        this.isSending = true;
        try {
            await sendQuoteToCustomer({ opportunityId: this.recordId });
            this.showToast(
                'Success',
                'WhatsApp quote message sent to the customer.',
                'success'
            );
        } catch (error) {
            this.showToast('Error', this.getErrorMessage(error), 'error');
        } finally {
            this.isSending = false;
        }
    }

    getErrorMessage(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unable to send WhatsApp message.';
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
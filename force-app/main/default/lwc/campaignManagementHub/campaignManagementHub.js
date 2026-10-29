import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCampaignObjectOptions from '@salesforce/apex/CampaignManagementHubController.getCampaignObjectOptions';

export default class CampaignManagementHub extends LightningElement {
    objectOptions = [];
    selectedObject;
    isLoadingOptions = true;
    loadError;

    @wire(getCampaignObjectOptions)
    wiredObjectOptions({ data, error }) {
        this.isLoadingOptions = false;
        if (data) {
            this.objectOptions = data;
            this.loadError = undefined;
            if (!this.selectedObject && data.length > 0) {
                this.selectedObject = data[0].value;
            } else if (
                this.selectedObject &&
                !data.some((option) => option.value === this.selectedObject)
            ) {
                this.selectedObject = data.length > 0 ? data[0].value : undefined;
            }
        } else if (error) {
            this.loadError = this.extractError(error);
            this.objectOptions = [];
            this.selectedObject = undefined;
            this.showToast('Campaign Management', this.loadError, 'error');
        }
    }

    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractError(error) {
        if (error && error.body) {
            if (Array.isArray(error.body)) {
                return error.body.map((item) => item.message).join(', ');
            }
            if (error.body.message) {
                return error.body.message;
            }
        }
        return 'Unknown error';
    }

    get hasObjectOptions() {
        return this.objectOptions.length > 0;
    }

    get showLeadView() {
        return this.selectedObject === 'Lead';
    }

    get showOpportunityView() {
        return this.selectedObject === 'Opportunity';
    }

    get showAccountView() {
        return this.selectedObject === 'Account';
    }

    get showContactView() {
        return this.selectedObject === 'Contact';
    }

    get showOfflineCampaignView() {
        return this.selectedObject === 'Offline_Campaign';
    }
}
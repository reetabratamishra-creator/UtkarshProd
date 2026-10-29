import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getDealerOpportunitiesData from '@salesforce/apex/DealerDashboardController.getDealerOpportunitiesData';

export default class DealerDashboardViewer extends LightningElement {
    @track recordsData = [];
    @track recordsColumns = [];
    @track errorMessage;
    @track isLoading = true;

    @wire(CurrentPageReference)
    handlePageRefChange(pageRef) {
        if (pageRef) {
            this.isLoading = true;
            this.loadData();
        }
    }

    loadData() {
        getDealerOpportunitiesData()
            .then(result => {
                this.recordsColumns = result.columns || [];
                this.recordsData = result.data || [];
                this.errorMessage = undefined;
                this.isLoading = false;
            })
            .catch(error => {
                this.errorMessage = this.extractErrorMessage(error);
                this.isLoading = false;
            });
    }

    get hasRecords() {
        return this.recordsData && this.recordsData.length > 0;
    }

    get recordCount() {
        return this.recordsData ? this.recordsData.length : 0;
    }

    get showError() {
        return !this.isLoading && !!this.errorMessage;
    }

    get showTable() {
        return !this.isLoading && !this.errorMessage && this.hasRecords;
    }

    get showEmpty() {
        return !this.isLoading && !this.errorMessage && !this.hasRecords;
    }

    extractErrorMessage(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        return 'An unexpected error occurred. Please try refreshing the page.';
    }
}
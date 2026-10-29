import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getLostLeadsData               from '@salesforce/apex/LostRecordsController.getLostLeadsData';
import getClosedLostOpportunitiesData from '@salesforce/apex/LostRecordsController.getClosedLostOpportunitiesData';
import getObjectAccess                 from '@salesforce/apex/LostRecordsController.getObjectAccess';

export default class LostRecords extends LightningElement {

    // ─── Object Access State ────────────────────────────────────────────────
    @track hasLeadAccess = false;
    @track hasOpportunityAccess = false;

    // ─── Leads State ────────────────────────────────────────────────────────
    @track leadsData    = [];
    @track leadsColumns = [];
    @track leadsError;
    @track isLeadsLoading = true;

    // ─── Opportunities State ─────────────────────────────────────────────────
    @track oppsData    = [];
    @track oppsColumns = [];
    @track oppsError;
    @track isOppsLoading = true;

    // ─── Lifecycle ───────────────────────────────────────────────────────────

    @wire(CurrentPageReference)
    handlePageRefChange(pageRef) {
        if (pageRef) {
            this.isLeadsLoading = true;
            this.isOppsLoading = true;
            this.checkObjectAccess();
        }
    }

    checkObjectAccess() {
        getObjectAccess()
            .then(result => {
                this.hasLeadAccess = result.Lead;
                this.hasOpportunityAccess = result.Opportunity;

                if (this.hasLeadAccess) {
                    this.loadLeads();
                } else {
                    this.isLeadsLoading = false;
                }

                if (this.hasOpportunityAccess) {
                    this.loadOpportunities();
                } else {
                    this.isOppsLoading = false;
                }
            })
            .catch(error => {
                this.hasLeadAccess = false;
                this.hasOpportunityAccess = false;
                this.isLeadsLoading = false;
                this.isOppsLoading = false;
                this.leadsError = this.extractErrorMessage(error);
                this.oppsError = this.extractErrorMessage(error);
            });
    }

    // ─── Data Loading ────────────────────────────────────────────────────────

    loadLeads() {
        getLostLeadsData()
            .then(result => {
                this.leadsColumns   = result.columns || [];
                this.leadsData      = result.data    || [];
                this.leadsError     = undefined;
                this.isLeadsLoading = false;
            })
            .catch(error => {
                this.leadsError     = this.extractErrorMessage(error);
                this.isLeadsLoading = false;
            });
    }

    loadOpportunities() {
        getClosedLostOpportunitiesData()
            .then(result => {
                this.oppsColumns   = result.columns || [];
                this.oppsData      = result.data    || [];
                this.oppsError     = undefined;
                this.isOppsLoading = false;
            })
            .catch(error => {
                this.oppsError     = this.extractErrorMessage(error);
                this.isOppsLoading = false;
            });
    }

    // ─── Leads Conditional Getters ───────────────────────────────────────────

    get hasLeads() {
        return this.leadsData && this.leadsData.length > 0;
    }

    get leadCount() {
        return this.leadsData ? this.leadsData.length : 0;
    }

    get showLeadsError() {
        return !this.isLeadsLoading && !!this.leadsError;
    }

    get showLeadsTable() {
        return !this.isLeadsLoading && !this.leadsError && this.hasLeads;
    }

    get showLeadsEmpty() {
        return !this.isLeadsLoading && !this.leadsError && !this.hasLeads;
    }

    // ─── Opportunities Conditional Getters ───────────────────────────────────

    get hasOpps() {
        return this.oppsData && this.oppsData.length > 0;
    }

    get oppCount() {
        return this.oppsData ? this.oppsData.length : 0;
    }

    get showOppsError() {
        return !this.isOppsLoading && !!this.oppsError;
    }

    get showOppsTable() {
        return !this.isOppsLoading && !this.oppsError && this.hasOpps;
    }

    get showOppsEmpty() {
        return !this.isOppsLoading && !this.oppsError && !this.hasOpps;
    }

    get showDivider() {
        return this.hasLeadAccess && this.hasOpportunityAccess;
    }

    // ─── Utilities ───────────────────────────────────────────────────────────

    extractErrorMessage(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message)       return error.message;
        return 'An unexpected error occurred. Please try refreshing the page.';
    }
}
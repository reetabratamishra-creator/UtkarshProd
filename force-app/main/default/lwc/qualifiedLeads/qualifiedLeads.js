import { LightningElement, track, wire, api } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getQualifiedLeadsData from '@salesforce/apex/QualifiedLeadsController.getQualifiedLeadsData';
import getObjectAccess       from '@salesforce/apex/QualifiedLeadsController.getObjectAccess';

export default class QualifiedLeads extends LightningElement {

    // ─── Design Properties ──────────────────────────────────────────────────
    @api filterValue = 'Qualified';

    // ─── Object Access State ────────────────────────────────────────────────
    @track hasLeadAccess = false;

    // ─── Leads State ────────────────────────────────────────────────────────
    @track leadsData    = [];
    @track leadsColumns = [];
    @track leadsError;
    @track isLeadsLoading = true;

    // ─── Lifecycle ───────────────────────────────────────────────────────────

    @wire(CurrentPageReference)
    handlePageRefChange(pageRef) {
        if (pageRef) {
            this.isLeadsLoading = true;
            this.checkObjectAccess();
        }
    }

    checkObjectAccess() {
        getObjectAccess()
            .then(result => {
                this.hasLeadAccess = result.Lead;

                if (this.hasLeadAccess) {
                    this.loadLeads();
                } else {
                    this.isLeadsLoading = false;
                }
            })
            .catch(error => {
                this.hasLeadAccess = false;
                this.isLeadsLoading = false;
                this.leadsError = this.extractErrorMessage(error);
            });
    }

    // ─── Data Loading ────────────────────────────────────────────────────────

    loadLeads() {
        getQualifiedLeadsData({ filterValue: this.filterValue })
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

    // ─── Conditional Getters ─────────────────────────────────────────────────

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

    // ─── Utilities ───────────────────────────────────────────────────────────

    extractErrorMessage(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message)       return error.message;
        return 'An unexpected error occurred. Please try refreshing the page.';
    }
}
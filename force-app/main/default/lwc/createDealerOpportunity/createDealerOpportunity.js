import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';

import INDUSTRY_FIELD from '@salesforce/schema/Opportunity.Industry__c';

import getOpportunityRecordTypeId from '@salesforce/apex/DealerOpportunityController.getOpportunityRecordTypeId';
import getDealerAccounts from '@salesforce/apex/DealerOpportunityController.getDealerAccounts';
import getDealerDetails from '@salesforce/apex/DealerOpportunityController.getDealerDetails';
import createDealerOpportunity from '@salesforce/apex/DealerOpportunityController.createDealerOpportunity';

const MAX_VISIBLE = 100;

export default class CreateDealerOpportunity extends NavigationMixin(LightningElement) {
    allDealers = [];          // department-scoped list {label, value}
    industryOptions = [];
    dealerRecordTypeId;

    // Dealer search/select state
    searchTerm = '';
    showDropdown = false;
    selectedDealerId;
    selectedDealerName;

    // Other form state
    closeDate;
    amount;
    industry;

    // Derived from selected dealer
    dealerPhone;
    dealerEmail;
    contactId;
    contactName;

    isSaving = false;

    @wire(getOpportunityRecordTypeId)
    wiredRtId({ data }) {
        if (data) {
            this.dealerRecordTypeId = data;
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$dealerRecordTypeId', fieldApiName: INDUSTRY_FIELD })
    wiredIndustry({ data }) {
        if (data) {
            this.industryOptions = data.values.map((v) => ({ label: v.label, value: v.value }));
        }
    }

    @wire(getDealerAccounts)
    wiredDealers({ data, error }) {
        if (data) {
            this.allDealers = data.map((d) => ({ label: d.name, value: d.id }));
        } else if (error) {
            this.showToast('Error loading dealers', this.reduceError(error), 'error');
        }
    }

    // ---- Searchable dealer picker ----
    get filteredDealers() {
        const term = (this.searchTerm || '').toLowerCase().trim();
        const source = term
            ? this.allDealers.filter((d) => d.label.toLowerCase().includes(term))
            : this.allDealers;
        return source.slice(0, MAX_VISIBLE);
    }

    get noResults() {
        return this.showDropdown && this.filteredDealers.length === 0;
    }

    get comboboxClass() {
        return (
            'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click' +
            (this.showDropdown ? ' slds-is-open' : '')
        );
    }

    handleDealerFocus() {
        this.showDropdown = true;
    }

    handleDealerBlur() {
        // option uses onmousedown, which fires before blur, so selection is safe
        this.showDropdown = false;
    }

    handleDealerSearch(event) {
        this.searchTerm = event.target.value;
        this.showDropdown = true;
        if (this.selectedDealerId) {
            this.clearSelection();   // editing invalidates a prior pick
        }
    }

    handleDealerSelect(event) {
        this.selectedDealerId = event.currentTarget.dataset.id;
        this.selectedDealerName = event.currentTarget.dataset.name;
        this.searchTerm = this.selectedDealerName;
        this.showDropdown = false;
        this.loadDealerDetails();
    }

    clearSelection() {
        this.selectedDealerId = undefined;
        this.selectedDealerName = undefined;
        this.dealerPhone = undefined;
        this.dealerEmail = undefined;
        this.contactId = undefined;
        this.contactName = undefined;
    }

    loadDealerDetails() {
        getDealerDetails({ accountId: this.selectedDealerId })
            .then((res) => {
                this.dealerPhone = res.phone;
                this.dealerEmail = res.email;
                this.contactId = res.contactId;
                this.contactName = res.contactName;
            })
            .catch((error) => {
                this.showToast('Error', this.reduceError(error), 'error');
            });
    }

    // ---- Other fields ----
    handleCloseDateChange(event) { this.closeDate = event.detail.value; }
    handleAmountChange(event) { this.amount = event.detail.value; }
    handleIndustryChange(event) { this.industry = event.detail.value; }

    get isSaveDisabled() {
        return this.isSaving || !this.selectedDealerId || !this.closeDate;
    }

    get hasContact() {
        return !!this.contactId;
    }

    handleSave() {
        const inputs = [...this.template.querySelectorAll('lightning-input, lightning-combobox')];
        const allValid = inputs.reduce((valid, cmp) => {
            cmp.reportValidity();
            return valid && cmp.checkValidity();
        }, true);
        if (!allValid) {
            return;
        }
        if (!this.selectedDealerId) {
            this.showToast('Missing dealer', 'Please select a Dealer.', 'warning');
            return;
        }

        this.isSaving = true;
        createDealerOpportunity({
            accountId: this.selectedDealerId,
            closeDate: this.closeDate,
            amount: this.amount ? parseFloat(this.amount) : null,
            industry: this.industry || null,
            opportunityName: null
        })
            .then((oppId) => {
                this.showToast('Success', 'Dealer Opportunity created.', 'success');
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: { recordId: oppId, objectApiName: 'Opportunity', actionName: 'view' }
                });
            })
            .catch((error) => {
                this.showToast('Error creating Opportunity', this.reduceError(error), 'error');
            })
            .finally(() => { this.isSaving = false; });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unknown error';
    }
}
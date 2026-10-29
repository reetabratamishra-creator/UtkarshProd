import { LightningElement, api, wire } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';
import getMatchingAccounts from '@salesforce/apex/AccountMatchController.getMatchingAccounts';
import searchAccounts from '@salesforce/apex/AccountMatchController.searchAccounts';

const DEBOUNCE_MS = 300;

export default class AccountMatchSelector extends LightningElement {
    // ---------- Flow inputs ----------
    @api accountName;
    @api phone;
    @api email;
    @api label = 'Account Name';
    @api required = false;

    // ---------- Flow outputs ----------
    @api selectedAccountId;
    @api isExistingAccount = false;
    @api resolvedAccountName;

    // ---------- Internal state ----------
    matches = [];
    matchError;
    searchTerm = '';
    searchResults = [];
    showDropdown = false;
    isSearching = false;
    _timer;

    connectedCallback() {
        // Seed the input with whatever the Flow passed in
        this.searchTerm = this.accountName || '';
        this.publish(null, false, this.searchTerm);
    }

    // ---------- Exact matches ----------
    @wire(getMatchingAccounts, { accountName: '$accountName', phone: '$phone', email: '$email' })
    wiredMatches({ data, error }) {
        if (data) {
            this.matches = data;
            this.matchError = undefined;
        } else if (error) {
            this.matches = [];
            this.matchError = error?.body?.message || 'Unable to load matching accounts.';
        }
    }

    get decoratedMatches() {
        return this.matches.map((a) => {
            const isSelected = a.Id === this.selectedAccountId;
            return {
                ...a,
                ownerName: a.Owner ? a.Owner.Name : '',
                buttonLabel: isSelected ? 'Selected' : 'Select',
                buttonVariant: isSelected ? 'success' : 'neutral',
                rowClass: isSelected
                    ? 'slds-box slds-box_x-small slds-var-m-bottom_xx-small selected-row'
                    : 'slds-box slds-box_x-small slds-var-m-bottom_xx-small'
            };
        });
    }

    get hasMatches() {
        return this.matches.length > 0;
    }

    get matchCount() {
        return this.matches.length;
    }

    // ---------- Type-ahead ----------
    handleSearchChange(event) {
        const value = event.target.value;
        this.searchTerm = value;

        // Typing invalidates any prior selection -> fall back to typed name
        this.publish(null, false, value);

        window.clearTimeout(this._timer);
        if (!value || value.trim().length < 2) {
            this.searchResults = [];
            this.showDropdown = false;
            return;
        }

        this.isSearching = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._timer = window.setTimeout(() => this.runSearch(value), DEBOUNCE_MS);
    }

    runSearch(term) {
        searchAccounts({ searchKey: term })
            .then((result) => {
                this.searchResults = result;
                this.showDropdown = result.length > 0;
            })
            .catch(() => {
                this.searchResults = [];
                this.showDropdown = false;
            })
            .finally(() => {
                this.isSearching = false;
            });
    }

    // mousedown fires before blur, so the click always registers
    handleOptionSelect(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        this.searchTerm = name;
        this.showDropdown = false;
        this.publish(id, true, name);
    }

    handleMatchSelect(event) {
        const id = event.currentTarget.dataset.id;
        const acc = this.matches.find((a) => a.Id === id);
        this.searchTerm = acc.Name;
        this.showDropdown = false;
        this.publish(id, true, acc.Name);
    }

    handleBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => { this.showDropdown = false; }, 150);
    }

    handleClear() {
        this.searchTerm = '';
        this.searchResults = [];
        this.showDropdown = false;
        this.publish(null, false, '');
    }

    get isSelected() {
        return !!this.selectedAccountId;
    }

    get comboboxClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${
            this.showDropdown ? 'slds-is-open' : ''
        }`;
    }

    // ---------- Output plumbing ----------
    publish(id, existing, name) {
        this.selectedAccountId = id;
        this.isExistingAccount = existing;
        this.resolvedAccountName = name;

        this.dispatchEvent(new FlowAttributeChangeEvent('selectedAccountId', id));
        this.dispatchEvent(new FlowAttributeChangeEvent('isExistingAccount', existing));
        this.dispatchEvent(new FlowAttributeChangeEvent('resolvedAccountName', name));
    }

    // Called by Flow on Next
    @api
    validate() {
        if (this.required && !this.selectedAccountId && !(this.searchTerm || '').trim()) {
            return { isValid: false, errorMessage: 'Select an existing account or enter an account name.' };
        }
        return { isValid: true };
    }
}
import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';
import searchAccounts from '@salesforce/apex/AccountResolverController_Opp_Create.searchAccounts';
import findDuplicateAccounts from '@salesforce/apex/AccountResolverController_Opp_Create.findDuplicateAccounts';

const DEBOUNCE_MS = 300;
const MODE_SEARCH = 'search';
const MODE_DUPLICATE = 'duplicate';

export default class AccountResolverforCustomOpp extends LightningElement {
    // ---------- Flow inputs ----------
    @api companyName;   // company name
    @api phone;
    @api email;

    // ---------- Flow outputs ----------
    @api selectedMode = MODE_SEARCH;
    @api selectedAccountId;
    @api isExistingAccount = false;
    @api resolvedAccountName;
    @api selectedRecordTypeName;

    // ---------- Internal state ----------
    searchTerm = '';
    searchResults = [];
    showDropdown = false;
    isSearching = false;

    duplicates = [];
    selectedDuplicateId;
    isLoadingDuplicates = false;
    duplicateError;

    _timer;

    connectedCallback() {
        console.log('[AccountResolver] connectedCallback — inputs:', {
            companyName: this.companyName,
            phone: this.phone,
            email: this.email,
            selectedRecordTypeName: this.selectedRecordTypeName
        });

        this.searchTerm = this.companyName || '';
        if (!this.selectedMode) {
            this.selectedMode = MODE_SEARCH;
        }
        this.loadDuplicates();
        if (this.isSearchMode) {
            this.publish({ id: null, existing: false, name: this.searchTerm, mode: MODE_SEARCH });
        }
    }

    // ---------- Duplicate lad ----------
    loadDuplicates() {
        if (!this.companyName && !this.phone && !this.email) {
            console.log('[AccountResolver] loadDuplicates skipped — no companyName/phone/email provided');
            return;
        }
        console.log('[AccountResolver] loadDuplicates — calling Apex with:', {
            companyName: this.companyName,
            phone: this.phone,
            email: this.email,
            recordTypeName: this.selectedRecordTypeName
        });
        this.isLoadingDuplicates = true;
        findDuplicateAccounts({
            companyName: this.companyName,
            phone: this.phone,
            email: this.email,
            recordTypeName: this.selectedRecordTypeName
        })
            .then((res) => {
                console.log('[AccountResolver] findDuplicateAccounts result:', JSON.parse(JSON.stringify(res)));
                this.duplicates = res || [];
                this.duplicateError = undefined;
            })
            .catch((err) => {
                console.error('[AccountResolver] findDuplicateAccounts error:', JSON.parse(JSON.stringify(err)));
                this.duplicates = [];
                this.duplicateError = err?.body?.message || 'Unable to load duplicate accounts.';
            })
            .finally(() => { this.isLoadingDuplicates = false; });
    }

    // ----------  Radio Button ----------
    get modeOptions() {
        return [
            { label: 'Search for or create a new account', value: MODE_SEARCH },
            { label: 'Select a matching account', value: MODE_DUPLICATE }
        ];
    }

    get isSearchMode() { return this.selectedMode === MODE_SEARCH; }
    get isDuplicateMode() { return this.selectedMode === MODE_DUPLICATE; }

    handleModeChange(event) {
        console.log('[AccountResolver] handleModeChange — new mode:', event.detail.value);
        this.selectedMode = event.detail.value;
        this.clearOutputs();
        if (this.isSearchMode) {
            this.publish({ id: null, existing: false, name: this.searchTerm, mode: MODE_SEARCH });
        } else {
            this.dispatchEvent(new FlowAttributeChangeEvent('selectedMode', MODE_DUPLICATE));
        }
    }

    // ---------- Option 2: duplicate picklist ----------
    get hasDuplicates() {
        return this.duplicates && this.duplicates.length > 0;
    }

    get duplicateOptions() {
        return this.duplicates.map((a) => {
            const meta = [a.Phone, a.Email__c].filter(Boolean).join(' · ');
            return { label: meta ? `${a.Name} (${meta})` : a.Name, value: a.Id };
        });
    }

    handleDuplicateChange(event) {
        const id = event.detail.value;
        console.log('[AccountResolver] handleDuplicateChange — selected duplicate id:', id);
        this.selectedDuplicateId = id;
        // Mode 2 returns ONLY the id
        this.publish({ id, existing: true, name: null, mode: MODE_DUPLICATE });
    }

    // ---------- Option 1: type-ahead / free text ----------
    handleSearchChange(event) {
        const value = event.target.value;
        this.searchTerm = value;
        // fall back to typed name
        this.publish({ id: null, existing: false, name: value, mode: MODE_SEARCH });

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
        console.log('[AccountResolver] runSearch — term:', term, 'recordTypeName:', this.selectedRecordTypeName);
        searchAccounts({ searchKey: term, recordTypeName: this.selectedRecordTypeName })
            .then((res) => {
                console.log('[AccountResolver] searchAccounts result:', JSON.parse(JSON.stringify(res)));
                this.searchResults = res;
                this.showDropdown = res.length > 0;
            })
            .catch((err) => {
                console.error('[AccountResolver] searchAccounts error:', JSON.parse(JSON.stringify(err)));
                this.searchResults = [];
                this.showDropdown = false;
            })
            .finally(() => { this.isSearching = false; });
    }

    handleOptionSelect(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        console.log('[AccountResolver] handleOptionSelect — id:', id, 'name:', name);
        this.searchTerm = name;
        this.showDropdown = false;
        this.publish({ id, existing: true, name, mode: MODE_SEARCH });
    }

    handleBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => { this.showDropdown = false; }, 150);
    }

    handleClearSearch() {
        console.log('[AccountResolver] handleClearSearch');
        this.searchTerm = '';
        this.searchResults = [];
        this.showDropdown = false;
        this.publish({ id: null, existing: false, name: '', mode: MODE_SEARCH });
    }

    get searchSelected() {
        return this.isSearchMode && !!this.selectedAccountId;
    }

    get comboboxClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${
            this.showDropdown ? 'slds-is-open' : ''
        }`;
    }

    // ---------- Output ----------
    publish({ id, existing, name, mode }) {
        console.log('[AccountResolver] publish:', { id, existing, name, mode });

        this.selectedAccountId = id;
        this.isExistingAccount = existing;
        this.resolvedAccountName = name;
        this.selectedMode = mode;

        this.dispatchEvent(new FlowAttributeChangeEvent('selectedAccountId', id));
        this.dispatchEvent(new FlowAttributeChangeEvent('isExistingAccount', existing));
        this.dispatchEvent(new FlowAttributeChangeEvent('resolvedAccountName', name));
        this.dispatchEvent(new FlowAttributeChangeEvent('selectedMode', mode));
    }

    clearOutputs() {
        console.log('[AccountResolver] clearOutputs');
        this.selectedAccountId = null;
        this.isExistingAccount = false;
        this.resolvedAccountName = null;
        this.selectedDuplicateId = null;
        this.searchResults = [];
        this.showDropdown = false;
        this.dispatchEvent(new FlowAttributeChangeEvent('selectedAccountId', null));
        this.dispatchEvent(new FlowAttributeChangeEvent('isExistingAccount', false));
        this.dispatchEvent(new FlowAttributeChangeEvent('resolvedAccountName', null));
    }

    // Called by Flow on Next
    @api
    validate() {
        if (this.isSearchMode) {
            if (!this.selectedAccountId && !(this.searchTerm || '').trim()) {
                return { isValid: false, errorMessage: 'Search for an account or type a new account name.' };
            }
        } else if (!this.selectedAccountId) {
            return { isValid: false, errorMessage: 'Select one of the matched duplicate accounts.' };
        }
        return { isValid: true };
    }

    get showAddressSelector() {
        const show = this.isExistingAccount && this.selectedAccountId;
        console.log('[AccountResolver] showAddressSelector evaluated:', show,
            '| isExistingAccount:', this.isExistingAccount,
            '| selectedAccountId:', this.selectedAccountId);
        return show;
    }

    @api selectedAddressBookId;

    handleAddressSelected(event) {
        console.log('[AccountResolver] handleAddressSelected:', event.detail);
        this.selectedAddressBookId = event.detail.addressBookId;

        this.dispatchEvent(
            new FlowAttributeChangeEvent(
                'selectedAddressBookId',
                this.selectedAddressBookId
            )
        );
    }
}
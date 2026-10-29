import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

import searchAccounts from '@salesforce/apex/TenderResolverController.searchAccounts';
import findDuplicateAccounts from '@salesforce/apex/TenderResolverController.findDuplicateAccounts';
import getAccountContacts from '@salesforce/apex/TenderResolverController.getAccountContacts';

// Adjust these schema imports if your exact API names differ
import AUTHORITY_FIELD from '@salesforce/schema/Tender__c.Authority_T__c';
import CITY_FIELD from '@salesforce/schema/Tender__c.City__c';
import STATE_FIELD from '@salesforce/schema/Tender__c.State__c';
import COUNTRY_FIELD from '@salesforce/schema/Tender__c.Country__c';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import processTenderSetup from '@salesforce/apex/TenderResolverController.processTenderSetup';

const DEBOUNCE_MS = 300;
const MODE_SEARCH = 'search';
const MODE_DUPLICATE = 'duplicate';

const CONTACT_MODE_EXISTING = 'existing';
const CONTACT_MODE_NEW = 'new';

export default class TenderResolver extends LightningElement {
    
    // Quick Action / Record Page Context
    @api recordId;

    // ---------- Internal State Variables ----------
    
    // Account Data
    selectedMode = MODE_SEARCH;
    selectedAccountId = null;
    isExistingAccount = false;
    resolvedAccountName = null;

    // Address Data
    addressStreet = '';
    addressCity = '';
    addressState = '';
    addressCountry = '';
    addressPincode = '';
    selectedAddressBookId = null;

    // Contact Data
    includeContact = false;
    isExistingContact = false;
    selectedContactId = null;
    contactFirstName = '';
    contactLastName = '';
    contactEmail = '';
    contactPhone = '';

    // ---------- Internal State ----------
    @track searchResults = [];
    @track duplicates = [];
    @track accountContacts = [];
    
    searchTerm = '';
    showDropdown = false;
    isSearching = false;
    selectedDuplicateId;
    isLoadingDuplicates = false;
    duplicateError;
    contactMode = CONTACT_MODE_NEW;
    isSaving = false;

    _timer;
    _isInitialized = false;

    // ================= DATA FETCHING (WIRE) =================
    @wire(getRecord, { 
        recordId: '$recordId', 
        fields: [AUTHORITY_FIELD, CITY_FIELD, STATE_FIELD, COUNTRY_FIELD] 
    })
    wiredTender({ error, data }) {
        if (data && !this._isInitialized) {
            // 1. Pre-populate search term from Authority_T__c
            this.searchTerm = data.fields.Authority_T__c?.value || '';
            
            // 2. Pre-populate Address fields if currently empty
            if (!this.addressCity && data.fields.City__c?.value) {
                this.addressCity = data.fields.City__c.value;
            }
            if (!this.addressState && data.fields.State__c?.value) {
                this.addressState = data.fields.State__c.value;
            }
            if (!this.addressCountry && data.fields.Country__c?.value) {
                this.addressCountry = data.fields.Country__c.value;
            }

            // 3. Kick off initial searches and flag as initialized
            this._isInitialized = true;
            this.loadDuplicates();

            if (this.isSearchMode) {
                this.publishAccount({ id: null, existing: false, name: this.searchTerm, mode: MODE_SEARCH });
            }
        } else if (error) {
            console.error('Error fetching Tender record', error);
        }
    }

    // ================= ACCOUNT LOGIC =================
    loadDuplicates() {
        if (!this.searchTerm) {
            return;
        }
        this.isLoadingDuplicates = true;
        findDuplicateAccounts({
            companyName: this.searchTerm,
            phone: null,
            email: null
        })
        .then((res) => {
            this.duplicates = res || [];
            this.duplicateError = undefined;
        })
        .catch((err) => {
            this.duplicates = [];
            this.duplicateError = err?.body?.message || 'Unable to load duplicate accounts.';
        })
        .finally(() => { this.isLoadingDuplicates = false; });
    }

    get modeOptions() {
        return [
            { label: 'Search for or create a new account', value: MODE_SEARCH },
            { label: 'Select a matched duplicate account', value: MODE_DUPLICATE }
        ];
    }

    get isSearchMode() { return this.selectedMode === MODE_SEARCH; }
    get isDuplicateMode() { return this.selectedMode === MODE_DUPLICATE; }
    get hasDuplicates() { return this.duplicates && this.duplicates.length > 0; }

    handleModeChange(event) {
        this.selectedMode = event.detail.value;
        this.clearAccountOutputs();
        if (this.isSearchMode) {
            this.publishAccount({ id: null, existing: false, name: this.searchTerm, mode: MODE_SEARCH });
        }
    }

    get duplicateOptions() {
        return this.duplicates.map((a) => {
            const meta = [a.Phone, a.Email__c].filter(Boolean).join(' · ');
            return { label: meta ? `${a.Name} (${meta})` : a.Name, value: a.Id };
        });
    }

    handleDuplicateChange(event) {
        const id = event.detail.value;
        this.selectedDuplicateId = id;
        this.publishAccount({ id, existing: true, name: null, mode: MODE_DUPLICATE });
        this.loadContactsForAccount(id);
    }

    handleSearchChange(event) {
        const value = event.target.value;
        this.searchTerm = value;
        this.publishAccount({ id: null, existing: false, name: value, mode: MODE_SEARCH });

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
            .then((res) => {
                this.searchResults = res;
                this.showDropdown = res.length > 0;
            })
            .catch(() => {
                this.searchResults = [];
                this.showDropdown = false;
            })
            .finally(() => { this.isSearching = false; });
    }

    handleOptionSelect(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        this.searchTerm = name;
        this.showDropdown = false;
        this.publishAccount({ id, existing: true, name, mode: MODE_SEARCH });
        this.loadContactsForAccount(id);
    }

    handleBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => { this.showDropdown = false; }, 150);
    }

    handleClearSearch() {
        this.searchTerm = '';
        this.searchResults = [];
        this.showDropdown = false;
        this.publishAccount({ id: null, existing: false, name: '', mode: MODE_SEARCH });
        this.accountContacts = [];
    }

    get searchSelected() { return this.isSearchMode && !!this.selectedAccountId; }
    
    get comboboxClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${
            this.showDropdown ? 'slds-is-open' : ''
        }`;
    }

    publishAccount({ id, existing, name, mode }) {
        this.selectedAccountId = id;
        this.isExistingAccount = existing;
        this.resolvedAccountName = name;
        this.selectedMode = mode;
        
        // If account is removed, reset contacts & address book
        if(!id) {
            this.accountContacts = [];
            this.selectedContactId = null;
            this.selectedAddressBookId = null;
            
            // Reset contact mode back to NEW since existing is no longer an option
            this.contactMode = CONTACT_MODE_NEW;
            this.isExistingContact = false;
        }

        this.notifyParent();
    }

    clearAccountOutputs() {
        this.selectedAccountId = null;
        this.isExistingAccount = false;
        this.resolvedAccountName = null;
        this.selectedDuplicateId = null;
        this.searchResults = [];
        this.showDropdown = false;
        this.accountContacts = [];
        
        // Reset contact mode back to NEW
        this.contactMode = CONTACT_MODE_NEW;
        this.isExistingContact = false;

        this.notifyParent();
    }

    // ================= ADDRESS LOGIC =================
    get showAddressSelector() {
        return this.isExistingAccount && this.selectedAccountId;
    }

    get showManualAddress() {
        // Hide manual address inputs if an address book has been selected
        return !this.selectedAddressBookId;
    }

    handleAddressChange(event) {
        const fieldName = event.target.dataset.field;
        this[fieldName] = event.target.value;
        this.notifyParent();
    }

    handleAddressSelected(event) {
        this.selectedAddressBookId = event.detail.addressBookId;
        this.notifyParent();
    }

    // ================= CONTACT LOGIC =================
    get contactModeOptions() {
        const options = [
            { label: 'Create New Contact', value: CONTACT_MODE_NEW }
        ];
        
        // Only show "Select Existing Contact" if an account is actually selected
        if (this.selectedAccountId) {
            options.push({ label: 'Select Existing Contact', value: CONTACT_MODE_EXISTING });
        }
        
        return options;
    }
    
    get isNewContactMode() { return this.contactMode === CONTACT_MODE_NEW; }
    get isExistingContactMode() { return this.contactMode === CONTACT_MODE_EXISTING; }
    get hasAccountContacts() { return this.accountContacts.length > 0; }

    get accountContactOptions() {
        return this.accountContacts.map(c => ({
            label: `${c.Name} ${c.Email ? '('+c.Email+')' : ''}`, 
            value: c.Id 
        }));
    }

    handleIncludeContactChange(event) {
        this.includeContact = event.target.checked;
        this.notifyParent();
    }

    handleContactModeChange(event) {
        this.contactMode = event.detail.value;
        this.isExistingContact = (this.contactMode === CONTACT_MODE_EXISTING);
        
        // Auto-switch to new if they chose existing but no account is selected
        if (this.isExistingContactMode && !this.selectedAccountId) {
            this.contactMode = CONTACT_MODE_NEW;
            this.isExistingContact = false;
        }
        this.notifyParent();
    }

    handleContactSelectChange(event) {
        this.selectedContactId = event.detail.value;
        this.notifyParent();
    }

    handleContactChange(event) {
        const fieldName = event.target.dataset.field;
        this[fieldName] = event.target.value;
        this.notifyParent();
    }

    loadContactsForAccount(accountId) {
        if (!accountId) return;
        getAccountContacts({ accountId: accountId })
            .then(res => {
                this.accountContacts = res || [];
                // If they previously had 'existing' selected but the new account has no contacts
                if(this.accountContacts.length === 0 && this.isExistingContactMode) {
                    this.contactMode = CONTACT_MODE_NEW;
                    this.isExistingContact = false;
                }
            })
            .catch(() => { this.accountContacts = []; });
    }

    // ================= HELPER & VALIDATION =================
    
    // Optional: Sends current state to parent component if wrapped in another LWC
    notifyParent() {
        this.dispatchEvent(new CustomEvent('statechange', {
            detail: {
                selectedAccountId: this.selectedAccountId,
                resolvedAccountName: this.resolvedAccountName,
                addressCity: this.addressCity,
                addressState: this.addressState,
                // ... include other variables as needed
            }
        }));
    }

    @api
    validate() {
        // 1. Validate Account
        if (this.isSearchMode) {
            if (!this.selectedAccountId && !(this.searchTerm || '').trim()) {
                return { isValid: false, errorMessage: 'Account: Search for an account or type a new account name.' };
            }
        } else if (!this.selectedAccountId) {
            return { isValid: false, errorMessage: 'Account: Select one of the matched duplicate accounts.' };
        }

        const hasFullManualAddress = 
            (this.addressStreet || '').trim() && 
            (this.addressCity || '').trim() && 
            (this.addressState || '').trim() && 
            (this.addressCountry || '').trim() && 
            (this.addressPincode || '').trim();

        if (this.selectedAccountId) {
            if (!this.selectedAddressBookId && !hasFullManualAddress) {
                return { isValid: false, errorMessage: 'Address: Please select an Address Book or fill in all Address fields.' };
            }
        } else {
            if (!hasFullManualAddress) {
                return { isValid: false, errorMessage: 'Address: Please fill in all Address fields for the new account.' };
            }
        }

        // 2. Validate Contact if enabled
        if (this.includeContact) {
            if (this.isExistingContactMode && !this.selectedContactId) {
                return { isValid: false, errorMessage: 'Contact: Please select an existing contact or choose to create a new one.' };
            }
            if (this.isNewContactMode && !(this.contactLastName || '').trim()) {
                return { isValid: false, errorMessage: 'Contact: Last Name is required when creating a new contact.' };
            }
        }
        

        return { isValid: true };
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleSave() {
        // 1. Validate Account
        if (this.isSearchMode && !this.selectedAccountId && !this.searchTerm.trim()) {
            this.showToast('Error', 'Please enter an account name or search for an existing one.', 'error');
            return;
        }
        if (this.isDuplicateMode && !this.selectedAccountId) {
            this.showToast('Error', 'Please select a duplicate account.', 'error');
            return;
        }

        const hasFullManualAddress = 
            (this.addressStreet || '').trim() && 
            (this.addressCity || '').trim() && 
            (this.addressState || '').trim() && 
            (this.addressCountry || '').trim() && 
            (this.addressPincode || '').trim();

        if (this.selectedAccountId) {
            // Existing Account Scenario
            if (!this.selectedAddressBookId && !hasFullManualAddress) {
                this.showToast('Error', 'Please select an Address Book or fill in all Address Details (Street, City, State, Country, Pincode).', 'error');
                return;
            }
        } else {
            // New Account Scenario
            if (!hasFullManualAddress) {
                this.showToast('Error', 'Please fill in all Address Details (Street, City, State, Country, Pincode) for the new account.', 'error');
                return;
            }
        }

        // 2. Validate Contact (if enabled)
        if (this.includeContact && this.isNewContactMode) {
            if (!this.contactLastName.trim() || !this.contactEmail.trim() || !this.contactPhone.trim()) {
                this.showToast('Error', 'Last Name, Email, and Phone are required to create a new contact.', 'error');
                return;
            }
        }

        this.isSaving = true;

        // 3. Build Payload
        const payload = {
            tenderId: this.recordId,
            accountId: this.selectedAccountId,
            accountName: this.searchTerm,
            addressBookId: this.selectedAddressBookId,
            street: this.addressStreet,
            city: this.addressCity,
            state: this.addressState,
            country: this.addressCountry,
            pincode: this.addressPincode,
            includeContact: this.includeContact,
            contactId: this.selectedContactId,
            contactFirstName: this.contactFirstName,
            contactLastName: this.contactLastName,
            contactEmail: this.contactEmail,
            contactPhone: this.contactPhone
        };

        // --- DEBUG LOG ---
        console.log('--- PAYLOAD GOING TO APEX ---');
        console.log(JSON.stringify(payload));

        // 4. Call Apex
        processTenderSetup({ payload: payload })
            .then(() => {
                this.showToast('Success', 'Tender setup completed successfully!', 'success');
                // Refresh the record page to show updated lookups
                getRecordNotifyChange([{ recordId: this.recordId }]);
                this.dispatchEvent(new CloseActionScreenEvent());

                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => {
                    window.location.href = '/' + this.recordId;
                }, 500);
            })
            .catch(error => {
                this.isSaving = false;
                this.showToast('Error saving record', error?.body?.message || error.message, 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
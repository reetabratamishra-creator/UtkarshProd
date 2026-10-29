import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { createRecord, updateRecord } from 'lightning/uiRecordApi';

// Schema imports for Account
import ACCOUNT_OBJECT from '@salesforce/schema/Account';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Account.Name';
import ACCOUNT_PHONE_FIELD from '@salesforce/schema/Account.Phone';
import ACCOUNT_EMAIL_FIELD from '@salesforce/schema/Account.Email__c';
import ZONE_FIELD from '@salesforce/schema/Address_Book__c.Zone__c';
import OCR_OBJECT from '@salesforce/schema/OpportunityContactRole';
import OCR_OPP_FIELD from '@salesforce/schema/OpportunityContactRole.OpportunityId';
import OCR_CONTACT_FIELD from '@salesforce/schema/OpportunityContactRole.ContactId';
import OCR_ISPRIMARY_FIELD from '@salesforce/schema/OpportunityContactRole.IsPrimary';
import getBidderName from '@salesforce/apex/bidderAwardController.getBidderName';

// Contact Schema Imports
import CONTACT_OBJECT from '@salesforce/schema/Contact';
import CONTACT_FIRSTNAME_FIELD from '@salesforce/schema/Contact.FirstName'; 
import CONTACT_LASTNAME_FIELD from '@salesforce/schema/Contact.LastName';
import CONTACT_PHONE_FIELD from '@salesforce/schema/Contact.Phone';
import CONTACT_EMAIL_FIELD from '@salesforce/schema/Contact.Email';
import CONTACT_ACCOUNT_FIELD from '@salesforce/schema/Contact.AccountId';

// Schema imports for Opportunity linking
import OPP_ID_FIELD from '@salesforce/schema/Opportunity.Id';
import OPP_ACCOUNT_FIELD from '@salesforce/schema/Opportunity.AccountId';

import searchAccounts from '@salesforce/apex/bidderAwardController.searchAccounts';
import findDuplicateAccounts from '@salesforce/apex/bidderAwardController.findDuplicateAccounts';
import processAddressBook from '@salesforce/apex/AddressBookProcessor.processFromLWC';

import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import ADDRESSBOOK_OBJECT from '@salesforce/schema/Address_Book__c';
import COUNTRY_FIELD from '@salesforce/schema/Address_Book__c.Country__c';
import STATE_FIELD from '@salesforce/schema/Address_Book__c.State__c';

import PRODUCT_CATEGORY_OBJECT from '@salesforce/schema/Product_Category__c';
import DEPARTMENT_FIELD from '@salesforce/schema/Product_Category__c.Department_Name__c';
import UOM_FIELD from '@salesforce/schema/Product_Category__c.UOM__c';
import PRODUCT_CATEGORY_FIELD from '@salesforce/schema/Product_Category__c.Product_Category__c';
import createProductCategories from '@salesforce/apex/bidderAwardController.createProductCategories';
import getOpportunityDepartment from '@salesforce/apex/bidderAwardController.getOpportunityDepartment';

// New Apex Imports
import getAccountContacts from '@salesforce/apex/bidderAwardController.getAccountContacts';
import getBidderContactDetails from '@salesforce/apex/bidderAwardController.getBidderContactDetails';
import finalizeOpportunityAward from '@salesforce/apex/bidderAwardController.finalizeOpportunityAward';
import createAddressBookAndJunction from '@salesforce/apex/bidderAwardController.createAddressBookAndJunction';

const DEBOUNCE_MS = 300;
const MODE_SEARCH = 'search';
const MODE_DUPLICATE = 'duplicate';
const PRODUCT_COLUMNS = [
    {
        label: 'Department',
        fieldName: 'Department_Name__c',
        type: 'text'
    },
    {
        label: 'Product Category',
        fieldName: 'Product_Category__c',
        type: 'text'
    },
    {
        label: 'UOM',
        fieldName: 'UOM__c',
        type: 'text'
    },
    {
        label: 'Quantity',
        fieldName: 'Quantity__c',
        type: 'number',
        editable: true
    },
    {
        type: 'button-icon',
        fixedWidth: 60,
        typeAttributes: {
            iconName: 'utility:delete',
            name: 'delete',
            title: 'Delete',
            variant: 'bare',
            alternativeText: 'Delete'
        }
    }
];

export default class BidderAward extends LightningElement {
    @api recordId; // Opportunity Id populated automatically by the Quick Action

    // User inputs
    phone = '';
    email = '';
    
    // Internal state
    selectedMode = MODE_SEARCH;
    selectedAccountId = null;
    isExistingAccount = false;
    
    searchTerm = '';
    searchResults = [];
    showDropdown = false;
    isSearching = false;
    isLoading = false;

    duplicates = [];
    selectedDuplicateId;
    duplicateError;

    _timer;

    // Contact state variables
    accountContacts = [];
    selectedContactId = null;
    bidderContactDetails = null;
    bidderName;

    selectedContactMode = 'manual'; 
    manualContact = { FirstName: '', LastName: '', Phone: '', Email: '' }; // <-- Added FirstName

    // Product Category
    productCategoryRows = [];
    productColumns = PRODUCT_COLUMNS;
    productDraftValues = [];

    //selectedDepartment = '';
    opportunityDepartment = '';
    selectedUom = '';
    productQuantity = null;

    //departmentOptions = [];
    uomOptions = [];

    productRowCounter = 0;

    selectedProductCategory = '';

    productCategoryOptions = [];
    allProductCategoryValues = [];
    productCategoryControllerValues = {};
    isProductCategoryLoading = true;

    // product category wires
    @wire(getObjectInfo, { objectApiName: PRODUCT_CATEGORY_OBJECT })
    productCategoryInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$productCategoryInfo.data.defaultRecordTypeId',
        fieldApiName: DEPARTMENT_FIELD
    })
    wiredDepartmentValues({ data }) {
        if (data) {
            this.departmentOptions = data.values;
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$productCategoryInfo.data.defaultRecordTypeId',
        fieldApiName: UOM_FIELD
    })
    wiredUomValues({ data }) {
        if (data) {
            this.uomOptions = data.values;
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$productCategoryInfo.data.defaultRecordTypeId',
        fieldApiName: PRODUCT_CATEGORY_FIELD
    })
    wiredProductCategoryValues({ data }) {
        if (data) {
            this.allProductCategoryValues = data.values;
            this.productCategoryControllerValues = data.controllerValues;

            console.log('calling set product catagory')
            this.setProductCategoryOptions();
        }
    }

    @wire(getOpportunityDepartment, { opportunityId: '$recordId' })
    wiredOpportunityDepartment({ error, data }) {
        if (data) {
            this.opportunityDepartment = data;
            this.setProductCategoryOptions();
        } else if (error) {
            console.error('Error fetching Opportunity Department', error);
        }
    }

    

    @wire(getBidderName, { opportunityId: '$recordId' })
    wiredBidderName({ error, data }) {
        if (data) {
            this.bidderName = data;
            if (!this.searchTerm) {
                this.searchTerm = data;
                if (this.searchTerm.trim().length >= 2) {
                    this.isSearching = true;
                    this.runSearch(this.searchTerm);
                }
            }
        } else if (error) {
            console.error('Error fetching bidder name', error);
        }
    }

    // Fetch the Bidder Contact Details automatically when component loads
    @wire(getBidderContactDetails, { opportunityId: '$recordId' })
        wiredBidderDetails({ error, data }) {
            if (data) {
                this.bidderContactDetails = data;
                this.selectedContactMode = 'bidder';
                this.autoLoadDuplicates();
            } else if (error) {
                console.error('Error fetching bidder details', error);
            }
    }

    get hasNewAddressData() {
    const a = this.newAddressBook;
    return !!(
        a.Street__c ||
        a.City__c ||
        a.State__c ||
        a.Country__c ||
        a.PIN__c ||
        a.Zone__c
    );
  }

    countryOptions = [];
    stateOptions = [];
    
    zoneOptions = [];

    @wire(getObjectInfo, { objectApiName: ADDRESSBOOK_OBJECT })
    addressBookInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$addressBookInfo.data.defaultRecordTypeId',
        fieldApiName: COUNTRY_FIELD
    })
    wiredCountryValues({ data }) {
        if (data) this.countryOptions = data.values; // [{label, value}]
    }

    @wire(getPicklistValues, {
        recordTypeId: '$addressBookInfo.data.defaultRecordTypeId',
        fieldApiName: STATE_FIELD
    })
    wiredStateValues({ data }) {
        if (data) this.stateOptions = data.values;
    }

    

        @wire(getPicklistValues, {
            recordTypeId: '$addressBookInfo.data.defaultRecordTypeId',
            fieldApiName: ZONE_FIELD
        })
        wiredZoneValues({ data }) {
            if (data) {
                this.zoneOptions = data.values;
            }
        }

    get showStateField() {
        return this.newAddressBook.Country__c === 'India';
    }

    autoLoadDuplicates() {
    if (!this.bidderContactDetails) return;
    this.isLoading = true;
    console.log(this.bidderContactDetails.Bidders__r?.Name,'is being searched');
    findDuplicateAccounts({
        companyName: this.bidderContactDetails.Bidders__r?.Name,
        phone: this.bidderContactDetails.Contact_Number__c,
        email: this.bidderContactDetails.Email__c
    })
    .then((res) => {
        this.duplicates = res || [];
        this.duplicateError = undefined;
    })
    .catch((err) => {
        this.duplicates = [];
        this.duplicateError = err?.body?.message || 'Unable to load duplicate accounts.';
    })
    .finally(() => { this.isLoading = false; });
   }

    handlePhoneChange(event) {
        this.phone = event.target.value;
    }

    handleEmailChange(event) {
        this.email = event.target.value;
    }

    handleAddressFieldChange(event) {
    const field = event.currentTarget.dataset.field;
    const value = event.target.type === 'checkbox'
        ? event.target.checked
        : (event.detail?.value ?? event.target.value);

        if (field === 'Country__c' && value !== 'India') {
        this.newAddressBook = { ...this.newAddressBook, Country__c: value, State__c: '' };
        return;
    }
    this.newAddressBook = { ...this.newAddressBook, [field]: value };
    }
    

    get showNewAddressBookFields() {
    // New account being created, OR an existing account with no address book selected yet
    return !this.isExistingAccount || (this.isExistingAccount && !this.selectedAddressBookId);
   }

   newAddressBook = {
    Street__c: '',
    City__c: '',
    State__c: '',
    Country__c: '',
    PIN__c: '',
    Zone__c: '',
    Primary_Address__c: false
    };

    

    // ---------- Duplicate load ----------
    loadDuplicates() {
        if (!this.searchTerm && !this.phone && !this.email) {
            this.showToast('Info', 'Please provide a Name, Phone, or Email to check for duplicates.', 'info');
            return;
        }
        
        this.isLoading = true;
        findDuplicateAccounts({
            companyName: this.searchTerm,
            phone: this.phone,
            email: this.email
        })
        .then((res) => {
            this.duplicates = res || [];
            this.duplicateError = undefined;
            if(this.duplicates.length > 0) {
                this.selectedMode = MODE_DUPLICATE;
                this.showToast('Success', `Found ${this.duplicates.length} duplicate(s).`, 'success');
            } else {
                this.showToast('Info', 'No duplicates found.', 'info');
            }
        })
        .catch((err) => {
            this.duplicates = [];
            this.duplicateError = err?.body?.message || 'Unable to load duplicate accounts.';
        })
        .finally(() => { this.isLoading = false; });
    }

    // ---------- Radio Button ----------
    get modeOptions() {
        return [
            { label: 'Search for or create a new account', value: MODE_SEARCH },
            { label: 'Select a matched duplicate account', value: MODE_DUPLICATE }
        ];
    }

    get isSearchMode() { return this.selectedMode === MODE_SEARCH; }
    get isDuplicateMode() { return this.selectedMode === MODE_DUPLICATE; }

    handleModeChange(event) {
        this.selectedMode = event.detail.value;
        this.clearSelection();
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
        this.selectedDuplicateId = event.detail.value;
        this.selectedAccountId = this.selectedDuplicateId;
        this.isExistingAccount = true;
        this.selectedAddressBookId = null;
        
        // NEW: Fetch contacts for this account
        this.fetchAccountContacts(this.selectedAccountId);
    }

    // ---------- Option 1: type-ahead / free text ----------
    handleSearchChange(event) {
        const value = event.target.value;
        this.searchTerm = value;
        this.isExistingAccount = false; 
        this.selectedAccountId = null;

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
        this.selectedAccountId = event.currentTarget.dataset.id;
        this.searchTerm = event.currentTarget.dataset.name;
        this.isExistingAccount = true;
        this.showDropdown = false;
        
        // NEW: Fetch contacts for this account
        this.fetchAccountContacts(this.selectedAccountId);
    }

    handleBlur() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => { this.showDropdown = false; }, 150);
    }

    handleClearSearch() {
        this.searchTerm = '';
        this.searchResults = [];
        this.clearSelection();
    }

    get searchSelected() {
        return this.isSearchMode && !!this.selectedAccountId;
    }

    get comboboxClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${
            this.showDropdown ? 'slds-is-open' : ''
        }`;
    }

    clearSelection() {
        this.selectedAccountId = null;
        this.isExistingAccount = false;
        this.selectedDuplicateId = null;
        this.selectedAddressBookId = null;
        this.showDropdown = false;
        
        // NEW: Clear contact data
        this.accountContacts = [];
        this.selectedContactId = null;

        if (this.selectedContactMode === 'existing') {
            this.selectedContactMode = this.bidderContactDetails ? 'bidder' : 'manual';
        }
    }

    // product category functions
    get hasProductCategories() {
        return this.productCategoryRows.length > 0;
    }

    get isProductCategoryDisabled() {
        return !this.selectedDepartment;
    }

    get isProductCategoryDisabled() {
        return (
            !this.opportunityDepartment ||
            !this.productCategoryOptions ||
            this.productCategoryOptions.length === 0
        );
    }
    get productCategoryPlaceholder() {
        return this.isProductCategoryLoading
            ? 'Loading product categories...'
            : 'Select Product Category';
    }

    setProductCategoryOptions() {
        if (
            !this.opportunityDepartment ||
            !this.allProductCategoryValues.length
        ) {
            this.productCategoryOptions = [];
            this.isProductCategoryLoading = true;
            return;
        }

        const controllerIndex =
            this.productCategoryControllerValues[this.opportunityDepartment];

        if (controllerIndex === undefined) {
            this.productCategoryOptions = [];
            this.isProductCategoryLoading = false;
            return;
        }

        this.productCategoryOptions =
            this.allProductCategoryValues.filter(option =>
                option.validFor.includes(controllerIndex)
            );

        this.isProductCategoryLoading = false;
    }

    /*handleDepartmentChange(event) {
        this.selectedDepartment = event.detail.value;

        // Clear previously selected Product Category
        this.selectedProductCategory = '';

        const controllerIndex =
            this.productCategoryControllerValues[this.selectedDepartment];

        if (controllerIndex === undefined) {
            this.productCategoryOptions = [];
            return;
        }

        this.productCategoryOptions =
            this.allProductCategoryValues.filter(option =>
                option.validFor.includes(controllerIndex)
            );
    }*/

    handleUomChange(event) {
        this.selectedUom = event.detail.value;
    }

    handleQuantityChange(event) {
        this.productQuantity = event.target.value;
    }

    handleProductCategoryChange(event) {
        this.selectedProductCategory = event.detail.value;
    }

    handleAddProductCategory() {

        if (!this.selectedProductCategory || !this.selectedUom || !this.productQuantity) {
            this.showToast('Error', 'Please select Product Category, UOM and enter Quantity.', 'error');
            return;
        }

        if (Number(this.productQuantity) <= 0) {
            this.showToast('Error', 'Quantity must be greater than 0.', 'error');
            return;
        }

        // Duplicate Product Category validation
        const alreadyAdded = this.productCategoryRows.some(
            row => row.Product_Category__c === this.selectedProductCategory
        );

        if (alreadyAdded) {
            this.showToast(
                'Product Category Already Added',
                'This product category has already been added. Delete it or edit it.',
                'warning'
            );
            return;
        }


        this.productRowCounter++;

        const newRow = {
            Id: `temp-${this.productRowCounter}`,
            Department_Name__c: this.opportunityDepartment,
            Product_Category__c: this.selectedProductCategory,
            UOM__c: this.selectedUom,
            Quantity__c: Number(this.productQuantity)
        };

        this.productCategoryRows = [
            ...this.productCategoryRows,
            newRow
        ];

        // Clear user-editable fields only
        this.selectedProductCategory = '';
        this.selectedUom = '';
        this.productQuantity = null;
    }

    handleProductSave(event) {
        const drafts = event.detail.draftValues;

        this.productCategoryRows = this.productCategoryRows.map(row => {
            const changedRow = drafts.find(draft => draft.Id === row.Id);

            return changedRow
                ? { ...row, ...changedRow }
                : row;
        });

        this.productDraftValues = [];
    }

    handleProductRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'delete') {
            this.productCategoryRows = this.productCategoryRows.filter(
                item => item.Id !== row.Id
            );
        }
    }

    // ---------- Save & DML Logic ----------
    async handleSave() {
        if (!this.productCategoryRows || this.productCategoryRows.length === 0) {
            this.showToast(
                'Error',
                'Please add at least one Product Category.',
                'error'
            );
            return;
        }

        if (this.isSearchMode && !this.selectedAccountId && !this.searchTerm.trim()) {
            this.showToast('Error', 'Search for an account or type a new account name.', 'error');
            return;
        }
        if (this.isDuplicateMode && !this.selectedAccountId) {
            this.showToast('Error', 'Select one of the matched duplicate accounts.', 'error');
            return;
        }

        if (this.showAddressSelector && !this.hasNewAddressData) {
            const addressSelector = this.template.querySelector('c-qa-address-book-selector');
            if (addressSelector) {
                const validation = addressSelector.validate();
                if (!validation.isValid) {
                    this.showToast('Error', validation.errorMessage, 'error');
                    return;
                }
            }
        }

        if (this.showNewAddressBookFields) {
            const addressInputs = this.template.querySelectorAll('.address-input');
            let isAddressValid = true;
            
            addressInputs.forEach(inputField => {
                if (!inputField.checkValidity()) {
                    inputField.reportValidity();
                    isAddressValid = false;
                }
            });

            if (!isAddressValid) {
                this.showToast('Error', 'Please complete all required fields for the new address book.', 'error');
                return;
            }
        }

        if (this.selectedContactMode === 'existing' && !this.selectedContactId) {
            this.showToast('Error', 'Please select an existing contact or change the contact assignment method.', 'error');
            return;
        }

        if (this.selectedContactMode === 'manual') {
            const contactInputs = this.template.querySelectorAll('.contact-input');
            let isContactValid = true;
            contactInputs.forEach(input => {
                if (!input.checkValidity()) {
                    input.reportValidity();
                    isContactValid = false;
                }
            });
            if (!isContactValid) {
                this.showToast('Error', 'Please complete all required fields for the new contact.', 'error');
                return;
            }
        }

        this.isLoading = true;
        
        try {
            let finalAccountId = this.selectedAccountId;

            // 1. Resolve Account (Create a New Account if needed)
            if (!this.isExistingAccount && this.isSearchMode) {
                const fields = {};
                fields[ACCOUNT_NAME_FIELD.fieldApiName] = this.searchTerm;
                fields[ACCOUNT_PHONE_FIELD.fieldApiName] = this.phone;
                fields[ACCOUNT_EMAIL_FIELD.fieldApiName] = this.email;
                
                const recordInput = { apiName: ACCOUNT_OBJECT.objectApiName, fields };

                console.group('STEP 1 - CREATE ACCOUNT');
                console.log('Existing Account?', this.isExistingAccount);
                console.log('Fields:', fields);

                const newAccount = await createRecord(recordInput);

                console.log('SUCCESS - Account Created:', newAccount.id);
                console.groupEnd();

                finalAccountId = newAccount.id;
            }

            if (this.recordId && finalAccountId) {
                // 2. Resolve Contact (Create a New Contact if needed)---logic changed to always create contact
                //let finalContactId = this.selectedContactId;
                let finalContactId;
                console.group('STEP 2 - RESOLVE CONTACT');

                if (this.selectedContactMode === 'existing') {
                    finalContactId = this.selectedContactId;
                    console.log('Using Existing Contact:', finalContactId);
                    
                } else if (this.selectedContactMode === 'bidder' && this.bidderContactDetails) {
                    const contactFields = {};
                    contactFields[CONTACT_LASTNAME_FIELD.fieldApiName] = this.bidderContactDetails.Name;
                    contactFields[CONTACT_PHONE_FIELD.fieldApiName] = this.bidderContactDetails.Contact_Number__c;
                    contactFields[CONTACT_EMAIL_FIELD.fieldApiName] = this.bidderContactDetails.Email__c;
                    contactFields[CONTACT_ACCOUNT_FIELD.fieldApiName] = finalAccountId;

                    const newContact = await createRecord({ apiName: CONTACT_OBJECT.objectApiName, fields: contactFields });
                    finalContactId = newContact.id;
                    console.log('Created Contact from Bidder Details:', finalContactId);

                } else if (this.selectedContactMode === 'manual') {
                    const contactFields = {};
                    contactFields[CONTACT_FIRSTNAME_FIELD.fieldApiName] = this.manualContact.FirstName;
                    contactFields[CONTACT_LASTNAME_FIELD.fieldApiName] = this.manualContact.LastName;
                    contactFields[CONTACT_PHONE_FIELD.fieldApiName] = this.manualContact.Phone;
                    contactFields[CONTACT_EMAIL_FIELD.fieldApiName] = this.manualContact.Email;
                    contactFields[CONTACT_ACCOUNT_FIELD.fieldApiName] = finalAccountId;

                    const newContact = await createRecord({ apiName: CONTACT_OBJECT.objectApiName, fields: contactFields });
                    finalContactId = newContact.id;
                    console.log('Created Contact Manually:', finalContactId);
                }
                
                console.groupEnd();
                //}

                // 3. Update the Opportunity to link the Account
                const oppFields = {};
                oppFields[OPP_ID_FIELD.fieldApiName] = this.recordId;
                oppFields[OPP_ACCOUNT_FIELD.fieldApiName] = finalAccountId;
                
                const oppRecordInput = { fields: oppFields };
                
                console.group('STEP 3 - UPDATE OPPORTUNITY');

                console.log('Opportunity Id:', this.recordId);
                console.log('Account:', finalAccountId);

                try { 
                    await updateRecord(oppRecordInput);
                } catch(error){
                    console.log('An error occored while updating opp: ', error.body);
                }
                

                console.log('SUCCESS - Opportunity Updated');
                console.groupEnd();

                // 4. NEW: Create Opportunity Contact Role to link Contact to Opportunity
                if (finalContactId) {
                    try {
                        const ocrFields = {};
                        ocrFields[OCR_OPP_FIELD.fieldApiName] = this.recordId;
                        ocrFields[OCR_CONTACT_FIELD.fieldApiName] = finalContactId;
                        ocrFields[OCR_ISPRIMARY_FIELD.fieldApiName] = true; // Optional: Makes this the primary contact
                        
                        const ocrInput = { apiName: OCR_OBJECT.objectApiName, fields: ocrFields };
                        console.group('STEP 4 - CREATE OCR');

                        console.log({
                            OpportunityId: this.recordId,
                            ContactId: finalContactId
                        });

                        await createRecord(ocrInput);

                        console.log('SUCCESS - OCR Created');
                        console.groupEnd();

                    } catch (ocrError) {
                        // If the Contact Role already exists, Salesforce might throw a duplicate error. 
                        // We catch it so it doesn't stop the rest of the save process.
                        console.warn('Opportunity Contact Role might already exist.', ocrError);
                    }
                }

                // 5. Run the backend logic (Junctions, Address Books, Contact updates)
                console.group('STEP 5 - PROCESS ADDRESS BOOK');

                console.log({
                    accountId: finalAccountId,
                    contactId: finalContactId,
                    opportunityId: this.recordId,
                    selectedAddressBookId: this.selectedAddressBookId
                });

                await processAddressBook({
                    leadId: null,
                    accountId: finalAccountId,
                    contactId: finalContactId,
                    opportunityId: this.recordId,
                    selectedAddressBookId: this.selectedAddressBookId
                });

                console.log('SUCCESS - AddressBookProcessor');
                console.groupEnd();

                if (!this.selectedAddressBookId && this.hasNewAddressData) {
                    console.group('STEP 6 - CREATE ADDRESS BOOK');

                    console.log(JSON.stringify(this.newAddressBook));

                    await createAddressBookAndJunction({
                        accountId: finalAccountId,
                        opportunityId: this.recordId,
                        addressData: this.newAddressBook
                    });

                    console.log('SUCCESS - Address Book Created');
                    console.groupEnd();
                }

                // new step 7
                // Save Product Categories
                if (this.productCategoryRows.length > 0) {

                    const productCategories = this.productCategoryRows.map(row => ({
                        Department_Name__c: row.Department_Name__c,
                        Product_Category__c: row.Product_Category__c,
                        UOM__c: row.UOM__c,
                        Quantity__c: Number(row.Quantity__c),
                        Opportunity__c: this.recordId
                    }));

                    console.group('SAVE PRODUCT CATEGORIES');
                    console.log(productCategories);

                    await createProductCategories({
                        productCategories: productCategories
                    });

                    console.log('SUCCESS - Product Categories Created');
                    console.groupEnd();
                }

                console.group('STEP 7 - FINALIZE AWARD');

                console.log('Opportunity:', this.recordId);

                await finalizeOpportunityAward({
                    awardedOppId: this.recordId
                });

                console.log('SUCCESS - Award Finalized');
                console.groupEnd();

                this.showToast('Success', 'Account, Contact, Address and Product Categories successfully applied! Related opportunities closed.', 'success');
                this.dispatchEvent(new CloseActionScreenEvent());
            }

        } catch (error) {
            console.group('===== HANDLE SAVE ERROR =====');

            console.log('Raw Error:', error);
            console.log('Stringified Error:', JSON.stringify(error, null, 2));

            console.log('Status:', error?.status);
            console.log('Body:', error?.body);
            console.log('Message:', error?.body?.message);
            console.log('Output:', error?.body?.output);
            console.log('Page Errors:', error?.body?.pageErrors);
            console.log('Field Errors:', error?.body?.fieldErrors);

            if (error?.body?.output?.errors) {
                console.table(error.body.output.errors);
            }

            if (error?.body?.output?.fieldErrors) {
                Object.entries(error.body.output.fieldErrors).forEach(([field, errs]) => {
                    console.error(`FIELD ERROR: ${field}`, errs);
                });
            }

            console.groupEnd();

            const msg =
                error?.body?.output?.errors?.[0]?.message ||
                error?.body?.pageErrors?.[0]?.message ||
                (error?.body?.fieldErrors &&
                    Object.values(error.body.fieldErrors).flat()[0]?.message) ||
                error?.body?.message ||
                error?.message ||
                'Unknown error';

            this.showToast('Error saving record', msg, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get showContactSelector() {
        return this.isExistingAccount && !!this.selectedAccountId;
    }

    get noContactsFound() {
        return this.accountContacts.length === 0;
    }

    get contactNotSelected() {
        return this.accountContacts.length > 0 && !this.selectedContactId;
    }

    handleContactChange(event) {
        this.selectedContactId = event.detail.value;
    }

    // Helper method to pull contacts from Apex
    fetchAccountContacts(accountId) {
        this.accountContacts = [];
        this.selectedContactId = null;

        getAccountContacts({ accountId: accountId })
            .then(result => {
                this.accountContacts = result.map(c => {
                    const meta = [c.Email, c.Phone].filter(Boolean).join(' · ');
                    return { 
                        label: meta ? `${c.Name} (${meta})` : c.Name, 
                        value: c.Id 
                    };
                });
            })
            .catch(err => console.error('Error fetching contacts', err));
    }

    // Address Book state variables
    selectedAddressBookId = null;

    get showAddressSelector() {
        return this.isExistingAccount && !!this.selectedAccountId;
    }

    handleAddressSelected(event) {
        this.selectedAddressBookId = event.detail.addressBookId;
    }

    get availableContactModes() {
        let modes = [];
        if (this.bidderContactDetails) {
            modes.push({ label: 'Use Bidder Contact Details', value: 'bidder' });
        }
        if (this.isExistingAccount) {
            modes.push({ label: 'Select Existing Account Contact', value: 'existing' });
        }
        modes.push({ label: 'Create New Contact Manually', value: 'manual' });
        return modes;
    }

    get isContactModeBidder() { return this.selectedContactMode === 'bidder'; }
    get isContactModeExisting() { return this.selectedContactMode === 'existing'; }
    get isContactModeManual() { return this.selectedContactMode === 'manual'; }

    handleContactModeChange(event) {
        this.selectedContactMode = event.detail.value;
    }

    handleManualContactChange(event) {
        const field = event.currentTarget.dataset.field;
        this.manualContact = { ...this.manualContact, [field]: event.target.value };
    }

}
import { LightningElement, api } from 'lwc';
import getAddressBooks from '@salesforce/apex/AddressBookSelectorController.getAddressBooks';

const COLUMNS = [
    { label: 'Name', fieldName: 'Name' },
    { label: 'Street', fieldName: 'Street__c' },
    { label: 'City', fieldName: 'City__c' },
    { label: 'State', fieldName: 'State__c' },
    { label: 'PIN', fieldName: 'PIN__c' },
    { label: 'Country', fieldName: 'Country__c' }
];

export default class QaAddressBookSelector extends LightningElement {
    _accountId;
    @api selectedAddressBookId;
    
    addresses = [];
    selectedRows = [];
    columns = COLUMNS;

    @api
    get accountId() {
        return this._accountId;
    }

    set accountId(value) {
        if (this._accountId === value) {
            return;
        }

        this._accountId = value;

        if (value) {
            this.loadAddresses();
        } else {
            this.addresses = [];
            this.selectedRows = [];
        }
    }

    get hasRecords() {
        return this.addresses && this.addresses.length > 0;
    }

    get noRecords() {
        return !this.hasRecords;
    }

    loadAddresses() {
        getAddressBooks({ accountId: this.accountId })
        .then(result => {
            this.addresses = result || [];
        })
        .catch(error => {
            console.error('Error loading Address Books', error);
            this.addresses = [];
        });
    }

    handleRowSelection(event) {
        const newSelection = event.detail.selectedRows.map(r => r.Id);
        let finalSelection = [];

        if (newSelection.length === 0) {
            finalSelection = [];
        } else if (newSelection.length === 1) {
            finalSelection = newSelection;
        } else {
            const newlySelected = newSelection.find(id => !this.selectedRows.includes(id));
            finalSelection = newlySelected ? [newlySelected] : [newSelection[0]];
        }

        this.selectedRows = finalSelection;
        this.selectedAddressBookId = finalSelection.length ? finalSelection[0] : null;

        // Pass the selection back to bidderAward
        this.dispatchEvent(
            new CustomEvent('addressselected', {
                detail: { addressBookId: this.selectedAddressBookId }
            })
        );
    }

    @api
    validate() {
        if (!this.hasRecords) {
            return { isValid: true };
        }

        if (!this.selectedAddressBookId) {
            return {
                isValid: false,
                errorMessage: 'Please select an Address Book.'
            };
        }

        return { isValid: true };
    }
}
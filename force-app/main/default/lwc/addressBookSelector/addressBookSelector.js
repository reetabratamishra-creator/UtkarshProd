import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';

import getAddressBooks
    from '@salesforce/apex/AddressBookSelectorController.getAddressBooks';

const COLUMNS = [
    {
        label: 'Name',
        fieldName: 'Name'
    },
    {
        label: 'Street',
        fieldName: 'Street__c'
    },
    {
        label: 'City',
        fieldName: 'City__c'
    },
    {
        label: 'State',
        fieldName: 'State__c'
    },
    {
        label: 'PIN',
        fieldName: 'PIN__c'
    },
    {
        label: 'Country',
        fieldName: 'Country__c'
    },
    // {
    //     label: 'Type',
    //     fieldName: 'Type__c'
    // },
    // {
    //     label: 'Primary',
    //     fieldName: 'Primary_Address__c',
    //     type: 'boolean'
    // }
];

export default class AddressBookSelector extends LightningElement {

    _accountId;

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

    // Flow Output
    @api selectedAddressBookId;

    columns = COLUMNS;

    addresses = [];

    selectedRows = [];


    get hasRecords() {
        return this.addresses && this.addresses.length > 0;
    }

    loadAddresses() {

        console.log('Calling apex for address book accid: ',  this.accountId);
        getAddressBooks({
            accountId: this.accountId
        })
        .then(result => {
            this.addresses = result || [];
        })
        .catch(error => {
            // eslint-disable-next-line no-console
            console.error('Error loading Address Books', error);
            this.addresses = [];
        });
    }

    handleRowSelection(event) {

        const newSelection = event.detail.selectedRows.map(r => r.Id);

        let finalSelection = [];

        if (newSelection.length === 0) {
            // User deselected everything
            finalSelection = [];
        }
        else if (newSelection.length === 1) {
            // Normal single selection
            finalSelection = newSelection;
        }
        else {
            // Find the newly checked row
            const newlySelected = newSelection.find(
                id => !this.selectedRows.includes(id)
            );

            finalSelection = newlySelected
                ? [newlySelected]
                : [newSelection[0]];
        }

        this.selectedRows = finalSelection;
        this.selectedAddressBookId =
            finalSelection.length ? finalSelection[0] : null;

        this.dispatchEvent(
            new CustomEvent('addressselected', {
                detail: {
                    addressBookId: this.selectedAddressBookId
                }
            })
        );
    }

    @api
    validate() {

        // No existing Address Books -> allow Flow to continue
        if (!this.hasRecords) {
            return { isValid: true };
        }

        // Require a selection
        if (!this.selectedAddressBookId) {
            return {
                isValid: false,
                errorMessage: 'Please select an Address Book.'
            };
        }

        return { isValid: true };
    }

    get noRecords() {
        return !this.hasRecords;
    }
}
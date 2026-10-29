import { LightningElement, api, wire } from 'lwc';
import getAddressBooks from '@salesforce/apex/AddressBookController.getAddressBooks';

const COLUMNS = [
    { label: 'Address Book', fieldName: 'addressBookUrl', type: 'url',
      typeAttributes: { label: { fieldName: 'Name' }, target: '_self' } },
    { label: 'Country', fieldName: 'Country__c' },
    { label: 'State', fieldName: 'State__c' },
    { label: 'City', fieldName: 'City__c' },
    { label: 'Street', fieldName: 'Street__c' },
    { label: 'PIN', fieldName: 'PIN__c' },
    { label: 'Zone', fieldName: 'Zone__c' }
];

export default class OpportunityAddresses extends LightningElement {
    @api recordId;
    columns = COLUMNS;
    addresses = [];
    error;

    @wire(getAddressBooks, { recordId: '$recordId' })
    wiredAddresses({ data, error }) {
        if (data) {
            this.addresses = data.map((rec) => ({
                ...rec,
                addressBookUrl: '/' + rec.Id
            }));
            this.error = undefined;
        } else if (error) {
            this.error = (error.body && error.body.message)
                ? error.body.message
                : JSON.stringify(error);
            // eslint-disable-next-line no-console
            console.error('getAddressBooks error:', error);
            this.addresses = [];
        }
    }

    get recordCount() {
        return this.addresses ? this.addresses.length : 0;
    }

    get cardTitle() {
        return `Opportunity Addresses (${this.recordCount})`;
    }

    get hasAddresses() {
        return this.addresses && this.addresses.length > 0;
    }
}
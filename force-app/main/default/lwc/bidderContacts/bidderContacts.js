import { LightningElement, api, wire } from 'lwc';
import getBidderContacts from '@salesforce/apex/BidderContactController.getBidderContacts';

export default class BidderContacts extends LightningElement {

    @api recordId;

    contacts = [];

    columns = [
        {
            label: 'Bidder Name',
            fieldName: 'recordUrl',
            type: 'url',
            typeAttributes: {
                label: { fieldName: 'Name' },
                target: '_blank'
            }
        },
        {
            label: 'Email',
            fieldName: 'Email__c',
            type: 'text'
        }
    ];

    @wire(getBidderContacts, { tenderId: '$recordId' })
    wiredContacts({ data }) {
        if (data) {
            this.contacts = data.map(row => ({
                ...row,
                recordUrl: '/' + row.Id
            }));
        }
    }

    get hasRecords() {
    return this.contacts && this.contacts.length > 0;
}

get cardTitle() {
    return `Bidders Contact Details (${this.contacts.length})`;
}
}
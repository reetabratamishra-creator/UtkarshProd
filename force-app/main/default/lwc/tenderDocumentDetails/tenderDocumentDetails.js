import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getDocuments from '@salesforce/apex/TenderDocumentDetailsController.getDocuments';

const COLUMNS = [
    {
        label: 'Tender Doc',
        fieldName: 'recordUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'Name' },
            target: '_blank'
        }
    },
    { label: 'Name', fieldName: 'Name__c', type: 'text' },
    { label: 'Type', fieldName: 'Type__c', type: 'text' },
    {
        label: 'Download URL',
        type: 'button',
        typeAttributes: {
            label: 'Download File',
            name: 'download',
            title: 'Download File',
            variant: 'brand-outline',
            iconName: 'utility:download',
            disabled: { fieldName: 'isDisabled' }
        }
    }
];

export default class TenderDocumentDetails extends LightningElement {
    @api recordId;
    columns = COLUMNS;
    documents = [];
    lastUpdated = 'a few seconds ago';
    wiredResult;

    @wire(getDocuments, { recordId: '$recordId' })
    wiredDocs(result) {
        this.wiredResult = result;
        const { data, error } = result;

        if (data) {
            this.documents = data.map(doc => {
                const url = this.resolveUrl(doc);
                return {
                    ...doc,
                    recordUrl: `/${doc.Id}`,
                    resolvedUrl: url,
                    isDisabled: !url
                };
            });
            this.lastUpdated = 'a few seconds ago';
        } else if (error) {
            console.error('Error fetching Tender Document Details', error);
            this.documents = [];
        }
    }

    resolveUrl(doc) {
        const shortUrl = doc.Download_URL__c;
        const longUrl = doc.Download_URL_Text__c;

        if (shortUrl && shortUrl.trim() !== '') {
            return this.normalize(shortUrl);
        }
        if (longUrl && longUrl.trim() !== '') {
            return this.normalize(longUrl);
        }
        return null;
    }

    normalize(url) {
        let cleanUrl = url.trim();
        if (!/^https?:\/\//i.test(cleanUrl)) {
            cleanUrl = 'https://' + cleanUrl;
        }
        return cleanUrl;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'download') {
            if (row.resolvedUrl) {
                window.open(row.resolvedUrl, '_blank');
            } else {
                console.warn('No download URL available for this document');
            }
        }
    }

    handleRefresh() {
        refreshApex(this.wiredResult);
    }
    renderedCallback() {
    if (!this.heightSet) {
        const table = this.template.querySelector('lightning-datatable');
        if (table) {
            table.style.height = '260px';
            this.heightSet = true;
        }
    }
}
}
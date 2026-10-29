import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

import ZIP_TEXT_FIELD from '@salesforce/schema/Tender__c.Zip_Document_Download_Text__c';
import ZIP_FIELD from '@salesforce/schema/Tender__c.Zip_Document_Download__c';
import SOURCE_TEXT_FIELD from '@salesforce/schema/Tender__c.Source_URL_in_Text__c';
import SOURCE_FIELD from '@salesforce/schema/Tender__c.Source_URL__c'; // adjust API name if different

const FIELDS = [ZIP_TEXT_FIELD, ZIP_FIELD, SOURCE_TEXT_FIELD, SOURCE_FIELD];

export default class TenderFileLinks extends LightningElement {
    @api recordId;
    record;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ data, error }) {
        if (data) {
            this.record = data;
        } else if (error) {
            console.error('Error loading Tender record', error);
        }
    }

    // ---- Zip URL (prefers text field, falls back to c field) ----
    get zipUrl() {
        if (!this.record) return null;
        const textVal = this.getFieldValue(ZIP_TEXT_FIELD);
        const fallbackVal = this.getFieldValue(ZIP_FIELD);
        return this.normalizeUrl(textVal) || this.normalizeUrl(fallbackVal);
    }

    // ---- Source URL (prefers text field, falls back to c field) ----
    get sourceUrl() {
        if (!this.record) return null;
        const textVal = this.getFieldValue(SOURCE_TEXT_FIELD);
        const fallbackVal = this.getFieldValue(SOURCE_FIELD);
        return this.normalizeUrl(textVal) || this.normalizeUrl(fallbackVal);
    }

    get hasAnyLink() {
        return !!(this.zipUrl || this.sourceUrl);
    }

    getFieldValue(fieldReference) {
        return this.record?.fields?.[fieldReference.fieldApiName]?.value;
    }

    normalizeUrl(value) {
        if (!value || typeof value !== 'string' || value.trim() === '') {
            return null;
        }
        let url = value.trim();
        // add https:// if the stored value has no protocol
        if (!/^https?:\/\//i.test(url)) {
            url = 'https://' + url;
        }
        return url;
    }

    handleZipClick() {
        if (this.zipUrl) {
            window.open(this.zipUrl, '_blank');
        }
    }

    handleSourceClick() {
        if (this.sourceUrl) {
            window.open(this.sourceUrl, '_blank');
        }
    }
}
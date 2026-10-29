import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import ZIP_TEXT_FIELD from '@salesforce/schema/Project__c.Tender__r.Zip_Document_Download_Text__c';
import ZIP_FIELD from '@salesforce/schema/Project__c.Tender__r.Zip_Document_Download__c';
import SOURCE_TEXT_FIELD from '@salesforce/schema/Project__c.Tender__r.Source_URL_in_Text__c';
import SOURCE_FIELD from '@salesforce/schema/Project__c.Tender__r.Source_URL__c';

const FIELDS = [ZIP_TEXT_FIELD, ZIP_FIELD, SOURCE_TEXT_FIELD, SOURCE_FIELD];

export default class ProjectFileLinks extends LightningElement {
    @api recordId; // This is now the Project__c Id
    record;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ data, error }) {
        if (data) {
            this.record = data;
        } else if (error) {
            console.error('Error loading Project/Tender record', error);
        }
    }

    // ---- Zip URL ----
    get zipUrl() {
        if (!this.record) return null;
        // getFieldValue safely extracts the value, even across relationships
        const textVal = getFieldValue(this.record, ZIP_TEXT_FIELD);
        const fallbackVal = getFieldValue(this.record, ZIP_FIELD);
        return this.normalizeUrl(textVal) || this.normalizeUrl(fallbackVal);
    }

    // ---- Source URL ----
    get sourceUrl() {
        if (!this.record) return null;
        const textVal = getFieldValue(this.record, SOURCE_TEXT_FIELD);
        const fallbackVal = getFieldValue(this.record, SOURCE_FIELD);
        return this.normalizeUrl(textVal) || this.normalizeUrl(fallbackVal);
    }

    get hasAnyLink() {
        return !!(this.zipUrl || this.sourceUrl);
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
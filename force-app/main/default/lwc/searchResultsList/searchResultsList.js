import { LightningElement, api } from 'lwc';

export default class SearchResultsList extends LightningElement {
    @api value; // array of SearchResult

    get records() {
        return this.value || [];
    }

    get hasRecords() {
        return this.records.length > 0;
    }
}
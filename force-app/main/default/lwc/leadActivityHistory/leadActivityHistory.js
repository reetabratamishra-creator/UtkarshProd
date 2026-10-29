import { LightningElement, api, wire } from 'lwc';
import getActivityHistories from '@salesforce/apex/LeadActivityHistoryController.getActivityHistories';

const COLUMNS = [
    { label: 'Activity Type', fieldName: 'activityType', type: 'text' },
    { label: 'Subject', fieldName: 'activitySubject', type: 'text' },
    { label: 'Field', fieldName: 'fieldName', type: 'text' },
    { label: 'Old Value', fieldName: 'oldValue', type: 'text' },
    { label: 'New Value', fieldName: 'newValue', type: 'text' },
    { label: 'Changed Date', fieldName: 'changedDate', type: 'date', typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
    { label: 'Changed By', fieldName: 'changedBy', type: 'text' }
    
];

export default class LeadActivityHistory extends LightningElement {
    @api recordId; // Lead Id from context
    columns = COLUMNS;
    historyData = [];

    @wire(getActivityHistories, { leadId: '$recordId' })
    wiredHistory({ data, error }) {
        if (data) {
            this.historyData = data;
            console.log('Leadid', this.recordId);
            console.log('History Data', JSON.stringify(this.historyData));
        } else if (error) {
            this.historyData = [];
            console.error('Error fetching activity histories:', error);
        }
    }

    get hasRecords() {
        return this.historyData && this.historyData.length > 0;
    }
}
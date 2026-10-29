import { LightningElement, api, wire } from 'lwc';
import getActivityHistories from '@salesforce/apex/OpportunityActivityHistoryController.getActivityHistories';

const COLUMNS = [
    { label: 'Activity Type', fieldName: 'activityType', type: 'text' },
    { label: 'Subject', fieldName: 'activitySubject', type: 'text' },
    { label: 'Field', fieldName: 'fieldName', type: 'text' },
    { label: 'Old Value', fieldName: 'oldValue', type: 'text' },
    { label: 'New Value', fieldName: 'newValue', type: 'text' },
    {
        label: 'Changed Date',
        fieldName: 'changedDate',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        }
    },
    { label: 'Changed By', fieldName: 'changedBy', type: 'text' }
];

export default class OpportunityActivityHistory extends LightningElement {
    @api recordId; // Opportunity Id from context

    columns = COLUMNS;
    historyData = [];

    @wire(getActivityHistories, { opportunityId: '$recordId' })
    wiredHistory({ data, error }) {
        if (data) {
            this.historyData = data;
            console.log('Opportunity Id', this.recordId);
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
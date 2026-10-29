import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

import IS_RESCHEDULED from '@salesforce/schema/Task_Log__c.isRescheduled__c';

const FIELDS = [
    IS_RESCHEDULED,
    'Task_Log__c.Name'
];

export default class TaskLogRecordView extends LightningElement {
    @api recordId;

    @wire(getRecord, {
        recordId: '$recordId',
        fields: FIELDS
    })
    record;

    get showRescheduleReason() {
        return getFieldValue(this.record.data, IS_RESCHEDULED);
    }

    get activeSections() {
        return ['Information', 'SystemInformation'];
    }
}
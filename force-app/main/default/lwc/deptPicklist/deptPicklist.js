import { LightningElement, api, wire, track } from 'lwc';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import LEAD_OBJECT from '@salesforce/schema/Lead';
import DEPT_FIELD from '@salesforce/schema/Lead.Department_Name__c';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';

export default class DeptPicklist extends LightningElement {
    @api selectedDept;
    @track deptOptions = [];
    recordTypeId;

    @wire(getObjectInfo, { objectApiName: LEAD_OBJECT })
    objectInfo({ data }) {
        if (data) this.recordTypeId = data.defaultRecordTypeId;
    }

    @wire(getPicklistValues, {
        recordTypeId: '$recordTypeId',
        fieldApiName: DEPT_FIELD
    })
    wiredDeptValues({ data }) {
        if (data) {
            this.deptOptions = data.values.map(opt => ({
                label: opt.label,
                value: opt.value
            }));
        }
    }

    handleDeptChange(event) {
        this.selectedDept = event.detail.value;
        this.dispatchEvent(
            new FlowAttributeChangeEvent('selectedDept', this.selectedDept)
        );
    }
}
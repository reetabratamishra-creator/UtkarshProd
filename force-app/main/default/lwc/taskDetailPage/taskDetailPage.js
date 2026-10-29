import { LightningElement, api, wire, track } from 'lwc';
import getTaskLayout from '@salesforce/apex/TaskRecordDetailController.getTaskLayout';

export default class TaskDetailPage extends LightningElement {

    @api recordId;
    @track sections = [];

    @wire(getTaskLayout, { recordId: '$recordId' })
    wiredLayout({ data, error }) {

        if (data) {
            console.log('*****line 13', data);
            this.sections = data.map(section => {

                const fields = (section.fields || [])
                .filter(f => {
                    // Hide Reschedule Reason when it has no value
                    if (f.label === 'Reschedule Reason') {
                        return f.value !== null && f.value !== undefined && f.value !== '';
                    }
                    return true;
                })
                .map(f => ({
                    ...f,

                    // lookup navigation link
                    recordUrl: f.recordId ? '/' + f.recordId : null
                }));

                let rows = [];

                for (let i = 0; i < fields.length; i += 2) {
                    rows.push({
                        key: section.sectionName + i,
                        leftField: fields[i],
                        rightField: fields[i + 1] || null
                    });
                }

                return {
                    ...section,
                    isExpanded: true,
                    iconName: 'utility:chevrondown',
                    rows
                };
            });

        } else if (error) {
            this.sections = [];
            console.error(error);
        }
    }

    toggleSection(event) {
        const name = event.currentTarget.dataset.section;

        this.sections = this.sections.map(sec => {
            if (sec.sectionName === name) {
                const expanded = !sec.isExpanded;
                return {
                    ...sec,
                    isExpanded: expanded,
                    iconName: expanded ? 'utility:chevrondown' : 'utility:chevronright'
                };
            }
            return sec;
        });
    }
}
import { LightningElement, api, wire, track } from 'lwc';
import getEventLayout from '@salesforce/apex/EventRecordDetailController.getEventLayout';

export default class EventDetailPage extends LightningElement {

    @api recordId;
    @track sections = [];

    @wire(getEventLayout, { recordId: '$recordId' })
    wiredLayout({ data, error }) {
        console.log('Data: ', data);
        if (data) {
            this.sections = data.map(section => {
                const fields = (section.fields || []).map(f => ({
                    ...f,
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
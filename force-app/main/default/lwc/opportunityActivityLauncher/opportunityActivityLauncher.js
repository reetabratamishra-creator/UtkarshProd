import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { refreshApex } from '@salesforce/apex';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import USER_ID from '@salesforce/user/Id';

import TASK_LOG_OBJECT from '@salesforce/schema/Task_Log__c';
import VISIT_TYPE_FIELD from '@salesforce/schema/Task_Log__c.Visit_Type__c';
import REASON_FIELD from '@salesforce/schema/Task_Log__c.Reason_for_Visit__c';

import getOpenStatus from '@salesforce/apex/OpportunityActivityLauncherController.getOpenStatus';
import getAssignableUsers from '@salesforce/apex/OpportunityActivityLauncherController.getAssignableUsers';
import createCall from '@salesforce/apex/OpportunityActivityLauncherController.createCall';
import createEvent from '@salesforce/apex/OpportunityActivityLauncherController.createEvent';
import createVisit from '@salesforce/apex/OpportunityActivityLauncherController.createVisit';

const MENU = 'menu';

export default class OpportunityActivityLauncher extends LightningElement {
    @api recordId; // Opportunity Id

    view = MENU;
    saving = false;

    callOpen = false;
    eventOpen = false;
    visitOpen = false;

    assignableUsers = [];

    @track call = { subject: '', date: '', time: '', comments: '', assignedTo: USER_ID };
    @track event = { subject: '', comments: '', start: '', end: '', assignedTo: USER_ID };
    @track visit = { visitType: '', reason: '', scheduleDate: '', assignedTo: USER_ID };

    _statusResult;
    _defaultsApplied = false;

    // ---------- wires ----------
    @wire(getOpenStatus, { opportunityId: '$recordId' })
    wiredStatus(result) {
        this._statusResult = result;
        if (result.data) {
            this.callOpen = result.data.callOpen;
            this.eventOpen = result.data.eventOpen;
            this.visitOpen = result.data.visitOpen;
        }
    }

    @wire(getAssignableUsers, { opportunityId: '$recordId' })
    wiredUsers({ data, error }) {
        if (data) {
            this.assignableUsers = data;
            if (!this._defaultsApplied && data.length) {
                this._defaultsApplied = true;
                const me = data.find((u) => u.id === USER_ID);
                const defaultId = me ? me.id : data[0].id;
                this.call = { ...this.call, assignedTo: defaultId };
                this.event = { ...this.event, assignedTo: defaultId };
                this.visit = { ...this.visit, assignedTo: defaultId };
            }
        } else if (error) {
            const msg = error.body && error.body.message ? error.body.message : 'Unknown error';
            this.toast('Could not load assignable users', msg, 'error');
            // eslint-disable-next-line no-console
            console.error('getAssignableUsers error', error);
        }
    }

    @wire(getObjectInfo, { objectApiName: TASK_LOG_OBJECT })
    taskLogInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$taskLogInfo.data.defaultRecordTypeId',
        fieldApiName: VISIT_TYPE_FIELD
    })
    visitTypePicklist;

    @wire(getPicklistValues, {
        recordTypeId: '$taskLogInfo.data.defaultRecordTypeId',
        fieldApiName: REASON_FIELD
    })
    reasonPicklist;

    // ---------- view getters ----------
    get showMenu() { return this.view === MENU; }
    get showCallForm() { return this.view === 'call'; }
    get showEventForm() { return this.view === 'event'; }
    get showVisitForm() { return this.view === 'visit'; }

    get visitTypeOptions() {
        return this.visitTypePicklist && this.visitTypePicklist.data
            ? this.visitTypePicklist.data.values.map((v) => ({ label: v.label, value: v.value }))
            : [];
    }

    get reasonOptions() {
        return this.reasonPicklist && this.reasonPicklist.data
            ? this.reasonPicklist.data.values.map((v) => ({ label: v.label, value: v.value }))
            : [];
    }

    get assignableUserOptions() {
        return (this.assignableUsers || []).map((u) => ({ label: u.name, value: u.id }));
    }
    get hasAssignees() { return this.assignableUserOptions.length > 0; }

    // ---------- no past dates ----------
    get nowLocal() {
        const d = new Date();
        const pad = (n) => String(n).padStart(2, '0');
        return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
            + `T${pad(d.getHours())}:${pad(d.getMinutes())}`;
    }
    get todayDate() {
        const d = new Date();
        const pad = (n) => String(n).padStart(2, '0');
        return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
    }
    get pastCallError() {
        if (!this.call.date || !this.call.time) return false;
        return new Date(this.combineDateTime(this.call.date, this.call.time)).getTime() < Date.now();
    }
    get pastEventError() {
        if (!this.event.start) return false;
        return new Date(this.event.start).getTime() < Date.now();
    }
    get pastVisitError() {
        return this.visit.scheduleDate && this.visit.scheduleDate < this.todayDate;
    }

    // ---------- validity ----------
    get callInvalid() {
        return !this.call.subject || !this.call.date || !this.call.time
            || (this.hasAssignees && !this.call.assignedTo)
            || this.pastCallError;
    }
    get eventInvalid() {
        if (!this.event.subject || !this.event.start || !this.event.end) return true;
        if (this.hasAssignees && !this.event.assignedTo) return true;
        if (this.pastEventError) return true;
        return new Date(this.event.end) <= new Date(this.event.start);
    }
    get visitInvalid() {
        return !this.visit.visitType || !this.visit.reason || !this.visit.scheduleDate
            || (this.hasAssignees && !this.visit.assignedTo)
            || this.pastVisitError;
    }

    // ---------- navigation ----------
    selectCall() { this.view = 'call'; }
    selectEvent() { this.view = 'event'; }
    selectVisit() { this.view = 'visit'; }
    backToMenu() { this.view = MENU; }

    // ---------- change handlers ----------
    handleCallChange(e) {
        this.call = { ...this.call, [e.target.dataset.field]: e.target.value };
    }
    handleEventChange(e) {
        this.event = { ...this.event, [e.target.dataset.field]: e.target.value };
    }
    handleVisitChange(e) {
        this.visit = { ...this.visit, [e.target.dataset.field]: e.target.value };
    }

    combineDateTime(dateStr, timeStr) {
        const [y, m, d] = dateStr.split('-').map(Number);
        const [hh, mm] = timeStr.substring(0, 5).split(':').map(Number);
        return new Date(y, m - 1, d, hh, mm).toISOString();
    }

    // ---------- save handlers ----------
    async saveCall() {
        if (this.callInvalid) return;
        this.saving = true;
        try {
            await createCall({
                opportunityId: this.recordId,
                subject: this.call.subject,
                followUp: this.combineDateTime(this.call.date, this.call.time),
                comments: this.call.comments,
                assignedToId: this.call.assignedTo || null
            });
            await this.finish('Call created');
        } catch (err) {
            this.fail(err);
        }
    }

    async saveEvent() {
        if (this.eventInvalid) return;
        this.saving = true;
        try {
            await createEvent({
                opportunityId: this.recordId,
                subject: this.event.subject,
                comments: this.event.comments,
                startDt: this.event.start,
                endDt: this.event.end,
                assignedToId: this.event.assignedTo || null
            });
            await this.finish('Event created');
        } catch (err) {
            this.fail(err);
        }
    }

    async saveVisit() {
        if (this.visitInvalid) return;
        this.saving = true;
        try {
            await createVisit({
                opportunityId: this.recordId,
                visitType: this.visit.visitType,
                reason: this.visit.reason,
                scheduleDate: this.visit.scheduleDate,
                assignedToId: this.visit.assignedTo || null
            });
            await this.finish('Visit created');
        } catch (err) {
            this.fail(err);
        }
    }

    // ---------- helpers ----------
    async finish(msg) {
        this.saving = false;
        this.toast('Success', msg, 'success');
        this.resetForms();
        this.view = MENU;
        if (this._statusResult) {
            await refreshApex(this._statusResult);
        }
    }

    fail(err) {
        this.saving = false;
        const msg =
            err && err.body && err.body.message ? err.body.message : 'Unexpected error';
        this.toast('Error', msg, 'error');
    }

    resetForms() {
        const owner = this._defaultsApplied && this.assignableUsers.length
            ? (this.assignableUsers.find((u) => u.id === USER_ID) || this.assignableUsers[0]).id
            : USER_ID;
        this.call = { subject: '', date: '', time: '', comments: '', assignedTo: owner };
        this.event = { subject: '', comments: '', start: '', end: '', assignedTo: owner };
        this.visit = { visitType: '', reason: '', scheduleDate: '', assignedTo: owner };
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}
import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import { CurrentPageReference } from 'lightning/navigation';

import getCaseContext from '@salesforce/apex/CaseActivityController.getCaseContext';
import createCallTask from '@salesforce/apex/CaseActivityController.createCallTask';
import createMeetingEvent from '@salesforce/apex/CaseActivityController.createMeetingEvent';

const CALL = 'call';
const EVENT = 'event';

export default class CaseActivityLauncher extends LightningElement {

    /* ------------------------------------------------------------------
     *  Case Id resolution
     *  A ScreenAction quick action injects @api recordId. The page-reference
     *  fallback keeps the component working when it is launched from an Aura
     *  wrapper, a URL-addressable page, or a Lightning App Page instead.
     * ------------------------------------------------------------------ */
    _injectedId;
    _pageRefId;
    caseId;

    @api
    get recordId() {
        return this._injectedId;
    }
    set recordId(value) {
        this._injectedId = value;
        this.resolveCaseId();
    }

    @wire(CurrentPageReference)
    capturePageRef(pageRef) {
        if (pageRef) {
            this._pageRefId = pageRef.state?.recordId
                || pageRef.state?.c__recordId
                || pageRef.attributes?.recordId;
            this.resolveCaseId();
        }
    }

    resolveCaseId() {
        const resolved = this._injectedId || this._pageRefId;
        if (resolved && resolved !== this.caseId) {
            this.caseId = resolved;
        }
    }

    /* ------------------------------------------------------------------
     *  State
     * ------------------------------------------------------------------ */
    mode = CALL;

    subject = '';
    comments = '';
    followUpDateTime = null;
    startDateTime = null;
    endDateTime = null;

    ownerName;
    ownerIsQueue = false;
    isBusy = false;

    @wire(getCaseContext, { caseId: '$caseId' })
    wiredContext({ data, error }) {
        if (data) {
            this.ownerName = data.ownerName;
            this.ownerIsQueue = data.ownerIsQueue;
            if (this.ownerIsQueue) {
                this.toast('Heads up',
                    `This Case is owned by the queue "${data.ownerName}". ` +
                    'Accept ownership before logging an activity.', 'warning');
            }
        } else if (error && this.caseId) {
            this.toast('Error', msgOf(error), 'error');
        }
    }

    /* ------------------------------------------------------------------
     *  Getters
     * ------------------------------------------------------------------ */
    get isCall() { return this.mode === CALL; }
    get callVariant() { return this.isCall ? 'brand' : 'neutral'; }
    get eventVariant() { return this.isCall ? 'neutral' : 'brand'; }
    get modeLabel() { return this.isCall ? 'call' : 'meeting'; }
    get saveLabel() { return this.isCall ? 'Create Call' : 'Create Meeting'; }
    get saveDisabled() { return this.isBusy || !this.caseId; }

    /**
     * Start of TODAY in the user's local timezone. Feeds the `min` attribute on
     * both datetime pickers so a past date cannot even be selected. Mirrors the
     * Apex rule, which compares on the DATE part only - an earlier hour today
     * is still allowed.
     */
    get minDateTime() {
        const startOfToday = new Date();
        startOfToday.setHours(0, 0, 0, 0);
        return startOfToday.toISOString();
    }

    /* ------------------------------------------------------------------
     *  Handlers
     * ------------------------------------------------------------------ */
    handleModeChange(event) {
        const next = event.currentTarget.dataset.mode;
        if (next === this.mode) {
            return;
        }
        this.mode = next === EVENT ? EVENT : CALL;
        this.clearCustomErrors();
    }

    handleChange(event) {
        this[event.target.dataset.field] = event.target.value;
        if (event.target.dataset.field === 'startDateTime') {
            this.clearCustomErrors();
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleSave() {
        if (!this.caseId) {
            this.toast('Error', 'No Case record was supplied to this action.', 'error');
            return;
        }
        if (!this.validate()) {
            return;
        }

        this.isBusy = true;
        try {
            if (this.isCall) {
                await createCallTask({
                    caseId: this.caseId,
                    subject: this.subject,
                    followUpDateTime: this.followUpDateTime,
                    comments: this.comments
                });
                this.toast('Success', 'Call task created and assigned to the Case owner.', 'success');
            } else {
                await createMeetingEvent({
                    caseId: this.caseId,
                    subject: this.subject,
                    startDateTime: this.startDateTime,
                    endDateTime: this.endDateTime,
                    comments: this.comments
                });
                this.toast('Success', 'Meeting created and assigned to the Case owner.', 'success');
            }
            this.dispatchEvent(new RefreshEvent());
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (err) {
            this.toast('Error', msgOf(err), 'error');
        } finally {
            this.isBusy = false;
        }
    }

    /* ------------------------------------------------------------------
     *  Validation
     * ------------------------------------------------------------------ */
    validate() {
        const inputs = [...this.template.querySelectorAll('lightning-input, lightning-textarea')];
        let valid = inputs.reduce((acc, input) => input.reportValidity() && acc, true);

        // Client-side mirror of the Apex rule so the user is not round-tripped.
        if (valid && !this.isCall && this.startDateTime && this.endDateTime &&
            new Date(this.endDateTime) <= new Date(this.startDateTime)) {
            const endInput = this.template.querySelector('[data-field="endDateTime"]');
            endInput.setCustomValidity('End Date & Time must be later than the Start Date & Time.');
            endInput.reportValidity();
            valid = false;
        }
        return valid;
    }

    clearCustomErrors() {
        const endInput = this.template.querySelector('[data-field="endDateTime"]');
        if (endInput) {
            endInput.setCustomValidity('');
            endInput.reportValidity();
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant,
            mode: variant === 'error' ? 'sticky' : 'dismissable'
        }));
    }
}

/**
 * Reads every shape a Salesforce error can arrive in, not just body.message.
 */
function msgOf(err) {
    // eslint-disable-next-line no-console
    console.error('caseActivityLauncher error:', err);
    const out = [];
    const push = (v) => { if (v && !out.includes(v)) out.push(v); };

    if (!err) return 'Unknown error';
    if (typeof err === 'string') return err;

    const body = err.body || err;

    if (Array.isArray(body)) {
        body.forEach((b) => push(b.message));
    } else if (body) {
        push(body.message);
        if (Array.isArray(body.pageErrors)) {
            body.pageErrors.forEach((e) => push(e.message));
        }
        if (body.fieldErrors) {
            Object.values(body.fieldErrors).forEach((arr) =>
                (arr || []).forEach((e) => push(e.message)));
        }
        if (body.output) {
            if (Array.isArray(body.output.errors)) {
                body.output.errors.forEach((e) => push(e.message));
            }
            if (body.output.fieldErrors) {
                Object.values(body.output.fieldErrors).forEach((arr) =>
                    (arr || []).forEach((e) => push(e.message)));
            }
        }
    }
    push(err.message);
    push(err.statusText);

    return out.length ? out.join(' | ') : 'Unexpected error';
}
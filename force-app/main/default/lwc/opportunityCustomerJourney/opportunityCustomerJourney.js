import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';

import getContext from '@salesforce/apex/OpportunityCustomerJourneyController.getContext';
import getEligibleDealers from '@salesforce/apex/OpportunityCustomerJourneyController.getEligibleDealers';
import saveCustomerJourney from '@salesforce/apex/OpportunityCustomerJourneyController.saveCustomerJourney';
import createFollowUpTask from '@salesforce/apex/OpportunityCustomerJourneyController.createFollowUpTask';

const DIRECT = 'Direct Business';
const DEALER = 'Refer to Dealer';
const NEGOTIATION = 'Negotiation';

export default class OpportunityCustomerJourney extends LightningElement {
    @api recordId; // Opportunity Id

    ctx = {};
    saving = false;

    step = 'JOURNEY';
    selectedJourney = '';
    selectedSubStage = '';

    dealerId = null;
    dealerError = false;
    amount = null;
    closeDate = null;
    valuesFromQuote = false;

    taskType = '';
    followUpDate = '';
    followUpTime = '';

    eligibleDealerIds = [];

    _ctxResult;

    @wire(getContext, { opportunityId: '$recordId' })
    wiredContext(result) {
        this._ctxResult = result;
        if (result.data) {
            this.ctx = result.data;
        }
    }

    @wire(getEligibleDealers, { opportunityId: '$recordId' })
    wiredDealers({ data }) {
        if (data) {
            this.eligibleDealerIds = data.map((a) => a.Id);
        }
    }

    // ---------- options ----------
    get journeyOptions() {
        return [
            { label: DIRECT, value: DIRECT },
            { label: DEALER, value: DEALER }
        ];
    }
    get taskTypeOptions() {
        return [
            { label: 'Meeting', value: 'Meeting' },
            { label: 'Call', value: 'Call' },
            { label: 'Visit', value: 'Visit' }
        ];
    }
    get subStageOptions() {
        return this.ctx && this.ctx.subStageOptions ? this.ctx.subStageOptions : [];
    }
    get currentJourneyLabel() {
        return this.ctx ? this.ctx.currentJourney : null;
    }

    // ---------- step visibility ----------
    get showJourneyStep() { return this.step === 'JOURNEY'; }
    get showDealerStep() { return this.step === 'DEALER'; }
    get showConfirmDirectStep() { return this.step === 'CONFIRM_DIRECT'; }
    get showFollowUpStep() { return this.step === 'FOLLOWUP'; }

    // Show the Sub Stage picker only after a journey is chosen, and only when the
    // Opportunity's Sub_Stage__c is genuinely empty. Checks the actual value that
    // came back from getContext rather than a separate boolean flag.
    get showSubStage() {
        if (!this.ctx || !this.selectedJourney) {
            return false;
        }
        const v = this.ctx.subStage;
        return v === null || v === undefined || v === '';
    }

    get nextDisabled() {
        if (!this.selectedJourney) return true;
        if (this.showSubStage && !this.selectedSubStage) return true;
        return false;
    }

    /**
     * Dealer picker filter:
     *   1. RecordTypeId = Dealer record type   (always enforced)
     *   2. Id in (department-matched dealers)   (added only when such dealers exist)
     * If the department match yields nothing (or hasn't loaded yet) we keep just
     * the record-type filter so dealers are always visible; the department rule is
     * still enforced server-side in validateDealer on save.
     */
    get dealerFilter() {
        if (!this.ctx || !this.ctx.dealerRecordTypeId) {
            return undefined;
        }

        const criteria = [
            {
                fieldPath: 'RecordTypeId',
                operator: 'eq',
                value: this.ctx.dealerRecordTypeId
            }
        ];

        if (this.eligibleDealerIds && this.eligibleDealerIds.length) {
            criteria.push({
                fieldPath: 'Id',
                operator: 'in',
                value: this.eligibleDealerIds
            });
        }

        return {
            criteria,
            filterLogic: criteria.length > 1 ? '1 AND 2' : '1'
        };
    }

    get dealerHelpText() {
        if (!this.eligibleDealerIds || this.eligibleDealerIds.length === 0) {
            return 'No dealers match this Opportunity department.';
        }
        return this.ctx && this.ctx.departmentName
            ? `Showing dealers for department: ${this.ctx.departmentName}`
            : 'Showing all dealers (no department set on this Opportunity)';
    }

    // Direct-Business confirm screen text
    get directTargetStage() {
        return this.ctx && this.ctx.hasQuote ? NEGOTIATION : 'Nurture';
    }
    get quotePresenceText() {
        return this.ctx && this.ctx.hasQuote ? 'an approved quotation exists' : 'no approved quotation present';
    }

    get followUpInvalid() {
        return !this.taskType || !this.followUpDate || !this.followUpTime;
    }

    // ---------- field handlers ----------
    handleJourneyChange(e) { this.selectedJourney = e.detail.value; }
    handleSubStageChange(e) { this.selectedSubStage = e.detail.value; }
    handleDealerChange(e) {
        this.dealerId = e.detail.recordId;
        this.dealerError = false;
    }
    handleAmountChange(e) { this.amount = e.target.value; }
    handleCloseDateChange(e) { this.closeDate = e.target.value; }
    handleTaskTypeChange(e) { this.taskType = e.detail.value; }
    handleFollowUpDateChange(e) { this.followUpDate = e.target.value; }
    handleFollowUpTimeChange(e) { this.followUpTime = e.target.value; }

    // ---------- navigation ----------
    handleNext() {
        if (this.nextDisabled) return;

        if (this.selectedJourney === DEALER) {
            // Refer to Dealer -> Negotiation. Prefill deal fields from the
            // Approved quote when present; otherwise fall back to the
            // Opportunity's own EDV/ECD so any existing values carry over.
            if (this.ctx.hasQuote) {
                this.amount = this.ctx.quoteAmount;
                this.closeDate = this.ctx.quoteCloseDate;
                this.valuesFromQuote = true;
            } else {
                this.amount = this.ctx.amount != null ? this.ctx.amount : null;
                this.closeDate = this.ctx.closeDate || null;
                this.valuesFromQuote = false;
            }
            this.dealerId = this.ctx.dealerAccountId;
            this.step = 'DEALER';
        } else {
            // Direct Business
            if (this.ctx.currentJourney === DEALER || this.ctx.stageName === NEGOTIATION) {
                // Show a confirm so the user sees the resulting stage (Negotiation vs Nurture).
                this.step = 'CONFIRM_DIRECT';
            } else {
                // In Nurture: nothing to prompt for (reqs 1 & 5).
                this.doSave();
            }
        }
    }

    backToJourney() {
        this.step = 'JOURNEY';
        this.dealerError = false;
    }

    // ---------- saves ----------
    saveDealer() {
        if (!this.dealerId) {
            this.dealerError = true;
            return;
        }
        // EDV/ECD are always required (prefilled from the quote when one exists, still editable).
        if (this.amount == null || this.amount === '' || !this.closeDate) {
            this.toast('Error', 'Expected Deal Value and Closure Date are required.', 'error');
            return;
        }
        this.doSave();
    }

    confirmDirect() {
        this.doSave();
    }

    async doSave() {
        this.saving = true;
        try {
            const res = await saveCustomerJourney({
                opportunityId: this.recordId,
                newJourney: this.selectedJourney,
                dealerAccountId: this.dealerId || null,
                amount: this.amount != null && this.amount !== '' ? this.amount : null,
                closeDate: this.closeDate || null,
                subStage: this.selectedSubStage || null
            });
            this.saving = false;
            this.toast('Success', 'Customer Journey updated.', 'success');

            if (res && res.needsFollowUpTask) {
                this.step = 'FOLLOWUP';
            } else {
                this.notifyAndClose();
            }
        } catch (err) {
            this.fail(err);
        }
    }

    async saveFollowUp() {
        if (this.followUpInvalid) return;
        this.saving = true;
        try {
            await createFollowUpTask({
                opportunityId: this.recordId,
                taskType: this.taskType,
                followUp: this.combineDateTime(this.followUpDate, this.followUpTime)
            });
            this.saving = false;
            this.toast('Success', 'Follow-up task created.', 'success');
            this.notifyAndClose();
        } catch (err) {
            this.fail(err);
        }
    }

    // ---------- helpers ----------
    combineDateTime(dateStr, timeStr) {
        const [y, m, d] = dateStr.split('-').map(Number);
        const [hh, mm] = timeStr.substring(0, 5).split(':').map(Number);
        return new Date(y, m - 1, d, hh, mm).toISOString();
    }

    notifyAndClose() {
        getRecordNotifyChange([{ recordId: this.recordId }]);
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    fail(err) {
        this.saving = false;
        const msg = err && err.body && err.body.message ? err.body.message : 'Unexpected error';
        this.toast('Error', msg, 'error');
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
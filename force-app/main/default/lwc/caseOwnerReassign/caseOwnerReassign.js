import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import getReassignContext from '@salesforce/apex/CaseOwnerReassignController.getReassignContext';
import reassignOwner from '@salesforce/apex/CaseOwnerReassignController.reassignOwner';

export default class CaseOwnerReassign extends LightningElement {
    _recordId;
    _requested = false;

    context;
    selectedOwnerId;
    errorMessage;
    isLoading = true;
    isSaving = false;

    /* ----------------------------------------------------------------
     * recordId arrives asynchronously in a quick action. Loading from
     * connectedCallback can fire before it is set, which sends null to
     * Apex. Loading from the setter guarantees we have the id first.
     * ---------------------------------------------------------------- */
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        this.loadIfReady();
    }

    /* Fallback: console tabs, Aura wrappers and URL-launched actions do not
     * always populate @api recordId, but the page reference carries it. */
    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        if (this._recordId || !pageRef) {
            return;
        }
        const fromPageRef = pageRef.attributes?.recordId ?? pageRef.state?.recordId;
        if (fromPageRef) {
            this._recordId = fromPageRef;
            this.loadIfReady();
        }
    }

    loadIfReady() {
        if (this._recordId && !this._requested) {
            this._requested = true;
            this.loadContext();
        }
    }

    async loadContext() {
        this.isLoading = true;
        this.errorMessage = undefined;
        try {
            this.context = await getReassignContext({ caseId: this._recordId });
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    /* ---------------- getters ---------------- */

    get options() {
        return this.context?.options ?? [];
    }

    get isBlocked() {
        return !!this.context?.blockReason;
    }

    get blockReason() {
        return this.context?.blockReason;
    }

    get showForm() {
        return !!this.context && !this.isBlocked && !this.errorMessage;
    }

    get moduleName() {
        return this.context?.moduleName;
    }

    get currentOwnerDisplay() {
        if (!this.context) {
            return '';
        }
        const level = this.context.currentLevel;
        return level && level !== 'OTHER'
            ? `${this.context.currentOwnerName} (${level})`
            : this.context.currentOwnerName;
    }

    get saveDisabled() {
        return this.isSaving || !this.selectedOwnerId;
    }

    /* ---------------- handlers ---------------- */

    handleChange(event) {
        this.selectedOwnerId = event.detail.value;
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleSave() {
        this.isSaving = true;
        this.errorMessage = undefined;
        try {
            const newOwnerName = await reassignOwner({
                caseId: this._recordId,
                newOwnerId: this.selectedOwnerId
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Owner changed',
                    message: `This Case now belongs to ${newOwnerName}.`,
                    variant: 'success'
                })
            );

            notifyRecordUpdateAvailable([{ recordId: this._recordId }]);
            this.handleClose();
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isSaving = false;
        }
    }

    reduceError(error) {
        return (
            error?.body?.message ||
            error?.body?.pageErrors?.[0]?.message ||
            error?.message ||
            'Something went wrong. Contact your administrator.'
        );
    }
}
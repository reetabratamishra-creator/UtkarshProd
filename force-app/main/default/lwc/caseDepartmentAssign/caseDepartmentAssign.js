import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import getAssignContext from '@salesforce/apex/CaseDepartmentAssignController.getAssignContext';
import getUsersByDepartment from '@salesforce/apex/CaseDepartmentAssignController.getUsersByDepartment';
import assignCase from '@salesforce/apex/CaseDepartmentAssignController.assignCase';

export default class CaseDepartmentAssign extends LightningElement {
    _recordId;
    _requested = false;

    context;
    users = [];
    selectedDepartment;
    selectedUserId;
    errorMessage;
    isLoading = true;
    isLoadingUsers = false;
    isSaving = false;
    usersLoaded = false;

    /* recordId arrives asynchronously in a quick action, so load from the
     * setter rather than connectedCallback. */
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        this.loadIfReady();
    }

    /* Fallback for console tabs, Aura wrappers and URL-launched actions. */
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
            this.context = await getAssignContext({ caseId: this._recordId });
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    /* ---------------- getters ---------------- */

    get departments() {
        return this.context?.departments ?? [];
    }

    get currentOwnerName() {
        return this.context?.currentOwnerName;
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

    get showUserPicker() {
        return this.usersLoaded && this.users.length > 0;
    }

    get showNoUsers() {
        return this.usersLoaded && this.users.length === 0;
    }

    get saveDisabled() {
        return this.isSaving || !this.selectedDepartment || !this.selectedUserId;
    }

    /* ---------------- handlers ---------------- */

    async handleDepartmentChange(event) {
        this.selectedDepartment = event.detail.value;
        this.selectedUserId = undefined;
        this.users = [];
        this.usersLoaded = false;
        this.errorMessage = undefined;

        this.isLoadingUsers = true;
        try {
            this.users = await getUsersByDepartment({ department: this.selectedDepartment });
            this.usersLoaded = true;
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoadingUsers = false;
        }
    }

    handleUserChange(event) {
        this.selectedUserId = event.detail.value;
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleSave() {
        this.isSaving = true;
        this.errorMessage = undefined;
        try {
            const result = await assignCase({
                caseId: this._recordId,
                department: this.selectedDepartment,
                newOwnerId: this.selectedUserId
            });

            const hasWarnings = result?.warnings?.length > 0;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: hasWarnings ? 'Case assigned, with issues' : 'Case assigned',
                    message: hasWarnings
                        ? `${result.ownerName} now owns this case. ${result.warnings.join(' ')}`
                        : `${result.ownerName} now owns this case.`,
                    variant: hasWarnings ? 'warning' : 'success',
                    mode: hasWarnings ? 'sticky' : 'dismissable'
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
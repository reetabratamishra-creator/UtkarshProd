import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import USER_ID from '@salesforce/user/Id';

import getModules from '@salesforce/apex/InternalTicketController.getModules';
import getFormPicklists from '@salesforce/apex/InternalTicketController.getFormPicklists';
import getUserContext from '@salesforce/apex/InternalTicketController.getUserContext';
import createTicket from '@salesforce/apex/InternalTicketController.createTicket';
import discardFile from '@salesforce/apex/InternalTicketController.discardFile';

export default class InternalTicketForm extends NavigationMixin(LightningElement) {
    @track form = {
        moduleId: '',
        department: '',
        priority: '',
        subject: '',
        description: ''
    };

    /**
     * Set by the platform when launched as a record action. The ticket doesn't use the
     * record, but its presence is how the component knows to close the action modal
     * instead of navigating away.
     */
    @api recordId;

    modules = [];
    isSaving = false;
    errorMessage;

    picklists = {};
    picklistIssues = [];

    /** Department comes from the running user when it resolves to exactly one value. */
    isDepartmentLocked = false;
    
    departmentNote;
    lockedDepartment;

    /**
     * Files upload before the ticket exists, staged against the running user's own
     * record, then relinked on save. lightning-file-upload streams straight to
     * Salesforce, so Apex never handles the bytes and size is not a constraint.
     */
    stagingRecordId = USER_ID;
    stagedFiles = [];

    /** True when running inside an action modal rather than as a standalone page. */
    get isAction() {
        return !!this.recordId;
    }

    connectedCallback() {
        this.resetForm();
    }

    // ---------------- Running user ----------------
    /*
    @wire(getUserContext)
    wiredUserContext({ data, error }) {
        if (data) {
            this.isDepartmentLocked = data.locked === true;
            this.departmentNote = data.note;
            if (data.locked && data.department) {
                this.form.department = data.department;
            }
        } else if (error) {
            // Leave the field open rather than blocking the form.
            this.isDepartmentLocked = false;
            this.departmentNote = undefined;
        }
    }
    */
        @wire(getUserContext)
    wiredUserContext({ data, error }) {
        if (data) {
            this.isDepartmentLocked = data.locked === true;
            this.departmentNote = data.note;
            if (data.locked && data.department) {
                this.lockedDepartment = data.department;
                this.form.department = data.department;
            }
        } else if (error) {
            // Leave the field open rather than blocking the form.
            this.isDepartmentLocked = false;
            this.departmentNote = undefined;
            this.lockedDepartment = undefined;
        }
    }

    get departmentDisplay() {
        return this.form.department || '—';
    }
    get hasDepartmentNote() {
        return !!this.departmentNote;
    }

    // ---------------- Modules ----------------
    @wire(getModules)
    wiredModules({ data, error }) {
        if (data) {
            this.modules = data;
        } else if (error) {
            this.modules = [];
            this.errorMessage = `Modules could not be loaded: ${this.reduceError(error)}`;
        }
    }

    get moduleOptions() {
        return this.modules.map((m) => ({ label: m.label, value: m.value }));
    }
    get hasNoModules() {
        return this.modules.length === 0;
    }
    get selectedModule() {
        return this.modules.find((m) => m.value === this.form.moduleId);
    }
    get showAssignee() {
        return !!this.selectedModule;
    }
    get assigneeName() {
        return this.selectedModule?.l1UserName;
    }
    /** No L1 on the matrix row means the ticket falls back to the person raising it. */
    get hasNoAssignee() {
        return !!this.selectedModule && !this.selectedModule.l1UserId;
    }

    // ---------------- Picklists ----------------
    /**
     * Sourced from Apex describe rather than getPicklistValues: the UI API filters
     * by record type, which silently empties fields whose values are not assigned
     * to the default record type.
     */
    @wire(getFormPicklists)
    wiredPicklists({ data, error }) {
        if (data) {
            const byField = {};
            const issues = [];
            data.forEach((field) => {
                byField[field.fieldApiName] = field.options || [];
                if (field.diagnostic) {
                    issues.push(`${field.label || field.fieldApiName} — ${field.diagnostic}`);
                }
            });
            this.picklists = byField;
            this.picklistIssues = issues;
        } else if (error) {
            this.picklists = {};
            this.picklistIssues = [];
            this.errorMessage = `Picklist values could not be loaded: ${this.reduceError(error)}`;
        }
    }

    get hasPicklistIssues() {
        return this.picklistIssues.length > 0;
    }
    get departmentOptions() {
        return this.picklists.Department__c ?? [];
    }
    get priorityOptions() {
        return this.picklists.Priority ?? [];
    }

    // ---------------- Files ----------------
    get hasFiles() {
        return this.stagedFiles.length > 0;
    }
    get maxFileSizeLabel() {
        return '25 MB';
    }

    // ---------------- Handlers ----------------
    handleFieldChange(event) {
        this.form[event.target.dataset.field] = event.detail.value;
    }

    /**
     * The file is already in Salesforce by the time this fires - only its document id
     * is held here, to be linked to the ticket once that exists.
     */
    handleUploadFinished(event) {
        const uploaded = (event.detail.files || []).map((f) => ({
            documentId: f.documentId,
            name: f.name
        }));
        const existing = new Set(this.stagedFiles.map((f) => f.documentId));
        this.stagedFiles = [
            ...this.stagedFiles,
            ...uploaded.filter((f) => !existing.has(f.documentId))
        ];
    }

    /** Removing a staged file deletes it - it was uploaded for real, not just picked. */
    handleRemoveFile(event) {
        const documentId = event.target.name;
        this.stagedFiles = this.stagedFiles.filter((f) => f.documentId !== documentId);
        discardFile({ documentId }).catch((error) => {
            this.errorMessage = this.reduceError(error);
        });
    }

    // ---------------- Save ----------------
    async handleSave() {
        this.errorMessage = undefined;
        if (!this.validate()) {
            return;
        }
        this.isSaving = true;
        try {
            const result = await createTicket({
                req: {
                    moduleId: this.form.moduleId,
                    department: this.form.department,
                    priority: this.form.priority,
                    subject: this.form.subject,
                    description: this.form.description,
                    documentIds: this.stagedFiles.map((f) => f.documentId)
                }
            });
            // Nothing left to discard - the files now belong to the ticket.
            //this.stagedFiles = [];

            const title = `Ticket ${result.caseNumber} raised`;
            if (result.warning) {
                this.toast(title, result.warning, 'warning', 'sticky');
            } else {
                const detail = result.emailSent
                    ? `Assigned to ${result.ownerName} and notified by email.`
                    : `Assigned to ${result.ownerName}. No email was sent — check their email address.`;
                this.toast(title, detail, result.emailSent ? 'success' : 'warning');
            }
            
            this.resetForm();
            this.close();
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: result.caseId,
                    objectApiName: 'Case',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        // Files were uploaded for real, so abandoning the form cleans them up.
        this.stagedFiles.forEach((file) => {
            discardFile({ documentId: file.documentId }).catch(() => {
                // Nothing useful to tell the user on the way out.
            });
        });

        this.resetForm();
        //this.stagedFiles = [];

        if (this.isAction) {
            // Inside a modal there is nowhere to navigate to - just dismiss it.
            this.close();
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Case',
                actionName: 'list'
            },
            state: { filterName: 'Recent' }
        });
    }

    /** Dismisses the action modal. Harmless no-op when rendered as a page. */
    close() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    validate() {
        const inputs = [
            ...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea')
        ];
        const allValid = inputs.reduce((valid, input) => input.reportValidity() && valid, true);

        if (!this.form.moduleId) {
            this.errorMessage = 'Select the module this ticket belongs to.';
            return false;
        }
        if (!this.form.department) {
            this.errorMessage = 'Select the department this ticket belongs to.';
            return false;
        }
        if (!allValid) {
            this.errorMessage = 'Fill in the highlighted fields before raising the ticket.';
            return false;
        }
        return true;
    }

    // ---------------- Utilities ----------------
    toast(title, message, variant, mode) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant, mode: mode || 'dismissable' }));
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Something went wrong. Try again.';
    }

        resetForm() {
        this.form = {
            moduleId: '',
            // Locked department comes back from the profile; otherwise start blank.
            department: this.isDepartmentLocked && this.lockedDepartment
                ? this.lockedDepartment
                : '',
            priority: '',
            subject: '',
            description: ''
        };
        this.isSaving = false;
        this.errorMessage = undefined;
        this.stagedFiles = [];
    }
}
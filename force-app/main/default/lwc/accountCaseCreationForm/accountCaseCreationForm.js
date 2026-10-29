import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import ACCOUNT_NAME from '@salesforce/schema/Account.Name';
import USER_ID from '@salesforce/user/Id';

import getFormPicklists from '@salesforce/apex/AccountCaseCreationController.getFormPicklists';
import getContactsForAccount from '@salesforce/apex/AccountCaseCreationController.getContactsForAccount';
import createContact from '@salesforce/apex/AccountCaseCreationController.createContact';
import getUsersByDepartment from '@salesforce/apex/AccountCaseCreationController.getUsersByDepartment';
import createCase from '@salesforce/apex/AccountCaseCreationController.createCase';
import discardFile from '@salesforce/apex/AccountCaseCreationController.discardFile';

const CONTACT_COLUMNS = [
    { label: 'Name', fieldName: 'name', type: 'text' },
    { label: 'Business Phone', fieldName: 'phone', type: 'phone' },
    { label: 'Email', fieldName: 'email', type: 'email' }
];

export default class AccountCaseCreationForm extends NavigationMixin(LightningElement) {
    @track form = {
        department: '',
        subDepartment: '',
        origin: '',
        caseType: '',
        subCategory: '',
        priority: '',
        subject: '',
        description: '',
        comments: '',
        assignedToId: '',
        customerName: ''
    };

    /** The Account this action was launched from. */
    @api recordId;

    contacts = [];
    selectedContactIds = [];
    isLoadingContacts = true;
    contactColumns = CONTACT_COLUMNS;
    userOptions = [];
    isSaving = false;
    errorMessage;

    picklists = {};
    picklistIssues = [];

    showNewContact = false;
    isSavingContact = false;
    @track newContact = { firstName: '', lastName: '', phone: '', email: '' };

    /**
     * Files upload before the case exists, staged against the running user's own
     * record, then relinked to the case on save. lightning-file-upload streams straight
     * to Salesforce, so Apex never handles the bytes and size is not a constraint.
     */
    stagingRecordId = USER_ID;
    stagedFiles = [];

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
    get originOptions() {
        return this.picklists.Origin ?? [];
    }
    get typeOptions() {
        return this.picklists.Type ?? [];
    }
    get priorityOptions() {
        return this.picklists.Priority ?? [];
    }
    get subDepartmentOptions() {
        return this.dependentOptions(this.picklists.Sub_Department__c, this.form.department);
    }
    get subCategoryOptions() {
        return this.dependentOptions(this.picklists.Sub_Category__c, this.form.caseType);
    }

    /**
     * Returns every value for an independent picklist, or only the values valid
     * for the current controlling value when the field is a dependent picklist.
     */
    dependentOptions(options, controllingValue) {
        if (!options?.length) {
            return [];
        }
        const isDependent = options.some((option) => option.validFor?.length);
        if (!isDependent) {
            return options;
        }
        if (!controllingValue) {
            return [];
        }
        return options.filter((option) => option.validFor?.includes(controllingValue));
    }

    // ---------------- Derived UI state ----------------
    get hasContacts() {
        return this.contacts.length > 0;
    }
    get contactSummary() {
        const count = this.selectedContactIds.length;
        if (!count) {
            return 'No contacts selected yet';
        }
        return count === 1 ? '1 contact will be linked' : `${count} contacts will be linked`;
    }
    get contactEmptyMessage() {
        return 'No contacts on this account. Use New Contact to add one.';
    }
    get isAssigneeDisabled() {
        return !this.form.department || this.userOptions.length === 0;
    }
    get assigneePlaceholder() {
        if (!this.form.department) {
            return 'Select a department first';
        }
        return this.userOptions.length
            ? 'Select a user'
            : 'No active user is tagged to this department';
    }
    get isSubDepartmentDisabled() {
        return this.subDepartmentOptions.length === 0;
    }
    get subDepartmentPlaceholder() {
        return this.form.department ? 'Select a sub department' : 'Select a department first';
    }
    get isSubCategoryDisabled() {
        return this.subCategoryOptions.length === 0;
    }
    get subCategoryPlaceholder() {
        return this.form.caseType ? 'Select a sub category' : 'Select a category first';
    }

    // ---------------- Files ----------------
    get hasFiles() {
        return this.stagedFiles.length > 0;
    }
    get maxFileSizeLabel() {
        return '25 MB';
    }

    // ---------------- Account ----------------
    /**
     * Wired rather than loaded in connectedCallback: recordId is not reliably
     * populated by then in a screen action, so an imperative call there can fire
     * with undefined and silently return nothing.
     */
    @wire(getContactsForAccount, { accountId: '$recordId' })
    wiredContacts({ data, error }) {
        if (data) {
            this.contacts = data;
            // A lone contact is almost certainly the one they mean.
            if (data.length === 1) {
                this.selectedContactIds = [data[0].value];
            }
            this.isLoadingContacts = false;
        } else if (error) {
            this.contacts = [];
            this.selectedContactIds = [];
            this.isLoadingContacts = false;
            this.errorMessage = `Contacts could not be loaded: ${this.reduceError(error)}`;
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: [ACCOUNT_NAME] })
    account;

    get accountNameDisplay() {
        return getFieldValue(this.account.data, ACCOUNT_NAME) || '—';
    }

    // ---------------- Handlers ----------------
    handleFieldChange(event) {
        this.form[event.target.dataset.field] = event.detail.value;
    }

    handleContactSelection(event) {
        this.selectedContactIds = event.detail.selectedRows.map((row) => row.value);
    }

    handleTypeChange(event) {
        this.form.caseType = event.detail.value;
        this.form.subCategory = '';
    }

    handleDepartmentChange(event) {
        this.form.department = event.detail.value;
        this.form.subDepartment = '';
        this.form.assignedToId = '';
        this.userOptions = [];
        if (!this.form.department) {
            return;
        }
        getUsersByDepartment({ department: this.form.department })
            .then((result) => {
                this.userOptions = result;
            })
            .catch((error) => {
                this.errorMessage = this.reduceError(error);
            });
    }

    // ---------------- New contact ----------------
    get canAddContactDisabled() {
        return !this.recordId || this.isSavingContact;
    }
    get isSaveContactDisabled() {
        return this.isSavingContact || !this.newContact.lastName;
    }

    handleToggleNewContact() {
        this.showNewContact = !this.showNewContact;
        if (!this.showNewContact) {
            this.newContact = { firstName: '', lastName: '', phone: '', email: '' };
        }
    }

    handleNewContactChange(event) {
        this.newContact[event.target.dataset.field] = event.detail.value;
    }

    async handleSaveContact() {
        this.errorMessage = undefined;
        this.isSavingContact = true;
        try {
            const created = await createContact({
                accountId: this.recordId,
                firstName: this.newContact.firstName,
                lastName: this.newContact.lastName,
                phone: this.newContact.phone,
                email: this.newContact.email
            });
            this.contacts = [...this.contacts, created];
            // A contact you just typed in is one you want on the case.
            this.selectedContactIds = [...this.selectedContactIds, created.value];
            this.showNewContact = false;
            this.newContact = { firstName: '', lastName: '', phone: '', email: '' };
            this.toast('Contact added', `${created.name} is selected for this case.`, 'success');
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isSavingContact = false;
        }
    }

    // ---------------- Files ----------------
    /**
     * The file is already in Salesforce by the time this fires - only its document id
     * is held here, to be linked to the case once that exists.
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
            const firstSelected = this.contacts.find((c) => c.value === this.selectedContactIds[0]);

            const result = await createCase({
                req: {
                    accountId: this.recordId,
                    contactIds: this.selectedContactIds,
                    department: this.form.department,
                    subDepartment: this.form.subDepartment,
                    origin: this.form.origin,
                    caseType: this.form.caseType,
                    subCategory: this.form.subCategory,
                    priority: this.form.priority,
                    subject: this.form.subject,
                    description: this.form.description,
                    comments: this.form.comments,
                    assignedToId: this.form.assignedToId,
                    customerName: firstSelected ? firstSelected.name : null,
                    // Already uploaded - Apex only links them to the case.
                    documentIds: this.stagedFiles.map((f) => f.documentId)
                }
            });
            // Nothing left to discard - the files now belong to the case.
            this.stagedFiles = [];

            this.reportOutcome(result);

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

    reportOutcome(result) {
        const title = `Case ${result.caseNumber} created`;
        if (result.warning) {
            this.toast(title, result.warning, 'warning', 'sticky');
            return;
        }
        const linked = result.contactsLinked || 0;
        const sent = result.emailsSent || 0;
        const files = result.filesAttached || 0;

        let detail = `${linked} contact${linked === 1 ? '' : 's'} linked`;
        if (files) {
            detail += `, ${files} file${files === 1 ? '' : 's'} attached`;
        }
        detail += sent
            ? `, ${sent} notified by email.`
            : '. No email was sent — none of the selected contacts has an email address.';
        this.toast(title, detail, sent || !linked ? 'success' : 'warning');
    }

    handleCancel() {
        // Files were uploaded for real, so abandoning the form cleans them up.
        this.stagedFiles.forEach((file) => {
            discardFile({ documentId: file.documentId }).catch(() => {
                // Nothing useful to tell the user on the way out.
            });
        });
        this.stagedFiles = [];
        this.close();
    }

    /** Closes the action modal. No-op if the component is dropped on a page instead. */
    close() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    validate() {
        const inputs = [
            ...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea')
        ];
        const allValid = inputs.reduce((valid, input) => input.reportValidity() && valid, true);

        if (!this.recordId) {
            this.errorMessage = 'The account could not be read from this record. Reload the page and try again.';
            return false;
        }
        if (!this.selectedContactIds.length) {
            this.errorMessage = 'Select at least one contact for this case.';
            return false;
        }
        if (!allValid) {
            this.errorMessage = 'Fill in the highlighted fields before creating the case.';
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
}
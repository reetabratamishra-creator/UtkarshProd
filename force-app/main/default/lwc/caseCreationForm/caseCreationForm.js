import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import USER_ID from '@salesforce/user/Id';

import getFormPicklists from '@salesforce/apex/CaseCreationController.getFormPicklists';
import getContactsForAccount from '@salesforce/apex/CaseCreationController.getContactsForAccount';
import getOpportunityContext from '@salesforce/apex/CaseCreationController.getOpportunityContext';
import createContact from '@salesforce/apex/CaseCreationController.createContact';
import getUsersByDepartment from '@salesforce/apex/CaseCreationController.getUsersByDepartment';
import createCase from '@salesforce/apex/CaseCreationController.createCase';
import discardFile from '@salesforce/apex/CaseCreationController.discardFile';

const RELATED_TO_OPTIONS = [
    { label: 'Account', value: 'Account' },
    { label: 'Opportunity', value: 'Opportunity' }
];

const CONTACT_COLUMNS = [
    { label: 'Name', fieldName: 'name', type: 'text' },
    { label: 'Business Phone', fieldName: 'phone', type: 'phone' },
    { label: 'Email', fieldName: 'email', type: 'email' },
    { label: 'Opportunity Role', fieldName: 'roleLabel', type: 'text', initialWidth: 180 }
];

export default class CaseCreationForm extends NavigationMixin(LightningElement) {
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
        assignedToId: ''
    };

    relatedTo = 'Account';
    accountId;
    opportunityId;
    /** Account behind the chosen opportunity - used when creating a contact. */
    resolvedAccountName;

    contacts = [];
    selectedContactIds = [];
    isLoadingContacts = false;

    userOptions = [];
    isSaving = false;
    errorMessage;

    picklists = {};
    picklistIssues = [];

    showNewContact = false;
    isSavingContact = false;
    @track newContact = { firstName: '', lastName: '', phone: '', email: '' };

    relatedToOptions = RELATED_TO_OPTIONS;
    contactColumns = CONTACT_COLUMNS;

    /**
     * Files are uploaded before the case exists, staged against the running user's own
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


    connectedCallback() {
    this.resetForm();
    }

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

    // ---------------- Step gating ----------------
    /** The customer step only opens once a department has been chosen. */
    get isDepartmentChosen() {
        return !!this.form.department;
    }
    get isAccountMode() {
        return this.relatedTo === 'Account';
    }
    get isOpportunityMode() {
        return this.relatedTo === 'Opportunity';
    }
    get hasRelatedRecord() {
        return this.isAccountMode ? !!this.accountId : !!this.opportunityId;
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

    // ---------------- Contacts ----------------
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
        if (!this.hasRelatedRecord) {
            return this.isAccountMode
                ? 'Select an account to see its contacts.'
                : 'Select an opportunity to see the contacts on its account.';
        }
        return 'No contacts found. Use New Contact to add one.';
    }
    get canAddContactDisabled() {
        return !this.hasRelatedRecord || this.isSavingContact;
    }
    get isSaveContactDisabled() {
        return this.isSavingContact || !this.newContact.lastName;
    }
    get newContactHint() {
        if (this.isOpportunityMode && this.resolvedAccountName) {
            return `The contact will be created under ${this.resolvedAccountName}, the opportunity's account.`;
        }
        return 'The contact will be created under the selected account.';
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

    handleTypeChange(event) {
        this.form.caseType = event.detail.value;
        this.form.subCategory = '';
    }

    handleRelatedToChange(event) {
        this.relatedTo = event.detail.value;
        this.resetCustomerSelection();
    }

    handleAccountChange(event) {
        this.accountId = event.detail.recordId;
        this.resetContacts();
        if (!this.accountId) {
            return;
        }
        this.isLoadingContacts = true;
        getContactsForAccount({ accountId: this.accountId })
            .then((result) => {
                this.contacts = this.decorate(result);
                // Nothing is preselected in account mode - the user chooses.
            })
            .catch((error) => {
                this.errorMessage = this.reduceError(error);
            })
            .finally(() => {
                this.isLoadingContacts = false;
            });
    }

    handleOpportunityChange(event) {
        this.opportunityId = event.detail.recordId;
        this.resetContacts();
        if (!this.opportunityId) {
            return;
        }
        this.isLoadingContacts = true;
        getOpportunityContext({ opportunityId: this.opportunityId })
            .then((context) => {
                this.resolvedAccountName = context.accountName;
                this.contacts = this.decorate(context.contacts);
                // The primary opportunity contact role starts ticked.
                this.selectedContactIds = [...(context.preselectedIds || [])];
            })
            .catch((error) => {
                this.errorMessage = this.reduceError(error);
            })
            .finally(() => {
                this.isLoadingContacts = false;
            });
    }

    handleContactSelection(event) {
        this.selectedContactIds = event.detail.selectedRows.map((row) => row.value);
    }

    /** Adds the display-only column the datatable renders. */
    decorate(contacts) {
        return (contacts || []).map((c) => ({
            ...c,
            roleLabel: c.isPrimary ? `${c.role || 'Contact'} (Primary)` : c.role || ''
        }));
    }

    resetContacts() {
        this.contacts = [];
        this.selectedContactIds = [];
        this.showNewContact = false;
        this.newContact = { firstName: '', lastName: '', phone: '', email: '' };
    }

    resetCustomerSelection() {
        this.accountId = undefined;
        this.opportunityId = undefined;
        this.resolvedAccountName = undefined;
        this.resetContacts();
    }

    // ---------------- New contact ----------------
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
            // In opportunity mode Apex resolves the account off the opportunity.
            const created = await createContact({
                accountId: this.isAccountMode ? this.accountId : null,
                opportunityId: this.isOpportunityMode ? this.opportunityId : null,
                firstName: this.newContact.firstName,
                lastName: this.newContact.lastName,
                phone: this.newContact.phone,
                email: this.newContact.email
            });

            this.contacts = [...this.contacts, ...this.decorate([created])];
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
                    accountId: this.isAccountMode ? this.accountId : null,
                    opportunityId: this.isOpportunityMode ? this.opportunityId : null,
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
            /*this.stagedFiles = [];

            this.reportOutcome(result);

            this.dispatchEvent(new CustomEvent('close'));*/
            this.reportOutcome(result);

            // Files now belong to the case, so just clear everything.
            this.resetForm();

            this.dispatchEvent(new CustomEvent('close'));

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
        const files = result.filesAttached || 0;

        // Email outcome is deliberately not reported: a non-send has several causes
        // and naming only one of them was misleading. Failures are still logged Apex-side.
        const parts = [`${linked} contact${linked === 1 ? '' : 's'} linked`];
        if (files) {
            parts.push(`${files} file${files === 1 ? '' : 's'} attached`);
        }
        this.toast(title, `${parts.join(', ')}.`, 'success');
    }

    handleCancel() {
        // Files were uploaded for real, so abandoning the form cleans them up.
        this.stagedFiles.forEach((file) => {
            discardFile({ documentId: file.documentId }).catch(() => {
                // Nothing useful to tell the user on the way out.
            });
        });
        //this.stagedFiles = [];
        this.resetForm();

        // Still fires for anyone embedding this inside a modal wrapper.
        this.dispatchEvent(new CustomEvent('close'));
        this.navigateToCaseList();
    }

    navigateToCaseList() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Case',
                actionName: 'list'
            },
            state: {
                filterName: 'Recent'
            }
        });
    }

    validate() {
        const inputs = [
            ...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea')
        ];
        const allValid = inputs.reduce((valid, input) => input.reportValidity() && valid, true);

        if (!this.form.department) {
            this.errorMessage = 'Choose the department handling this complaint.';
            return false;
        }
        if (!this.hasRelatedRecord) {
            this.errorMessage = this.isAccountMode
                ? 'Select the account the complaint is registered against.'
                : 'Select the opportunity the complaint relates to.';
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
    resetForm() {
    this.form = {
        department: '',
        subDepartment: '',
        origin: '',
        caseType: '',
        subCategory: '',
        priority: '',
        subject: '',
        description: '',
        comments: '',
        assignedToId: ''
    };
    this.relatedTo = 'Account';
    this.accountId = undefined;
    this.opportunityId = undefined;
    this.resolvedAccountName = undefined;

    this.contacts = [];
    this.selectedContactIds = [];
    this.isLoadingContacts = false;

    this.userOptions = [];
    this.isSaving = false;
    this.errorMessage = undefined;

    this.showNewContact = false;
    this.isSavingContact = false;
    this.newContact = { firstName: '', lastName: '', phone: '', email: '' };

    this.stagedFiles = [];
}
}
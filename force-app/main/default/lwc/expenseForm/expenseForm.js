/*import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import getMyEligibility from '@salesforce/apex/ExpenseController.getMyEligibility';
import saveExpense from '@salesforce/apex/ExpenseController.saveExpense';
import getExpenseWithLines from '@salesforce/apex/ExpenseController.getExpenseWithLines';

import EXPENSE_OBJECT from '@salesforce/schema/Expense__c';
import EMPLOYEE_FIELD from '@salesforce/schema/Expense__c.Employee__c';
import EMPLOYEE_LEVEL_FIELD from '@salesforce/schema/Expense__c.Employee_Level__c';
import EMPLOYEE_GRADE_FIELD from '@salesforce/schema/Expense__c.Employee_Grade__c';
import STATUS_FIELD from '@salesforce/schema/Expense__c.Status__c';
import PURPOSE_FIELD from '@salesforce/schema/Expense__c.Purpose__c';
import TRAVEL_START_DATE_FIELD from '@salesforce/schema/Expense__c.Travel_Start_Date__c';
import TRAVEL_END_DATE_FIELD from '@salesforce/schema/Expense__c.Travel_End_Date__c';
import TOTAL_AMOUNT_FIELD from '@salesforce/schema/Expense__c.Total_Amount__c';

export default class ExpenseForm extends LightningElement {
    @api recordId;
    @track expense = {};
    @track eligibility = {};
    @track isLoading = false;
    @track isNewRecord = false;

    // Object and field references
    expenseObject = EXPENSE_OBJECT;
    employeeField = EMPLOYEE_FIELD;
    employeeLevelField = EMPLOYEE_LEVEL_FIELD;
    employeeGradeField = EMPLOYEE_GRADE_FIELD;
    statusField = STATUS_FIELD;
    purposeField = PURPOSE_FIELD;
    travelStartDateField = TRAVEL_START_DATE_FIELD;
    travelEndDateField = TRAVEL_END_DATE_FIELD;
    totalAmountField = TOTAL_AMOUNT_FIELD;

    connectedCallback() {
        this.isNewRecord = !this.recordId;
        if (this.isNewRecord) {
            this.loadEligibility();
        } else {
            this.loadExpenseRecord();
        }
    }

    // Load user's eligibility
    loadEligibility() {
        this.isLoading = true;
        getMyEligibility()
            .then(result => {
                if (result) {
                    this.eligibility = result;
                    // Pre-populate employee level and grade
                    this.expense.Employee_Level__c = result.Level__c;
                    this.expense.Employee_Grade__c = result.Grade__c;
                }
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load eligibility: ' + this.getErrorMessage(error), 'error');
                this.isLoading = false;
            });
    }

    // Load existing expense record
    loadExpenseRecord() {
        if (!this.recordId) return;
        
        this.isLoading = true;
        getExpenseWithLines({ expenseId: this.recordId })
            .then(result => {
                this.expense = result;
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load expense: ' + this.getErrorMessage(error), 'error');
                this.isLoading = false;
            });
    }

    // Handle field changes
    handleFieldChange(event) {
        const field = event.target.fieldName || event.target.name;
        const value = event.target.value || event.detail.value;
        this.expense[field] = value;
    }

    // Handle save
    handleSave() {
        // Validate required fields
        if (!this.validateForm()) {
            return;
        }

        this.isLoading = true;
        saveExpense({ expense: this.expense })
            .then(result => {
                this.expense = result;
                this.recordId = result.Id;
                this.isNewRecord = false;
                this.showToast('Success', 'Expense saved successfully', 'success');
                this.isLoading = false;
                
                // Dispatch event to notify parent components
                this.dispatchEvent(new CustomEvent('expensesaved', { 
                    detail: { expenseId: result.Id } 
                }));
            })
            .catch(error => {
                this.showToast('Error', 'Failed to save expense: ' + this.getErrorMessage(error), 'error');
                this.isLoading = false;
            });
    }

    // Validate form
    validateForm() {
        const allValid = [...this.template.querySelectorAll('lightning-input-field')]
            .reduce((validSoFar, field) => {
                return validSoFar && field.reportValidity();
            }, true);
        
        if (!allValid) {
            this.showToast('Error', 'Please complete all required fields', 'error');
        }
        
        return allValid;
    }

    // Handle cancel
    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    // Show toast message
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    // Get error message from exception
    getErrorMessage(error) {
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        } else if (error.body && error.body.message) {
            return error.body.message;
        }
        return error.message || 'Unknown error';
    }

    // Computed properties
    get isReadOnly() {
        return this.expense.Status__c && this.expense.Status__c !== 'Draft';
    }

    get formTitle() {
        return this.isNewRecord ? 'New Expense' : 'Edit Expense';
    }
}*/

import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMyEligibility from '@salesforce/apex/ExpenseController.getMyEligibility';
import saveExpense from '@salesforce/apex/ExpenseController.saveExpense';
import getExpenseWithLines from '@salesforce/apex/ExpenseController.getExpenseWithLines';

export default class ExpenseForm extends LightningElement {
    @api recordId;

    @track expense = {};
    @track eligibility = {};
    @track isLoading = false;
    @track isNewRecord = false;

    connectedCallback() {
        this.isNewRecord = !this.recordId;
        if (this.isNewRecord) {
            this.loadEligibility();
        } else {
            this.loadExpenseRecord();
        }
    }

    // ─── Data Loading ────────────────────────────────────────────────────────

    loadEligibility() {
        this.isLoading = true;
        getMyEligibility()
            .then(result => {
                this.eligibility = result || {};
                // Pre-populate level and grade from eligibility
                if (result) {
                    this.expense = {
                        ...this.expense,
                        Employee_Level__c: result.Level__c,
                        Employee_Grade__c: result.Grade__c
                    };
                }
            })
            .catch(error => {
                this.showToast('Error', this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    loadExpenseRecord() {
        if (!this.recordId) return;
        this.isLoading = true;
        getExpenseWithLines({ expenseId: this.recordId })
            .then(result => {
                this.expense = result ? { ...result } : {};
            })
            .catch(error => {
                this.showToast('Error', this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ─── Field Change Handler ─────────────────────────────────────────────────

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        this.expense = { ...this.expense, [field]: value };
    }

    // ─── Save ─────────────────────────────────────────────────────────────────

    handleSave() {
        if (!this.validateForm()) return;

        this.isLoading = true;
        saveExpense({ expense: this.expense })
            .then(result => {
                this.expense = { ...result };
                this.recordId = result.Id;
                this.isNewRecord = false;
                this.showToast('Success', 'Expense saved successfully.', 'success');
                this.dispatchEvent(
                    new CustomEvent('expensesaved', { detail: { expenseId: result.Id } })
                );
            })
            .catch(error => {
                this.showToast('Error', this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // ─── Validation ───────────────────────────────────────────────────────────

    validateForm() {
        const inputs = this.template.querySelectorAll('lightning-input, lightning-textarea');
        let isValid = true;
        inputs.forEach(input => {
            if (!input.reportValidity()) {
                isValid = false;
            }
        });
        if (!isValid) {
            this.showToast('Validation Error', 'Please fill in all required fields.', 'error');
        }
        return isValid;
    }

    // ─── Cancel ───────────────────────────────────────────────────────────────

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    // ─── Computed Properties ──────────────────────────────────────────────────

    get isReadOnly() {
        const status = this.expense.Status__c;
        return status && status !== 'Draft';
    }

    get formTitle() {
        return this.isNewRecord ? 'New Expense' : 'Edit Expense';
    }

    get saveButtonLabel() {
        return this.isLoading ? 'Saving...' : 'Save';
    }

    get statusBadgeClass() {
        const status = this.expense.Status__c || 'Draft';
        const map = {
            Draft: 'slds-badge slds-badge_lightest',
            Submitted: 'slds-badge slds-theme_warning',
            Approved: 'slds-badge slds-theme_success',
            Rejected: 'slds-badge slds-theme_error'
        };
        return map[status] || 'slds-badge slds-badge_lightest';
    }

    get hasEligibility() {
        return this.eligibility && this.eligibility.Level__c;
    }

    // ─── Utilities ────────────────────────────────────────────────────────────

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    getErrorMessage(error) {
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        if (error.body && error.body.message) {
            return error.body.message;
        }
        return error.message || 'An unknown error occurred.';
    }
}
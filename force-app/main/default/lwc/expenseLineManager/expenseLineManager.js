import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getExpenseLines from '@salesforce/apex/ExpenseLineController.getExpenseLines';
import saveExpenseLine from '@salesforce/apex/ExpenseLineController.saveExpenseLine';
import deleteExpenseLine from '@salesforce/apex/ExpenseLineController.deleteExpenseLine';
import validateExpenseLine from '@salesforce/apex/ExpenseLineController.validateExpenseLine';
import getTotalAmount from '@salesforce/apex/ExpenseLineController.getTotalAmount';

const COLUMNS = [
    { label: 'Date', fieldName: 'Date__c', type: 'date', editable: false },
    { label: 'Type', fieldName: 'Expense_Type__c', type: 'text', editable: false },
    { label: 'City', fieldName: 'City__c', type: 'text', editable: false },
    { label: 'City Tier', fieldName: 'City_Tier__c', type: 'text', editable: false },
    { label: 'Travel Class', fieldName: 'Travel_Class__c', type: 'text', editable: false },
    { label: 'Amount', fieldName: 'Amount__c', type: 'currency', editable: false },
    { label: 'Bill Attached', fieldName: 'Bill_Attached__c', type: 'boolean', editable: false },
    { 
        label: 'Actions', 
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Edit', name: 'edit' },
                { label: 'Delete', name: 'delete' }
            ]
        }
    }
];

export default class ExpenseLineManager extends LightningElement {
    @api recordId; // Expense__c Id
    @track lines = [];
    @track columns = COLUMNS;
    @track isLoading = false;
    @track showModal = false;
    @track selectedLine = {};
    @track totalAmount = 0;
    @track isEditMode = false;

    // Expense Type Options
    expenseTypeOptions = [
        { label: 'Lodging', value: 'Lodging' },
        { label: 'Fooding', value: 'Fooding' },
        { label: 'Air', value: 'Air' },
        { label: 'Train', value: 'Train' },
        { label: 'Roadways', value: 'Roadways' },
        { label: 'Own Vehicle', value: 'Own Vehicle' }
    ];

    // City Tier Options
    cityTierOptions = [
        { label: 'Tier 1', value: 'Tier 1' },
        { label: 'Tier 2', value: 'Tier 2' }
    ];

    // Travel Class Options
    travelClassOptions = [
        { label: 'Business', value: 'Business' },
        { label: 'Economy', value: 'Economy' },
        { label: '1AC', value: '1AC' },
        { label: '2AC', value: '2AC' },
        { label: '3AC', value: '3AC' },
        { label: 'Sleeper', value: 'Sleeper' }
    ];

    // Vehicle Type Options
    vehicleTypeOptions = [
        { label: 'OLA/UBER/TAXI', value: 'OLA/UBER/TAXI' },
        { label: 'Auto', value: 'Auto' },
        { label: 'Bus', value: 'Bus' },
        { label: '2-Wheeler', value: '2-Wheeler' },
        { label: '4-Wheeler', value: '4-Wheeler' }
    ];

    connectedCallback() {
        if (this.recordId) {
            this.loadExpenseLines();
            this.loadTotalAmount();
        }
    }

    // Load expense lines
    loadExpenseLines() {
        this.isLoading = true;
        getExpenseLines({ expenseId: this.recordId })
            .then(result => {
                this.lines = result;
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load expense lines: ' + this.getErrorMessage(error), 'error');
                this.isLoading = false;
            });
    }

    // Load total amount
    loadTotalAmount() {
        getTotalAmount({ expenseId: this.recordId })
            .then(result => {
                this.totalAmount = result;
            })
            .catch(error => {
                console.error('Failed to load total amount:', error);
            });
    }

    // Handle row action
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        
        switch (actionName) {
            case 'edit':
                this.handleEdit(row);
                break;
            case 'delete':
                this.handleDelete(row);
                break;
        }
    }

    // Handle edit
    handleEdit(row) {
        this.selectedLine = { ...row };
        this.isEditMode = true;
        this.showModal = true;
    }

    // Handle delete
    handleDelete(row) {
        if (confirm('Are you sure you want to delete this expense line?')) {
            this.isLoading = true;
            deleteExpenseLine({ expenseLineId: row.Id })
                .then(() => {
                    this.showToast('Success', 'Expense line deleted successfully', 'success');
                    this.loadExpenseLines();
                    this.loadTotalAmount();
                })
                .catch(error => {
                    this.showToast('Error', 'Failed to delete expense line: ' + this.getErrorMessage(error), 'error');
                    this.isLoading = false;
                });
        }
    }

    // Handle add new line
    handleAddNew() {
        this.selectedLine = {
            Expense__c: this.recordId,
            Date__c: new Date().toISOString().split('T')[0],
            Bill_Attached__c: false
        };
        this.isEditMode = false;
        this.showModal = true;
    }

    // Handle field change in modal
    handleFieldChange(event) {
        const field = event.target.name;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.selectedLine = { ...this.selectedLine, [field]: value };
    }

    // Handle save
    handleSave() {
        if (!this.validateLineForm()) {
            return;
        }

        this.isLoading = true;
        
        // Validate against eligibility limits
        validateExpenseLine({ expenseLine: this.selectedLine })
            .then(validationResult => {
                if (!validationResult.isValid) {
                    this.showToast('Validation Error', validationResult.message, 'error');
                    this.isLoading = false;
                    return;
                }
                
                // Save the line
                return saveExpenseLine({ expenseLine: this.selectedLine });
            })
            .then(result => {
                if (result) {
                    this.showToast('Success', 'Expense line saved successfully', 'success');
                    this.handleCloseModal();
                    this.loadExpenseLines();
                    this.loadTotalAmount();
                }
            })
            .catch(error => {
                this.showToast('Error', 'Failed to save expense line: ' + this.getErrorMessage(error), 'error');
                this.isLoading = false;
            });
    }

    // Validate line form
    validateLineForm() {
        const inputs = this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea');
        let isValid = true;
        
        inputs.forEach(input => {
            if (!input.reportValidity()) {
                isValid = false;
            }
        });
        
        if (!isValid) {
            this.showToast('Error', 'Please complete all required fields', 'error');
        }
        
        return isValid;
    }

    // Handle close modal
    handleCloseModal() {
        this.showModal = false;
        this.selectedLine = {};
        this.isEditMode = false;
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
    get modalTitle() {
        return this.isEditMode ? 'Edit Expense Line' : 'New Expense Line';
    }

    get hasLines() {
        return this.lines && this.lines.length > 0;
    }

    get showDistanceField() {
        return this.selectedLine.Expense_Type__c === 'Own Vehicle';
    }

    get showTravelClassField() {
        return this.selectedLine.Expense_Type__c === 'Air' || 
               this.selectedLine.Expense_Type__c === 'Train';
    }

    get showVehicleTypeField() {
        return this.selectedLine.Expense_Type__c === 'Roadways';
    }
}
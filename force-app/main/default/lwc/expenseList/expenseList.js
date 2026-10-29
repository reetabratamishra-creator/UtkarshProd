import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getMyExpenses from '@salesforce/apex/ExpenseController.getMyExpenses';
import deleteExpense from '@salesforce/apex/ExpenseController.deleteExpense';

const COLUMNS = [
    {
        label: 'Expense Number',
        fieldName: 'expenseUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'Name' },
            target: '_blank'
        },
        sortable: true
    },
    {
        label: 'Status',
        fieldName: 'Status__c',
        type: 'text',
        sortable: true,
        cellAttributes: {
            class: { fieldName: 'statusClass' }
        }
    },
    {
        label: 'Total Amount',
        fieldName: 'Total_Amount__c',
        type: 'currency',
        sortable: true,
        typeAttributes: {
            currencyCode: 'INR',
            minimumFractionDigits: 2
        }
    },
    {
        label: 'Travel Start Date',
        fieldName: 'Travel_Start_Date__c',
        type: 'date',
        sortable: true
    },
    {
        label: 'Travel End Date',
        fieldName: 'Travel_End_Date__c',
        type: 'date',
        sortable: true
    },
    {
        label: 'Submitted Date',
        fieldName: 'Submitted_Date__c',
        type: 'date',
        sortable: true
    },
    {
        label: 'Purpose',
        fieldName: 'Purpose__c',
        type: 'text'
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'View', name: 'view' },
                { label: 'Edit', name: 'edit' },
                { label: 'Delete', name: 'delete' }
            ]
        }
    }
];

export default class ExpenseList extends NavigationMixin(LightningElement) {
    @track expenses = [];
    @track filteredExpenses = [];
    @track error;
    @track sortBy = 'Travel_Start_Date__c';
    @track sortDirection = 'desc';
    @track searchKey = '';
    @track statusFilter = 'All';
    
    columns = COLUMNS;
    wiredExpensesResult;

    statusOptions = [
        { label: 'All', value: 'All' },
        { label: 'Draft', value: 'Draft' },
        { label: 'Submitted', value: 'Submitted' },
        { label: 'Approved', value: 'Approved' },
        { label: 'Rejected', value: 'Rejected' }
    ];

    @wire(getMyExpenses)
    wiredExpenses(result) {
        this.wiredExpensesResult = result;
        if (result.data) {
            this.expenses = result.data.map(expense => {
                return {
                    ...expense,
                    expenseUrl: `/${expense.Id}`,
                    statusClass: this.getStatusClass(expense.Status__c)
                };
            });
            this.applyFilters();
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.expenses = [];
            this.filteredExpenses = [];
            this.showToast('Error', 'Error loading expenses: ' + this.getErrorMessage(result.error), 'error');
        }
    }

    getStatusClass(status) {
        switch(status) {
            case 'Draft':
                return 'slds-text-color_weak';
            case 'Submitted':
                return 'slds-text-color_default';
            case 'Approved':
                return 'slds-text-color_success';
            case 'Rejected':
                return 'slds-text-color_error';
            default:
                return '';
        }
    }

    handleSearch(event) {
        this.searchKey = event.target.value.toLowerCase();
        this.applyFilters();
    }

    handleStatusFilter(event) {
        this.statusFilter = event.detail.value;
        this.applyFilters();
    }

    applyFilters() {
        let filtered = [...this.expenses];

        // Apply status filter
        if (this.statusFilter !== 'All') {
            filtered = filtered.filter(expense => expense.Status__c === this.statusFilter);
        }

        // Apply search filter
        if (this.searchKey) {
            filtered = filtered.filter(expense => {
                const name = (expense.Name || '').toLowerCase();
                const purpose = (expense.Purpose__c || '').toLowerCase();
                return name.includes(this.searchKey) || purpose.includes(this.searchKey);
            });
        }

        this.filteredExpenses = filtered;
    }

    handleSort(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData(this.sortBy, this.sortDirection);
    }

    sortData(fieldName, direction) {
        let parseData = JSON.parse(JSON.stringify(this.filteredExpenses));
        let keyValue = (a) => {
            return a[fieldName];
        };
        let isReverse = direction === 'asc' ? 1 : -1;
        parseData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : '';
            y = keyValue(y) ? keyValue(y) : '';
            return isReverse * ((x > y) - (y > x));
        });
        this.filteredExpenses = parseData;
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        
        switch (actionName) {
            case 'view':
                this.navigateToRecord(row.Id);
                break;
            case 'edit':
                this.navigateToEdit(row.Id);
                break;
            case 'delete':
                this.handleDelete(row.Id);
                break;
            default:
        }
    }

    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Expense__c',
                actionName: 'view'
            }
        });
    }

    navigateToEdit(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Expense__c',
                actionName: 'edit'
            }
        });
    }

    handleNew() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Expense__c',
                actionName: 'new'
            }
        });
    }

    async handleDelete(recordId) {
        if (!confirm('Are you sure you want to delete this expense?')) {
            return;
        }

        try {
            await deleteExpense({ expenseId: recordId });
            this.showToast('Success', 'Expense deleted successfully', 'success');
            // Refresh the data
            return refreshApex(this.wiredExpensesResult);
        } catch (error) {
            this.showToast('Error', 'Error deleting expense: ' + this.getErrorMessage(error), 'error');
        }
    }

    handleRefresh() {
        return refreshApex(this.wiredExpensesResult);
    }

    getErrorMessage(error) {
        if (error.body) {
            if (Array.isArray(error.body)) {
                return error.body.map(e => e.message).join(', ');
            } else if (error.body.message) {
                return error.body.message;
            }
        }
        return error.message || 'Unknown error';
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    get hasExpenses() {
        return this.filteredExpenses && this.filteredExpenses.length > 0;
    }

    get recordCount() {
        return this.filteredExpenses ? this.filteredExpenses.length : 0;
    }

    get totalAmount() {
        if (!this.filteredExpenses || this.filteredExpenses.length === 0) {
            return 0;
        }
        return this.filteredExpenses.reduce((sum, expense) => {
            return sum + (expense.Total_Amount__c || 0);
        }, 0);
    }
}
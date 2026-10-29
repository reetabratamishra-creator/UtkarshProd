import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getPendingApprovals from '@salesforce/apex/ExpenseController.getPendingApprovals';
import approveExpense from '@salesforce/apex/ExpenseController.approveExpense';
import rejectExpense from '@salesforce/apex/ExpenseController.rejectExpense';

/*const COLUMNS = [
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
        label: 'Employee',
        fieldName: 'employeeName',
        type: 'text',
        sortable: true
    },
    {
        label: 'Level',
        fieldName: 'Employee_Level__c',
        type: 'text',
        sortable: true
    },
    {
        label: 'Grade',
        fieldName: 'Employee_Grade__c',
        type: 'text',
        sortable: true
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
        label: 'Travel Dates',
        fieldName: 'travelDates',
        type: 'text'
    },
    {
        label: 'Submitted Date',
        fieldName: 'Submitted_Date__c',
        type: 'date',
        sortable: true
    },
    {
        label: 'Days Pending',
        fieldName: 'daysPending',
        type: 'number',
        sortable: true,
        cellAttributes: {
            class: { fieldName: 'pendingClass' }
        }
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
                { label: 'Approve', name: 'approve' },
                { label: 'Reject', name: 'reject' }
            ]
        }
    }
];*/

export default class ExpenseApprovalQueue extends NavigationMixin(LightningElement) {
    @track expenses = [];
    @track error;
    @track sortBy = 'Submitted_Date__c';
    @track sortDirection = 'asc';
    @track showRejectModal = false;
    @track selectedExpenseId;
    @track rejectionComments = '';
    
    //columns = COLUMNS;
    wiredExpensesResult;

    @wire(getPendingApprovals)
    wiredExpenses(result) {
        this.wiredExpensesResult = result;
        if (result.data) {
            this.expenses = result.data.map(expense => {
                const travelStart = expense.Travel_Start_Date__c ? new Date(expense.Travel_Start_Date__c).toLocaleDateString() : '';
                const travelEnd = expense.Travel_End_Date__c ? new Date(expense.Travel_End_Date__c).toLocaleDateString() : '';
                const submittedDate = expense.Submitted_Date__c ? new Date(expense.Submitted_Date__c) : null;
                const today = new Date();
                const daysPending = submittedDate ? Math.floor((today - submittedDate) / (1000 * 60 * 60 * 24)) : 0;
                
                return {
                    ...expense,
                    expenseUrl: `/${expense.Id}`,
                    employeeName: expense.Employee__r ? expense.Employee__r.Name : '',
                    travelDates: travelStart && travelEnd ? `${travelStart} - ${travelEnd}` : '',
                    daysPending: daysPending,
                    //pendingClass: daysPending > 7 ? 'slds-text-color_error' : daysPending > 5 ? 'slds-text-color_warning' : ''
                    pendingBadgeClass: daysPending > 7 ? 'pending-badge pending-high'
                        : daysPending > 5 ? 'pending-badge pending-medium'
                        : 'pending-badge pending-low'
                };
            });
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.expenses = [];
            this.showToast('Error', 'Error loading pending approvals: ' + this.getErrorMessage(result.error), 'error');
        }
    }

    /*handleSort(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData(this.sortBy, this.sortDirection);
    }*/
    handleSort(event) {
        const fieldName = event.currentTarget.dataset.field;
        this.sortDirection = this.sortBy === fieldName && this.sortDirection === 'asc' ? 'desc' : 'asc';
        this.sortBy = fieldName;
        this.sortData(fieldName, this.sortDirection);
    }

    sortData(fieldName, direction) {
        let parseData = JSON.parse(JSON.stringify(this.expenses));
        let keyValue = (a) => {
            return a[fieldName];
        };
        let isReverse = direction === 'asc' ? 1 : -1;
        parseData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : '';
            y = keyValue(y) ? keyValue(y) : '';
            return isReverse * ((x > y) - (y > x));
        });
        this.expenses = parseData;
    }

    /*handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        
        switch (actionName) {
            case 'view':
                this.navigateToRecord(row.Id);
                break;
            case 'approve':
                this.handleApprove(row.Id);
                break;
            case 'reject':
                this.openRejectModal(row.Id);
                break;
            default:
        }
    }*/
    handleAction(event) {
        const action = event.currentTarget.dataset.action;
        const id = event.currentTarget.dataset.id;

        switch (action) {
            case 'view':
                this.navigateToRecord(id);
                break;
            case 'approve':
                this.handleApprove(id);
                break;
            case 'reject':
                this.openRejectModal(id);
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

    async handleApprove(expenseId) {
        if (!confirm('Are you sure you want to approve this expense?')) {
            return;
        }

        try {
            await approveExpense({ expenseId: expenseId });
            this.showToast('Success', 'Expense approved successfully', 'success');
            // Refresh the data
            return refreshApex(this.wiredExpensesResult);
        } catch (error) {
            this.showToast('Error', 'Error approving expense: ' + this.getErrorMessage(error), 'error');
        }
    }

    openRejectModal(expenseId) {
        this.selectedExpenseId = expenseId;
        this.rejectionComments = '';
        this.showRejectModal = true;
    }

    closeRejectModal() {
        this.showRejectModal = false;
        this.selectedExpenseId = null;
        this.rejectionComments = '';
    }

    handleCommentsChange(event) {
        this.rejectionComments = event.target.value;
    }

    async handleReject() {
        if (!this.rejectionComments || this.rejectionComments.trim().length === 0) {
            this.showToast('Error', 'Please provide rejection comments', 'error');
            return;
        }

        try {
            await rejectExpense({ 
                expenseId: this.selectedExpenseId,
                comments: this.rejectionComments 
            });
            this.showToast('Success', 'Expense rejected successfully', 'success');
            this.closeRejectModal();
            // Refresh the data
            return refreshApex(this.wiredExpensesResult);
        } catch (error) {
            this.showToast('Error', 'Error rejecting expense: ' + this.getErrorMessage(error), 'error');
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
        return this.expenses && this.expenses.length > 0;
    }

    get pendingCount() {
        return this.expenses ? this.expenses.length : 0;
    }

    get totalPendingAmount() {
        if (!this.expenses || this.expenses.length === 0) {
            return 0;
        }
        return this.expenses.reduce((sum, expense) => {
            return sum + (expense.Total_Amount__c || 0);
        }, 0);
    }
}
import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import FORM_FACTOR from '@salesforce/client/formFactor';
import getMyExpenses from '@salesforce/apex/MyExpensesController.getMyExpenses';

const REJECTED_STATUSES = ['Rejected by HOD', 'Rejected by HR', 'Rejected by ED', 'Rejected'];
const APPROVED_STATUSES = ['Approved by ED', 'ED Approved', 'HOD Approved', 'Reimbursed'];
const PAGE_SIZE = 20;

export default class MyExpenses extends NavigationMixin(LightningElement) {
    @track expenses = [];
    @track error;
    @track sortBy = '';
    @track sortDirection = 'asc';
    @track currentPage = 1;

    wiredExpensesResult;

    @wire(getMyExpenses)
    wiredExpenses(result) {
        this.wiredExpensesResult = result;
        if (result.data) {
            this.expenses = result.data.map(expense => ({
                ...expense,
                recordUrl: `/${expense.Id}`,
                remarkText: expense.Remark || '-',
                editableFlag: expense.canEdit ? 'true' : 'false',
                statusBadgeClass: this.getStatusBadgeClass(expense.Status),
                linkTitle: expense.canEdit ? 'Edit and resubmit this expense' : 'Open expense record'
            }));
            if (this.sortBy) {
                this.sortData(this.sortBy, this.sortDirection);
            }
            // Keep the current page on refresh, unless the list got shorter
            this.currentPage = Math.min(this.currentPage, this.totalPages);
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.expenses = [];
            this.showToast('Error', 'Error loading your expenses: ' + this.getErrorMessage(result.error), 'error');
        }
    }

    // Refresh when the user comes back from the resubmit tab
    handleVisibilityChange = () => {
        if (document.visibilityState === 'visible' && this.wiredExpensesResult) {
            refreshApex(this.wiredExpensesResult);
        }
    };

    connectedCallback() {
        document.addEventListener('visibilitychange', this.handleVisibilityChange);
    }

    disconnectedCallback() {
        document.removeEventListener('visibilitychange', this.handleVisibilityChange);
    }

    getStatusBadgeClass(status) {
        if (REJECTED_STATUSES.includes(status)) {
            return 'status-badge status-rejected';
        }
        if (APPROVED_STATUSES.includes(status)) {
            return 'status-badge status-approved';
        }
        if (status && status.startsWith('Pending')) {
            return 'status-badge status-pending';
        }
        return 'status-badge status-neutral';
    }

    handleSort(event) {
        const fieldName = event.currentTarget.dataset.field;
        this.sortDirection = this.sortBy === fieldName && this.sortDirection === 'asc' ? 'desc' : 'asc';
        this.sortBy = fieldName;
        this.sortData(fieldName, this.sortDirection);
        this.currentPage = 1;
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

    handleExpenseClick(event) {
        event.preventDefault();
        const { id, editable } = event.currentTarget.dataset;
        const pageReference = editable === 'true'
            ? {
                type: 'standard__component',
                attributes: { componentName: 'c__newExpenseForm' },
                state: { c__expenseId: id }
            }
            : {
                type: 'standard__recordPage',
                attributes: { recordId: id, objectApiName: 'Expense__c', actionName: 'view' }
            };

        // Salesforce mobile app has no browser tabs: navigate in place
        if (FORM_FACTOR !== 'Large') {
            this[NavigationMixin.Navigate](pageReference);
            return;
        }

        this[NavigationMixin.GenerateUrl](pageReference)
            .then(url => {
                window.open(url, '_blank');
            })
            .catch(() => {
                this[NavigationMixin.Navigate](pageReference);
            });
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
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // ---------- Pagination (20 rows per page) ----------
    get totalPages() {
        return Math.max(1, Math.ceil(this.expenseCount / PAGE_SIZE));
    }

    get pagedExpenses() {
        const start = (this.currentPage - 1) * PAGE_SIZE;
        return this.expenses.slice(start, start + PAGE_SIZE);
    }

    get showPagination() {
        return this.expenseCount > PAGE_SIZE;
    }

    get pageRangeStart() {
        return this.expenseCount === 0 ? 0 : (this.currentPage - 1) * PAGE_SIZE + 1;
    }

    get pageRangeEnd() {
        return Math.min(this.currentPage * PAGE_SIZE, this.expenseCount);
    }

    get isFirstPage() {
        return this.currentPage <= 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }

    handlePreviousPage() {
        if (!this.isFirstPage) {
            this.currentPage -= 1;
        }
    }

    handleNextPage() {
        if (!this.isLastPage) {
            this.currentPage += 1;
        }
    }

    get hasExpenses() {
        return this.expenses && this.expenses.length > 0;
    }

    get expenseCount() {
        return this.expenses ? this.expenses.length : 0;
    }

    get rejectedCount() {
        return this.expenses ? this.expenses.filter(e => e.canEdit).length : 0;
    }

    get hasRejected() {
        return this.rejectedCount > 0;
    }
}
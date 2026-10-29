import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getTickets from '@salesforce/apex/TicketListViewController.getTickets';
import getStatusSummary from '@salesforce/apex/TicketListViewController.getStatusSummary';

const PAGE_SIZE = 50;
const MAX_ROWS = 2000;
const SEARCH_DEBOUNCE_MS = 400;
const PIN_STORAGE_KEY = 'ticketListView.pinnedViewKey';

const SORT_TO_COLUMN = { TicketNo: 'ticketUrl', CreatedDate: 'createdDate' };
const COLUMN_TO_SORT = { ticketUrl: 'TicketNo', createdDate: 'CreatedDate' };

const VIEWS = [
    { key: 'ALL_TICKETS', label: 'All Internal Tickets', sortField: 'TicketNo', sortDirection: 'asc', filterText: 'Record Type Name' },
    { key: 'OPEN_TICKETS', label: 'All Open Tickets', sortField: 'TicketNo', sortDirection: 'desc', filterText: 'Closed, Record Type Name' },
    { key: 'RESOLVED_TICKETS', label: 'All Resolved Tickets', sortField: 'CreatedDate', sortDirection: 'desc', filterText: 'Status, Record Type Name' },
    { key: 'MY_TICKETS', label: 'My Tickets', sortField: 'TicketNo', sortDirection: 'asc', filterText: 'Owner, Record Type Name' }
];

export default class TicketListView extends NavigationMixin(LightningElement) {
    rows = [];
    hasMore = false;
    limitReached = false;
    cursor = null;
    errorMessage;

    selectedViewKey = 'ALL_TICKETS';
    pinnedViewKey = 'ALL_TICKETS';
    sortField = 'TicketNo';
    sortDirection = 'asc';
    searchTerm = '';
    viewSearch = '';
    isLoading = false;
    isLoadingMore = false;
    viewMenuOpen = false;
    showChart = false;
    chartData = [];
    updatedAt = Date.now();
    now = Date.now();

    _reqId = 0;
    _searchTimer;
    _tick;

    connectedCallback() {
        try {
            const saved = window.localStorage.getItem(PIN_STORAGE_KEY);
            if (saved && VIEWS.some((v) => v.key === saved)) {
                this.pinnedViewKey = saved;
            }
        } catch (e) {
            // localStorage not available
        }
        this.applyViewDefaults(this.pinnedViewKey);
        this.loadFirstPage();

        this._tick = setInterval(() => {
            this.now = Date.now();
        }, 30000);
    }

    disconnectedCallback() {
        clearInterval(this._tick);
        clearTimeout(this._searchTimer);
    }

    // ---------- data loading ----------
    buildRequest(cursor) {
        return {
            viewKey: this.selectedViewKey,
            pageSize: PAGE_SIZE,
            sortField: this.sortField,
            sortDirection: this.sortDirection,
            cursorValue: cursor ? cursor.value : null,
            cursorId: cursor ? cursor.id : null,
            searchTerm: this.searchTerm
        };
    }

    loadFirstPage() {
        const token = ++this._reqId;
        this.rows = [];
        this.cursor = null;
        this.hasMore = false;
        this.limitReached = false;
        this.errorMessage = undefined;
        this.isLoading = true;
        this.isLoadingMore = false;

        getTickets({ requestJson: JSON.stringify(this.buildRequest(null)) })
            .then((res) => {
                if (token !== this._reqId) return;
                this.applyPage(res);
                this.updatedAt = Date.now();
                this.now = this.updatedAt;
            })
            .catch((e) => {
                if (token !== this._reqId) return;
                this.errorMessage = this.reduceError(e);
            })
            .finally(() => {
                if (token === this._reqId) this.isLoading = false;
            });

        if (this.showChart) this.loadChart();
    }

    handleLoadMore() {
        if (this.isLoading || this.isLoadingMore || !this.hasMore) return;
        const token = this._reqId;
        this.isLoadingMore = true;

        getTickets({ requestJson: JSON.stringify(this.buildRequest(this.cursor)) })
            .then((res) => {
                if (token !== this._reqId) return;
                this.applyPage(res);
            })
            .catch((e) => {
                if (token !== this._reqId) return;
                this.errorMessage = this.reduceError(e);
                this.hasMore = false;
            })
            .finally(() => {
                if (token === this._reqId) this.isLoadingMore = false;
            });
    }

    applyPage(res) {
        const mapped = res.rows.map((r) => {
            const url = `/lightning/r/Case/${r.id}/view`;
            return { ...r, ticketUrl: url, subjectUrl: url };
        });
        this.rows = [...this.rows, ...mapped];

        const reachedCap = this.rows.length >= MAX_ROWS;
        this.hasMore = res.hasMore && !reachedCap;
        this.limitReached = res.hasMore && reachedCap;
        this.cursor = res.hasMore ? { value: res.nextCursorValue, id: res.nextCursorId } : null;
    }

    loadChart() {
        getStatusSummary({ requestJson: JSON.stringify(this.buildRequest(null)) })
            .then((data) => {
                this.chartData = data;
            })
            .catch((e) => {
                this.errorMessage = this.reduceError(e);
            });
    }

    // ---------- list views ----------
    get currentView() {
        return VIEWS.find((v) => v.key === this.selectedViewKey) || VIEWS[0];
    }

    applyViewDefaults(key) {
        const v = VIEWS.find((x) => x.key === key) || VIEWS[0];
        this.selectedViewKey = v.key;
        this.sortField = v.sortField;
        this.sortDirection = v.sortDirection;
    }

    handleToggleViewMenu() {
        this.viewMenuOpen = !this.viewMenuOpen;
        this.viewSearch = '';
    }

    handleViewSearch(event) {
        this.viewSearch = event.target.value || '';
    }

    handleSelectView(event) {
        const key = event.currentTarget.dataset.key;
        this.viewMenuOpen = false;
        if (key === this.selectedViewKey) return;

        this.searchTerm = '';
        const input = this.template.querySelector('.js-list-search');
        if (input) input.value = '';
        this.applyViewDefaults(key);
        this.loadFirstPage();
    }

    get filteredViews() {
        const q = this.viewSearch.trim().toLowerCase();
        return VIEWS.filter((v) => !q || v.label.toLowerCase().includes(q)).map((v) => ({
            ...v,
            isSelected: v.key === this.selectedViewKey,
            itemClass:
                'slds-listbox__item slds-media slds-media_center slds-p-vertical_x-small slds-p-horizontal_small list-item' +
                (v.key === this.selectedViewKey ? ' list-item_selected' : '')
        }));
    }

    get hasViewMatches() {
        return this.filteredViews.length > 0;
    }

    // ---------- pin ----------
    get isPinned() {
        return this.pinnedViewKey === this.selectedViewKey;
    }

    get pinVariant() {
        return this.isPinned ? 'brand' : 'border-filled';
    }

    get pinTitle() {
        return this.isPinned ? 'This list view is pinned' : 'Pin this list view';
    }

    handlePin() {
        this.pinnedViewKey = this.selectedViewKey;
        try {
            window.localStorage.setItem(PIN_STORAGE_KEY, this.pinnedViewKey);
        } catch (e) {
            // ignore
        }
    }

    // ---------- search / sort ----------
    handleSearch(event) {
        const value = event.target.value || '';
        clearTimeout(this._searchTimer);
        this._searchTimer = setTimeout(() => {
            if (value.trim() === this.searchTerm.trim()) return;
            this.searchTerm = value;
            this.loadFirstPage();
        }, SEARCH_DEBOUNCE_MS);
    }

    handleSort(event) {
        const field = COLUMN_TO_SORT[event.detail.fieldName];
        if (!field) return;
        this.sortField = field;
        this.sortDirection = event.detail.sortDirection;
        this.loadFirstPage();
    }

    get sortedByColumn() {
        return SORT_TO_COLUMN[this.sortField];
    }

    // ---------- toolbar ----------
    handleRefresh() {
        this.loadFirstPage();
    }

    handleGearSelect(event) {
        const action = event.detail.value;
        if (action === 'pin') {
            this.handlePin();
        } else if (action === 'clear') {
            this.searchTerm = '';
            const input = this.template.querySelector('.js-list-search');
            if (input) input.value = '';
            this.loadFirstPage();
        }
    }

    handleToggleChart() {
        this.showChart = !this.showChart;
        if (this.showChart) this.loadChart();
    }

    get chartVariant() {
        return this.showChart ? 'brand' : 'border-filled';
    }

    get chartBars() {
        const max = Math.max(1, ...this.chartData.map((d) => d.total));
        return [...this.chartData]
            .sort((a, b) => b.total - a.total)
            .map((d) => ({
                key: d.status || 'None',
                label: d.status || '(No status)',
                total: d.total,
                style: `width:${Math.max(2, Math.round((d.total / max) * 100))}%`
            }));
    }

    get hasChartData() {
        return this.chartData.length > 0;
    }

    // ---------- create button ----------
    handleCreateInternalTicket() {
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: { componentName: 'c__internalTicketForm' }
        });
    }

    // ---------- table ----------
    get columns() {
        return [
            {
                label: 'Ticket No.',
                fieldName: 'ticketUrl',
                type: 'url',
                typeAttributes: { label: { fieldName: 'ticketNo' }, target: '_self' },
                sortable: true,
                initialWidth: 170
            },
            {
                label: 'Subject',
                fieldName: 'subjectUrl',
                type: 'url',
                typeAttributes: { label: { fieldName: 'subject' }, target: '_self' },
                initialWidth: 320
            },
            { label: 'Department', fieldName: 'department', type: 'text', initialWidth: 170 },
            { label: 'Module', fieldName: 'module', type: 'text', initialWidth: 170 },
            { label: 'Status', fieldName: 'status', type: 'text', initialWidth: 120 },
            { label: 'Priority', fieldName: 'priority', type: 'text', initialWidth: 110 },
            {
                label: 'Date/Time Opened',
                fieldName: 'createdDate',
                type: 'date',
                typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hour12: true },
                sortable: true,
                initialWidth: 190
            },
            { label: 'Owner Name', fieldName: 'ownerAlias', type: 'text' }
        ];
    }

    // ---------- header labels ----------
    get itemsLabel() {
        const n = this.rows.length;
        return `${n}${this.hasMore || this.limitReached ? '+' : ''} item${n === 1 && !this.hasMore ? '' : 's'}`;
    }

    get sortedByLabel() {
        return this.sortField === 'CreatedDate' ? 'Date/Time Opened' : 'Ticket No.';
    }

    get filteredByLabel() {
        return this.currentView.filterText + (this.searchTerm.trim() ? ', Search' : '');
    }

    get updatedLabel() {
        const mins = Math.floor((this.now - this.updatedAt) / 60000);
        if (mins < 1) return 'Updated a few seconds ago';
        if (mins === 1) return 'Updated 1 minute ago';
        if (mins < 60) return `Updated ${mins} minutes ago`;
        return `Updated ${Math.floor(mins / 60)} hour(s) ago`;
    }

    get isEmpty() {
        return !this.isLoading && !this.errorMessage && this.rows.length === 0;
    }

    get showTable() {
        return this.rows.length > 0 || this.isLoading;
    }

    get viewMenuClass() {
        return 'slds-dropdown slds-dropdown_left view-dropdown' + (this.viewMenuOpen ? '' : ' slds-hide');
    }

    handleRootClick(event) {
        const path = event.composedPath();
        const inside = (name) => path.some((el) => el.dataset && el.dataset.popover === name);
        if (!inside('views')) this.viewMenuOpen = false;
    }

    reduceError(e) {
        if (!e) return 'Unknown error';
        if (Array.isArray(e.body)) return e.body.map((x) => x.message).join(', ');
        if (e.body && e.body.message) return e.body.message;
        return e.message || 'Unknown error';
    }
}
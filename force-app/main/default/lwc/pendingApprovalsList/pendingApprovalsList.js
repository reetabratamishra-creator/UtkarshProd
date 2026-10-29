import { LightningElement, api, track } from 'lwc';

export default class PendingApprovalsList extends LightningElement {
    @api pendingQuotes = [];

    /* 👉 Filter States commented out per user request
    @track searchTerm = '';
    @track selectedDepartment = 'ALL';
    */

    // Checks if there are ANY quotes assigned to this person
    get hasPendingApprovals() {
        return this.pendingQuotes && this.pendingQuotes.length > 0;
    }

    /*
    // 👉 NEW: Auto-Generates the Dropdown Options based on the available quotes
    get departmentOptions() {
        let options = [{ label: 'All Departments', value: 'ALL' }];
        
        if (!this.pendingQuotes) return options;

        let uniqueDepts = new Set();

        this.pendingQuotes.forEach(quote => {
            // Extracts the department from the Name (e.g., gets "Solar Structure - Department" from "Solar Structure - Department / customized")
            // If you eventually create a dedicated Department__c field on the Quote, you can change this to: quote.Department__c
            let deptName = quote.Name ? quote.Name.split('/')[0].trim() : 'Unknown';
            uniqueDepts.add(deptName);
        });

        // Alphabetize and add to options
        Array.from(uniqueDepts).sort().forEach(dept => {
            options.push({ label: dept, value: dept });
        });

        return options;
    }
    */

    // 👉 THE FILTER ENGINE (modified to return all pending quotes without filtering)
    get filteredQuotes() {
        if (!this.pendingQuotes) return [];
        return this.pendingQuotes;
        /*
        return this.pendingQuotes.filter(quote => {
            // 1. Text Search Filter (Matches Quote Name OR Submitter Name)
            let matchesSearch = true;
            if (this.searchTerm) {
                const searchLower = this.searchTerm.toLowerCase();
                const nameMatch = quote.Name && quote.Name.toLowerCase().includes(searchLower);
                const submitterMatch = quote.submitterName && quote.submitterName.toLowerCase().includes(searchLower);
                matchesSearch = nameMatch || submitterMatch;
            }

            // 2. Department Filter
            let matchesDept = true;
            if (this.selectedDepartment && this.selectedDepartment !== 'ALL') {
                let quoteDept = quote.Name ? quote.Name.split('/')[0].trim() : 'Unknown';
                matchesDept = (quoteDept === this.selectedDepartment);
            }

            // The quote only shows up if it passes ALL active filters
            return matchesSearch && matchesDept;
        });
        */
    }

    // Checks if the table should show the "No quotes match" message
    get hasFilteredQuotes() {
        return this.filteredQuotes.length > 0;
    }

    /*
    // 👉 Handlers for Filter Inputs
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    handleDepartmentChange(event) {
        this.selectedDepartment = event.detail.value;
    }

    clearFilters() {
        this.searchTerm = '';
        this.selectedDepartment = 'ALL';
    }
    */

    // 👉 Dispatches the event back to the parent to open the quote
    handleReviewClick(event) {
        const selectedQuoteId = event.currentTarget.dataset.id;
        const reviewEvent = new CustomEvent('reviewquote', {
            detail: { quoteId: selectedQuoteId }
        });
        this.dispatchEvent(reviewEvent);
    }
}
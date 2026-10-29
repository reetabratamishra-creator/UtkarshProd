import { LightningElement, api, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { registerRefreshHandler, unregisterRefreshHandler } from 'lightning/refresh';
import getEmployeeTimeline from '@salesforce/apex/EmployeeTimelineController.getEmployeeTimeline';
import addEmployeeTimelineItemWithCategory from '@salesforce/apex/EmployeeTimelineController.addEmployeeTimelineItemWithCategory';
import getReasonForVisitOptions from '@salesforce/apex/EmployeeTimelineController.getReasonForVisitOptions';
import getPOCPicVal from '@salesforce/apex/EmployeeTimelineController.getPOCPicVal';
import getVisitOutcomePicVal from '@salesforce/apex/EmployeeTimelineController.getVisitOutcomePicVal';
import taskDetails from '@salesforce/apex/EmployeeTimelineController.taskDetails';
import getApprovedWfhWfoRequestsToday from '@salesforce/apex/EmployeeTimelineController.getApprovedWfhWfoRequestsToday';
import getCustomerCategoryOptions from '@salesforce/apex/EmployeeTimelineController.getCustomerCategoryOptions';

// NEW IMPORTS FOR VISIT JOURNEY
import getOwnedLeads from '@salesforce/apex/EmployeeTimelineController.getOwnedLeads';
import getOwnedOpportunities from '@salesforce/apex/EmployeeTimelineController.getOwnedOpportunities';
import getNearbyAccounts from '@salesforce/apex/EmployeeTimelineController.getNearbyAccounts';
import getAllAccounts from '@salesforce/apex/EmployeeTimelineController.getAllAccounts';
import createAccountOrSite from '@salesforce/apex/EmployeeTimelineController.createAccountOrSite';
import updateTaskWithDisposition from '@salesforce/apex/EmployeeTimelineController.updateTaskWithDisposition';
import getScheduledVisits from '@salesforce/apex/EmployeeTimelineController.getScheduledVisits';
import rescheduleScheduledVisit from '@salesforce/apex/EmployeeTimelineController.rescheduleScheduledVisit';
import cancelScheduledVisit from '@salesforce/apex/EmployeeTimelineController.cancelScheduledVisit';
import searchOpportunities from '@salesforce/apex/EmployeeTimelineController.searchOpportunities';
import getEligibleSites from '@salesforce/apex/EmployeeTimelineController.getEligibleSites';
import checkAddressBook from '@salesforce/apex/EmployeeTimelineController.checkAddressBook';
import getContactsForAccount from '@salesforce/apex/EmployeeTimelineController.getContactsForAccount';
import searchAccounts from '@salesforce/apex/EmployeeTimelineController.searchAccounts';

export default class PunchTimeline extends NavigationMixin(LightningElement) {
    @api recordId; // Employee__c Id
    @api activePunchType = '';

    get isMarketVisitActive() {
        return this.activePunchType === 'Market Visit';
    }

    @track items = [];
    @track isLoading = true;
    @track showModal = false;
    @track saving = false;
    @track scheduledVisits = [];
    @track isScheduledCollapsed = false;
    @track selectedVisitDateObj = new Date();
    @track isDateLoading = false;
    dateTimeoutId;

    // Reschedule & Cancel Scheduled Visits properties
    @track showScheduleActionModal = false;
    @track scheduleActionType = 'Reschedule'; // 'Reschedule' or 'Cancel'
    @track scheduleActionReason = '';
    @track scheduleActionDate = '';
    // @track scheduleActionTime = '';
    @track savingScheduleAction = false;

    // Enquiry Association Type / Paths
    @track selectedEnquiryPath = 'Opps'; // 'Opps', 'NoEnquiry'
    @track leadOptions = [];
    @track selectedLeadId = '';
    @track scheduledLeadName = '';
    @track opportunityOptions = [];
    @track selectedOpportunityId = '';
    @track nearbyAccountOptions = [];
    @track accountOptions = [];
    @track selectedAccountId = '';
    @track parentAccountId = '';
    @track newAccountName = '';
    @track newAccountPhone = '';
    @track newAccountEmail = '';
    @track showNewAccountInline = false;

    // Account Search state for New Enquiry
    @track accSearchKey = '';
    @track rawAccounts = [];
    @track showAccDropdown = false;
    @track createNewAccount = false;
    @track accountSearchOptions = [];

    // Opportunity Search & Site selection state
    @track oppSearchKey = '';
    @track rawOpportunities = [];
    @track showOppDropdown = false;
    @track associatedAccountId = '';
    @track associatedAccountName = '';
    @track selectedTagVisitOption = 'Account';
    @track selectedSiteId = '';
    @track eligibleSites = [];
    @track newSiteName = '';
    @track addressBookStatusMessage = '';
    @track selectedAddressBookId = null;

    // Checkout contacts state
    @track hasExistingContacts = false;
    @track existingContactOptions = [];
    @track selectedContactId = '';
    @track showNewContactForm = false;
    @track resolvedAccountId = '';

    // Check-out properties
    @track checkedOutModal = false;
    @track serverVisitOutcomeOptions = [];
    @track visitOutcomeValue = '';
    @track nextActionValue = '';
    @track followUpDate;
    @track momValue = '';
    @track taskId = '';
    @track customerName = '';
    @track customerCategory = '';
    @track customerCategoryLocked = false;
    @track customerType = '';
    @track savingCheckedOut = false;
    @track selfiePreview = '';
    @track isSelfieCameraOpen = false;
    @track selectedScheduledVisitId = '';
    @track fileData;
    @track is100mOutside = false;
    @track justificationValue = '';
    selfieStream; // To track camera stream
    @track showImageModal = false;
    @track modalImageUrl = '';

    // Visit Category & Approved request tracking
    @track visitCategoryValue = 'Market Visit';
    @track selectedApprovedRequestId = '';
    @track approvedRequests = [];
    approvedRequestsWired;

    // POC contact details
    @track pocValue = 'No'; // 'Yes' | 'No'
    @track newContactFirstName = '';
    @track newContactLastName = '';
    @track newContactEmail = '';
    @track newContactPhone = '';

    // Remaining Account details (for No Enquiry path)
    @track remainingAccountPhone = '';
    @track remainingAccountEmail = '';
    @track remainingAccountContactName = '';
    @track customerCategoryOptions = [];
    @track followUpTypeValue = 'Visit';

    // Post checkout disposition
    @track postDispositionValue = 'No Action';
    @track lostReasonValue = '';

    // picklist options cached from describe or custom
    _reasonForVisitOptions = [];
    opportunitiesList = [];
    @track reasonForVisitValue = '';
    @track visitTypeValue = 'Follow up';

    limitSize = 100;
    wiredResult;
    currentLatitude;
    currentLongitude;

    // ── enquiry path / checkin helpers ──────────────────────────────────────
    get enquiryPathOptions() {
        return [
            { label: 'Check In against Opportunity', value: 'Opps' },
            { label: 'Check In for New Enquiry', value: 'NoEnquiry' }
        ];
    }

    get isLeadsPath() { return false; }
    get hasScheduledLead() { return !!this.selectedLeadId && !!this.scheduledLeadName; }
    get isAccountSelectionRequired() { return !this.hasScheduledLead; }
    get isOppsPath() { return this.selectedEnquiryPath === 'Opps'; }
    get isNoEnquiryPath() { return this.selectedEnquiryPath === 'NoEnquiry'; }
    get isMarketVisit() { return this.visitCategoryValue === 'Market Visit'; }

    handleEnquiryPathChange(event) {
        this.selectedEnquiryPath = event.detail.value;
        // Keep scheduled visit link so check-in still removes it from the schedule list
        const scheduledVisitId = this.selectedScheduledVisitId;
        const scheduledLeadId = this.selectedLeadId;
        const scheduledLeadName = this.scheduledLeadName;
        this.resetCheckInSelections();
        this.selectedScheduledVisitId = scheduledVisitId;
        this.selectedLeadId = scheduledLeadId;
        this.scheduledLeadName = scheduledLeadName;
    }

    resetCheckInSelections() {
        this.selectedLeadId = '';
        this.scheduledLeadName = '';
        this.selectedOpportunityId = '';
        this.selectedAccountId = '';
        this.parentAccountId = '';
        this.newAccountName = '';
        this.newAccountPhone = '';
        this.newAccountEmail = '';
        this.showNewAccountInline = false;
        this.selectedScheduledVisitId = '';
        this.visitCategoryValue = 'Market Visit';
        this.selectedApprovedRequestId = '';
        
        // Reset Account search/tagging state
        this.accSearchKey = '';
        this.rawAccounts = [];
        this.showAccDropdown = false;
        this.createNewAccount = false;
        this.accountSearchOptions = [];

        // Reset Opportunity search/tagging state
        this.oppSearchKey = '';
        this.rawOpportunities = [];
        this.showOppDropdown = false;
        this.associatedAccountId = '';
        this.associatedAccountName = '';
        this.selectedTagVisitOption = 'Account';
        this.selectedSiteId = '';
        this.eligibleSites = [];
        this.newSiteName = '';
        this.addressBookStatusMessage = '';
        this.selectedAddressBookId = null;
    }

    get tagVisitOptions() {
        return [
            { label: 'Account', value: 'Account' },
            { label: 'Site', value: 'Site' }
        ];
    }

    get isAccountTagOptionSelected() {
        return this.selectedTagVisitOption === 'Account';
    }

    get isSiteTagOptionSelected() {
        return this.selectedTagVisitOption === 'Site';
    }

    get hasEligibleSites() {
        // Only count real sites from Apex, NOT the synthetic 'Create New Site' option
        return this.eligibleSites && this.eligibleSites.length > 0;
    }

    get eligibleSiteOptions() {
        if (!this.eligibleSites) return [];
        let opts = this.eligibleSites.map(s => ({ label: s.Name, value: s.Id }));
        opts.push({ label: 'Create New Site', value: 'new' });
        return opts;
    }

    get showNewSiteInput() {
        // Show input when no real sites exist, OR user explicitly chose 'Create New Site'
        return !this.hasEligibleSites || this.selectedSiteId === 'new';
    }

    get isAccOptionsEmpty() {
        return !this.accountSearchOptions || this.accountSearchOptions.length === 0;
    }

    handleAccSearchKeyChange(event) {
        this.accSearchKey = event.target.value;
        this.showAccDropdown = true;
        
        clearTimeout(this.searchTimeout);
        this.searchTimeout = setTimeout(() => {
            this.executeAccountSearch();
        }, 300);
    }

    handleAccSearchFocus() {
        this.showAccDropdown = true;
        if (this.accSearchKey && (!this.accountSearchOptions || this.accountSearchOptions.length === 0)) {
            this.executeAccountSearch();
        }
    }

    handleAccSearchBlur() {
        setTimeout(() => {
            this.showAccDropdown = false;
        }, 200);
    }

    handleAccDropdownSelect(event) {
        const accId = event.currentTarget.dataset.value;
        const accLabel = event.currentTarget.dataset.label;
        this.accSearchKey = accLabel;
        this.selectedAccountId = accId;
        this.showAccDropdown = false;
        
        this.handleAccountChange({ detail: { value: accId } });
    }

    executeAccountSearch() {
        searchAccounts({ searchKey: this.accSearchKey })
            .then(result => {
                this.accountSearchOptions = result.map(a => ({
                    label: `${a.Name} ${a.Phone ? '(' + a.Phone + ')' : ''}`,
                    value: a.Id
                }));
                this.rawAccounts = result;
            })
            .catch(err => {
                console.error(err);
            });
    }

    handleAccountChange(event) {
        this.selectedAccountId = event.detail.value;
        let selectedAcc = this.rawAccounts.find(a => a.Id === this.selectedAccountId);
        if (!selectedAcc && this.accountOptions) {
            // fallback: check in accountOptions
            const opt = this.accountOptions.find(o => o.value === this.selectedAccountId);
            if (opt) {
                selectedAcc = { Id: opt.value, Name: opt.label };
            }
        }
        if (selectedAcc) {
            this.associatedAccountId = selectedAcc.Id;
            this.associatedAccountName = selectedAcc.Name;
            this.selectedTagVisitOption = 'Account';
            this.selectedAddressBookId = null;
            this.selectedSiteId = '';
            this.newSiteName = '';
            this.addressBookStatusMessage = 'Checking Address Book...';
            this.checkAccountAddressBook();
        }
    }

    handleCreateNewAccountToggle(event) {
        this.createNewAccount = event.target.checked;
        if (this.createNewAccount) {
            this.selectedAccountId = '';
            this.associatedAccountId = '';
            this.associatedAccountName = '';
            this.selectedAddressBookId = null;
            this.selectedSiteId = '';
            this.newSiteName = '';
            this.addressBookStatusMessage = '';
        }
    }

    get isOppOptionsEmpty() {
        return !this.opportunityOptions || this.opportunityOptions.length === 0;
    }

    handleOppSearchKeyChange(event) {
        this.oppSearchKey = event.target.value;
        this.showOppDropdown = true;
        
        clearTimeout(this.searchTimeout);
        this.searchTimeout = setTimeout(() => {
            this.executeOpportunitySearch();
        }, 300);
    }

    handleOppSearchFocus() {
        this.showOppDropdown = true;
        if (this.oppSearchKey && (!this.opportunityOptions || this.opportunityOptions.length === 0)) {
            this.executeOpportunitySearch();
        }
    }

    handleOppSearchBlur() {
        setTimeout(() => {
            this.showOppDropdown = false;
        }, 200);
    }

    handleOppDropdownSelect(event) {
        const oppId = event.currentTarget.dataset.value;
        const oppLabel = event.currentTarget.dataset.label;
        this.oppSearchKey = oppLabel;
        this.selectedOpportunityId = oppId;
        this.showOppDropdown = false;
        
        this.handleOpportunityChange({ detail: { value: oppId } });
    }

    executeOpportunitySearch() {
        searchOpportunities({ searchKey: this.oppSearchKey })
            .then(result => {
                this.opportunityOptions = result.map(o => ({
                    label: `${o.Name} (Account: ${this.headAccountName(o)})`,
                    value: o.Id
                }));
                this.rawOpportunities = result;
            })
            .catch(err => {
                console.error(err);
            });
    }

    handleOpportunityChange(event) {
        this.selectedOpportunityId = event.detail.value;
        let selectedOpp = this.rawOpportunities.find(o => o.Id === this.selectedOpportunityId);
        if (!selectedOpp) {
            selectedOpp = this.opportunitiesList.find(o => o.Id === this.selectedOpportunityId);
        }
        if (selectedOpp && selectedOpp.AccountId) {
            this.applyAssociatedAccountFromOpportunity(selectedOpp);
            this.selectedTagVisitOption = 'Account';
            this.selectedAddressBookId = null;
            this.selectedSiteId = '';
            this.newSiteName = '';
            this.addressBookStatusMessage = 'Checking Address Book...';
            this.checkAccountAddressBook();
        }
    }

    applyAssociatedAccountFromOpportunity(opp) {
        const parentId = opp.Account && opp.Account.ParentId;
        this.associatedAccountId = parentId || opp.AccountId;
        this.selectedAccountId = this.associatedAccountId;
        this.associatedAccountName = parentId
            ? (opp.Account.Parent && opp.Account.Parent.Name) || ''
            : (opp.Account ? opp.Account.Name : '');
    }

    headAccountName(opp) {
        if (!opp || !opp.Account) {
            return 'None';
        }
        if (opp.Account.ParentId && opp.Account.Parent && opp.Account.Parent.Name) {
            return opp.Account.Parent.Name;
        }
        return opp.Account.Name || 'None';
    }

    handleTagVisitOptionChange(event) {
        this.selectedTagVisitOption = event.detail.value;
        if (this.selectedTagVisitOption === 'Account') {
            this.checkAccountAddressBook();
        } else if (this.selectedTagVisitOption === 'Site') {
            this.fetchEligibleSitesForAccount();
        }
    }

    async checkAccountAddressBook() {
        try {
            const loc = await this.getCurrentLocation();
            this.currentLatitude = loc.latitude;
            this.currentLongitude = loc.longitude;
            
            const res = await checkAddressBook({
                accountId: this.associatedAccountId,
                latitude: this.currentLatitude,
                longitude: this.currentLongitude
            });
            
            if (res && res.found) {
                this.selectedAddressBookId = res.addressBookId;
                this.addressBookStatusMessage = `Matching address found in Address Book: "${res.address}". Visit will be tagged to it.`;
            } else {
                this.selectedAddressBookId = null;
                this.addressBookStatusMessage = 'No matching address found within 200 meters. A new address entry will be created in the Address Book upon check-in via Mapbox.';
            }
        } catch (error) {
            console.error(error);
            this.selectedAddressBookId = null;
            this.addressBookStatusMessage = 'Geocoordinates check failed. A new address entry will be created in the Address Book upon check-in via Mapbox.';
        }
    }

    async fetchEligibleSitesForAccount() {
        try {
            const loc = await this.getCurrentLocation();
            this.currentLatitude = loc.latitude;
            this.currentLongitude = loc.longitude;
            
            const sites = await getEligibleSites({
                parentAccountId: this.associatedAccountId,
                latitude: this.currentLatitude,
                longitude: this.currentLongitude
            });
            this.eligibleSites = sites;
            if (sites && sites.length > 0) {
                this.selectedSiteId = sites[0].Id;
                this.selectedAccountId = sites[0].Id;
            } else {
                this.selectedSiteId = 'new';
                this.selectedAccountId = '';
            }
        } catch (error) {
            console.error(error);
            this.eligibleSites = [];
            this.selectedSiteId = 'new';
            this.selectedAccountId = '';
        }
    }

    handleSiteChange(event) {
        this.selectedSiteId = event.detail.value;
        if (this.selectedSiteId !== 'new') {
            this.selectedAccountId = this.selectedSiteId;
        } else {
            this.selectedAccountId = '';
        }
    }

    handleNewSiteNameChange(event) {
        this.newSiteName = event.target.value;
    }

    toggleNewAccountInline() {
        this.showNewAccountInline = !this.showNewAccountInline;
        this.newAccountName = '';
        this.newAccountPhone = '';
        this.newAccountEmail = '';
        this.parentAccountId = '';
        if (!this.showNewAccountInline) {
            this.selectedAccountId = '';
        }
    }

    handleNewAccountNameChange(event) {
        this.newAccountName = event.detail.value;
    }

    handleNewAccountPhoneChange(event) {
        this.newAccountPhone = event.detail.value;
    }

    handleNewAccountEmailChange(event) {
        this.newAccountEmail = event.detail.value;
    }

    handleParentAccountChange(event) {
        this.parentAccountId = event.detail.value;
    }

    handleJustificationChange(event) {
        this.justificationValue = event.detail.value;
    }

    // Options for Visit Type
    get visitTypeOptions() {
        return [
            { label: 'First time visit', value: 'First time visit' },
            { label: 'Follow up', value: 'Follow up' }
        ];
    }

    get hasApprovedWfh() {
        return this.approvedRequests.some(r => r.Is_WFH_Request__c === true);
    }

    get hasApprovedWfo() {
        return this.approvedRequests.some(r => r.Is_WFO_Request__c === true);
    }

    get approvedWfhOptions() {
        return this.approvedRequests
            .filter(r => r.Is_WFH_Request__c === true)
            .map(r => {
                const startTime = r.WFH_Request_Start_Time__c ? this.formatTimeMs(r.WFH_Request_Start_Time__c) : '';
                const endTime = r.WFH_Request_End_Time__c ? this.formatTimeMs(r.WFH_Request_End_Time__c) : '';
                return {
                    label: `WFH Request (${startTime} - ${endTime})`,
                    value: r.Id
                };
            });
    }

    get approvedWfoOptions() {
        return this.approvedRequests
            .filter(r => r.Is_WFO_Request__c === true)
            .map(r => {
                const startTime = r.WFH_Request_Start_Time__c ? this.formatTimeMs(r.WFH_Request_Start_Time__c) : '';
                const endTime = r.WFH_Request_End_Time__c ? this.formatTimeMs(r.WFH_Request_End_Time__c) : '';
                return {
                    label: `WFO Request (${startTime} - ${endTime})`,
                    value: r.Id
                };
            });
    }

    formatTimeMs(ms) {
        let seconds = Math.floor(ms / 1000);
        let minutes = Math.floor(seconds / 60);
        let hours = Math.floor(minutes / 60);
        minutes = minutes % 60;
        const ampm = hours >= 12 ? 'PM' : 'AM';
        hours = hours % 12;
        hours = hours ? hours : 12;
        const minStr = minutes < 10 ? '0' + minutes : minutes;
        return `${hours}:${minStr} ${ampm}`;
    }

    get visitCategoryOptions() {
        return [
            { label: 'Market Visit', value: 'Market Visit' },
            { label: 'Work From Home (WFH)', value: 'WFH', disabled: !this.hasApprovedWfh },
            { label: 'Work From Office (WFO)', value: 'WFO', disabled: !this.hasApprovedWfo }
        ];
    }

    handleVisitCategoryChange(event) {
        this.visitCategoryValue = event.detail.value;
        this.selectedApprovedRequestId = '';
        
        if (this.visitCategoryValue === 'WFH') {
            this.reasonForVisitValue = 'WFH Session';
            this.visitTypeValue = 'WFH';
            const wfhReqs = this.approvedRequests.filter(r => r.Is_WFH_Request__c === true);
            if (wfhReqs.length === 1) {
                this.selectedApprovedRequestId = wfhReqs[0].Id;
            }
        } else if (this.visitCategoryValue === 'WFO') {
            this.reasonForVisitValue = 'WFO Session';
            this.visitTypeValue = 'WFO';
            const wfoReqs = this.approvedRequests.filter(r => r.Is_WFO_Request__c === true);
            if (wfoReqs.length === 1) {
                this.selectedApprovedRequestId = wfoReqs[0].Id;
            }
        } else {
            this.reasonForVisitValue = '';
            this.visitTypeValue = '';
        }
    }

    handleApprovedRequestChange(event) {
        this.selectedApprovedRequestId = event.detail.value;
    }

    get isWfhCategorySelected() {
        return this.visitCategoryValue === 'WFH';
    }

    get isWfoCategorySelected() {
        return this.visitCategoryValue === 'WFO';
    }

    handleVisitReasonChange(event) {
        this.reasonForVisitValue = event.detail.value;
    }

    handleVisitTypeChange(event) {
        this.visitTypeValue = event.detail.value;
    }

    // ── Check-out POC / details helpers ──────────────────────────────────────
    get pocRadioOptions() {
        return [
            { label: 'Yes', value: 'Yes' },
            { label: 'No', value: 'No' }
        ];
    }

    get isPocAvailable() { return this.pocValue === 'Yes'; }

    handlePocChange(event) {
        this.pocValue = event.detail.value;
    }

    handleContactFirstNameChange(event) { this.newContactFirstName = event.detail.value; }
    handleContactLastNameChange(event) { this.newContactLastName = event.detail.value; }
    handleContactEmailChange(event) { this.newContactEmail = event.detail.value; }
    handleContactPhoneChange(event) { this.newContactPhone = event.detail.value; }

    handleContactSelectionChange(event) {
        this.selectedContactId = event.detail.value;
        this.showNewContactForm = (this.selectedContactId === 'new');
    }

    loadContactsForActiveAccount() {
        if (!this.resolvedAccountId) {
            this.hasExistingContacts = false;
            this.showNewContactForm = true;
            this.selectedContactId = 'new';
            return;
        }
        
        getContactsForAccount({ accountId: this.resolvedAccountId })
            .then(result => {
                if (result && result.length > 0) {
                    this.hasExistingContacts = true;
                    this.existingContactOptions = result.map(c => ({
                        label: `${c.FirstName || ''} ${c.LastName || ''} (${c.Phone || 'No Phone'})`,
                        value: c.Id
                    }));
                    this.existingContactOptions.push({ label: 'Create New Contact', value: 'new' });
                    this.selectedContactId = result[0].Id;
                    this.showNewContactForm = false;
                } else {
                    this.hasExistingContacts = false;
                    this.showNewContactForm = true;
                    this.selectedContactId = 'new';
                }
            })
            .catch(err => {
                console.error(err);
                this.hasExistingContacts = false;
                this.showNewContactForm = true;
                this.selectedContactId = 'new';
            });
    }

    get normalizedCustomerType() {
        if (!this.customerType) return '';
        const ct = String(this.customerType).toLowerCase();
        if (ct.includes('lead')) return 'Lead';
        if (ct.includes('opp')) return 'Opportunity';
        if (ct.includes('account') || ct.includes('noenquiry')) return 'Account';
        return this.customerType;
    }

    get isTaskNoEnquiryPath() {
        // No Enquiry path means check-in under Account
        return this.normalizedCustomerType === 'Account';
    }

    handleRemainingPhoneChange(event) { this.remainingAccountPhone = event.detail.value; }
    handleRemainingEmailChange(event) { this.remainingAccountEmail = event.detail.value; }
    handleRemainingContactNameChange(event) { this.remainingAccountContactName = event.detail.value; }
    handleCustomerCategoryChange(event) {
        if (this.customerCategoryLocked) {
            return;
        }
        this.customerCategory = event.detail.value;
    }

    get isCustomerCategoryLocked() {
        return this.customerCategoryLocked === true && !!this.customerCategory;
    }

    applyExistingCustomerCategory(value) {
        const category = value == null ? '' : String(value).trim();
        if (!category) {
            return;
        }
        this.customerCategory = category;
        this.customerCategoryLocked = true;
        this.ensureCustomerCategoryOption(category);
    }

    ensureCustomerCategoryOption(category) {
        if (!category) {
            return;
        }
        const options = this.customerCategoryOptions || [];
        if (!options.some(opt => opt.value === category)) {
            this.customerCategoryOptions = [{ label: category, value: category }, ...options];
        }
    }

    handleFollowUpTypeChange(event) { this.followUpTypeValue = event.detail.value; }

    get followUpTypeOptions() {
        return [
            { label: 'Call', value: 'Call' },
            { label: 'Event', value: 'Event' },
            { label: 'Visit', value: 'Visit' }
        ];
    }

    // ── Post checkout disposition helpers ────────────────────────────────────
    get postDispositionOptions() {
        const type = this.normalizedCustomerType;
        if (type === 'Lead') {
            return [
                { label: 'Mark Lead as Lost', value: 'Mark Lead as Lost' },
                { label: 'Convert Lead', value: 'Convert Lead' },
                { label: 'No Action', value: 'No Action' }
            ];
        } else if (type === 'Opportunity') {
            return [
                { label: 'Edit Opportunity', value: 'Edit Opportunity' },
                { label: 'No Action', value: 'No Action' }
            ];
        } else if (type === 'Account') {
            return [
                { label: 'Create Lead', value: 'Create Lead' },
                { label: 'Create Opportunity', value: 'Create Opportunity' },
                { label: 'No Action', value: 'No Action' }
            ];
        }
        return [
            { label: 'No Action', value: 'No Action' }
        ];
    }

    get isLeadLost() {
        return this.postDispositionValue === 'Mark Lead as Lost';
    }

    get hasCheckoutFile() {
        return !!(this.fileData && this.fileData.fileName);
    }

    get checkoutFileName() {
        return this.fileData?.fileName || '';
    }

    get lostReasonOptions() {
        return [
            { label: 'Price Enquiry', value: 'Price Enquiry' },
            { label: 'Purchase from Other Brand', value: 'Purchase from Other Brand' },
            { label: 'Duplicate Lead', value: 'Duplicate Lead' },
            { label: 'Invalid Number', value: 'Invalid Number' },
            { label: 'Customer Details Not Received', value: 'Customer Details Not Received' },
            { label: 'Not Looking for This Product', value: 'Not Looking for This Product' },
            { label: 'Out of Service Area', value: 'Out of Service Area' },
            { label: 'Minimum Quantity Not Met', value: 'Minimum Quantity Not Met' },
            { label: 'Existing Customer', value: 'Existing Customer' },
            { label: 'Internal Problem', value: 'Internal Problem' },
            { label: 'Future Prospect', value: 'Future Prospect' },
            { label: 'Not Responding', value: 'Not Responding' },
            { label: 'Out of Product Range', value: 'Out of Product Range' },
            { label: 'Not Approved', value: 'Not Approved' },
            { label: 'Fake Enquiry', value: 'Fake Enquiry' }
        ];
    }

    handleDispositionChange(event) {
        this.postDispositionValue = event.detail.value;
        this.lostReasonValue = '';
    }

    handleLostReasonChange(event) {
        this.lostReasonValue = event.detail.value;
    }

    // ── Wire & data loading ──────────────────────────────────────────────────
    wiredScheduledResult;

    // Cacheable Apex results are persisted on the mobile device, so a
    // reschedule/cancel done on web is invisible there until the cache expires.
    // Re-fetch from the server on load, on returning to the app, and on
    // pull-to-refresh.
    _scheduledFreshLoaded = false;
    _timelineFreshLoaded = false;
    _refreshHandlerId;
    _onVisibilityChange;

    connectedCallback() {
        this._onVisibilityChange = () => {
            if (document.visibilityState === 'visible') {
                this.refreshAll();
            }
        };
        document.addEventListener('visibilitychange', this._onVisibilityChange);
        this._refreshHandlerId = registerRefreshHandler(this, () => this.refreshAll().then(() => true));
    }

    disconnectedCallback() {
        document.removeEventListener('visibilitychange', this._onVisibilityChange);
        if (this._refreshHandlerId) {
            unregisterRefreshHandler(this._refreshHandlerId);
        }
    }

    refreshAll() {
        const refreshes = [];
        if (this.wiredScheduledResult) {
            refreshes.push(refreshApex(this.wiredScheduledResult));
        }
        if (this.wiredResult) {
            refreshes.push(refreshApex(this.wiredResult));
        }
        return Promise.all(refreshes).catch(error => {
            console.error('Error refreshing punch timeline', error);
        });
    }

    @wire(getScheduledVisits, { employeeId: '$recordId' })
    wiredScheduledVisits(result) {
        this.wiredScheduledResult = result;
        if (!this._scheduledFreshLoaded && (result.data || result.error)) {
            // First emission may be a stale device-cached copy
            this._scheduledFreshLoaded = true;
            refreshApex(result);
        }
        const { data, error } = result;
        if (data) {
            this.scheduledVisits = data.map(visit => {
                let formattedDate = 'No Date';
                if (visit.followUpDate) {
                    try {
                        const d = new Date(visit.followUpDate);
                        formattedDate = d.toLocaleDateString('en-IN', {
                            day: 'numeric',
                            month: 'short',
                            year: 'numeric'
                        });
                    } catch (e) {
                        formattedDate = visit.followUpDate;
                    }
                }
                return {
                    ...visit,
                    formattedDate,
                    displayPurpose: visit.reasonForVisit || visit.nextAction || 'Visit',
                    isCancelled: visit.isCancelled === true,
                    cancelReason: visit.cancelReason || ''
                };
            });
        } else if (error) {
            console.error('Error loading scheduled visits', error);
            this.scheduledVisits = [];
        }
    }

    @wire(getApprovedWfhWfoRequestsToday, { employeeId: '$recordId' })
    wiredApprovedRequests(result) {
        this.approvedRequestsWired = result;
        if (result.data) {
            this.approvedRequests = result.data;
        } else if (result.error) {
            this.approvedRequests = [];
        }
    }

    get selectedVisitDate() {
        const d = this.selectedVisitDateObj;
        const offset = d.getTimezoneOffset();
        const localD = new Date(d.getTime() - (offset * 60 * 1000));
        return localD.toISOString().split('T')[0];
    }

    get selectedVisitDateDisplay() {
        const d = new Date();
        const offset = d.getTimezoneOffset();
        const localD = new Date(d.getTime() - (offset * 60 * 1000));
        const todayStr = localD.toISOString().split('T')[0];

        if (this.selectedVisitDate === todayStr) {
            return 'Today';
        }
        return this.selectedVisitDateObj.toLocaleDateString('en-IN', {
            day: 'numeric',
            month: 'short',
            year: 'numeric'
        });
    }

    get filteredScheduledVisits() {
        if (!this.scheduledVisits) return [];
        return this.scheduledVisits.filter(visit => {
            return visit.followUpDate === this.selectedVisitDate && !visit.isCancelled;
        });
    }

    get filteredCancelledVisits() {
        if (!this.scheduledVisits) return [];
        return this.scheduledVisits.filter(visit => {
            return visit.followUpDate === this.selectedVisitDate && visit.isCancelled;
        });
    }

    get hasScheduledVisits() {
        return this.filteredScheduledVisits && this.filteredScheduledVisits.length > 0;
    }

    get hasCancelledVisits() {
        return this.filteredCancelledVisits && this.filteredCancelledVisits.length > 0;
    }

    get hasAnyVisits() {
        return this.hasScheduledVisits || this.hasCancelledVisits;
    }

    get scheduledVisitsCount() {
        return this.filteredScheduledVisits ? this.filteredScheduledVisits.length : 0;
    }

    get cancelledVisitsCount() {
        return this.filteredCancelledVisits ? this.filteredCancelledVisits.length : 0;
    }

    get toggleIconName() {
        return this.isScheduledCollapsed ? 'utility:chevrondown' : 'utility:chevronup';
    }

    get isIOS() {
        return /iPad|iPhone|iPod/.test(navigator.userAgent) || 
            (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    }

    toggleScheduledVisits() {
        this.isScheduledCollapsed = !this.isScheduledCollapsed;
    }

    triggerDateLoading() {
        this.isDateLoading = true;
        if (this.dateTimeoutId) {
            clearTimeout(this.dateTimeoutId);
        }
        this.dateTimeoutId = setTimeout(() => {
            this.isDateLoading = false;
        }, 400);
    }

    handlePrevDay() {
        this.triggerDateLoading();
        const newDate = new Date(this.selectedVisitDateObj);
        newDate.setDate(newDate.getDate() - 1);
        this.selectedVisitDateObj = newDate;
    }

    handleNextDay() {
        this.triggerDateLoading();
        const newDate = new Date(this.selectedVisitDateObj);
        newDate.setDate(newDate.getDate() + 1);
        this.selectedVisitDateObj = newDate;
    }

    handleResetToToday() {
        this.triggerDateLoading();
        this.selectedVisitDateObj = new Date();
    }

    handleScheduledCheckIn(event) {
        const visitId = event.currentTarget.dataset.id;
        const visit = this.scheduledVisits.find(v => v.id === visitId);
        if (!visit) return;

        if (!this.isMarketVisitActive) {
            this.showToast('Action Blocked', 'Check-In is only available while Market Visit mode is active.', 'error');
            return;
        }

        const hasOpenTask = this.items?.some(item => item.isCheckout === false);
        if (hasOpenTask) {
            this.showToast('Error', 'You cannot add a new task without checking out the current task.', 'error');
            return;
        }

        this.showModal = true;
        this.resetCheckInSelections();
        if (this.approvedRequestsWired) {
            refreshApex(this.approvedRequestsWired);
        }
        this.selectedScheduledVisitId = visitId;

        // Customer_Type__c only holds New/Existing, so the anchor record is
        // resolved server-side into associationType.
        const resolvedCustType = visit.associationType ||
            (visit.opportunityId ? 'Opportunity' : (visit.leadId ? 'Lead' : (visit.accountId ? 'Account' : '')));

        if (resolvedCustType === 'Lead') {
            // There is no lead picker in the modal, so the lead is shown read-only
            // and carried through to the save.
            this.selectedEnquiryPath = 'NoEnquiry';
            this.selectedLeadId = visit.leadId;
            this.scheduledLeadName = visit.leadName || visit.clientName || '';
            this.selectedTagVisitOption = 'Account';
            if (visit.accountId) {
                this.selectedAccountId = visit.accountId;
                this.associatedAccountId = visit.accountId;
                this.associatedAccountName = visit.accountName || '';
                this.accSearchKey = visit.accountName || '';
                this.checkAccountAddressBook();
            }
        } else if (resolvedCustType === 'Opportunity') {
            this.selectedEnquiryPath = 'Opps';
            this.selectedOpportunityId = visit.opportunityId;
            // Bound to the search input — without it the field renders empty and
            // looks like nothing was selected.
            this.oppSearchKey = visit.opportunityName || visit.clientName || '';
            this.selectedTagVisitOption = 'Account';
            if (visit.accountId) {
                this.selectedAccountId = visit.accountId;
                this.associatedAccountId = visit.accountId;
                this.associatedAccountName = visit.accountName || '';
                this.checkAccountAddressBook();
            }
        } else if (resolvedCustType === 'Account') {
            this.selectedEnquiryPath = 'NoEnquiry';
            this.selectedAccountId = visit.accountId;
            this.associatedAccountId = visit.accountId;
            this.associatedAccountName = visit.accountName || visit.clientName || '';
            this.accSearchKey = visit.accountName || visit.clientName || '';
            this.selectedTagVisitOption = 'Account';
            this.checkAccountAddressBook();
        }

        this.reasonForVisitValue = visit.reasonForVisit || visit.nextAction || '';
        if (visit.visitType) {
            this.visitTypeValue = visit.visitType;
        }

        this.initGeolocationAndClients();
        this.loadReasonForVisitPicklist();

        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    // ── Reschedule & Cancel handlers ──
    @track selectedReasonOption = '';
    @track customReasonText = '';

    get scheduleReasonOptions() {
        if (this.scheduleActionType === 'Reschedule') {
            return [
                { label: 'Client requested to reschedule', value: 'Client requested to reschedule' },
                { label: 'Time conflict / running late', value: 'Time conflict / running late' },
                { label: 'Weather / Travel issues', value: 'Weather / Travel issues' },
                { label: 'Other', value: 'Other' }
            ];
        }
        return [
            { label: 'Client cancelled the meeting', value: 'Client cancelled the meeting' },
            { label: 'Meeting no longer required', value: 'Meeting no longer required' },
            { label: 'Client not reachable', value: 'Client not reachable' },
            { label: 'Duplicate schedule', value: 'Duplicate schedule' },
            { label: 'Other', value: 'Other' }
        ];
    }

    get isOtherReasonSelected() {
        return this.selectedReasonOption === 'Other';
    }

    get isRescheduleType() {
        return this.scheduleActionType === 'Reschedule';
    }

    handleRescheduleClick(event) {
        const visitId = event.currentTarget.dataset.id;
        this.selectedScheduledVisitId = visitId;
        this.scheduleActionType = 'Reschedule';
        this.selectedReasonOption = '';
        this.customReasonText = '';
        this.scheduleActionDate = '';
        // this.scheduleActionTime = '';
        this.showScheduleActionModal = true;
        this.scrollToScheduleActionModal();
    }

    handleCancelClick(event) {
        const visitId = event.currentTarget.dataset.id;
        this.selectedScheduledVisitId = visitId;
        this.scheduleActionType = 'Cancel';
        this.selectedReasonOption = '';
        this.customReasonText = '';
        this.scheduleActionDate = '';
        // this.scheduleActionTime = '';
        this.showScheduleActionModal = true;
        this.scrollToScheduleActionModal();
    }

    scrollToScheduleActionModal() {
        // Salesforce Mobile often leaves the page scrolled on the visit list,
        // so the modal opens off-screen and the tap looks like a no-op.
        window.scrollTo({ top: 0, behavior: 'smooth' });
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        window.setTimeout(() => {
            const modal = this.template.querySelector('.pt-schedule-action-modal');
            if (modal) {
                modal.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        }, 50);
    }

    closeScheduleActionModal() {
        this.showScheduleActionModal = false;
        this.selectedScheduledVisitId = '';
    }

    handleReasonOptionChange(event) {
        this.selectedReasonOption = event.detail.value;
    }

    handleCustomReasonChange(event) {
        this.customReasonText = event.detail.value;
    }

    get minScheduleDate() {
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        return tomorrow.toISOString().split('T')[0];
    }

    handleScheduleActionDateChange(event) {
        this.scheduleActionDate = event.detail.value;

        const dateInput = event.target;
        dateInput.setCustomValidity(
            this.scheduleActionDate < this.minScheduleDate
                ? 'Please select a date from tomorrow onwards.'
                : ''
        );
        dateInput.reportValidity();
        this.scheduleActionDate = event.detail.value;
    }

    /* handleScheduleActionTimeChange(event) {
        this.scheduleActionTime = event.detail.value;
    } */

    handleScheduleActionSubmit() {
        let finalReason = this.selectedReasonOption;
        if (finalReason === 'Other') {
            finalReason = this.customReasonText;
        }

        if (!finalReason) {
            this.showToast('Validation Error', 'Please select or enter a reason.', 'error');
            return;
        }

        this.savingScheduleAction = true;
        
        if (this.scheduleActionType === 'Reschedule') {
            if (!this.scheduleActionDate) {
                this.showToast('Validation Error', 'Please select a valid next schedule date.', 'error');
                this.savingScheduleAction = false;
                return;
            }

            if (this.scheduleActionDate < this.minScheduleDate) {
                this.showToast('Validation Error', 'Next schedule date must be from tomorrow onwards.', 'error');
                this.savingScheduleAction = false;
                return;
            }

            if (!this.scheduleActionDate) {
                this.showToast('Validation Error', 'Please select a next schedule date.', 'error');
                this.savingScheduleAction = false;
                return;
            }

            rescheduleScheduledVisit({
                visitId: this.selectedScheduledVisitId,
                reason: finalReason,
                nextDate: this.scheduleActionDate
                // nextTime: this.scheduleActionTime
            })
            .then(() => {
                this.showToast('Success', 'Visit rescheduled successfully.', 'success');
                this.closeScheduleActionModal();
                return refreshApex(this.wiredScheduledResult);
            })
            .catch(error => {
                console.error('Error rescheduling visit', error);
                this.showToast('Error', error.body?.message || 'Failed to reschedule visit.', 'error');
            })
            .finally(() => {
                this.savingScheduleAction = false;
            });

        } else if (this.scheduleActionType === 'Cancel') {
            cancelScheduledVisit({
                visitId: this.selectedScheduledVisitId,
                reason: finalReason,
                nextDate: this.scheduleActionDate ? this.scheduleActionDate : null
                // nextTime: this.scheduleActionTime
            })
            .then(() => {
                this.showToast('Success', 'Visit cancelled successfully.', 'success');
                this.closeScheduleActionModal();
                return refreshApex(this.wiredScheduledResult);
            })
            .catch(error => {
                console.error('Error cancelling visit', error);
                this.showToast('Error', error.body?.message || 'Failed to cancel visit.', 'error');
            })
            .finally(() => {
                this.savingScheduleAction = false;
            });
        }
    }

    @wire(getEmployeeTimeline, { employeeId: '$recordId', limitSize: '$limitSize' })
    wiredTimeline(result) {
        this.wiredResult = result;
        if (!this._timelineFreshLoaded && (result.data || result.error)) {
            // First emission may be a stale device-cached copy
            this._timelineFreshLoaded = true;
            refreshApex(result);
        }
        const { data, error } = result;
        this.isLoading = false;

        console.log('Employee Activity Data : ', JSON.stringify(data));

        if (data) {
            const oldItemsMap = new Map();
            if (this.items && this.items.length > 0) {
                this.items.forEach(item => {
                    if (item.id) {
                        oldItemsMap.set(item.id, item.isCollapsed);
                    }
                });
            }
            this.items = data.map(item => {
                const itemId = item.id;
                // Preserve collapsed status if it existed, otherwise default:
                // Checked-out items should start collapsed (true), active check-ins expanded (false)
                const defaultCollapsed = item.isCheckout === true;
                const isCollapsed = oldItemsMap.has(itemId) ? oldItemsMap.get(itemId) : defaultCollapsed;
                return {
                    ...item,
                    isCollapsed: isCollapsed
                };
            });
        } else if (error) {
            console.error('Timeline load error', error);
            this.items = [];
            this.showToast('Error', 'Failed to load timeline', 'error');
        }
    }

    get hasItems() {
        return this.items && this.items.length > 0;
    }

    get formattedItems() {
        if (!this.items) {
            return [];
        }

        const nodeDistanceById = this.buildNodeDistanceMap(this.items);

        return this.items.map((i, idx) => {
            const checkInRaw = i.loggedAt || i.createdTime;
            let time = '';
            if (checkInRaw) {
                try {
                    const d = new Date(checkInRaw);
                    time = d.toLocaleString('en-IN', {
                        dateStyle: 'short',
                        timeStyle: 'short'
                    });
                } catch (e) {
                    time = checkInRaw;
                }
            }

            let checkoutTime = '';
            if (i.loggedOutAt) {
                try {
                    const d = new Date(i.loggedOutAt);
                    checkoutTime = d.toLocaleString('en-IN', {
                        dateStyle: 'short',
                        timeStyle: 'short'
                    });
                } catch (e) {
                    checkoutTime = i.loggedOutAt;
                }
            }

            const checkInShort = this.formatTimeShort(checkInRaw);
            const checkOutShort = i.loggedOutAt
                ? this.formatTimeShort(i.loggedOutAt)
                : (i.isCheckout ? '' : 'Active');
            const visitDuration = this.formatVisitDuration(checkInRaw, i.loggedOutAt, i.isCheckout);

            let files = [];
            if (i.files) {
                files = i.files.map(file => {
                    const isImg = file.isImage === 'true' || file.isImage === true;
                    return {
                        ...file,
                        isImage: isImg
                    };
                });
            }

            const isCollapsed = i.isCollapsed !== false;
            const itemId = i.id || idx;

            return {
                id: itemId,
                description: i.description,
                time,
                checkoutTime,
                checkInShort,
                checkOutShort,
                visitDuration,
                nodeDistance: i.nodeDistance || nodeDistanceById[itemId] || '',
                user: i.createdByName,
                isCheckout: i.isCheckout,
                clientName: i.clientName || 'Unknown Customer',
                visitType: i.visitType,
                customerType: i.customerType,
                customerCategory: i.customerCategory,
                mom: i.mom,
                visitOutcome: i.visitOutcome,
                nextAction: i.nextAction,
                followUpDate: i.followUpDate,
                justification: i.justification,
                is100mOutside: i.is100mOutside,
                latitude: i.latitude,
                longitude: i.longitude,
                files,
                isCollapsed: isCollapsed,
                toggleIcon: isCollapsed ? 'utility:chevrondown' : 'utility:chevronup'
            };
        });
    }

    formatTimeShort(value) {
        if (!value) return '';
        try {
            const d = new Date(value);
            if (isNaN(d.getTime())) return String(value);
            return d.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true });
        } catch (e) {
            return String(value);
        }
    }

    formatVisitDuration(startValue, endValue, isCheckout) {
        if (!startValue) {
            return '';
        }
        if (!endValue) {
            return isCheckout ? '' : 'In Progress';
        }
        const start = new Date(startValue);
        const end = new Date(endValue);
        if (isNaN(start.getTime()) || isNaN(end.getTime())) {
            return '';
        }
        let durationMin = Math.floor((end.getTime() - start.getTime()) / 60000);
        if (durationMin < 0) durationMin = 0;
        if (durationMin < 60) {
            return durationMin + ' mins';
        }
        const hours = Math.floor(durationMin / 60);
        const mins = durationMin % 60;
        return hours + ' hr ' + mins + ' mins';
    }

    buildNodeDistanceMap(items) {
        const distById = {};
        const chronological = [...items].sort((a, b) => {
            const ta = new Date(a.loggedAt || a.createdTime || 0).getTime();
            const tb = new Date(b.loggedAt || b.createdTime || 0).getTime();
            return ta - tb;
        });
        let lastLat = null;
        let lastLng = null;
        let isFirst = true;
        chronological.forEach((item, idx) => {
            const id = item.id || idx;
            const lat = item.latitude != null ? Number(item.latitude) : null;
            const lng = item.longitude != null ? Number(item.longitude) : null;
            if (isFirst) {
                distById[id] = 'Start';
                isFirst = false;
            } else if (lat != null && lng != null && lastLat != null && lastLng != null && !isNaN(lat) && !isNaN(lng)) {
                distById[id] = this.calculateDistanceKm(lastLat, lastLng, lat, lng).toFixed(1) + ' KM';
            } else {
                distById[id] = '0 KM';
            }
            if (lat != null && lng != null && !isNaN(lat) && !isNaN(lng)) {
                lastLat = lat;
                lastLng = lng;
            }
        });
        return distById;
    }

    calculateDistanceKm(lat1, lon1, lat2, lon2) {
        if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
            return 0;
        }
        const radius = 6371.0;
        const dLat = (lat2 - lat1) * Math.PI / 180.0;
        const dLon = (lon2 - lon1) * Math.PI / 180.0;
        const rLat1 = lat1 * Math.PI / 180.0;
        const rLat2 = lat2 * Math.PI / 180.0;
        const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(rLat1) * Math.cos(rLat2) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return radius * c;
    }

    toggleItem(event) {
        const itemId = event.currentTarget.dataset.id;
        this.items = this.items.map(item => {
            if (item.id == itemId) {
                return {
                    ...item,
                    isCollapsed: !item.isCollapsed
                };
            }
            return item;
        });
    }

    openModal() {
        if (!this.isMarketVisitActive) {
            this.showToast('Action Blocked', 'Client visits can only be added while Market Visit mode is active.', 'error');
            return;
        }
        const hasOpenTask = this.items?.some(item => item.isCheckout === false);
        if (hasOpenTask) {
            this.showToast('Error', 'You cannot add a new task without checking out the current task.', 'error');
            return;
        }
        
        this.showModal = true;
        this.resetCheckInSelections();
        if (this.approvedRequestsWired) {
            refreshApex(this.approvedRequestsWired);
        }
        this.initGeolocationAndClients();
        this.loadReasonForVisitPicklist();
        
        // Auto scroll to top to show modal instantly
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    loadReasonForVisitPicklist() {
        getReasonForVisitOptions()
            .then(result => {
                this._reasonForVisitOptions = result.map(item => ({ label: item, value: item }));
            })
            .catch(error => {
                console.error('Error fetching Reason For Visit picklist:', error);
            });
    }

    loadCustomerCategoryPicklist() {
        getCustomerCategoryOptions()
            .then(result => {
                this.customerCategoryOptions = result.map(item => ({ label: item, value: item }));
                this.ensureCustomerCategoryOption(this.customerCategory);
            })
            .catch(error => {
                console.error('Error fetching Customer Category picklist:', error);
            });
    }

    get reasonForVisitOptions() {
        const options = (this._reasonForVisitOptions && this._reasonForVisitOptions.length > 0)
            ? [...this._reasonForVisitOptions]
            : [...this.defaultReasonForVisitOptions];
        // A combobox silently renders blank when its value is absent from the
        // options, which would hide a purpose prefilled from a scheduled visit.
        if (this.reasonForVisitValue && !options.some(o => o.value === this.reasonForVisitValue)) {
            options.unshift({ label: this.reasonForVisitValue, value: this.reasonForVisitValue });
        }
        return options;
    }

    get defaultReasonForVisitOptions() {
        return [
            { label: 'Order booking', value: 'Order booking' },
            { label: 'Upcoming project Discussion', value: 'Upcoming project Discussion' },
            { label: 'Payment collection', value: 'Payment collection' },
            { label: 'Negotiation meeting', value: 'Negotiation meeting' },
            { label: 'Introduction meeting', value: 'Introduction meeting' },
            { label: 'Complaint Management', value: 'Complaint Management' },
            { label: 'Site Visit', value: 'Site Visit' },
            { label: 'Brand Approval', value: 'Brand Approval' },
            { label: 'Existing project discussion', value: 'Existing project discussion' },
            { label: 'Other', value: 'Other' }
        ];
    }

    loadPOCPicklist() {
        // Fallback or describe values
        this.pocOptions = [
            { label: 'Yes', value: 'Yes' },
            { label: 'No', value: 'No' }
        ];
    }

    loadVisitOutcomePicklist() {
        getVisitOutcomePicVal()
            .then(result => {
                this.serverVisitOutcomeOptions = result.map(item => ({ label: item, value: item }));
            })
            .catch(() => {
                this.serverVisitOutcomeOptions = [
                    { label: 'Only information', value: 'Only information' },
                    { label: 'Enquiry generation', value: 'Enquiry generation' },
                    { label: 'Order finalization', value: 'Order finalization' }
                ];
            });
    }

    get visitOutcomeOptions() {
        return this.serverVisitOutcomeOptions && this.serverVisitOutcomeOptions.length > 0
            ? this.serverVisitOutcomeOptions
            : [
                { label: 'Only information', value: 'Only information' },
                { label: 'Enquiry generation', value: 'Enquiry generation' },
                { label: 'Order finalization', value: 'Order finalization' }
            ];
    }

    get nextActionOptions() {
        const type = this.normalizedCustomerType;
        if (type === 'Opportunity') {
            return [
                { label: 'Quotation Required', value: 'Quotation Required' },
                { label: 'Drawing Credential Approved', value: 'Drawing Credential Approved' },
                { label: 'Plant Visit', value: 'Plant Visit' },
                { label: 'Virtual Meeting', value: 'Virtual Meeting' },
                { label: 'Follow up visit', value: 'Follow up visit' },
                { label: 'Rate Discussion', value: 'Rate Discussion' }
            ];
        }
        if (type === 'Lead') {
            return [
                { label: 'Future Prospect', value: 'Future Prospect' },
                { label: 'Enquiry Received', value: 'Enquiry Received' },
                { label: 'Follow visit', value: 'Follow visit' },
                { label: 'Follow up call', value: 'Follow up call' }
            ];
        }
        return [];
    }

    get hasNextActionOptions() {
        return this.nextActionOptions && this.nextActionOptions.length > 0;
    }

    get followUpDateMin() {
        const today = new Date();
        const year = today.getFullYear();
        const month = String(today.getMonth() + 1).padStart(2, '0');
        const day = String(today.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    handleFollowUpDateChange(event) {
        this.followUpDate = event.target.value;
        if (this.followUpDate && this.followUpDate < this.followUpDateMin) {
            this.followUpDate = '';
            this.showToast('Error', 'Next Follow Up Date cannot be a past date.', 'error');
        }
    }
    handleMOMChange(event) { this.momValue = event.target.value; }
    handleVisitOutcomeChange(event) { this.visitOutcomeValue = event.detail.value; }
    handleNextActionChange(event) { this.nextActionValue = event.detail.value; }

    initModalState() {
        this.resetCheckInSelections();
        this.selectedEnquiryPath = 'Opps';
        this.currentLatitude = null;
        this.currentLongitude = null;
    }

    closeModal() {
        this.showModal = false;
        this.reasonForVisitValue = '';
        this.visitTypeValue = 'Follow up';
        this.stopStreams();
        this.saving = false;
        this.selfiePreview = '';
        this.isSelfieCameraOpen = false;
        this.initModalState();
    }

    initGeolocationAndClients() {
        if (!navigator.geolocation) {
            this.showToast('Error', 'Geolocation is not supported by this browser.', 'error');
            return;
        }

        navigator.geolocation.getCurrentPosition(
            (pos) => {
                this.currentLatitude = pos.coords.latitude;
                this.currentLongitude = pos.coords.longitude;
                this.loadDataForCheckIn();
            },
            (err) => {
                console.error('Check-in geolocation error', err);
                this.showToast('Error', 'Unable to get your location: ' + err.message, 'error');
            },
            { enableHighAccuracy: true, timeout: 10000 }
        );
    }

    loadDataForCheckIn() {
        getOwnedLeads()
            .then(result => {
                this.leadOptions = result.map(l => ({ label: `${l.Name} (${l.Company || ''})`, value: l.Id }));
            })
            .catch(err => console.error('Error loading owned leads', err));

        getOwnedOpportunities()
            .then(result => {
                this.opportunitiesList = result;
                this.opportunityOptions = result.map(o => ({ label: `${o.Name} - ${o.Account ? o.Account.Name : ''}`, value: o.Id }));
            })
            .catch(err => console.error('Error loading owned opportunities', err));

        getAllAccounts()
            .then(result => {
                this.accountOptions = result.map(a => ({ label: a.name, value: a.id }));
            })
            .catch(err => console.error('Error loading all accounts', err));

        if (this.currentLatitude && this.currentLongitude) {
            getNearbyAccounts({ latitude: this.currentLatitude, longitude: this.currentLongitude })
                .then(result => {
                    this.nearbyAccountOptions = result.map(a => ({ label: `${a.name} (${Number(a.distanceKm).toFixed(2)} km)`, value: a.id }));
                })
                .catch(err => console.error('Error loading nearby accounts', err));
        }
    }

    async addEntry() {
        if (!this.reasonForVisitValue) {
            this.showToast('Error', 'Reason for Visit is required', 'error');
            return;
        }
        if (this.visitCategoryValue === 'WFH' || this.visitCategoryValue === 'WFO') {
            if (!this.selectedApprovedRequestId) {
                this.showToast('Error', `Please select the corresponding approved ${this.visitCategoryValue} request.`, 'error');
                return;
            }
        }
        if (!this.selfiePreview) {
            this.showToast('Error', 'Please capture a selfie to proceed.', 'error');
            return;
        }

        this.saving = true;

        try {
            let finalLeadId = null;
            let finalAccountId = null;
            let finalOpportunityId = null;
            let finalClientId = null;

            if (this.isOppsPath) {
                if (!this.selectedOpportunityId) {
                    throw new Error('Please select an Opportunity');
                }
                finalOpportunityId = this.selectedOpportunityId;

                if (this.selectedTagVisitOption === 'Account') {
                    finalAccountId = this.associatedAccountId;
                    finalClientId = this.selectedAddressBookId;
                } else if (this.selectedTagVisitOption === 'Site') {
                    if (this.showNewSiteInput) {
                        if (!this.newSiteName) {
                            throw new Error('New Site Name is required');
                        }
                        const newSiteId = await createAccountOrSite({
                            name: this.newSiteName,
                            parentId: this.associatedAccountId,
                            lat: this.currentLatitude,
                            lng: this.currentLongitude,
                            phone: null,
                            email: null
                        });
                        finalAccountId = newSiteId;
                    } else {
                        finalAccountId = this.selectedSiteId;
                    }
                }
            } else if (this.isNoEnquiryPath) {
                if (this.createNewAccount) {
                    if (!this.newAccountName) {
                        throw new Error('Account Name is required');
                    }
                    if (this.newAccountPhone && !/^[0-9]{10}$/.test(this.newAccountPhone)) {
                        throw new Error('Account Phone number must be exactly 10 digits.');
                    }
                    const newAccId = await createAccountOrSite({
                        name: this.newAccountName,
                        parentId: null,
                        lat: this.currentLatitude,
                        lng: this.currentLongitude,
                        phone: this.newAccountPhone || null,
                        email: this.newAccountEmail || null
                    });
                    finalAccountId = newAccId;
                } else {
                    // A scheduled lead visit has no account yet, so the lead alone
                    // is enough to identify who is being visited.
                    if (!this.associatedAccountId && !this.hasScheduledLead) {
                        throw new Error('Please select an Account');
                    }
                    if (this.selectedTagVisitOption === 'Site' && !this.showNewSiteInput && !this.selectedSiteId) {
                        throw new Error('Please select a Site');
                    }
                    if (this.selectedTagVisitOption === 'Account') {
                        finalAccountId = this.associatedAccountId;
                        finalClientId = this.selectedAddressBookId;
                    } else if (this.selectedTagVisitOption === 'Site') {
                        if (this.showNewSiteInput) {
                            if (!this.newSiteName) {
                                throw new Error('New Site Name is required');
                            }
                            const newSiteId = await createAccountOrSite({
                                name: this.newSiteName,
                                parentId: this.associatedAccountId,
                                lat: this.currentLatitude,
                                lng: this.currentLongitude,
                                phone: null,
                                email: null
                            });
                            finalAccountId = newSiteId;
                        } else {
                            finalAccountId = this.selectedSiteId;
                        }
                    }
                }
            }

            // Preserve lead from scheduled visit even when using Account/Opp path
            if (!finalLeadId && this.selectedLeadId) {
                finalLeadId = this.selectedLeadId;
            }

            const scheduledVisitId = this.selectedScheduledVisitId || null;

            await addEmployeeTimelineItemWithCategory({
                employeeId: this.recordId,
                description: this.reasonForVisitValue,
                clientId: finalClientId,
                latitude: this.currentLatitude,
                longitude: this.currentLongitude,
                visitType: this.visitTypeValue,
                customerType: this.selectedEnquiryPath,
                reasonforVisit: this.reasonForVisitValue,
                leadFirstName: '',
                leadLastName: '',
                leadEmail: '',
                leadCompanyName: '',
                leadPhone: '',
                isManual: false,
                selfieImageBase64: this.selfiePreview,
                leadId: finalLeadId,
                accountId: finalAccountId,
                opportunityId: finalOpportunityId,
                scheduledVisitId: scheduledVisitId,
                visitCategory: this.visitCategoryValue,
                approvedRequestId: this.selectedApprovedRequestId || null,
                mapAddressToAccount: this.isNoEnquiryPath && this.createNewAccount
            });

            this.saving = false;
            this.closeModal();
            if (this.wiredResult) {
                refreshApex(this.wiredResult);
            }
            if (this.wiredScheduledResult) {
                refreshApex(this.wiredScheduledResult);
            }
            this.dispatchEvent(new CustomEvent('checkin'));
            this.showToast('Success', 'Timeline entry added', 'success');
        } catch (error) {
            console.error('Add timeline error', error);
            this.saving = false;
            this.showToast('Error', this.normalizeError(error) || error.message || 'Failed to add timeline entry', 'error');
        }
    }

    normalizeError(error) {
        if (!error) return null;
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        } else if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        return typeof error === 'string' ? error : null;
    }

    checkoutHandler(event) {
        this.checkedOutModal = true;
        this.loadPOCPicklist();
        this.loadVisitOutcomePicklist();
        this.loadCustomerCategoryPicklist();
        
        this.taskId = event.currentTarget.dataset.id;
        this.pocValue = 'No';
        this.newContactFirstName = '';
        this.newContactLastName = '';
        this.newContactEmail = '';
        this.newContactPhone = '';
        this.remainingAccountPhone = '';
        this.remainingAccountEmail = '';
        this.remainingAccountContactName = '';
        this.followUpTypeValue = 'Visit';
        this.postDispositionValue = 'No Action';
        this.lostReasonValue = '';
        this.customerType = '';
        this.customerCategory = '';
        this.customerCategoryLocked = false;
        this.savingCheckedOut = false;
        this.fileData = null;

        const currentItem = this.formattedItems ? this.formattedItems.find(i => i.id == this.taskId) : null;
        if (currentItem) {
            if (currentItem.clientName) {
                this.customerName = currentItem.clientName;
            }
            if (currentItem.customerType) {
                let ct = currentItem.customerType.toLowerCase();
                if (ct.includes('lead')) this.customerType = 'Lead';
                else if (ct.includes('opp')) this.customerType = 'Opportunity';
                else if (ct.includes('account') || ct.includes('noenquiry')) this.customerType = 'Account';
                else this.customerType = currentItem.customerType;
            }
            this.applyExistingCustomerCategory(currentItem.customerCategory);
        }

        // Auto scroll to top to show modal instantly
        window.scrollTo({ top: 0, behavior: 'smooth' });

        if (this.taskId !== '') {
            this.fetchTaskDetails();
        }
    }

    getCurrentLocation() {
        return new Promise((resolve, reject) => {
            if (!navigator.geolocation) {
                reject(new Error('Geolocation is not supported by this browser.'));
                return;
            }

            navigator.geolocation.getCurrentPosition(
                (pos) => {
                    resolve({
                        latitude: pos.coords.latitude,
                        longitude: pos.coords.longitude
                    });
                },
                (err) => reject(err),
                { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
            );
        });
    }

    async fetchTaskDetails() {
        try {
            try {
                const location = await this.getCurrentLocation();
                this.currentLatitude = location.latitude;
                this.currentLongitude = location.longitude;
            } catch (gpsError) {
                console.error('Checkout location lookup failed', gpsError);
            }

            const result = await taskDetails({
                taskId: this.taskId,
                latitude: this.currentLatitude,
                longitude: this.currentLongitude
            });

            if (result && result.length > 0) {
                if (result[0].customerName) {
                    this.customerName = result[0].customerName;
                }
                this.applyExistingCustomerCategory(result[0].customerCategory);
                if (result[0].customerType) {
                    let ct = result[0].customerType.toLowerCase();
                    if (ct.includes('lead')) this.customerType = 'Lead';
                    else if (ct.includes('opp')) this.customerType = 'Opportunity';
                    else if (ct.includes('account') || ct.includes('noenquiry')) this.customerType = 'Account';
                    else this.customerType = result[0].customerType;
                }
                this.is100mOutside = result[0].is100mOutside;
                this.resolvedAccountId = result[0].accountId;
                
                // Fetch associated contacts for selection
                this.loadContactsForActiveAccount();
            }
        } catch (error) {
            console.error(error);
            this.showToast('Error', this.normalizeError(error) || error.message || 'Error fetching task details', 'error');
        }
    }

    captureSelfieCheckin() {
        this.captureSelfie('.up-video-selfie-checkin', 'CHECKIN');
    }

    captureSelfieCheckout() {
        this.captureSelfie('.up-video-selfie', 'CHECKOUT');
    }

    captureSelfie(videoSelector, type) {
        const video = this.template.querySelector(videoSelector);
        const canvas = this.template.querySelector('canvas');
        if (!video || !canvas) return;
        this.selfiePreview = this.processCapture(video, canvas, type);
        this.closeSelfieCamera();
    }

    initCameras(videoSelector) {
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            console.warn('Camera not supported on this device.');
            return;
        }

        this.stopStreams();

        const videoEl = this.template.querySelector(videoSelector);
        if (videoEl) {
            navigator.mediaDevices.getUserMedia({
                video: { facingMode: 'user' },
                audio: false
            })
            .then((stream) => {
                this.selfieStream = stream;
                videoEl.setAttribute('playsinline', 'true');
                videoEl.setAttribute('webkit-playsinline', 'true');
                videoEl.setAttribute('muted', 'true');
                videoEl.playsInline = true;
                videoEl.muted = true;
                videoEl.srcObject = stream;
                videoEl.play().catch(err => console.error('Video play error:', err));
            })
            .catch((err) => {
                console.error('Camera error', err);
            });
        }
    }

    stopStreams() {
        if (this.selfieStream) {
            this.selfieStream.getTracks().forEach((track) => track.stop());
            this.selfieStream = null;
        }
    }

    triggerSelfieCapture() {
        const input = this.template.querySelector('.up-selfie-file-input');
        if (input) {
            input.click();
        }
    }

    handleSelfieFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            const reader = new FileReader();
            reader.onload = () => {
                this.selfiePreview = reader.result;
            };
            reader.readAsDataURL(file);
        }
    }

    openSelfieCameraCheckin() {
        this.isSelfieCameraOpen = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.initCameras('.up-video-selfie-checkin');
        }, 100);
    }

    openSelfieCameraCheckout() {
        this.isSelfieCameraOpen = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.initCameras('.up-video-selfie');
        }, 100);
    }

    closeSelfieCamera() {
        this.stopStreams();
        this.isSelfieCameraOpen = false;
    }

    retakeSelfie() { 
        this.selfiePreview = ''; 
        this.isSelfieCameraOpen = false;
    }

    processCapture(video, canvas, type) {
        canvas.width  = video.videoWidth  || 640;
        canvas.height = video.videoHeight || 480;
        const ctx = canvas.getContext('2d');

        ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

        // Timestamp
        const now = new Date();
        const stamp = `${type} - ${now.toLocaleString('en-IN')}`;

        const bannerH = 32;
        ctx.fillStyle = 'rgba(0, 0, 0, 0.6)';
        ctx.fillRect(0, canvas.height - bannerH, canvas.width, bannerH);

        ctx.fillStyle = '#DAA520';
        ctx.font = 'bold 14px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(stamp, canvas.width / 2, canvas.height - bannerH / 2);

        return canvas.toDataURL('image/jpeg');
    }

    handleFileChange(event) {
        const files = event.detail?.files || event.target?.files;
        const file = files && files[0];
        if (!file) return;

        // Validate extension
        const allowedExtensions = ['pdf', 'xls', 'xlsx', 'doc', 'docx', 'png', 'jpg', 'jpeg'];
        const extension = file.name.split('.').pop().toLowerCase();

        // Validate MIME type (empty type is common on mobile; fall back to extension)
        const allowedMimeTypes = [
            'application/pdf',
            'application/vnd.ms-excel',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'application/msword',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'image/png',
            'image/jpeg',
            'image/jpg'
        ];

        const mimeOk = !file.type || allowedMimeTypes.includes(file.type);
        if (!allowedExtensions.includes(extension) || !mimeOk) {
            this.fileData = null;
            this.showToast('Error', 'PDF/Excel/Word/PNG/JPG/JPEG is accepted', 'error');
            return;
        }

        // Convert to Base64
        const reader = new FileReader();
        reader.onload = () => {
            const result = reader.result || '';
            const base64 = typeof result === 'string' && result.includes(',')
                ? result.split(',')[1]
                : result;
            if (!base64) {
                this.fileData = null;
                this.showToast('Error', 'Could not read the selected file. Please try again.', 'error');
                return;
            }
            this.fileData = {
                fileName: file.name,
                base64: base64
            };
            this.showToast('Success', `${file.name} attached. It will be uploaded on checkout.`, 'success');
        };
        reader.onerror = () => {
            this.fileData = null;
            this.showToast('Error', 'Could not read the selected file. Please try again.', 'error');
        };
        reader.readAsDataURL(file);
    }

    clearCheckoutFile() {
        this.fileData = null;
    }

    async updateTaskHandler() {
        if (!this.momValue) {
            this.showToast('Error', 'MOM is required', 'error');
            return;
        }

        if (this.is100mOutside && !this.justificationValue) {
            this.showToast('Error', 'Justification is mandatory.', 'error');
            return;
        }

        if (this.hasExistingContacts) {
            if (!this.selectedContactId) {
                this.showToast('Error', 'Please select a Contact.', 'error');
                return;
            }
            if (this.selectedContactId === 'new') {
                if (!this.newContactFirstName || !this.newContactLastName || !this.newContactPhone) {
                    this.showToast('Error', 'First Name, Last Name, and Phone are required to create a new Contact.', 'error');
                    return;
                }
                if (!/^[0-9]{10}$/.test(this.newContactPhone)) {
                    this.showToast('Error', 'Phone number must be exactly 10 digits.', 'error');
                    return;
                }
            }
        } else {
            if (!this.newContactFirstName || !this.newContactLastName || !this.newContactPhone) {
                this.showToast('Error', 'First Name, Last Name, and Phone are required to create a Contact.', 'error');
                return;
            }
            if (!/^[0-9]{10}$/.test(this.newContactPhone)) {
                this.showToast('Error', 'Phone number must be exactly 10 digits.', 'error');
                return;
            }
        }


        if (!this.visitOutcomeValue) {
            this.showToast('Error', 'Visit Outcome is required', 'error');
            return;
        }

        if (this.hasNextActionOptions && !this.nextActionValue) {
            this.showToast('Error', 'Next Action is required', 'error');
            return;
        }

        if (this.isLeadLost && !this.lostReasonValue) {
            this.showToast('Error', 'Lost Reason is required.', 'error');
            return;
        }


        if (!this.followUpDate) {
            this.showToast('Error', 'Next Follow Up Date is required.', 'error');
            return;
        }

        if (this.followUpDate < this.followUpDateMin) {
            this.showToast('Error', 'Next Follow Up Date cannot be a past date.', 'error');
            return;
        }

        if (!this.followUpTypeValue) {
            this.showToast('Error', 'Create Follow Up as (Type) is required.', 'error');
            return;
        }

        if (!this.customerCategory) {
            this.showToast('Error', 'Customer Category is required.', 'error');
            return;
        }

        this.savingCheckedOut = true;

        try {
            const location = await this.getCurrentLocation();
            this.currentLatitude = location.latitude;
            this.currentLongitude = location.longitude;

            console.log('latitude :: ' + this.currentLatitude);
            console.log('longitude :: ' + this.currentLongitude);

            const result = await updateTaskWithDisposition({
                taskId: this.taskId,
                visitTypeValue: this.visitTypeValue,
                pocValue: 'Yes',
                visitOutcomeValue: this.visitOutcomeValue,
                nextActionValue: this.nextActionValue,
                followUpDate: this.followUpDate || null,
                momValue: this.momValue,
                selfieImageBase64: this.selfiePreview || null,
                latitude: this.currentLatitude,
                longitude: this.currentLongitude,
                fileName: this.fileData?.fileName || null,
                base64Data: this.fileData?.base64 || null,
                justificationValue: this.justificationValue,
                postDisposition: this.postDispositionValue,
                lostReason: this.lostReasonValue,
                newContactFirstName: this.newContactFirstName,
                newContactLastName: this.newContactLastName,
                newContactEmail: this.newContactEmail,
                newContactPhone: this.newContactPhone,
                remainingAccountPhone: this.remainingAccountPhone,
                remainingAccountEmail: this.remainingAccountEmail,
                remainingAccountContactName: this.remainingAccountContactName,
                selectedContactId: this.selectedContactId,
                followUpType: this.followUpTypeValue,
                customerCategory: this.customerCategory
            });

            // Handle Navigation Disposition Redirection first while component is connected to DOM
            if (result && result.redirectId) {
                if (
                    this.postDispositionValue === 'Convert Lead' ||
                    this.postDispositionValue === 'Edit Opportunity' ||
                    this.postDispositionValue === 'Create Lead' ||
                    this.postDispositionValue === 'Create Opportunity'
                ) {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: result.redirectId,
                            actionName: 'view'
                        }
                    });
                }
            }

            this.closeCheckedOutModal();

            if (this.wiredResult) {
                await refreshApex(this.wiredResult);
            }
            if (this.wiredScheduledResult) {
                await refreshApex(this.wiredScheduledResult);
            }

            this.dispatchEvent(new CustomEvent('checkout'));
            this.showToast('Success', 'Task Checked Out successfully', 'success');
        } catch (error) {
            console.error('updateTaskHandler error:', error);
            this.savingCheckedOut = false;
            this.showToast('Error', this.normalizeError(error) || error.message || 'Error while updating task record', 'error');
        } 
    }

    closeCheckedOutModal() {
        this.checkedOutModal = false;
        this.selfiePreview = '';
        this.isSelfieCameraOpen = false;
        this.visitOutcomeValue = '';
        this.nextActionValue = '';
        this.momValue = '';
        this.followUpDate = null;
        this.pocValue = 'No';
        this.newContactFirstName = '';
        this.newContactLastName = '';
        this.newContactEmail = '';
        this.newContactPhone = '';
        this.remainingAccountPhone = '';
        this.remainingAccountEmail = '';
        this.remainingAccountContactName = '';
        this.customerCategory = '';
        this.customerCategoryLocked = false;
        this.followUpTypeValue = 'Visit';
        this.postDispositionValue = 'No Action';
        this.lostReasonValue = '';
        this.savingCheckedOut = false;
        this.fileData = null;
    }

    openImagePreview(event) {
        this.modalImageUrl = event.currentTarget.dataset.url;
        this.showImageModal = true;
    }

    closeImagePreview() {
        this.showImageModal = false;
        this.modalImageUrl = '';
    }

    stopBubble(event) {
        event.stopPropagation();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}
/**
 * @description Opportunity (dealer) campaign management datatable — search Opportunities and send multi-channel campaigns.
 * @author      Anshita Chanda
 * @date        2026-08-06
 */
import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchDealerOpportunities from '@salesforce/apex/BWM_CampaignFilterCtrl.searchDealerOpportunities';
import getOpportunityStageOptions from '@salesforce/apex/DealerOpportunityManagementController.getOpportunityStageOptions';
import getOpportunityLostReasonOptions from '@salesforce/apex/DealerOpportunityManagementController.getOpportunityLostReasonOptions';
import getOpportunityCustomerCategoryOptions from '@salesforce/apex/BWM_CampaignFilterCtrl.getOpportunityCustomerCategoryOptions';
import getOpportunityCountryOptions from '@salesforce/apex/BWM_CampaignFilterCtrl.getOpportunityCountryOptions';
import getOpportunityStateOptions from '@salesforce/apex/BWM_CampaignFilterCtrl.getOpportunityStateOptions';
import getOpportunityDepartmentOptions from '@salesforce/apex/BWM_CampaignFilterCtrl.getOpportunityDepartmentOptions';
import getEmailTemplates from '@salesforce/apex/DealerOpportunityManagementController.getEmailTemplates';
import getWhatsAppTemplates from '@salesforce/apex/DealerOpportunityManagementController.getWhatsAppTemplates';
import getRcsTemplates from '@salesforce/apex/DealerOpportunityManagementController.getRcsTemplates';
import getSmsTemplates from '@salesforce/apex/DealerOpportunityManagementController.getSmsTemplates';
import sendOpportunityEmails from '@salesforce/apex/DealerOpportunityManagementController.sendOpportunityEmails';
import getBluewaveEmailTemplates from '@salesforce/apex/DealerOpportunityManagementController.getBluewaveEmailTemplates';
import sendOpportunityCampaignEmail from '@salesforce/apex/DealerOpportunityManagementController.sendOpportunityCampaignEmailScheduled';
import getCampaignJourneys from '@salesforce/apex/DealerOpportunityManagementController.getCampaignJourneys';
import sendOpportunityJourney from '@salesforce/apex/DealerOpportunityManagementController.sendOpportunityJourneyScheduled';
import sendOpportunityWhatsApp from '@salesforce/apex/BWM_WaCampCtrlA.sendOpportunityWhatsAppScheduled';
import sendOpportunityRcs from '@salesforce/apex/DealerOpportunityManagementController.sendOpportunityRcsScheduled';
import sendOpportunitySms from '@salesforce/apex/DealerOpportunityManagementController.sendOpportunitySmsScheduled';
import createCampaignWithMembers from '@salesforce/apex/BWM_CustomCampaignMemberCtrl.createCampaignWithMembers';
import { SEND_ACTION, MEMBER_TYPE, trackCampaignMembers } from 'c/campaignSendActions';
import {
    changedFieldCount,
    dateChipLabel,
    filtersMatch,
    listChipLabel,
    optionLabels,
    presetRange
} from 'c/campaignFilterUi';

const COLUMNS = [
    {
        label: 'Opportunity Name',
        fieldName: 'opportunityUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'Name' },
            target: '_blank'
        }
    },
    { label: 'Primary Contact Name', fieldName: 'PrimaryContactName', type: 'text' },
    { label: 'Email Address', fieldName: 'PrimaryContactEmail', type: 'email' },
    { label: 'Phone Number', fieldName: 'PrimaryContactPhone', type: 'phone' },
    { label: 'Stage', fieldName: 'StageName', type: 'text' },
    { label: 'Department', fieldName: 'DepartmentName', type: 'text' },
    { label: 'Lost Reason', fieldName: 'LostReason', type: 'text' },
    { label: 'Dealer Account', fieldName: 'DealerAccountName', type: 'text' },
    { label: 'Created Date', fieldName: 'CreatedDate', type: 'date' },
    { label: 'Close Date', fieldName: 'CloseDate', type: 'date' },
    { label: 'Amount', fieldName: 'Amount', type: 'currency' }
];

export default class DealerOpportunityDatatable extends LightningElement {
    columns = COLUMNS;
    opportunities = [];
    selectedRows = [];
    isLoading = true;

    searchTerm = '';
    dealerAccountFilter = '';
    selectedStages = [];
    stageOptions = [];
    selectedLostReasons = [];
    lostReasonOptions = [];
    selectedCustomerCategories = [];
    customerCategoryOptions = [];
    selectedCountry = '';
    countryOptions = [];
    selectedStates = [];
    stateOptions = [];
    selectedDepartments = [];
    departmentOptions = [];
    fromDate;
    toDate;
    datePreset = '';
    appliedFilters;

    isEmailModalOpen = false;
    isSendingEmail = false;
    selectedTemplateId;
    emailTemplates = [];
    emailTemplateSearch = '';

    isBluewaveEmailModalOpen = false;
    isLoadingBluewaveTemplates = false;
    isSendingBluewaveEmail = false;
    bluewaveTemplates = [];
    bluewaveTemplateSearch = '';
    bluewaveTemplateLoadError = '';
    selectedBluewaveTemplateId;

    isCampaignJourneyModalOpen = false;
    isLoadingCampaignJourneys = false;
    isSendingCampaignJourney = false;
    campaignJourneys = [];
    campaignJourneySearch = '';
    selectedCampaignJourneyName;

    isJourneyModalOpen = false;
    journeyModalStep = 'whatsapp';
    journeyModalMode = 'campaign';
    isLoadingWhatsAppTemplates = false;
    isLoadingRcsTemplates = false;
    isSendingWhatsApp = false;
    selectedWhatsAppTemplateName;
    whatsAppTemplates = [];
    whatsAppTemplateSearch = '';
    selectedRcsTemplateName;
    rcsTemplates = [];
    rcsTemplateSearch = '';
    isLoadingSmsTemplates = false;
    selectedSmsTemplateName;
    smsTemplates = [];
    smsTemplateSearch = '';

    isCampaignNameModalOpen = false;
    collectJourneySchedule = false;
    pendingSendAction = null;

    /**
     * Wire handler that loads Opportunity stage filter options.
     * @param {Object} {data, error} Wire result with data or error.
     * @returns {void} Nothing.
     */
    @wire(getOpportunityStageOptions)
    wiredOpportunityStageOptions({ data, error }) {
        if (data) {
            this.stageOptions = data.map((option) => ({
                label: option.label,
                value: option.value
            }));
        } else if (error) {
            this.showToast('Error', this.extractError(error), 'error');
        }
    }

    /**
     * Wire handler that loads Opportunity lost-reason filter options.
     * @param {Object} {data, error} Wire result with data or error.
     * @returns {void} Nothing.
     */
    @wire(getOpportunityLostReasonOptions)
    wiredOpportunityLostReasonOptions({ data, error }) {
        if (data) {
            this.lostReasonOptions = data.map((option) => ({
                label: option.label,
                value: option.value
            }));
        } else if (error) {
            this.showToast('Error', this.extractError(error), 'error');
        }
    }

    @wire(getOpportunityCustomerCategoryOptions)
    wiredOpportunityCustomerCategoryOptions({ data, error }) {
        if (data) {
            this.customerCategoryOptions = data.map((option) => ({
                label: option.label,
                value: option.value
            }));
        } else if (error) {
            this.showToast('Error', this.extractError(error), 'error');
        }
    }

    @wire(getOpportunityCountryOptions)
    wiredOpportunityCountryOptions({ data, error }) {
        if (data) {
            this.countryOptions = [
                { label: 'All Countries', value: '' },
                ...data.map((option) => ({
                    label: option.label,
                    value: option.value
                }))
            ];
        } else if (error) {
            this.showToast('Error', this.extractError(error), 'error');
        }
    }

    @wire(getOpportunityStateOptions)
    wiredOpportunityStateOptions({ data, error }) {
        if (data) {
            this.stateOptions = data.map((option) => ({
                label: option.label,
                value: option.value
            }));
        } else if (error) {
            this.showToast('Error', this.extractError(error), 'error');
        }
    }

    @wire(getOpportunityDepartmentOptions)
    wiredOpportunityDepartmentOptions({ data, error }) {
        if (data) {
            this.departmentOptions = data.map((option) => ({
                label: option.label,
                value: option.value
            }));
        } else if (error) {
            this.showToast('Error', this.extractError(error), 'error');
        }
    }

    /**
     * Wire handler that loads Salesforce email template options.
     * @param {Object} {data, error} Wire result with data or error.
     * @returns {void} Nothing.
     */
    @wire(getEmailTemplates)
    wiredEmailTemplates({ data, error }) {
        if (data) {
            this.emailTemplates = data.map((template) => ({
                label: template.label,
                value: template.value,
                folderName: template.folderName || ''
            }));
        } else if (error) {
            this.showToast('Error', this.extractError(error), 'error');
        }
    }

    /**
     * Loads the initial opportunities list when the component connects.
     * @returns {void} Nothing.
     */
    connectedCallback() {
        this.loadOpportunities(false);
    }

    /**
     * Searches dealer Opportunities via Apex and maps results for the datatable.
     * @param {boolean} notifyWhenEmpty When true, shows an info toast if no rows match.
     * @returns {Promise<void>} Resolves when search completes.
     */
    async loadOpportunities(notifyWhenEmpty) {
        this.isLoading = true;
        const requestedFilters = this.buildFilterState();

        try {
            const data = await searchDealerOpportunities({
                searchTerm: this.searchTerm,
                dealerAccountFilter: this.dealerAccountFilter,
                stages: this.selectedStages,
                departments: this.selectedDepartments,
                lostReasons: this.selectedLostReasons,
                fromDate: this.fromDate || null,
                toDate: this.toDate || null,
                customerCategories: this.selectedCustomerCategories,
                countryFilter: this.selectedCountry || null,
                states: this.showStateFilter ? this.selectedStates : []
            });

            this.opportunities = (data || []).map((row) => ({
                ...row,
                opportunityUrl: `/lightning/r/Opportunity/${row.Id}/view`,
                DealerAccountName: row.DealerAccountName || '',
                DepartmentName: row.DepartmentName || '',
                LostReason: row.LostReason || '',
                PrimaryContactName: row.PrimaryContactName || '',
                PrimaryContactEmail: row.PrimaryContactEmail || '',
                PrimaryContactPhone: row.PrimaryContactPhone || ''
            }));
            this.appliedFilters = requestedFilters;

            if (notifyWhenEmpty && this.opportunities.length === 0) {
                this.showToast('Search', 'No opportunities match your search criteria.', 'info');
            }
        } catch (error) {
            this.showToast('Search', this.extractError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Updates the free-text search term from the search input.
     * @param {Event} event Input change event.
     * @returns {void} Nothing.
     */
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    /**
     * Updates the dealer account filter from the input.
     * @param {Event} event Input change event.
     * @returns {void} Nothing.
     */
    handleDealerAccountChange(event) {
        this.dealerAccountFilter = event.target.value;
    }

    /**
     * Updates selected stage filter values and clears lost reasons when not applicable.
     * @param {Event} event Dual-listbox or combobox change event.
     * @returns {void} Nothing.
     */
    handleStageSelection(event) {
        this.selectedStages = event.detail.value || [];
        if (!this.showLostReasonFilter) {
            this.selectedLostReasons = [];
        }
    }

    /**
     * Clears selection and searches opportunities with current filters.
     * @returns {void} Nothing.
     */
    handleSearch() {
        this.selectedRows = [];
        this.loadOpportunities(true);
    }

    /**
     * Updates the selected lost-reason filter values.
     * @param {Event} event Multi-select change event.
     * @returns {void} Nothing.
     */
    handleLostReasonSelection(event) {
        this.selectedLostReasons = event.detail.value || [];
    }

    handleCustomerCategorySelection(event) {
        this.selectedCustomerCategories = event.detail.value || [];
    }

    handleCountryChange(event) {
        this.selectedCountry = event.detail.value || '';
        if (!this.showStateFilter) {
            this.selectedStates = [];
        }
    }

    handleStateSelection(event) {
        this.selectedStates = event.detail.value || [];
    }

    /**
     * Updates the department filter from the input.
     * @param {Event} event Input change event.
     * @returns {void} Nothing.
     */
    handleDepartmentSelection(event) {
        this.selectedDepartments = event.detail.value || [];
    }

    /**
     * Updates the created-from date filter.
     * @param {Event} event Date input change event.
     * @returns {void} Nothing.
     */
    handleFromDateChange(event) {
        this.fromDate = event.target.value;
        this.datePreset = 'custom';
    }

    /**
     * Updates the created-to date filter.
     * @param {Event} event Date input change event.
     * @returns {void} Nothing.
     */
    handleToDateChange(event) {
        this.toDate = event.target.value;
        this.datePreset = 'custom';
    }

    handleStagePill(event) {
        const value = event.currentTarget.dataset.value;
        const next = new Set(this.selectedStages || []);
        if (next.has(value)) {
            next.delete(value);
        } else {
            next.add(value);
        }
        this.selectedStages = [...next];
        if (!this.showLostReasonFilter) {
            this.selectedLostReasons = [];
        }
    }

    handleDatePreset(event) {
        const preset = event.currentTarget.dataset.preset;
        this.datePreset = preset;
        if (preset === 'custom') {
            return;
        }
        const range = presetRange(preset);
        this.fromDate = range.fromDate;
        this.toDate = range.toDate;
    }

    handleResetFilters() {
        this.searchTerm = '';
        this.dealerAccountFilter = '';
        this.selectedStages = [];
        this.selectedDepartments = [];
        this.selectedCustomerCategories = [];
        this.selectedCountry = '';
        this.selectedStates = [];
        this.selectedLostReasons = [];
        this.fromDate = null;
        this.toDate = null;
        this.datePreset = '';
        this.handleSearch();
    }

    handleRemoveAppliedChip(event) {
        const key = event.currentTarget.dataset.key;
        if (key === 'search') {
            this.searchTerm = '';
        } else if (key === 'dealer') {
            this.dealerAccountFilter = '';
        } else if (key === 'stages') {
            this.selectedStages = [];
            this.selectedLostReasons = [];
        } else if (key === 'dates') {
            this.fromDate = null;
            this.toDate = null;
            this.datePreset = '';
        } else if (key === 'departments') {
            this.selectedDepartments = [];
        } else if (key === 'categories') {
            this.selectedCustomerCategories = [];
        } else if (key === 'country') {
            this.selectedCountry = '';
            this.selectedStates = [];
        } else if (key === 'states') {
            this.selectedStates = [];
        } else if (key === 'lost') {
            this.selectedLostReasons = [];
        }
        this.handleSearch();
    }

    handleClearSelection() {
        this.selectedRows = [];
    }

    buildFilterState() {
        return {
            searchTerm: this.searchTerm || '',
            dealerAccountFilter: this.dealerAccountFilter || '',
            stages: this.selectedStages || [],
            departments: this.selectedDepartments || [],
            categories: this.selectedCustomerCategories || [],
            country: this.selectedCountry || '',
            states: this.showStateFilter ? this.selectedStates || [] : [],
            lostReasons: this.showLostReasonFilter ? this.selectedLostReasons || [] : [],
            fromDate: this.fromDate || '',
            toDate: this.toDate || ''
        };
    }

    /**
     * Stores the currently selected datatable rows.
     * @param {Event} event Datatable row selection event.
     * @returns {void} Nothing.
     */
    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows;
    }

    /**
     * Opens the Salesforce email template modal for selected opportunities.
     * @returns {void} Nothing.
     */
    handleSendEmail() {
        if (!this.hasSelection) {
            this.showToast('Send Email', 'Select at least one opportunity.', 'warning');
            return;
        }
        this.selectedTemplateId = null;
        this.emailTemplateSearch = '';
        this.isEmailModalOpen = true;
    }

    /**
     * Opens the Bluewave campaign email modal and loads templates for selected opportunities.
     * @returns {Promise<void>} Resolves when templates are loaded.
     */
    async handleSendBluewaveEmail() {
        if (!this.hasSelection) {
            this.showToast('Send Campaign Email', 'Select at least one opportunity.', 'warning');
            return;
        }

        this.isBluewaveEmailModalOpen = true;
        this.isLoadingBluewaveTemplates = true;
        this.isSendingBluewaveEmail = false;
        this.bluewaveTemplates = [];
        this.bluewaveTemplateSearch = '';
        this.bluewaveTemplateLoadError = '';
        this.selectedBluewaveTemplateId = null;

        try {
            const templates = await getBluewaveEmailTemplates();
            this.bluewaveTemplates = (templates || []).map((template) => ({
                label: template.label,
                value: template.value,
                createdAt: template.createdAt || '',
                updatedAt: template.updatedAt || '',
                updatedAtDisplay: this.formatBluewaveDate(template.updatedAt)
            }));
        } catch (error) {
            this.bluewaveTemplateLoadError = this.extractError(error);
            this.showToast('Send Campaign Email', this.bluewaveTemplateLoadError, 'error');
        } finally {
            this.isLoadingBluewaveTemplates = false;
        }
    }

    /**
     * Updates the Bluewave email template search filter.
     * @param {Event} event Input change event.
     * @returns {void} Nothing.
     */
    handleBluewaveTemplateSearch(event) {
        this.bluewaveTemplateSearch = event.target.value;
    }

    /**
     * Selects a Bluewave email template from the modal list.
     * @param {Event} event Click event with template id in dataset.
     * @returns {void} Nothing.
     */
    handleSelectBluewaveTemplate(event) {
        this.selectedBluewaveTemplateId = event.currentTarget.dataset.id;
    }

    /**
     * Closes the Bluewave campaign email modal when not loading or sending.
     * @returns {void} Nothing.
     */
    handleCloseBluewaveEmailModal() {
        if (!this.isLoadingBluewaveTemplates && !this.isSendingBluewaveEmail) {
            this.isBluewaveEmailModalOpen = false;
            this.bluewaveTemplates = [];
            this.bluewaveTemplateSearch = '';
            this.bluewaveTemplateLoadError = '';
            this.selectedBluewaveTemplateId = null;
        }
    }

    /**
     * Sends Bluewave campaign emails to selected opportunities.
     * @returns {Promise<void>} Resolves when send completes.
     */
    async handleConfirmSendBluewaveEmail() {
        if (!this.selectedBluewaveTemplateId) {
            this.showToast('Send Campaign Email', 'Select one email template.', 'warning');
            return;
        }
        this.openCampaignNameModal(SEND_ACTION.BLUEWAVE_EMAIL);
    }

    async executeSendBluewaveEmail(campaignName, scheduledDateTime) {
        const opportunityIds = this.selectedRows.map((row) => row.Id);
        this.isSendingBluewaveEmail = true;

        try {
            const result = await sendOpportunityCampaignEmail({
                opportunityIds,
                infobipTemplateId: this.selectedBluewaveTemplateId,
                scheduledDateTime
            });

            let message = `${result.sentCount} campaign email(s) sent successfully.`;
            if (result.skippedCount > 0) {
                message += ` ${result.skippedCount} could not be sent.`;
                if (result.messages && result.messages.length > 0) {
                    message += ' ' + result.messages.join(' ');
                }
            }

            this.showToast(
                'Send Campaign Email',
                message,
                result.sentCount > 0 ? 'success' : 'warning'
            );

            if (result.sentCount > 0) {
                await this.trackCampaignMembersForSelection(campaignName);
                this.isBluewaveEmailModalOpen = false;
                this.selectedBluewaveTemplateId = null;
            }
        } catch (error) {
            this.showToast('Send Campaign Email', this.extractError(error), 'error');
        } finally {
            this.isSendingBluewaveEmail = false;
        }
    }

    /**
     * Formats a Bluewave template date string for display.
     * @param {string} value ISO or date string from Bluewave.
     * @returns {string} Locale date string, original value, or empty string.
     */
    formatBluewaveDate(value) {
        if (!value) {
            return '';
        }
        const parsed = new Date(value);
        if (Number.isNaN(parsed.getTime())) {
            return value;
        }
        return parsed.toLocaleDateString();
    }

    /**
     * Opens the journey modal and loads Bluewave journeys for selected opportunities.
     * @returns {Promise<void>} Resolves when journeys are loaded.
     */
    async handleSendJourney() {
        if (!this.hasSelection) {
            this.showToast('Send Journey', 'Select at least one opportunity.', 'warning');
            return;
        }

        this.isCampaignJourneyModalOpen = true;
        this.isLoadingCampaignJourneys = true;
        this.campaignJourneys = [];
        this.campaignJourneySearch = '';
        this.selectedCampaignJourneyName = null;

        try {
            const journeys = await getCampaignJourneys();
            this.campaignJourneys = (journeys || []).map((journey) => ({
                label: journey.label,
                value: journey.value
            }));
        } catch (error) {
            this.showToast('Send Journey', this.extractError(error), 'error');
            this.isCampaignJourneyModalOpen = false;
        } finally {
            this.isLoadingCampaignJourneys = false;
        }
    }

    /**
     * Updates the campaign journey search filter.
     * @param {Event} event Input change event.
     * @returns {void} Nothing.
     */
    handleCampaignJourneySearch(event) {
        this.campaignJourneySearch = event.target.value;
    }

    /**
     * Selects a campaign journey from the modal list.
     * @param {Event} event Click event with journey name in dataset.
     * @returns {void} Nothing.
     */
    handleSelectCampaignJourney(event) {
        this.selectedCampaignJourneyName = event.currentTarget.dataset.name;
    }

    /**
     * Closes the campaign journey modal when not currently sending.
     * @returns {void} Nothing.
     */
    handleCloseCampaignJourneyModal() {
        if (!this.isSendingCampaignJourney) {
            this.isCampaignJourneyModalOpen = false;
            this.campaignJourneys = [];
            this.campaignJourneySearch = '';
            this.selectedCampaignJourneyName = null;
        }
    }

    /**
     * Queues Bluewave journey messages for selected opportunities.
     * @returns {Promise<void>} Resolves when journey send completes.
     */
    async handleConfirmSendCampaignJourney() {
        if (!this.selectedCampaignJourneyName) {
            this.showToast('Send Journey', 'Select one journey.', 'warning');
            return;
        }
        this.openCampaignNameModal(SEND_ACTION.JOURNEY);
    }

    async executeSendCampaignJourney(campaignName, scheduledDateTime) {
        const opportunityIds = this.selectedRows.map((row) => row.Id);
        this.isSendingCampaignJourney = true;

        try {
            const result = await sendOpportunityJourney({
                opportunityIds,
                journeyName: this.selectedCampaignJourneyName,
                scheduledDateTime
            });

            let message = `${result.sentCount} journey message(s) queued in Bluewave.`;
            if (result.sentCount > 0) {
                message += ' Check Message Log for delivery status.';
            }
            if (result.skippedCount > 0) {
                message += ` ${result.skippedCount} could not be sent.`;
                if (result.messages && result.messages.length > 0) {
                    message += ' ' + result.messages.join(' ');
                }
            }

            this.showToast(
                'Send Journey',
                message,
                result.sentCount > 0 ? 'success' : 'warning'
            );

            if (result.sentCount > 0) {
                await this.trackCampaignMembersForSelection(campaignName);
                this.isCampaignJourneyModalOpen = false;
                this.selectedCampaignJourneyName = null;
            }
        } catch (error) {
            this.showToast('Send Journey', this.extractError(error), 'error');
        } finally {
            this.isSendingCampaignJourney = false;
        }
    }

    /**
     * Updates the Salesforce email template search filter.
     * @param {Event} event Input change event.
     * @returns {void} Nothing.
     */
    handleEmailTemplateSearch(event) {
        this.emailTemplateSearch = event.target.value;
    }

    /**
     * Selects a Salesforce email template from the modal list.
     * @param {Event} event Click event with template id in dataset.
     * @returns {void} Nothing.
     */
    handleSelectEmailTemplate(event) {
        this.selectedTemplateId = event.currentTarget.dataset.id;
    }

    /**
     * Closes the Salesforce email template modal when not sending.
     * @returns {void} Nothing.
     */
    handleCloseEmailModal() {
        if (!this.isSendingEmail) {
            this.isEmailModalOpen = false;
            this.selectedTemplateId = null;
            this.emailTemplateSearch = '';
        }
    }

    /**
     * Sends Salesforce emails to selected opportunities, or shows guidance when not supported.
     * @returns {Promise<void>} Resolves when send completes or toast is shown.
     */
    async handleConfirmSendEmail() {
        if (!this.selectedTemplateId) {
            this.showToast('Send Email', 'Select one email template.', 'warning');
            return;
        }

        const opportunityIds = this.selectedRows.map((row) => row.Id);
        this.isSendingEmail = true;

        try {
            const result = await sendOpportunityEmails({
                opportunityIds,
                templateId: this.selectedTemplateId
            });

            let message = `${result.sentCount} email(s) sent successfully.`;
            if (result.skippedCount > 0) {
                message += ` ${result.skippedCount} could not be sent.`;
                if (result.messages && result.messages.length > 0) {
                    message += ' ' + result.messages.join(' ');
                }
            }

            this.showToast(
                'Send Email',
                message,
                result.sentCount > 0 ? 'success' : 'warning'
            );

            if (result.sentCount > 0) {
                this.isEmailModalOpen = false;
                this.selectedTemplateId = null;
            }
        } catch (error) {
            this.showToast('Send Email', this.extractError(error), 'error');
        } finally {
            this.isSendingEmail = false;
        }
    }

    /**
     * Opens the WhatsApp campaign modal and loads WhatsApp templates for selected opportunities.
     * @returns {Promise<void>} Resolves when WhatsApp templates are loaded.
     */
    async handleSendCustomerJourney() {
        if (!this.hasSelection) {
            this.showToast('Send WhatsApp Campaign', 'Select at least one opportunity.', 'warning');
            return;
        }

        this.journeyModalMode = 'campaign';
        this.journeyModalStep = 'whatsapp';
        this.selectedWhatsAppTemplateName = null;
        this.selectedRcsTemplateName = null;
        this.selectedSmsTemplateName = null;
        this.whatsAppTemplates = [];
        this.rcsTemplates = [];
        this.smsTemplates = [];
        this.whatsAppTemplateSearch = '';
        this.rcsTemplateSearch = '';
        this.smsTemplateSearch = '';
        this.isJourneyModalOpen = true;
        this.isLoadingWhatsAppTemplates = true;

        try {
            const templates = await getWhatsAppTemplates();
            this.whatsAppTemplates = templates.map((template) => ({
                label: template.label,
                value: template.value,
                categoryName: template.categoryName || '',
                language: template.language || '',
                badgeClass: this.getCategoryBadgeClass(template.categoryName)
            }));
        } catch (error) {
            this.showToast('Send WhatsApp Campaign', this.extractError(error), 'error');
            this.isJourneyModalOpen = false;
        } finally {
            this.isLoadingWhatsAppTemplates = false;
        }
    }

    async handleSendRcs() {
        if (!this.hasSelection) {
            this.showToast('Send RCS', 'Select at least one opportunity.', 'warning');
            return;
        }

        this.journeyModalMode = 'rcs';
        this.journeyModalStep = 'rcs';
        this.selectedRcsTemplateName = null;
        this.rcsTemplateSearch = '';
        this.rcsTemplates = [];
        this.isJourneyModalOpen = true;
        this.isLoadingRcsTemplates = true;

        try {
            const templates = await getRcsTemplates();
            this.rcsTemplates = templates.map((template) => ({
                label: template.label,
                value: template.value,
                status: template.status || ''
            }));
        } catch (error) {
            this.showToast('Send RCS', this.extractError(error), 'error');
            this.isJourneyModalOpen = false;
        } finally {
            this.isLoadingRcsTemplates = false;
        }
    }

    async handleSendSms() {
        if (!this.hasSelection) {
            this.showToast('Send SMS', 'Select at least one opportunity.', 'warning');
            return;
        }

        this.journeyModalMode = 'sms';
        this.journeyModalStep = 'sms';
        this.selectedSmsTemplateName = null;
        this.smsTemplateSearch = '';
        this.smsTemplates = [];
        this.isJourneyModalOpen = true;
        this.isLoadingSmsTemplates = true;

        try {
            const templates = await getSmsTemplates();
            this.smsTemplates = templates.map((template) => ({
                label: template.label,
                value: template.value,
                status: template.status || ''
            }));
        } catch (error) {
            this.showToast('Send SMS', this.extractError(error), 'error');
            this.isJourneyModalOpen = false;
        } finally {
            this.isLoadingSmsTemplates = false;
        }
    }

    /**
     * Advances to the RCS step and loads RCS templates if needed.
     * @returns {Promise<void>} Resolves when templates are loaded or step is ready.
     */
    async handleGoToRcsStep() {
        if (!this.selectedWhatsAppTemplateName) {
            this.showToast('Send WhatsApp Campaign', 'Select one WhatsApp template.', 'warning');
            return;
        }

        this.journeyModalStep = 'rcs';
        this.selectedRcsTemplateName = null;
        this.rcsTemplateSearch = '';

        if (this.rcsTemplates.length > 0) {
            return;
        }

        this.isLoadingRcsTemplates = true;
        try {
            const templates = await getRcsTemplates();
            this.rcsTemplates = templates.map((template) => ({
                label: template.label,
                value: template.value,
                status: template.status || ''
            }));
        } catch (error) {
            this.showToast('Send WhatsApp Campaign', this.extractError(error), 'error');
            this.journeyModalStep = 'whatsapp';
        } finally {
            this.isLoadingRcsTemplates = false;
        }
    }

    /**
     * Advances to the SMS step and loads SMS templates if needed.
     * @returns {Promise<void>} Resolves when templates are loaded or step is ready.
     */
    async handleGoToSmsStep() {
        this.journeyModalStep = 'sms';
        this.selectedSmsTemplateName = null;
        this.smsTemplateSearch = '';

        if (this.smsTemplates.length > 0) {
            return;
        }

        this.isLoadingSmsTemplates = true;
        try {
            const templates = await getSmsTemplates();
            this.smsTemplates = templates.map((template) => ({
                label: template.label,
                value: template.value,
                status: template.status || ''
            }));
        } catch (error) {
            this.showToast('Send WhatsApp Campaign', this.extractError(error), 'error');
            this.journeyModalStep = 'rcs';
        } finally {
            this.isLoadingSmsTemplates = false;
        }
    }

    /**
     * Navigates the WhatsApp campaign modal back to the RCS step.
     * @returns {void} Nothing.
     */
    handleBackToRcsStep() {
        if (!this.isSendingWhatsApp) {
            this.journeyModalStep = 'rcs';
            this.selectedSmsTemplateName = null;
            this.smsTemplateSearch = '';
        }
    }

    /**
     * Navigates the WhatsApp campaign modal back to the WhatsApp step.
     * @returns {void} Nothing.
     */
    handleBackToWhatsAppStep() {
        if (!this.isSendingWhatsApp) {
            this.journeyModalStep = 'whatsapp';
            this.selectedRcsTemplateName = null;
            this.rcsTemplateSearch = '';
        }
    }

    /**
     * Updates the WhatsApp template search filter.
     * @param {Event} event Input change event.
     * @returns {void} Nothing.
     */
    handleWhatsAppTemplateSearch(event) {
        this.whatsAppTemplateSearch = event.target.value;
    }

    /**
     * Selects a WhatsApp template from the modal list.
     * @param {Event} event Click event with template name in dataset.
     * @returns {void} Nothing.
     */
    handleSelectWhatsAppTemplate(event) {
        this.selectedWhatsAppTemplateName = event.currentTarget.dataset.name;
    }

    /**
     * Returns CSS class names for a WhatsApp template category badge.
     * @param {string} categoryName Template category (utility, marketing, etc.).
     * @returns {string} CSS class string for the badge.
     */
    getCategoryBadgeClass(categoryName) {
        const normalized = (categoryName || '').toLowerCase();
        if (normalized === 'utility') {
            return 'template-badge template-badge_utility';
        }
        if (normalized === 'marketing') {
            return 'template-badge template-badge_marketing';
        }
        return 'template-badge';
    }

    /**
     * Updates the RCS template search filter.
     * @param {Event} event Input change event.
     * @returns {void} Nothing.
     */
    handleRcsTemplateSearch(event) {
        this.rcsTemplateSearch = event.target.value;
    }

    /**
     * Selects an RCS template from the modal list.
     * @param {Event} event Click event with template name in dataset.
     * @returns {void} Nothing.
     */
    handleSelectRcsTemplate(event) {
        this.selectedRcsTemplateName = event.currentTarget.dataset.name;
    }

    /**
     * Updates the SMS template search filter.
     * @param {Event} event Input change event.
     * @returns {void} Nothing.
     */
    handleSmsTemplateSearch(event) {
        this.smsTemplateSearch = event.target.value;
    }

    /**
     * Selects an SMS template from the modal list.
     * @param {Event} event Click event with template name in dataset.
     * @returns {void} Nothing.
     */
    handleSelectSmsTemplate(event) {
        this.selectedSmsTemplateName = event.currentTarget.dataset.name;
    }

    /**
     * Closes the WhatsApp/RCS/SMS journey modal when not loading or sending.
     * @returns {void} Nothing.
     */
    handleCloseJourneyModal() {
        if (
            !this.isLoadingWhatsAppTemplates &&
            !this.isLoadingRcsTemplates &&
            !this.isLoadingSmsTemplates &&
            !this.isSendingWhatsApp
        ) {
            this.isJourneyModalOpen = false;
            this.journeyModalMode = 'campaign';
            this.journeyModalStep = 'whatsapp';
            this.selectedWhatsAppTemplateName = null;
            this.selectedRcsTemplateName = null;
            this.selectedSmsTemplateName = null;
            this.whatsAppTemplateSearch = '';
            this.rcsTemplateSearch = '';
            this.smsTemplateSearch = '';
            this.whatsAppTemplates = [];
            this.rcsTemplates = [];
            this.smsTemplates = [];
        }
    }

    /**
     * Stops click propagation so modal content clicks do not close the overlay.
     * @param {Event} event Click event from the modal body.
     * @returns {void} Nothing.
     */
    stopModalClick(event) {
        event.stopPropagation();
    }

    /**
     * Sends WhatsApp and optional RCS/SMS messages to selected opportunities.
     * @returns {Promise<void>} Resolves when all channel sends complete.
     */
    async handleConfirmSendMessages() {
        if (!this.selectedWhatsAppTemplateName) {
            this.showToast('Send WhatsApp Campaign', 'Select one WhatsApp template.', 'warning');
            return;
        }
        this.openCampaignNameModal(SEND_ACTION.MESSAGES);
    }

    async executeSendMessages(campaignName, scheduledDateTime) {
        const opportunityIds = this.selectedRows.map((row) => row.Id);
        const sendRcs = !!this.selectedRcsTemplateName;
        const sendSms = !!this.selectedSmsTemplateName;
        this.isSendingWhatsApp = true;

        try {
            let whatsAppResult = { sentCount: 0, skippedCount: 0, messages: [] };
            let rcsResult = { sentCount: 0, skippedCount: 0, messages: [] };
            let smsResult = { sentCount: 0, skippedCount: 0, messages: [] };

            try {
                whatsAppResult = await sendOpportunityWhatsApp({
                    opportunityIds,
                    templateName: this.selectedWhatsAppTemplateName,
                    scheduledDateTime
                });
            } catch (whatsAppError) {
                whatsAppResult = {
                    sentCount: 0,
                    skippedCount: opportunityIds.length,
                    messages: [this.extractError(whatsAppError)]
                };
            }

            if (sendRcs) {
                try {
                    rcsResult = await sendOpportunityRcs({
                        opportunityIds,
                        templateName: this.selectedRcsTemplateName,
                        scheduledDateTime
                    });
                } catch (rcsError) {
                    rcsResult = {
                        sentCount: 0,
                        skippedCount: opportunityIds.length,
                        messages: [this.extractError(rcsError)]
                    };
                }
            }

            if (sendSms) {
                try {
                    smsResult = await sendOpportunitySms({
                        opportunityIds,
                        templateName: this.selectedSmsTemplateName,
                        scheduledDateTime
                    });
                } catch (smsError) {
                    smsResult = {
                        sentCount: 0,
                        skippedCount: opportunityIds.length,
                        messages: [this.extractError(smsError)]
                    };
                }
            }

            const totalSent =
                (whatsAppResult.sentCount || 0) +
                (rcsResult.sentCount || 0) +
                (smsResult.sentCount || 0);
            const totalSkipped =
                (whatsAppResult.skippedCount || 0) +
                (rcsResult.skippedCount || 0) +
                (smsResult.skippedCount || 0);
            const detailMessages = []
                .concat(whatsAppResult.messages || [])
                .concat(rcsResult.messages || [])
                .concat(smsResult.messages || []);

            let message = `${whatsAppResult.sentCount || 0} WhatsApp`;
            if (sendRcs) {
                message += `, ${rcsResult.sentCount || 0} RCS`;
            }
            if (sendSms) {
                message += `, ${smsResult.sentCount || 0} SMS`;
            }
            message += ' message(s) queued in Bluewave.';
            if (totalSent > 0) {
                message += ' Check Message Log for delivery status.';
            }
            if (totalSkipped > 0) {
                message += ` ${totalSkipped} could not be sent.`;
                if (detailMessages.length > 0) {
                    message += ' ' + detailMessages.join(' ');
                }
            }

            this.showToast(
                'Send WhatsApp Campaign',
                message,
                totalSent > 0 ? 'success' : 'warning'
            );

            if (totalSent > 0) {
                await this.trackCampaignMembersForSelection(campaignName);
                this.isJourneyModalOpen = false;
                this.journeyModalMode = 'campaign';
                this.journeyModalStep = 'whatsapp';
                this.selectedWhatsAppTemplateName = null;
                this.selectedRcsTemplateName = null;
                this.selectedSmsTemplateName = null;
            }
        } catch (error) {
            this.showToast('Send WhatsApp Campaign', this.extractError(error), 'error');
        } finally {
            this.isSendingWhatsApp = false;
        }
    }

    async handleConfirmSendRcsOnly() {
        if (!this.selectedRcsTemplateName) {
            this.showToast('Send RCS', 'Select one RCS template.', 'warning');
            return;
        }
        this.openCampaignNameModal(SEND_ACTION.RCS_ONLY);
    }

    async executeSendRcsOnly(campaignName, scheduledDateTime) {
        const opportunityIds = this.selectedRows.map((row) => row.Id);
        this.isSendingWhatsApp = true;

        try {
            const rcsResult = await sendOpportunityRcs({
                opportunityIds,
                templateName: this.selectedRcsTemplateName,
                scheduledDateTime
            });

            const sentCount = rcsResult.sentCount || 0;
            const skippedCount = rcsResult.skippedCount || 0;
            const detailMessages = rcsResult.messages || [];
            let message = `${sentCount} RCS message(s) queued in Bluewave.`;
            if (sentCount > 0) {
                message += ' Check Message Log for delivery status.';
            }
            if (skippedCount > 0) {
                message += ` ${skippedCount} could not be sent.`;
                if (detailMessages.length > 0) {
                    message += ' ' + detailMessages.join(' ');
                }
            }

            this.showToast('Send RCS', message, sentCount > 0 ? 'success' : 'warning');

            if (sentCount > 0) {
                await this.trackCampaignMembersForSelection(campaignName);
                this.isJourneyModalOpen = false;
                this.journeyModalMode = 'campaign';
                this.journeyModalStep = 'whatsapp';
                this.selectedRcsTemplateName = null;
                this.rcsTemplateSearch = '';
                this.rcsTemplates = [];
            }
        } catch (error) {
            this.showToast('Send RCS', this.extractError(error), 'error');
        } finally {
            this.isSendingWhatsApp = false;
        }
    }

    async handleConfirmSendSmsOnly() {
        if (!this.selectedSmsTemplateName) {
            this.showToast('Send SMS', 'Select one SMS template.', 'warning');
            return;
        }
        this.openCampaignNameModal(SEND_ACTION.SMS_ONLY);
    }

    async executeSendSmsOnly(campaignName, scheduledDateTime) {
        const opportunityIds = this.selectedRows.map((row) => row.Id);
        this.isSendingWhatsApp = true;

        try {
            const smsResult = await sendOpportunitySms({
                opportunityIds,
                templateName: this.selectedSmsTemplateName,
                scheduledDateTime
            });

            const sentCount = smsResult.sentCount || 0;
            const skippedCount = smsResult.skippedCount || 0;
            const detailMessages = smsResult.messages || [];
            let message = `${sentCount} SMS message(s) queued in Bluewave.`;
            if (sentCount > 0) {
                message += ' Check Message Log for delivery status.';
            }
            if (skippedCount > 0) {
                message += ` ${skippedCount} could not be sent.`;
                if (detailMessages.length > 0) {
                    message += ' ' + detailMessages.join(' ');
                }
            }

            this.showToast('Send SMS', message, sentCount > 0 ? 'success' : 'warning');

            if (sentCount > 0) {
                await this.trackCampaignMembersForSelection(campaignName);
                this.isJourneyModalOpen = false;
                this.journeyModalMode = 'campaign';
                this.journeyModalStep = 'whatsapp';
                this.selectedSmsTemplateName = null;
                this.smsTemplateSearch = '';
                this.smsTemplates = [];
            }
        } catch (error) {
            this.showToast('Send SMS', this.extractError(error), 'error');
        } finally {
            this.isSendingWhatsApp = false;
        }
    }


    openCampaignNameModal(action) {
        this.pendingSendAction = action;
        this.collectJourneySchedule =
            action === 'bluewaveEmail' ||
            action === 'journey' ||
            action === 'messages' ||
            action === 'rcsOnly' ||
            action === 'smsOnly';
        this.isCampaignNameModalOpen = true;
    }

    closeCampaignNameModal() {
        this.isCampaignNameModalOpen = false;
        this.pendingSendAction = null;
        this.collectJourneySchedule = false;
        const modal = this.template.querySelector('c-campaign-name-modal');
        if (modal) {
            modal.reset();
        }
    }

    handleCampaignNameModalCancel() {
        if (!this.isCampaignNameModalSending) {
            this.closeCampaignNameModal();
        }
    }

    async handleCampaignNameModalConfirm(event) {
        const campaignName = event.detail.campaignName;
        const scheduledDateTime = event.detail.scheduledDateTime;
        const action = this.pendingSendAction;

        try {
            switch (action) {
                case SEND_ACTION.BLUEWAVE_EMAIL:
                    await this.executeSendBluewaveEmail(campaignName, scheduledDateTime);
                    break;
                case SEND_ACTION.JOURNEY:
                    await this.executeSendCampaignJourney(campaignName, scheduledDateTime);
                    break;
                case SEND_ACTION.MESSAGES:
                    await this.executeSendMessages(campaignName, scheduledDateTime);
                    break;
                case SEND_ACTION.RCS_ONLY:
                    await this.executeSendRcsOnly(campaignName, scheduledDateTime);
                    break;
                case SEND_ACTION.SMS_ONLY:
                    await this.executeSendSmsOnly(campaignName, scheduledDateTime);
                    break;
                default:
                    break;
            }
        } finally {
            if (!this.isCampaignNameModalSending) {
                this.closeCampaignNameModal();
            }
        }
    }

    async trackCampaignMembersForSelection(campaignName) {
        const recordIds = this.selectedRows.map((row) => row.Id);
        await trackCampaignMembers(
            createCampaignWithMembers,
            campaignName,
            MEMBER_TYPE.OPPORTUNITY,
            recordIds,
            (title, message, variant) => this.showToast(title, message, variant),
            (error) => this.extractError(error)
        );
    }

    /**
     * Dispatches a Lightning toast notification.
     * @param {string} title Toast title.
     * @param {string} message Toast message body.
     * @param {string} variant Toast variant (success, error, warning, info).
     * @returns {void} Nothing.
     */
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    /**
     * Extracts a readable error message from an Apex or Lightning error.
     * @param {Object} error Error object from Apex or wire.
     * @returns {string} Human-readable error message.
     */
    extractError(error) {
        if (error && error.body) {
            if (Array.isArray(error.body)) {
                return error.body.map((item) => item.message).join(', ');
            }
            if (error.body.message) {
                return error.body.message;
            }
        }
        return 'Unknown error';
    }

    get hasSelection() {
        return this.selectedRows.length > 0;
    }

    get isCampaignNameModalSending() {
        return (
            this.isSendingBluewaveEmail ||
            this.isSendingCampaignJourney ||
            this.isSendingWhatsApp
        );
    }

    get showBluewaveEmailModal() {
        return this.isBluewaveEmailModalOpen && !this.isCampaignNameModalOpen;
    }

    get showCampaignJourneyModal() {
        return this.isCampaignJourneyModalOpen && !this.isCampaignNameModalOpen;
    }

    get showJourneyModal() {
        return this.isJourneyModalOpen && !this.isCampaignNameModalOpen;
    }

    get campaignNameSendButtonLabel() {
        switch (this.pendingSendAction) {
            case SEND_ACTION.BLUEWAVE_EMAIL:
                return 'Send Campaign Email';
            case SEND_ACTION.JOURNEY:
                return 'Send Journey';
            case SEND_ACTION.MESSAGES:
                return 'Send';
            case SEND_ACTION.RCS_ONLY:
                return 'Send RCS';
            case SEND_ACTION.SMS_ONLY:
                return 'Send SMS';
            default:
                return 'Send';
        }
    }

    get selectedOpportunityCount() {
        return this.selectedRows.length;
    }

    get isSingleOpportunity() {
        return this.selectedRows.length === 1;
    }

    /**
     * Whether the Salesforce email send button should be disabled.
     * @returns {boolean} True when no template is selected or sending/loading.
     */
    get isSendDisabled() {
        return !this.selectedTemplateId || this.isSendingEmail || this.isLoadingEmailTemplates;
    }

    get isLoadingEmailTemplates() {
        return this.isEmailModalOpen && this.emailTemplates.length === 0;
    }

    /**
     * Returns email templates filtered by search term with selection card classes.
     * @returns {Array} Filtered email template cards.
     */
    get filteredEmailTemplates() {
        const term = this.emailTemplateSearch.trim().toLowerCase();
        return this.emailTemplates
            .filter((template) => {
                if (!term) {
                    return true;
                }
                return (
                    template.label.toLowerCase().includes(term) ||
                    (template.folderName || '').toLowerCase().includes(term)
                );
            })
            .map((template) => ({
                ...template,
                isSelected: template.value === this.selectedTemplateId,
                cardClass:
                    'template-card email-modal__card' +
                    (template.value === this.selectedTemplateId
                        ? ' template-card_selected email-modal__card_selected'
                        : '')
            }));
    }

    get hasFilteredEmailTemplates() {
        return this.filteredEmailTemplates.length > 0;
    }

    get selectedEmailTemplateLabel() {
        const selected = this.emailTemplates.find(
            (template) => template.value === this.selectedTemplateId
        );
        return selected ? selected.label : '';
    }

    get totalEmailTemplateCount() {
        return this.emailTemplates.length;
    }

    get filteredEmailTemplateCount() {
        return this.filteredEmailTemplates.length;
    }

    get showSelectedEmailPreview() {
        return !!this.selectedTemplateId;
    }

    /**
     * Returns Bluewave templates filtered by search term with selection card classes.
     * @returns {Array} Filtered Bluewave template cards.
     */
    get filteredBluewaveTemplates() {
        const term = this.bluewaveTemplateSearch.trim().toLowerCase();
        return this.bluewaveTemplates
            .filter((template) => {
                if (!term) {
                    return true;
                }
                return (
                    (template.label || '').toLowerCase().includes(term) ||
                    (template.value || '').toLowerCase().includes(term)
                );
            })
            .map((template) => ({
                ...template,
                isSelected: template.value === this.selectedBluewaveTemplateId,
                cardClass:
                    'template-card bluewave-modal__card' +
                    (template.value === this.selectedBluewaveTemplateId
                        ? ' template-card_selected bluewave-modal__card_selected'
                        : '')
            }));
    }

    get hasFilteredBluewaveTemplates() {
        return this.filteredBluewaveTemplates.length > 0;
    }

    get totalBluewaveTemplateCount() {
        return this.bluewaveTemplates.length;
    }

    get filteredBluewaveTemplateCount() {
        return this.filteredBluewaveTemplates.length;
    }

    get selectedBluewaveTemplateLabel() {
        const selected = this.bluewaveTemplates.find(
            (template) => template.value === this.selectedBluewaveTemplateId
        );
        return selected ? selected.label : '';
    }

    get showSelectedBluewaveTemplatePreview() {
        return !!this.selectedBluewaveTemplateId;
    }

    /**
     * Whether the Bluewave email send button should be disabled.
     * @returns {boolean} True when no template is selected or a send/load is in progress.
     */
    get isBluewaveEmailSendDisabled() {
        return (
            !this.selectedBluewaveTemplateId ||
            this.isSendingBluewaveEmail ||
            this.isLoadingBluewaveTemplates
        );
    }

    /**
     * Returns campaign journeys filtered by search term with selection card classes.
     * @returns {Array} Filtered journey cards.
     */
    get filteredCampaignJourneys() {
        const term = this.campaignJourneySearch.trim().toLowerCase();
        return this.campaignJourneys
            .filter((journey) => {
                if (!term) {
                    return true;
                }
                return (journey.label || '').toLowerCase().includes(term);
            })
            .map((journey) => ({
                ...journey,
                isSelected: journey.value === this.selectedCampaignJourneyName,
                cardClass:
                    'template-card campaign-journey-modal__card' +
                    (journey.value === this.selectedCampaignJourneyName
                        ? ' template-card_selected campaign-journey-modal__card_selected'
                        : '')
            }));
    }

    get hasFilteredCampaignJourneys() {
        return this.filteredCampaignJourneys.length > 0;
    }

    get totalCampaignJourneyCount() {
        return this.campaignJourneys.length;
    }

    get filteredCampaignJourneyCount() {
        return this.filteredCampaignJourneys.length;
    }

    get selectedCampaignJourneyLabel() {
        const selected = this.campaignJourneys.find(
            (journey) => journey.value === this.selectedCampaignJourneyName
        );
        return selected ? selected.label : '';
    }

    get showSelectedCampaignJourneyPreview() {
        return !!this.selectedCampaignJourneyName;
    }

    /**
     * Whether the journey send button should be disabled.
     * @returns {boolean} True when no journey is selected or a send/load is in progress.
     */
    get isCampaignJourneySendDisabled() {
        return (
            !this.selectedCampaignJourneyName ||
            this.isSendingCampaignJourney ||
            this.isLoadingCampaignJourneys
        );
    }

    /**
     * Whether the WhatsApp step Next button should be disabled.
     * @returns {boolean} True when no WhatsApp template is selected or templates are loading.
     */
    get isJourneyNextDisabled() {
        return !this.selectedWhatsAppTemplateName || this.isLoadingWhatsAppTemplates;
    }

    /**
     * Whether the WhatsApp-only send button should be disabled.
     * @returns {boolean} True when no template is selected or sending/loading.
     */
    get isWhatsAppSendDisabled() {
        return (
            !this.selectedWhatsAppTemplateName ||
            this.isSendingWhatsApp ||
            this.isLoadingWhatsAppTemplates
        );
    }

    get isRcsStep() {
        return (
            this.journeyModalMode === 'rcs' ||
            (this.journeyModalMode === 'campaign' && this.journeyModalStep === 'rcs')
        );
    }

    get isSmsStep() {
        return (
            this.journeyModalMode === 'sms' ||
            (this.journeyModalMode === 'campaign' && this.journeyModalStep === 'sms')
        );
    }

    get isWhatsAppStep() {
        return this.journeyModalMode === 'campaign' && this.journeyModalStep === 'whatsapp';
    }

    get isCampaignModalMode() {
        return this.journeyModalMode === 'campaign';
    }

    get isRcsOnlyModalMode() {
        return this.journeyModalMode === 'rcs';
    }

    get isSmsOnlyModalMode() {
        return this.journeyModalMode === 'sms';
    }

    get journeyModalTitle() {
        if (this.journeyModalMode === 'rcs') {
            return 'Send RCS';
        }
        if (this.journeyModalMode === 'sms') {
            return 'Send SMS';
        }
        return 'Send WhatsApp Campaign';
    }

    get isRcsOnlySendDisabled() {
        return (
            !this.selectedRcsTemplateName ||
            this.isSendingWhatsApp ||
            this.isLoadingRcsTemplates
        );
    }

    get isSmsOnlySendDisabled() {
        return (
            !this.selectedSmsTemplateName ||
            this.isSendingWhatsApp ||
            this.isLoadingSmsTemplates
        );
    }

    /**
     * Builds the CSS class string for the journey modal overlay theme.
     * @returns {string} Overlay class including channel theme.
     */
    get journeyModalOverlayClass() {
        let themeClass = 'whatsapp-modal';
        if (this.isRcsStep) {
            themeClass = 'rcs-modal';
        } else if (this.isSmsStep) {
            themeClass = 'sms-modal';
        }
        return 'journey-modal-overlay ' + themeClass;
    }

    /**
     * Whether the multi-channel journey send button should be disabled.
     * @returns {boolean} True while sending or loading RCS/SMS templates.
     */
    get isJourneySendDisabled() {
        return (
            this.isSendingWhatsApp ||
            this.isLoadingRcsTemplates ||
            this.isLoadingSmsTemplates
        );
    }

    /**
     * Returns the label for the journey modal primary send/skip button.
     * @returns {string} Button label for the current step.
     */
    get journeySendButtonLabel() {
        if (this.isSmsStep) {
            return this.selectedSmsTemplateName ? 'Send Message' : 'Skip SMS & Send';
        }
        if (this.isRcsStep) {
            return this.selectedRcsTemplateName ? 'Send Message' : 'Skip RCS & Send';
        }
        return 'Send WhatsApp';
    }

    get totalRecordCount() {
        return this.opportunities.length;
    }

    get selectedRowIds() {
        return (this.selectedRows || []).map((row) => row.Id);
    }

    get stagePills() {
        const selected = new Set(this.selectedStages || []);
        return (this.stageOptions || []).map((option) => ({
            label: option.label,
            value: option.value,
            className: selected.has(option.value) ? 'pill pill_selected' : 'pill'
        }));
    }

    get datePresetPills() {
        return [
            { label: 'Last 7 days', value: '7' },
            { label: 'Last 30 days', value: '30' },
            { label: 'This quarter', value: 'quarter' },
            { label: 'Custom', value: 'custom' }
        ].map((pill) => ({
            ...pill,
            className: this.datePreset === pill.value ? 'pill pill_selected' : 'pill'
        }));
    }

    get showCustomDates() {
        return this.datePreset === 'custom';
    }

    get filtersAreStale() {
        return (
            !!this.appliedFilters &&
            !this.isLoading &&
            !filtersMatch(this.buildFilterState(), this.appliedFilters)
        );
    }

    get staleFilterMessage() {
        const count = changedFieldCount(this.buildFilterState(), this.appliedFilters);
        return `${count} ${count === 1 ? 'filter' : 'filters'} changed. Results below are out of date.`;
    }

    get appliedChips() {
        const applied = this.appliedFilters;
        if (!applied) {
            return [];
        }
        const chips = [];
        const pushChip = (key, label) => {
            if (label) {
                chips.push({ key, label });
            }
        };
        pushChip('search', applied.searchTerm);
        pushChip('dealer', applied.dealerAccountFilter);
        pushChip('stages', listChipLabel(optionLabels(applied.stages, this.stageOptions)));
        pushChip('dates', dateChipLabel(applied.fromDate, applied.toDate));
        pushChip('departments', listChipLabel(optionLabels(applied.departments, this.departmentOptions)));
        pushChip('categories', listChipLabel(optionLabels(applied.categories, this.customerCategoryOptions)));
        pushChip('country', listChipLabel(optionLabels(applied.country ? [applied.country] : [], this.countryOptions)));
        pushChip('states', listChipLabel(optionLabels(applied.states, this.stateOptions)));
        pushChip('lost', listChipLabel(optionLabels(applied.lostReasons, this.lostReasonOptions)));
        return chips;
    }

    get selectedRecordCount() {
        return this.selectedRows.length;
    }

    get showSelectedSmsPreview() {
        return !!this.selectedSmsTemplateName;
    }

    /**
     * Returns SMS templates filtered by search term with selection card classes.
     * @returns {Array} Filtered SMS template cards.
     */
    get filteredSmsTemplates() {
        const term = this.smsTemplateSearch.trim().toLowerCase();
        return this.smsTemplates
            .filter((template) => {
                if (!term) {
                    return true;
                }
                return template.label.toLowerCase().includes(term);
            })
            .map((template) => ({
                ...template,
                isSelected: template.value === this.selectedSmsTemplateName,
                cardClass:
                    'template-card sms-modal__card' +
                    (template.value === this.selectedSmsTemplateName
                        ? ' template-card_selected sms-modal__card_selected'
                        : '')
            }));
    }

    get hasFilteredSmsTemplates() {
        return this.filteredSmsTemplates.length > 0;
    }

    get selectedSmsTemplateLabel() {
        const selected = this.smsTemplates.find(
            (template) => template.value === this.selectedSmsTemplateName
        );
        return selected ? selected.label : '';
    }

    get totalSmsTemplateCount() {
        return this.smsTemplates.length;
    }

    get filteredSmsTemplateCount() {
        return this.filteredSmsTemplates.length;
    }

    /**
     * Returns RCS templates filtered by search term with selection card classes.
     * @returns {Array} Filtered RCS template cards.
     */
    get filteredRcsTemplates() {
        const term = this.rcsTemplateSearch.trim().toLowerCase();
        return this.rcsTemplates
            .filter((template) => {
                if (!term) {
                    return true;
                }
                return template.label.toLowerCase().includes(term);
            })
            .map((template) => ({
                ...template,
                isSelected: template.value === this.selectedRcsTemplateName,
                cardClass:
                    'template-card rcs-modal__card' +
                    (template.value === this.selectedRcsTemplateName
                        ? ' template-card_selected rcs-modal__card_selected'
                        : '')
            }));
    }

    get hasFilteredRcsTemplates() {
        return this.filteredRcsTemplates.length > 0;
    }

    get selectedRcsTemplateLabel() {
        const selected = this.rcsTemplates.find(
            (template) => template.value === this.selectedRcsTemplateName
        );
        return selected ? selected.label : '';
    }

    get totalRcsTemplateCount() {
        return this.rcsTemplates.length;
    }

    get filteredRcsTemplateCount() {
        return this.filteredRcsTemplates.length;
    }

    get showSelectedRcsPreview() {
        return !!this.selectedRcsTemplateName;
    }

    /**
     * Returns WhatsApp templates filtered by search term with selection card classes.
     * @returns {Array} Filtered WhatsApp template cards.
     */
    get filteredWhatsAppTemplates() {
        const term = this.whatsAppTemplateSearch.trim().toLowerCase();
        return this.whatsAppTemplates
            .filter((template) => {
                if (!term) {
                    return true;
                }
                return (
                    template.label.toLowerCase().includes(term) ||
                    (template.categoryName || '').toLowerCase().includes(term)
                );
            })
            .map((template) => ({
                ...template,
                isSelected: template.value === this.selectedWhatsAppTemplateName,
                cardClass:
                    'template-card whatsapp-modal__card' +
                    (template.value === this.selectedWhatsAppTemplateName
                        ? ' template-card_selected whatsapp-modal__card_selected'
                        : '')
            }));
    }

    get hasFilteredWhatsAppTemplates() {
        return this.filteredWhatsAppTemplates.length > 0;
    }

    get selectedWhatsAppTemplateLabel() {
        const selected = this.whatsAppTemplates.find(
            (template) => template.value === this.selectedWhatsAppTemplateName
        );
        return selected ? selected.label : '';
    }

    get totalWhatsAppTemplateCount() {
        return this.whatsAppTemplates.length;
    }

    get filteredWhatsAppTemplateCount() {
        return this.filteredWhatsAppTemplates.length;
    }

    get showSelectedWhatsAppPreview() {
        return !!this.selectedWhatsAppTemplateName;
    }

    /**
     * Whether the lost-reason filter should be visible for the selected stages.
     * @returns {boolean} True when a lost stage is selected.
     */
    get showLostReasonFilter() {
        return (this.selectedStages || []).some((stage) => {
            const normalized = (stage || '').trim().toLowerCase();
            return normalized === 'lost' || normalized === 'closed lost';
        });
    }

    get showStateFilter() {
        const country = (this.selectedCountry || '').trim().toLowerCase();
        return country === 'india' || country === 'in';
    }
}
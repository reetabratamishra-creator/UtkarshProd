/**
 * @description Contact campaign management datatable — search Contacts and send Journey/WhatsApp/RCS/SMS/Email campaigns.
 * @author      Anshita Chanda
 * @date        2026-08-06
 */
import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchContacts from '@salesforce/apex/BWM_CampaignFilterCtrl.searchContacts';
import getContactCountryOptions from '@salesforce/apex/BWM_CampaignFilterCtrl.getContactCountryOptions';
import getContactStateOptions from '@salesforce/apex/BWM_CampaignFilterCtrl.getContactStateOptions';
import getWhatsAppTemplates from '@salesforce/apex/ContactManagementController.getWhatsAppTemplates';
import getRcsTemplates from '@salesforce/apex/ContactManagementController.getRcsTemplates';
import getSmsTemplates from '@salesforce/apex/ContactManagementController.getSmsTemplates';
import getBluewaveEmailTemplates from '@salesforce/apex/ContactManagementController.getBluewaveEmailTemplates';
import sendContactCampaignEmail from '@salesforce/apex/ContactManagementController.sendContactCampaignEmailScheduled';
import getCampaignJourneys from '@salesforce/apex/ContactManagementController.getCampaignJourneys';
import sendContactJourney from '@salesforce/apex/ContactManagementController.sendContactJourneyScheduled';
import sendContactWhatsApp from '@salesforce/apex/BWM_WaCampCtrlA.sendContactWhatsAppScheduled';
import sendContactRcs from '@salesforce/apex/ContactManagementController.sendContactRcsScheduled';
import sendContactSms from '@salesforce/apex/ContactManagementController.sendContactSmsScheduled';
import createCampaignWithMembers from '@salesforce/apex/BWM_CustomCampaignMemberCtrl.createCampaignWithMembers';
import { SEND_ACTION, MEMBER_TYPE, trackCampaignMembers } from 'c/campaignSendActions';
import { changedFieldCount, filtersMatch, listChipLabel, optionLabels } from 'c/campaignFilterUi';

const COLUMNS = [
    {
        label: 'Contact Name',
        fieldName: 'contactUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'Name' },
            target: '_blank'
        }
    },
    { label: 'Email', fieldName: 'Email', type: 'email' },
    { label: 'Account', fieldName: 'AccountName', type: 'text' },
    { label: 'Phone', fieldName: 'Phone', type: 'phone' },
    { label: 'Created Date', fieldName: 'CreatedDate', type: 'date' }
];

export default class ContactManagementDatatable extends LightningElement {
    columns = COLUMNS;
    contacts = [];
    selectedRows = [];
    isLoading = true;

    searchTerm = '';
    phoneFilter = '';
    emailFilter = '';
    selectedCountry = '';
    countryOptions = [];
    selectedStates = [];
    stateOptions = [];
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

    @wire(getContactCountryOptions)
    wiredContactCountryOptions({ data, error }) {
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

    @wire(getContactStateOptions)
    wiredContactStateOptions({ data, error }) {
        if (data) {
            this.stateOptions = data.map((option) => ({
                label: option.label,
                value: option.value
            }));
        } else if (error) {
            this.showToast('Error', this.extractError(error), 'error');
        }
    }

    /**
     * Loads the initial contacts list when the component connects.
     * @returns {void} Nothing.
     */
    connectedCallback() {
        this.loadContacts(false);
    }

    /**
     * Searches Contacts via Apex and maps results for the datatable.
     * @param {boolean} notifyWhenEmpty When true, shows an info toast if no rows match.
     * @returns {Promise<void>} Resolves when search completes.
     */
    async loadContacts(notifyWhenEmpty) {
        this.isLoading = true;
        const requestedFilters = this.buildFilterState();

        try {
            const data = await searchContacts({
                searchTerm: this.searchTerm,
                phoneFilter: this.phoneFilter,
                emailFilter: this.emailFilter,
                countryFilter: this.selectedCountry || null,
                states: this.showStateFilter ? this.selectedStates : []
            });

            this.contacts = (data || []).map((row) => ({
                ...row,
                contactUrl: `/lightning/r/Contact/${row.Id}/view`,
                Email: row.Email || '',
                Phone: row.MobilePhone || row.Phone || '',
                AccountName: row.Account ? row.Account.Name || '' : ''
            }));
            this.appliedFilters = requestedFilters;

            if (notifyWhenEmpty && this.contacts.length === 0) {
                this.showToast('Search', 'No contacts match your search criteria.', 'info');
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
     * Updates the phone filter from the input.
     * @param {Event} event Input change event.
     * @returns {void} Nothing.
     */
    handlePhoneFilterChange(event) {
        this.phoneFilter = event.target.value;
    }

    /**
     * Updates the email filter from the input.
     * @param {Event} event Input change event.
     * @returns {void} Nothing.
     */
    handleEmailFilterChange(event) {
        this.emailFilter = event.target.value;
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
     * Clears selection and searches contacts with current filters.
     * @returns {void} Nothing.
     */
    handleSearch() {
        this.selectedRows = [];
        this.loadContacts(true);
    }

    handleResetFilters() {
        this.searchTerm = '';
        this.phoneFilter = '';
        this.emailFilter = '';
        this.selectedCountry = '';
        this.selectedStates = [];
        this.handleSearch();
    }

    handleRemoveAppliedChip(event) {
        const key = event.currentTarget.dataset.key;
        if (key === 'search') {
            this.searchTerm = '';
        } else if (key === 'phone') {
            this.phoneFilter = '';
        } else if (key === 'email') {
            this.emailFilter = '';
        } else if (key === 'country') {
            this.selectedCountry = '';
            this.selectedStates = [];
        } else if (key === 'states') {
            this.selectedStates = [];
        }
        this.handleSearch();
    }

    handleClearSelection() {
        this.selectedRows = [];
    }

    buildFilterState() {
        return {
            searchTerm: this.searchTerm || '',
            phoneFilter: this.phoneFilter || '',
            emailFilter: this.emailFilter || '',
            country: this.selectedCountry || '',
            states: this.showStateFilter ? this.selectedStates || [] : []
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
     * Opens the Salesforce email template modal for selected contacts.
     * @returns {void} Nothing.
     */
    handleSendEmail() {
        if (!this.hasSelection) {
            this.showToast('Send Email', 'Select at least one contact.', 'warning');
            return;
        }
        this.selectedTemplateId = null;
        this.emailTemplateSearch = '';
        this.isEmailModalOpen = true;
    }

    /**
     * Opens the Bluewave campaign email modal and loads templates for selected contacts.
     * @returns {Promise<void>} Resolves when templates are loaded.
     */
    async handleSendBluewaveEmail() {
        if (!this.hasSelection) {
            this.showToast('Send Campaign Email', 'Select at least one contact.', 'warning');
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
     * Sends Bluewave campaign emails to selected contacts.
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
        const contactIds = this.selectedRows.map((row) => row.Id);
        this.isSendingBluewaveEmail = true;

        try {
            const result = await sendContactCampaignEmail({
                contactIds,
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
     * Opens the journey modal and loads Bluewave journeys for selected contacts.
     * @returns {Promise<void>} Resolves when journeys are loaded.
     */
    async handleSendJourney() {
        if (!this.hasSelection) {
            this.showToast('Send Journey', 'Select at least one contact.', 'warning');
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
     * Queues Bluewave journey messages for selected contacts.
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
        const contactIds = this.selectedRows.map((row) => row.Id);
        this.isSendingCampaignJourney = true;

        try {
            const result = await sendContactJourney({
                contactIds,
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
     * Sends Salesforce emails to selected contacts, or shows guidance when not supported.
     * @returns {Promise<void>} Resolves when send completes or toast is shown.
     */
    async handleConfirmSendEmail() {
        this.showToast(
            'Send Email',
            'Use Send Campaign Email for contact email delivery.',
            'info'
        );
    }

    /**
     * Opens the WhatsApp campaign modal and loads WhatsApp templates for selected contacts.
     * @returns {Promise<void>} Resolves when WhatsApp templates are loaded.
     */
    async handleSendCustomerJourney() {
        if (!this.hasSelection) {
            this.showToast('Send WhatsApp Campaign', 'Select at least one contact.', 'warning');
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
            this.showToast('Send RCS', 'Select at least one contact.', 'warning');
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
            this.showToast('Send SMS', 'Select at least one contact.', 'warning');
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
     * Sends WhatsApp and optional RCS/SMS messages to selected contacts.
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
        const contactIds = this.selectedRows.map((row) => row.Id);
        const sendRcs = !!this.selectedRcsTemplateName;
        const sendSms = !!this.selectedSmsTemplateName;
        this.isSendingWhatsApp = true;

        try {
            let whatsAppResult = { sentCount: 0, skippedCount: 0, messages: [] };
            let rcsResult = { sentCount: 0, skippedCount: 0, messages: [] };
            let smsResult = { sentCount: 0, skippedCount: 0, messages: [] };

            try {
                whatsAppResult = await sendContactWhatsApp({
                    contactIds,
                    templateName: this.selectedWhatsAppTemplateName,
                    scheduledDateTime
                });
            } catch (whatsAppError) {
                whatsAppResult = {
                    sentCount: 0,
                    skippedCount: contactIds.length,
                    messages: [this.extractError(whatsAppError)]
                };
            }

            if (sendRcs) {
                try {
                    rcsResult = await sendContactRcs({
                        contactIds,
                        templateName: this.selectedRcsTemplateName,
                        scheduledDateTime
                    });
                } catch (rcsError) {
                    rcsResult = {
                        sentCount: 0,
                        skippedCount: contactIds.length,
                        messages: [this.extractError(rcsError)]
                    };
                }
            }

            if (sendSms) {
                try {
                    smsResult = await sendContactSms({
                        contactIds,
                        templateName: this.selectedSmsTemplateName,
                        scheduledDateTime
                    });
                } catch (smsError) {
                    smsResult = {
                        sentCount: 0,
                        skippedCount: contactIds.length,
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
        const contactIds = this.selectedRows.map((row) => row.Id);
        this.isSendingWhatsApp = true;

        try {
            const rcsResult = await sendContactRcs({
                contactIds,
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
        const contactIds = this.selectedRows.map((row) => row.Id);
        this.isSendingWhatsApp = true;

        try {
            const smsResult = await sendContactSms({
                contactIds,
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
            MEMBER_TYPE.CONTACT,
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

    get selectedContactCount() {
        return this.selectedRows.length;
    }

    get isSingleContact() {
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
        return this.contacts.length;
    }

    get selectedRowIds() {
        return (this.selectedRows || []).map((row) => row.Id);
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
        pushChip('phone', applied.phoneFilter);
        pushChip('email', applied.emailFilter);
        pushChip('country', listChipLabel(optionLabels(applied.country ? [applied.country] : [], this.countryOptions)));
        pushChip('states', listChipLabel(optionLabels(applied.states, this.stateOptions)));
        return chips;
    }

    get selectedRecordCount() {
        return this.selectedRows.length;
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

    get showStateFilter() {
        const country = (this.selectedCountry || '').trim().toLowerCase();
        return country === 'india' || country === 'in';
    }
}
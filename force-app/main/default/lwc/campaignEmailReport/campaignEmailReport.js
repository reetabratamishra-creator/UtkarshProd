/**
 * @description Campaign email report LWC — consolidated Infobip email delivery stats (last 48 hours).
 * @author      Anshita Chanda
 * @date        2026-08-06
 */
import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import fetchEmailCampaignReport from '@salesforce/apex/CampaignEmailReportController.fetchEmailCampaignReport';
import getCampaignEmailSubjectOptionsFromLogs from '@salesforce/apex/CampaignEmailReportController.getCampaignEmailSubjectOptionsFromLogs';

const SUMMARY_COLUMNS = [
  { label: 'Index', fieldName: 'indexNo', type: 'number' },
  { label: 'Recipient', fieldName: 'recipient', type: 'text' },
  { label: 'Delivered', fieldName: 'delivered', type: 'number' },
  { label: 'Failed', fieldName: 'failed', type: 'number' },
  { label: 'Pending', fieldName: 'pending', type: 'number' },
  { label: 'Opened', fieldName: 'opened', type: 'number' }
];

export default class CampaignEmailReport extends NavigationMixin(LightningElement) {
  @track summaryRows = [];
  selectedProduct = 'Email';
  subjectSearchTerm = '';
  activeSubjectFilter = 'All Subjects';
  knownSubjects = [];
  productName = 'EMAIL';
  reportIds = [];
  isLoading = false;
  fetchComplete = false;
  errorMessage;
  columns = SUMMARY_COLUMNS;

  productOptions = [{ label: 'Email', value: 'Email' }];
  lastPageLoadKey;

  connectedCallback() {
    this.handlePageShow = (event) => {
      if (event.persisted) {
        this.lastPageLoadKey = null;
        this.initializeFreshReport(false);
      }
    };
    window.addEventListener('pageshow', this.handlePageShow);
  }

  disconnectedCallback() {
    if (this.handlePageShow) {
      window.removeEventListener('pageshow', this.handlePageShow);
    }
    this.resetReportUiState();
  }

  @wire(CurrentPageReference)
  handlePageReference(pageRef) {
    if (!pageRef) {
      return;
    }

    const pageLoadKey = pageRef.state?.c__ts || 'initial';
    if (pageLoadKey === this.lastPageLoadKey) {
      return;
    }
    this.lastPageLoadKey = pageLoadKey;
    this.initializeFreshReport(false);
  }

  @wire(getCampaignEmailSubjectOptionsFromLogs)
  wiredKnownSubjects({ data }) {
    if (data) {
      this.knownSubjects = (data || [])
        .map((option) => option?.value || option?.label || '')
        .filter((value) => value);
    }
  }

  get hasReport() {
    return this.summaryRows && this.summaryRows.length > 0;
  }

  get totalRecipients() {
    return this.summaryRows.length;
  }

  get totalDelivered() {
    return this.summaryRows.reduce((sum, row) => sum + (row.delivered || 0), 0);
  }

  get totalFailed() {
    return this.summaryRows.reduce((sum, row) => sum + (row.failed || 0), 0);
  }

  get totalPending() {
    return this.summaryRows.reduce((sum, row) => sum + (row.pending || 0), 0);
  }

  get totalOpened() {
    return this.summaryRows.reduce((sum, row) => sum + (row.opened || 0), 0);
  }

  get showEmptyState() {
    return this.fetchComplete && !this.hasReport && !this.errorMessage;
  }

  get isSubjectFilterActive() {
    return this.activeSubjectFilter && this.activeSubjectFilter !== 'All Subjects';
  }

  get emptyStateTitle() {
    return this.isSubjectFilterActive ? 'No records found for this subject' : 'No delivery data available';
  }

  get emptyStateMessage() {
    if (this.isSubjectFilterActive) {
      return `No campaign email delivery records were found for subject "${this.activeSubjectFilter}" in the last 48 hours. Please verify the subject text, try a different keyword, or leave the search blank and click Fetch Report to view all campaign sends.`;
    }
    return 'No email delivery reports were found for campaign sends in the last 48 hours. If emails were sent recently, try again shortly or confirm the sends were logged from Campaign Management.';
  }

  get showReportSection() {
    return this.fetchComplete && (this.hasReport || this.showEmptyState);
  }

  get disableFetch() {
    return this.isLoading || !this.selectedProduct;
  }

  get disableClearFilter() {
    return (
      this.isLoading ||
      (!this.isSubjectFilterActive && !(this.subjectSearchTerm || '').trim())
    );
  }

  handleProductChange(event) {
    this.selectedProduct = event.detail.value;
  }

  handleSubjectSearchChange(event) {
    this.subjectSearchTerm = event.detail.value ?? '';
  }

  resolveSubjectFilter() {
    const typedSubject = (this.subjectSearchTerm || '').trim();
    if (!typedSubject) {
      return null;
    }

    const exactMatch = this.knownSubjects.find(
      (subject) => subject.toLowerCase() === typedSubject.toLowerCase()
    );
    if (exactMatch) {
      return exactMatch;
    }

    const partialMatches = this.knownSubjects.filter((subject) =>
      subject.toLowerCase().includes(typedSubject.toLowerCase())
    );
    if (partialMatches.length === 1) {
      return partialMatches[0];
    }
    if (partialMatches.length > 1) {
      const startsWithMatches = partialMatches.filter((subject) =>
        subject.toLowerCase().startsWith(typedSubject.toLowerCase())
      );
      if (startsWithMatches.length === 1) {
        return startsWithMatches[0];
      }
    }

    return typedSubject;
  }

  resetReportUiState() {
    this.subjectSearchTerm = '';
    this.activeSubjectFilter = 'All Subjects';
    this.summaryRows = [];
    this.reportIds = [];
    this.fetchComplete = false;
    this.errorMessage = undefined;
  }

  async initializeFreshReport(showToast) {
    this.resetReportUiState();
    await this.fetchReport(null, showToast);
  }

  async handleFetch() {
    const typedValue = (this.subjectSearchTerm || '').trim();
    if (!typedValue) {
      this.subjectSearchTerm = '';
      await this.fetchReport(null, true);
      return;
    }

    const subject = this.resolveSubjectFilter();
    await this.fetchReport(subject, true);
  }

  async handleClearFilter() {
    this.subjectSearchTerm = '';
    await this.fetchReport(null, true);
  }

  async fetchReport(subject, showToast) {
    this.isLoading = true;
    this.errorMessage = undefined;
    this.fetchComplete = false;
    this.summaryRows = [];

    try {
      const result = await fetchEmailCampaignReport({
        campaignEmailSubject: subject || ''
      });
      this.summaryRows = (result?.summaryRows || []).map((row) => ({
        indexNo: row?.indexNo ?? 1,
        recipient: row?.recipient || '',
        delivered: row?.delivered ?? 0,
        failed: row?.failed ?? 0,
        pending: row?.pending ?? 0,
        opened: row?.opened ?? 0
      }));
      this.reportIds = result?.reportIds || [];
      this.productName = this.selectedProduct
        ? this.selectedProduct.toUpperCase()
        : 'EMAIL';
      this.activeSubjectFilter = subject || 'All Subjects';
      this.fetchComplete = true;

      if (!showToast) {
        return;
      }

      const toastMessage =
        this.summaryRows.length > 0
          ? subject
            ? `Email campaign report loaded for subject: ${subject}`
            : 'Email campaign report loaded for all subjects.'
          : this.emptyStateMessage;

      this.dispatchEvent(
        new ShowToastEvent({
          title:
            this.summaryRows.length > 0
              ? 'Report loaded'
              : this.emptyStateTitle,
          message: toastMessage,
          variant: this.summaryRows.length > 0 ? 'success' : 'warning'
        })
      );
    } catch (error) {
      this.errorMessage = this.normalizeError(error);
      this.fetchComplete = true;
      if (showToast) {
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Fetch failed',
            message: this.errorMessage,
            variant: 'error',
            mode: 'sticky'
          })
        );
      }
    } finally {
      this.isLoading = false;
    }
  }

  handleBackToList() {
    this.lastPageLoadKey = null;
    this.resetReportUiState();
    this[NavigationMixin.Navigate]({
      type: 'standard__objectPage',
      attributes: {
        objectApiName: 'Campaign',
        actionName: 'list'
      }
    });
  }

  normalizeError(error) {
    if (!error) {
      return 'Unknown error';
    }
    if (Array.isArray(error.body)) {
      return error.body.map((item) => item.message).join(', ');
    }
    if (error.body && typeof error.body.message === 'string') {
      return error.body.message;
    }
    if (typeof error.message === 'string') {
      return error.message;
    }
    return 'Unexpected error while fetching email campaign report.';
  }
}
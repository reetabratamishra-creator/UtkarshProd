import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCampaignOptions from '@salesforce/apex/CampaignStatsController.getCampaignOptions';
import fetchCampaignStats from '@salesforce/apex/CampaignStatsController.fetchCampaignStats';

const STATS_COLUMNS = [
  { label: 'Index', fieldName: 'indexNo', type: 'number' },
  { label: 'Delivered', fieldName: 'delivered', type: 'number' },
  { label: 'Failed', fieldName: 'failed', type: 'number' },
  { label: 'Non RCS No', fieldName: 'nonRcsNo', type: 'number' },
  { label: 'Read', fieldName: 'readCount', type: 'number' }
];

export default class CampaignStatsReport extends NavigationMixin(LightningElement) {
  @track campaignOptions = [];
  @track statsRows = [];
  selectedCampaignId;
  selectedCampaignName;
  selectedProduct = 'RCS';
  journeyName;
  journeyCampaignName;
  productName;
  rawResponse;
  reportIds = [];
  isLoading = false;
  errorMessage;
  recordIds = [];
  columns = STATS_COLUMNS;

  productOptions = [
    { label: 'RCS', value: 'RCS' },
    { label: 'WhatsApp', value: 'WhatsApp' }
  ];

  @wire(CurrentPageReference)
  setCurrentPageReference(pageRef) {
    const idsParam = pageRef?.state?.c__recordIds;
    if (!idsParam) {
      this.errorMessage =
        'No campaigns were passed. Go to Campaigns list, select rows, then click Fetch Campaign Stats.';
      return;
    }
    this.recordIds = idsParam
      .split(',')
      .map((value) => value.trim())
      .filter((value) => value);
    this.loadCampaignOptions();
  }

  get hasOptions() {
    return this.campaignOptions && this.campaignOptions.length > 0;
  }

  get hasReport() {
    return this.statsRows && this.statsRows.length > 0;
  }

  get disableFetch() {
    return (
      this.isLoading ||
      !this.selectedCampaignId ||
      !this.selectedCampaignName ||
      !this.selectedProduct
    );
  }

  async loadCampaignOptions() {
    this.isLoading = true;
    this.errorMessage = undefined;
    try {
      const options = await getCampaignOptions({ campaignIds: this.recordIds });
      this.campaignOptions = (options || []).map((item) => ({
        label: item.name,
        value: item.id,
        name: item.name
      }));
      if (this.campaignOptions.length === 1) {
        this.selectedCampaignId = this.campaignOptions[0].value;
        this.selectedCampaignName = this.campaignOptions[0].name;
      }
    } catch (error) {
      this.errorMessage = this.normalizeError(error);
    } finally {
      this.isLoading = false;
    }
  }

  handleCampaignChange(event) {
    this.selectedCampaignId = event.detail.value;
    const match = this.campaignOptions.find(
      (option) => option.value === this.selectedCampaignId
    );
    this.selectedCampaignName = match ? match.name : null;
  }

  handleProductChange(event) {
    this.selectedProduct = event.detail.value;
  }

  async handleFetch() {
    this.isLoading = true;
    this.errorMessage = undefined;
    try {
      const result = await fetchCampaignStats({
        campaignId: this.selectedCampaignId,
        campaignName: this.selectedCampaignName,
        productName: this.selectedProduct
      });
      this.journeyName = result.journeyName;
      this.journeyCampaignName = result.journeyCampaignName;
      this.productName = result.productName;
      this.rawResponse = result.rawResponse;
      this.statsRows = result.components || [];
      this.reportIds = result.reportIds || [];
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Campaign report saved',
          message:
            (this.reportIds.length || 0) +
            ' Campaign Report record(s) created.',
          variant: 'success'
        })
      );
    } catch (error) {
      this.errorMessage = this.normalizeError(error);
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Fetch failed',
          message: this.errorMessage,
          variant: 'error',
          mode: 'sticky'
        })
      );
    } finally {
      this.isLoading = false;
    }
  }

  handleBackToList() {
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
    return 'Unexpected error while fetching campaign stats.';
  }
}
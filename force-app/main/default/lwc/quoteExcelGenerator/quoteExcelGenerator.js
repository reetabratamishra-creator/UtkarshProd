import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import QUOTE_VALUE_FIELD from '@salesforce/schema/Quote.Quote_Value__c';
import getAvailableMappings from '@salesforce/apex/CreateQuoteController.getAvailableMappings';
import QUOTE_REFERENCE_FIELD from '@salesforce/schema/Quote.Quote_Reference__c';
// ── MOBILE EXPORT PATH — Deepanjan (17th July 2026) ──────────────────────────
// FORM_FACTOR is a compile-time constant: 'Large' on desktop, 'Medium'/'Small'
// on the Salesforce mobile app. Desktop keeps the iframe preview and
// window.open exactly as before; on mobile both are unusable (the webview
// blocks popup navigation and the VF iframe is what crash-reloads the app), so
// the export instead saves the rendered document as a Salesforce File via Apex
// and opens the app's NATIVE file previewer, which has its own download/share.
import FORM_FACTOR from '@salesforce/client/formFactor';
import { NavigationMixin } from 'lightning/navigation';
import saveQuoteDocumentToFiles from '@salesforce/apex/QuoteCostingDocumentMobileController.saveQuoteDocumentToFiles';

export default class QuoteDocumentGenerator extends NavigationMixin(LightningElement) {
    @api recordId;

    // Set by createQuote: false until the quote is Approved / finalized. Preview stays
    // on; only the export path is locked. Deepanjan (18th September 2026)
    @api allowDownload = false;

    get exportDisabled() { return this.isButtonDisabled || !this.allowDownload; }
    get showDownloadLockedNote() { return !this.allowDownload; }
    
    @track isButtonDisabled = true;
    @track selectedFormat = 'pdf'; 
    @track isLoading = false;
    
    // UI Tracks for Sub Type Dropdown
    @track subTypeOptions = [];
    @track selectedSubType = '';
    @track showSubTypeSelection = false;

    // Track for PDF Preview
    @track previewUrl = null;

    savedJsonData = {};
    allMappings = []; // Stores all metadata records for the department
    docConfig = null; // The currently selected specific config

       quoteReference = '';

    get buttonLabel() {
        return `Export as ${this.selectedFormat.toUpperCase()}`;
    }

    // Desktop check for the template: preview column renders only on 'Large'.
    // Deepanjan (17th July 2026)
    get isDesktop() {
        return FORM_FACTOR === 'Large';
    }

    // Controls whether the iframe renders (Always show PDF preview if available)
    get showPreview() {
        // Mobile: preview mode is OFF by request - the VF iframe is also what was
        // crash-reloading the app's webview. Deepanjan (17th July 2026)
        if (FORM_FACTOR !== 'Large') return false;
        return this.previewUrl != null;
    }

        @wire(getRecord, { recordId: '$recordId', fields: [QUOTE_VALUE_FIELD], optionalFields: [QUOTE_REFERENCE_FIELD] })
    wiredQuote({ error, data }) {
        if (data) {
                        this.quoteReference = getFieldValue(data, QUOTE_REFERENCE_FIELD) || '';
            const rawJson = getFieldValue(data, QUOTE_VALUE_FIELD);
            if (rawJson) {
                try {
                    this.savedJsonData = JSON.parse(rawJson);
                    // Fetch Metadata once JSON is ready
                    this.fetchMetadataConfig(); 
                } catch(e) {
                    console.error('Error parsing JSON from Quote', e);
                }
            }
        } else if (error) {
            console.error('Error fetching Quote Data', error);
        }
    }

    // =========================================================
    // FETCH & MAP ALL AVAILABLE TEMPLATES
    // =========================================================
    async fetchMetadataConfig() {
        const department = this.savedJsonData._Saved_Template_Name;

        if (department) {
            this.isLoading = true;
            try {
                const mappings = await getAvailableMappings({ department: department });
                
                if (mappings && mappings.length > 0) {
                    this.allMappings = mappings;
                    
                    this.subTypeOptions = mappings.map(map => ({
                        label: map.Template_Type__c === '*' ? 'Standard / Default' : map.Template_Type__c,
                        value: map.Template_Type__c
                    }));

                    this.showSubTypeSelection = this.subTypeOptions.length > 0;

                    if (this.subTypeOptions.length > 0) {
                        const savedSubType = this.savedJsonData.mast_standard || this.savedJsonData.mast_customized;
                        const exactMatch = this.subTypeOptions.find(opt => opt.value === savedSubType);
                        
                        this.selectedSubType = exactMatch ? exactMatch.value : this.subTypeOptions[0].value;
                        this.updateActiveConfig();
                    }
                } else {
                    this.showToast('No Templates', 'No document templates found for this department.', 'warning');
                    this.isButtonDisabled = true;
                }
            } catch (err) {
                console.error('Error fetching document config:', err);
                this.showToast('Error', 'Failed to load document templates.', 'error');
            } finally {
                this.isLoading = false;
            }
        }
    }

    // When User changes the Sub Type Dropdown
    handleSubTypeChange(event) {
        this.selectedSubType = event.detail.value;
        this.updateActiveConfig();
    }

   // ---------------------------------------------------
    // AVAILABILITY CHECKS (Checks metadata for VF page links)
    // ---------------------------------------------------
    get hasPdf() { return this.docConfig && this.docConfig.PDF_VF_Page__c; }
    get hasExcel() { return this.docConfig && this.docConfig.Excel_VF_Page__c; }
    get hasWord() { return this.docConfig && this.docConfig.Word_VF_Page__c; }

    // ---------------------------------------------------
    // DYNAMIC CARD STYLING (Applies blue border or greys out)
    // ---------------------------------------------------
    get pdfCardClass() {
        if (!this.hasPdf) return 'format-card disabled-card slds-box slds-text-align_center';
        return this.selectedFormat === 'pdf' 
            ? 'format-card selected-card slds-box slds-text-align_center' 
            : 'format-card slds-box slds-text-align_center';
    }
    
    get excelCardClass() {
        if (!this.hasExcel) return 'format-card disabled-card slds-box slds-text-align_center';
        return this.selectedFormat === 'excel' 
            ? 'format-card selected-card slds-box slds-text-align_center' 
            : 'format-card slds-box slds-text-align_center';
    }
    
    get wordCardClass() {
        if (!this.hasWord) return 'format-card disabled-card slds-box slds-text-align_center';
        return this.selectedFormat === 'word' 
            ? 'format-card selected-card slds-box slds-text-align_center' 
            : 'format-card slds-box slds-text-align_center';
    }

    // ---------------------------------------------------
    // HANDLE FORMAT CLICK
    // ---------------------------------------------------
    handleFormatSelect(event) {
        const format = event.currentTarget.dataset.format;
        
        // Block the click if the format doesn't have a VF page configured
        if (format === 'pdf' && !this.hasPdf) return;
        if (format === 'excel' && !this.hasExcel) return;
        if (format === 'word' && !this.hasWord) return;

        this.selectedFormat = format;
        
        if (typeof this.updatePreviewUrl === 'function') {
            this.updatePreviewUrl();
        }
    }

    
   
    // Finds the specific metadata config and updates the Live Preview URL
    updateActiveConfig() {
        this.docConfig = this.allMappings.find(map => map.Template_Type__c === this.selectedSubType);
        this.isButtonDisabled = !this.docConfig;

        // Generate the real-time preview URL for the iframe
        // Preview goes through the common QuoteOfferPreview VF page (canvas via pdf.js
        // in a real Worker), never the PDF page itself - so the browser holds no PDF.
        // Deepanjan (18th September 2026)
        if (this.docConfig && this.docConfig.PDF_VF_Page__c) {
            const pageName = this.docConfig.PDF_VF_Page__c.split('?')[0].replace(/^\/apex\//, '');
            this.previewUrl = `/apex/QuoteOfferPreview?id=${this.recordId}&page=${encodeURIComponent(pageName)}`;
        } else {
            this.previewUrl = null;
        }
    }

        // DOWNLOAD FILE NAME = QUOTE REFERENCE - Deepanjan (22nd September 2026)
    // Desktop Export opens the common QuoteOfferOpen page (same new tab, same document),
    // which saves the file as the Quote Reference: UIL/CB/26-27/00008106 -> UIL_CB_26-27_00008106.pdf
    // No Quote Reference yet -> the old URL, i.e. exactly the old behaviour.
    namedOpenUrl(targetUrl) {
        const ref = String(this.quoteReference || '').replace(/[^A-Za-z0-9_-]+/g, '_').replace(/^_+|_+$/g, '');
        const pageName = String(targetUrl || '').split('?')[0].replace(/^\/apex\//, '');
        if (!ref || !/^[A-Za-z0-9_]+$/.test(pageName)) return targetUrl;
        return `/apex/QuoteOfferOpen?id=${this.recordId}&page=${pageName}&type=${this.selectedFormat}&fn=${encodeURIComponent(ref)}`;
    }

    // =========================================================
    // GENERATE DOCUMENT (Downloads / Opens in New Tab)
    // =========================================================
    generateDocument() {
        // Hard stop, independent of how the button was drawn. Deepanjan (18th September 2026)
        if (!this.allowDownload) {
            this.showToast('Not Yet', 'Download is available once the quote is approved.', 'warning');
            return;
        }
        if (!this.docConfig) {
            this.showToast('Template Not Found', 'No document template is mapped for this selection.', 'error');
            return;
        }

        let targetUrl = '';

        if (this.selectedFormat === 'pdf') {
            targetUrl = this.docConfig.PDF_VF_Page__c ? `${this.docConfig.PDF_VF_Page__c}?id=${this.recordId}` : null;
            if (!targetUrl) {
                this.showToast('Not Available', 'PDF export is not configured for this template.', 'warning');
                return;
            }
        } 
        else if (this.selectedFormat === 'excel') {
            targetUrl = this.docConfig.Excel_VF_Page__c ? `${this.docConfig.Excel_VF_Page__c}?id=${this.recordId}` : null;
            if (!targetUrl) {
                this.showToast('Not Available', 'Excel export is not configured for this template.', 'warning');
                return;
            }
        } 
        else if (this.selectedFormat === 'word') {
            targetUrl = this.docConfig.Word_VF_Page__c ? `${this.docConfig.Word_VF_Page__c}?id=${this.recordId}` : null;
            if (!targetUrl) {
                this.showToast('Not Available', 'Word export is not configured for this template.', 'warning');
                return;
            }
        }

        if (targetUrl) {
            if (FORM_FACTOR === 'Large') {
                // DESKTOP: unchanged - opens the VF page in a new tab, browser
                // handles preview/download exactly as it always has.
                                window.open(this.namedOpenUrl(targetUrl), '_blank');
            } else {
                // MOBILE (Salesforce app): window.open is blocked/blank inside the
                // app's webview, so the document is rendered server-side, saved as
                // a File on the quote, and opened in the app's native previewer -
                // which provides download/share. Deepanjan (17th July 2026)
                this.saveAndOpenOnMobile();
            }
        }
    }

    // =========================================================
    // MOBILE-ONLY EXPORT — Deepanjan (17th July 2026)
    // Apex renders the same VF page with PageReference.getContent[AsPDF](),
    // inserts it as a ContentVersion linked to the quote, and returns the
    // ContentDocumentId; standard__namedPage/filePreview then opens the
    // native file viewer. Nothing here runs on desktop.
    // =========================================================
    async saveAndOpenOnMobile() {
        // send the bare VF path; the server appends ?id= itself and validates
        // the path shape, so no client-composed URL is ever fetched blindly.
        const vfPath = (this.selectedFormat === 'pdf' && this.docConfig.PDF_VF_Page__c)
            || (this.selectedFormat === 'excel' && this.docConfig.Excel_VF_Page__c)
            || (this.selectedFormat === 'word' && this.docConfig.Word_VF_Page__c)
            || null;

        if (!vfPath) {
            this.showToast('Not Available', 'Export is not configured for this template.', 'warning');
            return;
        }

        this.isLoading = true;
        try {
            const res = await saveQuoteDocumentToFiles({
                quoteId: this.recordId,
                vfPagePath: vfPath.split('?')[0],
                format: this.selectedFormat
            });

            const openUrl = res && (res.publicUrl || res.downloadUrl);
            if (openUrl) {
                // publicUrl first: the app's URL validator rejects the long
                // ContentDownloadUrl ("Page doesn't exist") but accepts the short
                // /a/<token> link, whose page has its own Download button. The file
                // stays PRIVATE - finalize owns the quote's copies.
                // Deepanjan (18th July 2026)
                this.showToast('Document Ready', 'Tap Download on the page that opens.', 'success');
                this[NavigationMixin.Navigate]({
                    type: 'standard__webPage',
                    attributes: { url: openUrl }
                });
            } else {
                this.showToast('Document Ready', 'Use the share icon in the preview to save it to your phone.', 'success');
                this[NavigationMixin.Navigate]({
                    type: 'standard__namedPage',
                    attributes: { pageName: 'filePreview' },
                    state: { selectedRecordId: res ? res.contentDocumentId : null }
                });
            }
        } catch (err) {
            const msg = (err && err.body && err.body.message) ? err.body.message : 'Could not generate the document.';
            console.error('Mobile export failed:', JSON.stringify(err));
            this.showToast('Export Failed', msg, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
}
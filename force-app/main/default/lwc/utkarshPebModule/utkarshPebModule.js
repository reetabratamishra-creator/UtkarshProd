import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadScript } from 'lightning/platformResourceLoader';
import PDF_JS_ZIP from '@salesforce/resourceUrl/pdfjs';
import { parseUniversalBuildingPdf } from 'c/pebBuildingParser';

export default class UtkarshPebModule extends LightningElement {
    @api quoteId;
    @api savedData = {};

    @track isModalOpen = false;

    // File Tracking
    @track buildingFile;
    @track buildingFileName = '';
    @track estimationFile;
    @track estimationFileName = '';

    // Data Tracking
    @track accessoriesList = []; // 👉 NEW: Array to hold extracted table rows
    @track termsRef = '';
    @track termsDate = '';
    @track supplierOrderFormat = '';
    @track transportationFreight = 0;

    // UI States
    @track isApplied = false;
    @track isExtracting = false;
    @track errorMessage = '';

    get hasAccessories() {
        return this.accessoriesList && this.accessoriesList.length > 0;
    }

    @api openModal() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
        this.errorMessage = '';
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
        this.isApplied = false;
    }

    handleRichTextChange(event) {
        this.supplierOrderFormat = event.target.value;
        this.isApplied = false;
    }

    handleBuildingFileChange(event) {
        if (event.target.files.length > 0) {
            this.buildingFile = event.target.files[0];
            this.buildingFileName = this.buildingFile.name;
            this.isApplied = false;
            // Optionally clear old accessories if they upload a new file
            // this.accessoriesList = []; 
        }
    }

    handleEstimationFileChange(event) {
        if (event.target.files.length > 0) {
            this.estimationFile = event.target.files[0];
            this.estimationFileName = this.estimationFile.name;
            this.isApplied = false;
        }
    }

    // 👉 NEW: Handler for the Checkbox in the grid
    handleAccessorySelect(event) {
        const id = event.target.dataset.id;
        const isChecked = event.target.checked;
        const index = this.accessoriesList.findIndex(acc => acc.id === id);
        if (index !== -1) {
            this.accessoriesList[index].selected = isChecked;
            this.isApplied = false;
        }
    }

    // 👉 NEW: Handler for users editing text inside the grid
    handleAccessoryChange(event) {
        const id = event.target.dataset.id;
        const field = event.target.dataset.field;
        const val = event.target.value;
        const index = this.accessoriesList.findIndex(acc => acc.id === id);
        if (index !== -1) {
            this.accessoriesList[index][field] = val;
            this.isApplied = false;
        }
    }

    // 👉 NEW: The Auto-Fill Mock Logic (Based strictly on your PDF upload!)
    async extractDataFromPDF() {
        if (!this.buildingFile) return;

        this.isExtracting = true;
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Reading Document...',
                message: 'Extracting technical specifications and accessories table. Please wait.',
                variant: 'info'
            })
        );

        try {
            if (!window.pdfjsLib) {
                await loadScript(this, PDF_JS_ZIP + '/build/pdf.js');
                await loadScript(this, PDF_JS_ZIP + '/build/pdf.worker.js');
            }
            const buffer = await this.buildingFile.arrayBuffer();
            const parsed = await parseUniversalBuildingPdf(new Uint8Array(buffer));
            this._buildingDescription = parsed;

            const allRows = [];
            let rId = 1;
            for (const acc of parsed.accessories) {
                allRows.push({
                    id: String(rId++),
                    selected: true,
                    description: acc.description,
                    size: acc.size,
                    quantity: acc.quantity,
                    remark: acc.remark
                });
            }
            for (const buy of parsed.buyouts) {
                allRows.push({
                    id: String(rId++),
                    selected: true,
                    description: buy.description,
                    size: buy.size,
                    quantity: buy.quantity,
                    remark: buy.remark
                });
            }

            this.accessoriesList = allRows;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Extraction Complete',
                    message: `Successfully extracted ${allRows.length} items from ${this.buildingFileName}.`,
                    variant: 'success'
                })
            );

        } catch (error) {
            console.error('Extraction Error:', error);
            this.errorMessage = 'Failed to extract data from the PDF: ' + (error.message || error);
        } finally {
            this.isExtracting = false;
        }
    }

  handleApply() {
        const sampleLineItems = [
            {
                itemName: 'Sample PEB Item - Connection Successful!',
                quantity: 1,
                unitPrice: 1500,
                unitCost: 1000,
                unitListPrice: 1500,
                netPrice: 1500,
                listPrice: 1500,
                cost: 1000,
                margin: 500,
                uom: 'EA',
                billable: false
            }
        ];

        const values = {
            _pebModuleTriggered: true
        };
        if (this._buildingDescription) {
            values._buildingDescription = this._buildingDescription;
        }

        const payload = {
            values: values,
            lineItems: sampleLineItems,
            modalConfig: { title: 'PEB_MODULE' },
            isComplete: true
        };

        this.dispatchEvent(new CustomEvent('applyvalues', { detail: payload }));
        this.closeModal();
    }

    handleGenerateBankDoc() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Generating Document',
                message: 'Compiling Bank Doc based on uploaded PDFs and configurations...',
                variant: 'info'
            })
        );
        // Call Apex to generate the doc
    }
}
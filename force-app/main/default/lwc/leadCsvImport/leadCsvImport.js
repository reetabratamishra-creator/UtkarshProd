import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLeadSourceOptions from '@salesforce/apex/LeadCsvImportController.getLeadSourceOptions';
import processLeadImport from '@salesforce/apex/LeadCsvImportController.processLeadImport';

/*const DATATABLE_COLUMNS = [
    { label: 'First Name', fieldName: 'firstName', editable: true },
    { label: 'Last Name', fieldName: 'lastName', editable: true },
    { label: 'Phone', fieldName: 'phone', type: 'phone', editable: true },
    { label: 'Department Name', fieldName: 'departmentName', editable: true },
    { label: 'Email', fieldName: 'email', type: 'email', editable: true }
];*/

const REQUIRED_FIELD_KEYS = ['firstName', 'lastName', 'phone', 'departmentName'];

const MAX_CSV_ROWS = 50;

// Column headers that must be present in the CSV (case-insensitive, order-independent).
const REQUIRED_COLUMNS = ['First Name', 'Last Name', 'Phone', 'Department Name'];

// Optional columns - still counted toward the "exactly 5 columns" rule.
const OPTIONAL_COLUMNS = ['Email'];

const ALL_EXPECTED_COLUMNS = [...REQUIRED_COLUMNS, ...OPTIONAL_COLUMNS];
const EXPECTED_COLUMN_COUNT = ALL_EXPECTED_COLUMNS.length;

// Maps a (lowercased, trimmed) CSV header name to the internal field key used
// by the preview datatable and the Apex wrapper.
const HEADER_TO_FIELD_KEY = {
    'first name': 'firstName',
    'last name': 'lastName',
    'phone': 'phone',
    'department name': 'departmentName',
    'email': 'email'
};

// Lead Source values for which the supporting-document upload is NOT required
// (comparison is case-insensitive).
const LEAD_SOURCES_NO_FILE_REQUIRED = ['OFFLINE CRM', 'Offline Marketing'];

/**
 * Minimal RFC-4180-ish CSV parser (no external library dependency).
 * Handles quoted fields, escaped quotes (""), and commas inside quotes.
 * Returns an array of rows, each row an array of trimmed string cells.
 */
function parseCsv(text) {
    const rows = [];
    let row = [];
    let field = '';
    let inQuotes = false;
    // Normalize line endings so \r\n and \r are treated like \n.
    const input = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');

    for (let i = 0; i < input.length; i++) {
        const char = input[i];

        if (inQuotes) {
            if (char === '"') {
                if (input[i + 1] === '"') {
                    field += '"';
                    i++;
                } else {
                    inQuotes = false;
                }
            } else {
                field += char;
            }
        } else if (char === '"') {
            inQuotes = true;
        } else if (char === ',') {
            row.push(field);
            field = '';
        } else if (char === '\n') {
            row.push(field);
            rows.push(row);
            row = [];
            field = '';
        } else {
            field += char;
        }
    }
    // Push the last field/row if the file didn't end with a newline.
    if (field.length > 0 || row.length > 0) {
        row.push(field);
        rows.push(row);
    }

    // Drop fully blank trailing rows (common with trailing newlines).
    return rows.filter((r) => r.some((cell) => cell && cell.trim().length > 0));
}

export default class LeadCsvImport extends LightningElement {
    // columns = DATATABLE_COLUMNS;

    // ---- Reactive state ----
    @track leadSourceOptions = [];
    selectedLeadSource = '';

    csvFileName = '';
    @track previewData = [];
    draftValues = [];
    datatableErrors = {};
    showPreview = false;

    supportingFileName = '';
    supportingFileBase64 = '';

    showErrorModal = false;
    errorModalMessage = '';

    isProcessing = false;
    showResultSummary = false;
    resultSummary = null;
    showFinishButton = false;

    isLeadSourcesLoaded = false;

    connectedCallback() {
        this.loadLeadSourceOptions();
    }

    get columns() {
        return [
            {
                label: 'First Name',
                fieldName: 'firstName',
                editable: !this.showResultSummary
            },
            {
                label: 'Last Name',
                fieldName: 'lastName',
                editable: !this.showResultSummary
            },
            {
                label: 'Phone',
                fieldName: 'phone',
                type: 'phone',
                editable: !this.showResultSummary
            },
            {
                label: 'Department Name',
                fieldName: 'departmentName',
                editable: !this.showResultSummary
            },
            {
                label: 'Email',
                fieldName: 'email',
                type: 'email',
                editable: !this.showResultSummary
            }
        ];
    }

    async loadLeadSourceOptions() {
        try {
            const options = await getLeadSourceOptions();
            this.leadSourceOptions = (options || []).map((val) => ({ label: val, value: val }));
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLeadSourcesLoaded = true;
        }
    }

    // ---- Computed getters ----

    get isFileSectionVisible() {
        if (!this.selectedLeadSource) {
            return false;
        }
        const normalized = this.selectedLeadSource.trim().toUpperCase();
        return !LEAD_SOURCES_NO_FILE_REQUIRED.some((src) => src.trim().toUpperCase() === normalized);
    }

    get isInsertDisabled() {
        return this.isProcessing || !this.showPreview;
    }

    get hasCsvFile() {
        return !!this.csvFileName;
    }

    get supportingFileRequiredLabel() {
        return this.isFileSectionVisible ? 'Supporting Document (required)' : '';
    }

    // ---- Lead Source ----

    handleLeadSourceChange(event) {
        this.selectedLeadSource = event.detail.value;
        // If the file section becomes hidden, clear any previously attached file
        // so a stale file isn't silently sent on Insert.
        if (!this.isFileSectionVisible) {
            this.supportingFileName = '';
            this.supportingFileBase64 = '';
        }
    }

    // ---- CSV Upload ----

    handleCsvFileChange(event) {
        const file = event.target.files && event.target.files[0];
        if (!file) {
            return;
        }
        const reader = new FileReader();
        reader.onload = () => {
            this.parseAndValidateCsv(reader.result, file.name);
        };
        reader.onerror = () => {
            this.openErrorModal('There was a problem reading the file. Please try again.');
        };
        reader.readAsText(file);
    }

    handleRemoveCsvFile() {
        this.resetCsvState();
    }

    parseAndValidateCsv(text, fileName) {
        const rows = parseCsv(text);
        if (!rows || rows.length === 0) {
            this.openErrorModal('The uploaded CSV file is empty.');
            return;
        }

        const header = rows[0];
        const dataRows = rows.slice(1);

        // 1. Column count check
        if (header.length !== EXPECTED_COLUMN_COUNT) {
            this.openErrorModal(
                `The CSV must contain exactly ${EXPECTED_COLUMN_COUNT} columns. Found ${header.length}.`
            );
            return;
        }

        // Build a header-name -> column-index map (case-insensitive, trimmed)
        const normalizedHeader = header.map((h) => h.trim().toLowerCase());
        const headerIndexByFieldKey = {};
        normalizedHeader.forEach((h, idx) => {
            const fieldKey = HEADER_TO_FIELD_KEY[h];
            if (fieldKey) {
                headerIndexByFieldKey[fieldKey] = idx;
            }
        });

        // 2. Required columns present check
        const missingRequired = REQUIRED_COLUMNS.filter((col) => {
            const fieldKey = HEADER_TO_FIELD_KEY[col.trim().toLowerCase()];
            return headerIndexByFieldKey[fieldKey] === undefined;
        });
        if (missingRequired.length > 0) {
            this.openErrorModal(
                `The CSV is missing required column(s): ${missingRequired.join(', ')}.`
            );
            return;
        }
        console.log('Data rows:', dataRows.length);
        // 3. Row limit check
        if (dataRows.length >= MAX_CSV_ROWS + 1) {
            this.openErrorModal(
                `The uploaded CSV contains ${dataRows.length} records. A maximum of ${MAX_CSV_ROWS} records can be imported at a time. Please split the file into smaller batches and try again.`
            );
            return;
        }
        if (dataRows.length === 0) {
            this.openErrorModal('The CSV does not contain any data rows.');
            return;
        }

        // Build preview data, keyed by field name rather than column position,
        // so column order in the source file doesn't matter.
        const emailIdx = headerIndexByFieldKey.email;
        this.previewData = dataRows.map((cells, i) => ({
            rowKey: `row-${i}-${Date.now()}`,
            firstName: (cells[headerIndexByFieldKey.firstName] || '').trim(),
            lastName: (cells[headerIndexByFieldKey.lastName] || '').trim(),
            phone: (cells[headerIndexByFieldKey.phone] || '').trim(),
            departmentName: (cells[headerIndexByFieldKey.departmentName] || '').trim(),
            email: emailIdx !== undefined ? (cells[emailIdx] || '').trim() : ''
        }));

        this.csvFileName = fileName;
        this.showPreview = true;
    }

    // ---- Datatable inline edit ----

    handleSave(event) {
        const draftValues = event.detail.draftValues;
        const updatedRows = this.previewData.map((row) => {
            const draft = draftValues.find((d) => d.rowKey === row.rowKey);
            return draft ? { ...row, ...draft } : row;
        });
        this.previewData = updatedRows;
        this.draftValues = [];
        this.datatableErrors = {};
    }

    // ---- Supporting file ----

    handleSupportingFileChange(event) {
        const file = event.target.files && event.target.files[0];
        if (!file) {
            return;
        }
        const reader = new FileReader();
        reader.onload = () => {
            // reader.result is a data URL: "data:<mime>;base64,<data>"
            const base64 = reader.result.split(',')[1];
            this.supportingFileBase64 = base64;
            this.supportingFileName = file.name;
        };
        reader.onerror = () => {
            this.showToast('Error', 'There was a problem reading the supporting file.', 'error');
        };
        reader.readAsDataURL(file);
    }

    handleRemoveSupportingFile() {
        this.supportingFileName = '';
        this.supportingFileBase64 = '';
    }

    // ---- Row validation before Insert ----

    validateRows() {
        const errors = { rows: {}, table: {} };
        let hasError = false;

        this.previewData.forEach((row) => {
            const missingFields = REQUIRED_FIELD_KEYS.filter((key) => !row[key] || !row[key].trim());
            if (missingFields.length > 0) {
                hasError = true;
                errors.rows[row.rowKey] = {
                    title: 'Missing required field(s)',
                    messages: [`Please complete: ${missingFields.join(', ')}`],
                    fieldNames: missingFields
                };
            }
        });

        if (hasError) {
            errors.table = {
                title: 'We found errors in the table.',
                messages: ['Please fix the highlighted rows before inserting.']
            };
        }

        this.datatableErrors = errors;
        return !hasError;
    }

    // ---- Action buttons ----

    async handleInsert() {
        if (!this.selectedLeadSource) {
            this.showToast('Error', 'Lead Source is required.', 'error');
            return;
        }
        if (!this.validateRows()) {
            this.showToast('Error', 'Please fix the highlighted rows before inserting.', 'error');
            return;
        }
        if (this.isFileSectionVisible && !this.supportingFileBase64) {
            this.showToast('Error', 'A supporting document is required for this Lead Source.', 'error');
            return;
        }

        this.isProcessing = true;
        try {
            const leadsJson = JSON.stringify(this.previewData);
            const result = await processLeadImport({
                leadsJson,
                leadSourceValue: this.selectedLeadSource,
                fileName: this.isFileSectionVisible ? this.supportingFileName : null,
                fileBase64: this.isFileSectionVisible ? this.supportingFileBase64 : null
            });
            //console.log(result);
            //console.log(result.errors);
            //console.log(JSON.stringify(result));

            this.resultSummary = {
                totalProcessed: result.totalProcessed,
                successCount: result.successCount,
                failCount: result.failCount,
                hasFailures: result.failCount > 0,
                errors: result.errors || []
            };
            this.showResultSummary = true;
            this.showFinishButton = true;
        } catch (error) {
            console.error(error);
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    handleCancel() {
        this.resetComponent();
    }

    handleFinish() {
        this.resetComponent();
    }

    // ---- Error modal ----

    openErrorModal(message) {
        this.errorModalMessage = message;
        this.showErrorModal = true;
    }

    handleCloseErrorModal() {
        this.showErrorModal = false;
        this.errorModalMessage = '';
        // Per spec: closing the error modal resets the whole component.
        this.resetComponent();
    }

    // ---- Reset helpers ----

    resetCsvState() {
        this.csvFileName = '';
        this.previewData = [];
        this.draftValues = [];
        this.datatableErrors = {};
        this.showPreview = false;
        this.supportingFileName = '';
        this.supportingFileBase64 = '';
        const csvInput = this.template.querySelector('[data-id="csv-file-input"]');
        if (csvInput) {
            csvInput.value = null;
        }
    }

    resetComponent() {
        this.selectedLeadSource = '';
        this.resetCsvState();
        this.showResultSummary = false;
        this.resultSummary = null;
        this.showFinishButton = false;
        this.isProcessing = false;
    }

    // ---- Utilities ----

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractErrorMessage(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'An unknown error occurred.';
    }
}
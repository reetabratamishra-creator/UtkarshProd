/**
 * @description Upload Offline Campaign LWC — Excel/CSV upload UI to create Offline Campaign rows in bulk.
 * @author      Anshita Chanda
 * @date        2026-08-06
 */
import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDepartmentOptions from '@salesforce/apex/OfflineCampaignUploadController.getDepartmentOptions';
import insertOfflineCampaignRows from '@salesforce/apex/OfflineCampaignUploadController.insertOfflineCampaignRows';

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export default class UploadOfflineCampaign extends LightningElement {
  @track rows = [];
  @track draftValues = [];
  @track departmentOptions = [];
  @track columns = [];
  @track insertSummary;
  @track errorSummary = [];

  isLoading = false;
  hasUploadedFile = false;
  uploadedFileName;
  groupList = '';

  /**
   * Builds datatable columns when the upload component connects.
   * @returns {void} Nothing.
   */
  connectedCallback() {
    this.buildColumns();
  }

  /**
   * Wire handler that loads department picklist options for upload.
   * @param {Object} {data, error} Wire result with data or error.
   * @returns {void} Nothing.
   */
  @wire(getDepartmentOptions)
  wiredDepartmentOptions({ data, error }) {
    if (data) {
      this.departmentOptions = data;
      this.buildColumns();
    } else if (error) {
      this.showToast('Error', this.normalizeError(error), 'error');
    }
  }

  /**
   * Builds editable datatable column definitions including department picklist.
   * @returns {void} Nothing.
   */
  buildColumns() {
    this.columns = [
      { label: 'Name', fieldName: 'recordName', type: 'text', editable: true },
      { label: 'Email', fieldName: 'email', type: 'email', editable: true },
      {
        label: 'Phone',
        fieldName: 'phoneDisplay',
        type: 'text',
        editable: true
      },
      {
        label: 'Department',
        fieldName: 'department',
        type: 'picklist',
        editable: true,
        typeAttributes: {
          placeholder: 'Choose department',
          options: this.departmentOptions || [],
          value: { fieldName: 'department' },
          context: { fieldName: 'department' }
        }
      },
      {
        label: 'Errors',
        fieldName: 'errors',
        type: 'text',
        wrapText: true,
        initialWidth: 260
      }
    ];
  }

  get hasRows() {
    return this.rows && this.rows.length > 0;
  }

  /**
   * Whether the insert button should be disabled.
   * @returns {boolean} True when loading or there are no rows.
   */
  get disableInsert() {
    return this.isLoading || !this.hasRows || !(this.groupList || '').trim();
  }

  get showSummary() {
    return this.insertSummary != null;
  }

  /**
   * @description Comma-separated department values customers must copy into the CSV.
   * @returns {string} Department names, or a short fallback while options load.
   */
  get departmentNames() {
    const names = (this.departmentOptions || [])
      .map((option) => option.value)
      .filter((value) => value);
    return names.length ? names.join(', ') : 'loading department list';
  }

  /**
   * Downloads a CSV template with the columns this upload accepts and one sample row.
   * @returns {void} Nothing.
   */
  handleDownloadFormat() {
    const sampleDepartment = this.csvEscape(
      (this.departmentOptions &&
        this.departmentOptions[0] &&
        this.departmentOptions[0].value) ||
        'Enquiry'
    );
    const csv = [
      'Name,Email,Phone,Department',
      `Sample Customer,sample.customer@example.com,9876543210,${sampleDepartment}`
    ].join('\r\n');
    const link = document.createElement('a');
    link.href =
      'data:text/csv;charset=utf-8,' + encodeURIComponent('\uFEFF' + csv);
    link.download = 'Offline_Campaign_Upload_Format.csv';
    link.click();
  }

  /**
   * @description Quotes a CSV value when it contains a comma, quote, or line break.
   * @param {string} value Cell value.
   * @returns {string} CSV-safe value.
   */
  csvEscape(value) {
    const text = value == null ? '' : String(value);
    if (/[",\r\n]/.test(text)) {
      return `"${text.replace(/"/g, '""')}"`;
    }
    return text;
  }

  handleGroupListChange(event) {
    this.groupList = event.detail.value ?? '';
  }

  /**
   * Reads an uploaded CSV/Excel text file and populates validated preview rows.
   * @param {Event} event File input change event.
   * @returns {void} Nothing.
   */
  handleFileChange(event) {
    const file = event.target.files && event.target.files[0];
    if (!file) {
      return;
    }

    this.uploadedFileName = file.name;
    this.isLoading = true;
    this.insertSummary = null;
    this.errorSummary = [];

    const reader = new FileReader();
    reader.onload = () => {
      try {
        const parsedRows = this.parseCsv(String(reader.result || ''));
        this.rows = parsedRows.map((row) => this.applyValidation(row));
        this.hasUploadedFile = true;
        this.draftValues = [];
        if (!this.rows.length) {
          this.showToast(
            'No data found',
            'The uploaded file did not contain any data rows.',
            'warning'
          );
        }
      } catch (error) {
        this.showToast('Upload failed', error.message, 'error');
        this.rows = [];
        this.hasUploadedFile = false;
      } finally {
        this.isLoading = false;
      }
    };
    reader.onerror = () => {
      this.isLoading = false;
      this.showToast('Upload failed', 'Unable to read the selected file.', 'error');
    };
    reader.readAsText(file);
  }

  /**
   * Consolidates inline draft cell edits from the datatable.
   * @param {Event} event Datatable cell change event.
   * @returns {void} Nothing.
   */
  handleCellChange(event) {
    this.draftValues = this.consolidateDraftChanges(
      this.draftValues,
      event.detail.draftValues
    );
  }

  /**
   * Applies draft edits to rows and shows a saved toast.
   * @param {Event} event Datatable save event.
   * @returns {void} Nothing.
   */
  handleSaveEdits(event) {
    const applied = this.applyDraftChanges(
      event?.detail?.draftValues,
      this.draftValues
    );
    if (applied) {
      this.showToast('Saved', 'Your changes have been saved.', 'success');
    }
  }

  /**
   * Merges one or more draft-value lists into the current rows and revalidates.
   * @param {Array} draftLists One or more draft value arrays.
   * @returns {boolean} True if any draft changes were applied.
   */
  applyDraftChanges(...draftLists) {
    const changes = this.consolidateDraftChanges(...draftLists);
    if (!changes.length) {
      return false;
    }

    const draftByKey = new Map();
    for (const change of changes) {
      if (!change?.rowKey) {
        continue;
      }
      const existing = draftByKey.get(change.rowKey) || {};
      draftByKey.set(change.rowKey, { ...existing, ...change });
    }

    this.rows = this.rows.map((row) => {
      const change = draftByKey.get(row.rowKey);
      if (!change) {
        return row;
      }

      const merged = { ...row, ...change };
      if (Object.prototype.hasOwnProperty.call(change, 'phoneDisplay')) {
        merged.phone = this.parsePhone(change.phoneDisplay);
      } else if (Object.prototype.hasOwnProperty.call(change, 'phone')) {
        merged.phone = this.parsePhone(change.phone);
        merged.phoneDisplay = change.phone;
      }
      return this.applyValidation(merged);
    });
    this.draftValues = [];
    return true;
  }

  /**
   * Merges multiple draft-value lists by rowKey into a single change list.
   * @param {Array} draftLists One or more draft value arrays.
   * @returns {Array} Consolidated draft changes.
   */
  consolidateDraftChanges(...draftLists) {
    const draftByKey = new Map();
    for (const draftList of draftLists) {
      if (!draftList || !draftList.length) {
        continue;
      }
      for (const change of draftList) {
        if (!change?.rowKey) {
          continue;
        }
        const existing = draftByKey.get(change.rowKey) || {};
        draftByKey.set(change.rowKey, { ...existing, ...change });
      }
    }
    return Array.from(draftByKey.values());
  }

  /**
   * Clears pending draft edits without applying them.
   * @returns {void} Nothing.
   */
  handleCancelEdits() {
    this.draftValues = [];
  }

  /**
   * Validates rows and inserts Offline Campaign records via Apex.
   * @returns {Promise<void>} Resolves when insert completes.
   */
  async handleInsert() {
    this.isLoading = true;
    this.insertSummary = null;
    this.errorSummary = [];

    try {
      const groupList = (this.groupList || '').trim();
      if (!groupList) {
        this.showToast(
          'Group / List required',
          'Enter the group or list name before inserting records.',
          'error'
        );
        return;
      }

      const validatedRows = this.rows.map((row) => this.applyValidation(row));
      const rowsWithErrors = validatedRows.filter((row) => row.errors);
      if (rowsWithErrors.length) {
        this.rows = validatedRows;
        this.showToast(
          'Validation failed',
          'Fix the errors shown in the table before inserting.',
          'error'
        );
        return;
      }

      const payload = validatedRows.map((row) => ({
        rowKey: row.rowKey,
        recordName: row.recordName,
        email: row.email || null,
        phone: row.phone,
        department: row.department || null,
        active: row.active === true
      }));

      const summary = await insertOfflineCampaignRows({
        rowsJson: JSON.stringify(payload),
        groupList
      });
      this.insertSummary = summary;
      this.errorSummary = (Array.isArray(summary.errorSummary)
        ? summary.errorSummary
        : summary.errorSummary
          ? [summary.errorSummary]
          : []
      ).map((message, index) => ({ key: `error-${index}`, value: message }));

      const resultByKey = new Map(
        (summary.rowResults || []).map((item) => [item.rowKey, item])
      );
      this.rows = this.rows.map((row) => {
        const result = resultByKey.get(row.rowKey);
        if (!result) {
          return row;
        }
        return {
          ...row,
          errors: result.success ? '' : result.errors
        };
      });

      this.showToast(
        'Insert complete',
        `Total: ${summary.totalCount}, Success: ${summary.successCount}, Failed: ${summary.failedCount}`,
        summary.failedCount > 0 ? 'warning' : 'success'
      );
    } catch (error) {
      this.showToast('Insert failed', this.normalizeError(error), 'error');
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * Clears uploaded rows, summary, and the file input.
   * @returns {void} Nothing.
   */
  handleReset() {
    this.rows = [];
    this.draftValues = [];
    this.insertSummary = null;
    this.errorSummary = [];
    this.hasUploadedFile = false;
    this.uploadedFileName = null;
    this.groupList = '';
    const fileInput = this.template.querySelector('input[type="file"]');
    if (fileInput) {
      fileInput.value = null;
    }
  }

  /**
   * Parses CSV text into Offline Campaign row objects.
   * @param {string} content Raw CSV file contents.
   * @returns {Array} Parsed row objects.
   */
  parseCsv(content) {
    const normalizedContent = content.replace(/^\uFEFF/, '');
    const lines = normalizedContent
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line.length > 0);

    if (!lines.length) {
      return [];
    }

    const headers = this.parseCsvLine(lines[0]).map((header) =>
      header.trim().toLowerCase()
    );
    const headerIndex = {
      name: headers.indexOf('name'),
      email: headers.indexOf('email'),
      phone: headers.indexOf('phone'),
      department: headers.indexOf('department'),
      active: headers.indexOf('active')
    };

    if (headerIndex.name === -1) {
      throw new Error('CSV must include a Name column.');
    }

    const parsedRows = [];
    for (let lineNumber = 1; lineNumber < lines.length; lineNumber++) {
      const values = this.parseCsvLine(lines[lineNumber]);
      if (values.every((value) => !value || !value.trim())) {
        continue;
      }

      const phoneValue = this.getCsvValue(values, headerIndex.phone);
      parsedRows.push({
        rowKey: `row-${lineNumber}`,
        recordName: this.getCsvValue(values, headerIndex.name),
        email: this.getCsvValue(values, headerIndex.email),
        phone: this.parsePhone(phoneValue),
        phoneDisplay: phoneValue,
        department: this.getCsvValue(values, headerIndex.department),
        active: this.parseActive(this.getCsvValue(values, headerIndex.active)),
        errors: ''
      });
    }

    return parsedRows;
  }

  /**
   * Parses a single CSV line, respecting quoted commas.
   * @param {string} line One CSV line.
   * @returns {Array<string>} Field values for the line.
   */
  parseCsvLine(line) {
    const values = [];
    let current = '';
    let inQuotes = false;

    for (let index = 0; index < line.length; index++) {
      const character = line[index];
      if (character === '"') {
        if (inQuotes && line[index + 1] === '"') {
          current += '"';
          index++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (character === ',' && !inQuotes) {
        values.push(current);
        current = '';
      } else {
        current += character;
      }
    }
    values.push(current);
    return values;
  }

  /**
   * Safely reads a trimmed CSV field by column index.
   * @param {Array<string>} values Parsed line values.
   * @param {number} index Column index, or -1 if missing.
   * @returns {string} Trimmed field value or empty string.
   */
  getCsvValue(values, index) {
    if (index === -1 || index >= values.length) {
      return '';
    }
    return (values[index] || '').trim();
  }

  /**
   * Normalizes a phone string to a trimmed value or null.
   * @param {string} value Raw phone input.
   * @returns {string|null} Trimmed phone or null.
   */
  parsePhone(value) {
    if (!value) {
      return null;
    }
    const trimmed = String(value).trim();
    return trimmed ? trimmed : null;
  }

  /**
   * Parses Active column values (true/yes/1/y) into a boolean.
   * @param {string} value Raw active column value.
   * @returns {boolean} True when the value indicates active.
   */
  parseActive(value) {
    if (!value) {
      return false;
    }
    const normalized = value.trim().toLowerCase();
    return ['true', 'yes', '1', 'y'].includes(normalized);
  }

  /**
   * Validates and normalizes a single upload row, attaching error text.
   * @param {Object} row Row to validate.
   * @returns {Object} Validated row with errors string.
   */
  applyValidation(row) {
    const errors = [];
    const departmentValues = new Set(
      (this.departmentOptions || []).map((option) => option.value)
    );
    const recordName = row.recordName ? String(row.recordName).trim() : '';

    if (!recordName) {
      errors.push('Name: Name is required.');
    } else if (recordName.length > 80) {
      errors.push('Name: Name cannot exceed 80 characters.');
    }

    if (row.email && !EMAIL_PATTERN.test(String(row.email).trim())) {
      errors.push('Email: Invalid email format.');
    }

    if (row.phone && !/^\+?[\d\s\-()]+$/.test(String(row.phone).trim())) {
      errors.push('Phone: Invalid phone format.');
    }

    if (row.department && !departmentValues.has(row.department)) {
      errors.push('Department: Invalid picklist value.');
    }

    const phoneDisplay =
      row.phoneDisplay != null && String(row.phoneDisplay).trim()
        ? String(row.phoneDisplay).trim()
        : row.phone
          ? String(row.phone).trim()
          : '';
    const phone = this.parsePhone(phoneDisplay);

    return {
      ...row,
      recordName,
      email: row.email ? String(row.email).trim() : '',
      department: row.department ? String(row.department).trim() : '',
      phone,
      phoneDisplay,
      errors: errors.join(' ')
    };
  }

  /**
   * Dispatches a Lightning toast notification.
   * @param {string} title Toast title.
   * @param {string} message Toast message body.
   * @param {string} variant Toast variant (success, error, warning, info).
   * @returns {void} Nothing.
   */
  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }

  /**
   * Normalizes an Apex or Lightning error into a readable string.
   * @param {Object} error Error object from Apex or wire.
   * @returns {string} Human-readable error message.
   */
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
    return 'Unexpected error while processing offline campaign upload.';
  }
}
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadScript } from 'lightning/platformResourceLoader';
import PDF_JS_ZIP from '@salesforce/resourceUrl/pdfjs';
import getCalculatorData from '@salesforce/apex/PEBPriceCalcController.getCalculatorData';
import getEstimationFileBase64 from '@salesforce/apex/PEBPriceCalcController.getEstimationFileBase64';
import getBuildingDescriptionFileBase64 from '@salesforce/apex/PEBPriceCalcController.getBuildingDescriptionFileBase64';
import saveCalculation from '@salesforce/apex/PEBPriceCalcController.saveCalculation';
import generatePdf from '@salesforce/apex/PEBPriceCalcController.generatePdf';
import { parseBuildingPdfV2 as parseUniversalBuildingPdf } from 'c/pebBuildingParserV2';
import { parseEstimationPdf } from 'c/pebEstimationParser';


const UNIT_OPTIONS = ['Sq.M', 'Kg', 'No.s', 'RM', 'Mtr', 'Ltr', 'Piece'].map((u) => ({ label: u, value: u }));

/**
 * Section A rows map estimation sections -> raw-material line items.
 * totalKey = which extracted section value pre-fills the "Total Weight" column.
 *
 *   A  Built-up            B  Cold formed        C1 Anchor bolts (line value)
 *   CRest Hardware TOTAL - C1                    D  Hot Rolled Section
 *   E  Deck Sheet          F  Galvalume Roof     G  Galvalume Wall
 *   H  Packing Material
 */
const SECTION_A_MAP = [
    { key: 'builtUp', slNo: 1, totalKey: 'A' },
    { key: 'coldForm', slNo: 2, totalKey: 'B' },
    { key: 'anchorBolt', slNo: 3, totalKey: 'C1' },
    { key: 'hardware', slNo: 4, totalKey: 'CRest' },
    { key: 'hotRolled', slNo: 5, totalKey: 'D' },
    { key: 'deckSheet', slNo: 6, totalKey: 'E' },
    { key: 'galvalumeRoof', slNo: 7, totalKey: 'F' },
    { key: 'galvalumeWall', slNo: 8, totalKey: 'G' },
    { key: 'packingMaterial', slNo: 9, totalKey: 'H' }
];

const TOTAL_KEYS = ['A', 'B', 'C1', 'CRest', 'D', 'E', 'F', 'G', 'H'];

const CONVERSION_KEYS = [
    'shotBlasting',
    'primer',
    'intermediateCoat',
    'finalPaint',
    'fabricationBuiltUpHR',
    'profilingColdForm',
    'profilingGalvalume',
    'design'
];

const OTHER_COST_ROWS = [
    { key: 'truck', description: 'Truck' },
    { key: 'trailer', description: 'Trailer' },
    { key: 'misc', description: 'Miscellaneous' },
    { key: 'other', description: 'Other' }
];

const VARIABLE_COST_ROWS = [
    { key: 'service', description: 'Service Cost' },
    { key: 'agency', description: 'Agency Commission' },
    { key: 'contingency', description: 'Contingency' }
];


// delivery option
const DELIVERY_TERM_OPTIONS = [
    { label: 'Ex-Works', value: 'ExWorks' },
    { label: 'FOR', value: 'FOR' }
];

/* ---------------------------------------------------------------------------
   Column geometry of the estimation PDF, in PDF points.
   CALIBRATED against the revised "Design Estimation" layout (landscape,
   792 x 612pt) using the header positions:
       Sr.No. @56 | Description @125 | Qty. @235 | Unit @266 |
       Unit weight @295 | Total weight (kg) @339
   Adjust these bands if the estimation template changes.
--------------------------------------------------------------------------- */
const COL = {
    SR: [0, 78],
    DESC: [78, 230],
    QTY: [230, 280],
    UNIT: [280, 310],
    UNIT_WT: [310, 340],
    TOTAL: [340, 900] // Expanded to catch deeply shifted totals
};
const ROW_TOL = 3; // pt - the value prints ~1pt above its own section label

/** description keyword -> extracted section key. Order is significant. */
const SECTION_MATCHERS = [
    { key: 'A', re: /built[\s-]*up|a572/i },
    { key: 'B', re: /cold[\s-]*form|a653/i },
    { key: 'HW', re: /hard[\s-]*ware|a307/i },
    { key: 'D', re: /hot[\s-]*rolled|misc\.?\s*hr|is[\s-]*2062/i },
    { key: 'E', re: /deck\s*sheet|decking|mezzanine\s*deck/i },
    { key: 'F', re: /galvalume[^|]*roof/i },
    { key: 'G', re: /galvalume[^|]*wall/i },
    { key: 'H', re: /packing/i }
];

export default class PebPriceCalculator extends LightningElement {

    @api isChildMode = false;
    @api savedPayload = null;   // parent's copy, used instead of the Opportunity field in child mode

handleApplyToQuote() {
    if (!this.validate()) return;
    const payload = this.buildPayload();
    this.dispatchEvent(new CustomEvent('saveconfig', {
        detail: { payload },
        bubbles: true,
        composed: true
    }));
}
    @api recordId; // Opportunity Id (record page)

    @track started = false;
    @track loading = false;
    @track saving = false;

    // Config / source info
    rateConfig;
    estimationFileName;
    estimationReadable = false;
    hasEstimationFile = false;
    hasSavedCalculation = false; // true when a saved calculation was rehydrated
    pdfjsReady = false; // set once pdf.js has loaded (for the client-side reader)
    @track autoReading = false; // true while auto-reading the attached estimation
    readProgress = 0; // 0-100 value for the estimation reading progress bar

    // Editable model
    @track sectionA = [];
    @track accessories = [];
    @track buyouts = [];
    @track specialItems = [];
    @track conversion = [];
    @track otherCost = [];
    @track variableCost = [];
    @track totals = {};
    @track marginPercent = 10;
    @track gstPercent = 18;
    @track benchmarkRate = 90;

    // PAYMENT TERMS - Deepanjan (31st July 2026)
    // Three free-text periods typed on the Summary screen. They take NO part in
    // any calculation; they only ride inside the saved JSON so that
    // GenerateBankDoc.page can print them in the Delivery Schedule and the
    // Validity clause. Nothing here can move a total.
    //@track consignmentPeriod = '';
    //@track erectionPeriod = '';
    @track offerValidity = '';

    // TRANSPORTATION - Summary tab, between Payment Terms and Totals.
    // transportationValue only counts toward the cost totals when deliveryTerm
    // is 'FOR'; on 'ExWorks' it's excluded from calc even if a number is typed,
    // so switching terms back and forth doesn't lose what the user entered.
    @track deliveryTerm = 'FOR';
    @track transportationValue = 0;

    // Add-row selectors
    selectedAccessoryType;
    selectedBuyoutType;

    rowSeq = 0;

    /* =================== getters =================== */
    get showLanding() {
        return !this.started && !this.loading;
    }

    get showCalculator() {
        return this.started && !this.loading;
    }

    // Show the browser-side PDF reader only when the server could not read the
    // estimation, pdf.js is available, and we're not mid auto-read.
    get showEstimationFallback() {
        return this.started && !this.estimationReadable && this.pdfjsReady && !this.autoReading;
    }

    // Show a loading indicator while the attached estimation is being read.
    get showEstimationLoading() {
        return this.started && this.autoReading;
    }

    get unitOptions() {
        return UNIT_OPTIONS;
    }

    get accessoryTypeOptions() {
        return this.optionsFrom(this.rateConfig && this.rateConfig.accessories);
    }

    get buyoutTypeOptions() {
        return this.optionsFrom(this.rateConfig && this.rateConfig.buyouts);
    }

    optionsFrom(cfg) {
        if (!cfg) {
            return [];
        }
        return Object.keys(cfg).map((k) => ({ label: cfg[k].label, value: k }));
    }

    get hasAccessories() {
        return this.accessories.length > 0;
    }

    get hasBuyouts() {
        return this.buyouts.length > 0;
    }

    get hasSpecialItems() {
        return this.specialItems.length > 0;
    }

    get isBannerSuccess() {
        return this.hasEstimationFile && this.estimationReadable;
    }

    get bannerClass() {
        const base = 'peb-banner slds-m-vertical_small slds-p-around_x-small ';
        return base + (this.isBannerSuccess ? 'peb-banner_success' : 'peb-banner_warning');
    }

    get bannerIcon() {
        return this.isBannerSuccess ? 'utility:success' : 'utility:info';
    }

    get bannerMessage() {
        if (this.hasEstimationFile && this.estimationReadable) {
            return `Section weights were pre-filled from "${this.estimationFileName}". Please verify each Total Weight before calculating.`;
        }
        if (this.hasEstimationFile) {
            return `Found "${this.estimationFileName}", but its text could not be read automatically (scanned or compressed PDF). Enter each section Total Weight manually from the estimation.`;
        }
        return 'No "Design Estimation.pdf" was found on this Opportunity. Enter each section Total Weight manually, or upload the file and reopen the calculator.';
    }
    // delivery option
    get deliveryTermOptions() {
        return DELIVERY_TERM_OPTIONS;
    }

    get isExWorks() {
        return this.deliveryTerm === 'ExWorks';
    }

    /* =================== client-side estimation reader =====================

       The Apex controller reads the Design Estimation.pdf server-side. That only
       works when the PDF stores its text uncompressed; every compressed/scanned
       file comes back with estimationReadable = false. This reader opens the
       SAME file in the browser with pdf.js (v2.5.207, main-thread mode so it
       survives Lightning Web Security) and produces the SAME totals map the
       Apex would have returned, then pre-fills Section A through SECTION_A_MAP.
       Values remain editable so the user still verifies before calculating.
    ======================================================================= */

    async connectedCallback() {
        try {
            // Load library + worker as plain scripts WITHOUT setting
            // GlobalWorkerOptions.workerSrc. This keeps pdf.js on the main thread
            // and avoids postMessage/structuredClone, which throws DataCloneError
            // under Lightning Web Security. Requires pdf.js 2.5.207 (<= 2.13.216).
            await loadScript(this, PDF_JS_ZIP + '/build/pdf.js');
            await loadScript(this, PDF_JS_ZIP + '/build/pdf.worker.js');
            this.pdfjsReady = true;
        } catch (e) {
            // Reader unavailable - manual entry still works, so fail quietly.
            this.pdfjsReady = false;
        }
        // Auto-open straight into the calculator when a saved calculation already
        // exists, so reopening this component shows last-saved values instead of
        // the explainer screen. Brand-new records with nothing saved still land
        // on the "Start Price Calculation" screen as before.
        if (this.isChildMode) {
            if (this.savedPayload) {
                this.loading = true;
                try {
                    await this.initCalculator();
                } catch (e) {
                    this.toast('Error', this.errMsg(e), 'error');
                } finally {
                    this.loading = false;
                }
            }
            return;
        }

        if (this.recordId) {
            this.loading = true;
            try {
                const data = await getCalculatorData({ opportunityId: this.recordId });
                this._prefetchedData = data;
                if (data.savedJson) {
                    await this.initCalculator(data);
                    this._prefetchedData = null;
                }
            } catch (e) {
                // Silent - landing screen still shows, manual Start re-fetches.
            } finally {
                this.loading = false;
            }
        }
    }

    async handleEstimationRead(event) {
        if (!this.pdfjsReady) {
            this.toast('Reader not ready', 'The PDF reader is still loading; try again in a moment.', 'warning');
            return;
        }
        const file = event.target.files && event.target.files[0];
        if (!file) {
            return;
        }
        try {
            const buffer = await file.arrayBuffer();
            const parsed = await this.extractFromBytes(new Uint8Array(buffer));
            this.applyExtracted(parsed);
            this.estimationFileName = file.name;
            this.hasEstimationFile = true;
            this.estimationReadable = true; // flips the banner to the "verify" state
            this.reportExtraction(parsed, file.name);
        } catch (e) {
            this.toast('Could not read PDF', `${this.errMsg(e)} - you can still enter the values manually.`, 'error');
        }
    }

    /** Runs extraction using pebEstimationParser on raw bytes and returns structured estimation result. */
    async extractFromBytes(uint8) {
        try {
            return await parseEstimationPdf(uint8);
        } catch (e) {
            console.warn('pebEstimationParser fallback:', e);
            const pdf = await window.pdfjsLib.getDocument({ data: uint8 }).promise;
            const words = [];
            for (let n = 1; n <= pdf.numPages; n++) {
                const page = await pdf.getPage(n);
                const viewport = page.getViewport({ scale: 1 });
                const tc = await page.getTextContent();
                for (const it of tc.items) {
                    const str = (it.str || '').replace(/\s+/g, ' ').trim();
                    if (!str) {
                        continue;
                    }
                    words.push({
                        x: it.transform[4],
                        top: viewport.height - it.transform[5],
                        str
                    });
                }
            }
            return this.extractFromWords(words);
        }
    }

    // new change
    async initCalculator(prefetched) {
        const data = prefetched || (await getCalculatorData({ opportunityId: this.recordId }));
        this.rateConfig = JSON.parse(data.rateConfigJson);
        this.gstPercent = data.gstPercent != null ? data.gstPercent : 18;
        if (this.rateConfig && this.rateConfig.benchmarkRate != null) {
            this.benchmarkRate = this.toNum(this.rateConfig.benchmarkRate);
        }
        this.estimationFileName = data.estimationFileName;
        this.estimationReadable = !!data.estimationReadable;
        this.hasEstimationFile = !!data.estimationFileName;

        this.buildFreshRows(data.sectionTotals || {});
        if (Array.isArray(data.specialItems) && data.specialItems.length) {
            this.specialItems = data.specialItems.map((s) =>
                this.mkSpecialItem(s.description, s.unit, s.qty, 0, 0)
            );
        }

        this.hasSavedCalculation = false;
        if (this.isChildMode) {
            // When opened from Create Quote (child mode), only hydrate if this specific quote already
            // has a saved payload. When creating a brand-new quote, savedPayload is null/empty,
            // so we start completely fresh from the PDF and NEVER fall back to Opportunity.Price_Calculation_JSON__c.
            if (this.savedPayload) {
                try {
                    this.hydrateFromSaved(this.savedPayload);
                    this.hasSavedCalculation = true;
                } catch (e) {
                    // ignore malformed saved state and keep fresh rows
                }
            }
        } else if (data.savedJson) {
            // Opportunity.Price_Calculation_JSON__c is only used when opening the calculator
            // directly as a tab on the Opportunity record page.
            try {
                this.hydrateFromSaved(JSON.parse(data.savedJson));
                this.hasSavedCalculation = true;
            } catch (e) {
                // ignore malformed saved state and keep fresh rows
            }
        }

        this.recompute();

        const willAutoRead = this.hasEstimationFile && !this.estimationReadable;
        this.autoReading = willAutoRead;
        this.started = true;

        if (willAutoRead) {
            this.autoReadEstimation();
        }
    }

    /**
     * Dynamically determines column bounds by finding the table header row
     * ("Sr.No.", "Description", "Qty", "Unit", "Unit weight", "Total weight").
     * Falls back to COL if no header row is recognized.
     */
    detectColumns(words) {
        const sorted = [...words].sort((a, b) => a.top - b.top || a.x - b.x);
        const rows = [];
        let cur = null;
        for (const w of sorted) {
            if (!cur || Math.abs(w.top - cur.top) > ROW_TOL) {
                cur = { top: w.top, items: [] };
                rows.push(cur);
            }
            cur.items.push(w);
        }

        let headerRow = null;
        for (const r of rows) {
            const text = r.items.map((i) => i.str).join(' ').toLowerCase();
            if (text.includes('description') && (text.includes('total') || text.includes('qty') || text.includes('sr'))) {
                headerRow = r;
                break;
            }
        }

        if (!headerRow) {
            return COL;
        }

        const items = headerRow.items;
        const findItem = (re) => items.find((i) => re.test(i.str));
        const srItem = findItem(/^sr/i);
        const descItem = findItem(/^desc/i);
        const qtyItem = findItem(/^qty/i);
        const unitWtItem = findItem(/unit\s*weight/i);
        const unitItem = items.find((i) => /^unit\b/i.test(i.str) && !/weight/i.test(i.str));
        const totalItem = findItem(/total/i);

        const srEnd = srItem ? Math.min(90, srItem.x + 20) : 78;

        let totalStart = 340;
        if (totalItem) {
            const prev = unitWtItem || unitItem || qtyItem;
            totalStart = prev ? (prev.x + totalItem.x) / 2 : totalItem.x - 30;
        }

        let qtyStart = 230;
        let qtyEnd = 280;
        let unitStart = 280;
        let unitEnd = 310;
        let unitWtStart = 310;

        if (qtyItem) {
            qtyStart = Math.max(srEnd + 50, qtyItem.x - 20);
        }
        const descEnd = qtyItem ? qtyStart : (totalItem ? totalItem.x - 50 : 230);

        if (qtyItem && unitItem) {
            const mid = (qtyItem.x + unitItem.x) / 2;
            qtyEnd = mid;
            unitStart = mid;
        }
        if (unitItem && unitWtItem) {
            const mid = (unitItem.x + unitWtItem.x) / 2;
            unitEnd = mid;
            unitWtStart = mid;
        } else if (unitItem && totalItem) {
            const mid = (unitItem.x + totalItem.x) / 2;
            unitEnd = mid;
        }

        return {
            SR: [0, srEnd],
            DESC: [srEnd, descEnd],
            QTY: [qtyStart, qtyEnd],
            UNIT: [unitStart, unitEnd],
            UNIT_WT: [unitWtStart, totalStart],
            TOTAL: [totalStart, 9999]
        };
    }

    /**
     * Coordinate-aware extraction for the estimation layout (handles both landscape
     * and portrait formats dynamically).
     *
     * Every row is grouped by vertical position, then read column by column:
     *   - a single letter in the Sr.No band starts a new section
     *   - a section's value is the number in the Total-weight band (falling back
     *     to the Qty band, which is where an area-based section may print it)
     *   - Section C keeps the itemised handling:
     *       C1    = the Anchor-bolts line value
     *       CRest = hardware connection bolts (TOTAL - C1, or TOTAL directly if <= C1)
     *   - Notes/accessories are ignored from section raw material totals
     */
    extractFromWords(words) {
        const col = this.detectColumns(words);
        const rows = this.groupRows(words);

        const sections = [];
        let inNotesOrAccessories = false;

        for (const row of rows) {
            const rowText = row.items.map((i) => i.str).join(' ').trim();
            // Ignore notes and accessories sections from PDF (stop accumulating into section rows)
            if (/^(note[s]?|accessories)\b/i.test(rowText)) {
                inNotesOrAccessories = true;
                continue;
            }
            if (inNotesOrAccessories) {
                continue;
            }
            const desc = this.textIn(row, col.DESC);
            const letter = this.sectionLetter(row, col);
            if (letter) {
                sections.push({
                    letter,
                    desc,
                    value: this.valueOf(row, col),
                    rows: []
                });
            } else if (sections.length) {
                sections[sections.length - 1].rows.push(row);
            }
        }

        const totals = {};
        TOTAL_KEYS.forEach((k) => {
            totals[k] = 0;
        });

        for (const sec of sections) {
            const match = SECTION_MATCHERS.find((m) => m.re.test(sec.desc)) ||
                SECTION_MATCHERS.find((m) => m.key === sec.letter.toUpperCase());
            if (!match) {
                continue;
            }
            if (match.key === 'HW') {
                const hw = this.hardwareTotals(sec, col);
                totals.C1 = hw.c1;
                totals.CRest = hw.rest;
            } else if (sec.value !== null) {
                totals[match.key] = sec.value;
            }
        }

        return { totals, specialItems: [] };
    }

    /** Groups words into visual rows by their vertical position. */
    groupRows(words) {
        const rows = [];
        const sorted = [...words].sort((a, b) => a.top - b.top || a.x - b.x);
        let cur = null;
        for (const w of sorted) {
            if (!cur || Math.abs(w.top - cur.top) > ROW_TOL) {
                cur = { top: w.top, items: [] };
                rows.push(cur);
            }
            cur.items.push(w);
        }
        return rows;
    }

    /** Concatenated text of the items falling inside an x band. */
    textIn(row, band) {
        return row.items
            .filter((i) => i.x >= band[0] && i.x < band[1])
            .sort((a, b) => a.x - b.x)
            .map((i) => i.str)
            .join(' ')
            .replace(/\s+/g, ' ')
            .trim();
    }

    /** First (or last) numeric token inside an x band, or null. */
    numAt(row, band, pickLast = false) {
        const hits = row.items
            .filter((i) => i.x >= band[0] && i.x < band[1] && /^[0-9][0-9,.]*$/.test(i.str))
            .sort((a, b) => a.x - b.x);
        
        if (hits.length === 0) {
            return null;
        }
        
        const hit = pickLast ? hits[hits.length - 1] : hits[0];
        return this.parseNum(hit.str);
    }

    parseNum(s) {
        const n = parseFloat(String(s).replace(/,/g, ''));
        return isNaN(n) ? null : n;
    }

    /** A row's value: Rightmost number in Total-weight column, else the Qty column. */
    valueOf(row, col = COL) {
        // Always pick the rightmost number in the TOTAL band to ensure we get the Total Weight
        const t = this.numAt(row, col.TOTAL, true);
        return t !== null ? t : this.numAt(row, col.QTY, true);
    }

    /** Returns the section letter when the row opens a new section. */
    sectionLetter(row, col = COL) {
        const hit = row.items.find((i) => i.x >= col.SR[0] && i.x < col.SR[1] && /^[A-Za-z]$/.test(i.str));
        return hit ? hit.str : null;
    }

    /**
     * Section C: C1 is the Anchor-bolts line, CRest is the remainder of the
     * hardware TOTAL (or TOTAL directly when TOTAL only represents connection bolts).
     */
    hardwareTotals(sec, col = COL) {
        let c1 = null;
        let total = null;
        let sumNonC1 = 0;
        let sumNonC1Seen = false;

        for (const row of sec.rows) {
            const desc = this.textIn(row, col.DESC).toLowerCase();
            const val = this.valueOf(row, col);
            if (/total/.test(desc)) {
                if (total === null && val !== null) {
                    total = val;
                }
                continue;
            }
            const isAnchor = desc.indexOf('anchor') >= 0 && desc.indexOf('bolt') >= 0 && desc.indexOf('non-standard') < 0;
            if (isAnchor && c1 === null) {
                c1 = val;
            } else if (val !== null) {
                sumNonC1 += val;
                sumNonC1Seen = true;
            }
        }

        // If no explicit TOTAL row, use the sum of connection bolts or the section value
        const c1v = c1 === null ? 0 : c1;
        let rest = 0;
        if (total !== null) {
            if (total > c1v) {
                rest = total - c1v;
            } else {
                // When document TOTAL row is <= c1, the document's TOTAL represents ONLY connection bolts
                rest = total;
            }
        } else if (sumNonC1Seen) {
            rest = sumNonC1;
        } else if (sec.value !== null) {
            rest = sec.value > c1v ? sec.value - c1v : sec.value;
        }

        return { c1: c1v, rest: rest > 0 ? rest : 0 };
    }

    /**
     * Builds a B3 Special Item from a row under the Note heading.
     * Description, unit and weight come from the document; the rate is entered
     * on screen.
     */
    toSpecialItem(row, col = COL) {
        // Note rows often print the serial and the description as one token that
        // starts left of the Description column ("1Example"), so read everything
        // to the left of the Qty column as the description.
        let description = this.textIn(row, [col.SR[0], col.QTY[0]]);
        if (!description) {
            return null;
        }
        // "1Example 1" / "1 Example 1" -> drop the leading serial number.
        description = description.replace(/^\s*[0-9]{1,3}[.)]?\s*/, '').trim();
        if (!description) {
            return null;
        }

        let qty = this.valueOf(row, col);
        let unit = this.normaliseUnit(this.textIn(row, col.UNIT));

        // Inline fallback: "... @ 360m"
        if (qty === null) {
            const m = /@\s*([0-9][0-9,.]*)\s*([a-zA-Z.]*)/.exec(description);
            if (m) {
                qty = this.parseNum(m[1]);
                unit = this.normaliseUnit(m[2]);
                description = (description.slice(0, m.index) + ' ' + description.slice(m.index + m[0].length))
                    .replace(/\s+/g, ' ')
                    .trim();
            }
        }

        return { description, unit, qty: this.toNum(qty) };
    }

    /** Maps a raw unit token onto the calculator's picklist values. */
    normaliseUnit(raw) {
        const u = (raw || '').toLowerCase().replace(/[^a-z]/g, '');
        if (!u) {
            return 'No.s';
        }
        if (['sqm', 'sqmt', 'sqmtr', 'm2', 'sq'].indexOf(u) >= 0) {
            return 'Sq.M';
        }
        if (['kg', 'kgs'].indexOf(u) >= 0) {
            return 'Kg';
        }
        if (['m', 'mt', 'mtr', 'mtrs', 'rm', 'rmt', 'metre', 'meter'].indexOf(u) >= 0) {
            return 'Mtr';
        }
        if (['ltr', 'l', 'litre', 'liter'].indexOf(u) >= 0) {
            return 'Ltr';
        }
        return 'No.s';
    }

    /**
     * Overlays extracted values onto Section A and B3. When a saved calculation
     * was rehydrated, only empty values are filled so manual edits survive a
     * re-open.
     */
    applyExtracted(parsed) {
        const totals = (parsed && parsed.totals) || {};
        const keepSaved = this.hasSavedCalculation;

        this.sectionA = this.sectionA.map((r) => {
            const m = SECTION_A_MAP.find((x) => x.key === r.key);
            if (!m || !m.totalKey) {
                return r;
            }
            const t = totals[m.totalKey];
            if (t === undefined || t === null) {
                return r;
            }
            if (keepSaved && this.toNum(r.totalWeight) > 0) {
                return r; // don't clobber a saved / edited weight
            }
            return { ...r, totalWeight: this.toNum(t) };
        });

        const found = (parsed && parsed.specialItems) || [];
        if (found.length && !(keepSaved && this.specialItems.length)) {
            this.specialItems = found.map((s) => this.mkSpecialItem(s.description, s.unit, s.qty, 0, 0));
        }

        this.recompute();
    }

    /** Toast summarising what the reader managed to pre-fill. */
    reportExtraction(parsed, fileName) {
        const totals = (parsed && parsed.totals) || {};
        const filled = TOTAL_KEYS.filter((k) => this.toNum(totals[k]) > 0).length;
        const notes = ((parsed && parsed.specialItems) || []).length;
        if (filled === 0 && notes === 0) {
            return;
        }
        const noteText = notes ? ` ${notes} Note item(s) added to B3 - enter their rates.` : '';
        this.toast(
            'Estimation read',
            `${filled} of ${TOTAL_KEYS.length} section values pre-filled from "${fileName}". Please verify each Total Weight before calculating.${noteText}`,
            'success'
        );
    }

    /* =================== lifecycle =================== */
    async handleStart() {
        this.loading = true;
        try {
            await this.initCalculator(this._prefetchedData);
            this._prefetchedData = null;
        } catch (error) {
            this.toast('Error', this.errMsg(error), 'error');
        } finally {
            this.loading = false;
        }
    }

    /**
     * Fetches the already-attached Design Estimation.pdf bytes from Apex and runs
     * the same client-side extraction, so the user never has to re-pick the file.
     * pdf.js may still be loading when handleStart finishes, so this waits
     * briefly for it before falling back to the manual picker.
     */
    async autoReadEstimation() {
        this.autoReading = true;
        this.startReadProgress();
        try {
            const ready = await this.waitForPdfjs();
            if (!ready) {
                return; // reader unavailable; manual picker/entry remains
            }
            const base64 = await getEstimationFileBase64({ opportunityId: this.recordId });
            if (!base64) {
                return; // no file bytes; manual picker/entry remains
            }
            const parsed = await this.extractFromBytes(this.base64ToUint8Array(base64));
            this.applyExtracted(parsed);
            this.estimationReadable = true;
            this.reportExtraction(parsed, this.estimationFileName);

            try {
                const bdBase64 = await getBuildingDescriptionFileBase64({ opportunityId: this.recordId, quoteId: this.quoteId });
                if (bdBase64) {
                    this._buildingDescription = await parseUniversalBuildingPdf(this.base64ToUint8Array(bdBase64));
                }
            } catch (err) {
                console.warn('Auto-reading building description failed:', err);
            }
        } catch (e) {
            // Silent: the manual picker (showEstimationFallback) stays available.
        } finally {
            this.finishReadProgress();
            this.autoReading = false;
        }
    }

    /* Progress-bar animation for the estimation read (fills toward 90% while
       working, then completes). Uses lightning-progress-bar - no custom CSS. */
    startReadProgress() {
        this.readProgress = 8;
        this.clearProgressTimer();
        this._progressTimer = setInterval(() => {
            if (this.readProgress < 90) {
                this.readProgress = Math.min(90, this.readProgress + 7);
            }
        }, 150);
    }

    finishReadProgress() {
        this.clearProgressTimer();
        this.readProgress = 100;
    }

    clearProgressTimer() {
        if (this._progressTimer) {
            clearInterval(this._progressTimer);
            this._progressTimer = null;
        }
    }

    disconnectedCallback() {
        this.clearProgressTimer();
    }

    /** Resolves true once pdf.js is loaded, or false after a short timeout. */
    waitForPdfjs(timeoutMs = 4000) {
        if (this.pdfjsReady) {
            return Promise.resolve(true);
        }
        return new Promise((resolve) => {
            const step = 100;
            let waited = 0;
            const timer = setInterval(() => {
                if (this.pdfjsReady) {
                    clearInterval(timer);
                    resolve(true);
                } else if ((waited += step) >= timeoutMs) {
                    clearInterval(timer);
                    resolve(false);
                }
            }, step);
        });
    }

    base64ToUint8Array(base64) {
        const binary = atob(base64);
        const bytes = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i++) {
            bytes[i] = binary.charCodeAt(i);
        }
        return bytes;
    }

    handleClose() {
        this.started = false;
    }

    buildFreshRows(totals) {
        const cfgA = this.rateConfig.sectionA || {};
        this.sectionA = SECTION_A_MAP.filter((m) => cfgA[m.key]).map((m) => {
            const cfg = cfgA[m.key];
            return {
                key: m.key,
                slNo: m.slNo,
                description: cfg.label,
                unit: cfg.unit,
                rate: cfg.rate,
                totalWeight: m.totalKey ? this.toNum(totals[m.totalKey]) : 0,
                additionalWeight: 0,
                reason: '',
                totalCalcWeight: 0,
                cost: 0,
                reasonRequired: false
            };
        });

        const cfgC = this.rateConfig.conversion || {};
        this.conversion = CONVERSION_KEYS.filter((key) => cfgC[key]).map((key) => {
            const cfg = cfgC[key];
            return {
                key,
                description: cfg.label,
                unit: cfg.unit,
                rate: cfg.rate,
                selected: false,
                weight: 0,
                cost: 0
            };
        });

        this.otherCost = OTHER_COST_ROWS.map((r) => ({
            key: r.key,
            description: r.description,
            unit: 'No.s',
            qty: 0,
            rate: 0,
            cost: 0
        }));

        this.variableCost = VARIABLE_COST_ROWS.map((r) => ({
            key: r.key,
            description: r.description,
            cost: 0
        }));

        this.accessories = [];
        this.buyouts = [];
        this.specialItems = [];
    }

    hydrateFromSaved(saved) {
        if (saved && saved._buildingDescription) {
            this._buildingDescription = saved._buildingDescription;
        }
        const s = saved._state;
        if (!s) {
            return;
        }
        if (s.marginPercent != null) {
            this.marginPercent = s.marginPercent;
        }
        if (s.gstPercent != null) {
            this.gstPercent = s.gstPercent;
        }
        if (s.benchmarkRate != null) {
            this.benchmarkRate = this.toNum(s.benchmarkRate);
        }
        if (s.paymentTerms) {
            this.consignmentPeriod = s.paymentTerms.consignmentPeriod || '';
            //this.erectionPeriod = s.paymentTerms.erectionPeriod || '';
            this.offerValidity = s.paymentTerms.validity || '';
        }
        if (s.transportation) {
            this.deliveryTerm = s.transportation.deliveryTerm || 'FOR';
            this.transportationValue = this.toNum(s.transportation.value);
        }
        // Section A overlay
        if (Array.isArray(s.sectionA)) {
            this.sectionA = this.sectionA.map((r) => {
                const saveRow = s.sectionA.find((x) => x.key === r.key);
                return saveRow
                    ? {
                          ...r,
                          totalWeight: this.toNum(saveRow.totalWeight),
                          additionalWeight: this.toNum(saveRow.additionalWeight),
                          reason: saveRow.reason || ''
                      }
                    : r;
            });
        }
        // Accessories / Buyouts / Special items rebuild
        if (Array.isArray(s.accessories)) {
            this.accessories = s.accessories
                .filter((x) => this.rateConfig.accessories[x.key])
                .map((x) => this.mkAccessory(x.key, x.qty, x.unitWt));
        }
        if (Array.isArray(s.buyouts)) {
            this.buyouts = s.buyouts
                .filter((x) => this.rateConfig.buyouts[x.key])
                .map((x) => this.mkBuyout(x.key, x.qty, x.unitWt, x.rate));
        }
        if (Array.isArray(s.specialItems)) {
            this.specialItems = s.specialItems.map((x) =>
                this.mkSpecialItem(x.description, x.unit, x.qty, x.rate, x.unitWt)
            );
        }
        // Conversion selections
        if (Array.isArray(s.conversion)) {
            this.conversion = this.conversion.map((r) => {
                const sv = s.conversion.find((x) => x.key === r.key);
                return sv ? { ...r, selected: !!sv.selected } : r;
            });
        }
        // Other cost
        if (Array.isArray(s.otherCost)) {
            this.otherCost = this.otherCost.map((r) => {
                const sv = s.otherCost.find((x) => x.key === r.key);
                return sv
                    ? { ...r, unit: sv.unit || r.unit, qty: this.toNum(sv.qty), rate: this.toNum(sv.rate) }
                    : r;
            });
        }
        // Variable cost
        if (Array.isArray(s.variableCost)) {
            this.variableCost = this.variableCost.map((r) => {
                const sv = s.variableCost.find((x) => x.key === r.key);
                return sv ? { ...r, cost: this.toNum(sv.cost) } : r;
            });
        }
    }

    mkAccessory(key, qty, unitWt) {
        const cfg = this.rateConfig.accessories[key];
        // Accessories are normally weighed by hand (Unit Wt. typed in), but a
        // few items - e.g. the Rain Water Down Spout sizes - have a fixed
        // Unit Wt. defined on the rate config itself, same as Buyouts. When
        // present, that value always wins and the field is locked in the UI.
        const hasFixedUnitWt = cfg.unitWt != null;
        return {
            rowId: 'acc-' + this.rowSeq++,
            key,
            description: cfg.label,
            unit: cfg.unit,
            qty: this.toNum(qty),
            unitWt: hasFixedUnitWt ? this.toNum(cfg.unitWt) : this.toNum(unitWt),
            rate: cfg.rate,
            totalWeight: 0,
            cost: 0,
            fixedUnitWt: hasFixedUnitWt
        };
    }

    mkBuyout(key, qty) {
    const cfg = this.rateConfig.buyouts[key];
    return {
        rowId: 'buy-' + this.rowSeq++,
        key,
        description: cfg.label,
        unit: cfg.unit,
        qty: this.toNum(qty),
        unitWt: this.toNum(cfg.unitWt),
        rate: this.toNum(cfg.rate),
        totalWeight: 0,
        cost: 0
    };
}

    /** B3 row: description/unit/qty come from the Note section, rate is manual. */
    mkSpecialItem(description, unit, qty, rate, unitWt) {
        return {
            rowId: 'spc-' + this.rowSeq++,
            description: description || '',
            unit: unit || 'No.s',
            qty: this.toNum(qty),
            unitWt: this.toNum(unitWt),
            totalWeight: 0,
            rate: this.toNum(rate),
            cost: 0
        };
    }

    /* =================== recompute engine =================== */
    recompute() {
        let secAWeight = 0;
        let secACost = 0;
        let builtUpW = 0;
        let coldFormW = 0;
        let hotRolledW = 0;
        let galvRoofW = 0;
        let galvWallW = 0;

        this.sectionA = this.sectionA.map((r) => {
            const add = this.toNum(r.additionalWeight);
            const tcw = this.toNum(r.totalWeight) + add;
            const cost = tcw * this.toNum(r.rate);
            const required = add > 0;
            secAWeight += tcw;
            secACost += cost;
            if (r.key === 'builtUp') builtUpW = tcw;
            if (r.key === 'coldForm') coldFormW = tcw;
            if (r.key === 'hotRolled') hotRolledW = tcw;
            if (r.key === 'galvalumeRoof') galvRoofW = tcw;
            if (r.key === 'galvalumeWall') galvWallW = tcw;
            return { ...r, totalCalcWeight: tcw, cost, reasonRequired: required };
        });

        let accW = 0;
        let accCost = 0;
        this.accessories = this.accessories.map((r) => {
            const tw = this.toNum(r.qty) * this.toNum(r.unitWt);
            const cost = this.toNum(r.qty) * this.toNum(r.rate);
            accW += tw;
            accCost += cost;
            return { ...r, totalWeight: tw, cost };
        });

        let buyW = 0;
        let buyCost = 0;
        this.buyouts = this.buyouts.map((r) => {
            const tw = this.toNum(r.qty) * this.toNum(r.unitWt);
            const cost = this.toNum(r.qty) * this.toNum(r.rate);
            buyW += tw;
            buyCost += cost;
            return { ...r, totalWeight: tw, cost };
        });

        // B3 Special Items - qty comes from the document, rate from the screen.
        let specCost = 0;
        let specWeight = 0; 
        this.specialItems = this.specialItems.map((r) => {
            const tw = this.toNum(r.qty) * this.toNum(r.unitWt);
            const cost = this.toNum(r.qty) * this.toNum(r.rate);
            specCost += cost;
            specWeight += tw;
            return { ...r, totalWeight: tw, cost };
        });

        // Conversion weights (per spec formulas)
        const shotW = builtUpW + hotRolledW;
        const base = (shotW / 1000) * 6;
        const weightByKey = {
            shotBlasting: shotW,
            primer: Math.round(base),
            intermediateCoat: Math.round(base), // same basis as the primer coat
            finalPaint: Math.round(base * 2),
            fabricationBuiltUpHR: builtUpW + hotRolledW,
            profilingColdForm: coldFormW,
            profilingGalvalume: galvRoofW + galvWallW,
            design: secAWeight + accW + buyW
        };

        let convCost = 0;
        this.conversion = this.conversion.map((r) => {
            const w = weightByKey[r.key] || 0;
            const cost = r.selected ? w * this.toNum(r.rate) : 0;
            if (r.selected) convCost += cost;
            return { ...r, weight: w, cost };
        });

        let otherTot = 0;
        
        this.otherCost = this.otherCost.map((r) => {
            const cost = this.toNum(r.qty) * this.toNum(r.rate);
            otherTot += cost;
            
            return { ...r, cost };
        });

        const transportationCost = this.deliveryTerm === 'FOR' ? this.toNum(this.transportationValue) : 0;

        let varTot = 0;
        this.variableCost.forEach((r) => {
            varTot += this.toNum(r.cost);
        });

        const sectionBCost = accCost + buyCost + specCost;
        const directCost = secACost + sectionBCost + convCost + otherTot;
        const projectCost = directCost + varTot;
        const mPct = this.toNum(this.marginPercent);
        const marginRs = (projectCost * mPct) / 100;
        const withMargin = projectCost + marginRs;
        const gPct = this.toNum(this.gstPercent);
        const gstRs = (withMargin * gPct) / 100;
        // ── APPROVAL GUARD (A + B1 + B2 weight benchmark) ──
        const bRate = (this.benchmarkRate != null && this.benchmarkRate > 0)
            ? this.toNum(this.benchmarkRate)
            : ((this.rateConfig && this.rateConfig.benchmarkRate != null) ? this.toNum(this.rateConfig.benchmarkRate) : 90);
        this.benchmarkRate = bRate;
        const totalWeightAll = Math.round((secAWeight + accW + buyW) * 100) / 100;
        const totalPriceCalc = Math.round(totalWeightAll * bRate);
        const needsUtkarshApproval = withMargin < totalPriceCalc;

        this.totals = {
            sectionATotalWeight: secAWeight,
            sectionATotalCost: secACost,
            accessoriesTotalWeight: accW,  
            accessoriesTotalCost: accCost,
            buyoutsTotalWeight: buyW, 
            buyoutsTotalCost: buyCost,
            specialItemsTotalWeight: specWeight,
            specialItemsTotalCost: specCost,
            sectionBTotalCost: sectionBCost,
            conversionTotalCost: convCost,
            otherCostTotal: otherTot,
            transportationCost,
            deliveryTerm: this.deliveryTerm,
            variableCostTotal: varTot,
            //peb_hasErectionOrSheeting: hasErectionOrSheeting,
            totalDirectCost: directCost,
            totalProjectCost: projectCost,
            marginPercent: mPct,
            marginRs,
            totalWithMargin: withMargin,
            gstPercent: gPct,
            gstRs,
            totalWeightAll,
            benchmarkRate: bRate,
            totalPriceCalc,
            needsUtkarshApproval,
            grandTotal: withMargin + gstRs
        };
    }

    /* =================== handlers =================== */
    handleSectionAChange(event) {
        const { key, field } = event.target.dataset;
        let value = event.target.value;
        if (field !== 'reason') {
            value = this.nonNeg(value);
        }
        this.sectionA = this.sectionA.map((r) => (r.key === key ? { ...r, [field]: value } : r));
        this.recompute();
    }

    handleAccessoryTypeChange(event) {
        this.selectedAccessoryType = event.detail.value;
    }

    handleAddAccessory() {
        if (!this.selectedAccessoryType) {
            this.toast('Select an accessory', 'Choose an accessory type to add.', 'warning');
            return;
        }
        this.accessories = [...this.accessories, this.mkAccessory(this.selectedAccessoryType, 0, 0)];
        this.recompute();
    }

    handleAccessoryChange(event) {
        const { id, field } = event.target.dataset;
        const value = field === 'unit' ? event.detail.value : this.nonNeg(event.target.value);
        this.accessories = this.accessories.map((r) => {
            if (r.rowId !== id) return r;
            if (field === 'unitWt' && r.fixedUnitWt) return r; // locked - config value only
            return { ...r, [field]: value };
        });
        this.recompute();
    }

    handleRemoveAccessory(event) {
        const id = event.target.dataset.id;
        this.accessories = this.accessories.filter((r) => r.rowId !== id);
        this.recompute();
    }

    handleBuyoutTypeChange(event) {
        this.selectedBuyoutType = event.detail.value;
    }

    handleAddBuyout() {
        if (!this.selectedBuyoutType) {
            this.toast('Select a buyout', 'Choose a buyout type to add.', 'warning');
            return;
        }
        this.buyouts = [...this.buyouts, this.mkBuyout(this.selectedBuyoutType, 0, 0, 0)];
        this.recompute();
    }

    handleBuyoutChange(event) {
        const { id, field } = event.target.dataset;
        //const value = field === 'unit' ? event.detail.value : this.nonNeg(event.target.value);
        const value = this.nonNeg(event.target.value); // only 'qty' and 'rate' can reach here now
        this.buyouts = this.buyouts.map((r) => (r.rowId === id ? { ...r, [field]: value } : r));
        this.recompute();
    }

    handleRemoveBuyout(event) {
        const id = event.target.dataset.id;
        this.buyouts = this.buyouts.filter((r) => r.rowId !== id);
        this.recompute();
    }

    handleAddSpecialItem() {
        this.specialItems = [...this.specialItems, this.mkSpecialItem('', 'No.s', 0, 0, 0)];
        this.recompute();
    }

    handleSpecialChange(event) {
        const { id, field } = event.target.dataset;
        let value;
        if (field === 'unit') {
            value = event.detail.value;
        } else if (field === 'description') {
            value = event.target.value;
        } else {
            value = this.nonNeg(event.target.value);
        }
        this.specialItems = this.specialItems.map((r) => (r.rowId === id ? { ...r, [field]: value } : r));
        this.recompute();
    }

    handleRemoveSpecialItem(event) {
        const id = event.target.dataset.id;
        this.specialItems = this.specialItems.filter((r) => r.rowId !== id);
        this.recompute();
    }

    handleConversionToggle(event) {
        const key = event.target.dataset.key;
        const selected = event.target.checked;
        this.conversion = this.conversion.map((r) => (r.key === key ? { ...r, selected } : r));
        this.recompute();
    }

    handleOtherChange(event) {
        const { key, field } = event.target.dataset;
        const value = field === 'unit' ? event.detail.value : this.nonNeg(event.target.value);
        this.otherCost = this.otherCost.map((r) => (r.key === key ? { ...r, [field]: value } : r));
        this.recompute();
    }

    handleVariableChange(event) {
        const key = event.target.dataset.key;
        const value = this.nonNeg(event.target.value);
        this.variableCost = this.variableCost.map((r) => (r.key === key ? { ...r, cost: value } : r));
        this.recompute();
    }

    handleMarginChange(event) {
        this.marginPercent = this.nonNeg(event.target.value);
        this.recompute();
    }

    handleGstChange(event) {
        this.gstPercent = this.nonNeg(event.target.value);
        this.recompute();
    }

    // Free text only - deliberately does NOT call recompute(), so typing a
    // period can never disturb a figure in the Summary box next to it.
    handlePaymentTermChange(event) {
        const field = event.target.dataset.field;
        if (field) {
            this[field] = event.target.value;
        }
        if (typeof event.target.reportValidity === 'function') {
            event.target.reportValidity();
        }
    }

    // delivery option
    handleDeliveryTermChange(event) {
        this.deliveryTerm = event.detail.value;
        this.recompute();
    }

    handleTransportationValueChange(event) {
        this.transportationValue = this.nonNeg(event.target.value);
        this.recompute();
    }

    /* =================== save / pdf =================== */
    async handleSave() {
        if (!this.validate()) {
            return;
        }
        this.saving = true;
        try {
            await saveCalculation({ opportunityId: this.recordId, payload: JSON.stringify(this.buildPayload()) });
            this.toast('Saved', 'Price calculation saved to the Opportunity.', 'success');
        } catch (error) {
            this.toast('Error', this.errMsg(error), 'error');
        } finally {
            this.saving = false;
        }
    }

    async handleDownloadPdf() {
        if (!this.validate()) {
            return;
        }
        this.saving = true;
        try {
            await saveCalculation({ opportunityId: this.recordId, payload: JSON.stringify(this.buildPayload()) });
            const base64 = await generatePdf({ opportunityId: this.recordId });
            this.downloadBase64Pdf(base64, 'PriceCalculation.pdf');
            this.toast('PDF ready', 'The Price Calculation PDF has been downloaded.', 'success');
        } catch (error) {
            this.toast('Error', this.errMsg(error), 'error');
        } finally {
            this.saving = false;
        }
    }

    downloadBase64Pdf(base64, filename) {
        const binary = atob(base64);
        const bytes = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i++) {
            bytes[i] = binary.charCodeAt(i);
        }
        const blob = new Blob([bytes], { type: 'application/pdf' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = filename;
        link.click();
        URL.revokeObjectURL(url);
    }

    validate() {
        let ok = true;
        this.template.querySelectorAll('lightning-input, lightning-combobox').forEach((el) => {
            if (typeof el.reportValidity === 'function' && !el.reportValidity()) {
                ok = false;
            }
        });
        if (!ok) {
            this.toast(
                'Check the highlighted fields',
                'A reason is required whenever an Additional Weight is entered, and all values must be zero or positive.',
                'warning'
            );
            return false;
        }
        // B3 rates are entered manually, so a priced special item must have one.
        const missingRate = this.specialItems.some((r) => this.toNum(r.qty) > 0 && this.toNum(r.rate) <= 0);
        if (missingRate) {
            this.toast(
                'Special item rate missing',
                'Enter a rate for every Special Item that has a quantity, or remove the row.',
                'warning'
            );
            return false;
        }
        return true;
    }

    buildPayload() {
        const money = (n) => Math.round(this.toNum(n) * 100) / 100;
        return {
            generatedDate: this.formatDate(),
            sectionA: this.sectionA.map((r) => ({
                slNo: r.slNo,
                description: r.description,
                unit: r.unit,
                totalWeight: this.toNum(r.totalWeight),
                additionalWeight: this.toNum(r.additionalWeight),
                reason: r.reason || '',
                totalCalcWeight: money(r.totalCalcWeight),
                rate: this.toNum(r.rate),
                cost: money(r.cost)
            })),
            accessories: this.accessories.map((r) => this.accPayload(r)),
            buyouts: this.buyouts.map((r) => this.accPayload(r)),
            specialItems: this.specialItems.map((r) => ({
                description: r.description,
                unit: r.unit,
                qty: this.toNum(r.qty),
                rate: this.toNum(r.rate),
                cost: money(r.cost)
            })),
            conversion: this.conversion
                .filter((r) => r.selected)
                .map((r) => ({
                    description: r.description,
                    unit: r.unit,
                    weight: money(r.weight),
                    rate: this.toNum(r.rate),
                    cost: money(r.cost)
                })),
            otherCost: this.otherCost.map((r) => ({
                description: r.description,
                unit: r.unit,
                qty: this.toNum(r.qty),
                rate: this.toNum(r.rate),
                cost: money(r.cost)
            })),
            variableCost: this.variableCost.map((r) => ({
                description: r.description,
                cost: this.toNum(r.cost)
            })),
            // Read by QuoteExportController.loadPebBankDocData(). Blank strings
            // are kept rather than dropped so the Apex side can tell "typed
            // nothing" from "key absent" on an older saved estimate.
            paymentTerms: {
                consignmentPeriod: (this.consignmentPeriod || '').trim(),
                //erectionPeriod: (this.erectionPeriod || '').trim(),
                validity: (this.offerValidity || '').trim()
            },
            transportation: {
                deliveryTerm: this.deliveryTerm,
                value: this.toNum(this.transportationValue)
            },
            totals: this.totals,
            _state: this.buildState(),
            _buildingDescription: this._buildingDescription || null
        };
    }

    accPayload(r) {
        const money = (n) => Math.round(this.toNum(n) * 100) / 100;
        return {
            description: r.description,
            unit: r.unit,
            qty: this.toNum(r.qty),
            unitWt: this.toNum(r.unitWt),
            totalWeight: money(r.totalWeight),
            rate: this.toNum(r.rate),
            cost: money(r.cost)
        };
    }

    buildState() {
        return {
            marginPercent: this.toNum(this.marginPercent),
            gstPercent: this.toNum(this.gstPercent),
            benchmarkRate: this.toNum(this.benchmarkRate),
            paymentTerms: {
                consignmentPeriod: (this.consignmentPeriod || '').trim(),
                erectionPeriod: (this.erectionPeriod || '').trim(),
                validity: (this.offerValidity || '').trim()
            },
            transportation: {
                deliveryTerm: this.deliveryTerm,
                value: this.toNum(this.transportationValue)
            },
            sectionA: this.sectionA.map((r) => ({
                key: r.key,
                totalWeight: this.toNum(r.totalWeight),
                additionalWeight: this.toNum(r.additionalWeight),
                reason: r.reason || ''
            })),
            accessories: this.accessories.map((r) => ({ key: r.key, qty: this.toNum(r.qty), unitWt: this.toNum(r.unitWt) })),
            buyouts: this.buyouts.map((r) => ({
                key: r.key,
                qty: this.toNum(r.qty),
                unitWt: this.toNum(r.unitWt),
                rate: this.toNum(r.rate)
            })),
            specialItems: this.specialItems.map((r) => ({
                description: r.description,
                unit: r.unit,
                qty: this.toNum(r.qty),
                rate: this.toNum(r.rate)
            })),
            conversion: this.conversion.map((r) => ({ key: r.key, selected: r.selected })),
            otherCost: this.otherCost.map((r) => ({
                key: r.key,
                unit: r.unit,
                qty: this.toNum(r.qty),
                rate: this.toNum(r.rate)
            })),
            variableCost: this.variableCost.map((r) => ({ key: r.key, cost: this.toNum(r.cost) }))
        };
    }

    /* =================== utils =================== */
    toNum(v) {
        const n = parseFloat(v);
        return isNaN(n) ? 0 : n;
    }

    nonNeg(v) {
        const n = parseFloat(v);
        if (isNaN(n)) {
            return 0;
        }
        return n < 0 ? 0 : n;
    }

    formatDate() {
        const d = new Date();
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return `${String(d.getDate()).padStart(2, '0')}-${months[d.getMonth()]}-${d.getFullYear()}`;
    }

    errMsg(error) {
        return (error && error.body && error.body.message) || (error && error.message) || 'Unexpected error';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
   
}
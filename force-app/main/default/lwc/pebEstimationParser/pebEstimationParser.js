/**
 * Universal PEB Design Estimation Parser
 * ---------------------------------------
 * Resilient multi-format extraction engine for PEB Design Estimation documents.
 * Modeled after the architecture of pebBuildingParser.
 *
 * Supports:
 *   1. Landscape & Portrait estimation layouts (auto-adapting column geometry)
 *   2. Section A Raw Material weights (Built-up, Cold Form, Hardware C1/CRest, etc.)
 *   3. Hardware itemization handling (subtotal vs grand-total conventions)
 *   4. Notes & Accessories item parsing
 *   5. Document metadata extraction (Enquiry No, Project, Location, Date, Built-up area)
 */

const SECTION_MATCHERS = [
    { key: 'A', re: /built[\s-]*up|a572|grade\s*50/i },
    { key: 'B', re: /cold[\s-]*form|a653/i },
    { key: 'HW', re: /hard[\s-]*ware|a307|a325/i },
    { key: 'D', re: /hot[\s-]*rolled|misc\.?\s*hr|is[\s-]*2062/i },
    { key: 'E', re: /deck\s*sheet|decking|mezzanine\s*deck/i },
    { key: 'F', re: /galvalume[^|]*roof/i },
    { key: 'G', re: /galvalume[^|]*wall/i },
    { key: 'H', re: /packing/i }
];

const DEFAULT_TOTALS = {
    A: 0,
    B: 0,
    C1: 0,
    CRest: 0,
    D: 0,
    E: 0,
    F: 0,
    G: 0,
    H: 0
};

/**
 * Normalizes unit token to standard PEB calculator unit picklist values.
 */
export function normaliseUnit(raw) {
    const u = (raw || '').toLowerCase().replace(/[^a-z]/g, '');
    if (!u) return 'No.s';
    if (['sqm', 'sqmt', 'sqmtr', 'm2', 'sq'].includes(u)) return 'Sq.M';
    if (['kg', 'kgs'].includes(u)) return 'Kg';
    if (['m', 'mt', 'mtr', 'mtrs', 'rm', 'rmt', 'metre', 'meter'].includes(u)) return 'Mtr';
    if (['ltr', 'l', 'litre', 'liter'].includes(u)) return 'Ltr';
    if (['nos', 'no', 'pcs', 'piece', 'pieces'].includes(u)) return 'No.s';
    return 'No.s';
}

/**
 * Parses numeric string, stripping commas.
 */
export function parseNum(s) {
    if (s == null) return null;
    const n = parseFloat(String(s).replace(/,/g, ''));
    return isNaN(n) ? null : n;
}

/**
 * Main entry point: Parses a Design Estimation PDF and returns structured data.
 * @param {Uint8Array|ArrayBuffer|string} inputData - PDF bytes or base64 string
 * @returns {Promise<Object>} Structured estimation result
 */
export async function parseEstimationPdf(inputData) {
    if (!window.pdfjsLib) {
        throw new Error('PDF.js library is not loaded');
    }

    let uint8;
    if (typeof inputData === 'string') {
        const binary = atob(inputData);
        uint8 = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i++) {
            uint8[i] = binary.charCodeAt(i);
        }
    } else if (inputData instanceof Uint8Array) {
        uint8 = inputData;
    } else if (inputData instanceof ArrayBuffer) {
        uint8 = new Uint8Array(inputData);
    } else {
        throw new Error('Invalid input data for PDF parsing');
    }

    const doc = await window.pdfjsLib.getDocument({ data: uint8 }).promise;
    const allPages = [];
    const allWords = [];

    for (let p = 1; p <= doc.numPages; p++) {
        const page = await doc.getPage(p);
        const vp = page.getViewport({ scale: 1 });
        const tc = await page.getTextContent();
        const pageWords = [];

        for (const it of tc.items) {
            const str = (it.str || '').replace(/\s+/g, ' ').trim();
            if (!str) continue;
            const w = {
                page: p,
                x: it.transform[4],
                y: it.transform[5],
                top: vp.height - it.transform[5],
                w: it.width,
                h: it.height,
                str
            };
            pageWords.push(w);
            allWords.push(w);
        }

        allPages.push({ pageNumber: p, viewport: vp, words: pageWords });
    }

    // Group items into physical horizontal lines
    const sortedWords = [...allWords].sort((a, b) => a.top - b.top || a.x - b.x);
    const rows = [];
    let curRow = null;
    for (const w of sortedWords) {
        if (!curRow || Math.abs(w.top - curRow.top) > 3) {
            curRow = { top: w.top, items: [] };
            rows.push(curRow);
        }
        curRow.items.push(w);
    }
    for (const r of rows) {
        r.items.sort((a, b) => a.x - b.x);
    }

    // 1. Detect Column Geometry from Headers
    const firstVp = allPages[0] && allPages[0].viewport;
    const isLandscape = firstVp ? firstVp.width > firstVp.height : true;
    const col = detectColumns(rows, isLandscape);

    // Helpers
    const textIn = (row, band) =>
        row.items
            .filter((i) => i.x >= band[0] && i.x < band[1])
            .sort((a, b) => a.x - b.x)
            .map((i) => i.str)
            .join(' ')
            .replace(/\s+/g, ' ')
            .trim();

    const numAt = (row, band, pickLast = false) => {
        const hits = row.items
            .filter((i) => i.x >= band[0] && i.x < band[1] && /^[0-9][0-9,.]*$/.test(i.str))
            .sort((a, b) => a.x - b.x);
        if (hits.length === 0) return null;
        const hit = pickLast ? hits[hits.length - 1] : hits[0];
        return parseNum(hit.str);
    };

    const valueOf = (row) => {
        const t = numAt(row, col.TOTAL, true);
        return t !== null ? t : numAt(row, col.QTY, true);
    };

    // 2. Extract Header Metadata
    const metadata = extractMetadata(rows);

    // 3. Extract Table Sections, Notes, and Accessories
    const sections = [];
    const notes = [];
    const accessories = [];
    let currentBlock = 'SECTIONS';

    for (const row of rows) {
        const rowText = row.items.map((i) => i.str).join(' ').trim();

        if (/^note[s]?\b/i.test(rowText)) {
            currentBlock = 'NOTE';
            continue;
        }
        if (/^accessories\b/i.test(rowText)) {
            currentBlock = 'ACCESSORIES';
            continue;
        }

        if (currentBlock === 'NOTE' || currentBlock === 'ACCESSORIES') {
            let desc = textIn(row, [col.SR[0], col.QTY[0]]);
            if (!desc) continue;
            let srNo = '';
            const m = desc.match(/^([0-9]{1,3})[.)]?\s*(.*)$/);
            if (m) {
                srNo = m[1];
                desc = m[2];
            }
            if (!desc) continue;

            let qty = numAt(row, col.QTY, true);
            if (qty === null) qty = numAt(row, col.TOTAL, true);
            const unit = normaliseUnit(textIn(row, col.UNIT));

            const item = {
                srNo: srNo || String((currentBlock === 'NOTE' ? notes.length : accessories.length) + 1),
                description: desc,
                qty: qty || 0,
                unit
            };

            if (currentBlock === 'NOTE') notes.push(item);
            else accessories.push(item);
            continue;
        }

        // Section row
        const srHit = row.items.find((i) => i.x >= col.SR[0] && i.x < col.SR[1] && /^[A-Za-z]$/.test(i.str));
        const letter = srHit ? srHit.str : null;
        const desc = textIn(row, col.DESC);
        if (letter) {
            sections.push({
                letter,
                desc,
                value: valueOf(row),
                rows: []
            });
        } else if (sections.length) {
            sections[sections.length - 1].rows.push(row);
        }
    }

    // 4. Compute Totals (with robust hardware logic)
    const totals = { ...DEFAULT_TOTALS };

    for (const sec of sections) {
        const match =
            SECTION_MATCHERS.find((m) => m.re.test(sec.desc)) ||
            SECTION_MATCHERS.find((m) => m.key === sec.letter.toUpperCase());
        if (!match) continue;

        if (match.key === 'HW') {
            let c1 = null;
            let total = null;
            let sumNonC1 = 0;
            let sumNonC1Seen = false;

            for (const r of sec.rows) {
                const rDesc = textIn(r, col.DESC).toLowerCase();
                const rVal = valueOf(r);
                if (/total/.test(rDesc)) {
                    if (total === null && rVal !== null) total = rVal;
                    continue;
                }
                const isAnchor = rDesc.includes('anchor') && rDesc.includes('bolt') && !rDesc.includes('non-standard');
                if (isAnchor && c1 === null) {
                    c1 = rVal;
                } else if (rVal !== null) {
                    sumNonC1 += rVal;
                    sumNonC1Seen = true;
                }
            }

            const c1v = c1 === null ? 0 : c1;
            let rest = 0;
            if (total !== null) {
                rest = total > c1v ? total - c1v : total;
            } else if (sumNonC1Seen) {
                rest = sumNonC1;
            } else if (sec.value !== null) {
                rest = sec.value > c1v ? sec.value - c1v : sec.value;
            }

            totals.C1 = c1v;
            totals.CRest = rest > 0 ? rest : 0;
        } else if (sec.value !== null) {
            totals[match.key] = sec.value;
        }
    }

    return {
        metadata,
        columns: col,
        totals,
        sections: sections.map((s) => ({
            letter: s.letter,
            description: s.desc,
            value: s.value,
            subRowCount: s.rows.length
        })),
        notes,
        accessories,
        specialItems: notes.map((n) => ({
            description: n.description,
            unit: n.unit,
            qty: n.qty
        }))
    };
}

/**
 * Dynamically detects table column bounds based on table headers.
 */
function detectColumns(rows, isLandscape) {
    let headerRow = null;
    for (const r of rows) {
        const text = r.items.map((i) => i.str).join(' ').toLowerCase();
        if (text.includes('description') && (text.includes('total') || text.includes('qty') || text.includes('sr'))) {
            headerRow = r;
            break;
        }
    }

    if (headerRow) {
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

        if (qtyItem) qtyStart = Math.max(srEnd + 50, qtyItem.x - 20);
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

    // Default fallbacks based on orientation
    if (isLandscape) {
        return {
            SR: [0, 78],
            DESC: [78, 230],
            QTY: [230, 280],
            UNIT: [280, 310],
            UNIT_WT: [310, 340],
            TOTAL: [340, 9999]
        };
    }

    return {
        SR: [0, 85],
        DESC: [85, 340],
        QTY: [340, 380],
        UNIT: [380, 420],
        UNIT_WT: [420, 470],
        TOTAL: [470, 9999]
    };
}

/**
 * Extracts metadata from the document header lines (Enquiry No, Project, Date, Area, etc.).
 */
function extractMetadata(rows) {
    const meta = {
        projectName: '',
        location: '',
        preparedBy: '',
        checkedBy: '',
        date: '',
        enquiryNo: '',
        builtUpArea: null
    };

    let hasAreaHeader = false;

    for (const r of rows) {
        if (r.top > 160) continue; // metadata is only at the top of the sheet
        const lineText = r.items.map((i) => i.str).join(' ');

        let m = lineText.match(/enq(?:uiry)?\.?\s*no\.?[:\s]*([0-9a-zA-Z\-_/]+)/i);
        if (m && !meta.enquiryNo) meta.enquiryNo = m[1].trim();

        m = lineText.match(/prepared\s*by[:\s]*([a-zA-Z.\s]+?)(?=\s*DATE|\s*CHECKED|\s*area|\s*building|\s*$)/i);
        if (m && !meta.preparedBy) meta.preparedBy = m[1].trim();

        m = lineText.match(/checked\s*by[:\s]*([a-zA-Z.\s]+?)(?=\s*DATE|\s*$)/i);
        if (m && !meta.checkedBy) meta.checkedBy = m[1].trim();

        m = lineText.match(/date[:\s]*([0-9]{2}[-/][0-9]{2}[-/][0-9]{4})/i);
        if (m && !meta.date) meta.date = m[1].trim();

        if (/building\s*built\s*up|area\s*in\s*sqm/i.test(lineText)) {
            hasAreaHeader = true;
        }

        m = lineText.match(/(?:built\s*up\s*area|area\s*in\s*sqm)[:\s]*([0-9][0-9,.]*)/i);
        if (m && meta.builtUpArea == null) {
            meta.builtUpArea = parseNum(m[1]);
        } else if (hasAreaHeader && meta.builtUpArea == null) {
            // Check for right-aligned area number in the header block
            const rightNum = r.items.find((i) => i.x > 450 && /^[0-9][0-9,.]*$/.test(i.str));
            if (rightNum) {
                meta.builtUpArea = parseNum(rightNum.str);
            }
        }

        // Project Name & Location from the top-left area
        if (r.items.length && r.items[0].x < 120) {
            const firstStr = r.items[0].str.trim();
            if (!/^(enq|date|prep|check|sr|building|area|description)/i.test(firstStr)) {
                if (!meta.projectName) {
                    meta.projectName = firstStr;
                } else if (!meta.location && firstStr !== meta.projectName) {
                    meta.location = firstStr;
                }
            }
        }
    }

    return meta;
}
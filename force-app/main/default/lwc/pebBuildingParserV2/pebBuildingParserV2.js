/**
 * pebBuildingParserV2 - Reetabrata (8th October 2026)
 * ------------------------------------------------------------------------
 * Reads the Building Description PDF by its TABLE GRID - the cell borders that
 * Word draws into the PDF - instead of by fixed x-positions and per-section row
 * skeletons. Row count, column count, colspan and rowspan all come from the
 * document, so a table with 8 rows, 12 rows or 6 columns prints as-is.
 *
 * ADDITIVE. Nothing existing is changed:
 *   - calls the ORIGINAL parseUniversalBuildingPdf first and keeps everything it
 *     returns (clientInfo, geometry, accessories, paramTable, ...)
 *   - replaces ONLY result.docSections, and only when at least one bordered
 *     table was found. Otherwise the V1 docSections stay exactly as today.
 *   - emits the SAME docSections shape QuoteExportController.buildDocSectionsFromParsed
 *     already consumes (title / subtitle / sectionType / colCount / colWidths /
 *     tableHeaders / tableRows{c1..c10, rNSpan, cNSpan, skipCN, isCNBold} /
 *     listItems / notes). Apex and GenerateBankDoc.page are untouched.
 *   - rows carry only the keys that are set (a false flag is simply absent), so
 *     the saved JSON is smaller than V1's.
 *
 * Limits inherited from the existing Apex renderer (deliberately NOT changed):
 *   - at most 10 columns: extra columns fold into column 10
 *   - rowspan / colspan only on columns 1-6: a merge starting further right is
 *     printed unmerged (text in the first cell, blanks after it)
 *
 * Requires pdf.js 2.5.207 loaded on window (main-thread mode), same as the
 * calculator already does. Only the PEB price calculator imports this module.
 */
import { parseUniversalBuildingPdf } from 'c/pebBuildingParser';

const TOL = 1.5;          // pt - two lines closer than this are the same line
const THIN = 2.5;         // pt - a filled rectangle no thicker than this is a border
const MIN_LEN = 4;        // pt - ignore shorter border segments
const COVER = 0.6;        // a border must cover 60% of a cell edge to count as present
const MAX_COLS = 10;      // DocRow has c1..c10
const MAX_SPAN_COL = 6;   // Apex reads r1Span..r6Span / c1Span..c6Span only

const START_RE = /DESIGN\s*CRITERIA/i;
// (A) / A.1 / C.1.8.7 / D.  - the space after the number is optional ("D.2Building")
const HEADING_RE = /^(?:\([A-Z]\)|[A-Z](?:\.\d+)+|[A-Z]\.)(?=\s*\S)/;
const MAJOR_RE = /^(?:\([A-Z]\)|[A-Z]\.(?!\d))/;
const LIST_RE = /^(?:\d{1,2}[.)]|[•\-–])\s*\S/;   // "1) text" and "1)text"
const PAGE_RE = /^Page\s+\d+\s+of\s+\d+$/i;

/**
 * Drop-in replacement for parseUniversalBuildingPdf: same input, same output
 * object, better docSections.
 */
export async function parseBuildingPdfV2(inputData) {
    const bytes = toBytes(inputData);
    const result = await parseUniversalBuildingPdf(bytes.slice());
    try {
        const sections = await extractGridDocSections(bytes.slice());
        if (sections.some(s => s.sectionType === 'table' && s.tableRows.length > 0)) {
            result.docSections = sections;
            result._docSectionsSource = 'grid-v2';
        } else {
            console.warn('[PEB V2] no bordered tables found - keeping V1 docSections');
        }
    } catch (e) {
        console.warn('[PEB V2] grid extraction failed - keeping V1 docSections:', e && e.message);
    }
    return result;
}

function toBytes(d) {
    if (d instanceof Uint8Array) return d;
    if (d instanceof ArrayBuffer) return new Uint8Array(d);
    return new Uint8Array(d);
}

/* ════════════════════════════════════════════════════════════════════════
   PAGE READING
   ════════════════════════════════════════════════════════════════════════ */
async function extractGridDocSections(bytes) {
    const lib = window.pdfjsLib;
    if (!lib || !lib.OPS) throw new Error('pdf.js is not loaded');
    const doc = await lib.getDocument({ data: bytes }).promise;
    const pages = [];
    for (let n = 1; n <= doc.numPages; n++) {
        const page = await doc.getPage(n);
        const segs = await readBorderSegments(page, lib.OPS);   // getOperatorList also resolves the fonts
        const tc = await page.getTextContent();
        const fontCache = new Map();
        const items = tc.items
            .filter(it => (it.str || '').trim() !== '')
            .map(it => ({
                str: it.str,
                x: it.transform[4],
                y: it.transform[5],
                w: it.width || 0,
                h: it.height || Math.abs(it.transform[3]) || 8,
                bold: fontIsBold(page, it.fontName, fontCache),
                inTable: false
            }));
        const tables = buildTables(segs);
        assignItems(tables, items);
        const lines = groupLines(items.filter(it => !it.inTable));
        pages.push({ n, tables, lines });
    }
    dropPageFurniture(pages);
    return toDocSections(pages);
}

function fontIsBold(page, fontName, cache) {
    if (!fontName) return false;
    if (cache.has(fontName)) return cache.get(fontName);
    let bold = false;
    try {
        const co = page.commonObjs;
        if (co && typeof co.has === 'function' && co.has(fontName)) {
            const f = co.get(fontName);
            const name = String((f && (f.name || f.fallbackName)) || '');
            bold = /bold|black|heavy|semibold|demibold/i.test(name);
        }
    } catch (e) {
        bold = false;
    }
    cache.set(fontName, bold);
    return bold;
}

/* ════════════════════════════════════════════════════════════════════════
   BORDER SEGMENTS - walk the page's operator list, track the CTM, and keep
   every thin filled rectangle / straight line as a horizontal or vertical
   segment in page user space (the same space getTextContent reports in).
   ════════════════════════════════════════════════════════════════════════ */
async function readBorderSegments(page, OPS) {
    const ol = await page.getOperatorList();
    const segs = [];
    let ctm = [1, 0, 0, 1, 0, 0];
    const stack = [];
    let pending = [];
    let cur = null;

    const pt = (x, y) => [ctm[0] * x + ctm[2] * y + ctm[4], ctm[1] * x + ctm[3] * y + ctm[5]];

    const pushSeg = (x1, y1, x2, y2) => {
        if (Math.abs(y1 - y2) <= TOL && Math.abs(x1 - x2) >= MIN_LEN) {
            segs.push({ h: true, y: (y1 + y2) / 2, a: Math.min(x1, x2), b: Math.max(x1, x2) });
        } else if (Math.abs(x1 - x2) <= TOL && Math.abs(y1 - y2) >= MIN_LEN) {
            segs.push({ h: false, x: (x1 + x2) / 2, a: Math.min(y1, y2), b: Math.max(y1, y2) });
        }
    };

    const commit = (stroked) => {
        pending.forEach(p => {
            if (p.kind === 'rect') {
                const c = [pt(p.x, p.y), pt(p.x + p.w, p.y), pt(p.x + p.w, p.y + p.h), pt(p.x, p.y + p.h)];
                const xs = c.map(q => q[0]);
                const ys = c.map(q => q[1]);
                const x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs);
                const y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys);
                const w = x1 - x0, h = y1 - y0;
                if (h <= THIN && w >= MIN_LEN) {
                    segs.push({ h: true, y: (y0 + y1) / 2, a: x0, b: x1 });
                } else if (w <= THIN && h >= MIN_LEN) {
                    segs.push({ h: false, x: (x0 + x1) / 2, a: y0, b: y1 });
                } else if (stroked) {
                    // a stroked box = four borders; a filled box is cell shading - ignored
                    pushSeg(x0, y0, x1, y0); pushSeg(x0, y1, x1, y1);
                    pushSeg(x0, y0, x0, y1); pushSeg(x1, y0, x1, y1);
                }
            } else {
                const a = pt(p.x1, p.y1), b = pt(p.x2, p.y2);
                pushSeg(a[0], a[1], b[0], b[1]);
            }
        });
        pending = [];
        cur = null;
    };

    // pdf.js >= 5 packs the whole path into one flat array with DrawOPS codes
    // (moveTo 0, lineTo 1, curveTo 2, quadraticCurveTo 3, closePath 4) and puts
    // the paint op in constructPath's first argument. Rectangles arrive as
    // moveTo/lineTo sequences there, which pushSeg already handles.
    const walkFlat = (data) => {
        for (let i = 0; i < data.length;) {
            const code = data[i++];
            if (code === 0) { cur = [data[i], data[i + 1]]; i += 2; }
            else if (code === 1) {
                const p = [data[i], data[i + 1]]; i += 2;
                if (cur) pending.push({ kind: 'line', x1: cur[0], y1: cur[1], x2: p[0], y2: p[1] });
                cur = p;
            }
            else if (code === 2) { cur = [data[i + 4], data[i + 5]]; i += 6; }
            else if (code === 3) { cur = [data[i + 2], data[i + 3]]; i += 4; }
            else if (code === 4) { /* closePath */ }
            else break;
        }
    };

    // pdf.js 2.x packs path building into one constructPath op: [subOps[], coords[]]
    const walk = (ops, args) => {
        let k = 0;
        for (let i = 0; i < ops.length; i++) {
            const o = ops[i];
            if (o === OPS.rectangle) {
                pending.push({ kind: 'rect', x: args[k], y: args[k + 1], w: args[k + 2], h: args[k + 3] });
                k += 4;
            } else if (o === OPS.moveTo) {
                cur = [args[k], args[k + 1]];
                k += 2;
            } else if (o === OPS.lineTo) {
                const p = [args[k], args[k + 1]];
                if (cur) pending.push({ kind: 'line', x1: cur[0], y1: cur[1], x2: p[0], y2: p[1] });
                cur = p;
                k += 2;
            } else if (o === OPS.curveTo) {
                cur = [args[k + 4], args[k + 5]];
                k += 6;
            } else if (o === OPS.curveTo2 || o === OPS.curveTo3) {
                cur = [args[k + 2], args[k + 3]];
                k += 4;
            } else if (o === OPS.closePath) {
                // nothing to do
            } else {
                break;  // unknown sub-op: argument count unknown, stop this path
            }
        }
    };

    for (let i = 0; i < ol.fnArray.length; i++) {
        const op = ol.fnArray[i];
        const a = ol.argsArray[i];
        if (op === OPS.save) {
            stack.push(ctm.slice());
        } else if (op === OPS.restore) {
            if (stack.length) ctm = stack.pop();
        } else if (op === OPS.transform) {
            ctm = compose(ctm, a);
        } else if (op === OPS.paintFormXObjectBegin) {
            stack.push(ctm.slice());
            if (a && a[0]) ctm = compose(ctm, a[0]);
        } else if (op === OPS.paintFormXObjectEnd) {
            if (stack.length) ctm = stack.pop();
        } else if (op === OPS.constructPath) {
            if (Array.isArray(a[0])) {
                walk(a[0], a[1]);                                   // 2.x: [subOps[], coords[]]
            } else if (typeof a[0] === 'number' && a[1] && a[1].length !== undefined) {
                // >= 5: [paintOp, flatPath, minMax]; the flat path may itself be wrapped in an Array
                const flat = (ArrayBuffer.isView(a[1]) || typeof a[1][0] === 'number') ? a[1] : a[1][0];
                if (flat && flat.length) walkFlat(flat);
                const paint = a[0];
                if (paint === OPS.fill || paint === OPS.eoFill) commit(false);
                else if (paint === OPS.endPath) { pending = []; cur = null; }
                else commit(true);
            }
        } else if (op === OPS.rectangle || op === OPS.moveTo || op === OPS.lineTo) {
            walk([op], a);
        } else if (op === OPS.endPath) {
            pending = []; cur = null;             // clip only - never painted
        } else if (op === OPS.fill || op === OPS.eoFill) {
            commit(false);
        } else if (op === OPS.stroke || op === OPS.closeStroke || op === OPS.fillStroke ||
                   op === OPS.eoFillStroke || op === OPS.closeFillStroke || op === OPS.closeEOFillStroke) {
            commit(true);
        }
    }
    return segs;
}

// CTM' = CTM × M  (apply M first, then the existing CTM) - canvas transform() semantics
function compose(c, m) {
    return [
        c[0] * m[0] + c[2] * m[1],
        c[1] * m[0] + c[3] * m[1],
        c[0] * m[2] + c[2] * m[3],
        c[1] * m[2] + c[3] * m[3],
        c[0] * m[4] + c[2] * m[5] + c[4],
        c[1] * m[4] + c[3] * m[5] + c[5]
    ];
}

/* ════════════════════════════════════════════════════════════════════════
   TABLES - connected groups of borders become tables; the distinct y's of
   the horizontal borders are the row boundaries, the distinct x's of the
   vertical borders are the column boundaries; a missing border = a merge.
   ════════════════════════════════════════════════════════════════════════ */
function buildTables(segs) {
    const hs = mergeCollinear(segs.filter(s => s.h), 'y');
    const vs = mergeCollinear(segs.filter(s => !s.h), 'x');
    const all = hs.concat(vs);
    const parent = all.map((_, i) => i);
    const find = i => (parent[i] === i ? i : (parent[i] = find(parent[i])));
    const union = (i, j) => { parent[find(i)] = find(j); };

    const T2 = TOL * 2;
    for (let i = 0; i < hs.length; i++) {
        for (let j = 0; j < vs.length; j++) {
            const h = hs[i], v = vs[j];
            if (v.x >= h.a - T2 && v.x <= h.b + T2 && h.y >= v.a - T2 && h.y <= v.b + T2) {
                union(i, hs.length + j);
            }
        }
    }

    const groups = {};
    all.forEach((s, i) => {
        const r = find(i);
        if (!groups[r]) groups[r] = { hs: [], vs: [] };
        groups[r][s.h ? 'hs' : 'vs'].push(s);
    });

    const tables = [];
    Object.keys(groups).forEach(k => {
        const g = groups[k];
        if (g.hs.length < 2 || g.vs.length < 2) return;
        const ys = cluster(g.hs.map(s => s.y)).sort((a, b) => b - a);   // top first (PDF y grows upward)
        const xs = cluster(g.vs.map(s => s.x)).sort((a, b) => a - b);
        if (ys.length < 2 || xs.length < 2) return;
        if (xs[xs.length - 1] - xs[0] < 40) return;                      // a box, not a table
        tables.push(makeTable(xs, ys, g.hs, g.vs));
    });
    tables.sort((a, b) => b.top - a.top);
    return tables;
}

// Segments on the same line (same y for horizontals / same x for verticals,
// within TOL) that touch or nearly touch are joined into one. Grouping by the
// line position FIRST matters: borders of neighbouring tables can sit 0.1pt
// apart, and a plain (key, a) sort would interleave them and swallow one.
function mergeCollinear(list, key) {
    const byPos = list.slice().sort((p, q) => p[key] - q[key]);
    const out = [];
    let group = [];
    const flushGroup = () => {
        if (!group.length) return;
        const pos = group.reduce((s, x) => s + x[key], 0) / group.length;
        group.sort((p, q) => p.a - q.a);
        let last = null;
        group.forEach(s => {
            if (last && s.a <= last.b + 3) {
                last.b = Math.max(last.b, s.b);
            } else {
                last = Object.assign({}, s, { [key]: pos });
                out.push(last);
            }
        });
        group = [];
    };
    byPos.forEach(s => {
        if (group.length && s[key] - group[group.length - 1][key] > TOL) flushGroup();
        group.push(s);
    });
    flushGroup();
    return out;
}

function cluster(values) {
    const sorted = values.slice().sort((a, b) => a - b);
    const out = [];
    let group = [];
    sorted.forEach(v => {
        if (group.length && v - group[group.length - 1] > TOL) {
            out.push(group.reduce((s, x) => s + x, 0) / group.length);
            group = [];
        }
        group.push(v);
    });
    if (group.length) out.push(group.reduce((s, x) => s + x, 0) / group.length);
    return out;
}

function makeTable(xs, ys, hs, vs) {
    const nr = ys.length - 1;
    const nc = xs.length - 1;
    const covers = (segList, key, pos, lo, hi) => segList.some(s =>
        Math.abs(s[key] - pos) <= TOL && (Math.min(s.b, hi) - Math.max(s.a, lo)) >= COVER * (hi - lo));
    const vAt = (j, i) => covers(vs, 'x', xs[j], ys[i + 1], ys[i]);   // border at column edge j within row i
    const hAt = (i, j) => covers(hs, 'y', ys[i], xs[j], xs[j + 1]);   // border at row edge i within column j

    const covered = [];
    for (let i = 0; i < nr; i++) covered.push(new Array(nc).fill(false));

    const cells = [];
    for (let i = 0; i < nr; i++) {
        for (let j = 0; j < nc; j++) {
            if (covered[i][j]) continue;
            let cs = 1;
            while (j + cs < nc && !covered[i][j + cs] && !vAt(j + cs, i)) cs++;
            let rs = 1;
            while (i + rs < nr) {
                let open = true;
                for (let k = j; k < j + cs; k++) {
                    if (covered[i + rs][k] || hAt(i + rs, k)) { open = false; break; }
                }
                if (!open) break;
                rs++;
            }
            for (let r = i; r < i + rs; r++) for (let k = j; k < j + cs; k++) covered[r][k] = true;
            cells.push({ i, j, rs, cs, x0: xs[j], x1: xs[j + cs], yt: ys[i], yb: ys[i + rs], items: [] });
        }
    }
    return { xs, ys, nr, nc, cells, top: ys[0], bottom: ys[nr], left: xs[0], right: xs[nc] };
}

function assignItems(tables, items) {
    items.forEach(it => {
        const cx = it.x + it.w / 2;
        const cy = it.y + it.h * 0.35;
        for (let t = 0; t < tables.length; t++) {
            const tb = tables[t];
            if (cx < tb.left - TOL || cx > tb.right + TOL || cy < tb.bottom - TOL || cy > tb.top + TOL) continue;
            const cell = tb.cells.find(c => cx >= c.x0 - TOL && cx <= c.x1 + TOL && cy >= c.yb - TOL && cy <= c.yt + TOL);
            if (cell) {
                cell.items.push(it);
                it.inTable = true;
                break;
            }
        }
    });
}

/* ════════════════════════════════════════════════════════════════════════
   TEXT - items are joined by the GAP between them, not with a blanket space,
   so "S teel" / "o f" style breaks are never produced in the first place.
   ════════════════════════════════════════════════════════════════════════ */
function groupByLine(items) {
    const sorted = items.slice().sort((p, q) => q.y - p.y);
    const lines = [];
    let line = null;
    sorted.forEach(it => {
        if (!line || Math.abs(it.y - line.y) > Math.max(2, it.h * 0.5)) {
            line = { y: it.y, items: [] };
            lines.push(line);
        }
        line.items.push(it);
    });
    lines.forEach(l => l.items.sort((p, q) => p.x - q.x));
    return lines;
}

function lineText(items) {
    let out = '';
    let endX = null;
    items.forEach(it => {
        const s = it.str;
        if (endX !== null) {
            const gap = it.x - endX;
            // a real word gap is ~25% of the font size; kerning gaps inside a word are < 5%
            if (gap > Math.max(0.6, it.h * 0.12) && !/\s$/.test(out) && !/^\s/.test(s)) out += ' ';
        }
        out += s;
        endX = it.x + it.w;
    });
    return out.replace(/\s+/g, ' ').trim();
}

// A line inside a cell that starts a new item - "a) ...", "b) ...", "1. ...",
// "1) ...", "- ...", "• ..." - keeps its own line in the offer (\n, printed by
// white-space: pre-line on the PEB spec table). Any other line is a wrap of the
// previous one and is joined with a space, as before. Reetabrata (8th October 2026)
const CELL_ITEM_RE = /^(?:[a-z][.)]|\d{1,2}[.)]|[•\-–])\s*\S/i;
// The same markers in the MIDDLE of the text - "... (As per Drawing) b) 200 kg/m ..."
// when the source PDF ran the items together on one line. Lower-case letters,
// numbers and bullets only, a space on both sides, and the ")" must not be
// closing an earlier "(" - so "(Grid K)", "(Axis 1)", "(Part-1)", "– N/A" and
// "No. 1." are never split.
const CELL_ITEM_MID_RE = /\s((?:[a-z]|\d{1,2})\)|•)(?=\s|$)/g;
// true when the text has a "(" that has not been closed yet. Item markers
// ("a)", "1)") carry a ")" of their own and are not counted.
function hasOpenParen(text) {
    const t = text.replace(/(?:^|\s)(?:[a-z]|\d{1,2})\)(?=\s|$)/g, ' ');
    return (t.match(/\(/g) || []).length > (t.match(/\)/g) || []).length;
}
function splitCellItems(text) {
    return text.replace(CELL_ITEM_MID_RE, (m, marker, idx) =>
        hasOpenParen(text.slice(0, idx)) ? m : '\n' + marker);   // unmatched "(" ahead -> closing paren, not an item
}
function joinItems(items) {
    if (!items.length) return '';
    let out = '';
    groupByLine(items).forEach(l => {
        const t = lineText(l.items).replace(/\s+/g, ' ').trim();
        if (!t) return;
        if (!out) out = t;
        else {
            // a "1)" starting a wrapped line may just be closing "(Axis" above it
            out += (CELL_ITEM_RE.test(t) && !hasOpenParen(out) ? '\n' : ' ') + t;
        }
    });
    return splitCellItems(out);
}

function groupLines(freeItems) {
    return groupByLine(freeItems).map(l => ({
        y: l.y,
        x: l.items[0].x,
        text: lineText(l.items),
        bold: l.items.every(it => it.bold)
    })).filter(l => l.text !== '');
}

// "Page 1 of 5" and anything else that repeats at the same place on most pages
function dropPageFurniture(pages) {
    const total = pages.length;
    const keyOf = l => l.text.toLowerCase().replace(/\d+/g, '#').replace(/\s+/g, ' ') + '|' + Math.round(l.y / 12);
    const counts = {};
    pages.forEach(p => {
        const seen = new Set();
        p.lines.forEach(l => {
            const k = keyOf(l);
            if (!seen.has(k)) { seen.add(k); counts[k] = (counts[k] || 0) + 1; }
        });
    });
    const limit = Math.max(2, Math.ceil(total / 2));
    pages.forEach(p => {
        p.lines = p.lines.filter(l => !PAGE_RE.test(l.text) && !(total >= 2 && counts[keyOf(l)] >= limit));
    });
}

/* ════════════════════════════════════════════════════════════════════════
   DOC SECTIONS - the exact shape QuoteExportController already renders.
   ════════════════════════════════════════════════════════════════════════ */
function mkSection(type, title) {
    return {
        title: title || '',
        subtitle: '',
        sectionType: type,
        colCount: 0,
        colWidths: [],
        tableHeaders: [],
        tableRows: [],
        listItems: [],
        notes: []
    };
}

function toDocSections(pages) {
    const stream = [];
    pages.forEach(p => {
        const blocks = p.tables.map(t => ({ kind: 'table', y: t.top, table: t }))
            .concat(p.lines.map(l => ({ kind: 'line', y: l.y, line: l })));
        blocks.sort((a, b) => b.y - a.y);
        blocks.forEach((b, idx) => {
            b.first = idx === 0;
            b.last = idx === blocks.length - 1;
            stream.push(b);
        });
    });

    const startIdx = stream.findIndex(b => b.kind === 'line' && START_RE.test(b.line.text));
    if (startIdx < 0) return [];

    const out = [];
    let pendingTitle = null;   // sub-heading waiting for its table / list
    let para = [];             // plain lines since the last heading / table
    let lastTable = null;      // section whose notes trailing lines belong to
    let curList = null;
    let afterTable = false;
    let prevBlock = null;

    const flush = () => {
        if (pendingTitle !== null) {
            // a sub-heading with no table and no list before the next heading
            // (e.g. "C.1.8 Building Additions"): print it as a heading line
            const s = mkSection('chapter', pendingTitle);
            s.notes = para;
            out.push(s);
        } else if (para.length) {
            const last = out[out.length - 1];
            if (lastTable) lastTable.notes = lastTable.notes.concat(para);
            else if (last && last.sectionType === 'chapter') last.notes = last.notes.concat(para);
            else { const s = mkSection('chapter', ''); s.notes = para; out.push(s); }
        }
        pendingTitle = null;
        para = [];
    };

    for (let i = startIdx; i < stream.length; i++) {
        const b = stream[i];
        if (b.kind === 'table') {
            const continues = b.first && prevBlock && prevBlock.kind === 'table' && prevBlock.last &&
                              lastTable && sameGrid(prevBlock.table, b.table);
            if (continues) {
                appendRows(lastTable, b.table);
            } else {
                const s = mkSection('table', pendingTitle || '');
                s.subtitle = para.join(' ');
                fillTable(s, b.table);
                out.push(s);
                lastTable = s;
                pendingTitle = null;
                para = [];
            }
            curList = null;
            afterTable = true;
        } else {
            const text = b.line.text;
            if (HEADING_RE.test(text) && text.length <= 140) {
                flush();
                curList = null;
                afterTable = false;
                lastTable = null;
                if (MAJOR_RE.test(text)) out.push(mkSection('chapter', text));
                else pendingTitle = text;
            } else if (LIST_RE.test(text)) {
                if (!curList) {
                    curList = mkSection('list', pendingTitle || '');
                    pendingTitle = null;
                    para = [];
                    lastTable = null;
                    out.push(curList);
                }
                curList.listItems.push(text);
            } else if (curList) {
                curList.listItems[curList.listItems.length - 1] += ' ' + text;   // wrapped list item
            } else if (afterTable && lastTable) {
                lastTable.notes.push(text);                                        // "Special condition..." etc.
            } else {
                para.push(text);
            }
        }
        prevBlock = b;
    }
    flush();
    return out;
}

function sameGrid(a, b) {
    if (a.nc !== b.nc) return false;
    for (let k = 0; k <= a.nc; k++) if (Math.abs(a.xs[k] - b.xs[k]) > 2.5) return false;
    return true;
}

function fillTable(section, t) {
    const nc = Math.min(t.nc, MAX_COLS);
    section.colCount = nc;
    section.colWidths = columnWidths(t, nc);
    section.tableRows = buildRows(t, nc);
}

// a table split across a page break: append the rows, dropping a repeated header row
function appendRows(section, t) {
    const rows = buildRows(t, section.colCount);
    const rowText = r => Array.from({ length: MAX_COLS }, (_, i) => r['c' + (i + 1)] || '').join('|');
    if (rows.length && section.tableRows.length && rowText(rows[0]) === rowText(section.tableRows[0])) rows.shift();
    section.tableRows = section.tableRows.concat(rows);
}

function columnWidths(t, nc) {
    const W = t.right - t.left;
    const out = [];
    for (let j = 0; j < nc; j++) {
        const hi = (j === nc - 1) ? t.right : t.xs[j + 1];
        out.push((Math.round(((hi - t.xs[j]) / W) * 1000) / 10) + '%');
    }
    return out;
}

function buildRows(t, nc) {
    const rows = [];
    for (let i = 0; i < t.nr; i++) rows.push({});
    t.cells.forEach(c => {
        const text = joinItems(c.items);
        const bold = c.items.length > 0 && c.items.every(it => it.bold);
        const j = Math.min(c.j, nc - 1);                       // overflow columns fold into the last one
        const col = j + 1;
        const row = rows[c.i];
        row['c' + col] = row['c' + col] ? (row['c' + col] + ' ' + text).trim() : text;
        if (bold && text) row['isC' + col + 'Bold'] = true;

        const canSpan = c.j < MAX_SPAN_COL;                    // Apex has rNSpan / cNSpan for 1-6 only
        const cs = Math.min(c.cs, nc - j);
        const rs = c.rs;
        if (canSpan && cs > 1) {
            row['c' + col + 'Span'] = cs;
            for (let k = j + 1; k < j + cs; k++) row['skipC' + (k + 1)] = true;
        }
        if (canSpan && rs > 1) {
            row['r' + col + 'Span'] = rs;
            const span = cs > 1 ? cs : 1;
            for (let r = c.i + 1; r < c.i + rs; r++) {
                for (let k = j; k < j + span; k++) rows[r]['skipC' + (k + 1)] = true;
            }
        }
        // !canSpan with a merge: text sits in the first cell, the covered cells stay
        // blank (not skipped), so the column count of every row is preserved
    });
    return rows;
}
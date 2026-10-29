import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import SHEETJS_STYLED from '@salesforce/resourceUrl/sheetjs_styled';   // NEW resource — old 'sheetjs' untouched. Reetabrata (14th July 2026)
// ── MOBILE EXPORT PATH — Deepanjan (17th July 2026) ──────────────────────────
// XLSX.writeFile() ends in a blob + <a download> click, which the Salesforce
// mobile app's webview silently swallows - the toast fired but no file existed.
// On phones the SAME generated workbook is base64'd to Apex, saved as a File on
// the quote, and opened in the app's native previewer (download/share lives
// there). Desktop keeps writeFile untouched.
import FORM_FACTOR from '@salesforce/client/formFactor';
import { NavigationMixin } from 'lightning/navigation';
import saveGeneratedFile from '@salesforce/apex/QuoteCostingDocumentMobileController.saveGeneratedFile';
import getQuoteValueJson from '@salesforce/apex/CreateQuoteController.getQuoteValueJson';
import getDynamicConfiguration from '@salesforce/apex/CreateQuoteController.getDynamicConfiguration';
import getPricingRates from '@salesforce/apex/CreateQuoteController.getPricingRates';
import fetchBlueprintPayload from '@salesforce/apex/CreateQuoteController.fetchBlueprintPayload'; // pull formulas that live in a blueprint, not inline. Reetabrata (14th July 2026)

// Cost Sheet Generator — builds a traceable, styled XLSX from a saved quote.
// Rewritten Reetabrata (14th July 2026):
//  * #NAME? fix — CEILING.MATH/FLOOR.MATH replaced with CEILING(x,1)/FLOOR(x,1),
//    which every Excel version resolves (post-2007 names need an _xlfn. prefix
//    that SheetJS does not write).
//  * Ternaries now convert at ANY paren depth (old ternToIf only handled depth 0,
//    so almost nothing translated). String compares coerce with &"" so
//    (B55&"")="24" matches JS '24'=='24' semantics.
//  * Every live formula is triple-validated before it is written as a live cell:
//    JS-eval(original) == Excel-eval(translation) == the value actually saved on
//    the quote. Any disagreement -> the cell stays a plain value. Wrong numbers
//    can never go live.
//  * Full styling (title bar, section bands, input/live fills, borders, number
//    formats) via the xlsx-js-style
//    build, loaded from the NEW sheetjs_styled static resource on its own
//    window.XLSXStyle global — the existing 'sheetjs' resource is untouched.

// ===== ENGINE START (pure functions — no LWC dependencies) =====

const ENGINE = (() => {

    const num = (v) => { if (v === null || v === undefined || v === '') return null; const n = Number(v); return isNaN(n) ? null : n; };

    // number format that shows EXACTLY the decimals of the saved value — no display
    // rounding (0.079 must render 0.079, not 0.08). Rajeev (17th July 2026)
    const fmtFor = (v) => {
        const n = num(v);
        if (n === null) return '#,##0.00';
        if (Number.isInteger(n)) return '#,##0.00';
        const s = String(n);
        const i = s.indexOf('.');
        if (i === -1 || s.indexOf('e') !== -1) return 'General';
        const dec = Math.min(s.length - i - 1, 9);
        return dec <= 2 ? '#,##0.00' : '#,##0.' + '0'.repeat(dec);
    };

    const pretty = (k) => String(k).replace(/__c$/, '').replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());

    // walk a Section_Logic JSON payload -> flat list of {apiName,label,formula,section}
    const collectFormulas = (payloadObj, out, sectionLabel) => {
        if (Array.isArray(payloadObj)) { payloadObj.forEach(x => collectFormulas(x, out, sectionLabel)); return; }
        if (payloadObj && typeof payloadObj === 'object') {
            let sl = sectionLabel;
            if (payloadObj.id && payloadObj.fields) sl = payloadObj.label || payloadObj.id;
            if (payloadObj.formula && payloadObj.apiName)
                out.push({ apiName: payloadObj.apiName, label: payloadObj.label || '', formula: payloadObj.formula, section: sl || 'General' });
            Object.keys(payloadObj).forEach(k => collectFormulas(payloadObj[k], out, k === 'fields' ? sl : sectionLabel));
        }
    };

    // walk the payload -> catalog[apiName] = {label, section, type, order} for EVERY
    // field (inputs + formulas), so the sheet can show real UI labels and group by
    // the estimator's own sections. Reetabrata (14th July 2026)
    const collectFields = (payloadObj, catalog, sectionLabel, counter) => {
        counter = counter || { n: 0 };
        if (Array.isArray(payloadObj)) { payloadObj.forEach(x => collectFields(x, catalog, sectionLabel, counter)); return catalog; }
        if (payloadObj && typeof payloadObj === 'object') {
            let sl = sectionLabel;
            if (payloadObj.id && payloadObj.fields) sl = payloadObj.label || payloadObj.id;
            if (payloadObj.apiName && !catalog[payloadObj.apiName]) {
                catalog[payloadObj.apiName] = {
                    label: payloadObj.label || '',
                    section: sl || 'General',
                    type: payloadObj.type || '',
                    hasFormula: !!payloadObj.formula,
                    order: counter.n++
                };
            }
            Object.keys(payloadObj).forEach(k => collectFields(payloadObj[k], catalog, k === 'fields' ? sl : sectionLabel, counter));
        }
        return catalog;
    };

    // ─────────────────────────────────────────────────────────────────────────
    // Generic quote-shape normalizer. Reetabrata (14th July 2026)
    // Some departments save a field directly (Standard Pole: d1_rate -> quote.d1_rate).
    // Others save row-prefixed copies (High Mast: blueprint field lm_5_unit_cost is
    // saved as r1_lm_5_unit_cost, r2_lm_5_unit_cost, one "r{n}" per mast row). This
    // rewrites the collected formulas so their apiNames + referenced tokens match the
    // ACTUAL saved keys, with NO department knowledge:
    //   - if a formula's apiName is already a saved key -> keep as-is
    //   - else, for every row-prefix "r{n}_" under which the field is saved, clone the
    //     formula with apiName and all field-token references rewritten to r{n}_<token>
    //     (only tokens that actually exist as r{n}_<token> in the quote are rewritten;
    //     others, e.g. Base_Amount__c, are left for the normal scope to resolve).
    // The result is a formula list that buildWorkbook can consume unchanged for EITHER
    // shape, so the same single code path serves every department.
    // ─────────────────────────────────────────────────────────────────────────
    const normalizeFormulasToQuote = (formulas, catalog, quote) => {
        const savedKeys = new Set(Object.keys(quote));
        const hasVal = (k) => { const v = quote[k]; return v !== '' && v !== null && v !== undefined; };
        // Active row/column prefixes = those that actually carry data. A prefix may also
        // carry an "is_" infix (HDPE column-repeater saves c1_is_X, not c1_X). We record
        // both the prefix and whether it uses the is_ infix. Only prefixes with at least
        // one non-empty field are expanded, so empty grid columns are ignored.
        // Reetabrata (14th July 2026)
        const prefixInfo = {};   // prefix string (e.g. 'c1_') -> { infix: 'is_' | '' }
        savedKeys.forEach(k => {
            const m = k.match(/^((?:r\d+|c\d+|kit_line_\d+)_)(is_)?(.+)/);
            if (m && hasVal(k)) {
                const px = m[1], infix = m[2] || '';
                if (!(px in prefixInfo)) prefixInfo[px] = { infix };
                // prefer the infix form if any key uses it consistently
                if (infix) prefixInfo[px].infix = 'is_';
            }
        });
        const prefixes = Object.keys(prefixInfo);

        // Core-name index for departments whose saved key differs from the metadata
        // apiName by a prefix that ISN'T derivable from the metadata (e.g. HDPE: field
        // p_BOQ_Quantity is saved as c1_is_BOQ_Quantity). Strip leading prefix noise
        // (c{n}_, is_, single-letter d_/p_) to a "core", then map core -> saved key.
        // ONLY cores that map to exactly ONE saved key are usable — if a core is
        // ambiguous (two saved keys share it), we refuse to guess and leave it, so a
        // wrong value can never go live. Reetabrata (14th July 2026)
        const coreOf = (k) => k.replace(/^(c\d+_)?/, '').replace(/^(is_)/, '').replace(/^[a-z]_/, '').toLowerCase();
        const coreIndex = {};       // core -> saved key (only when unique among NON-EMPTY keys)
        const coreCount = {};
        savedKeys.forEach(k => {
            if (!hasVal(k)) return;                              // ignore empty grid columns
            const c = coreOf(k); coreCount[c] = (coreCount[c] || 0) + 1; coreIndex[c] = k;
        });
        const uniqueCore = (apiName) => {
            const c = coreOf(apiName);
            return (coreCount[c] === 1) ? coreIndex[c] : null;   // unique non-empty match or nothing
        };

        const out = [];
        const seen = new Set();
        const pushOnce = (f) => { const key = f.apiName + '|' + f.section; if (!seen.has(key)) { seen.add(key); out.push(f); } };

        formulas.forEach(f => {
            // 1) direct shape (Standard Pole and friends)
            if (savedKeys.has(f.apiName)) { pushOnce(f); return; }

            // 2) row/column-prefixed shape: clone per active prefix where this field is
            //    actually saved (handling an optional is_ infix, e.g. c1_is_X)
            let matchedAny = false;
            prefixes.forEach(px => {
                const infix = prefixInfo[px].infix;
                const savedName = px + infix + f.apiName;
                if (!savedKeys.has(savedName)) return;
                matchedAny = true;
                const newFormula = f.formula.replace(/[a-zA-Z_][a-zA-Z0-9_]*/g, (tok) => {
                    if (tok === f.apiName) return savedName;
                    return savedKeys.has(px + infix + tok) ? (px + infix + tok) : tok;
                });
                const pfxBase = px.replace(/_$/, '');
                let rowLabel;
                if (/^r\d+$/.test(pfxBase)) rowLabel = 'Row ' + pfxBase.slice(1);
                else if (/^c\d+$/.test(pfxBase)) rowLabel = 'Column ' + pfxBase.slice(1);
                else if (/^kit_line_\d+$/.test(pfxBase)) rowLabel = 'KIT Line ' + pfxBase.replace('kit_line_', '');
                else rowLabel = pfxBase.toUpperCase();
                pushOnce({
                    apiName: savedName,
                    label: f.label,
                    formula: newFormula,
                    section: rowLabel + (f.section && f.section !== 'General' ? ' — ' + f.section : '')
                });
                if (catalog[f.apiName] && !catalog[savedName]) {
                    catalog[savedName] = Object.assign({}, catalog[f.apiName]);
                }
            });
            if (matchedAny) return;

            // 3) unique-core match (HDPE-style renamed keys). Only if this formula's own
            //    field resolves to a unique saved key; rewrite referenced tokens the same
            //    way, but only where the token's core is unique too. Reetabrata (14th July 2026)
            const ownSaved = uniqueCore(f.apiName);
            if (ownSaved) {
                // if another formula already resolved to this same saved key (e.g. the
                // pipe and duct branches both map to c1_is_X), keep just the first —
                // they read the same saved inputs and produce the same value.
                if (seen.has(ownSaved + '|__core__')) return;
                seen.add(ownSaved + '|__core__');
                const newFormula = f.formula.replace(/[a-zA-Z_][a-zA-Z0-9_]*/g, (tok) => {
                    if (tok === f.apiName) return ownSaved;
                    const mapped = uniqueCore(tok);
                    return mapped || tok;
                });
                if (!catalog[ownSaved] && catalog[f.apiName]) catalog[ownSaved] = Object.assign({}, catalog[f.apiName]);
                pushOnce({ apiName: ownSaved, label: f.label, formula: newFormula, section: f.section });
                return;
            }

            // 4) no saved value in any shape -> keep original (buildWorkbook treats as unvalued)
            pushOnce(f);
        });
        return out;
    };

    // balanced-paren rewrite of  jsName(arg)  ->  excelName(arg + suffix)
    const fmatch = (s, i) => { let d = 0; while (i < s.length) { if (s[i] === '(') d++; else if (s[i] === ')') { d--; if (d === 0) return i; } i++; } return -1; };

    const wrapFunc = (e, jsName, excelName, suffix) => {
        let out = '', i = 0;
        while (i < e.length) {
            if (e.startsWith(jsName, i)) {
                const j = i + jsName.length, k = fmatch(e, j);
                if (k === -1) { out += e.slice(i); break; }
                out += excelName + '(' + wrapFunc(e.slice(j + 1, k), jsName, excelName, suffix) + (suffix || '') + ')';
                i = k + 1;
            } else { out += e[i]; i++; }
        }
        return out;
    };

    // cond ? a : b  ->  IF(cond,a,b)  — at ANY depth. Chained ternaries nest into
    // IF(c1,v1,IF(c2,v2,...)). Reetabrata (14th July 2026)
    const ternToIf = (s) => {
        let d = 0, q = -1;
        for (let i = 0; i < s.length; i++) { const c = s[i]; if (c === '(') d++; else if (c === ')') d--; else if (c === '?' && d === 0) { q = i; break; } }
        if (q === -1) {
            // no depth-0 ternary here: recurse into every paren group
            let out = '', i = 0;
            while (i < s.length) {
                if (s[i] === '(') {
                    const k = fmatch(s, i);
                    if (k === -1) { out += s.slice(i); break; }
                    out += '(' + ternToIf(s.slice(i + 1, k)) + ')';
                    i = k + 1;
                } else { out += s[i]; i++; }
            }
            return out;
        }
        // matching ':' at depth 0, skipping any nested depth-0 '?'
        let dd = 0, extra = 0, co = -1;
        for (let i = q + 1; i < s.length; i++) {
            const c = s[i];
            if (c === '(') dd++; else if (c === ')') dd--;
            else if (c === '?' && dd === 0) extra++;
            else if (c === ':' && dd === 0) { if (extra === 0) { co = i; break; } extra--; }
        }
        if (co === -1) return s;
        return 'IF(' + ternToIf(s.slice(0, q).trim()) + ',' + ternToIf(s.slice(q + 1, co).trim()) + ',' + ternToIf(s.slice(co + 1).trim()) + ')';
    };

    // JS formula -> Excel formula. Returns {excel, safe}.
    const toExcel = (f) => {
        let e = f.replace(/'([^']*)'/g, '"$1"');
        let prev = null;
        while (prev !== e) { prev = e; e = e.replace(/\|\|\s*0(?![\w.])/g, ''); }        // (x || 0) -> (x); Excel treats blank as 0
        e = e.replace(/typeof\s+\w+\s*!==?\s*"undefined"\s*&&\s*/g, '')
             .replace(/typeof\s+\w+\s*!==?\s*"undefined"/g, 'TRUE');
        e = e.replace(/\bNumber\s*\(/g, '(');
        e = e.replace(/\bparseFloat\s*\(/g, '(');                  // parseFloat(x) -> (x); Excel coerces text to number
        // parseInt(x) -> truncate toward zero. Excel INT() floors, so use the JS-equivalent
        // pattern TRUNC(x). parseInt(x, 10) -> TRUNC(x). Reetabrata (14th July 2026)
        e = wrapFunc(e, 'parseInt', 'TRUNC', '');
        e = e.replace(/,\s*10\s*\)/g, ')');                        // drop the radix arg left inside TRUNC(x,10)
        // x.toFixed(n) -> ROUND(x, n). Uses balanced-paren scan so nested parens in the
        // left operand are handled: ((a*b)/1000).toFixed(2) -> ROUND(((a*b)/1000),2).
        // Reetabrata (14th July 2026)
        {
            let guardTF = 0;
            while (/\.toFixed\s*\(/.test(e) && guardTF++ < 40) {
                const idx = e.search(/\.toFixed\s*\(/);
                // find the left operand: either a balanced ")...(" group or a bare token
                let ls, left;
                if (e[idx - 1] === ')') {
                    // scan back to the matching "("
                    let depth = 0, j = idx - 1;
                    for (; j >= 0; j--) { if (e[j] === ')') depth++; else if (e[j] === '(') { depth--; if (depth === 0) break; } }
                    ls = j; left = e.slice(j, idx);
                } else {
                    let j = idx - 1;
                    while (j >= 0 && /[A-Za-z0-9_.]/.test(e[j])) j--;
                    ls = j + 1; left = e.slice(ls, idx);
                }
                const nMatch = e.slice(idx).match(/\.toFixed\s*\(\s*(\d+)\s*\)/);
                if (!nMatch) break;
                const digits = nMatch[1];
                const after = idx + nMatch[0].length;
                e = e.slice(0, ls) + 'ROUND(' + left + ',' + digits + ')' + e.slice(after);
            }
        }
        // null comparisons: Excel has no null. `x !== null` would ship the bare token null
        // (-> #NAME?), and in the evaluators it became `var null=0` — a SyntaxError that
        // silently forced every tower formula to a static value. The estimator uses it as an
        // "is this answered" guard and a blank cell reads as "" through &"", so translate it
        // to the same blank test `!= ''` already gets. Must run before the string-comparison
        // rules and before === collapses to =. Reetabrata (16th July 2026)
        e = e.replace(/([A-Za-z_][A-Za-z0-9_]*)\s*!==?\s*null\b/g, '(($1&"")<>"")');
        e = e.replace(/([A-Za-z_][A-Za-z0-9_]*)\s*===?\s*null\b/g, '(($1&"")="")');
        e = e.replace(/\bnull\s*!==?\s*([A-Za-z_][A-Za-z0-9_]*)/g, '(($1&"")<>"")');
        e = e.replace(/\bnull\s*===?\s*([A-Za-z_][A-Za-z0-9_]*)/g, '(($1&"")="")');
        // string comparisons: coerce the field to text so 24 = "24" works like JS.
        // Outer parens are required — Excel's & and + bind tighter than =. Reetabrata (14th July 2026)
        e = e.replace(/([A-Za-z_][A-Za-z0-9_]*)\s*===?\s*"([^"]*)"/g, '(($1&"")="$2")');
        e = e.replace(/([A-Za-z_][A-Za-z0-9_]*)\s*!==?\s*"([^"]*)"/g, '(($1&"")<>"$2")');
        if (e.includes('Math.round(')) e = wrapFunc(e, 'Math.round', 'ROUND', ',0');
        if (e.includes('Math.ceil(')) e = wrapFunc(e, 'Math.ceil', 'CEILING', ',1');    // #NAME? fix: NOT CEILING.MATH
        // trig / power / roots used by High Mast & Octagonal weight formulas. Reetabrata (14th July 2026)
        if (e.includes('Math.pow(')) e = wrapFunc(e, 'Math.pow', 'POWER', '');
        if (e.includes('Math.sqrt(')) e = wrapFunc(e, 'Math.sqrt', 'SQRT', '');
        if (e.includes('Math.tan(')) e = wrapFunc(e, 'Math.tan', 'TAN', '');
        if (e.includes('Math.sin(')) e = wrapFunc(e, 'Math.sin', 'SIN', '');
        if (e.includes('Math.cos(')) e = wrapFunc(e, 'Math.cos', 'COS', '');
        if (e.includes('Math.abs(')) e = wrapFunc(e, 'Math.abs', 'ABS', '');
        e = e.replace(/Math\.PI\b/g, 'PI()');
        if (e.includes('Math.floor(')) e = wrapFunc(e, 'Math.floor', 'FLOOR', ',1');    // #NAME? fix: NOT FLOOR.MATH
        e = e.replace(/===/g, '=').replace(/!==/g, '<>').replace(/==/g, '=').replace(/!=/g, '<>');
        let g = 0;
        while (e.includes('?') && g < 50) { const n = ternToIf(e); if (n === e) break; e = n; g++; }
        // remaining booleans: TRUE/FALSE arithmetic — a&&b -> a*b, a||b -> a+b (IF treats nonzero as TRUE)
        e = e.replace(/&&/g, '*').replace(/\|\|/g, '+');
        const hard = e.includes('?') || e.includes('typeof') || e.includes('Math.') || /\bNumber\s*\(/.test(e) || /\bnull\b/.test(e);   // bare null would be #NAME? in Excel. Reetabrata (16th July 2026)
        return { excel: e, safe: !hard };
    };

    const EXCEL_WORDS = new Set(['ROUND', 'CEILING', 'FLOOR', 'IF', 'TRUE', 'FALSE', 'POWER', 'SQRT', 'TAN', 'SIN', 'COS', 'ABS', 'PI', 'TRUNC']);

    // apply fn only to the parts of the formula OUTSIDE quoted string literals,
    // so "Galvanized" / "Per pcs" etc. are never rewritten. Reetabrata (14th July 2026)
    const outsideStrings = (expr, fn) =>
        expr.split(/("(?:[^"\\]|\\.)*")/).map((part, i) => (i % 2 === 1 ? part : fn(part))).join('');

    // evaluate the ORIGINAL JS formula against the quote scope (this is exactly
    // what the estimator engine does, so it must reproduce the saved value)
    const jsEval = (formula, scope) => {
        try {
            const ids = new Set(formula.match(/[a-zA-Z_$][a-zA-Z0-9_$]*/g) || []);
            let pre = '';
            ids.forEach(id => {
                if (['Math', 'Number', 'typeof', 'undefined', 'null', 'true', 'false', 'String'].includes(id)) return;   // null: keep the JS literal. Reetabrata (16th July 2026)
                pre += (id in scope) ? `var ${id}=${JSON.stringify(scope[id])};` : `var ${id}=0;`;
            });
            // eslint-disable-next-line no-new-func
            const v = Function('"use strict";' + pre + 'return (' + formula + ');')();
            // .toFixed()/string-number results (e.g. "79.80") coerce back to number so the
            // triple-gate can compare them. Reetabrata (14th July 2026)
            if (typeof v === 'string' && v.trim() !== '' && !isNaN(Number(v))) return Number(v);
            return (typeof v === 'number' && isFinite(v)) ? v : null;
        } catch (x) { return null; }
    };

    // evaluate the TRANSLATED Excel formula (before cell substitution) in JS,
    // using helpers that mirror Excel exactly. Reetabrata (14th July 2026)
    const xlEval = (excel, scope) => {
        try {
            let e = excel;
            e = e.replace(/\bCEILING\(/g, '__CEIL(').replace(/\bFLOOR\(/g, '__FLR(')
                 .replace(/\bROUND\(/g, '__RND(').replace(/\bIF\(/g, '__IF(').replace(/\bTRUNC\(/g, '__TRUNC(');
            // Excel math funcs back to JS Math for validation. Reetabrata (14th July 2026)
            e = e.replace(/\bPOWER\(/g, 'Math.pow(').replace(/\bSQRT\(/g, 'Math.sqrt(')
                 .replace(/\bTAN\(/g, 'Math.tan(').replace(/\bSIN\(/g, 'Math.sin(')
                 .replace(/\bCOS\(/g, 'Math.cos(').replace(/\bABS\(/g, 'Math.abs(')
                 .replace(/\bPI\(\)/g, 'Math.PI');
            e = e.replace(/&""/g, '+""');
            e = e.replace(/<>/g, '!=').replace(/([^<>=!])=([^=])/g, '$1==$2');
            e = e.replace(/\bTRUE\b/g, 'true').replace(/\bFALSE\b/g, 'false');
            const ids = new Set(e.match(/[a-zA-Z_$][a-zA-Z0-9_$]*/g) || []);
            let pre = 'function __CEIL(x,s){return Math.ceil(x/s)*s;}function __FLR(x,s){return Math.floor(x/s)*s;}'
                    + 'function __RND(x,n){var m=Math.pow(10,n);return Math.round(x*m)/m;}function __IF(c,a,b){return c?a:b;}'
                    + 'function __TRUNC(x,n){var m=Math.pow(10,n||0);return Math.sign(x)*Math.floor(Math.abs(x)*m)/m;}';
            ids.forEach(id => {
                if (['__CEIL', '__FLR', '__RND', '__IF', '__TRUNC', 'Math', 'true', 'false', 'null', 'undefined', 'pow', 'sqrt', 'tan', 'sin', 'cos', 'abs', 'PI'].includes(id)) return;   // Reetabrata (16th July 2026)
                pre += (id in scope) ? `var ${id}=${JSON.stringify(scope[id])};` : `var ${id}=0;`;
            });
            // eslint-disable-next-line no-new-func
            const v = Function('"use strict";' + pre + 'return (' + e + ');')();
            return (typeof v === 'number' && isFinite(v)) ? v : null;
        } catch (x) { return null; }
    };

    // human-friendly version of a JS formula for the Details column
    const plainFormula = (f) => f
        .replace(/\|\|\s*0(?![\w.])/g, '')
        .replace(/typeof\s+\w+\s*!==?\s*['"]undefined['"]\s*&&\s*/g, '')
        .replace(/Math\.round/g, 'round').replace(/Math\.ceil/g, 'round up to').replace(/Math\.floor/g, 'round down to')
        .replace(/Number\(/g, '(')
        .replace(/===?/g, ' is ').replace(/!==?/g, ' is not ')
        .replace(/&&/g, ' and ').replace(/\|\|/g, ' or ')
        .replace(/\?/g, ' then ').replace(/:/g, ' else ')
        .replace(/\(\s+/g, '(').replace(/\s+\)/g, ')').replace(/\s{2,}/g, ' ').trim();

    const tidy = (e) => e.replace(/\(\s+/g, '(').replace(/\s+\)/g, ')').replace(/\s{2,}/g, ' ').trim();

    // ---------- workbook builder ----------
    // XLSX: the sheetjs / xlsx-js-style global. catalog: apiName -> {label,section,type,order}. Returns the workbook.
    const buildWorkbook = (XLSX, quote, rateCard, baseAmount, gst, formulas, catalog) => {
        catalog = catalog || {};
        const fmap = {}; formulas.forEach(f => { fmap[f.apiName] = f; });

        // real UI label for any apiName (catalog first, then formula label, then decoded api). Reetabrata (14th July 2026)
        const labelOf = (api) => {
            const c = catalog[api];
            if (c && c.label && c.label.trim()) return c.label.trim();
            if (fmap[api] && fmap[api].label) return fmap[api].label;
            return pretty(api);
        };
        const sectionOf = (api) => (catalog[api] && catalog[api].section) || (fmap[api] && fmap[api].section) || 'General';
        const orderOf = (api) => (catalog[api] ? catalog[api].order : 99999);

        // ---- evaluation scope: user inputs + rate card + pricing constants ----
        const scope = {};
        Object.keys(quote).forEach(k => { const n = Number(quote[k]); scope[k] = (quote[k] !== '' && quote[k] !== null && !isNaN(n)) ? n : quote[k]; });
        Object.keys(rateCard).forEach(k => { scope[k] = rateCard[k]; });
        scope.Base_Amount__c = baseAmount; scope.GST__c = gst;

        // ---- decide which formulas can go live (triple agreement) ----
        const valued = formulas.filter(f => num(quote[f.apiName]) !== null);
        const liveSet = new Set();
        valued.forEach(f => {
            const { excel, safe } = toExcel(f.formula);
            if (!safe) return;
            const jv = jsEval(f.formula, scope);
            const xv = xlEval(excel, scope);
            const sv = num(quote[f.apiName]);
            if (jv !== null && xv !== null && sv !== null
                && Math.abs(jv - xv) < 0.05 && Math.abs(jv - sv) <= Math.max(0.05, Math.abs(sv) * 0.0005)) liveSet.add(f.apiName);
        });

        // ---- disambiguate duplicate labels (e.g. many "Rate / PCS", repeated
        //      "Reflect in offer?" inputs) with a short suffix. Count across BOTH
        //      inputs and calculated fields. Reetabrata (14th July 2026)
        const labelCount = {};
        const bumpLabel = (api) => { const L = labelOf(api); labelCount[L] = (labelCount[L] || 0) + 1; };
        valued.forEach(f => bumpLabel(f.apiName));
        {
            const refd = new Set();
            formulas.forEach(f => (f.formula.match(/[a-zA-Z_][a-zA-Z0-9_]*/g) || []).forEach(t => refd.add(t)));
            refd.forEach(t => { if (!fmap[t] && quote[t] !== undefined && quote[t] !== null && quote[t] !== '') bumpLabel(t); });
        }
        const shortApi = (api) => pretty(api).replace(/^D\d+\s+/i, '');
        const displayLabel = (api) => {
            const L = labelOf(api);
            return labelCount[L] > 1 ? `${L}  (${shortApi(api)})` : L;
        };

        // ---- styles ----
        const B = { style: 'thin', color: { rgb: 'B7C3D6' } };
        const border = { top: B, bottom: B, left: B, right: B };
        const F = (o) => Object.assign({ name: 'Arial', sz: 10 }, o);
        const ST = {
            title:    { font: F({ sz: 15, bold: true, color: { rgb: 'FFFFFF' } }), fill: { patternType: 'solid', fgColor: { rgb: '1F4E79' } }, alignment: { vertical: 'center' } },
            note:     { font: F({ sz: 9, italic: true, color: { rgb: '7F7F7F' } }) },
            sumHead:  { font: F({ sz: 11, bold: true, color: { rgb: 'FFFFFF' } }), fill: { patternType: 'solid', fgColor: { rgb: '548235' } }, alignment: { vertical: 'center' } },
            sumLabel: { font: F({ sz: 11, bold: true, color: { rgb: '1F4E79' } }), fill: { patternType: 'solid', fgColor: { rgb: 'E2EFDA' } }, border },
            sumVal:   { font: F({ sz: 12, bold: true, color: { rgb: '375623' } }), fill: { patternType: 'solid', fgColor: { rgb: 'E2EFDA' } }, border, alignment: { horizontal: 'right' } },
            secHead:  { font: F({ sz: 11, bold: true, color: { rgb: 'FFFFFF' } }), fill: { patternType: 'solid', fgColor: { rgb: '305496' } }, alignment: { vertical: 'center' } },
            subHead:  { font: F({ bold: true, color: { rgb: '1F4E79' } }), fill: { patternType: 'solid', fgColor: { rgb: 'D9E1F2' } }, border },
            colHead:  { font: F({ bold: true }), fill: { patternType: 'solid', fgColor: { rgb: 'E9EDF4' } }, border },
            label:    { font: F({}), border },
            input:    { font: F({}), fill: { patternType: 'solid', fgColor: { rgb: 'FFF2CC' } }, border, alignment: { horizontal: 'right' } },
            inputTxt: { font: F({}), fill: { patternType: 'solid', fgColor: { rgb: 'FFF2CC' } }, border },
            src:      { font: F({ sz: 9, color: { rgb: '7F7F7F' } }), border },
            live:     { font: F({ bold: true }), fill: { patternType: 'solid', fgColor: { rgb: 'E2EFDA' } }, border, alignment: { horizontal: 'right' } },
            amt:      { font: F({}), border, alignment: { horizontal: 'right' } },
            final:    { font: F({ bold: true }), fill: { patternType: 'solid', fgColor: { rgb: 'FCE4D6' } }, border, alignment: { horizontal: 'right' } },
            finalLbl: { font: F({ bold: true }), fill: { patternType: 'solid', fgColor: { rgb: 'FCE4D6' } }, border },
            frm:      { font: F({ sz: 9, color: { rgb: '7F7F7F' } }), border }
        };

        const aoa = []; const merges = []; const styleMap = {}; const fmtMap = {}; const rowHts = {};
        let R = 0;
        const push = (arr) => { aoa.push(arr); return ++R; };
        const styleRow = (rn, styles) => { ['A', 'B', 'C'].forEach((col, i) => { if (styles[i]) styleMap[col + rn] = styles[i]; }); };
        const mergeRow = (rn) => merges.push({ s: { r: rn - 1, c: 0 }, e: { r: rn - 1, c: 2 } });

        const cell = {};
        const addrVal = {};

        // ---- header ----
        let prodName = quote._Dynamic_Product_Name || quote.type_of_pole || 'Quote';
        if (prodName === 'PEB QFR') prodName = 'PEB QRF';
        let rn = push([`COST SHEET — ${prodName}`]); mergeRow(rn); styleRow(rn, [ST.title, ST.title, ST.title]); rowHts[rn] = 28;
        rn = push(['Yellow cells are inputs. Green amounts are live Excel formulas — edit an input and the totals recalculate.']);
        mergeRow(rn); styleRow(rn, [ST.note]);
        push([]);

        // ---- SUMMARY / RESULTS box (formulas filled after calc rows are placed) ----
        rn = push(['SUMMARY']); mergeRow(rn); styleRow(rn, [ST.sumHead, ST.sumHead, ST.sumHead]); rowHts[rn] = 20;
        // choose headline fields: match by label keyword, fall back to apiName hints
        const wantSummary = [
            { key: /final\s*list\s*price/i, label: 'Final List Price' },
            { key: /final\s*unit\s*cost/i, label: 'Final Unit Cost' },
            { key: /final\s*total\s*amount/i, label: 'Final Total Amount' },
            { key: /pole\s*total\s*amount/i, label: 'Pole Total Amount' }
        ];
        const summarySlots = [];
        wantSummary.forEach(w => {
            const match = valued.find(f => w.key.test(labelOf(f.apiName)) || w.key.test(f.label || ''));
            if (match && !summarySlots.some(s => s.api === match.apiName)) {
                const r = push([w.label, null, null]);
                styleRow(r, [ST.sumLabel, ST.sumVal, ST.sumLabel]);
                merges.push({ s: { r: r - 1, c: 1 }, e: { r: r - 1, c: 2 } });
                fmtMap['B' + r] = '#,##0.00';
                summarySlots.push({ api: match.apiName, row: r });
            }
        });
        if (!summarySlots.length) { const r = push(['(totals appear once the quote has calculated values)']); mergeRow(r); styleRow(r, [ST.note]); }
        push([]);

        // ---- USER INPUTS & RATES, grouped by section with real labels ----
        rn = push(['USER INPUTS & RATES']); mergeRow(rn); styleRow(rn, [ST.secHead, ST.secHead, ST.secHead]); rowHts[rn] = 20;

        const addValRow = (labelText, v, src, isText) => {
            const r = push([labelText, v, src]);
            styleRow(r, [ST.label, isText ? ST.inputTxt : ST.input, ST.src]);
            if (!isText) fmtMap['B' + r] = '#,##0.####';
            return r;
        };

        // pricing constants first (their own mini-group)
        let r = push(['Pricing & Rates']); mergeRow(r); styleRow(r, [ST.subHead, ST.subHead, ST.subHead]);
        const addConst = (k, v, src) => { const rr = addValRow(k === 'GST__c' ? 'GST (multiplier)' : k === 'Base_Amount__c' ? 'Base Amount' : pretty(k), v, src, false); cell[k] = 'B' + rr; addrVal['B' + rr] = v; };
        Object.keys(rateCard).forEach(k => addConst(k, rateCard[k], 'Rate Card'));
        addConst('GST__c', gst, 'Price Calculator');
        addConst('Base_Amount__c', baseAmount, 'Price Calculator');

        // remaining referenced inputs, grouped by their metadata section
        const referenced = new Set();
        formulas.forEach(f => (f.formula.match(/[a-zA-Z_][a-zA-Z0-9_]*/g) || []).forEach(t => referenced.add(t)));
        const inputApis = [...referenced].filter(t => {
            if (cell[t] || fmap[t]) return false;                 // skip constants already shown + formula fields
            const v = quote[t];
            return !(v === null || v === undefined || v === '');
        });
        // group -> section, ordered by metadata order
        const inSections = []; const inBy = {};
        inputApis.forEach(a => { const s = sectionOf(a); if (!inBy[s]) { inBy[s] = []; inSections.push(s); } inBy[s].push(a); });
        inSections.forEach(s => {
            const rows = inBy[s].slice().sort((x, y) => orderOf(x) - orderOf(y));
            r = push([s === 'General' ? 'Other Inputs' : s]); mergeRow(r); styleRow(r, [ST.subHead, ST.subHead, ST.subHead]);
            rows.forEach(a => {
                const raw = quote[a];
                const isNum = num(raw) !== null;
                const rr = addValRow(displayLabel(a), isNum ? Number(raw) : raw, catalog[a] ? 'Entered by user' : 'Entered by user', !isNum);
                cell[a] = 'B' + rr; addrVal['B' + rr] = raw;
            });
        });
        push([]);

        // ---- CALCULATED FIELDS, grouped by section ----
        rn = push(['CALCULATED FIELDS']); mergeRow(rn); styleRow(rn, [ST.secHead, ST.secHead, ST.secHead]); rowHts[rn] = 20;
        rn = push(['Field', 'Amount', 'How it is calculated']); styleRow(rn, [ST.colHead, ST.colHead, ST.colHead]);

        const sections = []; const bySection = {};
        valued.forEach(f => { const s = sectionOf(f.apiName); if (!bySection[s]) { bySection[s] = []; sections.push(s); } bySection[s].push(f); });

        // pass 1: place rows, assign cells
        const placedRows = [];
        sections.forEach(s => {
            const r2 = push([s]); mergeRow(r2); styleRow(r2, [ST.subHead, ST.subHead, ST.subHead]);
            bySection[s].slice().sort((x, y) => orderOf(x.apiName) - orderOf(y.apiName)).forEach(f => {
                const r3 = push([displayLabel(f.apiName), null, null]);
                cell[f.apiName] = 'B' + r3;
                addrVal['B' + r3] = quote[f.apiName];
                placedRows.push({ f, row: r3 });
            });
        });

        // pass 2: fill amounts + formulas
        // pass 2: fill amounts + formulas. Three tiers now: (1) cell-referenced live,
        // (2) literal live (all tokens inlined; used when refs are impossible), then
        // (3) static value. Tiers 1–2 are both triple-validated, so every live cell
        // still provably equals the saved quote value. Rajeev (17th July 2026)
        placedRows.forEach(({ f, row }) => {
            const isFinal = /^final|total amount/i.test(labelOf(f.apiName));
            const sv = num(quote[f.apiName]);
            const tol = Math.max(0.05, Math.abs(sv === null ? 0 : sv) * 0.0005);

            // Excel accepts NUMERIC IF conditions (nonzero = TRUE) natively; only a
            // text-literal condition #VALUE!s. Convert inlined text conditions the way
            // JS truthiness sees them: non-empty -> TRUE, empty -> FALSE. Reetabrata (17th July 2026)
            const fixIfText = (s) => {
                let prev = null, out = s;
                while (prev !== out) { prev = out; out = out.replace(/IF\(\s*"([^"]*)"\s*,/g, (m, t) => 'IF(' + (t !== '' ? 'TRUE' : 'FALSE') + ',');
                }
                return out;
            };

            const tr = toExcel(f.formula);
            let mode = 'static';
            let exl = '';

            if (tr.safe && sv !== null) {

                // ---- tier 1: cell-referenced live (unchanged logic) ----
                let live = liveSet.has(f.apiName);
                if (live) {
                    exl = tr.excel;
                    exl = outsideStrings(exl, part => {
                        (part.match(/[a-zA-Z_][a-zA-Z0-9_]*/g) || []).forEach(t => {
                            if (EXCEL_WORDS.has(t)) return;
                            if (cell[t]) part = part.replace(new RegExp('\\b' + t + '\\b', 'g'), cell[t]);
                            else if (fmap[t]) live = false;
                            else part = part.replace(new RegExp('\\b' + t + '\\b', 'g'), '0');
                        });
                        return part;
                    });
                    exl = tidy(exl);
                    if (live) {
                        const ownAddr = cell[f.apiName];
                        if ((exl.match(/\b[A-Z]{1,2}[0-9]{1,4}\b/g) || []).includes(ownAddr)) live = false;
                        if (live) {
                            const ownRow = Number(String(ownAddr).replace(/^[A-Z]+/, ''));
                            for (const addr of (exl.match(/\b[A-Z]{1,2}[0-9]{1,4}\b/g) || [])) {
                                const b2 = Object.keys(cell).find(bb => cell[bb] === addr);
                                if (b2 !== undefined && fmap[b2] && Number(addr.replace(/^[A-Z]+/, '')) >= ownRow) { live = false; break; }
                            }
                        }
                        if (live) {
                            const keepRefs = [];
                            let masked = exl.replace(/\(\s*([A-Z]{1,2}[0-9]{1,4})\s*&""\)/g, (m0) => {
                                keepRefs.push(m0); return '\u0002' + (keepRefs.length - 1) + '\u0002';
                            });
                            masked = outsideStrings(masked, part =>
                                part.replace(/\b([A-Z]{1,2}[0-9]{1,4})\b/g, (m, addr) => {
                                    if (!(addr in addrVal)) return m;
                                    const v = addrVal[addr];
                                    if (v === '' || v === null || v === undefined || isNaN(Number(v))) {
                                        const s2 = String(v == null ? '' : v).toLowerCase();
                                        if (s2 === 'true' || v === true) return 'TRUE';
                                        if (s2 === 'false' || v === false) return 'FALSE';
                                        return '"' + String(v).replace(/"/g, '') + '"';
                                    }
                                    return m;
                                }));
                            exl = masked.replace(/\u0002(\d+)\u0002/g, (m0, i) => keepRefs[Number(i)]);
                            exl = fixIfText(exl);                                   // Reetabrata (17th July 2026)
                        }
                        if (live) {
                            const resolved = outsideStrings(exl, part =>
                                part.replace(/\b([A-Z]{1,2}[0-9]{1,4})\b/g, (m, addr) => {
                                    if (!(addr in addrVal)) return m;
                                    const v = addrVal[addr];
                                    const n = Number(v);
                                    return (v !== '' && v !== null && v !== undefined && !isNaN(n)) ? '(' + n + ')' : JSON.stringify(String(v == null ? '' : v));
                                }));
                            const fv = xlEval(fixIfText(resolved), {});
                            if (fv === null || Math.abs(fv - sv) > tol) live = false;
                            if (live && /IF\(\s*"[^"]*"\s*,/.test(exl)) live = false;   // text condition survived: refuse (numeric IF is fine now)
                        }
                    }
                    if (live) mode = 'refs';
                }

                // ---- tier 2: literal live — every token inlined from the evaluation
                // scope. No cell refs => immune to cycles / unvalued formula refs, so
                // the full computation is always visible on double-click. Reetabrata (17th July 2026)
                if (mode === 'static') {
                    let lit = fixIfText(outsideStrings(tr.excel, part =>
                        part.replace(/\b[a-zA-Z_][a-zA-Z0-9_]*\b/g, (tok) => {
                            if (EXCEL_WORDS.has(tok)) return tok;
                            let v = (tok in scope) ? scope[tok] : 0;
                            if (fmap[tok]) { const fn = num(quote[tok]); v = (fn !== null) ? fn : v; }   // formula token -> its saved value
                            if (v === true || String(v).toLowerCase() === 'true') return 'TRUE';
                            if (v === false || String(v).toLowerCase() === 'false') return 'FALSE';
                            const n = Number(v);
                            if (v !== '' && v !== null && v !== undefined && !isNaN(n)) return '(' + n + ')';
                            return '"' + String(v == null ? '' : v).replace(/"/g, '') + '"';
                        })));
                    lit = tidy(lit);
                    if (!/IF\(\s*"[^"]*"\s*,/.test(lit)) {
                        const fv = xlEval(lit, {});
                        if (fv !== null && Math.abs(fv - sv) <= tol) { exl = lit; mode = 'literal'; }
                    }
                }
            }

            const r0 = row - 1;
            if (mode !== 'static') {
                aoa[r0][1] = { f: exl };
                aoa[r0][2] = '= ' + exl;
                styleMap['B' + row] = isFinal ? ST.final : ST.live;
            } else {
                const v = num(quote[f.apiName]);
                aoa[r0][1] = (v !== null) ? v : quote[f.apiName];
                aoa[r0][2] = plainFormula(f.formula);
                styleMap['B' + row] = isFinal ? ST.final : ST.amt;
            }
            styleMap['A' + row] = isFinal ? ST.finalLbl : ST.label;
            styleMap['C' + row] = ST.frm;
            fmtMap['B' + row] = fmtFor(quote[f.apiName]);      // exact-precision display. Reetabrata (17th July 2026)
        });

        // ---- fill SUMMARY values now that calc cells exist (live ref if available) ----
        summarySlots.forEach(({ api, row }) => {
            const r0 = row - 1;
            if (cell[api]) { aoa[r0][1] = { f: cell[api] }; }
            else { const v = num(quote[api]); aoa[r0][1] = (v !== null) ? v : quote[api]; }
            fmtMap['B' + row] = fmtFor(quote[api]);            // Rajeev (17th July 2026)
        });

        // ---- assemble ----
        const ws = XLSX.utils.aoa_to_sheet(aoa);
        ws['!merges'] = merges;
        ws['!cols'] = [{ wch: 46 }, { wch: 18 }, { wch: 78 }];
        ws['!rows'] = [];
        Object.keys(rowHts).forEach(rr => { ws['!rows'][rr - 1] = { hpt: rowHts[rr] }; });
        Object.keys(styleMap).forEach(addr => { if (ws[addr]) ws[addr].s = styleMap[addr]; });
        Object.keys(fmtMap).forEach(addr => { if (ws[addr] && (typeof ws[addr].v === 'number' || ws[addr].f)) ws[addr].z = fmtMap[addr]; });
        ws['!freeze'] = { xSplit: 0, ySplit: 2 };  // keep title visible (honored by xlsx-js-style)

        const wb = XLSX.utils.book_new();
        XLSX.utils.book_append_sheet(wb, ws, 'Cost Sheet');
        return { wb, liveCount: liveSet.size, totalValued: valued.length };
    };

    return { num, pretty, collectFormulas, collectFields, normalizeFormulasToQuote, toExcel, jsEval, xlEval, buildWorkbook, plainFormula };
})();

// ===== ENGINE END =====

export default class CostSheetGenerator extends NavigationMixin(LightningElement) {
    @api recordId;              // Quote Id
    @api templateName;          // e.g. "Steel Tubular Pole - Department"
    @api departmentName;        // for getPricingRates
    @track isBusy = false;
    _sheetReady = false;

    async connectedCallback() {
        try { await loadScript(this, SHEETJS_STYLED); this._sheetReady = true; }
        catch (e) { this._toast('Could not load the spreadsheet engine.'); }
    }

    // dedicated global from sheetjs_styled; falls back to window.XLSX just in case. Reetabrata (14th July 2026)
    get _XLSX() { return window.XLSXStyle || window.XLSX; }

    async handleGenerate() {
        // eslint-disable-next-line no-console
        console.log('[CostSheet] FORM_FACTOR =', FORM_FACTOR);
        if (!this._sheetReady) { this._toast('Spreadsheet engine still loading, try again.'); return; }
        this.isBusy = true;
        try {
            const [rawJson, config, rates] = await Promise.all([
                getQuoteValueJson({ quoteId: this.recordId }),
                getDynamicConfiguration({ templateName: this.templateName }),
                getPricingRates({ departmentName: this.departmentName })
            ]);
            if (!rawJson) { this._toast('This quote has no saved values yet.'); this.isBusy = false; return; }
            const quote = JSON.parse(rawJson);

            // rate card: accept either [{apiName,defaultValue}] or a flat {api:value} map. Reetabrata (14th July 2026)
            const rateCard = {};
            try {
                const rc = JSON.parse(rates.JSON_Payload__c);
                if (Array.isArray(rc)) rc.forEach(x => { if (x && x.apiName !== undefined) rateCard[x.apiName] = Number(x.defaultValue); });
                else if (rc && typeof rc === 'object') Object.keys(rc).forEach(k => { const n = Number(rc[k]); if (!isNaN(n)) rateCard[k] = n; });
            } catch (e) { /* no rate card — inputs fall back to quote values */ }
            // Base amount & GST live on the QUOTE (per-quote), not the department
            // metadata — the estimator evaluates formulas against the quote's own
            // values. The Price_Calculator__mdt often has Base_Amount__c = 0, so
            // preferring it (old bug) wrote 0 into the input cell that every base-
            // price formula points at. Prefer the quote; fall back to metadata only
            // when the quote genuinely has no value. Reetabrata (14th July 2026)
            const pick = (...vals) => {
                for (const v of vals) {
                    if (v === null || v === undefined || v === '') continue;
                    const n = Number(v);
                    if (!isNaN(n)) return n;
                }
                return null;
            };
            const baseAmount = pick(quote.Base_Amount__c, rates.Base_Amount__c) ?? 0;
            const gst = pick(quote.GST__c, rates.GST__c) ?? 1.18;

            const formulas = [];
            const catalog = {};
            const blueprintIds = new Set();
            (config.logicRules || []).forEach(r => {
                try {
                    const parsed = JSON.parse(r.JSON_Payload__c);
                    ENGINE.collectFormulas(parsed, formulas);
                    ENGINE.collectFields(parsed, catalog);            // real labels + sections. Reetabrata (14th July 2026)
                } catch (e) { /* skip bad payloads */ }
                // Some departments keep their fields/formulas in a Blueprint (fetched
                // separately), not inline. Collect the blueprint Id so we can pull them
                // too — same generic type:formula detection, no per-department logic.
                // Reetabrata (14th July 2026)
                if (r.Blueprint_Library__c) blueprintIds.add(r.Blueprint_Library__c);
            });
            // fetch each referenced blueprint and merge its fields/formulas
            await Promise.all([...blueprintIds].map(async (bpId) => {
                try {
                    const bp = await fetchBlueprintPayload({ blueprintId: bpId });
                    if (!bp) return;
                    const parsed = (typeof bp === 'string') ? JSON.parse(bp) : bp;
                    ENGINE.collectFormulas(parsed, formulas);
                    ENGINE.collectFields(parsed, catalog);
                } catch (e) { /* a blueprint failed to load — sheet still builds from what loaded */ }
            }));

            // Some departments (e.g. Solar Structure) keep their fields/formulas in the
            // Price_Calculator record's own JSON_Payload__c rather than a Section_Logic
            // rule. Collect from it too — same generic type:formula detection. The rate-
            // card constant parse above is unaffected. Reetabrata (14th July 2026)
            try {
                if (rates && rates.JSON_Payload__c) {
                    const rp = JSON.parse(rates.JSON_Payload__c);
                    ENGINE.collectFormulas(rp, formulas);
                    ENGINE.collectFields(rp, catalog);
                }
            } catch (e) { /* pricing payload isn't field JSON — fine, it was the rate card */ }

            // Normalize formulas to the quote's actual key shape (direct vs row-prefixed)
            // so the same builder works for every department. Reetabrata (14th July 2026)
            const normalizedFormulas = ENGINE.normalizeFormulasToQuote(formulas, catalog, quote);

            const { wb } = ENGINE.buildWorkbook(this._XLSX, quote, rateCard, baseAmount, gst, normalizedFormulas, catalog);
            let prodName = quote._Dynamic_Product_Name || quote.type_of_pole || 'Quote';
            if (prodName === 'PEB QFR') prodName = 'PEB QRF';
            const fileName = `Cost_Sheet_${String(prodName).replace(/\s+/g, '_')}.xlsx`;
            if (FORM_FACTOR === 'Large') {
                // DESKTOP: unchanged - browser download via SheetJS.
                this._XLSX.writeFile(wb, fileName);
                this._toast('Cost sheet downloaded.', 'success');
            } else {
                // MOBILE: same workbook, but writeFile's <a download> click is
                // swallowed by the app's webview - so hand the bytes to Apex.
                // The file is saved PRIVATE (finalize owns the quote's copies).
                // If the org returns a ContentDistribution download URL, open it
                // in the SYSTEM browser - that downloads straight into phone
                // storage; otherwise fall back to the in-app previewer (its
                // share icon can still save to the phone). Deepanjan (18th July 2026)
                const res = await saveGeneratedFile({
                    recordId: this.recordId,
                    base64Data: this._XLSX.write(wb, { bookType: 'xlsx', type: 'base64' }),
                    fileName: fileName
                });
                const openUrl = res && (res.publicUrl || res.downloadUrl);
                if (openUrl) {
                    // publicUrl first: the app's URL validator rejects the long
                    // ContentDownloadUrl but accepts the short /a/<token> link,
                    // whose page has its own Download button. Deepanjan (18th July 2026)
                    this._toast('Cost sheet ready - tap Download on the page that opens.', 'success');
                    this[NavigationMixin.Navigate]({
                        type: 'standard__webPage',
                        attributes: { url: openUrl }
                    });
                } else {
                    this._toast('Cost sheet saved to Files. Use the share icon to save it to your phone.', 'success');
                    this[NavigationMixin.Navigate]({
                        type: 'standard__namedPage',
                        attributes: { pageName: 'filePreview' },
                        state: { selectedRecordId: res ? res.contentDocumentId : null }
                    });
                }
            }
        } catch (e) {
            this._toast('Could not build the cost sheet: ' + (e.body?.message || e.message || e));
        }
        this.isBusy = false;
    }

    _toast(msg, variant) {
        this.dispatchEvent(new CustomEvent('costsheettoast', { detail: { msg, variant: variant || 'error' } }));
        // eslint-disable-next-line no-console
        console.log('[CostSheet]', msg);
    }
}
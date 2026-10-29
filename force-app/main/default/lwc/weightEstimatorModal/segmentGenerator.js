/**
 * segmentGenerator.js  (v3 - lean; blueprints generated at runtime)
 * -------------------------------------------------------------------------
 * "Segment Above 5" helper for weightEstimatorModal.
 * Same behaviour as before, but the lm_segment_6..15 + lm_overlap_details
 * blueprints are GENERATED here at runtime instead of being embedded as
 * ~570 KB of JSON (which exceeds the LWC component-file size limit).
 * Only the grid config (mast_grid + repeaters + Base-Plate/Foundation/L-Ring)
 * is embedded. Generated maths verified identical to lm_segment_5 at N=5.
 * -------------------------------------------------------------------------
 */
export const SEG_MIN = 6;
export const SEG_MAX = 15;

export function validateSegmentCount(raw) {
    const n = parseInt(raw, 10);
    if (isNaN(n)) return { ok: false, block: false, value: '', message: '' };
    if (n >= 1 && n <= 5) return { ok: false, block: true, value: '',
        message: 'For 1-5 segments, use Standard Mast > Lighting Mast. This estimator is only for 6 segments and above.' };
    if (n > SEG_MAX) return { ok: true, block: false, value: SEG_MAX,
        message: 'You can generate up to ' + SEG_MAX + ' segments here.' };
    return { ok: true, block: false, value: n, message: '' };
}

export function buildNotReadyPlaceholder(mastType) {
    return [{ id: 'seg5_not_ready', label: (mastType || 'This mast') + ' - Coming Soon', expanded: true,
        fields: [{ apiName: 'seg5_not_ready_note', label: 'The ' + mastType + ' estimator is not available yet.', type: 'header', colSpan: 12 }] }];
}

/* ===== blueprint generators (verified faithful to lm_segment_5) ===== */
function _midThkList(N, form) {
    const p = [];
    for (let k = N - 1; k >= 2; k--) {
        p.push(form === 'gt0'
            ? '(lm_ovr_mid' + k + '_thickness>0 ? lm_ovr_mid' + k + '_thickness : lm_mid' + k + '_thickness)'
            : '(lm_override_mid' + k + ' ? lm_ovr_mid' + k + '_thickness : lm_mid' + k + '_thickness)');
    }
    return p.join(' + ');
}
function _taper(N, form) {
    const inner = '(' + _midThkList(N, form) + ' + lm_' + N + '_top_thickness + ' + (N - 1) + ')';
    return '(lm_bot' + N + '_oaf_bot - (lm_' + N + '_top_oaf_top - ' + inner + ' * 2)) / lm_height_of_mast';
}
const _nextTop = (N, k) => (k < N - 1 ? 'lm_mid' + (k + 1) + '_oaf_top' : 'lm_bot' + N + '_oaf_top');
const _junc    = (N, k) => (k < N - 1 ? 'lm_ovr_m' + (k - 1) + '_m' + k : 'lm_ovr_m' + (k - 1) + '_b');

function _num(apiName, label, extra) { return Object.assign({ apiName, label, type: 'number', colSpan: 3 }, extra || {}); }

function _genSegmentFields(N) {
    const F = [];
    // ── SEGMENT ABOVE 5: all segment dimensions are USER INPUT (no auto-calculation) - Reetabrata (9th July 2026)
    // TOP    : Length, Thickness, OAF Top
    // MIDDLE : Length, Thickness
    // BOTTOM : Length, Thickness, OAF Bottom
    // Segment Weight is entered manually; Base/Unit price & cost still calculate from it.

    // ---- TOP (segment 1) ----
    F.push({ apiName: 'lm_' + N + '_hdr_top', label: 'TOP SEGMENT (MM)', type: 'header', colSpan: 12 });
    F.push(_num('lm_' + N + '_top_length',    'LENGTH',    { required: true }));
    F.push(_num('lm_' + N + '_top_thickness', 'THICKNESS', { required: true }));
    F.push(_num('lm_' + N + '_top_oaf_top',   'OAF TOP',   { required: true }));

    // ---- MIDDLES (k = 2 .. N-1) ----
    for (let k = 2; k <= N - 1; k++) {
        F.push({ apiName: 'lm_hdr_mid' + k, label: 'MIDDLE SEGMENT ' + k + ' (MM)', type: 'header', colSpan: 12 });
        // Length and Thickness flow down from TOP SEGMENT. The user can still type over
        // any one of them - isManualOverride then stops the formula touching that cell -
        // so only the segments left alone follow the top. Deepanjan (20th Aug 2026)
        F.push(_num('lm_mid' + k + '_length',    'LENGTH',    { required: true, formula: '(lm_' + N + '_top_length || 0)' }));
        F.push(_num('lm_mid' + k + '_thickness', 'THICKNESS', { required: true, formula: '(lm_' + N + '_top_thickness || 0)' }));
    }

    // ---- BOTTOM (segment N) ----
    F.push({ apiName: 'lm_hdr_bot' + N, label: 'BOTTOM SEGMENT ' + N + ' (MM)', type: 'header', colSpan: 12 });
    // same flow-down from TOP SEGMENT. Deepanjan (20th Aug 2026)
    F.push(_num('lm_bot' + N + '_length',    'LENGTH',     { required: true, formula: '(lm_' + N + '_top_length || 0)' }));
    F.push(_num('lm_bot' + N + '_thickness', 'THICKNESS',  { required: true, formula: '(lm_' + N + '_top_thickness || 0)' }));
    F.push(_num('lm_bot' + N + '_oaf_bot',   'OAF BOTTOM', { required: true }));

    // ---- TOTALS ----
    F.push({ apiName: 'lm_' + N + '_hdr_totals', label: 'TOTALS', type: 'header', colSpan: 12 });
    // Segment weight is now a manual entry (no formula) - Reetabrata (9th July 2026)
    F.push(_num('lm_' + N + '_segment_weight', 'SEGMENT WEIGHT (KG)', { required: true, isWeightTotal: true }));
    F.push(_num('lm_' + N + '_base_price', 'BASE PRICE', { readOnly: true, isBasePrice: true, formula: 'Base_Amount__c' }));
    // 👉 ADD THIS GHOST FIELD:
    F.push(_num('lm_' + N + '_ghost_quantity', 'Line Item Quantity', { readOnly: true, isQuantity: true, formula: '(lm_quantity || 1)', isVisible: false }));
    F.push(_num('lm_' + N + '_ghost_realization', 'Line Item Realization', { readOnly: true, isRealization: true, formula: '(lm_seg5_realization || 0)', isVisible: false }));
    F.push(_num('lm_' + N + '_unit_price', 'UNIT PRICE', { readOnly: true, isUnitPrice: true,
        // si_* are quote-level (NOT row-cloned). They must NOT start with 'lm_', or the
        // matrix-accordion-repeater's replaceTarget:'lm_' rewrites them to r{row}_lm_si_*
        // which does not exist -> ReferenceError. typeof guards evaluation order too,
        // because `|| 0` does not protect an UNDECLARED identifier. - Reetabrata (9th July 2026)
        // lm_si_* (NOT bare si_*) since 27-Jul: Special Items is now cloned PER ROW
        // by an accordion-repeater, so both this formula and the SI fields carry the
        // same 'lm_' prefix and the matrix clone rewrites BOTH to the same r{row}_lm_
        // keys - row 2's special item folds into row 2's segments only. The typeof
        // guards stay because `|| 0` cannot protect an undeclared identifier.
        // Deepanjan (27th July 2026)
        // lm_fdn_acc_weight used to be ADDED here. It is a WEIGHT in KG (the
        // Foundation Bolt & Stiffener line's own weight, isWeightTotal), so adding
        // it to a rupee amount put a flat +500 on a 500 kg quote - Qno 00001135
        // priced 220,500 where 2000 kg x 110 = 220,000. It is also already carried
        // by its own line item, so it was counted twice. The normal Lighting Mast
        // blueprint never had this term. Removed, leaving weight x rate exactly as
        // the normal recipe does. Deepanjan (19th Aug 2026)
        // PU PAINT - Deepanjan (8th September 2026). Same rule as the normal LCLM blueprint,
        // whose every lm_N_unit_price ends "+ (lm_pu_paint ? lm_pu_paint_unit_price : 0)":
        // the realized PU Paint rate is ADDED HERE, in the formula, and saved in the JSON as
        // part of the segment UNIT PRICE - nothing is added in Apex any more (the 4 Sep Apex
        // fold double-charged and is removed). lm_pu_paint_unit_price already carries the
        // realization. Its own "Extra Micron & PU Paint" line item is untouched, exactly as
        // in the normal recipe. typeof guards: recipes without the PU section (Signage,
        // Latching, Custom Lighting) must not hit an undeclared identifier. Keys start with
        // 'lm_' so the row repeater rewrites them to the same r{n}_ row as this segment.
        formula: '((lm_total_price || 0) * Math.round((lm_' + N + '_segment_weight || 0) + (typeof lm_si_weight_add !== "undefined" ? (lm_si_weight_add || 0) : 0)) + (typeof lm_si_price_add !== "undefined" ? (lm_si_price_add || 0) : 0) + (typeof lm_pu_paint !== \"undefined\" && lm_pu_paint && typeof lm_pu_paint_unit_price !== \"undefined\" ? (lm_pu_paint_unit_price || 0) : 0))  ' }));//gst removed
    F.push(_num('lm_' + N + '_unit_cost', 'UNIT COST', { readOnly: true, isUnitCost: true,
        // Same removal as UNIT PRICE above. Deepanjan (19th Aug 2026)
        formula: '((Base_Amount__c || 0) * Math.round((lm_' + N + '_segment_weight || 0) + (typeof lm_si_weight_add !== "undefined" ? (lm_si_weight_add || 0) : 0)) + (typeof lm_si_price_add !== "undefined" ? (lm_si_price_add || 0) : 0))  ' }));//gst removed
    return F;
}

function _cvRange(lo) { const a = []; for (let n = Math.max(lo, SEG_MIN); n <= SEG_MAX; n++) a.push(String(n)); return a; }

function _genOverlapFields() {
    const F = [];
    F.push(_num('lm_ovr_t_m', 'LENGTH OF OVERLAP 1 (T & M)', { colSpan: 4, unit: 'mm', controllingField: 'lm_no_of_segment', controllingValues: _cvRange(3) }));
    for (let i = 1; i <= SEG_MAX - 3; i++) {
        F.push(_num('lm_ovr_m' + i + '_m' + (i + 1), 'LENGTH OF OVERLAP ' + (i + 1) + ' (M' + i + ' & M' + (i + 1) + ')', { colSpan: 4, unit: 'mm', controllingField: 'lm_no_of_segment', controllingValues: _cvRange(i + 3) }));
    }
    for (let N = SEG_MIN; N <= SEG_MAX; N++) {
        // override fields removed (all inputs now) - reference the plain segment lengths - Reetabrata (9th July 2026)
        const lens = ['lm_' + N + '_top_length'];
        for (let k = 2; k <= N - 1; k++) lens.push('(lm_mid' + k + '_length || 0)');
        lens.push('(lm_bot' + N + '_length || 0)');
        const inputs = ['lm_ovr_t_m']; for (let i = 1; i <= N - 3; i++) inputs.push('lm_ovr_m' + i + '_m' + (i + 1));
        // guard with == N so inactive counts don't reference non-existent segment fields (ReferenceError) - Reetabrata (8th July 2026)
        const closure = 'lm_no_of_segment == ' + N + ' ? (' + lens.join(' + ') + ' - (lm_height_of_mast * 1000) - (' + inputs.join(' + ') + ')) : 0';
        F.push(_num('lm_ovr_m' + (N - 2) + '_b', 'LENGTH OF OVERLAP ' + (N - 1) + ' (M' + (N - 2) + ' & B)', { colSpan: 4, unit: 'mm', readOnly: true, formula: closure, controllingField: 'lm_no_of_segment', controllingValues: [String(N)] }));
        F.push(_num('lm_' + N + '_longitudinal_welding', 'NO. OF LONGITUDINAL WELDING', { colSpan: 4, readOnly: true, defaultValue: 0, formula: 'lm_no_of_segment == ' + N + ' ? (lm_bot' + N + '_oaf_bot <= 600 ? 1 : 2) : 0', controllingField: 'lm_no_of_segment', controllingValues: [String(N)] }));
    }
    return F;
}

function _buildBlueprints() {
    const bp = {};
    for (let N = SEG_MIN; N <= SEG_MAX; N++) bp['lm_segment_' + N] = _genSegmentFields(N);
    bp['lm_overlap_details'] = _genOverlapFields();
    return bp;
}

const LM_MODALFIELDS = [
    {
        "id": "lm_general_details",
        "label": "General Details",
        "expanded": true,
        "fields": [
            {"apiName": "h_sl", "label": "SL. NO.", "type": "header", "colSpan": 1},
            {"apiName": "h_ht", "label": "HEIGHT OF MAST", "type": "header", "colSpan": 2},
            {"apiName": "h_seg", "label": "NO. OF SEGMENT", "type": "header", "colSpan": 3},
            {"apiName": "h_rz", "label": "TOTAL PRICE (/KG)", "type": "header", "colSpan": 2},
            {"apiName": "h_rzamt", "label": "REALIZATION", "type": "header", "colSpan": 2},
            {"apiName": "h_qt", "label": "QUANTITY", "type": "header", "colSpan": 2},
            {
                "apiName": "mast_grid",
                "type": "grid-repeater",
                "defaultRows": 5,
                "maxRows": 10,
                "addMoreApiName": "add_more_rows",
                "fields": [
                    {"apiName": "sl_no", "label": " ", "type": "text", "defaultValue": "{row}", "readOnly": true, "colSpan": 1},
                    {"apiName": "lm_height_of_mast", "label": " ", "type": "number", "unit": "meter", "colSpan": 2},
                    {"apiName": "lm_no_of_segment", "label": " ", "type": "number", "unit": "Number (6+)", "colSpan": 3, "min": 6, "max": 15},
                    {"apiName": "lm_total_price", "label": " ", "type": "number", "unit": "Value", "colSpan": 2, "formula": "(Base_Amount__c || 0) + 5"},
                    {"apiName": "lm_seg5_realization", "label": " ", "type": "number", "colSpan": 2, "readOnly": true, "isRealization": true, "formula": "(lm_total_price || 0) - (Base_Amount__c || 0)"},
                    {"apiName": "lm_quantity", "label": " ", "type": "number", "unit": "Value", "colSpan": 2}
                ]
            },
            {"apiName": "add_more_rows", "label": "Add more?", "type": "checkbox", "colSpan": 1},
            {"apiName": "wind_speed", "label": "Wind Speed ?", "type": "picklist", "options": ["NO", "YES"], "defaultValue": "NO", "colSpan": 2},
            {"apiName": "wind_speed_value", "label": "WIND SPEED", "type": "text", "required": true, "colSpan": 2, "controllingField": "wind_speed", "controllingValues": ["YES"]},
            {"apiName": "spacer_foot", "label": " ", "type": "header", "colSpan": 7}
        ]
    },
    {
        "type": "matrix-accordion-repeater",
        "gridFieldApi": "lm_no_of_segment",
        "maxRows": 10,
        "replaceTarget": "lm_",
        "templates": [
            {"value": "6", "cloneFrom": "lm_segment_6", "label": "LM - Segment {row}.6"},
            {"value": "7", "cloneFrom": "lm_segment_7", "label": "LM - Segment {row}.7"},
            {"value": "8", "cloneFrom": "lm_segment_8", "label": "LM - Segment {row}.8"},
            {"value": "9", "cloneFrom": "lm_segment_9", "label": "LM - Segment {row}.9"},
            {"value": "10", "cloneFrom": "lm_segment_10", "label": "LM - Segment {row}.10"},
            {"value": "11", "cloneFrom": "lm_segment_11", "label": "LM - Segment {row}.11"},
            {"value": "12", "cloneFrom": "lm_segment_12", "label": "LM - Segment {row}.12"},
            {"value": "13", "cloneFrom": "lm_segment_13", "label": "LM - Segment {row}.13"},
            {"value": "14", "cloneFrom": "lm_segment_14", "label": "LM - Segment {row}.14"},
            {"value": "15", "cloneFrom": "lm_segment_15", "label": "LM - Segment {row}.15"}
        ]
    },
    {
        "id": "lm_base_plate_details",
        "label": "Base Plate Details",
        "expanded": false,
        "controllingField": "r1_lm_no_of_segment, r2_lm_no_of_segment, r3_lm_no_of_segment, r4_lm_no_of_segment, r5_lm_no_of_segment, r6_lm_no_of_segment, r7_lm_no_of_segment, r8_lm_no_of_segment, r9_lm_no_of_segment, r10_lm_no_of_segment",
        "controllingValues": ["*"],
        "fields": [
            {"apiName": "h_bp_sl", "label": "SL. NO.", "type": "header", "colSpan": 1},
            {"apiName": "h_bp_type", "label": "BASE PLATE TYPE", "type": "header", "colSpan": 4},
            {"apiName": "h_bp_od", "label": "OD OF BASE PLATE", "type": "header", "colSpan": 3},
            {"apiName": "h_bp_thk", "label": "THICKNESS OF BASE PLATE", "type": "header", "colSpan": 2},
            {"apiName": "h_bp_pcd", "label": "P.C.D", "type": "header", "colSpan": 2},
            {
                "apiName": "bp_grid",
                "type": "grid-repeater",
                "maxRows": 10,
                "fields": [
                    {"apiName": "bp_sl_no", "label": " ", "type": "text", "defaultValue": "{row}", "readOnly": true, "colSpan": 1, "controllingField": "lm_no_of_segment", "controllingValues": ["*"]},
                    {"apiName": "lm_base_plate_type", "label": " ", "type": "picklist", "required": true, "options": ["Circular", "Square"],"defaultValue": "Circular", "colSpan": 4, "controllingField": "lm_no_of_segment", "controllingValues": ["*"]},
                    {"apiName": "lm_od_of_base_plate", "label": " ", "type": "number", "unit": "mm", "colSpan": 3, "controllingField": "lm_no_of_segment", "controllingValues": ["*"]},
                    {"apiName": "lm_thickness_of_base_plate", "label": " ", "type": "number", "unit": "mm", "colSpan": 2, "controllingField": "lm_no_of_segment", "controllingValues": ["*"]},
                    {"apiName": "lm_pcd", "label": " ", "type": "number", "unit": "mm", "colSpan": 2, "controllingField": "lm_no_of_segment", "controllingValues": ["*"]},
                ]
            }
        ]
    },
    {
        "id": "lm_foundation_bolt_stiffner",
        "label": "Foundation Bolt & Stiffener",
        "expanded": false,
        "controllingField": "r1_lm_no_of_segment, r2_lm_no_of_segment, r3_lm_no_of_segment, r4_lm_no_of_segment, r5_lm_no_of_segment, r6_lm_no_of_segment, r7_lm_no_of_segment, r8_lm_no_of_segment, r9_lm_no_of_segment, r10_lm_no_of_segment",
        "controllingValues": ["*"],
        "fields": [
            {"apiName": "h_fb_sl", "label": "SL. NO.", "type": "header", "colSpan": 1},
            {"apiName": "h_fb_type", "label": "FOUNDATION BOLT TYPE", "type": "header", "colSpan": 2},
            // 12 columns (slds-size_{colSpan}-of-12), so the two columns this needs are
            // taken from LENGTH OF BOLT and NO. OF BOLT (2 -> 1 each); both hold short
            // numbers and NO. OF NUT already sits at colSpan 1.
            {"apiName": "h_fb_dia", "label": "DIAMETER OF FOUNDATION BOLT", "type": "header", "colSpan": 3},
            {"apiName": "h_fb_len", "label": "LENGTH OF BOLT", "type": "header", "colSpan": 2},
            {"apiName": "h_fb_nob", "label": "NO. OF BOLT", "type": "header", "colSpan": 2},
            // Header cells and grid cells share ONE continuous 12-column flow, so a header
            // run shorter than 12 pulls the next row's first cell up onto the header line.
            // This header must therefore stay unconditionally visible - it is one header for
            // up to ten rows anyway, and those rows can differ. Deepanjan (20th Aug 2026)
            {"apiName": "h_fb_wt", "label": "FOUNDATION ACCESSORY WEIGHT (KG)", "type": "header", "colSpan": 2},
            {
                "apiName": "fb_grid",
                "type": "grid-repeater",
                "maxRows": 10,
                "fields": [
                    {"apiName": "fb_sl_no", "label": " ", "type": "text", "defaultValue": "{row}", "readOnly": true, "colSpan": 1, "controllingField": "lm_no_of_segment", "controllingValues": ["*"]},
                    // bolt type বাকি সব cell-এর মতোই lm_no_of_segment-এ বাঁধা. আগেরবার এটাকে
                    // weight cell-এর parent বানানো হয়েছিল, তাতে dia/length/nos-এর সাথে parent
                    // আলাদা হয়ে গিয়ে APPLY-এর পর ওই তিনটের value মুছে যাচ্ছিল. তাই এবার সবাই
                    // এক parent-এ, আর Without Foundation-এর কাজটা Apex-এর fdnSuppressed করছে.
                    // Deepanjan (21st Aug 2026)
                    {"apiName": "lm_fdn_bolt_type", "label": " ", "type": "picklist", "options": ["With Foundation", "Without Foundation"], "required": true, "colSpan": 2, "controllingField": "lm_no_of_segment", "controllingValues": ["*"]},
                    // NO defaultValue on purpose: an unused mast row leaves this blank,
                    // and the weight cell below keys off it, so blank keeps that row's
                    // weight hidden exactly as the old lm_no_of_segment gate did.
                    {"apiName": "lm_fdn_bolt_dia", "label": " ", "type": "number", "unit": "mm", "colSpan": 3, "controllingField": "lm_no_of_segment", "controllingValues": ["*"]},   // open field, was a picklist - UIL-HM-084. Deepanjan (19th Aug 2026)
                    {"apiName": "lm_fdn_bolt_length", "label": " ", "type": "number", "unit": "mm", "colSpan": 2, "controllingField": "lm_no_of_segment", "controllingValues": ["*"]},
                    {"apiName": "lm_fdn_no_of_bolt", "label": " ", "type": "number", "unit": "Nos.", "colSpan": 2, "controllingField": "lm_no_of_segment", "controllingValues": ["*"]},
                    // Single controlling field on purpose: the engine ORs a comma list, so
                    // pairing this with lm_no_of_segment ["*"] would make it always visible.
                    // Blank bolt type -> no match -> hidden, which reproduces the old gate.
                    // required is only enforced while isVisible, so hiding it also drops the
                    // mandatory flag; the value is cleared, so UNIT PRICE / UNIT COST fall to 0.
                    {"apiName": "lm_fdn_acc_weight", "label": " ", "type": "number", "unit": "KG", "readOnly": false, "isWeightTotal": true, "controllingField": "lm_fdn_bolt_type", "controllingValues": ["With Foundation"], "required": true, "colSpan": 2},
                    {"apiName": "lm_fdn_wt_blank", "label": " ", "type": "header", "controllingField": "lm_fdn_bolt_type", "controllingValues": ["Without Foundation"], "colSpan": 2},
                    {"apiName": "lm_fdn_base_price", "label": "BASE PRICE", "type": "number", "readOnly": true, "isBasePrice": true, "controllingField": "lm_no_of_segment", "controllingValues": ["*"], "formula": "Base_Amount__c"},
                    // Foundation Bolt & Stiffener is priced the same way a segment is: the weight
                    // the user types in FOUNDATION ACCESSORY WEIGHT (KG) times the rate. It used to
                    // derive its own weight from dia/length/no-of-bolt geometry and ignore the typed
                    // weight, so Qno 00001135 carried a 500 kg line item but was priced on 225.15 kg.
                    // dia / length / no. of bolt now only describe the item in the offer text.
                    // Deepanjan (19th Aug 2026)
                    {"apiName": "lm_fdn_unit_price", "label": "UNIT PRICE", "isUnitPrice": true, "type": "number", "readOnly": true, "controllingField": "lm_no_of_segment", "controllingValues": ["*"], "formula": "((lm_total_price || 0) * (lm_fdn_acc_weight || 0))"},//gst removed
                    // Base_Amount__c is TOTAL PRICE minus the realization (110 - 5 = 105 here), the
                    // same basis the segment unit cost uses. Deepanjan (19th Aug 2026)
                    {"apiName": "lm_fdn_unit_cost", "label": "UNIT COST", "isUnitCost": true, "type": "number", "readOnly": true, "controllingField": "lm_no_of_segment", "controllingValues": ["*"], "formula": "((Base_Amount__c || 0) * (lm_fdn_acc_weight || 0))"},//gst removed
                    // 👉 ADD THIS GHOST FIELD:
                    {"apiName": "lm_fdn_ghost_quantity", "label": "Line Item Quantity", "type": "number", "readOnly": true, "isQuantity": true, "formula": "(lm_quantity || 1)", "isVisible": false, "controllingField": "lm_no_of_segment", "controllingValues": ["*"]},
                    {"apiName": "lm_fdn_ghost_realization", "label": "Line Item Realization", "type": "number", "readOnly": true, "isRealization": true, "formula": "(lm_seg5_realization || 0)", "isVisible": false, "controllingField": "lm_no_of_segment", "controllingValues": ["*"]}
                ]
            }
        ]
    },
    {
        "id": "lm_l_ring_details",
        "label": "L-Ring Details",
        "expanded": false,
        "controllingField": "r1_lm_no_of_segment, r2_lm_no_of_segment, r3_lm_no_of_segment, r4_lm_no_of_segment, r5_lm_no_of_segment, r6_lm_no_of_segment, r7_lm_no_of_segment, r8_lm_no_of_segment, r9_lm_no_of_segment, r10_lm_no_of_segment",
        "controllingValues": ["*"],
        "fields": [
            {"apiName": "h_lr_sl", "label": "SL. NO.", "type": "header", "colSpan": 2},
            {"apiName": "h_lr_type", "label": "TYPE OF L-RING", "type": "header", "colSpan": 5},
            {"apiName": "h_lr_dia", "label": "RING DIAMETER", "type": "header", "colSpan": 5},
            {
                "apiName": "lr_grid",
                "type": "grid-repeater",
                "maxRows": 10,
                "fields": [
                    {"apiName": "lr_sl_no", "label": " ", "type": "text", "defaultValue": "{row}", "readOnly": true, "colSpan": 2, "controllingField": "lm_no_of_segment", "controllingValues": ["*"]},
                    {"apiName": "lm_type_of_l_ring", "label": " ", "type": "picklist", "options": ["F = Fixed Type Ring", "D = Detachable Type Ring"], "colSpan": 5, "controllingField": "lm_no_of_segment", "controllingValues": ["*"]},
                    {"apiName": "lm_ring_diameter", "label": " ", "type": "picklist", "colSpan": 5, "options": ["600", "800", "1050", "1200"], "controllingField": "lm_no_of_segment", "controllingValues": ["*"]}
                ]
            }
        ]
    },
    {
        "id": "lm_additional_accessories",
        "label": "Additional Accessories",
        "expanded": false,
        "controllingField": "r1_lm_no_of_segment, r2_lm_no_of_segment, r3_lm_no_of_segment, r4_lm_no_of_segment, r5_lm_no_of_segment, r6_lm_no_of_segment, r7_lm_no_of_segment, r8_lm_no_of_segment, r9_lm_no_of_segment, r10_lm_no_of_segment",
        "controllingValues": ["*"],
        "fields": [
            {"apiName": "lm_qty_of_hm", "label": "QTY. OF HM", "type": "number", "formula": "r1_lm_quantity || r2_lm_quantity || r3_lm_quantity || r4_lm_quantity || r5_lm_quantity || r6_lm_quantity || r7_lm_quantity || r8_lm_quantity || r9_lm_quantity || r10_lm_quantity || 0", "colSpan": 1, "readOnly": true},
            {"apiName": "lm_mast_height", "label": "MAST HEIGHT", "type": "number", "formula": "(r1_lm_height_of_mast || r2_lm_height_of_mast || r3_lm_height_of_mast || r4_lm_height_of_mast || r5_lm_height_of_mast || r6_lm_height_of_mast || r7_lm_height_of_mast || r8_lm_height_of_mast || r9_lm_height_of_mast || r10_lm_height_of_mast || 0) * 10", "colSpan": 1, "readOnly": true},
            {"apiName": "lm_no_of_luminaries", "label": "NO. OF LUMINARIES", "type": "number", "colSpan": 2},
            {"apiName": "lm_type_of_luminaries", "label": "TYPE OF LUMINARIES", "type": "picklist", "options": ["Symmetric", "Asymmetric"], "colSpan": 2},
            {"apiName": "lm_type_of_welded_arm", "label": "TYPE OF WELDED ARM", "type": "number", "colSpan": 2},
            {"apiName": "lm_suspension_system", "label": "SUSPN SYSM (NO. OF POINT)", "type": "picklist", "options": ["2= 2 suspension type", "3= 3 suspension type"], "colSpan": 2},
            {"apiName": "lm_cable_type", "label": "CABLE TYPE", "type": "picklist", "colSpan": 2, "options": ["T=2.5 SQmm 5Core", "F=4 SQmm 5Core", "S=6 SQmm 5Core", "H=2.5 SQmm 8Core", "X=NA"]},
            {"apiName": "lm_no_of_cable", "label": "NO OF CABLE", "type": "picklist", "options": ["0=NA", "1=Single cable", "2=Double cable"], "colSpan": 4},
            {"apiName": "lm_l_ring_tier", "label": "1 TIER OR 2 TIER L- RING", "type": "picklist", "options": ["1-Single tire", "2-Two tire"], "colSpan": 4},
            {"apiName": "lm_type_of_ring_vw", "label": "TYPE OF RING V/W", "type": "picklist", "options": ["W= Fixed Type", "V= Detachable Type"], "colSpan": 4},
            {"apiName": "lm_type_of_winch", "label": "TYPE OF WINCH", "type": "text", "colSpan": 3},
            {"apiName": "lm_winch_unit", "label": " ", "type": "text", "readOnly": true, "disabled": true, "defaultValue": "KG", "colSpan": 1},
                    // Drum type as its own picklist instead of asking the user to type
                    // "1500 DGDD" - no spelling to get wrong, and the offer reads
                    // "1500 KG DGDD" without depending on how the text was split.
                    // Blank = nothing appended. Deepanjan (21st Aug 2026)
                    {"apiName": "lm_winch_drum", "label": "DRUM TYPE", "type": "picklist", "options": ["", "SGDD", "DGDD"], "colSpan": 4},
            {"apiName": "lm_type_of_power_tool", "label": "TYPE OF POWER TOOL", "type": "text", "colSpan": 3},
            {"apiName": "lm_power_tool_unit", "label": " ", "type": "text", "readOnly": true, "disabled": true, "defaultValue": "HP", "colSpan": 1},
            {"apiName": "lm_type_of_wire_rope", "label": "TYPE OF WIRE ROPE", "type": "text", "colSpan": 3},
            {"apiName": "lm_wire_rope_unit", "label": " ", "type": "text", "readOnly": true, "disabled": true, "defaultValue": "mm Dia", "colSpan": 1},
            {"apiName": "lm_optional_electrical_items", "label": "OPTIONAL ELECTRICAL ITEMS", "type": "checkbox", "colSpan": 2},
            {"apiName": "lm_type_of_aol", "label": "Type of AOL", "type": "picklist", "controllingField": "lm_optional_electrical_items", "controllingValues": ["true"], "options": ["S=Single Dome, GLS Type", "D=Double Dome, GLS Type", "K=Double Dome, LED Type", "L=Single Dome, LED Type", "X= NA"], "colSpan": 2},
            {"apiName": "lm_no_of_aviation_light", "label": "No. of Aviation Light", "type": "picklist", "controllingField": "lm_optional_electrical_items", "controllingValues": ["true"], "options": ["1=One AOL", "2=Two AOL", "X=NA"], "colSpan": 2},
            {"apiName": "lm_feeder_piller_control", "label": "Feeder Piller / Control", "type": "picklist", "controllingField": "lm_optional_electrical_items", "controllingValues": ["true"], "options": ["0=No fidder piller needed", "1=One fidder piller needed", "2=Single Door Small Feeder Piller", "X=Neither fidder piller nor control piller", "Special Feeder Pillar"], "colSpan": 2},
            {"apiName": "lm_acc_rate", "label": "RATE", "type": "number", "colSpan": 2},
            {"apiName": "lm_acc_realization", "label": "REALIZATION", "type": "number", "colSpan": 2, "defaultValue": 5, "unit": "%"},
            {"apiName": "lm_acc_realization_amount", "label": "REALIZATION AMOUNT", "type": "number", "colSpan": 2, "readOnly": true, "formula": "(lm_acc_rate || 0) * (lm_acc_realization || 0) / 100"},
            {"apiName": "lm_acc_total_rate", "label": "TOTAL RATE", "type": "number", "colSpan": 2, "readOnly": true, "formula": "(lm_acc_rate || 0) + ((lm_acc_rate || 0) * (lm_acc_realization || 0) / 100)"},
            /* ── Line item ── Deepanjan (4th September 2026). The offer PDF has always printed
               "Supply of LIGHTING MAST ACCESSORIES PART" at TOTAL RATE x mast qty, but this
               section carried no line-item flag, so the Quote line-item table never got that
               row and the two disagreed by the whole accessories amount. Three invisible ghost
               fields (same pattern as lm_{N}_ghost_*): UNIT PRICE = TOTAL RATE (rate + realization,
               what HighMastSOWController reads), UNIT COST = the bare RATE, QTY = the mast row's
               own quantity. All 0 when no rate is entered, so no empty line is ever emitted. */
            {"apiName": "lm_acc_ghost_unit_price", "label": "Line Item Unit Price", "type": "number", "readOnly": true, "isUnitPrice": true, "formula": "(lm_acc_total_rate || 0)", "isVisible": false},
            {"apiName": "lm_acc_ghost_unit_cost",  "label": "Line Item Unit Cost",  "type": "number", "readOnly": true, "isUnitCost":  true, "formula": "(lm_acc_rate || 0)",       "isVisible": false},
            {"apiName": "lm_acc_ghost_quantity",   "label": "Line Item Quantity",   "type": "number", "readOnly": true, "isQuantity":  true, "formula": "(lm_quantity || 1)",       "isVisible": false}
        ]
    },
    {
        "id": "lm_special_items",
        "label": "Special Items",
        "expanded": false,
        "controllingField": "r1_lm_no_of_segment, r2_lm_no_of_segment, r3_lm_no_of_segment, r4_lm_no_of_segment, r5_lm_no_of_segment, r6_lm_no_of_segment, r7_lm_no_of_segment, r8_lm_no_of_segment, r9_lm_no_of_segment, r10_lm_no_of_segment",
        "controllingValues": ["*"],
        "fields": [
            {"apiName": "lm_si_type", "label": "TYPE", "type": "picklist", "options": ["Price", "Weight"], "colSpan": 3},
            {"apiName": "lm_si_description", "label": "ITEM DESCRIPTION", "type": "text", "colSpan": 4, "controllingField": "lm_si_type", "controllingValues": ["Price", "Weight"]},
            {"apiName": "lm_si_value", "label": "VALUE", "type": "number", "colSpan": 3, "controllingField": "lm_si_type", "controllingValues": ["Price", "Weight"]},
            {"apiName": "lm_si_show_separate", "label": "Show separate in offer", "type": "checkbox", "colSpan": 3},
            {"apiName": "si_price_add", "type": "hidden", "formula": "(lm_si_show_separate ? 0 : (lm_si_type == 'Price' ? (lm_si_value || 0) : 0))"},
            {"apiName": "si_weight_add", "type": "hidden", "formula": "(lm_si_show_separate ? 0 : (lm_si_type == 'Weight' ? (lm_si_value || 0) : 0))"},
            /* ── Line item when 'Show separate in offer' is TICKED ── Deepanjan (4th Sep 2026)
               UNTICKED, the value is folded into the segment rate above and this section has
               no line-item flags, so nothing else happened. TICKED, the offer PDF printed the
               item as its own row but the Quote line-item table got NOTHING - so the table
               and the PDF disagreed by exactly this item. Same three fields the Stadium
               recipe (mrl_si_unit_price / _unit_cost / _line_qty) has always carried, so the
               table now gets the same row the PDF prints. All three are 0 when UNTICKED, so
               the estimator's "unitPrice > 0" gate emits no line - identical to today.
               RATE mirrors HighMastSOWController.specialItemUnitRateRow(): TYPE = Weight is
               VALUE kg x TOTAL PRICE (/KG); TYPE = Price is the typed amount. COST is
               VALUE kg x the bare Base_Amount__c. QTY is the mast row's own quantity - the
               item belongs to that mast, so one Motor per mast, not one per quote. After the
               per-row clone these read r{n}_lm_total_price / r{n}_lm_quantity, the row's own. */
            {"apiName": "lm_si_unit_price", "label": "UNIT PRICE (if separate)", "type": "number", "readOnly": true, "colSpan": 4, "isUnitPrice": true,
             "formula": "(lm_si_show_separate ? (lm_si_type == 'Price' ? (lm_si_value || 0) : (lm_si_type == 'Weight' ? ((lm_total_price || 0) * (lm_si_value || 0)) : 0)) : 0)"},
            {"apiName": "lm_si_unit_cost", "label": "UNIT COST (if separate)", "type": "number", "readOnly": true, "colSpan": 4, "isUnitCost": true,
             "formula": "(lm_si_show_separate ? (lm_si_type == 'Price' ? (lm_si_value || 0) : (lm_si_type == 'Weight' ? ((Base_Amount__c || 0) * (lm_si_value || 0)) : 0)) : 0)"},
            {"apiName": "lm_si_line_qty", "label": "QTY", "type": "number", "readOnly": true, "colSpan": 4, "isQuantity": true,
             "formula": "(lm_si_show_separate ? (lm_quantity || 1) : 0)"}
        ]
    }
];


/* ── LCLM EXTRA SECTIONS ──────────────────────────────────────────────────────
   Lightning Cum Lighting Mast for Segment Above 5. Identical to the Lighting Mast
   recipe (segment weight is already a manual entry here), plus the two sections
   below. They are appended only for LCLM, so 'Lighting Mast' is byte-for-byte
   unchanged. Both sections are quote-level (single entry, not row-cloned), which
   is why their apiNames are read straight from the saved JSON by the PDF
   controllers. - Reetabrata (15th July 2026)
   ──────────────────────────────────────────────────────────────────────────── */
const LCLM_EXTRA_SECTIONS = [
    {
        id: 'lclm_lightning_spike', label: 'Lightning Spike Details', expanded: false,
        controllingField: 'r1_lm_no_of_segment, r2_lm_no_of_segment, r3_lm_no_of_segment, r4_lm_no_of_segment, r5_lm_no_of_segment, r6_lm_no_of_segment, r7_lm_no_of_segment, r8_lm_no_of_segment, r9_lm_no_of_segment, r10_lm_no_of_segment', controllingValues: ['*'],
        fields: [
            { apiName: 'lm_spike_length', label: 'LIGHTNING SPIKE LENGTH', type: 'number', unit: 'meter', colSpan: 12 },
            { apiName: 'lm_spike_price_basis', label: 'PRICE BASIS', type: 'picklist', options: ['Weight', 'Price'], defaultValue: 'Weight', colSpan: 12 },
            { apiName: 'lm_spike_weight', label: 'LIGHTNING SPIKE WEIGHT', type: 'number', unit: 'Kg', colSpan: 12, isWeightTotal: true, controllingField: 'lm_spike_price_basis', controllingValues: ['Weight'] },
            { apiName: 'lm_spike_price_input', label: 'LIGHTNING SPIKE PRICE', type: 'number', colSpan: 12, controllingField: 'lm_spike_price_basis', controllingValues: ['Price'] },
            { apiName: 'lm_spike_base_price', label: 'BASE PRICE', type: 'number', readOnly: true, colSpan: 12, formula: 'Base_Amount__c' },
            // Weight basis carries realization, a manually typed Price does not -
            // the same rule the main LCLM section logic follows. lm_total_price is
            // this recipe's realization-bearing rate (Base_Amount__c + 5); there is
            // no lm_realization field here. UNIT COST stays on Base_Amount__c,
            // because cost never carries realization. Deepanjan (10th August 2026)
            { apiName: 'lm_spike_unit_price', label: 'UNIT PRICE', type: 'number', readOnly: true, colSpan: 12, isUnitPrice: true,
              formula: "(lm_spike_price_basis == 'Price' ? (lm_spike_price_input || 0) : ((lm_total_price || 0) * (lm_spike_weight || 0)))  " },//gst removed
            { apiName: 'lm_spike_unit_cost', label: 'UNIT COST', type: 'number', readOnly: true, colSpan: 12, isUnitCost: true,
              formula: "(lm_spike_price_basis == 'Price' ? (lm_spike_price_input || 0) : ((Base_Amount__c || 0) * (lm_spike_weight || 0)))  " }//gst removed
        ]
    },
    {
        id: 'lclm_down_conductor', label: 'Down Conductor Details', expanded: false,
        controllingField: 'r1_lm_no_of_segment, r2_lm_no_of_segment, r3_lm_no_of_segment, r4_lm_no_of_segment, r5_lm_no_of_segment, r6_lm_no_of_segment, r7_lm_no_of_segment, r8_lm_no_of_segment, r9_lm_no_of_segment, r10_lm_no_of_segment', controllingValues: ['*'],
        fields: [
            { apiName: 'lm_dc_weight', label: 'DOWN CONDUCTOR WEIGHT', type: 'number', unit: 'Kg', colSpan: 12, isWeightTotal: true },
            { apiName: 'lm_dc_base_price', label: 'BASE PRICE', type: 'number', readOnly: true, colSpan: 12, formula: 'Base_Amount__c' },
            { apiName: 'lm_dc_unit_price', label: 'UNIT PRICE', type: 'number', readOnly: true, colSpan: 12, isUnitPrice: true,
              // Down Conductor has no price basis - it is always weight based, so
              // realization always applies. Deepanjan (10th August 2026)
              formula: '((lm_total_price || 0) * (lm_dc_weight || 0))  ' },//gst removed
            { apiName: 'lm_dc_unit_cost', label: 'UNIT COST', type: 'number', readOnly: true, colSpan: 12, isUnitCost: true,
              formula: '((Base_Amount__c || 0) * (lm_dc_weight || 0))  ' }//gst removed
        ]
    }
];


/* ── EXTRA MICRON & PU PAINT (Segment Above 5) ────────────────────────────────
   Stadium Mast already carries these per sub-mast (mrl_* / lwc_*). Lighting Mast
   and LCLM had no equivalent, so they get this quote-level section instead.
   It sits OUTSIDE the mast grid on purpose: the grid is per-row (r1..r10), and a
   PU paint charge inside it would be added once per mast row. Here the charge is
   its own line item, so it lands on the quote exactly once whatever the row count.
   - Reetabrata (15th July 2026)
   ──────────────────────────────────────────────────────────────────────────── */
const SEG5_MICRON_PU_PAINT = {
    id: 'lm_micron_pu_paint', label: 'Extra Micron & PU Paint', expanded: false,
    controllingField: 'r1_lm_no_of_segment, r2_lm_no_of_segment, r3_lm_no_of_segment, r4_lm_no_of_segment, r5_lm_no_of_segment, r6_lm_no_of_segment, r7_lm_no_of_segment, r8_lm_no_of_segment, r9_lm_no_of_segment, r10_lm_no_of_segment', controllingValues: ['*'],
    fields: [
        { apiName: 'lm_is_extra_micron', label: 'EXTRA MICRON?', type: 'checkbox', colSpan: 6 },
        { apiName: 'lm_extra_micron', label: 'EXTRA MICRON VALUE?', type: 'text', colSpan: 6,
          controllingField: 'lm_is_extra_micron', controllingValues: ['true'] },
        { apiName: 'lm_pu_paint', label: 'PU PAINT TO BE PROVIDED', type: 'checkbox', colSpan: 4 },
        { apiName: 'lm_pu_paint_note', label: 'NOTE', type: 'text', colSpan: 4,
          controllingField: 'lm_pu_paint', controllingValues: ['true'] },
        { apiName: 'lm_pu_paint_price', label: 'PRICE', type: 'number', colSpan: 4,
          controllingField: 'lm_pu_paint', controllingValues: ['true'] },
        // Realization on PU Paint works the way Additional Accessories does: a PERCENT
        // on the rate the user typed, default 5. It is not the General Details rate -
        // the price here is the user's own. Deepanjan (20th Aug 2026)
        { apiName: 'lm_pu_paint_realization', label: 'REALIZATION', type: 'number', unit: '%',
          defaultValue: 5, colSpan: 4, isRealization: true,
          controllingField: 'lm_pu_paint', controllingValues: ['true'] },
        // UNIT PRICE carries the realization, UNIT COST stays on the typed price.
        // No GST - the whole department moved to ex-GST on 6 Aug.
        { apiName: 'lm_pu_paint_unit_price', label: 'UNIT PRICE', type: 'number', readOnly: true,
          colSpan: 6, isUnitPrice: true, formula: '(lm_pu_paint ? ((lm_pu_paint_price || 0) * (1 + (lm_pu_paint_realization || 0) / 100)) : 0)  ' },//gst removed
        { apiName: 'lm_pu_paint_unit_cost', label: 'UNIT COST', type: 'number', readOnly: true,
          colSpan: 6, isUnitCost: true, formula: '(lm_pu_paint ? (lm_pu_paint_price || 0) : 0)  ' },//gst removed
        // Line-item QUANTITY - Deepanjan (4th September 2026). This section had no quantity
        // field, so the estimator's fallback put the "Extra Micron & PU Paint" line on the
        // Quote at qty 1 whatever the mast quantity was, while the offer PDF now carries PU
        // Paint inside the mast rate x mast qty (HighMastSOWController / HMScopeCombinedController,
        // 4th Sep 2026). Same ghost pattern as lm_{N}_ghost_quantity and lm_fdn_ghost_quantity:
        // invisible, saved, reads the row's own lm_quantity after the per-row clone. Table and
        // PDF now agree on this line to the rupee.
        { apiName: 'lm_pu_ghost_quantity', label: 'Line Item Quantity', type: 'number', readOnly: true,
          isQuantity: true, formula: '(lm_quantity || 1)', isVisible: false }
    ]
};


// ── FLAG MAST (Segment Above 5) — Deepanjan (19th July 2026) ─────────────────
// ACCESSORY COSTING FORMAT + Additional Details, grafted VERBATIM from the
// FLAG MAST - ESTIMATOR (Customized Mast section logic). The fm_ac_* / fm_ad_*
// apiNames are kept unchanged so any offer/cost-sheet mapping keyed on them
// keeps working; since they do not start with 'lm_', the matrix repeater's
// replaceTarget cannot rewrite them (same rule that protects si_*). Only
// controllingField was re-pointed at the LM grid's r{n}_lm_no_of_segment.
// Both sections are standalone costing tables - their grand totals do NOT
// feed the mast unit price (verified against the source config).
const FM_SEG5_EXTRA_SECTIONS = [
    {
        "id": "fm_accessory_costing",
        "label": "ACCESSORY COSTING FORMAT",
        "expanded": true,
        "controllingField": "r1_lm_no_of_segment, r2_lm_no_of_segment, r3_lm_no_of_segment, r4_lm_no_of_segment, r5_lm_no_of_segment, r6_lm_no_of_segment, r7_lm_no_of_segment, r8_lm_no_of_segment, r9_lm_no_of_segment, r10_lm_no_of_segment",
        "controllingValues": ["*"],
        "fields": [
            {"apiName": "fm_h_ac_sl", "label": "SL. NO.", "type": "header", "colSpan": 1},
            {"apiName": "fm_h_ac_bom", "label": "BOM", "type": "header", "colSpan": 3},
            {"apiName": "fm_h_ac_opt", "label": "SPEC", "type": "header", "colSpan": 3},
            {"apiName": "fm_h_ac_qty", "label": "QTY", "type": "header", "colSpan": 1},
            {"apiName": "fm_h_ac_rate", "label": "Rate", "type": "header", "colSpan": 2},
            {"apiName": "fm_h_ac_amt", "label": "Amount", "type": "header", "colSpan": 2},
            {"apiName": "fm_ac_1_sl", "label": "1", "type": "text", "readOnly": true, "colSpan": 1},
            {"apiName": "fm_ac_1_hdr", "label": "Wire Rope", "type": "header", "colSpan": 3},
                        // SPEC column widened by one (QTY gave up the space, so every row is still
            // 12 wide and the table stays aligned). The extra cell is a disabled
            // placeholder on every row except Winch Gear, where it is the SGDD/DGDD
            // picklist. Segment Above 5 Flag Mast only - the Customized Mast Flag Mast
            // grid lives in Section Logic metadata, not in this file.
            // Deepanjan (21st Aug 2026)
{"apiName": "fm_ac_1_option", "label": " ", "type": "text", "colSpan": 1},
            {"apiName": "fm_ac_1_unit", "label": " ", "type": "text", "readOnly": true, "disabled": true, "defaultValue": "mm", "colSpan": 1},
            {"apiName": "fm_ac_1_gear", "label": " ", "type": "text", "readOnly": true, "disabled": true, "colSpan": 1},
            {"apiName": "fm_ac_1_qty", "label": " ", "isQuantity": true, "type": "number", "colSpan": 1},
            {"apiName": "fm_ac_1_rate", "label": " ", "type": "number", "colSpan": 2},
            {"apiName": "fm_ac_1_amount", "label": " ", "type": "number", "readOnly": true, "colSpan": 2, "formula": "((fm_ac_1_qty || 0) * (fm_ac_1_rate || 0))  "},//gst removed
            {"apiName": "fm_ac_2_sl", "label": "2", "type": "text", "readOnly": true, "colSpan": 1},
            {"apiName": "fm_ac_2_hdr", "label": "Wire rope", "type": "header", "colSpan": 3},
            {"apiName": "fm_ac_2_option", "label": " ", "type": "text", "colSpan": 1},
            {"apiName": "fm_ac_2_unit", "label": " ", "type": "text", "readOnly": true, "disabled": true, "defaultValue": "mm", "colSpan": 1},
            {"apiName": "fm_ac_2_gear", "label": " ", "type": "text", "readOnly": true, "disabled": true, "colSpan": 1},
            {"apiName": "fm_ac_2_qty", "label": " ", "isQuantity": true, "type": "number", "colSpan": 1},
            {"apiName": "fm_ac_2_rate", "label": " ", "type": "number", "colSpan": 2},
            {"apiName": "fm_ac_2_amount", "label": " ", "type": "number", "readOnly": true, "colSpan": 2, "formula": "((fm_ac_2_qty || 0) * (fm_ac_2_rate || 0))  "},//gst removed
            {"apiName": "fm_ac_3_sl", "label": "3", "type": "text", "readOnly": true, "colSpan": 1},
            {"apiName": "fm_ac_3_hdr", "label": "Winch Gear", "type": "header", "colSpan": 3},
            {"apiName": "fm_ac_3_option", "label": " ", "type": "text", "colSpan": 1},
            {"apiName": "fm_ac_3_unit", "label": " ", "type": "text", "readOnly": true, "disabled": true, "defaultValue": "KG", "colSpan": 1},
            {"apiName": "fm_ac_3_gear", "label": " ", "type": "picklist", "options": ["", "SGDD", "DGDD"], "colSpan": 1},
            {"apiName": "fm_ac_3_qty", "label": " ", "isQuantity": true, "type": "number", "colSpan": 1},
            {"apiName": "fm_ac_3_rate", "label": " ", "type": "number", "colSpan": 2},
            {"apiName": "fm_ac_3_amount", "label": " ", "type": "number", "readOnly": true, "colSpan": 2, "formula": "((fm_ac_3_qty || 0) * (fm_ac_3_rate || 0))  "},//gst removed
            {"apiName": "fm_ac_4_sl", "label": "4", "type": "text", "readOnly": true, "colSpan": 1},
            {"apiName": "fm_ac_4_hdr", "label": "Motor", "type": "header", "colSpan": 3},
            {"apiName": "fm_ac_4_option", "label": " ", "type": "text", "colSpan": 1},
            {"apiName": "fm_ac_4_unit", "label": " ", "type": "text", "readOnly": true, "disabled": true, "defaultValue": "HP", "colSpan": 1},
            {"apiName": "fm_ac_4_gear", "label": " ", "type": "text", "readOnly": true, "disabled": true, "colSpan": 1},
            {"apiName": "fm_ac_4_qty", "label": " ", "isQuantity": true, "type": "number", "colSpan": 1},
            {"apiName": "fm_ac_4_rate", "label": " ", "type": "number", "colSpan": 2},
            {"apiName": "fm_ac_4_amount", "label": " ", "type": "number", "readOnly": true, "colSpan": 2, "formula": "((fm_ac_4_qty || 0) * (fm_ac_4_rate || 0))  "},//gst removed
            {"apiName": "fm_ac_5_sl", "label": "5", "type": "text", "readOnly": true, "colSpan": 1},
            {"apiName": "fm_ac_5_hdr", "label": "Snap hook", "type": "header", "colSpan": 3},
            {"apiName": "fm_ac_5_option", "label": " ", "type": "picklist", "colSpan": 2, "readOnly": true, "disabled": true},
            {"apiName": "fm_ac_5_gear", "label": " ", "type": "text", "readOnly": true, "disabled": true, "colSpan": 1},
            {"apiName": "fm_ac_5_qty", "label": " ", "isQuantity": true, "type": "number", "colSpan": 1},
            {"apiName": "fm_ac_5_rate", "label": " ", "type": "number", "colSpan": 2},
            {"apiName": "fm_ac_5_amount", "label": " ", "type": "number", "readOnly": true, "colSpan": 2, "formula": "((fm_ac_5_qty || 0) * (fm_ac_5_rate || 0))  "},//gst removed
            {"apiName": "fm_ac_6_sl", "label": "6", "type": "text", "readOnly": true, "colSpan": 1},
            {"apiName": "fm_ac_6_hdr", "label": "SS Accessories & Flag Clamps", "type": "header", "colSpan": 3},
            {"apiName": "fm_ac_6_option", "label": " ", "type": "picklist", "colSpan": 2, "readOnly": true},
            {"apiName": "fm_ac_6_gear", "label": " ", "type": "text", "readOnly": true, "disabled": true, "colSpan": 1},
            {"apiName": "fm_ac_6_qty", "label": " ", "isQuantity": true, "type": "number", "colSpan": 1},
            {"apiName": "fm_ac_6_rate", "label": " ", "type": "number", "colSpan": 2},
            {"apiName": "fm_ac_6_amount", "label": " ", "type": "number", "readOnly": true, "colSpan": 2, "formula": "((fm_ac_6_qty || 0) * (fm_ac_6_rate || 0))  "},//gst removed
            {"apiName": "fm_ac_7_sl", "label": "7", "type": "text", "readOnly": true, "colSpan": 1},
            {"apiName": "fm_ac_7_hdr", "label": "Counter weight", "type": "header", "colSpan": 3},
            {"apiName": "fm_ac_7_option", "label": " ", "type": "picklist", "colSpan": 2, "readOnly": true},
            {"apiName": "fm_ac_7_gear", "label": " ", "type": "text", "readOnly": true, "disabled": true, "colSpan": 1},
            {"apiName": "fm_ac_7_qty", "label": " ", "isQuantity": true, "type": "number", "colSpan": 1},
            {"apiName": "fm_ac_7_rate", "label": " ", "type": "number", "colSpan": 2},
            {"apiName": "fm_ac_7_amount", "label": " ", "type": "number", "readOnly": true, "colSpan": 2, "formula": "((fm_ac_7_qty || 0) * (fm_ac_7_rate || 0))  "},//gst removed
            // Row 8 - Control Panel. SPEC (and the gear cell) disabled; QTY and Rate are
            // the user's. Apex already had FM_AC_ROWS = 8 and "Control Panel" as the 8th
            // FM_AC_LABELS entry, so both offer builders pick this row up unchanged.
            // Deepanjan (21st Aug 2026)
            {"apiName": "fm_ac_8_sl", "label": "8", "type": "text", "readOnly": true, "colSpan": 1},
            {"apiName": "fm_ac_8_hdr", "label": "Control Panel", "type": "header", "colSpan": 3},
            {"apiName": "fm_ac_8_option", "label": " ", "type": "text", "readOnly": true, "disabled": true, "colSpan": 2},
            {"apiName": "fm_ac_8_gear", "label": " ", "type": "text", "readOnly": true, "disabled": true, "colSpan": 1},
            {"apiName": "fm_ac_8_qty", "label": " ", "isQuantity": true, "type": "number", "colSpan": 1},
            {"apiName": "fm_ac_8_rate", "label": " ", "type": "number", "colSpan": 2},
            {"apiName": "fm_ac_8_amount", "label": " ", "type": "number", "readOnly": true, "colSpan": 2, "formula": "((fm_ac_8_qty || 0) * (fm_ac_8_rate || 0))  "},//gst removed
            // Plain sum of the eight AMOUNT cells, sitting under that column - no realization,
            // no GST. Display only; the priced line item still comes from fm_ac_grand_total.
            // Segment Above 5 Flag Mast only (this recipe). Deepanjan (7th September 2026)
            {"apiName": "fm_ac_total_spacer", "label": " ", "type": "header", "colSpan": 10},
            {"apiName": "fm_ac_amount_total", "label": "Total Amount", "type": "number", "readOnly": true, "colSpan": 2, "formula": "(fm_ac_1_amount || 0) + (fm_ac_2_amount || 0) + (fm_ac_3_amount || 0) + (fm_ac_4_amount || 0) + (fm_ac_5_amount || 0) + (fm_ac_6_amount || 0) + (fm_ac_7_amount || 0) + (fm_ac_8_amount || 0)"},
            {"apiName": "fm_ac_realization", "label": "Realization (%)", "type": "number", "readOnly": false, "defaultValue": 5, "colSpan": 6},   // label only - Deepanjan (7th September 2026)
            {"apiName": "fm_ac_grand_total", "label": "Total Amount (incl. GST & Realization)", "type": "number", "readOnly": true, "colSpan": 6, "formula": "((fm_ac_1_amount || 0) + (fm_ac_2_amount || 0) + (fm_ac_3_amount || 0) + (fm_ac_4_amount || 0) + (fm_ac_5_amount || 0) + (fm_ac_6_amount || 0) + (fm_ac_7_amount || 0) + (fm_ac_8_amount || 0)) * (1 + (fm_ac_realization || 0) / 100)"}
        ]
    },
    {
        "id": "fm_additional_details",
        "label": "Additional Details",
        "expanded": true,
        "controllingField": "r1_lm_no_of_segment, r2_lm_no_of_segment, r3_lm_no_of_segment, r4_lm_no_of_segment, r5_lm_no_of_segment, r6_lm_no_of_segment, r7_lm_no_of_segment, r8_lm_no_of_segment, r9_lm_no_of_segment, r10_lm_no_of_segment",
        "controllingValues": ["*"],
        "fields": [
            {"apiName": "fm_h_ad_sl", "label": "SL. NO.", "type": "header", "colSpan": 1},
            {"apiName": "fm_h_ad_desc", "label": "DESCRIPTION", "type": "header", "colSpan": 3},
            {"apiName": "fm_h_ad_qty", "label": "QTY", "type": "header", "colSpan": 2},
            {"apiName": "fm_h_ad_rate", "label": "Rate", "type": "header", "colSpan": 3},
            {"apiName": "fm_h_ad_amt", "label": "Amount", "type": "header", "colSpan": 3},
            {"apiName": "fm_ad_1_sl", "label": "1", "type": "text", "readOnly": true, "colSpan": 1},
            {"apiName": "fm_ad_1_desc", "label": "32A STD FEEDER PILLAR", "type": "header", "colSpan": 3},
            {"apiName": "fm_ad_1_qty", "label": " ", "isQuantity": true, "type": "number", "colSpan": 2},
            {"apiName": "fm_ad_1_rate", "label": " ", "type": "number", "colSpan": 3},
            {"apiName": "fm_ad_1_amount", "label": " ", "type": "number", "readOnly": true, "colSpan": 3, "formula": "((fm_ad_1_qty || 0) * (fm_ad_1_rate || 0))  "},//gst removed
            {"apiName": "fm_ad_2_sl", "label": "2", "type": "text", "readOnly": true, "colSpan": 1},
            {"apiName": "fm_ad_2_desc", "label": "GI STAND", "type": "header", "colSpan": 3},
            {"apiName": "fm_ad_2_qty", "label": " ", "isQuantity": true, "type": "number", "colSpan": 2},
            {"apiName": "fm_ad_2_rate", "label": " ", "type": "number", "colSpan": 3},
            {"apiName": "fm_ad_2_amount", "label": " ", "type": "number", "readOnly": true, "colSpan": 3, "formula": "((fm_ad_2_qty || 0) * (fm_ad_2_rate || 0))  "},//gst removed
            {"apiName": "fm_ad_3_sl", "label": "3", "type": "text", "readOnly": true, "colSpan": 1},
            {"apiName": "fm_ad_3_desc", "label": "CONTROL PANEL FOR MOTOR OPERATE", "type": "header", "colSpan": 3},
            {"apiName": "fm_ad_3_qty", "label": " ", "isQuantity": true, "type": "number", "colSpan": 2},
            {"apiName": "fm_ad_3_rate", "label": " ", "type": "number", "colSpan": 3},
            {"apiName": "fm_ad_3_amount", "label": " ", "type": "number", "readOnly": true, "colSpan": 3, "formula": "((fm_ad_3_qty || 0) * (fm_ad_3_rate || 0))  "},//gst removed
            {"apiName": "fm_ad_4_sl", "label": "4", "type": "text", "readOnly": true, "colSpan": 1},
            {"apiName": "fm_ad_4_desc", "label": "SMALL LIGHT FEEDER PILLAR WITH STAND", "type": "header", "colSpan": 3},
            {"apiName": "fm_ad_4_qty", "label": " ", "isQuantity": true, "type": "number", "colSpan": 2},
            {"apiName": "fm_ad_4_rate", "label": " ", "type": "number", "colSpan": 3},
            {"apiName": "fm_ad_4_amount", "label": " ", "type": "number", "readOnly": true, "colSpan": 3, "formula": "((fm_ad_4_qty || 0) * (fm_ad_4_rate || 0))  "},//gst removed
            {"apiName": "fm_ad_5_sl", "label": "5", "type": "text", "readOnly": true, "colSpan": 1},
            {"apiName": "fm_ad_5_desc", "label": "Decorative Dome", "type": "text", "colSpan": 3},
            {"apiName": "fm_ad_5_qty", "label": " ", "isQuantity": true, "type": "number", "colSpan": 2},
            {"apiName": "fm_ad_5_rate", "label": " ", "type": "number", "colSpan": 3},
            {"apiName": "fm_ad_5_amount", "label": " ", "type": "number", "readOnly": true, "colSpan": 3, "formula": "((fm_ad_5_qty || 0) * (fm_ad_5_rate || 0))  "},//gst removed
            // Plain sum of the five AMOUNT cells under that column - same as fm_ac_amount_total.
            // Deepanjan (7th September 2026)
            {"apiName": "fm_ad_total_spacer", "label": " ", "type": "header", "colSpan": 9},
            {"apiName": "fm_ad_amount_total", "label": "Total Amount", "type": "number", "readOnly": true, "colSpan": 3, "formula": "(fm_ad_1_amount || 0) + (fm_ad_2_amount || 0) + (fm_ad_3_amount || 0) + (fm_ad_4_amount || 0) + (fm_ad_5_amount || 0)"},
            {"apiName": "fm_ad_realization", "label": "Realization (%)", "type": "number", "readOnly": false, "defaultValue": 5, "colSpan": 6},   // label only - Deepanjan (7th September 2026)
            {"apiName": "fm_ad_grand_total", "label": "Total Amount (incl. GST & Realization)", "type": "number", "readOnly": true, "colSpan": 6, "formula": "((fm_ad_1_amount || 0) + (fm_ad_2_amount || 0) + (fm_ad_3_amount || 0) + (fm_ad_4_amount || 0) + (fm_ad_5_amount || 0)) * (1 + (fm_ad_realization || 0) / 100)"}
        ]
    }
];

// ── FLAG MAST per-row LINE ITEMS — Deepanjan (20th July 2026) ────────────────
// The ACCESSORY COSTING FORMAT and Additional Details tables are editable grids
// (fm_ac_* / fm_ad_*), but a grid alone emits no quote line item. These hidden,
// self-contained sections mirror the PDF exactly: ONE line per row, created only
// when that row's qty >= 1 (controllingValues [">=1"] - note qty 0 is non-empty,
// so ["*"] would wrongly fire on every row). unit_price = row _amount * (1 +
// realization/100), matching cmFlagAccessoryItemLines / cmFlagAdditionalItemLines
// in HighMastSOWController to the rupee, so the quote and the offer PDF agree.
// forceHidden + revealedHiddenInputs = internal line block, never a second UI table.
const FM_SEG5_LINE_ITEM_SECTIONS = [
    {
        "id": "fm_ac_line_1",
        "label": "FLAG MAST ACCESSORY - Wire Rope",
        "expanded": false,
        "isVisible": false,
        "forceHidden": true,
        "revealedHiddenInputs": true,
        "controllingField": "fm_ac_1_qty",
        "controllingValues": [">=1"],
        "lineItemGroup": "fm_ac_line_1",
        "fields": [
            {"apiName": "fm_ac_1_ln_designation", "type": "text", "readOnly": true, "colSpan": 6, "label": "Wire Rope", "value": "Wire Rope"},
            {"apiName": "fm_ac_1_ln_qty", "type": "number", "readOnly": true, "colSpan": 2, "isQuantity": true, "formula": "(fm_ac_1_qty || 0)"},
            {"apiName": "fm_ac_1_ln_unit_price", "type": "number", "readOnly": true, "colSpan": 2, "isUnitPrice": true, "formula": "(fm_ac_1_amount || 0) * (1 + (fm_ac_realization || 0) / 100)"},
            {"apiName": "fm_ac_1_ln_unit_cost", "type": "number", "readOnly": true, "colSpan": 2, "isUnitCost": true, "formula": "(fm_ac_1_amount || 0) * (1 + (fm_ac_realization || 0) / 100)"}
        ]
    },
    {
        "id": "fm_ac_line_2",
        "label": "FLAG MAST ACCESSORY - Wire rope",
        "expanded": false,
        "isVisible": false,
        "forceHidden": true,
        "revealedHiddenInputs": true,
        "controllingField": "fm_ac_2_qty",
        "controllingValues": [">=1"],
        "lineItemGroup": "fm_ac_line_2",
        "fields": [
            {"apiName": "fm_ac_2_ln_designation", "type": "text", "readOnly": true, "colSpan": 6, "label": "Wire rope", "value": "Wire rope"},
            {"apiName": "fm_ac_2_ln_qty", "type": "number", "readOnly": true, "colSpan": 2, "isQuantity": true, "formula": "(fm_ac_2_qty || 0)"},
            {"apiName": "fm_ac_2_ln_unit_price", "type": "number", "readOnly": true, "colSpan": 2, "isUnitPrice": true, "formula": "(fm_ac_2_amount || 0) * (1 + (fm_ac_realization || 0) / 100)"},
            {"apiName": "fm_ac_2_ln_unit_cost", "type": "number", "readOnly": true, "colSpan": 2, "isUnitCost": true, "formula": "(fm_ac_2_amount || 0) * (1 + (fm_ac_realization || 0) / 100)"}
        ]
    },
    {
        "id": "fm_ac_line_3",
        "label": "FLAG MAST ACCESSORY - Winch Gear",
        "expanded": false,
        "isVisible": false,
        "forceHidden": true,
        "revealedHiddenInputs": true,
        "controllingField": "fm_ac_3_qty",
        "controllingValues": [">=1"],
        "lineItemGroup": "fm_ac_line_3",
        "fields": [
            {"apiName": "fm_ac_3_ln_designation", "type": "text", "readOnly": true, "colSpan": 6, "label": "Winch Gear", "value": "Winch Gear"},
            {"apiName": "fm_ac_3_ln_qty", "type": "number", "readOnly": true, "colSpan": 2, "isQuantity": true, "formula": "(fm_ac_3_qty || 0)"},
            {"apiName": "fm_ac_3_ln_unit_price", "type": "number", "readOnly": true, "colSpan": 2, "isUnitPrice": true, "formula": "(fm_ac_3_amount || 0) * (1 + (fm_ac_realization || 0) / 100)"},
            {"apiName": "fm_ac_3_ln_unit_cost", "type": "number", "readOnly": true, "colSpan": 2, "isUnitCost": true, "formula": "(fm_ac_3_amount || 0) * (1 + (fm_ac_realization || 0) / 100)"}
        ]
    },
    {
        "id": "fm_ac_line_4",
        "label": "FLAG MAST ACCESSORY - Motor",
        "expanded": false,
        "isVisible": false,
        "forceHidden": true,
        "revealedHiddenInputs": true,
        "controllingField": "fm_ac_4_qty",
        "controllingValues": [">=1"],
        "lineItemGroup": "fm_ac_line_4",
        "fields": [
            {"apiName": "fm_ac_4_ln_designation", "type": "text", "readOnly": true, "colSpan": 6, "label": "Motor", "value": "Motor"},
            {"apiName": "fm_ac_4_ln_qty", "type": "number", "readOnly": true, "colSpan": 2, "isQuantity": true, "formula": "(fm_ac_4_qty || 0)"},
            {"apiName": "fm_ac_4_ln_unit_price", "type": "number", "readOnly": true, "colSpan": 2, "isUnitPrice": true, "formula": "(fm_ac_4_amount || 0) * (1 + (fm_ac_realization || 0) / 100)"},
            {"apiName": "fm_ac_4_ln_unit_cost", "type": "number", "readOnly": true, "colSpan": 2, "isUnitCost": true, "formula": "(fm_ac_4_amount || 0) * (1 + (fm_ac_realization || 0) / 100)"}
        ]
    },
    {
        "id": "fm_ac_line_5",
        "label": "FLAG MAST ACCESSORY - Snap hook",
        "expanded": false,
        "isVisible": false,
        "forceHidden": true,
        "revealedHiddenInputs": true,
        "controllingField": "fm_ac_5_qty",
        "controllingValues": [">=1"],
        "lineItemGroup": "fm_ac_line_5",
        "fields": [
            {"apiName": "fm_ac_5_ln_designation", "type": "text", "readOnly": true, "colSpan": 6, "label": "Snap hook", "value": "Snap hook"},
            {"apiName": "fm_ac_5_ln_qty", "type": "number", "readOnly": true, "colSpan": 2, "isQuantity": true, "formula": "(fm_ac_5_qty || 0)"},
            {"apiName": "fm_ac_5_ln_unit_price", "type": "number", "readOnly": true, "colSpan": 2, "isUnitPrice": true, "formula": "(fm_ac_5_amount || 0) * (1 + (fm_ac_realization || 0) / 100)"},
            {"apiName": "fm_ac_5_ln_unit_cost", "type": "number", "readOnly": true, "colSpan": 2, "isUnitCost": true, "formula": "(fm_ac_5_amount || 0) * (1 + (fm_ac_realization || 0) / 100)"}
        ]
    },
    {
        "id": "fm_ac_line_6",
        "label": "FLAG MAST ACCESSORY - SS Accessories & Flag Clamps",
        "expanded": false,
        "isVisible": false,
        "forceHidden": true,
        "revealedHiddenInputs": true,
        "controllingField": "fm_ac_6_qty",
        "controllingValues": [">=1"],
        "lineItemGroup": "fm_ac_line_6",
        "fields": [
            {"apiName": "fm_ac_6_ln_designation", "type": "text", "readOnly": true, "colSpan": 6, "label": "SS Accessories & Flag Clamps", "value": "SS Accessories & Flag Clamps"},
            {"apiName": "fm_ac_6_ln_qty", "type": "number", "readOnly": true, "colSpan": 2, "isQuantity": true, "formula": "(fm_ac_6_qty || 0)"},
            {"apiName": "fm_ac_6_ln_unit_price", "type": "number", "readOnly": true, "colSpan": 2, "isUnitPrice": true, "formula": "(fm_ac_6_amount || 0) * (1 + (fm_ac_realization || 0) / 100)"},
            {"apiName": "fm_ac_6_ln_unit_cost", "type": "number", "readOnly": true, "colSpan": 2, "isUnitCost": true, "formula": "(fm_ac_6_amount || 0) * (1 + (fm_ac_realization || 0) / 100)"}
        ]
    },
    {
        "id": "fm_ac_line_7",
        "label": "FLAG MAST ACCESSORY - Counter weight",
        "expanded": false,
        "isVisible": false,
        "forceHidden": true,
        "revealedHiddenInputs": true,
        "controllingField": "fm_ac_7_qty",
        "controllingValues": [">=1"],
        "lineItemGroup": "fm_ac_line_7",
        "fields": [
            {"apiName": "fm_ac_7_ln_designation", "type": "text", "readOnly": true, "colSpan": 6, "label": "Counter weight", "value": "Counter weight"},
            {"apiName": "fm_ac_7_ln_qty", "type": "number", "readOnly": true, "colSpan": 2, "isQuantity": true, "formula": "(fm_ac_7_qty || 0)"},
            {"apiName": "fm_ac_7_ln_unit_price", "type": "number", "readOnly": true, "colSpan": 2, "isUnitPrice": true, "formula": "(fm_ac_7_amount || 0) * (1 + (fm_ac_realization || 0) / 100)"},
            {"apiName": "fm_ac_7_ln_unit_cost", "type": "number", "readOnly": true, "colSpan": 2, "isUnitCost": true, "formula": "(fm_ac_7_amount || 0) * (1 + (fm_ac_realization || 0) / 100)"}
        ]
    },
    {
        "id": "fm_ac_line_8",
        "label": "FLAG MAST ACCESSORY - Control Panel",
        "expanded": false,
        "isVisible": false,
        "forceHidden": true,
        "revealedHiddenInputs": true,
        "controllingField": "fm_ac_8_qty",
        "controllingValues": [">=1"],
        "lineItemGroup": "fm_ac_line_8",
        "fields": [
            {"apiName": "fm_ac_8_ln_designation", "type": "text", "readOnly": true, "colSpan": 6, "label": "Control Panel", "value": "Control Panel"},
            {"apiName": "fm_ac_8_ln_qty", "type": "number", "readOnly": true, "colSpan": 2, "isQuantity": true, "formula": "(fm_ac_8_qty || 0)"},
            {"apiName": "fm_ac_8_ln_unit_price", "type": "number", "readOnly": true, "colSpan": 2, "isUnitPrice": true, "formula": "(fm_ac_8_amount || 0) * (1 + (fm_ac_realization || 0) / 100)"},
            {"apiName": "fm_ac_8_ln_unit_cost", "type": "number", "readOnly": true, "colSpan": 2, "isUnitCost": true, "formula": "(fm_ac_8_amount || 0) * (1 + (fm_ac_realization || 0) / 100)"}
        ]
    },
    {
        "id": "fm_ad_line_1",
        "label": "FM ADDITIONAL ITEM - 32A STD FEEDER PILLAR",
        "expanded": false,
        "isVisible": false,
        "forceHidden": true,
        "revealedHiddenInputs": true,
        "controllingField": "fm_ad_1_qty",
        "controllingValues": [">=1"],
        "lineItemGroup": "fm_ad_line_1",
        "fields": [
            {"apiName": "fm_ad_1_ln_designation", "type": "text", "readOnly": true, "colSpan": 6, "label": "32A STD FEEDER PILLAR", "value": "32A STD FEEDER PILLAR"},
            {"apiName": "fm_ad_1_ln_qty", "type": "number", "readOnly": true, "colSpan": 2, "isQuantity": true, "formula": "(fm_ad_1_qty || 0)"},
            {"apiName": "fm_ad_1_ln_unit_price", "type": "number", "readOnly": true, "colSpan": 2, "isUnitPrice": true, "formula": "(fm_ad_1_amount || 0) * (1 + (fm_ad_realization || 0) / 100)"},
            {"apiName": "fm_ad_1_ln_unit_cost", "type": "number", "readOnly": true, "colSpan": 2, "isUnitCost": true, "formula": "(fm_ad_1_amount || 0) * (1 + (fm_ad_realization || 0) / 100)"}
        ]
    },
    {
        "id": "fm_ad_line_2",
        "label": "FM ADDITIONAL ITEM - GI STAND",
        "expanded": false,
        "isVisible": false,
        "forceHidden": true,
        "revealedHiddenInputs": true,
        "controllingField": "fm_ad_2_qty",
        "controllingValues": [">=1"],
        "lineItemGroup": "fm_ad_line_2",
        "fields": [
            {"apiName": "fm_ad_2_ln_designation", "type": "text", "readOnly": true, "colSpan": 6, "label": "GI STAND", "value": "GI STAND"},
            {"apiName": "fm_ad_2_ln_qty", "type": "number", "readOnly": true, "colSpan": 2, "isQuantity": true, "formula": "(fm_ad_2_qty || 0)"},
            {"apiName": "fm_ad_2_ln_unit_price", "type": "number", "readOnly": true, "colSpan": 2, "isUnitPrice": true, "formula": "(fm_ad_2_amount || 0) * (1 + (fm_ad_realization || 0) / 100)"},
            {"apiName": "fm_ad_2_ln_unit_cost", "type": "number", "readOnly": true, "colSpan": 2, "isUnitCost": true, "formula": "(fm_ad_2_amount || 0) * (1 + (fm_ad_realization || 0) / 100)"}
        ]
    },
    {
        "id": "fm_ad_line_3",
        "label": "FM ADDITIONAL ITEM - CONTROL PANEL FOR MOTOR OPERATE",
        "expanded": false,
        "isVisible": false,
        "forceHidden": true,
        "revealedHiddenInputs": true,
        "controllingField": "fm_ad_3_qty",
        "controllingValues": [">=1"],
        "lineItemGroup": "fm_ad_line_3",
        "fields": [
            {"apiName": "fm_ad_3_ln_designation", "type": "text", "readOnly": true, "colSpan": 6, "label": "CONTROL PANEL FOR MOTOR OPERATE", "value": "CONTROL PANEL FOR MOTOR OPERATE"},
            {"apiName": "fm_ad_3_ln_qty", "type": "number", "readOnly": true, "colSpan": 2, "isQuantity": true, "formula": "(fm_ad_3_qty || 0)"},
            {"apiName": "fm_ad_3_ln_unit_price", "type": "number", "readOnly": true, "colSpan": 2, "isUnitPrice": true, "formula": "(fm_ad_3_amount || 0) * (1 + (fm_ad_realization || 0) / 100)"},
            {"apiName": "fm_ad_3_ln_unit_cost", "type": "number", "readOnly": true, "colSpan": 2, "isUnitCost": true, "formula": "(fm_ad_3_amount || 0) * (1 + (fm_ad_realization || 0) / 100)"}
        ]
    },
    {
        "id": "fm_ad_line_4",
        "label": "FM ADDITIONAL ITEM - SMALL LIGHT FEEDER PILLAR WITH STAND",
        "expanded": false,
        "isVisible": false,
        "forceHidden": true,
        "revealedHiddenInputs": true,
        "controllingField": "fm_ad_4_qty",
        "controllingValues": [">=1"],
        "lineItemGroup": "fm_ad_line_4",
        "fields": [
            {"apiName": "fm_ad_4_ln_designation", "type": "text", "readOnly": true, "colSpan": 6, "label": "SMALL LIGHT FEEDER PILLAR WITH STAND", "value": "SMALL LIGHT FEEDER PILLAR WITH STAND"},
            {"apiName": "fm_ad_4_ln_qty", "type": "number", "readOnly": true, "colSpan": 2, "isQuantity": true, "formula": "(fm_ad_4_qty || 0)"},
            {"apiName": "fm_ad_4_ln_unit_price", "type": "number", "readOnly": true, "colSpan": 2, "isUnitPrice": true, "formula": "(fm_ad_4_amount || 0) * (1 + (fm_ad_realization || 0) / 100)"},
            {"apiName": "fm_ad_4_ln_unit_cost", "type": "number", "readOnly": true, "colSpan": 2, "isUnitCost": true, "formula": "(fm_ad_4_amount || 0) * (1 + (fm_ad_realization || 0) / 100)"}
        ]
    },
    {
        "id": "fm_ad_line_5",
        "label": "FM ADDITIONAL ITEM - Decorative Dome",
        "expanded": false,
        "isVisible": false,
        "forceHidden": true,
        "revealedHiddenInputs": true,
        "controllingField": "fm_ad_5_qty",
        "controllingValues": [">=1"],
        "lineItemGroup": "fm_ad_line_5",
        "fields": [
            {"apiName": "fm_ad_5_ln_designation", "type": "text", "readOnly": true, "colSpan": 6, "label": "Decorative Dome", "value": "Decorative Dome"},
            {"apiName": "fm_ad_5_ln_qty", "type": "number", "readOnly": true, "colSpan": 2, "isQuantity": true, "formula": "(fm_ad_5_qty || 0)"},
            {"apiName": "fm_ad_5_ln_unit_price", "type": "number", "readOnly": true, "colSpan": 2, "isUnitPrice": true, "formula": "(fm_ad_5_amount || 0) * (1 + (fm_ad_realization || 0) / 100)"},
            {"apiName": "fm_ad_5_ln_unit_cost", "type": "number", "readOnly": true, "colSpan": 2, "isUnitCost": true, "formula": "(fm_ad_5_amount || 0) * (1 + (fm_ad_realization || 0) / 100)"}
        ]
    }
];


/* ── PER-ROW SECTIONS (Segment Above 5) — Deepanjan (27th July 2026) ─────────
   Additional Accessories, Special Items and Extra Micron & PU Paint used to be
   quote-level (one set for the whole quote). They now repeat PER MAST ROW for
   Lighting Mast, LCLM and Flag Mast - one instance per grid row that has a
   No. of Segment - exactly like the Overlap/welding accordion-repeater.
   Stadium Mast is untouched (its own STADIUM_MODALFIELDS never used these).

   The engine's clone is a raw SUBSTRING replace (split('lm_').join('r{n}_lm_')
   on the JSON string), which forces two source-level rules:
     1. The old cross-row pick-first formulas inside Additional Accessories
        (r1_lm_quantity || r2_lm_quantity || ...) would be mangled into
        r{n}_r1_lm_quantity garbage. Per-row they must read the ROW'S OWN
        value anyway, so they become plain lm_quantity / lm_height_of_mast
        and the clone itself makes them r{n}_-specific.
     2. si_price_add / si_weight_add were deliberately UNPREFIXED to stay
        quote-level. Per-row they must clone WITH the section, so they are
        renamed lm_si_price_add / lm_si_weight_add here and in the segment
        unit-price/cost formulas above - the same substring replace then
        keeps each row's fold aligned with that row's segments.

   The blueprints are DERIVED from the existing definitions at runtime rather
   than duplicated, so there is exactly one source of truth to maintain. */

function _seg5PerRowBlueprints() {
    const aa = JSON.parse(JSON.stringify(
        LM_MODALFIELDS.find(sec => sec.id === 'lm_additional_accessories').fields));
    aa.find(f => f.apiName === 'lm_qty_of_hm').formula   = '(lm_quantity || 0)';
    aa.find(f => f.apiName === 'lm_mast_height').formula = '(lm_height_of_mast || 0) * 10';

    const si = JSON.parse(JSON.stringify(
        LM_MODALFIELDS.find(sec => sec.id === 'lm_special_items').fields));
    si.forEach(f => {
        if (f.apiName === 'si_price_add')  f.apiName = 'lm_si_price_add';
        if (f.apiName === 'si_weight_add') f.apiName = 'lm_si_weight_add';
    });

    const pu = JSON.parse(JSON.stringify(SEG5_MICRON_PU_PAINT.fields));

    return {
        lm_additional_accessories: aa,
        lm_special_items:          si,
        lm_micron_pu_paint:        pu
    };
}

/* One accordion-repeater per section - same recipe as the Overlap/welding
   repeater, so each instance appears only when its row has a segment count. */
const SEG5_ROW_SEGMENT_VALUES = ['6', '7', '8', '9', '10', '11', '12', '13', '14', '15'];

function _seg5RowRepeater(cloneFrom, label) {
    return {
        type: 'accordion-repeater',
        gridFieldApi: 'lm_no_of_segment',
        maxRows: 10,
        cloneFrom: cloneFrom,
        label: label,
        replaceTarget: 'lm_',
        controllingValues: SEG5_ROW_SEGMENT_VALUES.slice()
    };
}

/* LCLM's two extra sections repeat per row too (27th July 2026). Their fields
   are entirely lm_-prefixed and they carry no hidden/line-item flags, so the
   plain accordion-repeater route is safe - same recipe as the sections above.
   Blueprints are derived from LCLM_EXTRA_SECTIONS so there is still exactly
   one definition to maintain. */
function _lclmPerRowBlueprints() {
    return {
        lclm_lightning_spike: JSON.parse(JSON.stringify(
            LCLM_EXTRA_SECTIONS.find(sec => sec.id === 'lclm_lightning_spike').fields)),
        lclm_down_conductor: JSON.parse(JSON.stringify(
            LCLM_EXTRA_SECTIONS.find(sec => sec.id === 'lclm_down_conductor').fields))
    };
}

const SEG5_AA_REPEATER = () => _seg5RowRepeater('lm_additional_accessories', 'Additional Accessories {row}');
const SEG5_SI_REPEATER = () => _seg5RowRepeater('lm_special_items',          'Special Items {row}');
const SEG5_PU_REPEATER = () => _seg5RowRepeater('lm_micron_pu_paint',        'Extra Micron & PU Paint {row}');
const LCLM_SPIKE_REPEATER = () => _seg5RowRepeater('lclm_lightning_spike',   'Lightning Spike Details {row}');
const LCLM_DC_REPEATER    = () => _seg5RowRepeater('lclm_down_conductor',    'Down Conductor Details {row}');

/* ── FLAG MAST per-row ACCESSORY COSTING / Additional Details — Deepanjan
   (27th July 2026) ─────────────────────────────────────────────────────────
   These cannot go through the accordion-repeater: the engine's expansion
   copies only id/label/expanded/controlling/clone keys, which would DROP the
   forceHidden / isVisible / revealedHiddenInputs / lineItemGroup flags that
   make the twelve line-item sections invisible internal blocks. So they are
   pre-expanded HERE instead - one clone per grid row, produced with the very
   same substring replace the engine uses (split('fm_').join('r{n}_fm_')),
   preserving every flag byte-for-byte. The substring replace also rewrites
   controllingField (fm_ac_1_qty -> r{n}_fm_ac_1_qty) and lineItemGroup
   (fm_ac_line_1 -> r{n}_fm_ac_line_1), so each row emits its OWN quote line
   items. The two visible tables get " {row}" appended to their labels and are
   re-pointed at that row's segment count, exactly like the other per-row
   sections. */
function _fmPerRowCostingSections() {
    const out = [];
    const source = FM_SEG5_EXTRA_SECTIONS.concat(FM_SEG5_LINE_ITEM_SECTIONS);
    for (let r = 1; r <= 10; r++) {
        const cloned = JSON.parse(
            JSON.stringify(source).split('fm_').join('r' + r + '_fm_'));
        cloned.forEach(sec => {
            if (sec.id === 'r' + r + '_fm_accessory_costing' ||
                sec.id === 'r' + r + '_fm_additional_details') {
                sec.label = sec.label + ' ' + r;
                sec.controllingField  = 'r' + r + '_lm_no_of_segment';
                sec.controllingValues = SEG5_ROW_SEGMENT_VALUES.slice();
            }
        });
        out.push(...cloned);
    }
    return out;
}

/* Remove the old quote-level sections from a cloned base so their per-row
   repeaters can take their place. */
function _stripSections(sections, ids) {
    const drop = {};
    ids.forEach(id => { drop[id] = true; });
    return sections.filter(sec => !drop[sec.id]);
}

/* RING DIAMETER is an open entry for LCLM ONLY - Deepanjan (20th Aug 2026).
   Lighting Mast keeps its 600/800/1050/1200 picklist, so this is applied to
   LCLM's own deep clone of LM_MODALFIELDS rather than to the shared constant.
   lm_ring_diameter feeds no formula anywhere, so nothing else is affected. */
function _openRingDiameter(sections) {
    const lr = sections.find(sec => sec.id === 'lm_l_ring_details');
    if (!lr) return sections;
    (lr.fields || []).forEach(f => {
        (f.fields || [f]).forEach(g => {
            if (g && g.apiName === 'lm_ring_diameter') {
                // 'text', NOT 'number': the picklist stored "600" as a STRING, and
                // the weight PDF reads this key. A number type would save 600 and
                // any (String) cast / String.valueOf in Apex would break or print
                // "600.0". text keeps the stored shape byte-identical to before.
                g.type = 'text';
                delete g.options;
            }
        });
    });
    return sections;
}

export function buildDynamicMast(mastType) {
    if (mastType === 'Lighting Mast') {
        // Additional Accessories / Special Items / Extra Micron & PU Paint are
        // per-row repeaters since 27-Jul (see the block above buildDynamicMast).
        return {
            // 'lm_l_ring_details' is dropped for LIGHTING MAST ONLY - Deepanjan
            // (21st Aug 2026). LCLM's branch below keeps the section (and its open
            // RING DIAMETER), and Flag Mast never had it. Nothing else depends on
            // it: zero formulas, zero controllingFields, and neither offer builder
            // reads lm_type_of_l_ring / lm_ring_diameter - only the weight PDF does,
            // where the two cells now come out blank.
            modalFields: _stripSections(
                    JSON.parse(JSON.stringify(LM_MODALFIELDS)),
                    ['lm_l_ring_details', 'lm_additional_accessories', 'lm_special_items'])
                .concat([SEG5_AA_REPEATER(), SEG5_SI_REPEATER(), SEG5_PU_REPEATER()]),
            blueprints: Object.assign(_buildBlueprints(), _seg5PerRowBlueprints())
        };
    }
    if (mastType === 'LCLM') {
        // Same recipe and blueprints as Lighting Mast (weight is already manual entry here),
        // with the spike / down-conductor sections appended. - Reetabrata (15th July 2026)
        // Accessories / Special Items / PU Paint are per-row repeaters since 27-Jul,
        // and so are Lightning Spike / Down Conductor (same date, same recipe).
        return {
            // 'lm_l_ring_details' dropped for LCLM too - Deepanjan (22nd Aug 2026), same
            // grounds as the Lighting Mast removal: no formula or controllingField reads
            // lm_type_of_l_ring / lm_ring_diameter, neither offer builder reads them, only
            // the weight PDF does (those two cells come out blank, as already accepted for
            // Lighting Mast). 1 TIER/2 TIER L-RING and TYPE OF RING V/W live in Additional
            // Accessories and still reach the KIT table. _openRingDiameter() is a no-op
            // here now, kept for the day the section comes back.
            modalFields: _openRingDiameter(_stripSections(
                    JSON.parse(JSON.stringify(LM_MODALFIELDS)),
                    ['lm_l_ring_details', 'lm_additional_accessories', 'lm_special_items']))
                .concat([LCLM_SPIKE_REPEATER(), LCLM_DC_REPEATER()])
                .concat([SEG5_AA_REPEATER(), SEG5_SI_REPEATER(), SEG5_PU_REPEATER()]),
            blueprints: Object.assign(
                _buildBlueprints(), _seg5PerRowBlueprints(), _lclmPerRowBlueprints())
        };
    }
    if (mastType === 'Stadium Mast') {
        // Segment Above 5 for Stadium Mast - Reetabrata (9th July 2026)
        // Middles mid2..mid14 are all present and shown via '>=N' controllingValues,
        // so any segment count 6..15 works with no per-N blueprints.
        return {
            modalFields: JSON.parse(JSON.stringify(STADIUM_MODALFIELDS)),
            blueprints: {}
        };
    }
    if (mastType === 'Flag Mast') {
        // Flag Mast (Segment Above 5) - Deepanjan (19th July 2026)
        // Same LM recipe/blueprints as Lighting Mast & LCLM (segment weight is
        // already MANUAL entry there), minus L-Ring and Additional Accessories,
        // in the order asked for: General Details, Segments (6-15), Base Plate,
        // Foundation Bolt & Stiffener, Extra Micron & PU Paint, Accessory
        // Costing Format, Additional Details, Special Items. Segment accordion
        // labels read "FM - Segment" instead of "LM - Segment"; apiNames stay
        // lm_ so every engine formula (price, overlap, welding) works unchanged.
        // Special Items and Extra Micron & PU Paint are per-row repeaters since
        // 27-Jul; Additional Accessories stays dropped for Flag Mast as before.
        const kept = _stripSections(
            JSON.parse(JSON.stringify(LM_MODALFIELDS)),
            ['lm_l_ring_details', 'lm_additional_accessories', 'lm_special_items']);
        kept.forEach(sec => {
            if (sec.type === 'matrix-accordion-repeater' && Array.isArray(sec.templates)) {
                sec.templates.forEach(t => { t.label = String(t.label || '').replace('LM - Segment', 'FM - Segment'); });
            }
        });
        return {
            modalFields: kept
                .concat([SEG5_PU_REPEATER()])
                .concat(_fmPerRowCostingSections())
                .concat([SEG5_SI_REPEATER()]),
            blueprints: Object.assign(_buildBlueprints(), _seg5PerRowBlueprints())
        };
    }
    // Unknown mast type: keep the old stub so the modal never renders empty.
    return {
        modalFields: [{ id: 'seg5_stub', label: mastType + ' - Not Configured', expanded: true,
            fields: [{ apiName: 'seg5_stub_note', label: mastType + ' has its own UI and calculation, which is not built yet.', type: 'header', colSpan: 12 }] }],
        blueprints: {}
    };
}

// GST is applied ONCE, in the offer VF page. It used to be multiplied into every
// Stadium unit price and unit cost here as well, and Apex reads several of those
// figures straight out of the estimator JSON and hands them to buildRow(), which
// adds GST again - so every Stadium offer line carried GST twice. The Segment
// Above 5 formulas above were stripped of GST for the same reason (see the 22
// "gst removed" notes); Stadium was missed. Deepanjan (19th Aug 2026)
const STADIUM_MODALFIELDS = [
    {
        "id": "stadium_mast_types",
        "label": "STADIUM MAST TYPES",
        "expanded": true,
        "showRequired": true,
        "isCheckboxGroup": true,
        "fields": [
            {"apiName": "man_riding_lift", "label": "Man Riding Lift", "type": "checkbox", "colSpan": 6, "required": false},
            {"apiName": "ladder_with_cage", "label": "Ladder With Cage", "type": "checkbox", "colSpan": 6, "required": false},
            {"apiName": "man_riding_wind_speed", "label": "Wind Speed", "type": "text", "colSpan": 6, "required": false},
            {"apiName": "ladder_cage_wind_speed", "label": "Wind Speed", "type": "text", "colSpan": 6, "required": false}
        ]
    },
    {
        "id": "general_details_man_riding_lift",
        "label": "GENERAL DETAILS - MAN RIDING LIFT",
        "expanded": true,
        "showRequired": true,
        "controllingField": "man_riding_lift",
        "controllingValues": ["true"],
        "fields": [
            {"apiName": "mrl_segment_height", "label": "SEGMENT HEIGHT", "type": "number", "required": true, "unit": "MTRS"},
            {"apiName": "mrl_head_frame_height", "label": "HEAD FRAME HEIGHT", "type": "number", "required": true, "unit": "MTRS"},
            {"apiName": "mrl_height_of_mast", "label": "HEIGHT OF THE MAST", "type": "number", "required": false, "unit": "MTRS", "defaultValue": 0, "readOnly": true, "formula": "mrl_segment_height + mrl_head_frame_height"},
            {"apiName": "mrl_no_of_segment", "label": "NO OF SEGMENT", "type": "number", "required": true, "unit": "6 TO 15", "min": 6, "max": 15},
            {"apiName": "mrl_top_dia", "label": "TOP DIA", "type": "number", "required": true, "unit": "MM"},
            {"apiName": "mrl_bottom_dia", "label": "BOTTOM DIA", "type": "number", "required": true, "unit": "MM"},
            {"apiName": "mrl_is_extra_micron", "label": "EXTRA MICRON?", "type": "checkbox"},
            {"apiName": "mrl_extra_micron", "label": "EXTRA MICRON VALUE?", "type": "text", "controllingField": "mrl_is_extra_micron", "controllingValues": ["true"]},
            {"apiName": "mrl_pu_paint", "label": "PU PAINT", "type": "checkbox"},
            {"apiName": "mrl_pu_paint_note", "label": "Note", "type": "text", "controllingField": "mrl_pu_paint", "controllingValues": ["true"]},
            {"apiName": "mrl_pu_paint_price", "label": "PRICE VALUE", "type": "number", "controllingField": "mrl_pu_paint", "controllingValues": ["true"]},
            // PU Paint realization - was missing on Stadium, so the charge went in at cost.
            // Default 5%, same as Flag Mast/Lighting Mast. Deepanjan (21st Aug 2026)
            {"apiName": "mrl_pu_paint_realization", "label": "REALIZATION", "type": "number", "unit": "%", "defaultValue": 5, "controllingField": "mrl_pu_paint", "controllingValues": ["true"]}
        ]
    },
    {
        "id": "mrl_segment_weight_details",
        "label": "Segment Weight Details",
        "expanded": true,
        "showRequired": true,
        "controllingField": "man_riding_lift",
        "controllingValues": ["true"],
        "fields": [
            // Duplicate of BASE MAN RIDING PRICE in Segment Dimension - hidden now that the Apex
            // side no longer depends on it: stadiumSiRatePerKg() reads amount_realization first
            // and man_riding_base_price / ladder_cage_base_price as the fallback, both of which
            // persist. Still computed here for the Special Items formulas. Deepanjan (21st Aug 2026)
            {"apiName": "mrl_base_amount", "type": "hidden", "formula": "Base_Amount__c"},
            {"apiName": "mrl_weight", "label": "Weight", "type": "number", "colSpan": 4},
            {"apiName": "mrl_quantity", "label": "Quantity", "type": "number", "required": false, "colSpan": 3},
            {"apiName": "mrl_amount_realization", "label": "Total Price", "type": "number", "colSpan": 4, "formula": "(Base_Amount__c || 0) + 10"},
            {"apiName": "mrl_realization", "type": "hidden", "isRealization": true, "formula": "(mrl_amount_realization || 0) - (Base_Amount__c || 0)"},
                        // UNIT PRICE / UNIT COST removed from Segment Weight Details - Deepanjan (22nd Aug 2026).
            // They printed the exact same two numbers as UNIT MAN RIDING PRICE / UNIT MAN RIDING
            // COST further down in Segment Dimension (595250 / 545000 on his own screen), and
            // because their apiNames ended in _unit_price / _unit_cost the estimator also priced
            // this display-only section as a SECOND line item at the full mast price. Dropping
            // them fixes the duplicate on screen AND on the quote; the section now matches the
            // Ladder With Cage copy, which never had them.
        ]
    },
    {
        "id": "man_riding_lift_section",
        "label": "Segment Dimension",
        "expanded": false,
        "showRequired": true,
        "controllingField": "mrl_no_of_segment",
        "controllingValues": [">=6"],
        "fields": [
            {"apiName": "mrl_lbl_top", "label": "TOP SEGMENT", "type": "header", "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=6"]},
            {"apiName": "mrl_top_segment_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=6"]},
            {"apiName": "mrl_top_segment_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=6"]},
            {"apiName": "mrl_lbl_mid2", "label": "MIDDLE SEGMENT - 2", "type": "header", "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=6"]},
            {"apiName": "mrl_middle_segment_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=6"], "formula": "(mrl_top_segment_length || 0)"},
            {"apiName": "mrl_middle_segment_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=6"], "formula": "(mrl_top_segment_thickness || 0)"},
            {"apiName": "mrl_lbl_mid3", "label": "MIDDLE SEGMENT - 3", "type": "header", "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=4"]},
            {"apiName": "mrl_mid3_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=4"], "formula": "(mrl_top_segment_length || 0)"},
            {"apiName": "mrl_mid3_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=4"], "formula": "(mrl_top_segment_thickness || 0)"},
            {"apiName": "mrl_lbl_mid4", "label": "MIDDLE SEGMENT - 4", "type": "header", "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=5"]},
            {"apiName": "mrl_mid4_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=5"], "formula": "(mrl_top_segment_length || 0)"},
            {"apiName": "mrl_mid4_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=5"], "formula": "(mrl_top_segment_thickness || 0)"},
            {"apiName": "mrl_lbl_mid5", "label": "MIDDLE SEGMENT - 5", "type": "header", "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=6"]},
            {"apiName": "mrl_mid5_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=6"], "formula": "(mrl_top_segment_length || 0)"},
            {"apiName": "mrl_mid5_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=6"], "formula": "(mrl_top_segment_thickness || 0)"},
            {"apiName": "mrl_lbl_mid6", "label": "MIDDLE SEGMENT - 6", "type": "header", "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=7"]},
            {"apiName": "mrl_mid6_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=7"], "formula": "(mrl_top_segment_length || 0)"},
            {"apiName": "mrl_mid6_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=7"], "formula": "(mrl_top_segment_thickness || 0)"},
            {"apiName": "mrl_lbl_mid7", "label": "MIDDLE SEGMENT - 7", "type": "header", "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=8"]},
            {"apiName": "mrl_mid7_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=8"], "formula": "(mrl_top_segment_length || 0)"},
            {"apiName": "mrl_mid7_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=8"], "formula": "(mrl_top_segment_thickness || 0)"},
            {"apiName": "mrl_lbl_mid8", "label": "MIDDLE SEGMENT - 8", "type": "header", "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=9"]},
            {"apiName": "mrl_mid8_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=9"], "formula": "(mrl_top_segment_length || 0)"},
            {"apiName": "mrl_mid8_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=9"], "formula": "(mrl_top_segment_thickness || 0)"},
            {"apiName": "mrl_lbl_mid9", "label": "MIDDLE SEGMENT - 9", "type": "header", "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=10"]},
            {"apiName": "mrl_mid9_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=10"], "formula": "(mrl_top_segment_length || 0)"},
            {"apiName": "mrl_mid9_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=10"], "formula": "(mrl_top_segment_thickness || 0)"},
            {"apiName": "mrl_lbl_mid10", "label": "MIDDLE SEGMENT - 10", "type": "header", "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=11"]},
            {"apiName": "mrl_mid10_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=11"], "formula": "(mrl_top_segment_length || 0)"},
            {"apiName": "mrl_mid10_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=11"], "formula": "(mrl_top_segment_thickness || 0)"},
            {"apiName": "mrl_lbl_mid11", "label": "MIDDLE SEGMENT - 11", "type": "header", "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=12"]},
            {"apiName": "mrl_mid11_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=12"], "formula": "(mrl_top_segment_length || 0)"},
            {"apiName": "mrl_mid11_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=12"], "formula": "(mrl_top_segment_thickness || 0)"},
            {"apiName": "mrl_lbl_mid12", "label": "MIDDLE SEGMENT - 12", "type": "header", "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=13"]},
            {"apiName": "mrl_mid12_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=13"], "formula": "(mrl_top_segment_length || 0)"},
            {"apiName": "mrl_mid12_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=13"], "formula": "(mrl_top_segment_thickness || 0)"},
            {"apiName": "mrl_lbl_mid13", "label": "MIDDLE SEGMENT - 13", "type": "header", "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=14"]},
            {"apiName": "mrl_mid13_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=14"], "formula": "(mrl_top_segment_length || 0)"},
            {"apiName": "mrl_mid13_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=14"], "formula": "(mrl_top_segment_thickness || 0)"},
            {"apiName": "mrl_lbl_mid14", "label": "MIDDLE SEGMENT - 14", "type": "header", "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=15"]},
            {"apiName": "mrl_mid14_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=15"], "formula": "(mrl_top_segment_length || 0)"},
            {"apiName": "mrl_mid14_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=15"], "formula": "(mrl_top_segment_thickness || 0)"},
            {"apiName": "mrl_lbl_bottom", "label": "BOTTOM", "type": "header", "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=6"]},
            {"apiName": "mrl_bottom_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=6"], "formula": "(mrl_top_segment_length || 0)"},
            {"apiName": "mrl_bottom_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "mrl_no_of_segment", "controllingValues": [">=6"], "formula": "(mrl_top_segment_thickness || 0)"},
            {"apiName": "mrl_man_riding_total_weight", "label": "MAN RIDING TOTAL WEIGHT (KG)", "type": "number", "readOnly": true, "isWeightTotal": true, "formula": "(mrl_weight || 0)"},
            {"apiName": "mrl_man_riding_base_price", "label": "BASE MAN RIDING PRICE", "type": "number", "readOnly": true, "isBasePrice": true, "formula": "Base_Amount__c"},
            {"apiName": "mrl_man_riding_unit_price", "label": "UNIT MAN RIDING PRICE", "isUnitPrice": true, "type": "number", "readOnly": true, "formula": "(((Base_Amount__c || 0) + (mrl_realization || 0)) * (mrl_weight || 0)) + (mrl_pu_paint ? (typeof mrl_pu_paint_price !== \"undefined\" ? ((mrl_pu_paint_price || 0) * (1 + ((typeof mrl_pu_paint_realization !== \"undefined\" ? (mrl_pu_paint_realization || 0) : 0)) / 100)) : 0) : 0)"},
            {"apiName": "mrl_man_riding_unit_cost", "label": "UNIT MAN RIDING COST", "isUnitCost": true, "type": "number", "readOnly": true, "formula": "((Base_Amount__c || 0) * (mrl_weight || 0)) + (mrl_pu_paint ? (typeof mrl_pu_paint_price !== \"undefined\" ? (mrl_pu_paint_price || 0) : 0) : 0)"},
            // Duplicate of "Quantity" in Segment Weight Details. Deepanjan (21st Aug 2026)
            {"apiName": "mrl_ghost_quantity_for_top_section", "type": "hidden", "isQuantity": true, "formula": "(mrl_quantity || 1)"},
            {"apiName": "mrl_ghost_realization_for_top_section", "type": "hidden", "isRealization": true, "formula": "(mrl_realization || 0)"},
            {"apiName": "mrl_hdr_base_plate", "label": "BASE PLATE", "type": "header", "readOnly": true, "colSpan": 12},
            {"apiName": "mrl_bp_diameter", "label": "DIAMETER", "type": "number", "required": false, "colSpan": 3},
            {"apiName": "mrl_bp_thickness", "label": "THICKNESS", "type": "number", "required": false, "colSpan": 3},
            {"apiName": "mrl_bp_pcd", "label": "PCD", "type": "number", "required": false, "colSpan": 3},
            {"apiName": "mrl_bp_spacer_1", "label": "-", "type": "header", "readOnly": true, "colSpan": 3}
        ]
    },
    {
        "id": "accessories_man_riding_lift",
        "label": "ACCESSORIES & ESTIMATION",
        "expanded": false,
        "showRequired": true,
        "controllingField": "mrl_no_of_segment",
        "controllingValues": [">=6"],
        "fields": [
            {"apiName": "mrl_hdr_seg_acc", "label": "SEGMENT DETAILS", "type": "header", "readOnly": true, "colSpan": 12},
            {"apiName": "mrl_no_of_lum", "label": "No. of lum", "type": "number", "required": true, "colSpan": 3},
            {"apiName": "mrl_type_of_lum", "label": "Type of Lum.", "type": "picklist", "required": true, "options": ["Asymmetric"], "colSpan": 3},
            {"apiName": "mrl_watt", "label": "Watt", "type": "number", "required": true, "colSpan": 3},
            {"apiName": "mrl_special_note", "label": "Special Note", "type": "text", "required": false, "colSpan": 3},
            {"apiName": "mrl_foundation_bolt_label", "label": "FOUNDATION BOLT", "type": "header", "readOnly": true, "colSpan": 12},
            {"apiName": "mrl_foundation_bolt_type", "label": "FOUNDATION BOLT TYPE", "type": "picklist", "required": false, "options": ["with Foundation Bolt", "without Foundation Bolt"], "colSpan": 3},
            {"apiName": "mrl_fb_amount_realization", "label": "Total Price", "type": "number", "required": false, "colSpan": 3, "formula": "(Base_Amount__c || 0) + 10", "disableControllingField": "mrl_foundation_bolt_type", "disableControllingValues": ["with Foundation Bolt"]},
            {"apiName": "mrl_fb_realization", "type": "hidden", "isRealization": true, "formula": "(mrl_fb_amount_realization || 0) - (Base_Amount__c || 0)"},
            {"apiName": "mrl_fb_spacer_1", "label": "-", "type": "header", "readOnly": true, "colSpan": 3},
            {"apiName": "mrl_fb_diameter", "label": "Diameter", "type": "number", "required": false, "colSpan": 3},   // open field, was a picklist - UIL-HM-084. Deepanjan (19th Aug 2026)
            {"apiName": "mrl_fb_length", "label": "Length", "type": "number", "required": false, "colSpan": 3},
            {"apiName": "mrl_fb_no_of_bolt", "label": "No. of bolt", "type": "number", "required": false, "colSpan": 3},
            {"apiName": "mrl_fb_quantity", "label": "quantity", "type": "number", "required": true, "isQuantity": true, "colSpan": 3, "disableControllingField": "mrl_foundation_bolt_type", "disableControllingValues": ["with Foundation Bolt"], "controllingField": "mrl_foundation_bolt_type", "controllingValues": ["with Foundation Bolt"]},
            {"apiName": "mrl_foundation_weight", "label": "FOUNDATION WEIGHT (KG)", "type": "number", "readOnly": false, "isWeightTotal": true, "required": true, "colSpan": 3, "controllingField": "mrl_foundation_bolt_type", "controllingValues": ["with Foundation Bolt"]},
            {"apiName": "mrl_foundation_base_price", "label": "BASE FOUNDATION PRICE", "type": "number", "readOnly": true, "isBasePrice": true, "formula": "Base_Amount__c"},
            {"apiName": "mrl_foundation_unit_price", "label": "UNIT FOUNDATION PRICE", "isUnitPrice": true, "type": "number", "readOnly": true, "formula": "(((Base_Amount__c || 0) + (mrl_fb_realization || 0)) * (mrl_foundation_weight || 0))"},
            {"apiName": "mrl_foundation_unit_cost", "label": "UNIT FOUNDATION COST", "isUnitCost": true, "type": "number", "readOnly": true, "formula": "((Base_Amount__c || 0) * (mrl_foundation_weight || 0))"}
        ]
    },
    {
        "id": "mast_accessories_man_riding_lift",
        "label": "Man Riding Lift Details",
        "expanded": false,
        "showRequired": true,
        "controllingField": "mrl_no_of_segment",
        "controllingValues": [">=6"],
        "fields": [
            {"apiName": "mrl_mast_acc_description", "label": "Description", "type": "text", "required": false, "colSpan": 3},
            {"apiName": "mrl_mast_acc_rate", "label": "Rate", "type": "number", "required": true, "colSpan": 3},
            {"apiName": "mrl_mast_acc_realization", "label": "Realization", "type": "number", "unit": "%", "required": false, "defaultValue": 5, "colSpan": 3},
            {"apiName": "mrl_mast_acc_quantity", "label": "quantity", "type": "number", "required": true, "isQuantity": true, "readOnly": false, "defaultValue": 1, "colSpan": 3},
            {"apiName": "mrl_mast_acc_foundation_base_price", "label": "MAST ACCESSORIES BASE FOUNDATION PRICE", "type": "number", "readOnly": true, "isBasePrice": true, "formula": "mrl_mast_acc_rate"},
            {"apiName": "mrl_mast_acc_foundation_unit_price", "label": "MAST ACCESSORIES UNIT FOUNDATION PRICE", "isUnitPrice": true, "type": "number", "readOnly": true, "formula": "((mrl_mast_acc_rate || 0) * (1 + (mrl_mast_acc_realization || 0) / 100))"},
            {"apiName": "mrl_mast_acc_foundation_unit_cost", "label": "MAST ACCESSORIES UNIT FOUNDATION COST", "isUnitCost": true, "type": "number", "readOnly": true, "formula": "((mrl_mast_acc_rate || 0))"}
        ]
    },
    /* ── MOVED UP ── Deepanjan (6th September 2026)
       This block (winch / power tool / wire rope / accessories RATE) is gated on
       man_riding_lift, i.e. it belongs to the Man Riding Lift mast - but it sat at the
       very bottom, AFTER all the Ladder-With-Cage sections and just above Special Items.
       Users filling the MRL mast top-down never reached it (Q 00001317 went out with no
       accessories line at all). Same object, same apiNames, same gating - only its
       position in the accordion has changed. Bugs 1 & 4 of the Stadium seg5 list. */
    {
        "id": "lm_additional_accessories",
        "label": "Additional Accessories",
        "expanded": false,
        "controllingField": "man_riding_lift",
        "controllingValues": ["true"],
        "fields": [
            // Open fields with a disabled unit box, exactly like the Lighting Mast block
            // above (lm_winch_unit / lm_power_tool_unit / lm_wire_rope_unit and the
            // SGDD/DGDD drum picklist). Same apiNames, so nothing downstream re-maps -
            // only the input type changes. Row stays 12 wide. Deepanjan (21st Aug 2026)
            {"apiName": "lm_type_of_winch", "label": "TYPE OF WINCH", "type": "text", "colSpan": 3},
            {"apiName": "lm_winch_unit", "label": " ", "type": "text", "readOnly": true, "disabled": true, "defaultValue": "KG", "colSpan": 1},
            {"apiName": "lm_winch_drum", "label": "DRUM TYPE", "type": "picklist", "options": ["", "SGDD", "DGDD"], "colSpan": 4},
            {"apiName": "lm_type_of_power_tool", "label": "TYPE OF POWER TOOL", "type": "text", "colSpan": 3},
            {"apiName": "lm_power_tool_unit", "label": " ", "type": "text", "readOnly": true, "disabled": true, "defaultValue": "HP", "colSpan": 1},
            {"apiName": "lm_type_of_wire_rope", "label": "TYPE OF WIRE ROPE", "type": "text", "colSpan": 3},
            {"apiName": "lm_wire_rope_unit", "label": " ", "type": "text", "readOnly": true, "disabled": true, "defaultValue": "mm Dia", "colSpan": 1},
            {"apiName": "lm_acc_spacer_1", "label": " ", "type": "header", "readOnly": true, "colSpan": 8},
            // RATE is mandatory whenever this block is visible, i.e. Man Riding Lift is ticked.
            // The "at least one of TYPE OF WINCH / DRUM TYPE / TYPE OF POWER TOOL / TYPE OF
            // WIRE ROPE" half of the rule is a cross-field check and lives in
            // weightEstimatorModal._validateStadiumAccessoryType. Deepanjan (6th September 2026)
            {"apiName": "lm_acc_rate", "label": "RATE", "type": "number", "colSpan": 3, "required": true},
            {"apiName": "lm_acc_realization", "label": "REALIZATION", "type": "number", "colSpan": 3, "defaultValue": 5, "unit": "%"},
            {"apiName": "lm_acc_realization_amount", "label": "REALIZATION AMOUNT", "type": "number", "colSpan": 3, "readOnly": true, "formula": "(lm_acc_rate || 0) * (lm_acc_realization || 0) / 100"},
            {"apiName": "lm_acc_total_rate", "label": "TOTAL RATE", "type": "number", "colSpan": 3, "readOnly": true, "formula": "(lm_acc_rate || 0) + ((lm_acc_rate || 0) * (lm_acc_realization || 0) / 100)"}
        ]
    },
    {
        "id": "general_details_ladder_with_cage",
        "label": "GENERAL DETAILS - LADDER WITH CAGE",
        "expanded": false,
        "showRequired": true,
        "controllingField": "ladder_with_cage",
        "controllingValues": ["true"],
        "fields": [
            {"apiName": "lwc_segment_height", "label": "SEGMENT HEIGHT", "type": "number", "required": true, "unit": "MTRS"},
            {"apiName": "lwc_head_frame_height", "label": "HEAD FRAME HEIGHT", "type": "number", "required": true, "unit": "MTRS"},
            {"apiName": "lwc_height_of_mast", "label": "HEIGHT OF THE MAST", "type": "number", "required": false, "unit": "MTRS", "defaultValue": 0, "readOnly": true, "formula": "lwc_segment_height + lwc_head_frame_height"},
            {"apiName": "lwc_no_of_segment", "label": "NO. OF SEGMENT", "type": "number", "required": true, "unit": "6 TO 15", "min": 6, "max": 15},
            {"apiName": "lwc_top_dia", "label": "TOP DIA", "type": "number", "required": true, "unit": "MM"},
            {"apiName": "lwc_bottom_dia", "label": "BOTTOM DIA", "type": "number", "required": true, "unit": "MM"},
            {"apiName": "lwc_is_extra_micron", "label": "EXTRA MICRON?", "type": "checkbox"},
            {"apiName": "lwc_extra_micron", "label": "EXTRA MICRON VALUE?", "type": "text", "controllingField": "lwc_is_extra_micron", "controllingValues": ["true"]},
            {"apiName": "lwc_pu_paint", "label": "PU PAINT", "type": "checkbox"},
            {"apiName": "lwc_pu_paint_note", "label": "Note", "type": "text", "controllingField": "lwc_pu_paint", "controllingValues": ["true"]},
            {"apiName": "lwc_pu_paint_price", "label": "PRICE VALUE", "type": "number", "controllingField": "lwc_pu_paint", "controllingValues": ["true"]},
            // PU Paint realization - was missing on Stadium, so the charge went in at cost.
            // Default 5%, same as Flag Mast/Lighting Mast. Deepanjan (21st Aug 2026)
            {"apiName": "lwc_pu_paint_realization", "label": "REALIZATION", "type": "number", "unit": "%", "defaultValue": 5, "controllingField": "lwc_pu_paint", "controllingValues": ["true"]}
        ]
    },
    {
        "id": "lwc_estimation_label",
        "label": "Segment Weight Details",
        "type": "header",
        "readOnly": true,
        "controllingField": "ladder_with_cage",
        "controllingValues": ["true"],
        "fields": [
            // Duplicate of LADDER WITH CAGE BASE PRICE - see the MRL note above; same reason.
            {"apiName": "lwc_base_amount", "type": "hidden", "formula": "Base_Amount__c"},
            {"apiName": "lwc_weight", "label": "Weight", "type": "number", "required": false, "colSpan": 3},
            {"apiName": "lwc_quantity", "label": "Quantity", "type": "number", "required": false, "colSpan": 3},
            {"apiName": "lwc_amount_realization", "label": "Total Price", "type": "number", "required": false, "colSpan": 3, "formula": "(Base_Amount__c || 0) + 10"},
            {"apiName": "lwc_realization", "type": "hidden", "isRealization": true, "formula": "(lwc_amount_realization || 0) - (Base_Amount__c || 0)"}
        ]
    },
    {
        "id": "ladder_with_cage_section",
        "label": "Segment Dimension",
        "expanded": true,
        "showRequired": true,
        "controllingField": "lwc_no_of_segment",
        "controllingValues": [">=6"],
        "fields": [
            {"apiName": "lwc_lbl_top", "label": "TOP SEGMENT", "type": "header", "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=6"]},
            {"apiName": "lwc_top_segment_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=6"]},
            {"apiName": "lwc_top_segment_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=6"]},
            {"apiName": "lwc_lbl_mid2", "label": "MIDDLE SEGMENT - 2", "type": "header", "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=6"]},
            {"apiName": "lwc_middle_segment_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=6"], "formula": "(lwc_top_segment_length || 0)"},
            {"apiName": "lwc_middle_segment_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=6"], "formula": "(lwc_top_segment_thickness || 0)"},
            {"apiName": "lwc_lbl_mid3", "label": "MIDDLE SEGMENT - 3", "type": "header", "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=4"]},
            {"apiName": "lwc_mid3_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=4"], "formula": "(lwc_top_segment_length || 0)"},
            {"apiName": "lwc_mid3_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=4"], "formula": "(lwc_top_segment_thickness || 0)"},
            {"apiName": "lwc_lbl_mid4", "label": "MIDDLE SEGMENT - 4", "type": "header", "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=5"]},
            {"apiName": "lwc_mid4_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=5"], "formula": "(lwc_top_segment_length || 0)"},
            {"apiName": "lwc_mid4_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=5"], "formula": "(lwc_top_segment_thickness || 0)"},
            {"apiName": "lwc_lbl_mid5", "label": "MIDDLE SEGMENT - 5", "type": "header", "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=6"]},
            {"apiName": "lwc_mid5_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=6"], "formula": "(lwc_top_segment_length || 0)"},
            {"apiName": "lwc_mid5_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=6"], "formula": "(lwc_top_segment_thickness || 0)"},
            {"apiName": "lwc_lbl_mid6", "label": "MIDDLE SEGMENT - 6", "type": "header", "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=7"]},
            {"apiName": "lwc_mid6_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=7"], "formula": "(lwc_top_segment_length || 0)"},
            {"apiName": "lwc_mid6_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=7"], "formula": "(lwc_top_segment_thickness || 0)"},
            {"apiName": "lwc_lbl_mid7", "label": "MIDDLE SEGMENT - 7", "type": "header", "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=8"]},
            {"apiName": "lwc_mid7_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=8"], "formula": "(lwc_top_segment_length || 0)"},
            {"apiName": "lwc_mid7_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=8"], "formula": "(lwc_top_segment_thickness || 0)"},
            {"apiName": "lwc_lbl_mid8", "label": "MIDDLE SEGMENT - 8", "type": "header", "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=9"]},
            {"apiName": "lwc_mid8_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=9"], "formula": "(lwc_top_segment_length || 0)"},
            {"apiName": "lwc_mid8_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=9"], "formula": "(lwc_top_segment_thickness || 0)"},
            {"apiName": "lwc_lbl_mid9", "label": "MIDDLE SEGMENT - 9", "type": "header", "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=10"]},
            {"apiName": "lwc_mid9_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=10"], "formula": "(lwc_top_segment_length || 0)"},
            {"apiName": "lwc_mid9_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=10"], "formula": "(lwc_top_segment_thickness || 0)"},
            {"apiName": "lwc_lbl_mid10", "label": "MIDDLE SEGMENT - 10", "type": "header", "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=11"]},
            {"apiName": "lwc_mid10_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=11"], "formula": "(lwc_top_segment_length || 0)"},
            {"apiName": "lwc_mid10_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=11"], "formula": "(lwc_top_segment_thickness || 0)"},
            {"apiName": "lwc_lbl_mid11", "label": "MIDDLE SEGMENT - 11", "type": "header", "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=12"]},
            {"apiName": "lwc_mid11_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=12"], "formula": "(lwc_top_segment_length || 0)"},
            {"apiName": "lwc_mid11_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=12"], "formula": "(lwc_top_segment_thickness || 0)"},
            {"apiName": "lwc_lbl_mid12", "label": "MIDDLE SEGMENT - 12", "type": "header", "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=13"]},
            {"apiName": "lwc_mid12_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=13"], "formula": "(lwc_top_segment_length || 0)"},
            {"apiName": "lwc_mid12_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=13"], "formula": "(lwc_top_segment_thickness || 0)"},
            {"apiName": "lwc_lbl_mid13", "label": "MIDDLE SEGMENT - 13", "type": "header", "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=14"]},
            {"apiName": "lwc_mid13_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=14"], "formula": "(lwc_top_segment_length || 0)"},
            {"apiName": "lwc_mid13_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=14"], "formula": "(lwc_top_segment_thickness || 0)"},
            {"apiName": "lwc_lbl_mid14", "label": "MIDDLE SEGMENT - 14", "type": "header", "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=15"]},
            {"apiName": "lwc_mid14_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=15"], "formula": "(lwc_top_segment_length || 0)"},
            {"apiName": "lwc_mid14_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=15"], "formula": "(lwc_top_segment_thickness || 0)"},
            {"apiName": "lwc_lbl_bottom", "label": "BOTTOM", "type": "header", "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=6"]},
            {"apiName": "lwc_bottom_length", "label": "Length (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=6"], "formula": "(lwc_top_segment_length || 0)"},
            {"apiName": "lwc_bottom_thickness", "label": "Thickness (MM)", "type": "number", "required": true, "colSpan": 4, "controllingField": "lwc_no_of_segment", "controllingValues": [">=6"], "formula": "(lwc_top_segment_thickness || 0)"},
            {"apiName": "lwc_ladder_cage_weight", "label": "LADDER WITH CAGE WEIGHT (KG)", "type": "number", "readOnly": true, "isWeightTotal": true, "formula": "(lwc_weight || 0)"},
            {"apiName": "lwc_ladder_cage_base_price", "label": "LADDER WITH CAGE BASE PRICE", "type": "number", "readOnly": true, "isBasePrice": true, "formula": "Base_Amount__c"},
            {"apiName": "lwc_ladder_cage_unit_price", "label": "LADDER WITH CAGE UNIT PRICE", "isUnitPrice": true, "type": "number", "readOnly": true, "formula": "(((Base_Amount__c || 0) + (lwc_realization || 0)) * (lwc_ladder_cage_weight || 0)) + (lwc_pu_paint ? (typeof lwc_pu_paint_price !== \"undefined\" ? ((lwc_pu_paint_price || 0) * (1 + ((typeof lwc_pu_paint_realization !== \"undefined\" ? (lwc_pu_paint_realization || 0) : 0)) / 100)) : 0) : 0)"},
            {"apiName": "lwc_ladder_cage_unit_cost", "label": "LADDER WITH CAGE UNIT COST", "isUnitCost": true, "type": "number", "readOnly": true, "formula": "((Base_Amount__c || 0) * (lwc_ladder_cage_weight || 0)) + (lwc_pu_paint ? (typeof lwc_pu_paint_price !== \"undefined\" ? (lwc_pu_paint_price || 0) : 0) : 0)"},
            // Duplicate of "Quantity" in Segment Weight Details. Deepanjan (21st Aug 2026)
            {"apiName": "lwc_ladder_cage_ghost_quantity_for_top_section", "type": "hidden", "isQuantity": true, "formula": "(lwc_quantity || 1)"},
            {"apiName": "lwc_ghost_realization_for_top_section", "type": "hidden", "isRealization": true, "formula": "(lwc_realization || 0)"},
            {"apiName": "lwc_hdr_base_plate", "label": "BASE PLATE", "type": "header", "readOnly": true, "colSpan": 12},
            {"apiName": "lwc_bp_diameter", "label": "DIAMETER", "type": "number", "required": false, "colSpan": 3},
            {"apiName": "lwc_bp_thickness", "label": "THICKNESS", "type": "number", "required": false, "colSpan": 3},
            {"apiName": "lwc_bp_pcd", "label": "PCD", "type": "number", "required": false, "colSpan": 3},
            {"apiName": "lwc_bp_spacer_1", "label": "-", "type": "header", "readOnly": true, "colSpan": 3}
        ]
    },
    {
        "id": "accessories_ladder_with_cage",
        "label": "ACCESSORIES & ESTIMATION",
        "expanded": false,
        "showRequired": true,
        "controllingField": "lwc_no_of_segment",
        "controllingValues": [">=6"],
        "fields": [
            {"apiName": "lwc_hdr_seg_acc", "label": "SEGMENT DETAILS", "type": "header", "readOnly": true, "colSpan": 12},
            {"apiName": "lwc_no_of_lum", "label": "No. of lum", "type": "number", "required": true, "colSpan": 3},
            {"apiName": "lwc_type_of_lum", "label": "Type of Lum.", "type": "picklist", "required": true, "options": ["Asymmetric"], "colSpan": 3},
            {"apiName": "lwc_watt", "label": "Watt", "type": "number", "required": true, "colSpan": 3},
            {"apiName": "lwc_special_note", "label": "Special Note", "type": "text", "required": false, "colSpan": 3},
            {"apiName": "lwc_foundation_bolt_label", "label": "FOUNDATION BOLT", "type": "header", "readOnly": true, "colSpan": 12},
            {"apiName": "lwc_foundation_bolt_type", "label": "FOUNDATION BOLT TYPE", "type": "picklist", "required": false, "options": ["with Foundation Bolt", "without Foundation Bolt"], "colSpan": 3},
            {"apiName": "lwc_fb_amount_realization", "label": "Total Price", "type": "number", "required": false, "colSpan": 3, "formula": "(Base_Amount__c || 0) + 10", "disableControllingField": "lwc_foundation_bolt_type", "disableControllingValues": ["with Foundation Bolt"]},
            {"apiName": "lwc_fb_realization", "type": "hidden", "isRealization": true, "formula": "(lwc_fb_amount_realization || 0) - (Base_Amount__c || 0)"},
            {"apiName": "lwc_fb_spacer_1", "label": "-", "type": "header", "readOnly": true, "colSpan": 3},
            {"apiName": "lwc_fb_diameter", "label": "Diameter", "type": "number", "required": false, "colSpan": 3},   // open field, was a picklist - UIL-HM-084. Deepanjan (19th Aug 2026)
            {"apiName": "lwc_fb_length", "label": "Length", "type": "number", "required": false, "colSpan": 3},
            {"apiName": "lwc_fb_no_of_bolt", "label": "No. of bolt", "type": "number", "required": false, "colSpan": 3},
            {"apiName": "lwc_fb_quantity", "label": "quantity", "type": "number", "required": false, "isQuantity": true, "colSpan": 3, "disableControllingField": "lwc_foundation_bolt_type", "disableControllingValues": ["with Foundation Bolt"], "controllingField": "lwc_foundation_bolt_type", "controllingValues": ["with Foundation Bolt"]},
            {"apiName": "lwc_foundation_weight", "label": "FOUNDATION WEIGHT (KG)", "type": "number", "readOnly": false, "isWeightTotal": true, "required": true, "colSpan": 3, "controllingField": "lwc_foundation_bolt_type", "controllingValues": ["with Foundation Bolt"]},
            {"apiName": "lwc_foundation_base_price", "label": "BASE FOUNDATION PRICE", "type": "number", "readOnly": true, "isBasePrice": true, "formula": "Base_Amount__c"},
            {"apiName": "lwc_foundation_unit_price", "label": "UNIT FOUNDATION PRICE", "isUnitPrice": true, "type": "number", "readOnly": true, "formula": "(((Base_Amount__c || 0) + (lwc_fb_realization || 0)) * (lwc_foundation_weight || 0))"},
            {"apiName": "lwc_foundation_unit_cost", "label": "UNIT FOUNDATION COST", "isUnitCost": true, "type": "number", "readOnly": true, "formula": "((Base_Amount__c || 0) * (lwc_foundation_weight || 0))"}
        ]
    },
    {
        "id": "ladder_with_cage",
        "label": "Ladder With Cage",
        "expanded": false,
        "showRequired": true,
        "controllingField": "lwc_no_of_segment",
        "controllingValues": [">=6"],
        "fields": [
            {"apiName": "lwc_acc_description", "label": "Description", "type": "text", "required": false, "colSpan": 3},
            {"apiName": "lwc_acc_weight", "label": "Weight", "type": "number", "required": false, "colSpan": 3},
            /* ── PRICED ── Deepanjan (6th September 2026). The seg5 copy of this section stopped
               at description + weight; the NORMAL Stadium recipe (Section Logic "Customized
               Mast", same section id) also carries the four fields below, and both offer
               controllers already read lwc_unit_price from them. Without them the
               "Supply of standard Man-Riding Ladder with Safety Cage system" line came out at
               0.00 (Q 00001317, bug 5). These are the normal recipe's fields verbatim - same
               apiNames, same weight x (base + foundation realization) formulas - so seg5 now
               prices the ladder exactly as normal Stadium does and Apex needs no change. */
            {"apiName": "lwc_base_price", "label": "BASE PRICE", "type": "number", "readOnly": true, "isBasePrice": true, "formula": "Base_Amount__c"},
            {"apiName": "lwc_acc_realization", "label": "REALIZATION", "type": "number", "readOnly": true, "formula": "lwc_fb_realization"},
            {"apiName": "lwc_unit_price", "label": "UNIT PRICE", "isUnitPrice": true, "type": "number", "readOnly": true, "formula": "(((Base_Amount__c + (lwc_fb_realization || 0)) * (lwc_acc_weight || 0)))"},
            {"apiName": "lwc_unit_cost", "label": "UNIT COST", "isUnitCost": true, "type": "number", "readOnly": true, "formula": "((Base_Amount__c || 0) * (lwc_acc_weight || 0))"}
        ]
    },
    {
        "id": "mrl_special_items",
        "label": "Special Items - Man Riding Lift",
        "expanded": false,
        "controllingField": "man_riding_lift",
        "controllingValues": ["true"],
        "fields": [
            {"apiName": "mrl_si_type", "label": "TYPE", "type": "picklist", "options": ["Price", "Weight"], "colSpan": 3},
            {"apiName": "mrl_si_description", "label": "ITEM DESCRIPTION", "type": "text", "colSpan": 4, "controllingField": "mrl_si_type", "controllingValues": ["Price", "Weight"]},
            // VALUE is mandatory once a TYPE is picked. The field is already hidden until
            // mrl_si_type has a value, and validateRequiredFields only checks visible
            // fields, so this is "required if TYPE filled" with no engine change. Stops
            // the Q 00001317 entry (rate typed into ITEM DESCRIPTION, VALUE blank -> item
            // printed at 0). Deepanjan (6th September 2026)
            {"apiName": "mrl_si_value", "label": "VALUE", "type": "number", "colSpan": 3, "controllingField": "mrl_si_type", "controllingValues": ["Price", "Weight"], "required": true},
            {"apiName": "mrl_si_show_separate", "label": "Show separate in offer", "type": "checkbox", "colSpan": 3},
            {"apiName": "mrl_si_price_add", "type": "hidden", "formula": "(mrl_si_show_separate ? 0 : (mrl_si_type == 'Price' ? (mrl_si_value || 0) : 0))"},
            {"apiName": "mrl_si_weight_add", "type": "hidden", "formula": "(mrl_si_show_separate ? 0 : (mrl_si_type == 'Weight' ? (mrl_si_value || 0) : 0))"},
            {"apiName": "mrl_si_unit_price", "label": "UNIT PRICE (if separate)", "type": "number", "readOnly": true, "colSpan": 4, "isUnitPrice": true, "formula": "((typeof mrl_si_show_separate !== \"undefined\" ? mrl_si_show_separate : false) ? ((typeof mrl_si_type !== \"undefined\" ? mrl_si_type : \"\") == \"Price\" ? (typeof mrl_si_value !== \"undefined\" ? (mrl_si_value || 0) : 0) : ((typeof mrl_si_type !== \"undefined\" ? mrl_si_type : \"\") == \"Weight\" ? (((typeof mrl_base_amount !== \"undefined\" ? (mrl_base_amount || 0) : 0) + (typeof mrl_realization !== \"undefined\" ? (mrl_realization || 0) : 0)) * (typeof mrl_si_value !== \"undefined\" ? (mrl_si_value || 0) : 0)) : 0)) : 0)"},
            {"apiName": "mrl_si_unit_cost", "label": "UNIT COST (if separate)", "type": "number", "readOnly": true, "colSpan": 4, "isUnitCost": true, "formula": "((typeof mrl_si_show_separate !== \"undefined\" ? mrl_si_show_separate : false) ? ((typeof mrl_si_type !== \"undefined\" ? mrl_si_type : \"\") == \"Price\" ? (typeof mrl_si_value !== \"undefined\" ? (mrl_si_value || 0) : 0) : ((typeof mrl_si_type !== \"undefined\" ? mrl_si_type : \"\") == \"Weight\" ? ((typeof mrl_base_amount !== \"undefined\" ? (mrl_base_amount || 0) : 0) * (typeof mrl_si_value !== \"undefined\" ? (mrl_si_value || 0) : 0)) : 0)) : 0)"},
            {"apiName": "mrl_si_line_qty", "label": "QTY", "type": "number", "readOnly": true, "colSpan": 4, "isQuantity": true, "formula": "((typeof mrl_si_show_separate !== \"undefined\" ? mrl_si_show_separate : false) ? ((typeof mrl_quantity !== \"undefined\" ? (mrl_quantity || 1) : 1)) : 0)"}
        ]
    },
    {
        "id": "lwc_special_items",
        "label": "Special Items - Ladder With Cage",
        "expanded": false,
        "controllingField": "ladder_with_cage",
        "controllingValues": ["true"],
        "fields": [
            {"apiName": "lwc_si_type", "label": "TYPE", "type": "picklist", "options": ["Price", "Weight"], "colSpan": 3},
            {"apiName": "lwc_si_description", "label": "ITEM DESCRIPTION", "type": "text", "colSpan": 4, "controllingField": "lwc_si_type", "controllingValues": ["Price", "Weight"]},
            // VALUE is mandatory once a TYPE is picked. The field is already hidden until
            // lwc_si_type has a value, and validateRequiredFields only checks visible
            // fields, so this is "required if TYPE filled" with no engine change. Stops
            // printed at 0). Deepanjan (6th September 2026)
            {"apiName": "lwc_si_value", "label": "VALUE", "type": "number", "colSpan": 3, "controllingField": "lwc_si_type", "controllingValues": ["Price", "Weight"], "required": true},
            {"apiName": "lwc_si_show_separate", "label": "Show separate in offer", "type": "checkbox", "colSpan": 3},
            {"apiName": "lwc_si_price_add", "type": "hidden", "formula": "(lwc_si_show_separate ? 0 : (lwc_si_type == 'Price' ? (lwc_si_value || 0) : 0))"},
            {"apiName": "lwc_si_weight_add", "type": "hidden", "formula": "(lwc_si_show_separate ? 0 : (lwc_si_type == 'Weight' ? (lwc_si_value || 0) : 0))"},
            {"apiName": "lwc_si_unit_price", "label": "UNIT PRICE (if separate)", "type": "number", "readOnly": true, "colSpan": 4, "isUnitPrice": true, "formula": "((typeof lwc_si_show_separate !== \"undefined\" ? lwc_si_show_separate : false) ? ((typeof lwc_si_type !== \"undefined\" ? lwc_si_type : \"\") == \"Price\" ? (typeof lwc_si_value !== \"undefined\" ? (lwc_si_value || 0) : 0) : ((typeof lwc_si_type !== \"undefined\" ? lwc_si_type : \"\") == \"Weight\" ? (((typeof lwc_base_amount !== \"undefined\" ? (lwc_base_amount || 0) : 0) + (typeof lwc_realization !== \"undefined\" ? (lwc_realization || 0) : 0)) * (typeof lwc_si_value !== \"undefined\" ? (lwc_si_value || 0) : 0)) : 0)) : 0)"},
            {"apiName": "lwc_si_unit_cost", "label": "UNIT COST (if separate)", "type": "number", "readOnly": true, "colSpan": 4, "isUnitCost": true, "formula": "((typeof lwc_si_show_separate !== \"undefined\" ? lwc_si_show_separate : false) ? ((typeof lwc_si_type !== \"undefined\" ? lwc_si_type : \"\") == \"Price\" ? (typeof lwc_si_value !== \"undefined\" ? (lwc_si_value || 0) : 0) : ((typeof lwc_si_type !== \"undefined\" ? lwc_si_type : \"\") == \"Weight\" ? ((typeof lwc_base_amount !== \"undefined\" ? (lwc_base_amount || 0) : 0) * (typeof lwc_si_value !== \"undefined\" ? (lwc_si_value || 0) : 0)) : 0)) : 0)"},
            {"apiName": "lwc_si_line_qty", "label": "QTY", "type": "number", "readOnly": true, "colSpan": 4, "isQuantity": true, "formula": "((typeof lwc_si_show_separate !== \"undefined\" ? lwc_si_show_separate : false) ? ((typeof lwc_quantity !== \"undefined\" ? (lwc_quantity || 1) : 1)) : 0)"}
        ]
    }
];
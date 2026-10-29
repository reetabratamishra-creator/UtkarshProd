import { LightningElement, api, track } from 'lwc';
import fetchBlueprintPayload from '@salesforce/apex/CreateQuoteController.fetchBlueprintPayload';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'; // 👉 Required for the warning popup
import getPriceVariationData from '@salesforce/apex/CreateQuoteController.getPriceVariationData';
import getRateCardJson from '@salesforce/apex/CreateQuoteController.getRateCardJson';
import getTransmissionPricing from '@salesforce/apex/CreateQuoteController.getTransmissionPricing';
import {
    validateSegmentCount,
    buildDynamicMast,
    buildNotReadyPlaceholder
} from './segmentGenerator';
import CORE_SUBTYPE_DATA from './coreSubtypeWeightData';

/* ═══════════════════════════════════════════════════════════════════════════
   PERF: formula-engine caches. Pure memoisation - no rule, order or result of
   the math engine changes. Compiled once, reused for the life of the tab.
   Previously _evaluateAllFormulas compiled 3 RegExps per valMap key, per
   formula field, per pass (3 passes) => tens of millions of compiles a keystroke.
   - Reetabrata (9th July 2026)
   ═══════════════════════════════════════════════════════════════════════════ */
const _TOKEN_RE = /[A-Za-z_$][A-Za-z0-9_$]*/g;          // maximal-munch identifier scan
const _IDENT_RE = /^[A-Za-z_$][A-Za-z0-9_$]*$/;         // key is a plain identifier?
const _RE_CACHE = new Map();                            // key -> { word, dot, probe }
const _FN_CACHE = new Map();                            // expr -> compiled Function
 
function _reFor(key) {
    let e = _RE_CACHE.get(key);
    if (!e) {
        const esc = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        e = {
            word:  new RegExp('\\b' + esc + '\\b', 'g'),   // used only in .replace() -> lastIndex resets
            dot:   new RegExp('\\b' + esc + '\\b\\.'),     // non-global .test() -> no lastIndex drift
            probe: new RegExp('\\b' + esc + '\\b')
        };
        _RE_CACHE.set(key, e);
    }
    return e;
}
 
// PERF - Deepanjan (4th September 2026)
// _expandFields compiled `new RegExp('\\b' + apiName + '\\b', 'g')` once per column per
// sub-field per apiName - ~68,000 compiles for one Custom Lighting Pole open. The pattern
// depends only on apiName, so it is compiled once here and reused. Built from the SAME
// unescaped string as the original, so it matches exactly what it matched before.
// (Deliberately NOT _reFor: that one escapes metacharacters, which the original did not.)
const _PREFIX_RE_CACHE = new Map();
function _prefixReFor(apiName) {
    let re = _PREFIX_RE_CACHE.get(apiName);
    if (!re) {
        re = new RegExp(`\\b${apiName}\\b`, 'g');
        _PREFIX_RE_CACHE.set(apiName, re);
    }
    return re;
}

function _fnFor(expr) {
    let fn = _FN_CACHE.get(expr);
    if (!fn) {
        if (_FN_CACHE.size > 5000) _FN_CACHE.clear();   // bound memory
        fn = Function('Math', '"use strict"; return (' + expr + ')');
        _FN_CACHE.set(expr, fn);
    }
    return fn;
}

/*
const MULTI_PRICE_MODAL_TITLES = [
    'STANDARD POLE ESTIMATOR',
    'CUSTOMIZED POLE ESTIMATOR'
];
*/
// api names mapped based on modal - for bom validation check
const TELECOM_COMPOSITION_GROUPS = {
        'Tubular':            ['tub_pipe_com', 'tub_plate_com', 'tub_ang_chan_com', 'tub_misc_com'],
        'Tubular Signalling': ['tsg_pipe_com', 'tsg_plate_com', 'tsg_ang_chan_com', 'tsg_misc_com']
    };
const TELECOM_COMPOSITION_APIS = [].concat(...Object.values(TELECOM_COMPOSITION_GROUPS));

export default class WeightEstimatorModal extends LightningElement {

    
    
@api isReadOnly = false;
    @track isModalOpen = false;
    @track modalTitle = '';
    @track accordionSections = [];
    @track isLoading = false;
 
    _modalConfig = null;
    _lastValues = {};
    _typingTimer;
    _segCountTimer; // debounce for the Segment-Above-5 count validation - Reetabrata (8th July)
    _structuralApis = null; // api names that OTHER fields depend on (counts / controllers) - Reetabrata (8th July)
    @track columnTotalsArray = [];
    @track baseRates = {};
    _pvRowData = {};
    _pvSharedKey = '';
 
    @track rateCardData = [];

    _headlessMode = false;
    _headlessResult = null;
 
    // =========================================================
    // PUBLIC API
    // =========================================================
    @api
    async openModal(config) {
        try {
            if (!config) return;
 
            this.isLoading = true;
// ─────────────────Reetabrata (7th July)────────────────────────────────────────
            // let the spinner paint before the heavy synchronous build - Reetabrata (8th July)
            await new Promise(requestAnimationFrame);
            await new Promise(resolve => setTimeout(resolve, 0));
// ─────────────────Reetabrata (7th July)────────────────────────────────────────
 
            // Instantly flattens accidental arrays into safe strings -Abhishek saxena
            this._modalConfig = JSON.parse(JSON.stringify(config, (key, value) => {
                if ((key === 'controllingField' || key === 'disableControllingField') && Array.isArray(value)) {
                    return value.join(',');
                }
                return value;
            }));
            //end
            this.modalTitle = this._modalConfig.title || 'ESTIMATOR';
            this.baseRates = config.baseRates || {};
            this._modalConfig.blueprints = {};
            // 👉 ADD THIS LINE: Catch the massive JSON dict from the parent!
            //Abhishek saxena
           this.baseRates = this._modalConfig.baseRates || {};
            this.weightManifest = this._modalConfig.weightManifest || {};
            //End
            //this._lastValues = this._modalConfig.savedData || {};
            this._lastValues = {
                ...this._lastValues,
                ...(this._modalConfig.savedData || {})
            };
 
            // add the same apis in _lastValues
            console.log('***line 51', this._modalConfig.preRegisterApis);
            if (this._modalConfig.preRegisterApis) {
                Object.keys(this._modalConfig.preRegisterApis).forEach(apiName => {
                    if (!(apiName in this._lastValues)) {
                        this._lastValues[apiName] = this._modalConfig.preRegisterApis[apiName];
                    }
                });
            }
 
            if (this._modalConfig.blueprintId) {
                let payloadString = await fetchBlueprintPayload({ blueprintId: this._modalConfig.blueprintId });
 
                if (payloadString) {
                    try {
                        // 👉 FIX: Handle both string AND Proxy/object returns
                        let parsed;
 
                        if (typeof payloadString === 'string') {
                            // It's a string — clean and parse it
                            payloadString = payloadString.replace(/[\u200B-\u200D\uFEFF]/g, '');
                            parsed = JSON.parse(payloadString);
                        } else if (typeof payloadString === 'object') {
                            // It's already an object (or Proxy) — convert to string first, then reparse to clean it
                            parsed = JSON.parse(JSON.stringify(payloadString));
                        } else {
                            parsed = payloadString;
                        }
 
                        this._modalConfig.blueprints = parsed;
                    } catch (parseError) {
                        console.error('❌ FATAL ERROR: JSON syntax error!', parseError);
                    }
                }
            }
 
            // ── SEGMENT ABOVE 5 (gated) Reetabrata (7th July)─────────────────────────────
if (this._modalConfig.dynamicSegments === true) {
    if (this._modalConfig.notReady === true) {
        this._modalConfig.modalFields =
            buildNotReadyPlaceholder(this._modalConfig.mastType);
    } else {
        const built = buildDynamicMast(this._modalConfig.mastType);
        this._modalConfig.modalFields = built.modalFields;
        this._modalConfig.blueprints = Object.assign(
            {}, this._modalConfig.blueprints || {}, built.blueprints
        );
    }
}
// ─────────────────Reetabrata (7th July)────────────────────────────────────────
 
            this.accordionSections = this._buildSections(this._modalConfig.modalFields || []);
            this._buildStructuralApiSet(); // precompute which fields drive visibility - Reetabrata (8th July)
            this.isModalOpen = true;
 
            
 
            this.accordionSections.forEach(sec => {
                this._evaluateFieldVisibility(sec.fields);
                this._evaluateDynamicDisable(sec.fields); // 👉 SAFELY INJECTED HERE
 
 
                // WAKE UP DEPENDENT PICKLISTS ON PAGE LOAD: Abhishek saxena
                sec.fields.filter(f => f.dependentOptionsMap).forEach(dep => {
 
 
                    let ctrlNames = [];
                    if (Array.isArray(dep.controllingFields)) ctrlNames = dep.controllingFields;
                    else if (Array.isArray(dep.controllingField)) ctrlNames = dep.controllingField;
                    else if (typeof dep.controllingFields === 'string') ctrlNames = dep.controllingFields.split(',').map(s => s.trim());
                    else if (typeof dep.controllingField === 'string') ctrlNames = dep.controllingField.split(',').map(s => s.trim());
 
                    if (ctrlNames.length === 0) return;
 
 
                    let currentValues = ctrlNames.map(ctrlName => {
                        let ctrlField = sec.fields.find(x => x.apiName.endsWith(ctrlName) && x.columnCountIndex === dep.columnCountIndex);
                        return ctrlField && ctrlField.value ? String(ctrlField.value).trim() : '';
                    });
 
 
                    let possibleKeys = [];
                    let tempVals = [];
                    for (let val of currentValues) {
                        if (val !== '') {
                            tempVals.push(val);
                            possibleKeys.unshift(tempVals.join('|'));
                        } else {
                            break;
                        }
                    }
 
                    let matchedKey = possibleKeys.find(key => dep.dependentOptionsMap[key]);
                    let fullyFilled = currentValues.every(v => v !== '');
 
 
                    if (!dep.masterOptions) dep.masterOptions = dep.options ? [...dep.options] : [];
 
 
                    if (matchedKey) {
 
                        let mapVal = dep.dependentOptionsMap[matchedKey];
                        if (mapVal.length > 0 && typeof mapVal[0] === 'string') {
                            dep.options = mapVal.map(opt => ({ label: opt, value: opt }));
                        } else {
                            dep.options = mapVal;
                        }
                    } else if (fullyFilled) {
 
                        dep.options = dep.masterOptions;
                    } else {
 
                        dep.options = [];
                    }
                });
                // End 
 
            });
            // 👉 THE NEW FIX: Evaluate Lookups BEFORE UI render so dynamic pricing loads instantly!
            this._evaluateLookups();
            this._evaluateAllFormulas();
            this._evaluateSectionVisibility();
            this._evaluateAllFormulas();
            // ═══════════════════════════════════════════════════════════════════════
            // ★ CHANGE 1 of 5 — BUG 1 (KIT picklist options empty on first open) ★
            // Reetabrata (14th July 2026)
            // Re-resolve dependent picklist options now that formula-driven controlling
            // fields (no_of_segment_select, etc.) have values. The original onload
            // "WAKE UP DEPENDENT PICKLISTS" block (~line 172) is left untouched.
            // ═══════════════════════════════════════════════════════════════════════
            this._resolveDependentOptionsOnLoad(); // Reetabrata (14th July 2026)
            
            this._evaluateDynamicColSpans();
            this._evaluateSectionLabels();
 
            this.accordionSections = this.accordionSections.map(sec => {
                sec.fields.forEach(f => this._updateFieldUI(f));
                this._updateSectionUI(sec);
                return { ...sec };
            });
 
            // Fetch PV data if saved values already have month/year/materialType
            await this._checkAndFetchPriceVariation();
 
 
            this.isLoading = false;
 
        } catch (e) {
            console.error('openModal error:', e);
            this.isLoading = false;
        }
    }
 
    @api
    closeModal() {
        try {
            this._saveCurrentValues();
            this.isModalOpen = false;
        } catch (e) {
            console.error('closeModal error:', e);
        }
    }
 
    // fetch prices for Transmission Tower
    async _fetchSharedPvRates({ monthApi, yearApi, bloomsApi, billetsApi, zincApi, cpiApi, getFieldVal, setFieldVal }) {
        try {
            const month = getFieldVal(monthApi);
            const year = getFieldVal(yearApi);
 
            if (!month || !year) return;
 
            //const sharedKey = `${monthApi}_${month}_${year}`;
            //if (this._pvSharedKey === sharedKey) {
                //console.log(`[PV] Cache hit for ${sharedKey} — skipping fetch`);
               // return;
            //}
            console.log(`[PV] Fetching shared rates for ${monthApi} → ${month} ${year}`);
            this.isLoading = true;
 
            const sharedData = await getTransmissionPricing({
                month,
                year
            });
 
            console.log('*****line 214 ', monthApi, yearApi, cpiApi, month, year, sharedData);
 
            if (sharedData) {
                //update bloom price
                if (bloomsApi) {
                    setFieldVal(bloomsApi, Number(sharedData.bloomsPrice) || 0);
                    console.log(`[PV] ${bloomsApi} ← ${sharedData.bloomsPrice}`);
                }
 
                // update Billets value
                if (billetsApi) {
                    setFieldVal(billetsApi, Number(sharedData.billetsPrice) || 0);
                    console.log(`[PV] ${billetsApi} ← ${sharedData.billetsPrice}`);
                }
                // update zinc value
                if (zincApi) {
                    setFieldVal(zincApi, Number(sharedData.zincPrice) || 0);
                    console.log(`[PV] ${zincApi} ← ${sharedData.zincPrice}`);
                }
                // update zinc value
                if (cpiApi) {
                    setFieldVal(cpiApi, Number(sharedData.cpiValue) || 0);
                    console.log(`[PV] ${cpiApi} ← ${sharedData.cpiValue}`);
                }
 
                //this._pvSharedKey = sharedKey;
            }
 
            // ── Re-run the formula engine so dependent fields recalculate ─────────
            this.accordionSections.forEach(sec => this._evaluateFieldVisibility(sec.fields));
            this._evaluateLookups(); // 👉 NEW FIX: Re-evaluate dynamic lookups!
            this._evaluateSectionVisibility();
            this._evaluateAllFormulas();
            this.accordionSections = this.accordionSections.map(sec => {
                sec.fields.forEach(f => this._updateFieldUI(f));
                this._updateSectionUI(sec);
                return { ...sec };
            });
        }
        catch (ex) {
            console.error('[PV Shared] Error fetching transmission pricing:', JSON.stringify(ex));
        }
        finally {
            this.isLoading = false;
        }
    }
 
 
    async _checkAndFetchPriceVariation() {
        try {
 
            // ── Helpers ───────────────────────────────────────────────────────
            const getFieldVal = (apiName) => {
                if (!apiName) return '';
                for (const sec of this.accordionSections) {
                    const f = sec.fields.find(x => x.apiName === apiName);
                    if (f && f.value !== '' && f.value !== null && f.value !== undefined)
                        return String(f.value);
                }
                return String(this._lastValues[apiName] || '');
            };
 
            const setFieldVal = (apiName, value) => {
                if (!apiName) return;
                this.accordionSections.forEach(sec => {
                    const f = sec.fields.find(x => x.apiName === apiName);
                    if (f) { f.value = value; f.userCleared = false; }
                });
            };
 
            // ── Detect mode ───────────────────────────────────────────────────
            const basisValue = String(this._lastValues['Price_Basis'] || '');
 
            // With column-repeater, runtime fields are c1_material_list_type, c2_... etc.
            // Check for any c{N}_material_list_type field OR legacy _1 suffix
            const hasMaterialField = this.accordionSections.some(sec =>
                sec.fields.some(f =>
                    f.apiName === 'material_list_type_1' ||
                    /^c\d+_material_list_type$/.test(f.apiName)
                )
            );
            const hasPVMonthField = this.accordionSections.some(sec =>
                sec.fields.some(f => f.apiName === 'price_variable_month')
            );
 
            const isCoreMode = basisValue === 'Price Variation' && hasPVMonthField;
            const isFirmMode = hasMaterialField && !hasPVMonthField;
 
            // check Transmission Tower Modal - rajeev 15-06-2026
            const hasPvtMonth = this.accordionSections.some(sec =>
                sec.fields.some(f => f.apiName === 'pvt_price_variable_month')
            );
            const isTowerPvMode = hasPvtMonth && getFieldVal('pvt_price_basics') === 'Price Variation';
 
            // check Tranmission Substation Modal 
            const hasPvsMonth = this.accordionSections.some(sec =>
                sec.fields.some(f => f.apiName === 'pvs_price_variable_month')
            );
            const isSubstationPvMode = hasPvsMonth && getFieldVal('pvs_price_model') === 'Price Variation';
 
            const hasPvBaseMonth = this.accordionSections.some(sec =>
                sec.fields.some(f => f.apiName === 'pv_base_month')
            );
 
            if (isTowerPvMode) {
                await this._fetchSharedPvRates({
                    monthApi: 'pvt_price_variable_month',
                    yearApi: 'pvt_price_variable_year',
                    bloomsApi: 'pvt_pv_blooms',
                    billetsApi: 'pvt_pv_billets',
                    zincApi: 'pvt_pv_zinc_value_as_IEEMA',
                    cpiApi: 'pvt_pv_CPI',
                    getFieldVal,
                    setFieldVal
                });
            }
 
            if (isSubstationPvMode) {
                await this._fetchSharedPvRates({
                    monthApi: 'pvs_price_variable_month',
                    yearApi: 'pvs_price_variable_year',
                    bloomsApi: 'pvs_pv_blooms',
                    billetsApi: 'pvs_pv_billets',
                    zincApi: 'pvs_pv_zinc_value_as_per_ieema',
                    cpiApi: 'pvs_pv_CPI',
                    getFieldVal,
                    setFieldVal
                });
            }
 
            if (hasPvBaseMonth) {
                await this._fetchSharedPvRates({
                    monthApi: 'pv_base_month',
                    yearApi: 'pv_base_year',
                    bloomsApi: 'pv_blooms',
                    billetsApi: 'pv_billets',
                    zincApi: 'pv_zinc',
                    cpiApi: 'pv_consumer_price_index',
                    getFieldVal,
                    setFieldVal
                })
            }
 
            if (isTowerPvMode || isSubstationPvMode || hasPvBaseMonth) return;
 
            if (!isCoreMode && !isFirmMode) return;
 
            const priceBasisType = isCoreMode ? 'Price Variation' : 'FIRM';
 
            // ── Validate required inputs ──────────────────────────────────────
            const month = isCoreMode ? getFieldVal('price_variable_month') : '';
            const year = isCoreMode ? getFieldVal('price_variable_year') : '';
            if (isCoreMode && (!month || !year)) return;
 
            this.isLoading = true;
 
            // ── 1. Shared rates — Core only (billets / zinc / CPI) ────────────
            if (isCoreMode) {
                const sharedKey = `${month}_${year}`;
                if (this._pvSharedKey !== sharedKey) {
                    const sharedData = await getPriceVariationData({
                        month, year, materialType: '', priceBasisType
                    });
                    if (sharedData) {
                        setFieldVal('billets_rate', Number(sharedData.billetsPrice) || 0);
                        setFieldVal('zinc_rate', Number(sharedData.zincPrice) || 0);
                        setFieldVal('cpi_rate', Number(sharedData.cpiValue) || 0);
                        this._pvSharedKey = sharedKey;
                        console.log('[PV] Shared rates — billets:', sharedData.billetsPrice,
                            'zinc:', sharedData.zincPrice, 'cpi:', sharedData.cpiValue);
                    }
                }
            }
 
            // ── 2. Build dynamic material rows ────────────────────────────────
            // Supports both:
            //   column-repeater prefix:  c{N}_material_list_type / c{N}_unit_rate / c{N}_added_up
            //   legacy static suffix:    material_list_type_{N}  / unit_rate_{N}  / added_up_{N}
 
            const buildMaterialRows = () => {
                const rows = [];
 
                // ── column-repeater style (new JSON) ──────────────────────────
                // Collect all c{N}_material_list_type fields across all sections
                const colRepeaterFields = [];
                for (const sec of this.accordionSections) {
                    for (const f of sec.fields) {
                        const match = f.apiName.match(/^c(\d+)_material_list_type$/);
                        if (match) {
                            colRepeaterFields.push(Number(match[1]));
                        }
                    }
                }
 
                if (colRepeaterFields.length > 0) {
                    // Sort by column index and build rows
                    const uniqueIndexes = [...new Set(colRepeaterFields)].sort((a, b) => a - b);
                    for (const n of uniqueIndexes) {
                        rows.push({
                            materialApi: `c${n}_material_list_type`,
                            unitRateApi: `c${n}_unit_rate`,
                            addedUpApi: `c${n}_added_up`
                        });
                    }
                    return rows;
                }
 
                // ── Legacy static style (old JSON: _1, _2, _3 ...) ───────────
                // Read number_of_materials field; fall back to scanning existing fields
                const countVal = parseInt(getFieldVal('number_of_materials'), 10);
                const maxCount = !isNaN(countVal) && countVal > 0
                    ? Math.min(countVal, 10)
                    : 10; // scan all possible if field not present
 
                for (let n = 1; n <= maxCount; n++) {
                    const apiName = `material_list_type_${n}`;
                    const exists = this.accordionSections.some(sec =>
                        sec.fields.some(f => f.apiName === apiName)
                    );
                    if (!exists) break; // stop at first missing slot
                    rows.push({
                        materialApi: apiName,
                        unitRateApi: `unit_rate_${n}`,
                        addedUpApi: `added_up_${n}`
                    });
                }
 
                return rows;
            };
 
            const materialRows = buildMaterialRows();
            console.log(`[PV] Processing ${materialRows.length} material row(s)`);
 
            // ── 3. Per-row unit price — Core AND FIRM ─────────────────────────
            const discount = Number(getFieldVal('discount')) || 0;
            let zincCoatingWasAutoSet = false;
 
            for (const row of materialRows) {
                const materialType = getFieldVal(row.materialApi);
 
                if (!materialType) {
                    setFieldVal(row.unitRateApi, '');
                    continue;
                }
 
                // Only re-fetch when material / month / year / basis changes
                const cacheKey = `${priceBasisType}_${materialType}_${month}_${year}`;
                if (
                    !this._pvRowData[row.materialApi] ||
                    this._pvRowData[row.materialApi].cacheKey !== cacheKey
                ) {
                    const rowData = await getPriceVariationData({
                        month, year, materialType, priceBasisType
                    });
                    if (rowData) {
                        this._pvRowData[row.materialApi] = {
                            cacheKey,
                            baseUnitPrice: Number(rowData.unitPrice) || 0,
                            addOnAmount: Number(rowData.addOnAmount) || 0,
                            addOnPercentage: Number(rowData.addOnPercentage) || 0,
                            calOnPercentage: rowData.calOnPercentage,
                            metaZincCoating: String(rowData.zincCoatingType || '').trim()
                        };
                        console.log(`[${priceBasisType}] Fetched: ${materialType} → base:`,
                            rowData.unitPrice, '| zinc:', rowData.zincCoatingType);
                    }
                }
 
                const pvData = this._pvRowData[row.materialApi];
                if (!pvData) { setFieldVal(row.unitRateApi, ''); continue; }
 
                // Auto-set zinc_coating from metadata ONLY when field is currently empty
                const existingZinc = getFieldVal('zinc_coating');
                if (!existingZinc && !zincCoatingWasAutoSet && pvData.metaZincCoating) {
                    setFieldVal('zinc_coating', pvData.metaZincCoating);
                    zincCoatingWasAutoSet = true;
                }
 
                // Only show unit price when zinc coating has a value
                const currentZinc = getFieldVal('zinc_coating');
                if (!currentZinc) {
                    setFieldVal(row.unitRateApi, '');
                    continue;
                }
 
                // ── Zinc coating logic ────────────────────────────────────────
                let finalUnitPrice;
                const base = pvData.baseUnitPrice;
 
                if (currentZinc === '1000') {
                    finalUnitPrice = pvData.calOnPercentage
                        ? base + base * (pvData.addOnPercentage / 100)
                        : base + pvData.addOnAmount;
                } else if (currentZinc === '610') {
                    finalUnitPrice = base;
                } else {
                    finalUnitPrice = base;
                }
 
                // ── User-entered adjustments ──────────────────────────────────
                //const addedUp = Number(getFieldVal(row.addedUpApi)) || 0;
                //finalUnitPrice += addedUp;
 
                //if (discount > 0 && basisValue === 'Price Variation') {
                    //finalUnitPrice = finalUnitPrice - discount;
                //}
 
                const billetsPrice = Number(getFieldVal('billets_rate')) || 0;
                if (billetsPrice > 0 && materialType != 'SPECIAL 1') {
                    finalUnitPrice = finalUnitPrice + billetsPrice;
                }
 
                setFieldVal(row.unitRateApi, Math.round(finalUnitPrice * 1000) / 1000);
                // The addedUp / discount adjustments above are intentionally disabled -
                // they are already applied by the blueprint formula
                // (cost_price = unit_rate - discount + added_up), so applying them here too
                // double-counted them. This log must therefore NOT reference the now-removed
                // `addedUp` variable: doing so threw a ReferenceError that aborted this loop
                // after the first row, leaving every later row unpriced and skipping the
                // Step-4 UI/formula refresh below entirely. Reetabrata (24th July 2026)
                console.log(`[${priceBasisType}] ${materialType} | zinc: ${currentZinc}`,
                    `| discount: ${discount} | billets: ${billetsPrice}`,
                    `→ ${finalUnitPrice}`);
            }
 
            // ── 4. Refresh UI ─────────────────────────────────────────────────
            this.accordionSections.forEach(sec => this._evaluateFieldVisibility(sec.fields));
            this._evaluateSectionVisibility();
            this._evaluateAllFormulas();
            this.accordionSections = this.accordionSections.map(sec => {
                sec.fields.forEach(f => this._updateFieldUI(f));
                this._updateSectionUI(sec);
                return { ...sec };
            });
 
 
        } catch (e) {
            console.error('[PV] Error:', e);
        } finally {
            this.isLoading = false;
        }
    }
 
 
 
 
 
    // =========================================================
    // 🌟 EXPANSION LOGIC
    // =========================================================
    _expandSections(modalFields) {
        let expandedSections = [];
        modalFields.forEach(section => {
            if (section.type === 'matrix-accordion-repeater') {
                const maxRows = section.maxRows || 10;
                const gridField = section.gridFieldApi;
 
                for (let r = 1; r <= maxRows; r++) {
                    section.templates.forEach(template => {
                        expandedSections.push({
                            id: `${template.cloneFrom}_r${r}`,
                            label: template.label.replace('{row}', r),
                            expanded: section.expanded !== false,
                            controllingField: `r${r}_${gridField}`,
                            controllingValues: [template.value],
                            cloneFrom: template.cloneFrom,
                            replaceTarget: section.replaceTarget,
                            replaceWith: `r${r}_${section.replaceTarget}`
                        });
                    });
                }
            } else if (section.type === 'accordion-repeater') {
                const maxRows = section.maxRows || 10;
                const gridField = section.gridFieldApi;
                const allowedValues = section.controllingValues || ["*"];
 
                for (let r = 1; r <= maxRows; r++) {
                    expandedSections.push({
                        id: `${section.cloneFrom}_r${r}`,
                        label: section.label.replace('{row}', r),
                        expanded: section.expanded !== false,
                        controllingField: `r${r}_${gridField}`,
                        controllingValues: allowedValues,
                        cloneFrom: section.cloneFrom,
                        replaceTarget: section.replaceTarget,
                        replaceWith: `r${r}_${section.replaceTarget}`
                    });
                }
            } else {
                expandedSections.push(section);
            }
        });
        return expandedSections;
    }
 
    // PHASE 3: Expand grid/columns inside sections
    _expandFields(fields, globalApiNames = []) {
        let expanded = [];
        fields.forEach(field => {
            if (field.type === 'column-repeater') {
                const maxCols = field.maxColumns || 10;
                const countApi = field.countApiName;
 
                expanded.push({
                    apiName: `${field.apiName}_top_spacer`,
                    label: ' ',
                    type: 'header',
                    colSpan: 4,
                    controllingField: countApi,
                    controllingValues: [">=1"],
                    isColRepeaterLabel: true,
                    repeaterApi: countApi,
                    repeaterMaxCols: maxCols
                });
 
                for (let c = 1; c <= maxCols; c++) {
                    expanded.push({
                        apiName: `${field.apiName}_top_hdr_${c}`,
                        label: String(c),
                        type: 'header',
                        colSpan: 2,
                        controllingField: countApi,
                        controllingValues: [">=1"],
                        columnCountApi: countApi,
                        columnCountIndex: c,
                        isColRepeaterInput: true,
                        repeaterApi: countApi,
                        repeaterMaxCols: maxCols
                    });
                }
 
               // NEW:
field.fields.forEach(subField => {
    // 👉 THE FIX: If subField has its own controllingField,
    // combine it with countApi so the label hides when condition isn't met.
    // We use c1_ prefix because column 1 is always the representative column for the label.
    let labelControllingField = countApi;
    let labelControllingValues = [">=1"];
 
    if (subField.controllingField) {
        const fieldsToReplace = globalApiNames.length > 0
            ? globalApiNames
            : field.fields.map(f => f.apiName);
 
        // Rewrite the subField's controllingField to use c1_ prefix (column 1 is representative)
        let cFields = subField.controllingField.split(',');
        let rewrittenControlling = cFields.map(cf => {
            let isNeg = cf.trim().startsWith('!');
            let clean = isNeg ? cf.trim().substring(1) : cf.trim();
            let isInternal = fieldsToReplace.includes(clean);
            return (isNeg ? '!' : '') + (isInternal ? `c1_${clean}` : clean);
        }).join(',');
 
        // Combine: must satisfy count>=1 AND the subField's own condition
        labelControllingField = `${countApi},${rewrittenControlling}`;
        labelControllingValues = subField.controllingValues || ['*'];
    }
 
    expanded.push({
        ...subField,
        apiName: `lbl_${subField.apiName}`,
        type: subField.hideLabelLayout ? subField.type : 'header',
        colSpan: 4,
        controllingField: labelControllingField,
        controllingValues: labelControllingValues,
        isColRepeaterLabel: true,
        repeaterApi: countApi,
        repeaterMaxCols: maxCols,
        formula: undefined,
        dependentOptionsMap: undefined  // 👉 Labels must never have dependentOptionsMap
    });
 
                   /* field.fields.forEach(subField => {
                    expanded.push({
                        ...subField,
                        apiName: `lbl_${subField.apiName}`,
                        type: subField.hideLabelLayout ? subField.type : 'header',
                        colSpan: 4,
                        controllingField: countApi,
                        controllingValues: [">=1"],
                        isColRepeaterLabel: true,
                        repeaterApi: countApi,
                        repeaterMaxCols: maxCols,
                        formula: undefined
                    });*/
 
 
 
                    // PERF - Deepanjan (4th September 2026)
                    // fieldsToReplace and its length-sorted copy are identical for every one of
                    // the maxCols iterations below, so build them ONCE per sub-field instead of
                    // once per column. The replace loop below is the SAME sequential,
                    // longest-first loop as before, so every formula comes out byte-identical.
                    const fieldsToReplace = globalApiNames.length > 0
                        ? globalApiNames
                        : field.fields.map(f => f.apiName);
                    const sortedToReplace = subField.formula
                        ? [...fieldsToReplace].sort((a, b) => b.length - a.length)
                        : null;

                    for (let c = 1; c <= maxCols; c++) {
                        let cloned = JSON.parse(JSON.stringify(subField));
                        cloned.apiName = `c${c}_${cloned.apiName}`;
                        cloned.label = cloned.unit ? cloned.unit : ' ';
                        cloned.colSpan = 2;
                        cloned.columnCountApi = countApi;
                        cloned.columnCountIndex = c;
                        cloned.isColRepeaterInput = true;
                        cloned.repeaterApi = countApi;
                        cloned.repeaterMaxCols = maxCols;
 
                        // Use globalApiNames (repeater sub-fields only, standalone fields excluded)
                        // so cross-repeater references like material_list_type → c1_material_list_type work,
                        // while standalone fields like 'discount' stay unprefixed.
                        // (fieldsToReplace / sortedToReplace are hoisted above the column loop - Deepanjan 4th Sep 2026)
 
                        if (cloned.formula) {
                            for (const apiName of sortedToReplace) {
                                cloned.formula = cloned.formula.replace(_prefixReFor(apiName), `c${c}_${apiName}`);
                            }
                        }
                       if (cloned.controllingFields && Array.isArray(cloned.controllingFields)) {
                            cloned.controllingFields = cloned.controllingFields.map(cf => {
                                let isNeg = cf.trim().startsWith('!');
                                let clean = isNeg ? cf.trim().substring(1) : cf.trim();
                                let isInternal = fieldsToReplace.includes(clean);
                                return (isNeg ? '!' : '') + (isInternal ? `c${c}_${clean}` : clean);
                            });
                        } else if (cloned.controllingField) {
                            let cFields = cloned.controllingField.split(',');
                            cloned.controllingField = cFields.map(cf => {
                                let isNeg = cf.trim().startsWith('!');
                                let clean = isNeg ? cf.trim().substring(1) : cf.trim();
                                let isInternal = fieldsToReplace.includes(clean);
                                return (isNeg ? '!' : '') + (isInternal ? `c${c}_${clean}` : clean);
                            }).join(',');
                        }
 
                        if (cloned.disableControllingField) {
                            let dFields = cloned.disableControllingField.split(',');
                            cloned.disableControllingField = dFields.map(df => {
                                let isNeg = df.trim().startsWith('!');
                                let clean = isNeg ? df.trim().substring(1) : df.trim();
                                let isInternal = fieldsToReplace.includes(clean);
                                return (isNeg ? '!' : '') + (isInternal ? `c${c}_${clean}` : clean);
                            }).join(',');
                        }
 
                        expanded.push(cloned);
                    }
                });
            } else if (field.type === 'grid-repeater') {
                const defaultRows = field.defaultRows || 5;
                const maxRows = field.maxRows || 10;
                const addMoreApi = field.addMoreApiName;
 
                for (let r = 1; r <= maxRows; r++) {
                    field.fields.forEach(subField => {
                        let clonedField = JSON.parse(JSON.stringify(subField));
                        clonedField.apiName = `r${r}_${clonedField.apiName}`;

                        // Every cell born from a grid-repeater is part of a TABLE by
                        // definition, whether or not the section also has header cells.
                        // The mobile marker in _updateSectionUI reads this flag so such
                        // sections keep the desktop 12-column shape and pan sideways on
                        // the phone. No desktop rule reads it. Reetabrata (17th July 2026)
                        clonedField.isGridRepeaterCell = true;
 
                        if (clonedField.defaultValue === '{row}') clonedField.defaultValue = String(r);
                        if (clonedField.label && clonedField.label.includes('{row}')) {
                            clonedField.label = clonedField.label.replace('{row}', r);
                        }
 
                        // added by faizan
 
                        if (clonedField.formula) {
                            const fieldsToReplace = field.fields.map(f => f.apiName);
                            [...fieldsToReplace].sort((a, b) => b.length - a.length).forEach(apiName => {
                                clonedField.formula = clonedField.formula.replace(
                                    new RegExp(`\\b${apiName}\\b`, 'g'),
                                    `r${r}_${apiName}`
                                );
                            });
                        }
 
                        // Endes
 
                        if (clonedField.controllingField) {
                            let cFields = clonedField.controllingField.split(',');
                            cFields = cFields.map(cf => {
                                let isNeg = cf.trim().startsWith('!');
                                let cleanName = isNeg ? cf.trim().substring(1) : cf.trim();
                                return (isNeg ? '!' : '') + `r${r}_${cleanName}`;
                            });
                            clonedField.controllingField = cFields.join(',');
                        }
 
                        if (r > defaultRows && addMoreApi) {
                            if (!clonedField.controllingField) {
                                clonedField.controllingField = addMoreApi;
                                clonedField.controllingValues = ["true"];
                            }
                        }
                        expanded.push(clonedField);
                    });
                }
            } // 👉 NEW: Sub-Section Logic
           // 👉 NEW: Sub-Section Logic
            else if (field.type === 'sub-section') {
                const headerApiName = `${field.apiName}_header`;
                const isExpandedDef = field.expanded === true; // Read 'expanded: true' from JSON
                // 👉 isVisible:false hides the whole sub-section; otherwise it shows by default - Reetabrata (8th July 2026)
                const subHidden = field.isVisible === false;
 
                // 1. Inject an Accordion Header field to visually separate this sub-section
                expanded.push({
                    apiName: headerApiName,
                    label: field.label || ' ',
                    type: 'sub-section-header', // 👉 Using custom type
                    isSubSectionExpanded: !subHidden, // Reetabrata (8th July 2026)
                    colSpan: field.colSpan || 12,
                    controllingField: field.controllingField || null,
                    controllingValues: field.controllingValues || ['*'],
                    forceHidden: subHidden // 👉 hard-hide when isVisible:false - Reetabrata (8th July 2026)
                });
 
                // 2. Flatten all child fields into the parent section
                if (field.fields && Array.isArray(field.fields)) {
                    field.fields.forEach(subField => {
                        let cloned = JSON.parse(JSON.stringify(subField));
                        
                        // 👉 Tie child to the Accordion Header
                        cloned.parentSubSectionApi = headerApiName; 
                        cloned.isCollapsedUI = subHidden; // shown by default; only hidden when isVisible:false - Reetabrata (8th July 2026)
                        cloned.forceHidden = subHidden;   // 👉 hard-hide when isVisible:false - Reetabrata (8th July 2026)
 
                        // Inherit the sub-section's visibility rules if the child doesn't have its own
                        if (field.controllingField) {
                            if (cloned.controllingField) {
                                cloned.controllingField = `${field.controllingField},${cloned.controllingField}`;
                            } else {
                                cloned.controllingField = field.controllingField;
                                cloned.controllingValues = field.controllingValues || ['*'];
                            }
                        }
                        expanded.push(cloned);
                    });
                }
            }
            else {
                expanded.push(field);
            }
        });
        return expanded;
    }
 
 
    // =========================================================
    // SECTION BUILDER 
    // =========================================================
    _buildSections(modalFields) {
        if (!modalFields || modalFields.length === 0) return [];
 
        let processedSections = this._expandSections(modalFields);
 
        const isFlat = processedSections[0].apiName !== undefined && processedSections[0].fields === undefined;
        if (isFlat) {
            let expandedFields = this._expandFields(processedSections);
            const fields = this._buildFields(expandedFields, 'default_section', true);
            return [this._makeSectionObj({ id: 'default_section', label: '', expanded: true }, fields)];
        }
 
        processedSections = processedSections.map(sectionDef => {
            if (sectionDef.cloneFrom) {
                let sourceFields = null;
 
                if (this._modalConfig.blueprints && this._modalConfig.blueprints[sectionDef.cloneFrom]) {
                    sourceFields = this._modalConfig.blueprints[sectionDef.cloneFrom];
                } else {
                    const sourceSection = processedSections.find(s => s.id === sectionDef.cloneFrom);
                    if (sourceSection) sourceFields = sourceSection.fields;
                }
 
                if (sourceFields) {
                    let sourceString = JSON.stringify(sourceFields);
                    const targetPrefix = sectionDef.replaceTarget || 'd1_';
                    const newPrefix = sectionDef.replaceWith || 'd2_';
 
                    sourceString = sourceString.split(targetPrefix).join(newPrefix);
 
                    if (sectionDef.replaceLabelTarget && sectionDef.replaceLabelWith) {
                        sourceString = sourceString.split(sectionDef.replaceLabelTarget).join(sectionDef.replaceLabelWith);
                    }
 
                    if (sectionDef.replaceExtraTarget && sectionDef.replaceExtraWith) {
                        sourceString = sourceString.split(sectionDef.replaceExtraTarget).join(sectionDef.replaceExtraWith);
                    }
 
                    try {
                        const clonedFields = JSON.parse(sourceString);
                        return { ...sectionDef, fields: clonedFields };
                    } catch (err) {
                        console.error(`❌ ERROR: Failed to clone string for ${sectionDef.cloneFrom}`, err);
                    }
                }
            }
            return sectionDef;
        });
 
        // 👉 FIX: Collect ALL base API names globally before expansion
        // Collect ONLY repeater sub-field names for cross-repeater formula replacement.
        // Standalone fields (like 'discount') are excluded — they must stay unprefixed.
        const globalApiNames = [];
        processedSections.forEach(sec => {
            if (sec.fields) {
                sec.fields.forEach(f => {
                    if (f.fields) {
                        f.fields.forEach(subF => globalApiNames.push(subF.apiName));
                    }
                    // Standalone fields (no nested f.fields) intentionally not added
                });
            }
        });
 
 
        return processedSections.map(sectionDef => {
            const showRequired = sectionDef.showRequired !== false;
            let finalFields = sectionDef.fields || [];
 
            // Pass global names into the expander so formulas update globally
            finalFields = this._expandFields(finalFields, globalApiNames);
 
            const builtFields = this._buildFields(finalFields, sectionDef.id, showRequired);
            return this._makeSectionObj(sectionDef, builtFields, showRequired);
        });
    }
 
    // evaluate section labels to render dynamic values like - "labelFormat": "{type_of_tower} - {ang_product_details1}" => Angular - XYZ - rajeev 29-05-2026
    _evaluateSectionLabels() {
        const allValues = {};
 
        // 1. Collect values from every modal field
        this.accordionSections.forEach(sec => {
            sec.fields.forEach(f => {
                if (f.value !== undefined && f.value !== null && f.value !== '') {
                    allValues[f.apiName] = f.value;
                }
            });
        });
 
        // also put values coming from modalSave Data
        if (this._lastValues) {
            Object.keys(this._lastValues).forEach(key => {
                if (!(key in allValues)) {
                    const v = this._lastValues[key];
                    if (v !== undefined && v !== null && v !== '') {
                        allValues[key] = v;
                    }
                }
            })
        }
 
        // replace apiName placeholder in labelFormat
        this.accordionSections.forEach(sec => {
            if (!sec.labelFormat) return;
            sec.label = sec.labelFormat.replace(/\{([^}]+)\}/g, (match, apiName) => {
                const val = allValues[apiName];
                return (val !== undefined && val !== null && val !== '') ? String(val) : '';
            });
        })

        this.accordionSections.forEach(sec => {
            sec.fields.forEach(f => {
                if (!f.labelsByController || !f.labelsByController.controllingApi) return;

                const cfg = f.labelsByController;
                // allValues already holds every field value + _lastValues (built above)
                const ctrlVal = allValues[cfg.controllingApi] !== undefined
                    ? String(allValues[cfg.controllingApi]).trim()
                    : '';

                const newLabel = (ctrlVal !== '' && cfg.map && cfg.map[ctrlVal] !== undefined)
                    ? cfg.map[ctrlVal]
                    : (cfg.default !== undefined ? cfg.default : f.baseLabel);

                if (f.label !== newLabel) {
                    f.label = newLabel;
                    this._updateFieldUI(f);
                }
            });
        });
    }
 
    // validate telecom tower composition updated for both tubular/signalling - rajeev 10-09-2026
    _validateTelecomTowerComposition() {
        const groups = [];

        Object.keys(TELECOM_COMPOSITION_GROUPS).forEach(product => {
            const apis = TELECOM_COMPOSITION_GROUPS[product];
            const seen = new Set();
            let total = 0;
            let found = false;

            this.accordionSections.forEach(sec => {
                sec.fields.forEach(f => {
                    if (!f.isVisible) return;
                    if (!apis.includes(f.apiName)) return;
                    if (seen.has(f.apiName)) return;   // same field in 2 sections
                    seen.add(f.apiName);
                    found = true;
                    total += Number(f.value) || 0;
                });
            });

            if (found) groups.push({ product, total: Math.round(total * 100) / 100 });
        });

        // no composition fields on this modal - every other department unaffected
        if (groups.length === 0) return true;

        const bad = groups.filter(g => g.total > 100);
        if (bad.length === 0) return true;

        const detail = bad.map(g => `${g.product} is ${g.total}%`).join(' and ');
        this.dispatchEvent(new ShowToastEvent({
            title: 'Composition Error',
            message: `Total composition for ${detail}. The sum of PIPE + PLATE + ANGLES & CHANNELS `
                + '+ MISCELLANEOUS must not exceed 100% for each tower type. Please correct the '
                + 'values before saving.',
            variant: 'error'
        }));
        return false;
    }

    // Adding validation for payments that such that each angular, tubular, & tubular signalling should have same payment
    // terms details - rajeev 14 sep
    _validateTelecomPaymentTerms() {
        const PRODUCTS = [
            { name: 'Angular',            pfx: 'agl_' },
            { name: 'Tubular',            pfx: 'tub_' },
            { name: 'Tubular Signalling', pfx: 'tsg_' }
        ];
        const GATE = 'payment_terms_req';
        const TERM = 'select_payment_terms';
        const DAYS = 'payment_terms_days';
        const RATE = 'bank_int_rate';
        const NEEDS_DETAIL = ['Against LC Before Dispatch', 'Against VFS'];
        const VIRTUAL_SECTION = '__cross_modal_context__';

        // real    = fields declared by THIS modal's JSON (visible copy preferred)
        // virtual = other modals' saved values injected by crossPriceVariationContext
        const real = new Map();
        const virtual = new Map();
        (this.accordionSections || []).forEach(sec => {
            const isVirtualSec = !!sec && sec.id === VIRTUAL_SECTION;
            (sec && sec.fields || []).forEach(f => {
                if (!f || !f.apiName) return;
                if (isVirtualSec || f.type === 'hidden') {
                    if (!virtual.has(f.apiName)) virtual.set(f.apiName, f);
                    return;
                }
                const hit = real.get(f.apiName);
                if (!hit || (!hit.isVisible && f.isVisible)) real.set(f.apiName, f);
            });
        });

        // Which product's modal is open? Decided from REAL fields only.
        const mine = PRODUCTS.find(p => real.has(p.pfx + TERM));
        if (!mine) return true;                       // not a Telecom Tower modal

        const saved = this._lastValues || {};
        const isBlank = v => v === '' || v === null || v === undefined || String(v).trim() === '';
        const str = v => (isBlank(v) ? '' : String(v).trim());
        const num = v => { if (isBlank(v)) return null; const n = Number(v); return isNaN(n) ? null : n; };

        // Accepts the gate as a checkbox (true) or as a Yes/No picklist.
        const GATE_ON = new Set(['true', 'yes', 'y', '1']);
        const gateOn = v => (v === true || v === 1) ? true : GATE_ON.has(str(v).toLowerCase());

        // Current product: live real field. Other products: virtual copy, then saved.
        const read = (p, key) => {
            const api = p.pfx + key;
            if (p.pfx === mine.pfx) return real.has(api) ? real.get(api).value : '';
            if (virtual.has(api))   return virtual.get(api).value;
            return saved[api];
        };

        const entries = [];
        PRODUCTS.forEach(p => {
            if (!gateOn(read(p, GATE))) return;       // gate OFF -> not participating
            const term = str(read(p, TERM));
            if (term === '') return;                  // gate ON but no term chosen yet
            entries.push({
                name: p.name,
                term,
                days: num(read(p, DAYS)),
                rate: num(read(p, RATE))
            });
        });

        if (entries.length < 2) return true;          // only one tower type to check

        // Master = first participating tower type (Angular -> Tubular -> Signalling).
        const master = entries[0];
        const problems = [];

        entries.slice(1).forEach(e => {
            if (e.term !== master.term) {
                problems.push(`${e.name} is "${e.term}" but ${master.name} is "${master.term}".`);
            }
        });

        // Only once every participant agrees on the term do the LC / VFS details matter.
        if (problems.length === 0 && NEEDS_DETAIL.includes(master.term)) {
            entries.slice(1).forEach(e => {
                if (e.days === null && master.days !== null) {
                    problems.push(`No Of Days is missing on ${e.name} - it must be `
                        + `${master.days}, same as ${master.name}.`);
                } else if (e.days !== null && master.days !== null && e.days !== master.days) {
                    problems.push(`No Of Days differs - ${master.name}: ${master.days}, `
                        + `${e.name}: ${e.days}.`);
                }

                // Rate is a rounded formula output (3 dp) - compare with a tiny epsilon,
                // same as the Tower / Substation check.
                if (e.rate === null && master.rate !== null) {
                    problems.push(`Prevailing rate of Bank Interest is missing on ${e.name} - `
                        + `it must be ${master.rate}%, same as ${master.name}.`);
                } else if (e.rate !== null && master.rate !== null
                        && Math.abs(e.rate - master.rate) > 0.00005) {
                    problems.push(`Prevailing rate of Bank Interest differs - `
                        + `${master.name}: ${master.rate}%, ${e.name}: ${e.rate}%.`);
                }
            });
        }

        if (problems.length === 0) return true;

        this.dispatchEvent(new ShowToastEvent({
            title: 'Telecom Tower - Payment Terms Mismatch',
            message: 'Every tower type with the Interest Component turned on must use the same '
                + 'Payment Terms:\n' + problems.join('\n')
                + '\nPlease correct it before saving.',
            variant: 'error'
        }));
        return false;
    }

    /*
     * Tower and Substation must agree on Price Basis: Price Variation on one
     * means Price Variation on the other, FIRM means FIRM.
     *
     * The two live in separate Section Logic records under different apiNames -
     * Tower `pvt_price_basics` (options "Price Variation" / "FIRM") and
     * Substation `pvs_price_model` (options "Price Variation" / "Firm"). Note the
     * casing differs between the two option sets, so the comparison is
     * normalised rather than a raw ===.
     *
     * Both records set requiresCrossModalData: true, so crossPriceVariationContext()
     * in createQuote.js merges the other modal's saved keys into savedData, which
     * lands in this._lastValues. That is how the Substation modal can see the
     * Tower's basis and the other way round. Same read order the PV-rate block
     * above uses: the live field first, the cross-modal saved value as fallback.
     *
     * Fires only when BOTH sides actually have a value. Whichever modal is filled
     * first has nothing to compare against and must not be blocked; the mismatch
     * surfaces when the second one is applied. Editing the first one later is
     * caught too, because by then the second side is saved.
     *
     * Returns true for every other department - if neither field is on this modal
     * there is nothing to check. Deepanjan (12th August 2026)
     */
    _validateTowerSubstationPriceBasis() {
        const TOWER_API = 'pvt_price_basics';
        const SUBSTATION_API = 'pvs_price_model';

        // Prefer a visible field, then any field, then the cross-modal saved value.
        const readBasis = (apiName) => {
            let anyMatch = null;
            for (const sec of this.accordionSections || []) {
                for (const f of sec.fields || []) {
                    if (f.apiName !== apiName) continue;
                    if (f.isVisible) return String(f.value || '').trim();
                    if (anyMatch === null) anyMatch = String(f.value || '').trim();
                }
            }
            if (anyMatch) return anyMatch;
            return String(this._lastValues[apiName] || '').trim();
        };

        const onThisModal = (this.accordionSections || []).some(sec =>
            (sec.fields || []).some(f => f.apiName === TOWER_API || f.apiName === SUBSTATION_API)
        );
        if (!onThisModal) return true;

        const towerBasis = readBasis(TOWER_API);
        const substationBasis = readBasis(SUBSTATION_API);
        if (!towerBasis || !substationBasis) return true;

        // "FIRM" vs "Firm" is the same choice spelled two ways.
        const normalise = (v) => v.toUpperCase().replace(/\s+/g, ' ');
        if (normalise(towerBasis) === normalise(substationBasis)) return true;

        this.dispatchEvent(new ShowToastEvent({
            title: 'Price Basis Mismatch',
            message: `Tower is set to "${towerBasis}" but Substation is set to "${substationBasis}". `
                + 'Both must use the same Price Basis. Please correct one of them before saving.',
            variant: 'error'
        }));
        return false;
    }

    _validateTowerSubstationPaymentTerms() {
        const TOWER_BASIS_API = 'pvt_price_basics';
        const SUBSTATION_BASIS_API = 'pvs_price_model';

        // visible field first, then any matching field, then the cross-modal
        // saved value. Generic so it can read basis, picklist, checkbox and
        // number fields alike.
        const readRaw = (apiName) => {
            let anyMatch;
            for (const sec of this.accordionSections || []) {
                for (const f of sec.fields || []) {
                    if (f.apiName !== apiName) continue;
                    if (f.isVisible) return f.value;
                    if (anyMatch === undefined) anyMatch = f.value;
                }
            }
            if (anyMatch !== undefined) return anyMatch;
            return this._lastValues ? this._lastValues[apiName] : undefined;
        };

        const readStr = (apiName) => String(readRaw(apiName) || '').trim();
        const readBool = (apiName) => {
            const v = readRaw(apiName);
            return v === true || v === 'true';
        };
        // Returns null when genuinely empty (not-yet-filled), never 0-as-empty.
        const readNum = (apiName) => {
            const v = readRaw(apiName);
            if (v === '' || v === null || v === undefined) return null;
            const n = Number(v);
            return isNaN(n) ? null : n;
        };

        const onThisModal = (this.accordionSections || []).some(sec =>
            (sec.fields || []).some(f => f.apiName === TOWER_BASIS_API || f.apiName === SUBSTATION_BASIS_API)
        );
        if (!onThisModal) return true;

        // "FIRM" vs "Firm" - same normalisation used for the basis comparison.
        const normalise = (v) => v.toUpperCase().replace(/\s+/g, ' ');

        const towerBasis = normalise(readStr(TOWER_BASIS_API));
        const substationBasis = normalise(readStr(SUBSTATION_BASIS_API));

        const towerPrefix =
            towerBasis === 'FIRM' ? 'pvt_firm_' :
            towerBasis === 'PRICE VARIATION' ? 'pvt_pv_' : null;

        const substationPrefix =
            substationBasis === 'FIRM' ? 'pvs_firm_' :
            substationBasis === 'PRICE VARIATION' ? 'pvs_pv_' : null;

        // Either side hasn't picked a basis yet, or the two bases disagree -
        // in both cases there is no safe, single field-set pair to compare, and
        // a basis mismatch is already reported (or will be) by
        // _validateTowerSubstationPriceBasis. Stay silent here.
        if (!towerPrefix || !substationPrefix) return true;
        if (towerPrefix.startsWith('pvt_firm_') !== substationPrefix.startsWith('pvs_firm_')) return true;

        if (towerPrefix === 'pvt_pv_') {
            const towerModule = readStr('pvt_price_module');
            const substationModule = readStr('pvs_price_module');
            const towerMonth = readStr('pvt_price_variable_month');
            const substationMonth = readStr('pvs_price_variable_month');
            const towerYear = readStr('pvt_price_variable_year');
            const substationYear = readStr('pvs_price_variable_year');

            const pvProblems = [];

            if (towerModule && substationModule && towerModule !== substationModule) {
                pvProblems.push(`PRICE MODULE (Tower: "${towerModule}", Substation: "${substationModule}")`);
            }
            if (towerMonth && substationMonth && towerMonth !== substationMonth) {
                pvProblems.push(`PRICE VARIATION (MONTH) (Tower: "${towerMonth}", Substation: "${substationMonth}")`);
            }
            if (towerYear && substationYear && towerYear !== substationYear) {
                pvProblems.push(`PRICE VARIABLE (YEAR) (Tower: "${towerYear}", Substation: "${substationYear}")`);
            }

            if (pvProblems.length > 0) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Price Variation Details Mismatch',
                    message: 'Both Tower and Substation are on Price Variation, but the following details '
                        + `differ: ${pvProblems.join('; ')}. These must be identical between Tower and `
                        + 'Substation. Please correct one of them before saving.',
                    variant: 'error'
                }));
                return false;
            }
        }

        const towerInterestOn = readBool(`${towerPrefix}interest_component`);
        const substationInterestOn = readBool(`${substationPrefix}interest_component`);

        // Payment Terms only exists once the "Interest Component ... ?" checkbox
        // is on. If either side hasn't switched it on (or hasn't picked a term
        // yet), there is nothing on that side to compare against - don't block.
        if (!towerInterestOn && !substationInterestOn) return true;

        const towerTerm = readStr(`${towerPrefix}payment_terms`);
        const substationTerm = readStr(`${substationPrefix}payment_terms`);

        if (!towerTerm || !substationTerm) return true;

        if (towerTerm !== substationTerm) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Payment Terms Mismatch',
                message: `Tower Payment Terms is "${towerTerm}" but Substation Payment Terms is `
                    + `"${substationTerm}". Both must use the same Payment Terms. Please correct one `
                    + 'of them before saving.',
                variant: 'error'
            }));
            return false;
        }

        // Only "Against LC Before Dispatch" and "Against VFS" unlock the extra
        // No Of Days / Prevailing Rate fields. Every other Payment Terms value
        // (Before Dispatch, Against PDC, Against Open Credit) has no further
        // fields to reconcile, so matching the term above is already sufficient.
        const NEEDS_DETAIL = ['Against LC Before Dispatch', 'Against VFS'];
        if (!NEEDS_DETAIL.includes(towerTerm)) return true;

        const towerDays = readNum(`${towerPrefix}no_of_days`);
        const substationDays = readNum(`${substationPrefix}no_of_days`);
        const towerRate = readNum(`${towerPrefix}prevailing_rate_of_bank_interest`);
        const substationRate = readNum(`${substationPrefix}prevailing_rate_of_bank_interest`);

        const problems = [];

        // Only compare once BOTH sides have entered the detail value - same
        // non-blocking rule as everything above.
        if (towerDays !== null && substationDays !== null && towerDays !== substationDays) {
            problems.push(`No Of Days (Tower: ${towerDays}, Substation: ${substationDays})`);
        }

        // Rate is a rounded formula output (rounded to 3 decimals by the global
        // math engine) - compare with a tiny epsilon instead of strict ===.
        if (towerRate !== null && substationRate !== null && Math.abs(towerRate - substationRate) > 0.00005) {
            problems.push(`Prevailing Rate of Bank Interest (Tower: ${towerRate}%, Substation: ${substationRate}%)`);
        }

        if (problems.length > 0) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Payment Terms Detail Mismatch',
                message: `Both sides use Payment Terms "${towerTerm}", but the following details differ: `
                    + `${problems.join('; ')}. These must be identical between Tower and Substation. `
                    + 'Please correct one of them before saving.',
                variant: 'error'
            }));
            return false;
        }

        return true;
    }
 
    _formatDateDDMMYYYY(isoStr) {
    if (!isoStr || typeof isoStr !== 'string') return '';
    const parts = isoStr.split('-'); // YYYY-MM-DD
    if (parts.length !== 3) return isoStr;
    const [yyyy, mm, dd] = parts;
    return `${dd}/${mm}/${yyyy}`;
    }
 
    _makeSectionObj(sectionDef, fields, showRequired = true) {
        const sec = {
            id: sectionDef.id || sectionDef.name,
            label: sectionDef.label || '',
            labelFormat: sectionDef.labelFormat || null,
            isExpanded: sectionDef.expanded !== false,
            showRequired: showRequired,
            isCheckboxGroup: sectionDef.isCheckboxGroup || false,
            controllingField: sectionDef.controllingField || null,
            controllingValues: sectionDef.controllingValues || null,
            controllingOperator: sectionDef.controllingOperator || 'OR',
            // lineItemGroup lets two sections contribute to ONE line item. The grouping code
            // below already reads sec.lineItemGroup, but _makeSectionObj never copied it, so it
            // was permanently undefined and groupId always fell back to sec.id. No metadata
            // sets it today, so null keeps every existing section on its own id exactly as
            // before. Reetabrata (16th July 2026)
            lineItemGroup: sectionDef.lineItemGroup || null,
            isVisible: !sectionDef.controllingField,
            forceHidden: sectionDef.isVisible === false, // 👉 isVisible:false hides the section - Reetabrata (8th July 2026)
            fields: fields,
            chevronIcon: '',
            headerClass: '',
            gridWrapperClass: '',
            visibleFields: []
        };
 
        if (sectionDef.isExpanded !== undefined) sec.isExpanded = sectionDef.isExpanded;
        if (sectionDef.isVisible !== undefined) sec.isVisible = sectionDef.isVisible;
 
        // ═══════════════════════════════════════════════════════════════════════
        // isVisible:false ALWAYS HIDES THE WHOLE SECTION. Reetabrata (14th July 2026)
        // A section marked isVisible:false is a pure internal calc block: it stays
        // fully hidden in the UI (forceHidden), its formulas still compute in
        // _evaluateAllFormulas, and all its fields still persist to the saved JSON via
        // the forceHidden branch in the save path. No auto-reveal of input fields.
        // ═══════════════════════════════════════════════════════════════════════

        this._updateSectionUI(sec);
        return sec;
    }
 
    _updateSectionUI(sec) {
        sec.chevronIcon = sec.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
 
        const req = sec.fields.some(f => f.required && f.isVisible && !f.hasValue);
        sec.headerClass = sec.isExpanded
            ? `section-header expanded${req ? ' has-required' : ''}`
            : `section-header${req ? ' has-required' : ''}`;
 
        const isSpreadsheet = sec.fields.some(f => f.colSpan && f.colSpan < 12);
        sec.gridWrapperClass = isSpreadsheet
            ? 'section-fields slds-grid slds-wrap grid-container spreadsheet-mode'
            : 'section-fields slds-grid slds-wrap grid-container standard-mode';
 
        sec.visibleFields = sec.fields.filter(f => f.isVisible);

        // Column-repeater sections (a label column + c1..cN value columns) lose all
        // meaning when their cells are stacked vertically - the labels pile up first
        // and the values follow with nothing tying them together. This marker lets the
        // mobile CSS keep exactly the desktop table shape for THESE sections and pan
        // them sideways, while every other section stacks into the 2-column form grid.
        // No rule outside @media (max-width: 600px) targets the class, so desktop
        // rendering is untouched. Reetabrata (17th July 2026)
        if (sec.fields.some(f => f.isColRepeaterInput || f.isColRepeaterLabel)) {
            sec.gridWrapperClass += ' has-col-repeater';
        }

        // Grid-header TABLES get the same mobile treatment. Sections like LM/LCLM
        // General Details (SL NO. / HEIGHT OF MAST / ... header cells followed by
        // grid-repeater rows) and HDPE Accessories Details (Sl no. / Product Category /
        // Item Name / ... header cells followed by input cells with matching colSpans)
        // are tables exactly like the col-repeater sections: stacking their cells
        // vertically detaches every value from its column heading, which is what the
        // phone screenshots showed. A section qualifies when it renders at least one
        // grid-header-cell, i.e. a type:'header' field with colSpan < 12 (full-width
        // colSpan 12 headers are plain row titles, not table columns, so they do NOT
        // mark the section). Also marks any section containing grid-repeater cells
        // (isGridRepeaterCell, tagged during expansion) so header-less grid tables and
        // tables inside FOLDER-launched modals are caught too - folder modals build
        // their sections through this very same path. Reusing the existing
        // has-col-repeater class means the
        // MOBILE v3 CSS (desktop 12-column track + horizontal pan) applies unchanged,
        // and since no rule outside @media (max-width: 600px) targets the class,
        // desktop rendering stays byte-identical. Reetabrata (17th July 2026)
        if (!sec.gridWrapperClass.includes('has-col-repeater') &&
            sec.fields.some(f => ((f.isHeader || f.type === 'header') && f.colSpan && f.colSpan < 12) || f.isGridRepeaterCell)) {
            sec.gridWrapperClass += ' has-col-repeater';
        }


        // MOBILE: a phone table packs its 12 columns into 56px each, which leaves an
        // input in a 1-span column only ~6px of visible text - typed values, picked
        // picklist values and auto-filled weights are there but cannot be seen (CB
        // Accessories / Miscellaneous). When such a table has an EDITABLE input in a
        // 1-span column, mark it so the mobile CSS gives the table wider columns. Read
        // once, when the section is built, from the metadata (not from view-mode
        // read-only), so the table keeps the same width in view mode. Desktop never
        // reads this class. Deepanjan (24th September 2026)
        if (sec._narrowInputs === undefined) {
            sec._narrowInputs = sec.gridWrapperClass.includes('has-col-repeater') &&
                                sec.fields.some(f => Number(f.colSpan) === 1 && !f.baseReadOnly &&
                    // Telecom tables: colSpan comes as the string "1" and the AWT inputs carry a
                    // formula (pre-filled from BOM) while staying editable - both must still
                    // count. Every other department keeps the original test. Deepanjan (29th Sep 2026)
                    (!f.formula || (this._modalConfig && this._modalConfig.department === 'Telecom Tower - Department')) &&
                    ['picklist', 'number', 'text', 'date', 'textarea'].includes(f.type));
        }
        if (sec._narrowInputs && sec.gridWrapperClass.includes('has-col-repeater')) {
            sec.gridWrapperClass += ' has-narrow-inputs';
        }
    }
 
    
    // =========================================================
    // FIELD BUILDER reeta
    // =========================================================
    _buildFields(fieldDefs, sectionId, showRequired = true) {
        return fieldDefs.map(f => {
            const defaultVal = this._computeDefaultVal(f);
            const lastVal = this._lastValues[f.apiName];
            const wasCleared = this._lastValues[`${f.apiName}__cleared`] === true;
            const wasManual = this._lastValues[`${f.apiName}__manual`] === true;
            const hasLastVal = !wasCleared && lastVal !== undefined && lastVal !== null && lastVal !== '';
 
            const initialValue = f.formula
                ? (hasLastVal ? lastVal : (defaultVal !== '' ? defaultVal : ''))
                : (hasLastVal ? lastVal : (wasCleared ? '' : defaultVal));
 
            const field = {
                apiName: f.apiName,
                label: f.label,
                type: f.type,
                labelsByController: f.labelsByController || null,
                value: initialValue,
                isWeightTotal: f.isWeightTotal || false,
                isQuantity: f.isQuantity || false,
                isRealization: f.isRealization || false,
                isUnitPrice: f.isUnitPrice || false,
                isUnitCost: f.isUnitCost || false,
                isListPrice: f.isListPrice || false,
                isMargin: f.isMargin || false,
                isDiscount: f.isDiscount || false,        
                isAddedUp: f.isAddedUp || false,          // 👉 ADD THIS
                isTolerance: f.isTolerance || false, 
                approvalMetric: f.approvalMetric || null,  //added by faizan
                defaultValue: defaultVal,
                userCleared: wasCleared,
                isManualOverride: wasManual,
                formula: f.formula || null,
                required: showRequired ? (f.required || false) : false,
 
                // 👉 SAFELY INJECTED TRACKER FOR READONLY
                readOnly: this.isReadOnly ? true : (f.readOnly || false),
                baseReadOnly: f.readOnly || false,
 
                unit: f.unit || null,
                min: f.min || null,
                max: f.max || null,
                controllingField: f.controllingField || null,
                controllingValues: f.controllingValues || ['*'],
 
                disableControllingField: f.disableControllingField || null,
                disableControllingValues: f.disableControllingValues || ['*'],
                hideLabelLayout: f.hideLabelLayout || false,
 
                columnCountApi: f.columnCountApi || null,
                columnCountIndex: f.columnCountIndex || null,
                isColRepeaterLabel: f.isColRepeaterLabel || false,
                isColRepeaterInput: f.isColRepeaterInput || false,
                // carried from the grid-repeater expansion; read only by the mobile
                // table marker in _updateSectionUI. Reetabrata (17th July 2026)
                isGridRepeaterCell: f.isGridRepeaterCell || false,
                repeaterApi: f.repeaterApi || null,
                repeaterMaxCols: f.repeaterMaxCols || null,
 
                options: (f.options || []).map(opt => ({ label: opt, value: opt })),
                masterOptions: (f.options || []).map(opt => ({ label: opt, value: opt })), //  SAVES ORIGINAL LIST Abhishek saxena
                dependentOptionsMap: f.dependentOptionsMap || null, // CATCHES THE MAP FROM JSON Abhishek saxena
                controllingFields: f.controllingFields || null,//CATCHES THE ARRAY Abhishek saxena
                //Abhishek saxena
                lookupWeight: f.lookupWeight || false,
                weightMap: f.weightMap || null,
                baseRatesMap: f.baseRatesMap || null,
                calculateTotalWeight: f.calculateTotalWeight || false,
                calculateSecretWeight: f.calculateSecretWeight || false,
                //End
                sectionId,
                colSpan: f.colSpan || 12,
                isVisible: false,
 
                isSubSectionHeader: false,
                isSubSectionExpanded: f.isSubSectionExpanded || false,
                parentSubSectionApi: f.parentSubSectionApi || null,
                isCollapsedUI: f.isCollapsedUI || false,
                forceHidden: f.forceHidden || false, // Reetabrata (8th July 2026)
 
                containerClass: '', checkboxCellClass: '', dividerClass: '', labelClass: '',
               
                isText: false, isPicklist: false, isNumber: false, isDate: false, isCheckbox: false, isHeader: false, isTextarea: false, hasValue: false
            };
 
            this._updateFieldUI(field);
            return field;
        });
    }
 
    _updateFieldUI(field) {
        field.isText = field.type === 'text';
        field.isPicklist = field.type === 'picklist';
        field.isNumber = field.type === 'number';
        field.isDate = field.type === 'date';
        field.isCheckbox = field.type === 'checkbox';
        field.isHeader = field.type === 'header';
        
        // 👉 CRITICAL FIX: This triggers the HTML to draw the grey accordion box!
        field.isSubSectionHeader = field.type === 'sub-section-header'; 
        
        field.isTextarea = field.type === 'textarea';
        field.isSubtypeQtyGrid = field.type === 'subtype_qty_grid';
        
        field.displayValue = field.isDate ? this._formatDateDDMMYYYY(field.value) : field.value;
 
        const sizeClass = `slds-col slds-size_${field.colSpan}-of-12`;
       let baseClass = (field.type === 'header' || field.type === 'sub-section-header')
            ? (field.colSpan < 12 ? 'field-cell-grid grid-header-cell' : 'field-row-header')
            : (field.colSpan < 12 ? 'field-cell-grid' : 'field-row-standard');
            
        if (field.readOnly) baseClass += ' readonly-row';
        
        // 👉 This hides the internal fields when the accordion is collapsed
        if (field.isCollapsedUI) baseClass += ' slds-hide';
        
        field.containerClass = `${sizeClass} ${baseClass}`;
 
        // 👉 This controls the chevron rotation
        if (field.isSubSectionHeader) {
            field.chevronIcon = field.isSubSectionExpanded ? 'utility:chevrondown' : 'utility:chevronright';
            field.subSectionHeaderClass = `sub-section-header-bar ${field.isSubSectionExpanded ? 'expanded' : ''}`;
        }
 
        field.checkboxCellClass = field.value === true ? 'checkbox-cell selected' : 'checkbox-cell';
 
        field.hasValue = field.type === 'checkbox' ? field.value === true : (field.value !== '' && field.value !== null && field.value !== undefined);
        field.dividerClass = (field.required && !field.hasValue) ? 'field-divider required-divider' : 'field-divider';
        field.labelClass = field.required ? 'field-label required-label' : 'field-label';
        if (field.isSubtypeQtyGrid) this._sqgEnrich(field);
    }
 
    _computeDefaultVal(f) {
        if (f.type === 'checkbox') return f.defaultValue || false;
        if (f.type === 'number') {
            return (f.defaultValue !== undefined && f.defaultValue !== null) ? Number(f.defaultValue) : '';
        }
        return (f.defaultValue !== undefined && f.defaultValue !== null) ? String(f.defaultValue) : '';
    }

    /* No class-level this.isFirmMode exists — detect mode the same way the
       pricing engine does: material grid present AND no PV month field = FIRM.*/
    _sqgIsFirm() {
        const hasMaterialField = this.accordionSections.some(sec =>
            sec.fields.some(f =>
                f.apiName === 'material_list_type_1' ||
                /^c\d+_material_list_type$/.test(f.apiName)
            )
        );
        const hasPVMonthField = this.accordionSections.some(sec =>
            sec.fields.some(f => f.apiName === 'price_variable_month')
        );
        return hasMaterialField && !hasPVMonthField;
    }

    /* ═══════════════ Core SUB-TYPE × QUANTITY multiselect widget (Path B) ═══════════════
       One field type: 'subtype_qty_grid'. Fully gated. Writes total_weight + total_quantity
       into the  column's EXISTING slots,so unit_rate / cost / summary / line-item stay
       unchanged. Weight comes from CORE_SUBTYPE_DATA (blueprint ternary -> weightMap). */

    _sqgDataset() {
        const key = this._sqgIsFirm() ? 'FIRM' : 'PV';
        return (CORE_SUBTYPE_DATA && CORE_SUBTYPE_DATA[key]) || { weightMap: {}, typeToSubtypes: {} };
    }

    // self-locate this column's target slots from the widget's own c{N}_ prefix
    _sqgTargets(field) {
        const m = (field.apiName || '').match(/^(c\d+_)/);
        const pfx = m ? m[1] : '';
        return {
            controllingApi: field.controllingField || (pfx + 'material_list_type'),
            weightApi: pfx + 'total_weight_mt',
            qtyApi: pfx + (this._sqgIsFirm() ? 'quantity_mt' : 'quantity_pc')
        };
    }

    _sqgGetSelection(fieldApi) {
        // field.value is the source of truth (it survives _saveCurrentValues and
        // persists through save/reopen); _lastValues is the fallback
        const fld = this._sqgFindField(fieldApi);
        const raw = (fld && fld.value) ? fld.value : this._lastValues[fieldApi];
        if (!raw || typeof raw !== 'string') return [];
        try { const p = JSON.parse(raw); return Array.isArray(p) ? p : []; } catch (e) { return []; }
    }
    _sqgSaveSelection(fieldApi, rows) {
        // Embed the per-unit weight (MT) on every row: the MATERIAL LIST table in
        // CoreOfferLetterController reads c{n}_subtype_qty as [{subtype, qty, wt}]
        // and prints WEIGHT/NOS (KG) + TOTAL WEIGHT (MT) from wt. Without it the
        // Apex fallback only covers single-subtype columns; multi-subtype columns
        // print blank weight cells. Deepanjan (24th July 2026)
        const _ds = this._sqgDataset();
        rows.forEach(r => { r.wt = Number(_ds.weightMap[r.subtype]) || 0; });
        const json = JSON.stringify(rows);
        this._lastValues[fieldApi] = json;
        this.accordionSections.forEach(sec => sec.fields.forEach(fl => {
            if (fl.apiName === fieldApi) { fl.value = json; fl.userCleared = false; }
        }));
    }

    // resolve a field's CURRENT value: live field object first (slow path writes
    // field.value immediately but _lastValues only syncs later), then _lastValues
    _sqgLiveVal(api) {
        if (this.accordionSections && this.accordionSections.length) {
            for (const sec of this.accordionSections) {
                const f = (sec.fields || []).find(x => x.apiName === api);
                if (f && f.value !== '' && f.value !== null && f.value !== undefined) return f.value;
            }
        }
        const lv = this._lastValues ? this._lastValues[api] : undefined;
        return (lv === undefined || lv === null) ? '' : lv;
    }

    // build the render model for one widget field (called from _updateFieldUI)
    // ---- mobile bottom-sheet open/close (phone layout only; the launcher
    //      button is display:none on desktop, so this never fires there) ----
    handleSqgSheetOpen(event) {
        const api = event.currentTarget.dataset.name;
        const field = this._sqgFindField(api);
        // readOnly no longer blocks OPENING: after Apply the launcher is the only
        // way to see the saved selection. Every control inside the sheet already
        // carries disabled={field.readOnly}, so in read-only it opens as a pure
        // view-only popup - nothing can be changed from it. Edit mode identical.
        // Reetabrata (24th July 2026)
        if (!field) return;
        field.sqgSheetOpen = true;
        this.accordionSections = [...this.accordionSections];
    }

    handleSqgSheetClose(event) {
        const api = event.currentTarget.dataset.name;
        const field = this._sqgFindField(api);
        if (!field) return;
        field.sqgSheetOpen = false;
        this.accordionSections = [...this.accordionSections];
    }

    _sqgEnrich(field) {
        const ds = this._sqgDataset();
        const t = this._sqgTargets(field);
        const selectedType = String(this._sqgLiveVal(t.controllingApi) || '');
        const available = ds.typeToSubtypes[selectedType] || [];

        // auto-drop stale subtypes when the material type changes (only if we know the list)
        let rows = this._sqgGetSelection(field.apiName);
        // Upgrade pass: rows saved before wt existed get it embedded the next time
        // the modal is opened in EDIT mode (save re-derives wt for every row), so a
        // reopen + Apply makes an old quote's MATERIAL LIST weights print too.
        // Deepanjan (24th July 2026)
        if (!field.readOnly && rows.length > 0 && rows.some(r => r.wt === undefined)) {
            this._sqgSaveSelection(field.apiName, rows);
        }
        // Guard: in read-only (post-Apply view) never rewrite the saved selection.
        // The auto-drop below would otherwise silently delete saved sub-types from
        // a quote nobody can edit. Edit mode unchanged (!readOnly is always true).
        // Reetabrata (24th July 2026)
        if (available.length > 0 && !field.readOnly) {
            const availSet = new Set(available);
            const filtered = rows.filter(r => availSet.has(r.subtype));
            if (filtered.length !== rows.length) { rows = filtered; this._sqgSaveSelection(field.apiName, rows); }
        }

        field.isDependentBlocked = !selectedType;
        const selSet = new Set(rows.map(r => r.subtype));
        field.subtypeOptions = available.map(sub => ({ label: sub, value: sub, checked: selSet.has(sub) }));
        field.selectedValues = rows.map(r => r.subtype);
        const prevRows = field.qtyRows || [];
        field.qtyRows = rows.map(r => {
            const w = Number(ds.weightMap[r.subtype]) || 0;
            const q = Number(r.qty) || 0;
            const existing = prevRows.find(p => p.subtype === r.subtype);
            if (existing) {
                existing.qty = r.qty; existing.unitWeight = w;
                existing.rowWeight = this._sqgRound(w * q, 5);
                return existing;
            }
            return { key: field.apiName + '::' + r.subtype, subtype: r.subtype, qty: r.qty,
                     unitWeight: w, rowWeight: this._sqgRound(w * q, 5) };
        });
        const totals = this._sqgTotals(field.apiName);
        field.totalWeight = totals.totalWeight;
        field.totalQuantity = totals.totalQuantity;

        // ---- mobile bottom-sheet props (used only by the phone layout) ----
        // sqgSheetOpen is user state; never reset it here, only default it once.
        if (field.sqgSheetOpen === undefined) field.sqgSheetOpen = false;
        const colM = String(field.apiName || '').match(/^c(\d+)_/);
        field.sqgSheetTitle = (colM ? 'Column ' + colM[1] : 'Sub-types') +
            (selectedType ? ' \u00B7 ' + selectedType : '');
        field.sqgLaunchLabel = rows.length === 0
            ? 'Select sub-types'
            : rows.length + ' selected \u00B7 Wt ' + (field.totalWeight || 0);
    }

    _sqgTotals(fieldApi) {
        const ds = this._sqgDataset();
        let tw = 0, tq = 0;
        this._sqgGetSelection(fieldApi).forEach(r => {
            const q = Number(r.qty) || 0;
            const w = Number(ds.weightMap[r.subtype]) || 0;
            tw += w * q; tq += q;
        });
        return { totalWeight: this._sqgRound(tw, 5), totalQuantity: this._sqgRound(tq, 5) };
    }

    // push totals into the existing weight + quantity fields (the whole trick)
    _sqgWriteTargets(field) {
        const t = this._sqgTargets(field);
        const totals = this._sqgTotals(field.apiName);
        this._lastValues[t.weightApi] = totals.totalWeight;
        this._lastValues[t.qtyApi] = totals.totalQuantity;
        this.accordionSections.forEach(sec => sec.fields.forEach(f => {
            if (f.apiName === t.weightApi) { f.value = totals.totalWeight; this._updateFieldUI(f); }
            if (f.apiName === t.qtyApi)    { f.value = totals.totalQuantity; this._updateFieldUI(f); }
        }));
    }

    _sqgFindField(fieldApi) {
        let out = null;
        this.accordionSections.some(sec => sec.fields.some(f => {
            if (f.apiName === fieldApi) { out = f; return true; } return false;
        }));
        return out;
    }

    _sqgRefresh(fieldApi) {
        const field = this._sqgFindField(fieldApi);
        if (!field) return;
        this._sqgEnrich(field);
        this._sqgWriteTargets(field);
        this.accordionSections = this.accordionSections.map(sec => {
            this._updateSectionUI(sec);
            return { ...sec, fields: [...sec.fields] };
        });
    }

    // ★ multiselect tick/untick (lightning-dual-listbox -> event.detail.value = array)
    handleSubtypeToggle(event) {
        const fieldApi = event.currentTarget.dataset.name;
        const selected = (event.detail && Array.isArray(event.detail.value)) ? event.detail.value : [];
        const prev = this._sqgGetSelection(fieldApi);
        const prevBySub = {};
        prev.forEach(r => { prevBySub[r.subtype] = r.qty; });
        const rows = selected.map(sub => ({ subtype: sub, qty: prevBySub[sub] != null ? prevBySub[sub] : null }));
        this._sqgSaveSelection(fieldApi, rows);
        this._sqgRefresh(fieldApi);
    }

    // ★ per-subtype quantity change
    handleSubtypeQtyChange(event) {
        const fieldApi = event.currentTarget.dataset.name;
        const subtype  = event.currentTarget.dataset.subtype;
        const val      = event.target.value;
        const rows = this._sqgGetSelection(fieldApi);
        const row = rows.find(r => r.subtype === subtype);
        if (row) row.qty = (val === '' ? null : Number(val));
        this._sqgSaveSelection(fieldApi, rows);

        // targeted update: mutate this widget's rows + totals in place,
        // write targets - do NOT rebuild sections (typing must not reset the UI)
        const field = this._sqgFindField(fieldApi);
        if (field) {
            const ds = this._sqgDataset();
            const qr = (field.qtyRows || []).find(p => p.subtype === subtype);
            if (qr) {
                qr.qty = row ? row.qty : null;
                qr.rowWeight = this._sqgRound((Number(ds.weightMap[subtype]) || 0) * (Number(qr.qty) || 0), 5);
            }
            const totals = this._sqgTotals(fieldApi);
            field.totalWeight = totals.totalWeight;
            field.totalQuantity = totals.totalQuantity;
            this._sqgWriteTargets(field);
            this.accordionSections = [...this.accordionSections];
        }
    }

    _sqgRound(n, dp = 3) {
        const f = Math.pow(10, dp);
        return Math.round((Number(n) || 0) * f) / f;
    }
 
    handleSectionToggle(event) {
        try {
            const sectionId = event.currentTarget.dataset.id;
            const idx = this.accordionSections.findIndex(s => s.id === sectionId);
            if (idx !== -1) {
                this.accordionSections[idx].isExpanded = !this.accordionSections[idx].isExpanded;
                this._updateSectionUI(this.accordionSections[idx]);
                this.accordionSections[idx] = { ...this.accordionSections[idx] };
                this.accordionSections = [...this.accordionSections];
            }
        } catch (e) {
            console.error('handleSectionToggle error:', e);
        }
    }
    handleSubSectionToggle(event) {
        try {
            const apiName = event.currentTarget.dataset.name;
            const sectionId = event.currentTarget.dataset.section;
 
            let clonedSections = JSON.parse(JSON.stringify(this.accordionSections));
            const sec = clonedSections.find(s => s.id === sectionId);
            
            if (sec) {
                const headerField = sec.fields.find(f => f.apiName === apiName);
                if (headerField) {
                    // 1. Toggle the header state
                    headerField.isSubSectionExpanded = !headerField.isSubSectionExpanded;
                    
                    // 2. Toggle the visual UI state for all nested children
                    sec.fields.forEach(child => {
                        if (child.parentSubSectionApi === apiName) {
                            child.isCollapsedUI = !headerField.isSubSectionExpanded;
                        }
                    });
 
                    // 3. Update the UI styles and refresh the HTML's array reference!
                    clonedSections.forEach(s => {
                        s.fields.forEach(f => this._updateFieldUI(f));
                        this._updateSectionUI(s); // 👉 CRITICAL FIX: Forces HTML to recognize the CSS changes
                    });
 
                    this.accordionSections = clonedSections;
                }
            }
        } catch (e) {
            console.error('handleSubSectionToggle error:', e);
        }
    }
 
    // =========================================================
    // 👉 PERFORMANCE: collect every api name that some OTHER field depends on
    // (controllingField / disableControllingField / column-repeater counts).
    // A plain number/text field NOT in this set can skip the whole re-render on
    // change and just store its value - Reetabrata (8th July)
    // =========================================================
    _buildStructuralApiSet() {
        try {
            const set = new Set();
            const addTokens = (raw) => {
                if (!raw) return;
                String(raw).split(',').forEach(t => {
                    let s = t.trim();
                    if (s.startsWith('!')) s = s.substring(1);
                    if (s) set.add(s);
                });
            };
            this.accordionSections.forEach(sec => {
                addTokens(sec.controllingField);
                sec.fields.forEach(f => {
                    addTokens(f.controllingField);
                    addTokens(f.disableControllingField);
                    if (f.columnCountApi) set.add(f.columnCountApi);
                    if (f.repeaterApi) set.add(f.repeaterApi);
                });
            });
            this._structuralApis = set;
        } catch (e) {
            console.error('_buildStructuralApiSet error:', e);
            this._structuralApis = new Set();
        }
    }
 
    handleFieldChange(event) {
        try {
            const fieldApiName = event.currentTarget.dataset.name;
            let newValue = this._extractValue(event);
 
            // ── Pre-fill OVR fields: when a segment's Override toggle is switched ON,
            //    copy the base Length/Thickness into the OVR fields so they aren't blank - Reetabrata (8th July 2026)
            if ((newValue === true || newValue === 'true') && fieldApiName) {
                const om = fieldApiName.match(/^(.*)lm_override_(mid\d+|bot\d+)$/);
                if (om) {
                    const pfx = om[1];   // grid prefix, e.g. 'r1_'
                    const seg = om[2];   // 'mid4' or 'bot9'
                    ['length', 'thickness'].forEach(attr => {
                        const baseApi = `${pfx}lm_${seg}_${attr}`;
                        const ovrApi  = `${pfx}lm_ovr_${seg}_${attr}`;
                        let baseVal = null;
                        this.accordionSections.some(sec => sec.fields.some(f => {
                            if (f.apiName === baseApi) { baseVal = f.value; return true; }
                            return false;
                        }));
                        if (baseVal !== null && baseVal !== '' && baseVal !== undefined) {
                            this.accordionSections.forEach(sec => sec.fields.forEach(f => {
                                if (f.apiName === ovrApi &&
                                    (f.value === '' || f.value === null || f.value === undefined)) {
                                    f.value = baseVal;
                                    f.userCleared = false;
                                    this._lastValues[ovrApi] = baseVal;
                                    this._updateFieldUI(f);
                                }
                            }));
                        }
                    });
                }
            }
            // for transmission tower consider line items only for current checked modal which is on the screen, if I first added value for 
            // for firm then moving to price variation then only price variation should be considered. firm value/line items should not be considered
            // and vice versa. so when we are changing price basis with gsm checked then this block marked it false before change so that never considered on evaluation
            if (fieldApiName === 'pvt_price_basics' || fieldApiName === 'pvs_price_model') {
                const staleCheckboxApis = fieldApiName === 'pvt_price_basics'
                    ? ['pvt_pv_610_gsm', 'pvt_pv_900_gsm', 'pvt_pv_1000_gsm',
                    'pvt_firm_610_gsm', 'pvt_firm_900_gsm', 'pvt_firm_1000_gsm']
                    : ['pvs_pv_610_gsm', 'pvs_pv_900_gsm', 'pvs_pv_1000_gsm',
                    'pvs_firm_610_gsm', 'pvs_firm_900_gsm', 'pvs_firm_1000_gsm'];

                staleCheckboxApis.forEach(api => {
                    this.accordionSections.forEach(sec => {
                        const f = sec.fields.find(x => x.apiName === api);
                        if (f && f.value === true) {
                            f.value = false;
                            f.userCleared = false;
                            this._updateFieldUI(f);
                        }
                    });
                    this._lastValues[api] = false;
                });
            }


            //Reetabrata (8th July 2026)
 
 
            // ── SEGMENT ABOVE 5 count guard + regen (gated) ───Reetabrata (7th July)───────
        // In the grid the field is r1_lm_no_of_segment, r2_..., so match by suffix.
        // Validate on a DEBOUNCE so typing "12" isn't rejected the instant "1" is seen. - Reetabrata (8th July)
if (this._modalConfig && this._modalConfig.dynamicSegments &&
    fieldApiName && fieldApiName.endsWith('lm_no_of_segment')) {
 
    const rawSeg = newValue;
    const segEl = event.target;
    const segApi = fieldApiName;
 
    clearTimeout(this._segCountTimer);
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._segCountTimer = setTimeout(() => {
        const check = validateSegmentCount(rawSeg);
 
        if (check.block) {                          // 1-5 rejected (only after the user pauses typing)
            this.dispatchEvent(new ShowToastEvent({
                title: 'Use the 5-Segment Estimator',
                message: check.message,
                variant: 'warning'
            }));
            if (segEl) segEl.value = '';
            this.accordionSections.forEach(sec => {
                const f = sec.fields.find(x => x.apiName === segApi);
                if (f) { f.value = ''; f.userCleared = true; this._updateFieldUI(f); }
            });
            this._lastValues[segApi] = '';
            this.accordionSections.forEach(sec => this._evaluateFieldVisibility(sec.fields));
            this._evaluateSectionVisibility();
            this.accordionSections = [...this.accordionSections];
        } else if (check.value !== rawSeg && check.message) {  // capped at 15
            this.dispatchEvent(new ShowToastEvent({
                title: 'Maximum Limit Reached',
                message: check.message,
                variant: 'warning'
            }));
            if (segEl) segEl.value = check.value;
            this.accordionSections.forEach(sec => {
                const f = sec.fields.find(x => x.apiName === segApi);
                if (f) { f.value = check.value; this._updateFieldUI(f); }
            });
            this._lastValues[segApi] = check.value;
            this.accordionSections = [...this.accordionSections];
        }
    }, 900);
    // Let the typed value flow through normally below so the user can keep typing (1 -> 12).
    // NO manual regeneration - the matrix-accordion-repeater shows the
    // matching lm_segment_{N} section on its own, just like 1-5 does.
}
        // ───────────────────────Reetabrata (7th July)──────────────────────────────────
 
           /* let maxAllowedForThisField = null;
            this.accordionSections.forEach(sec => sec.fields.forEach(f => {
                if (f.repeaterApi === fieldApiName && f.repeaterMaxCols) {
                    maxAllowedForThisField = f.repeaterMaxCols;
                }
            }));
            if (maxAllowedForThisField && newValue > maxAllowedForThisField) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Maximum Limit Reached',
                    message: `You can only generate up to ${maxAllowedForThisField} segments here.`,
                    variant: 'warning'
                }));
                newValue = maxAllowedForThisField;
                event.target.value = newValue;
            }*/
 
            let wasUpdated = false;
 
            // ── PERFORMANCE: find the changed field WITHOUT cloning the whole modal ── Reetabrata (8th July)
            // The same apiName can exist in several sections (e.g. lm_mid2_length lives in every
            // lm_segment_N blueprint). Collect ALL matches and prefer a VISIBLE one, otherwise the
            // value would be written into a hidden section and lost on save. - Reetabrata (9th July 2026)
            const matchedFields = [];
            let changedField = null;
            for (const sec of this.accordionSections) {
                for (const x of sec.fields) {
                    if (x.apiName === fieldApiName) {
                        matchedFields.push(x);
                        if (changedField === null && sec.isVisible !== false && x.isVisible !== false) {
                            changedField = x;
                        }
                    }
                }
            }
            if (changedField === null && matchedFields.length) changedField = matchedFields[0];
            if (!changedField) return;
 
            const isDiscreteField = ['picklist', 'checkbox', 'toggle', 'date'].includes(changedField.type);
            // structural = something else depends on this field (a count / controller). Those still need a light refresh.
            const isStructural = this._structuralApis ? this._structuralApis.has(fieldApiName) : true;
 
            // ── FAST PATH: plain number / text ── just store the value; NO clone, NO render, NO spinner, NO math.
            // The typed value is already in the input box; the CALCULATE / APPLY button runs the math.
            if (!isDiscreteField && !isStructural) {
                // keep every duplicate in sync so the visible one always holds the value - Reetabrata (9th July 2026)
                matchedFields.forEach(mf => { mf.value = newValue; });
                changedField.value = newValue;
                // if the user emptied the field, treat it as cleared so the default doesn't repopulate - Reetabrata (8th July)
                changedField.userCleared = (newValue === '' || newValue === null || newValue === undefined);
                if (changedField.formula) {
                    changedField.isManualOverride = (newValue !== '' && newValue !== null);
                }
                this._lastValues[fieldApiName] = newValue;
                this._lastValues[`${fieldApiName}__cleared`] = changedField.userCleared;
                return;
            }
 
            // 🌟 1. DEEP CLONE FIX: Break the LWC Proxy lock
            // (deep clone removed - stringifying ~9000 fields froze the tab; mutate the real array in place) - Reetabrata (8th July)
            let clonedSections = this.accordionSections;
 
            clonedSections.forEach(sec => {
                const field = sec.fields.find(f => f.apiName === fieldApiName);
                if (field) {
                    field.value = newValue;
                    // if the user emptied the field, treat it as cleared so the default doesn't repopulate - Reetabrata (8th July)
                    field.userCleared = (newValue === '' || newValue === null || newValue === undefined);
                    if (field.formula) {
                        field.isManualOverride = (newValue !== '' && newValue !== null);
                    }
 
                    // UNIVERSAL DEPENDENT PICKLIST LOGIC
                    sec.fields.filter(f => f.dependentOptionsMap).forEach(dep => {
                        let ctrlNames = dep.controllingFields && Array.isArray(dep.controllingFields)
                            ? dep.controllingFields
                            : (dep.controllingField ? dep.controllingField.split(',').map(s => s.trim()) : []);
 
                        if (ctrlNames.length === 0) return;
                        if (!ctrlNames.some(ctrl => fieldApiName.endsWith(ctrl))) return;
                        if (dep.columnCountIndex && field.columnCountIndex && dep.columnCountIndex !== field.columnCountIndex) return;
 
                        let currentValues = ctrlNames.map(ctrlName => {
                            let ctrlField = sec.fields.find(x => x.apiName.endsWith(ctrlName) && x.columnCountIndex === dep.columnCountIndex);
                            return ctrlField && ctrlField.value ? String(ctrlField.value).trim() : '';
                        });
 
                        let hasBlank = currentValues.some(v => v === '');
                        let mapKey = currentValues.join('|');
 
                        if (hasBlank) {
                            dep.options = [];
                        } else if (dep.dependentOptionsMap[mapKey]) {
                            dep.options = dep.dependentOptionsMap[mapKey].map(opt => ({ label: opt, value: opt }));
                        } else {
                            dep.options = dep.masterOptions;
                        }
 
                        // THE UX FIX: Only clear the box if the old value is no longer valid!
                        let isValid = dep.options.some(opt => opt.value === dep.value);
                        if (!isValid) {
                            dep.value = '';
                        }
 
                        this._updateFieldUI(dep);
                    });
 
                    // Core subtype_qty_grid: re-enrich any widget in this section whose
                    // controlling field just changed (additive; no-op for other types)
                    sec.fields.filter(w => w.isSubtypeQtyGrid).forEach(w => this._updateFieldUI(w));
 
                    this._updateFieldUI(field);
                    this._updateSectionUI(sec);
                    wasUpdated = true;
                }
            });
 
            if (!wasUpdated) return;
 
            // 🌟 2. REASSIGN CLONED ARRAY TO TRIGGER UI RENDER
            // (shallow copy triggers re-render without the costly deep clone) - Reetabrata (8th July)
            this.accordionSections = [...clonedSections];
 
            clearTimeout(this._typingTimer);
            this._typingTimer = setTimeout(() => {
                setTimeout(() => {
                    // ── PERFORMANCE: defer the heavy formula engine ── Reetabrata (8th July)
                    // Discrete/dependency fields (picklist / checkbox / toggle / date) auto-calculate.
                    // Number / text fields only refresh the cheap UI while typing; the heavy
                    // weight/price math waits for the CALCULATE (or APPLY) button.
                    // (isDiscreteField was already computed above, before the deep clone)
 
                    //check composition validation when composition value changed
                    const comAPI = TELECOM_COMPOSITION_APIS;
 
                    if (isDiscreteField) {
                        // dependency picklists / discrete fields → full recalculation now
                        // 👉 turn the spinner on, let it PAINT (rAF + setTimeout), THEN run the blocking calc - Reetabrata (8th July)
                        this.isLoading = true;
                        requestAnimationFrame(() => {
                            // eslint-disable-next-line @lwc/lwc/no-async-operation
                            setTimeout(() => {
                                try {
                                    this._calculateNow();
                                    if (comAPI.includes(fieldApiName)) {
                                        this._validateTelecomTowerComposition();
                                    }
                                } catch (mathError) {
                                    console.error('Math Engine Error:', mathError);
                                } finally {
                                    this.isLoading = false;
                                }
                                // Fetch PV data whenever month, year, or material type changes
                                this._checkAndFetchPriceVariation();
                            }, 0);
                        });
                    } else {
                        // number / text → cheap UI reactions only (heavy math waits for the button)
                        try {
                            this.accordionSections.forEach(sec => {
                                this._evaluateFieldVisibility(sec.fields);
                                this._evaluateDynamicDisable(sec.fields);
                            });
                            this._evaluateSectionVisibility();
                            this._evaluateDynamicColSpans();
                            ////evaluate section label after field change
                            this._evaluateSectionLabels();
 
                            this.accordionSections = this.accordionSections.map(sec => {
                                sec.fields.forEach(f => this._updateFieldUI(f));
                                this._updateSectionUI(sec);
                                return { ...sec };
                            });
 
                            if (comAPI.includes(fieldApiName)) {
                                this._validateTelecomTowerComposition();
                            }
                        } catch (mathError) {
                            console.error('Math Engine Error:', mathError);
                        }
                        // Fetch PV data whenever month, year, or material type changes
                        this._checkAndFetchPriceVariation();
                    }
                }, 50);
            }, 200);
        } catch (e) {
            console.error('handleFieldChange error:', e);
            this.isLoading = false;
        }
    }
 
    _extractValue(event) {
        if (event.target.type === 'checkbox' || event.target.type === 'toggle') {
            return event.target.checked;
        }
        let val = event.detail?.value ?? event.target?.value ?? '';
       // if (event.target.type === 'number' && val !== '') return Number(val);
        return val;
    }
 
    // =========================================================
    // DYNAMIC ALIGNMENT ENGINE 
    // =========================================================
    _evaluateDynamicColSpans() {
        const counts = {};
 
        this.accordionSections.forEach(sec => sec.fields.forEach(f => {
            if (f.value !== '' && f.value !== null && f.value !== undefined && !isNaN(f.value)) {
                counts[f.apiName] = Number(f.value);
            }
        }));
 
        this.accordionSections.forEach(sec => {
            sec.fields.forEach(f => {
                if (f.repeaterApi) {
                    let userCount = counts[f.repeaterApi] || 0;
                    const maxAllowed = f.repeaterMaxCols || 10;
 
                    if (userCount > maxAllowed) userCount = maxAllowed;
                    if (userCount < 1) userCount = 1;
 
                    let lblSpan = 12;
                    let inpSpan = 12;
 
                    if (userCount === 1) { lblSpan = 6; inpSpan = 6; }
                    else if (userCount === 2) { lblSpan = 4; inpSpan = 4; }
                    else if (userCount === 3) { lblSpan = 3; inpSpan = 3; }
                    else if (userCount === 4) { lblSpan = 4; inpSpan = 2; }
                    else if (userCount === 5) { lblSpan = 2; inpSpan = 2; }
                    else {
                        inpSpan = 1;
                        lblSpan = 12 - (userCount * inpSpan);
                        if (lblSpan < 1) lblSpan = 1;
                    }
 
                    if (f.isColRepeaterLabel) {
                        f.colSpan = lblSpan;
                    } else if (f.isColRepeaterInput) {
                        f.colSpan = inpSpan;
                    }
 
                    this._updateFieldUI(f);
                }
            });
        });
    }
 
    // =========================================================
    // 👉 NEW & SAFE: DYNAMIC DISABLE / READONLY ENGINE
    // =========================================================
    // ═══════════════════════════════════════════════════════════════════════
    // PERF - Deepanjan (4th September 2026)
    // _evaluateFieldVisibility and _evaluateDynamicDisable resolved every parent
    // with `fields.find(...)` and, on a miss, a `find` over EVERY section. In a
    // column-repeater modal (Octagonal / Custom Lighting Pole builds ~1,800
    // fields) that is a full linear scan per field - millions of property reads,
    // every one of them through the @track proxy. This builds one
    // apiName -> field index per call instead.
    //
    // Resolution order is IDENTICAL to the scans it replaces: first match inside
    // `fields`, otherwise first match walking this.accordionSections in order.
    // It hands back the SAME object references, so a value written to a parent
    // earlier in the same pass is read back exactly as before. The global index
    // is built lazily - only when a local miss actually happens.
    // ═══════════════════════════════════════════════════════════════════════
    _fieldResolver(fields) {
        const local = new Map();
        for (const f of fields) {
            if (!local.has(f.apiName)) local.set(f.apiName, f);
        }
        let global = null;
        return (apiName) => {
            const hit = local.get(apiName);
            if (hit) return hit;
            if (global === null) {
                global = new Map();
                for (const sec of this.accordionSections) {
                    for (const f of sec.fields) {
                        if (!global.has(f.apiName)) global.set(f.apiName, f);
                    }
                }
            }
            return global.get(apiName);
        };
    }

    _evaluateDynamicDisable(fields) {
        try {
            if (this.isReadOnly) {
                fields.forEach(field => {
                    field.readOnly = true;
                    field.baseReadOnly = true;
                    this._updateFieldUI(field);
                });
                return;
            }
 
            const resolve = this._fieldResolver(fields); // PERF - Deepanjan (4th September 2026)
            fields.forEach(field => {
                if (!field.disableControllingField) {
                    field.readOnly = field.baseReadOnly;
                    this._updateFieldUI(field);
                    return;
                }
 
                const parentApiNames = field.disableControllingField.includes(',')
                    ? field.disableControllingField.split(',').map(s => s.trim())
                    : [field.disableControllingField];
 
                let isEnabled = false;
 
                for (const rawApiName of parentApiNames) {
                    const isNegated = rawApiName.startsWith('!');
                    const apiName = isNegated ? rawApiName.substring(1) : rawApiName;
 
                    // same first-match order as the find() scans this replaces - Deepanjan (4th Sep 2026)
                    let parent = resolve(apiName);
 
                    if (parent) {
                        const parentHasValue = parent.type === 'checkbox'
                            ? parent.value === true
                            : parent.value !== '' && parent.value !== null && parent.value !== undefined;
 
                        if (isNegated && !parentHasValue) {
                            isEnabled = true;
                        }
                        // 👉 STRICT CHECK (Uses isEnabled)
                        else if (!isNegated && parentHasValue) {
                            const controllingValues = field.disableControllingValues || ['*'];
 
                            let rawParentValue = '';
                            if (parent.type === 'checkbox') {
                                rawParentValue = String(parent.value || false);
                            } else {
                                rawParentValue = (parent.value === null || parent.value === undefined) ? '' : String(parent.value);
                            }
 
                            const safeParentValue = rawParentValue.toLowerCase();
                            const safeControllingValues = controllingValues.map(v => String(v).toLowerCase());
 
                            const matchedNum = safeControllingValues.some(cv => {
                                if (cv.startsWith('>=')) {
                                    const threshold = Number(cv.substring(2));
                                    const val = Number(parent.value);
                                    return !isNaN(val) && val >= threshold;
                                }
                                return false;
                            });
 
                            const matched = safeControllingValues.includes('*')
                                ? parentHasValue
                                : (matchedNum || safeControllingValues.includes(safeParentValue));
 
                            if (matched) {
                                isEnabled = true; // 👉 Correct variable used here!
                                break;
                            }
                        }
                    }
                }
 
                field.readOnly = field.baseReadOnly || !isEnabled;
                this._updateFieldUI(field);
            });
        } catch (e) {
            console.error('_evaluateDynamicDisable error:', e);
        }
    }
 
    // =========================================================
    // ★ CHANGE 2 of 5 — BUG 1 (KIT picklist options empty on first open) ★
    // Reetabrata (14th July 2026)  — NEW METHOD (purely additive)
    // DEPENDENT PICKLIST RE-RESOLUTION
    // The onload "WAKE UP" block runs before _evaluateAllFormulas(), so formula-driven
    // controlling fields (e.g. no_of_segment_select = Number(r1_lm_no_of_segment)||...)
    // are still empty when KIT picklists (CABLE TYPE / TYPE OF WINCH / TYPE OF POWER
    // TOOL) try to resolve their options -> options come up empty until Apply+reopen.
    // This pass re-runs the SAME resolution logic AFTER formulas are computed, so the
    // controlling values are present. It is idempotent and only fills options; it never
    // clears a user's chosen value.
    // =========================================================
    _resolveDependentOptionsOnLoad() { // Reetabrata (14th July 2026)
        this.accordionSections.forEach(sec => {
            sec.fields.filter(f => f.dependentOptionsMap).forEach(dep => {
                let ctrlNames = [];
                if (Array.isArray(dep.controllingFields)) ctrlNames = dep.controllingFields;
                else if (Array.isArray(dep.controllingField)) ctrlNames = dep.controllingField;
                else if (typeof dep.controllingFields === 'string') ctrlNames = dep.controllingFields.split(',').map(s => s.trim());
                else if (typeof dep.controllingField === 'string') ctrlNames = dep.controllingField.split(',').map(s => s.trim());

                if (ctrlNames.length === 0) return;

                let currentValues = ctrlNames.map(ctrlName => {
                    let ctrlField = sec.fields.find(x => x.apiName.endsWith(ctrlName) && x.columnCountIndex === dep.columnCountIndex);
                    return ctrlField && ctrlField.value ? String(ctrlField.value).trim() : '';
                });

                let possibleKeys = [];
                let tempVals = [];
                for (let val of currentValues) {
                    if (val !== '') {
                        tempVals.push(val);
                        possibleKeys.unshift(tempVals.join('|'));
                    } else {
                        break;
                    }
                }

                let matchedKey = possibleKeys.find(key => dep.dependentOptionsMap[key]);
                let fullyFilled = currentValues.every(v => v !== '');

                if (!dep.masterOptions) dep.masterOptions = dep.options ? [...dep.options] : [];

                if (matchedKey) {
                    let mapVal = dep.dependentOptionsMap[matchedKey];
                    if (mapVal.length > 0 && typeof mapVal[0] === 'string') {
                        dep.options = mapVal.map(opt => ({ label: opt, value: opt }));
                    } else {
                        dep.options = mapVal;
                    }
                } else if (fullyFilled) {
                    dep.options = dep.masterOptions;
                } else {
                    dep.options = [];
                }
            });
        });
    }
 
    // =========================================================
    // VISIBILITY ENGINES 
    // =========================================================
    _evaluateSectionVisibility() {
        try {
            const allFieldValues = {};
            this.accordionSections.forEach(sec => {
                sec.fields.forEach(f => { allFieldValues[f.apiName] = f.value; });
            });
 
            this.accordionSections.forEach(sec => {
                // isVisible:false (-> forceHidden) means "never draw this section in the UI".
                // It must NOT mean "ignore controllingField": a forceHidden section still has to
                // know whether it applies, otherwise every variant of a mutually-exclusive group
                // (e.g. the 12 PV/FIRM price models) looks active at once and each emits a line.
                // So we always evaluate controllingField into sec.isApplicable below, and only
                // then force the UI flag off. Reetabrata (15th July 2026)
                if (!sec.controllingField) {
                    sec.isApplicable = true;
                    sec.isVisible = !sec.forceHidden;
                    return;
                }
 
                const parentApiNames = sec.controllingField.includes(',')
                    ? sec.controllingField.split(',').map(s => s.trim())
                    : [sec.controllingField];
 
                let isVisible = false;
 
                // Adding context to handle evaluation based on controlling operator - rajeev 17-05-2026
                const operator = sec.controllingOperator || 'OR';
                let matchCount = 0;
 
                for (const apiName of parentApiNames) {
                    const parentValue = allFieldValues[apiName];
                    const parentIsEmpty = parentValue === '' || parentValue === null ||
                        parentValue === undefined || parentValue === false;
 
                    if (!parentIsEmpty) {
                        const normalized = typeof parentValue === 'boolean' ? String(parentValue) : String(parentValue);
                        const controllingValues = sec.controllingValues || [];
                        const safeControllingValues = controllingValues.map(String);
 
                        const matchedNum = safeControllingValues.some(cv => {
                            if (cv.startsWith('>=')) {
                                const threshold = Number(cv.substring(2));
                                const val = Number(parentValue);
                                return !isNaN(val) && val >= threshold;
                            }
                            return false;
                        });
 
                        if (matchedNum || safeControllingValues.includes('*') || safeControllingValues.includes(normalized)) {
                            //isVisible = true;
                            //break;
 
                            matchCount++;
                            if (operator === 'OR') {
                                isVisible = true;
                                break;    // OR: first match is enough, stop immediately
                            }
                        }
                    }
                }
 
                // AND: every field in the list must have matched
                if (operator === 'AND') {
                    isVisible = matchCount === parentApiNames.length;
                }
 
                // Reetabrata (15th July 2026): isApplicable = the controllingField verdict.
                // isVisible = that verdict AND the section is allowed on screen.
                sec.isApplicable = isVisible;
                sec.isVisible = isVisible && !sec.forceHidden;
            });
        } catch (e) {
            console.error('_evaluateSectionVisibility error:', e);
        }
    }
 
    _evaluateFieldVisibility(fields) {
        try {
            const resolve = this._fieldResolver(fields); // PERF - Deepanjan (4th September 2026)
            fields.forEach(field => {
                // 👉 isVisible:false on a sub-section hard-hides its header + children - Reetabrata (8th July 2026)
                if (field.forceHidden) { field.isVisible = false; return; }
                if (field.columnCountApi) {
                    // same first-match order as the find() scans this replaces - Deepanjan (4th Sep 2026)
                    let countParent = resolve(field.columnCountApi);
                    const currentCount = countParent ? (Number(countParent.value) || 0) : 0;
                    if (currentCount < field.columnCountIndex) {
                        field.isVisible = false;
                        if (!field.formula) field.value = (!field.userCleared && field.defaultValue !== '' && field.defaultValue != null) ? field.defaultValue : (field.type === 'checkbox' ? false : '');
                        return;
                    }
                }
 
                if (!field.controllingField) {
                    field.isVisible = true;
                    this._restoreDefaultIfEmpty(field);
                    return;
                }
 
                const parentApiNames = field.controllingField.includes(',')
                    ? field.controllingField.split(',').map(s => s.trim())
                    : [field.controllingField];
 
                let isVisible = false;
                let forceHide = false;
 
                for (const rawApiName of parentApiNames) {
                    const isNegated = rawApiName.startsWith('!');
                    const apiName = isNegated ? rawApiName.substring(1) : rawApiName;
 
                    // same first-match order as the find() scans this replaces - Deepanjan (4th Sep 2026)
                    let parent = resolve(apiName);
 
                    if (parent) {
                        const parentHasValue = parent.type === 'checkbox'
                            ? parent.value === true
                            : parent.value !== '' && parent.value !== null && parent.value !== undefined;
 
                        if (isNegated && parentHasValue) {
                            forceHide = true;
                        }
                        // 👉 THE VISIBILITY BYPASS FOR SPACERS (Uses isVisible)
                        else if (!isNegated && (parentHasValue || field.type === 'header')) {
                            const controllingValues = field.controllingValues || ['*'];
 
                            let rawParentValue = '';
                            if (parent.type === 'checkbox') {
                                rawParentValue = String(parent.value || false);
                            } else {
                                rawParentValue = (parent.value === null || parent.value === undefined) ? '' : String(parent.value);
                            }
 
                            const safeParentValue = rawParentValue.toLowerCase();
                            const safeControllingValues = controllingValues.map(v => String(v).toLowerCase());
 
                            const matchedNum = safeControllingValues.some(cv => {
                                if (cv.startsWith('>=')) {
                                    const threshold = Number(cv.substring(2));
                                    const val = Number(parent.value);
                                    return !isNaN(val) && val >= threshold;
                                }
                                return false;
                            });
 
                            const matched = safeControllingValues.includes('*')
                                ? parentHasValue
                                : (matchedNum || safeControllingValues.includes(safeParentValue));
 
                            if (matched) {
                                isVisible = true; // 👉 Correct variable used here!
                            }
                        }
                    }
                }
 
                field.isVisible = forceHide ? false : isVisible;
 
                if (!field.isVisible) {
                    // CROSS PRODUCT — Deepanjan (10th September 2026)
                    const __saved = this._lastValues[field.apiName];
                    const __hasSaved = __saved !== undefined && __saved !== null && __saved !== '';
                    if (!field.formula && !__hasSaved) {
                        field.value = (!field.userCleared && field.defaultValue !== '' && field.defaultValue !== null && field.defaultValue !== undefined)
                            ? field.defaultValue
                            : (field.type === 'checkbox' ? false : '');
                    }
                } else {
                    this._restoreDefaultIfEmpty(field);
                }
            });
        } catch (e) {
            console.error('_evaluateFieldVisibility error:', e);
        }
    }
 
    _restoreDefaultIfEmpty(field) {
        if (!field.userCleared &&
            (field.value === '' || field.value === null || field.value === undefined) &&
            (field.defaultValue !== '' && field.defaultValue !== null && field.defaultValue !== undefined)) {
            field.value = field.defaultValue;
        }
    }
 
    // =========================================================
    // THE GLOBAL MATH ENGINE
    // =========================================================
    _evaluateAllFormulas() {
        try {
            const rawMap = {};
            const valMap = {};
            const allFields = [];
 
            // PERF: these debug logs stringified the entire modal (~9000 fields) and froze the tab - disabled - Reetabrata (8th July)
            // console.log('acc ', JSON.stringify(this.accordionSections, null, 2));
            // console.log(
            //     'last values',
            //     JSON.stringify(this._lastValues, null, 2)
            // );
 
            this.accordionSections.forEach(sec => {
                // before returning for not visible section pre-register fields for default value.
                // commented visibility thing to check in transmission tower - rajeev 14 july 3pm

                //if (!sec.isVisible) {
                    //return;
                //}
 
                sec.fields.forEach(f => {
                    allFields.push(f);
                    let val = f.value;
 
 
                    rawMap[f.apiName] = (val !== null && val !== undefined) ? val : '';
                    const numVal = Number(val);
                    if (val === '' || val === null || val === undefined) {
                        valMap[f.apiName] = 0;
                    } else if (!isNaN(numVal)) {
                        valMap[f.apiName] = numVal;
                    } else {
                        // 👉 CRITICAL FIX: Wraps text strings in quotes so the math engine can read them!
                        valMap[f.apiName] = `'${val}'`;
                    }
                });
            });
 
            // =========================================================
            // 👉 THE BRIDGE: Inject saved values from OTHER folders!
            // =========================================================
            if (this._lastValues) {
                Object.keys(this._lastValues).forEach(key => {
                    // Only add it if it's not already in the dictionary (current modal values take priority)
                    if (valMap[key] === undefined) {
                        let savedVal = this._lastValues[key];
 
                        // 👉 ADD THIS: Extract prefix from picklist values before adding to valMap
                        if (typeof savedVal === 'string' && savedVal.includes('=')) {
                            const prefix = savedVal.split('=')[0].trim();
                            const numPrefix = Number(prefix);
                            savedVal = isNaN(numPrefix) ? prefix : numPrefix;
                        }
 
                        rawMap[key] = (savedVal !== null && savedVal !== undefined) ? savedVal : '';
                        const numSavedVal = Number(savedVal);
 
                        if (savedVal === '' || savedVal === null || savedVal === undefined || savedVal === false) {
                            valMap[key] = 0;
                        } else if (savedVal === true) {
                            valMap[key] = 'true'; // Keep booleans as strings for JS eval
                        } else if (!isNaN(numSavedVal)) {
                            valMap[key] = numSavedVal;
                        } else {
                            valMap[key] = `'${String(savedVal).replace(/'/g, "\\'")}'`; // Escape quotes safely
                        }
                    }
                });
            }
 
            // PERF: disabled - stringified large map every pass - Reetabrata (8th July)
            // console.log(
            //     '***line 1122 valMap',
            //     JSON.stringify(valMap, null, 2)
            // );
 
            // PERF: disabled - stringified large map every pass - Reetabrata (8th July)
            // console.log(
            //     'rawMap',
            //     JSON.stringify(rawMap, null, 2)
            // );
            // 👉 3. ADD THIS BLOCK: Inject Database Rates into the Math Engine!
            if (this.baseRates) {
                Object.keys(this.baseRates).forEach(key => {
                    valMap[key] = Number(this.baseRates[key]) || 0;
                });
            }
 
            // PERF: key sets are stable for the whole call (every field is pre-registered
            // above and the passes only overwrite existing keys, never add new ones), so
            // build them ONCE instead of per-field-per-pass. - Reetabrata (9th July 2026)
            const rawKeySet   = new Set(Object.keys(rawMap));
            const valKeySet   = new Set(Object.keys(valMap));
            // Keys that are not plain identifiers can't be found by the token scan;
            // they keep the original RegExp probe. In practice this list is empty.
            const oddRawKeys  = Object.keys(rawMap).filter(k => !_IDENT_RE.test(k));
            const oddValKeys  = Object.keys(valMap).filter(k => !_IDENT_RE.test(k));
            const tokenCache  = new Map();   // formula string -> its identifier tokens
 
            for (let pass = 0; pass < 3; pass++) {
                allFields.forEach(field => {
 
                    if (!field.formula || (field.isManualOverride && field.type !== 'header')) return;
 
                    // PERF: identical result to `Object.keys(rawMap).filter(k => \bk\b matches formula)`,
                    // computed by scanning the formula once instead of compiling one RegExp per key.
                    // - Reetabrata (9th July 2026)
                    let _fTokens = tokenCache.get(field.formula);
                    if (!_fTokens) {
                        _fTokens = field.formula.match(_TOKEN_RE) || [];
                        tokenCache.set(field.formula, _fTokens);
                    }
                    const parentApiNames = [];
                    const _seenParent = new Set();
                    for (const _t of _fTokens) {
                        if (_t === field.apiName || _seenParent.has(_t) || !rawKeySet.has(_t)) continue;
                        _seenParent.add(_t);
                        parentApiNames.push(_t);
                    }
                    for (const _k of oddRawKeys) {
                        if (_k !== field.apiName && !_seenParent.has(_k) && _reFor(_k).probe.test(field.formula)) {
                            _seenParent.add(_k);
                            parentApiNames.push(_k);
                        }
                    }
 
                    let newResult = '';
 
                    const anyParentHasValue = parentApiNames.some(key => {
                        const raw = rawMap[key];
                        return raw !== '' && raw !== null && raw !== undefined && String(raw).trim() !== '';
                    });
 
                    if (!anyParentHasValue && parentApiNames.length > 0) {
                        newResult = (field.defaultValue !== undefined && field.defaultValue !== null) ? field.defaultValue : '';
                    } else {
                        try {
                            const rowMatch = field.apiName.match(/^(r\d+)_/);
                            const rowPrefix = rowMatch ? rowMatch[1] : null;
 
                            let expr = field.formula;
 
                            if (rowPrefix) {
 
                                // Extract all NON-prefixed variables from formula
                                const tokens = expr.match(/\b[a-zA-Z_][a-zA-Z0-9_]*\b/g) || [];
 
                                tokens.forEach(token => {
 
                                    // Skip JS keywords / Math / numbers
                                    if (['Math', 'true', 'false'].includes(token)) return;
 
                                    // Skip already prefixed variables (r1_, r2_, etc.)
                                    if (/^r\d+_/.test(token)) return;
 
                                    const dynamicKey = rowPrefix + '_' + token;
 
                                    // Replace ONLY if such key exists
                                    if (valMap.hasOwnProperty(dynamicKey)) {
                                        // PERF: cached regex instead of a fresh compile per token. - Reetabrata (9th July 2026)
                                        expr = expr.replace(_reFor(token).word, dynamicKey);
                                    }
                                });
                            }
 
                            // PERF: the old code swept EVERY valMap key (thousands) and compiled two
                            // RegExps for each. Keys absent from `expr` can only ever produce a no-op
                            // replace, so scan `expr` once and substitute only the keys present, still
                            // in descending-length order. Same substitutions, same order, same result.
                            // - Reetabrata (9th July 2026)
                            const _exprTokens = expr.match(_TOKEN_RE) || [];
                            const _present = [];
                            const _seenSub = new Set();
                            for (const _t of _exprTokens) {
                                if (_seenSub.has(_t) || !valKeySet.has(_t)) continue;
                                _seenSub.add(_t);
                                _present.push(_t);
                            }
                            for (const _k of oddValKeys) {
                                if (!_seenSub.has(_k)) { _seenSub.add(_k); _present.push(_k); }
                            }
                            _present.sort((a, b) => b.length - a.length);
                            const _exprBefore = expr;
                            for (const key of _present) {
                                const _re = _reFor(key);
                                // If this key is used with a dot method like .startsWith(), wrap as string
                                if (_re.dot.test(expr)) {
                                    expr = expr.replace(_re.word, `'${rawMap[key]}'`);
                                } else {
                                    expr = expr.replace(_re.word, valMap[key]);
                                }
                            }
 
                            // CORRECTNESS GUARD: a text-valued key substitutes a quoted string
                            // (valMap[k] = `'<text>'`). If that text happens to contain another
                            // apiName as a whole word, the ORIGINAL full sweep would have gone on
                            // to substitute it, while the token scan above would not. That should
                            // never happen with real data, but if it does we replay the original
                            // algorithm verbatim so the result is guaranteed identical.
                            // - Reetabrata (9th July 2026)
                            let _leaked = false;
                            const _after = expr.match(_TOKEN_RE) || [];
                            for (const _t of _after) {
                                if (valKeySet.has(_t)) { _leaked = true; break; }
                            }
                            if (_leaked) {
                                expr = _exprBefore;
                                Object.keys(valMap)
                                    .sort((a, b) => b.length - a.length)
                                    .forEach(key => {
                                        const _re = _reFor(key);
                                        if (_re.dot.test(expr)) {
                                            expr = expr.replace(_re.word, `'${rawMap[key]}'`);
                                        } else {
                                            expr = expr.replace(_re.word, valMap[key]);
                                        }
                                    });
                            }
 
                            // 🟢 --- START OF DEBUG LOGS --- 🟢
                            // console.log(`\n========== EVALUATING: ${field.apiName} (Pass ${pass + 1}) ==========`); // PERF disabled - Reetabrata (8th July)
                            console.log(`📝 Original Formula: \n${field.formula}`);
                            console.log(`⚙️ Expression to Evaluate: \n${expr}`);
 
                            // 👉 Includes the 'Math' fix so Math.pow() works!
                            // PERF: cached compile, identical semantics. - Reetabrata (9th July 2026)
                            const result = _fnFor(expr)(Math);
 
                             console.log(`✅ Evaluated Result: ${result}`);
                            // 🟢 --- END OF DEBUG LOGS --- 🟢
 
                            if (typeof result === 'string' || typeof result === 'boolean') {
                                newResult = result;
                            } else if (typeof result === 'number' && !isNaN(result) && isFinite(result)) {
                                newResult = Math.round(result * 1000) / 1000;
                            } else {
                                newResult = '';
                            }
                        } catch (e) {
                            // 🔴 Log exact syntax errors if the formula breaks!
                            console.error(`❌ Math Engine Error on ${field.apiName}:`, e.message);
                            console.error(`⚠️ Failed Expression: \n${field.formula}`); // Helps see what broke
                            newResult = '';
                        }
                    }
 
                    if (field.value !== newResult) {
                        field.value = newResult;
                        rawMap[field.apiName] = newResult;
                        const numVal = Number(newResult);
                        valMap[field.apiName] = !isNaN(numVal) ? numVal : 0;
                    }
                });
            }
            this._calculateGridTotals();
 
        } catch (err) {
            console.error('Global Math Engine Error:', err);
        }
    }
 
    // =========================================================
    //  DICTIONARY LOOKUP ENGINE (Backwards Compatible!) //Abhishek saxena
    // =========================================================
   // =========================================================
    //  DICTIONARY LOOKUP ENGINE
    // =========================================================
    // =========================================================
    //  DICTIONARY LOOKUP ENGINE (Global Scope Fix)
    // =========================================================
    _evaluateLookups() {
        // 👉 THE ULTIMATE FIX: A global search helper that finds values anywhere in the modal or saved history
        const getSafeValue = (searchName, colIndex) => {
            if (!searchName) return '';
            
            // Allows matching exact names, or repeater prefixes (like c1_uom)
            const isMatch = (api) => api === searchName || api.endsWith(`_${searchName}`) || api.endsWith(searchName);
 
            console.log('isMatch function created for searchName:', isMatch.toString());
            console.log(`🔍 Searching for "${searchName}" in column index ${colIndex}...`);
 
            // 1. Search all active accordion sections globally
            for (const section of this.accordionSections) {
                let field = section.fields.find(x => isMatch(x.apiName) && (x.columnCountIndex === colIndex || !x.columnCountIndex));
                if (field && field.value !== '' && field.value !== null && field.value !== undefined) {
                    return String(field.value).trim();
                }
            }
            
            // 2. Fallback to _lastValues (for values saved in other separate modals/folders!)
            const savedKey = Object.keys(this._lastValues).find(key => isMatch(key));
            if (savedKey) {
                let saved = this._lastValues[savedKey];
                if (saved !== '' && saved !== null && saved !== undefined) {
                    return String(saved).trim();
                }
            }
            
            return '';
        };
 
        this.accordionSections.forEach(sec => {
            sec.fields.forEach(field => {
 
                if (field.weightMap || field.lookupWeight === true) {
 
                    let ctrlNames = Array.isArray(field.controllingFields)
                        ? field.controllingFields
                        : (field.controllingField ? field.controllingField.split(',').map(s => s.trim()) : []);
 
                        console.log('🎯 DEBUG: Controlling Fields for', field.apiName, 'are:', JSON.stringify(ctrlNames));
                    if (ctrlNames.length === 0) return;
 
                    // 👉 Fetch current values using the new global search
                    let currentValues = ctrlNames.map(ctrlName => getSafeValue(ctrlName, field.columnCountIndex));
                    console.log('🎯 DEBUG: Current Values for', field.apiName, 'are:', JSON.stringify(currentValues));
                    let engineeringValues = currentValues.slice(0, 4);
                    console.log('🎯 DEBUG: Engineering Values for', field.apiName, 'are:', JSON.stringify(engineeringValues));
 
                    if (engineeringValues.some(v => v === '')) {
                        field.value = 0;
                    } else {
                        let mapKey = engineeringValues.join('|');
 
                        console.log('🎯 DEBUG: Mapped Key Created is:', JSON.stringify(mapKey));
                        console.log('📋 DEBUG: Available weightMap is:', JSON.stringify(field.weightMap));
                        let foundWeight = field.weightMap ? (field.weightMap[mapKey] || 0) : 0;
 
                        let multVal = 0;
                        if (field.multiplyBy) {
                            let mVal = getSafeValue(field.multiplyBy, field.columnCountIndex);
                            multVal = mVal !== '' ? Number(mVal) : 0;
                        } else if (field.baseRatesMap) {
                            // 👉 Fetch specs globally
                            let steelTypeVal = getSafeValue('steel_type', field.columnCountIndex);
                            let desigVal = getSafeValue('designation', field.columnCountIndex);
 
                            let shapeVal = currentValues[1] || '';
                            let classVal = currentValues[2] || '';
                            let sizeVal = currentValues[3] || '';
 
                            let rateValues = [steelTypeVal, desigVal, shapeVal, classVal, sizeVal];
                            let searchKeys = [
                                    rateValues.join('|'),             
                                    rateValues.slice(0, 4).join('|'), 
                                    rateValues.slice(0, 3).join('|'), 
                                    rateValues.slice(0, 2).join('|'), 
                                    rateValues[0]                     
                                ];
 
                            for (let sk of searchKeys) {
                                if (this.baseRates && this.baseRates[sk] !== undefined) {
                                    multVal = this.baseRates[sk];
                                    break;
                                } else if (field.baseRatesMap && field.baseRatesMap[sk] !== undefined) {
                                    multVal = field.baseRatesMap[sk];
                                    break;
                                }
                            }
                        }
 
                        if (field.extraChargesMap) {
                            let endFinishVal = getSafeValue('end_finish', field.columnCountIndex);
                            if (endFinishVal && field.extraChargesMap[endFinishVal]) {
                                multVal += field.extraChargesMap[endFinishVal];
                            }
                        }
 
                        let uomVal = getSafeValue('uom', field.columnCountIndex);
 
                        if (field.multiplyBy || field.baseRatesMap) {
 
                            if (uomVal === '') {
                                field.value = '';
                                if (field.calculateSecretWeight) field.secretWeight = 0;
                            } else {
                                if (!uomVal) uomVal = 'Meters';
 
                                let finalRate = 0;
                                if (uomVal === 'MT') {
                                    finalRate = multVal * 1000;
                                } else if (uomVal === 'Pieces') {
                                    finalRate = foundWeight * 6 * multVal;
                                } else {
                                    finalRate = foundWeight * multVal;
                                }
 
                                field.value = Math.round(finalRate * 1000) / 1000;
 
                                if (field.calculateSecretWeight) {
                                    let qtyVal = getSafeValue('quantity', field.columnCountIndex);
                                    qtyVal = qtyVal !== '' ? Number(qtyVal) : 0;
 
                                    let totalKg = 0;
                                    if (uomVal === 'MT') {
                                        totalKg = qtyVal * 1000;
                                    } else if (uomVal === 'Pieces') {
                                        totalKg = foundWeight * 6 * qtyVal;
                                    } else {
                                        totalKg = foundWeight * qtyVal;
                                    }
                                    field.secretWeight = Math.round(totalKg * 1000) / 1000;
                                }
                            }
 
                        } else {
                            field.value = foundWeight;
                        }
                    }
                    this._updateFieldUI(field);
                }
            });
        });
    }
    //End
 
    handleClearField(event) {
        try {
            const fieldApiName = event.currentTarget.dataset.name;
 
            this.accordionSections.forEach(sec => {
                const field = sec.fields.find(f => f.apiName === fieldApiName);
                if (field) {
                    field.value = field.type === 'checkbox' ? false : '';
                    field.userCleared = true;
                    field.isManualOverride = false;
                    this._updateFieldUI(field);
                    this._updateSectionUI(sec);
                }
            });
 
            this._lastValues[fieldApiName] = '';
            this._lastValues[`${fieldApiName}__cleared`] = true;
            this._lastValues[`${fieldApiName}__manual`] = false;
 
            this.accordionSections = [...this.accordionSections];
            this.accordionSections.forEach(sec => {
                this._evaluateFieldVisibility(sec.fields);
                this._evaluateDynamicDisable(sec.fields); // 👉 SAFELY INJECTED HERE
            });
            this._evaluateSectionVisibility();
            this._evaluateAllFormulas();
            
            //evaluate section label after clear
            this._evaluateSectionLabels();
 
            this._evaluateDynamicColSpans();
 
            this.accordionSections = this.accordionSections.map(sec => {
                sec.fields.forEach(f => this._updateFieldUI(f));
                this._updateSectionUI(sec);
                return { ...sec };
            });
 
        } catch (e) {
            console.error('handleClearField error:', e);
        }
    }
 
    // =========================================================
    // 👉 THE FIX: VISIBLE FIELDS ALWAYS WIN
    // =========================================================
    _saveCurrentValues() {
        try {
            // 1. Set a default empty state for everything
            this.accordionSections.forEach(sec => {
                sec.fields.forEach(f => {
                    if (this._lastValues[f.apiName] === undefined) {
                        this._lastValues[f.apiName] = f.type === 'checkbox' ? false : '';
                    }
                });
            });
 
            this.accordionSections.forEach(sec => {
                sec.fields.forEach(f => {
                    if (f.type === 'hidden' && f.value !== undefined && f.value !== null && f.value !== '') {
                        this._lastValues[f.apiName] = f.value;
                    }
                });
            });
 
            // 2. Let the VISIBLE sections overwrite the empty state
            this.accordionSections.forEach(sec => {
                if (sec.isVisible) {
                    sec.fields.forEach(f => {
                        if (f.isVisible) {
                            this._lastValues[f.apiName] = f.value;
                            this._lastValues[`${f.apiName}__cleared`] = f.userCleared === true;
                            this._lastValues[`${f.apiName}__manual`] = f.isManualOverride === true;
                        }
                    });
                }
            });
        } catch (e) {
            console.error('_saveCurrentValues error:', e);
        }
    }
 
    // =========================================================
    // 👉 ON-DEMAND CALCULATION (CALCULATE / APPLY) - Reetabrata (8th July)
    // Runs the full heavy pipeline ONCE instead of on every keystroke.
    // =========================================================
    _calculateNow() {
        try {
            this.accordionSections.forEach(sec => {
                this._evaluateFieldVisibility(sec.fields);
                this._evaluateDynamicDisable(sec.fields);
            });
 
            // moving evaluate look first - so it first fetch values from map then formula evaluation happans - rajeev 02-07-2026
            this._evaluateLookups();
            this._evaluateAllFormulas();
            this._evaluateSectionVisibility();
            this._evaluateAllFormulas();
            this._evaluateDynamicColSpans();
            ////evaluate section label after field change
            this._evaluateSectionLabels();
 
            this.accordionSections = this.accordionSections.map(sec => {
                sec.fields.forEach(f => this._updateFieldUI(f));
                this._updateSectionUI(sec);
                return { ...sec };
            });
        } catch (mathError) {
            console.error('Math Engine Error:', mathError);
        }
    }
 
    // 👉 Bound to the CALCULATE button in the footer - Reetabrata (8th July)
    handleCalculate() {
        this.isLoading = true;
        setTimeout(() => {
            try {
                this._calculateNow();
            } catch (e) {
                console.error('handleCalculate error:', e);
            } finally {
                this.isLoading = false;
            }
        }, 0);
    }
 
    // 👉 APPLY now runs the CALCULATE pass first, with the spinner visible.
    // isLoading is flipped BEFORE the work is queued so LWC gets a frame to paint
    // the spinner; the heavy _calculateNow() + _applyNow() then run on the next
    // tick. Same pattern as handleCalculate(). The `finally` is essential: the
    // Telecom-Tower validation inside _applyNow() returns early, and _resetModal()
    // does not touch isLoading, so without it the spinner would never stop.
    // - Reetabrata (9th July 2026)
    handleApply() {
        if (this.isLoading) return;   // ignore double-clicks while a run is in flight
        this.isLoading = true;
        setTimeout(() => {
            try {
                this._calculateNow();   // exactly what the CALCULATE button runs
                this._applyNow();
            } catch (e) {
                console.error('handleApply error:', e);
            } finally {
                this.isLoading = false;
            }
        }, 0);
    }
 
    // Body of the original handleApply(), unchanged apart from the _calculateNow()
    // call being hoisted into handleApply() above. - Reetabrata (9th July 2026)
    _applyNow() {
        console.log('🛑 [DEBUG] handleApply START');
        try {
            if (!this._headlessMode && !this._validateTelecomTowerComposition()) {
                return; // Blocks save completely, toast already shown inside method
            }

            if (!this._headlessMode && !this._validateTelecomPaymentTerms()) {
                return; // Blocks save completely, toast already shown inside method
            }

            // Tower and Substation must share one Price Basis. No-op on every
            // other department. Deepanjan (12th August 2026)
            if (!this._headlessMode && !this._validateTowerSubstationPriceBasis()) {
                return; // Blocks save completely, toast already shown inside method
            }

            // Tower and Substation must agree on Payment Terms (and, where applicable,
            // No Of Days / Prevailing Rate of Bank Interest). No-op on every other
            // department.
            if (!this._headlessMode && !this._validateTowerSubstationPaymentTerms()) {
                return; // Blocks save completely, toast already shown inside method
            }

            // 👉 Block Apply when a visible required field is empty, or a min-flagged
            //    field (e.g. Full Vehicle Freight) holds 0 / negative. Toast shown inside.
            if (!this._headlessMode && !this.validateRequiredFields()) {
                return;
            }

            // ═══════════════════════════════════════════════════════════════
            // FIRST-APPLY FRESHNESS — Deepanjan (24th July 2026)
            // Two-step guard, both no-ops when everything is already fresh:
            //  1. Re-run the CALCULATE pipeline (lookups + a double formula
            //     pass) so dependency chains like added_up -> unit_rate ->
            //     cost_price -> unit_price fully converge before we read.
            //  2. Sync duplicates FROM the visible copy: the same apiName can
            //     live in several sections (hidden internal-calc groups). The
            //     change handler already syncs every duplicate when the USER
            //     types (see matchedFields: "prefer a VISIBLE one"), but
            //     FORMULA outputs updated only the copy they sit on - the
            //     hidden duplicates kept the value loaded at open. The line
            //     item parser then read those stale hidden copies (its "||"
            //     collectors are last-wins), so the first Apply saved the old
            //     unit_price (e.g. 75797 instead of 76297). Copying the
            //     visible value onto its hidden namesakes makes every copy
            //     agree, WITHOUT touching the parser's iteration order or any
            //     hidden-only section's behaviour.
            // Hardened: can never block the save itself.
            // ═══════════════════════════════════════════════════════════════
            try {
                this._evaluateLookups();
                this._evaluateAllFormulas();
                this._evaluateAllFormulas();

                const visibleVals = {};
                this.accordionSections.forEach(sec => {
                    if (!sec.isVisible) return;
                    sec.fields.forEach(f => {
                        if (f.type === 'header' || f.type === 'hidden') return;
                        if (!f.isVisible) return;
                        if (f.value !== '' && f.value !== null && f.value !== undefined) {
                            visibleVals[f.apiName] = f.value;
                        }
                    });
                });
                this.accordionSections.forEach(sec => {
                    sec.fields.forEach(f => {
                        if (f.isVisible) return;
                        if (visibleVals[f.apiName] !== undefined && f.value !== visibleVals[f.apiName]) {
                            f.value = visibleVals[f.apiName];
                        }
                    });
                });
            } catch (freshErr) {
                console.error('Pre-apply refresh failed (saving as-is):', freshErr);
            }
 
            const result = {};
            const parsedLineItems = []; 
 
            // 1. Baseline empty state.
            // Include hidden internal calc sections (forceHidden) AND sections that were
            // revealed only to collect inputs (revealedHiddenInputs) — both hold internal
            // fields whose values must persist. Reetabrata (14th July 2026)
            this.accordionSections.forEach(sec => {
                if (!sec.isVisible && !sec.forceHidden && !sec.revealedHiddenInputs) return;
 
                sec.fields.forEach(f => {
                    if (f.type === 'header' || f.type === 'hidden') return;
                    if (result[f.apiName] === undefined) result[f.apiName] = f.type === 'checkbox' ? false : '';
                });
            });
 
            // 2. Save field values AND capture parent push mappings.
            // For a normal visible section: save its visible fields (unchanged behaviour).
            // For an internal calc section — whether still fully hidden (forceHidden) or
            // revealed to show inputs (revealedHiddenInputs) — save ALL its non-header
            // fields, so both the user inputs AND the hidden formula outputs are stored in
            // the JSON exactly as required. Reetabrata (14th July 2026)
            const parentPushes = {}; 
            this.accordionSections.forEach(sec => {
                const isInternalCalc = sec.forceHidden === true || sec.revealedHiddenInputs === true;
                if (!sec.isVisible && !isInternalCalc) return;
                sec.fields.forEach(f => {
                    if (f.type === 'header' || f.type === 'hidden') return;
                    if (f.isVisible || isInternalCalc) {
                        result[f.apiName] = (f.value !== null && f.value !== undefined) ? f.value : '';
 
                        if (f.pushToParentApiName) {
                            parentPushes[f.pushToParentApiName] = result[f.apiName];
                        }
                    }
                });
            });

                        // SEGMENT ABOVE 5 — manual overrides survive reopen. Deepanjan (22nd September 2026)
            // An editable field that also carries a formula (TOTAL PRICE (/KG) =
            // Base_Amount__c + 5, every segment LENGTH / THICKNESS, SI price/weight add)
            // is skipped by the formula engine only while isManualOverride is true. That
            // flag lived only in this instance's _lastValues and never reached the saved
            // JSON, so any rebuild from saved data re-ran the formula over the typed
            // value (99 -> 102). The flag now travels with the values as
            // <apiName>__manual, which _buildFields already reads.
            // TRUE only for a VISIBLE field the user overrode. FALSE is written only to
            // retire a flag that was TRUE before - an override the user cleared, or a
            // field that went invisible (its value is blanked by the baseline above, so
            // the formula must be free to run again when it reappears). Everything else
            // writes nothing, so the JSON grows by a handful of keys. Sections that are
            // not visible are skipped, exactly like the value loop above.
            // Other departments are untouched.
            if (this._modalConfig) {
                const savedAtOpen = this._modalConfig.savedData || {};   // absent in headless
                const lastVals    = this._lastValues || {};
                const wasTrue = k => savedAtOpen[k] === true || lastVals[k] === true;
                const formulaApis = new Set();
                const manualNow   = new Set();
                this.accordionSections.forEach(sec => {
                    if (!sec.isVisible) return;
                    sec.fields.forEach(f => {
                        if (!f.formula || f.type === 'header' || f.type === 'hidden') return;
                        formulaApis.add(f.apiName);
                        if (f.isVisible && f.isManualOverride === true) manualNow.add(f.apiName);
                    });
                });
                formulaApis.forEach(api => {
                    const k = `${api}__manual`;
                    if (manualNow.has(api)) result[k] = true;
                    else if (wasTrue(k)) result[k] = false;
                });
            }

            // PU Paint realization is not a line item, so the approval matrix could never
            // see it. Every field carrying an approvalMetric tag is folded into ONE flat key
            // on the saved values. Lowest value wins - low realization is the risky case.
            // The field is hidden while PU Paint is unticked, so nothing is written then.
            const approvalMins = {};
            this.accordionSections.forEach(sec => {
            const isInternalCalc = sec.forceHidden === true || sec.revealedHiddenInputs === true;
            if (!sec.isVisible && !isInternalCalc) return;
            sec.fields.forEach(f => {
            if (!f.approvalMetric) return;
            if (!f.isVisible && !isInternalCalc) return;
            const v = Number(f.value);
            if (f.value === '' || f.value === null || !Number.isFinite(v)) return;
            const k = 'approval_' + f.approvalMetric;
            approvalMins[k] = (k in approvalMins) ? Math.min(approvalMins[k], v) : v;
            });
            });
            // clear stale approval_* first, so a re-save can never leave an old value behind
            Object.keys(result).filter(k => k.startsWith('approval_')).forEach(k => delete result[k]);
            Object.assign(result, approvalMins);

           
          // 3. 👉 DYNAMIC LINE ITEM PARSER
            let sectionCounter = 1;
            const groupedSectionsMap = new Map();
            
            // Pre-compute which sections carry genuine line-item flags, so a section that
            // is RESPONSIBLE for a line item is processed even when it is hidden. Line-item
            // creation is governed by these flags (see sectionHasLineFlags below), never by
            this.accordionSections.forEach(sec => {
                // Process the section if it is visible OR it is INTENTIONALLY hidden via
                // isVisible:false (forceHidden) — an internal calc/line section that must
                // still emit its line item. A section hidden only because its controllingField
                // did not match (e.g. an EMPTY repeater row) is NOT a line-item section and is
                // skipped, so empty rows create no spurious line items. Reetabrata (14th July 2026)
                if (!sec.isVisible && !sec.forceHidden) return;

                // A forceHidden section (isVisible:false) is an internal block that still emits
                // its line - but only when its controllingField says it applies. Without this,
                // every member of a mutually-exclusive hidden group (the 12 PV/FIRM price
                // models) is treated as active and each emits a line. Sections with no
                // controllingField default to applicable, so pure internal-calc blocks are
                // untouched. Reetabrata (15th July 2026)
                const __applies = (sec.isApplicable !== undefined) ? sec.isApplicable : true;
                if (sec.forceHidden && !__applies) return;

                const groupId = sec.lineItemGroup || sec.id;
                
                if (!groupedSectionsMap.has(groupId)) {
                    groupedSectionsMap.set(groupId, {
                        label: sec.label, 
                        fields: [],
                        // The grouped pseudo-section must carry the REAL visibility of its
                        // constituents. Without this, `sec.isVisible` is undefined below, so
                        // __readHidden treats every flagged section as a hidden line section
                        // and reads its hidden fields — e.g. the 9 count-hidden columns of a
                        // column-repeater (Solar), whose rate-driven formulas hold nonzero
                        // prices, each emitting a phantom "(Item N)" line. OR-merge across
                        // the group: visible if any part is visible; internal-calc if any
                        // part is forceHidden/revealedHiddenInputs. Reetabrata (15th July 2026)
                        isVisible: false,
                        forceHidden: false,
                        revealedHiddenInputs: false
                    });
                }
                const __grp = groupedSectionsMap.get(groupId);            // Reetabrata (15th July 2026)
                __grp.isVisible = __grp.isVisible || sec.isVisible === true;
                __grp.forceHidden = __grp.forceHidden || sec.forceHidden === true;
                __grp.revealedHiddenInputs = __grp.revealedHiddenInputs || sec.revealedHiddenInputs === true;
                __grp.fields.push(...sec.fields);
            });
 
            groupedSectionsMap.forEach((sec, groupId) => {
                
                let maxCol = 1;
                sec.fields.forEach(f => {
                    if (f.isColRepeaterInput && f.columnCountIndex > maxCol) maxCol = f.columnCountIndex;
                });
 
                // ═══════════════════════════════════════════════════════════════════
                // ★ CHANGE 3 of 5 — BUG 2 (Stadium "Segment Weight Details" creates a
                //   spurious line item) ★  Reetabrata (14th July 2026)  — NEW VARIABLE
                // A section is a genuine LINE-ITEM section only if at least one field
                // declares a line-item flag (isWeightTotal / isUnitPrice / isUnitCost /
                // isQuantity / isListPrice / isRealization / isMargin / isDiscount) OR
                // carries a designation. Display-only sections such as "Segment Weight
                // Details" have a field whose apiName ends in "_weight" (which trips the
                // weight fallback below) but declare NO line-item flags — they must not
                // create a line item. This gate preserves every real section (all carry
                // these flags) and only suppresses the duplicate weight-display rows.
                // ═══════════════════════════════════════════════════════════════════
                const sectionHasLineFlags = sec.fields.some(f => // Reetabrata (14th July 2026)
                    f.isWeightTotal || f.isUnitPrice || f.isUnitCost || f.isQuantity ||
                    f.isListPrice || f.isRealization || f.isMargin || f.isDiscount ||
                    (f.secretWeight !== undefined && f.secretWeight > 0) ||
                    (f.apiName && (
                        f.apiName.toLowerCase().endsWith('unit_price') ||
                        f.apiName.toLowerCase().endsWith('unit_cost') ||
                        f.apiName.toLowerCase().endsWith('list_price') ||
                        f.apiName.toLowerCase().endsWith('designation')
                    ))
                );
 
                // When a section is responsible for a line item, its line-item fields may
                // themselves be hidden (a hidden line section). In that case we must read
                // field values regardless of field visibility; visibility only controls the
                // UI, not whether the line item is built. For normal visible sections this
                // is unchanged (all their line fields are visible). Reetabrata (14th July 2026)
                const __readHidden = sectionHasLineFlags && (!sec.isVisible || sec.revealedHiddenInputs);

                // ✅ NEW BLOCK START
                const gridRowIndices = new Set();
                sec.fields.forEach(f => {
                    if (!f.isVisible && !__readHidden) return;
                    const rowMatch = f.apiName.match(/^r(\d+)_/);
                    if (rowMatch) gridRowIndices.add(Number(rowMatch[1]));
                });
 
                if (gridRowIndices.size > 0) {
                    [...gridRowIndices].sort((a, b) => a - b).forEach(rowIdx => {
                        let weight = 0, qty = 1, realization = 0, unitPrice = 0, unitCost = 0, listPrice = 0, discount = 0, margin = 0;
                        let steel_type = '', designation = '', size_nb = '', pipe_class = '', standard = '', end_finish = '', uom = '', rate = 0, gst = 0, price_per_uom = 0, total_price = 0 , added_up = '', tolerance = '';
                        
                        sec.fields.forEach(f => {
                            if (!f.isVisible && !__readHidden) return;
                            const rowMatch = f.apiName.match(/^r(\d+)_/);
                            if (!rowMatch || Number(rowMatch[1]) !== rowIdx) return;
 
                            // 👉 BULLETPROOF FALLBACKS ADDED HERE
                            if (f.isWeightTotal || f.apiName.toLowerCase().endsWith('_weight')) weight = Number(f.value) || weight;
                            if (f.secretWeight !== undefined && f.secretWeight > 0) weight = f.secretWeight;
                            if (f.isQuantity || f.apiName.toLowerCase().includes('quantity')) qty = Number(f.value) || qty;
                            if (f.isRealization) realization = Number(f.value) || 0;
                            if (f.isUnitPrice || f.apiName.toLowerCase().endsWith('unit_price')) unitPrice = Number(f.value) || unitPrice;
                            if (f.isUnitCost || f.apiName.toLowerCase().endsWith('unit_cost')) unitCost = Number(f.value) || unitCost;
                            if (f.isListPrice || f.apiName.toLowerCase().endsWith('list_price')) listPrice = Number(f.value) || listPrice;
                            if (f.isDiscount || f.apiName.toLowerCase().endsWith('discount')) discount = Number(f.value) || discount;
                            if (f.isMargin || f.apiName.toLowerCase().endsWith('margin')) margin = Number(f.value) || margin; // 👉 Extracts Margin

                             // 👉 ADD THESE TWO LINES TO EXTRACT THE VALUES
                           // 👉 EXACT MATCH FIX: Prevent sub-components from overwriting the main component
                            const isMainAddedUp = /^[a-z]\d+_added_up$/.test(f.apiName) || f.apiName === 'added_up';
                            const isMainTolerance = /^[a-z]\d+_(tolerance_percent|tol_pct)$/.test(f.apiName) || f.apiName === 'tolerance';

                            if (isMainAddedUp) {
                                added_up = (f.value !== '' && f.value !== null && f.value !== undefined) ? Number(f.value) : '';
                            }
                            if (isMainTolerance) {
                                tolerance = (f.value !== '' && f.value !== null && f.value !== undefined) ? Number(f.value) : '';
                            }
                            
                            if (f.apiName.endsWith('steel_type')) steel_type = f.value;
                            if (f.apiName.endsWith('designation')) designation = f.value;
                            if (f.apiName.endsWith('size_nb')) size_nb = f.value;
                            if (f.apiName.endsWith('pipe_class')) pipe_class = f.value;
                            if (f.apiName.endsWith('standard_spec_grade')) standard = f.value;
                            if (f.apiName.endsWith('end_finish')) end_finish = f.value;
                            if (f.apiName.endsWith('uom')) uom = f.value;
                            if (f.apiName.endsWith('rate')) rate = Number(f.value) || 0;
                            if (f.apiName.endsWith('gst')) gst = Number(f.value) || 0;
                            if (f.apiName.endsWith('price_per_uom')) price_per_uom = Number(f.value) || 0;
                            if (f.apiName.endsWith('total_price')) total_price = Number(f.value) || 0;
                        });
 
                        // ★ CHANGE 4 of 5 — BUG 2 gate (grid-row push) ★ Reetabrata (14th July 2026)
                        // Was: if (weight > 0 || unitPrice > 0 || unitCost > 0 || designation !== '')
                        if (sectionHasLineFlags && (weight > 0 || unitPrice > 0 || unitCost > 0 || designation !== '')) { // Reetabrata (14th July 2026)
                            let cleanSectionName = sec.label.replace(/^[0-9.]+\s*/, '').trim();
                            let finalItemName = `${this.modalTitle.replace('WEIGHT ESTIMATOR - ', '').trim()} - ${cleanSectionName} (Row ${rowIdx})`;
                            
                            parsedLineItems.push({
                                itemName: finalItemName,
                                weight, quantity: qty, realization,
                                unitPrice, unitCost, listPrice, discount,
                                steel_type, designation, size_nb, pipe_class,
                                standard_spec_grade: standard, end_finish, uom,
                                rate, gst, price_per_uom, total_price,added_up, tolerance
                            });
                        }
                    });
                    sectionCounter++;
                    return; 
                }
                // ✅ NEW BLOCK END
 
                for (let c = 1; c <= maxCol; c++) {

                    // This block create a line item for each basic rates in Steel tubular Pole - rajeev 27-july 2026
                    // ═══ STEEL TUBULAR POLE ONLY — one line item per isUnitPrice field.
                    // Gate 1: hardcoded department check. Gate 2: 2+ priced fields in the
                    // section. Any other department fails Gate 1 and never enters. ═══
                    // const _isPoleDept = MULTI_PRICE_MODAL_TITLES.includes(
                    //     (this.modalTitle || '').trim().toUpperCase()
                    // );

                    // if (_isPoleDept) {
                    //     const _inScope = (f) => (f.isVisible || __readHidden) &&
                    //         (f.columnCountIndex === c || !f.columnCountIndex);

                    //     const _priced = sec.fields.filter(f =>
                    //         _inScope(f) && f.isUnitPrice && Number(f.value) > 0);

                    //     if (_priced.length > 1) {
                    //         const _priceApis = _priced.map(f => f.apiName);
                    //         // Skip rollups: a priced field whose formula references another
                    //         // priced field in this section (d1_final_total_amount sums the
                    //         // component rates) would double-count the components.
                    //         const _leaves = _priced.filter(f => {
                    //             if (!f.formula) return true;
                    //             return !_priceApis.some(api =>
                    //                 api !== f.apiName &&
                    //                 new RegExp('\\b' + api + '\\b').test(f.formula));
                    //         });
                    //         const _emit = _leaves.length ? _leaves : _priced;
                    //         const _ordered = sec.fields.filter(_inScope);

                    //         // Section weight goes on the first emitted line only
                    //         let _secWeight = 0;
                    //         _ordered.forEach(f => {
                    //             if (f.isWeightTotal || f.apiName.toLowerCase().endsWith('_weight'))
                    //                 _secWeight = Number(f.value) || _secWeight;
                    //             if (f.secretWeight !== undefined && f.secretWeight > 0)
                    //                 _secWeight = f.secretWeight;
                    //         });

                    //         const _cleanName = sec.label.replace(/^[0-9.]+\s*/, '').trim();
                    //         let _first = true;

                    //         _emit.forEach(pf => {
                    //             const idx = _ordered.indexOf(pf);

                    //             // Pair the rate with ITS quantity: nearest isQuantity AFTER
                    //             // this rate (stopping at the next rate), else nearest BEFORE,
                    //             // else 1. Matches your JSON layout (rate → added-up → qty).
                    //             let q = null;
                    //             for (let i = idx + 1; i < _ordered.length; i++) {
                    //                 if (_ordered[i].isUnitPrice) break;
                    //                 if (_ordered[i].isQuantity) { q = Number(_ordered[i].value) || 1; break; }
                    //             }
                    //             if (q === null) for (let i = idx - 1; i >= 0; i--) {
                    //                 if (_ordered[i].isUnitPrice) break;
                    //                 if (_ordered[i].isQuantity) { q = Number(_ordered[i].value) || 1; break; }
                    //             }
                    //             if (q === null) q = 1;

                    //             // Component name from the controlling checkbox's label
                    //             // ("MS / GI", "Cast Iron (IS)", "Single Arm", ...)
                    //             let comp = '';
                    //             if (pf.controllingField && !pf.controllingField.includes(',')) {
                    //                 const ctrl = sec.fields.find(x =>
                    //                     x.apiName === pf.controllingField.trim());
                    //                 if (ctrl && ctrl.label && ctrl.label.trim())
                    //                     comp = ctrl.label.trim();
                    //             }
                    //             let nm = `${this.modalTitle.trim()} - ${_cleanName}`;
                    //             if (comp) nm += ` - ${comp}`;
                    //             if (maxCol > 1) nm += ` (Item ${c})`;

                    //             const p = Math.round(Number(pf.value) * 1000) / 1000;
                    //             parsedLineItems.push({
                    //                 itemName: nm,
                    //                 weight: _first ? _secWeight : 0,
                    //                 quantity: q, realization: 0,
                    //                 unitPrice: p, unitCost: p, listPrice: p,
                    //                 discount: 0, margin: 0,
                    //                 steel_type: '', designation: '', size_nb: '', pipe_class: '',
                    //                 standard_spec_grade: '', end_finish: '', uom: '',
                    //                 rate: 0, gst: 0, price_per_uom: 0, total_price: 0,
                    //                 added_up: '', tolerance: ''
                    //             });
                    //             _first = false;
                    //         });
                    //         continue; // this section/column fully handled — skip legacy path
                    //     }
                    //     // _priced.length <= 1 → fall through to legacy path even for Pole,
                    //     // so single-price Pole sections (if any) behave like before.
                    // }

                    let weight = 0, qty = 1, realization = 0, unitPrice = 0, unitCost = 0, listPrice = 0, discount = 0, margin = 0;
                    let steel_type = '', designation = '', size_nb = '', pipe_class = '', standard = '', end_finish = '', uom = '', rate = 0, gst = 0, price_per_uom = 0, total_price = 0, added_up = '', tolerance = '';
 
                    sec.fields.forEach(f => {
                        if (!f.isVisible && !__readHidden) return;
                        if (f.columnCountIndex === c || !f.columnCountIndex) {
                            
                            // 👉 BULLETPROOF FALLBACKS ADDED HERE
                            if (f.isWeightTotal || f.apiName.toLowerCase().endsWith('_weight')) weight = Number(f.value) || weight;
                            if (f.secretWeight !== undefined && f.secretWeight > 0) weight = f.secretWeight;
                            if (f.isQuantity || f.apiName.toLowerCase().includes('quantity')) qty = Number(f.value) || qty;
                            if (f.isRealization) realization = Number(f.value) || 0;
                            if (f.isUnitPrice || f.apiName.toLowerCase().endsWith('unit_price')) {
                                unitPrice = Number(f.value) || unitPrice;
                            }
                            if (f.isUnitCost || f.apiName.toLowerCase().endsWith('unit_cost')) {
                                unitCost = Number(f.value) || unitCost;
                            }
                            if (f.isListPrice || f.apiName.toLowerCase().endsWith('list_price')) listPrice = Number(f.value) || listPrice;
                            if (f.isDiscount || f.apiName.toLowerCase().endsWith('discount')) discount = Number(f.value) || discount;
                            if (f.isMargin || f.apiName.toLowerCase().endsWith('margin')) margin = Number(f.value) || margin; // 👉 Extracts Margin

                             // 👉 ADD THESE TWO LINES TO EXTRACT THE VALUES
                           // 👉 THE FIX: Safely extract values without forcing an empty string to become a 0
                           // 👉 EXACT MATCH FIX: Prevent sub-components from overwriting the main component
                            const isMainAddedUp = /^[a-z]\d+_added_up$/.test(f.apiName) || f.apiName === 'added_up';
                            const isMainTolerance = /^[a-z]\d+_(tolerance_percent|tol_pct)$/.test(f.apiName) || f.apiName === 'tolerance';

                            if (isMainAddedUp) {
                                added_up = (f.value !== '' && f.value !== null && f.value !== undefined) ? Number(f.value) : '';
                            }
                            if (isMainTolerance) {
                                tolerance = (f.value !== '' && f.value !== null && f.value !== undefined) ? Number(f.value) : '';
                            }
 
                            if (f.apiName.endsWith('steel_type')) steel_type = f.value;
                            if (f.apiName.endsWith('designation')) designation = f.value;
                            if (f.apiName.endsWith('size_nb')) size_nb = f.value;
                            if (f.apiName.endsWith('pipe_class')) pipe_class = f.value;
                            if (f.apiName.endsWith('standard_spec_grade')) standard = f.value;
                            if (f.apiName.endsWith('end_finish')) end_finish = f.value;
                            if (f.apiName.endsWith('uom')) uom = f.value;
                            if (f.apiName.endsWith('rate')) rate = Number(f.value) || 0;
                            if (f.apiName.endsWith('gst')) gst = Number(f.value) || 0;
                            if (f.apiName.endsWith('price_per_uom')) price_per_uom = Number(f.value) || 0;
                            if (f.apiName.endsWith('total_price')) total_price = Number(f.value) || 0;
                        }
                    });
 
                    // ★ CHANGE 5 of 5 — BUG 2 gate (column push) ★ Reetabrata (14th July 2026)
                    // Was: if (weight > 0 || unitPrice > 0 || unitCost > 0 || designation !== '')
                    // ── Added: skip a section-level line whose section label resolves to EMPTY.
                    // Such a line renders as a nameless "{Modal} - " row — it is always a
                    // container/base section (e.g. the Freight base section carrying the product
                    // total forward), never a real product line, which always has a descriptive
                    // label. Repeater rows keep their "{label}" name and are unaffected, and no
                    // labeled section in any department is touched. Reetabrata (14th July 2026)
                    let cleanSectionName = sec.label.replace(/^[0-9.]+\s*/, '').trim();
                    if (sectionHasLineFlags && cleanSectionName !== '' && (weight > 0 || unitPrice > 0 || unitCost > 0 || designation !== '')) {
                        let finalItemName = `${this.modalTitle.replace('WEIGHT ESTIMATOR - ', '').trim()} - ${cleanSectionName}`;
                        
                        if (maxCol > 1) {
                            finalItemName += ` (Item ${c})`;
                        }
                        
                        parsedLineItems.push({
                            itemName: finalItemName,
                            weight: weight, quantity: qty, realization: realization,
                            unitPrice: unitPrice, unitCost: unitCost, listPrice: listPrice, discount: discount,margin: margin,
                            steel_type: steel_type, designation: designation, size_nb: size_nb, pipe_class: pipe_class,
                            standard_spec_grade: standard, end_finish: end_finish, uom: uom,
                           rate: rate, gst: gst, price_per_uom: price_per_uom, total_price: total_price, added_up: added_up, tolerance: tolerance
                        });
                    }
                }
                sectionCounter++;
            });
 
            this._saveCurrentValues();

            // Headless recompute (cross-modal refresh): capture results, no event, no reset.
            if (this._headlessMode) {
                this._headlessResult = {
                    values: result,
                    lineItems: parsedLineItems,
                    parentPushes: parentPushes
                };
                return;
            }
            
            // 4. Send BOTH the raw values AND the Line Items to the Parent
            this.dispatchEvent(new CustomEvent('applyvalues', {
                detail: {
                    values: result,
                    lineItems: parsedLineItems,
                    modalConfig: this._modalConfig,
                    parentPushes: parentPushes,
                    isComplete: true
                }
            }));
            
            this._resetModal();
            console.log('🛑 [DEBUG] handleApply COMPLETE');
        } catch (e) {
            console.error('🚨 [DEBUG ERROR] handleApply crashed!');
            console.error('🚨 [DEBUG ERROR] Message:', e.message);
            console.error('handleApply error:', e);
        }
    }
 
    handleClose() {
        try {
            this._saveCurrentValues();
            this.dispatchEvent(new CustomEvent('modalclose', {}));
            this._resetModal();
        } catch (e) {
            console.error('handleClose error:', e);
        }
    }
 
    _resetModal() {
        this.isModalOpen = false;
        this.accordionSections = [];
        this.modalTitle = '';
        this._modalConfig = null;
    }
 
    stopPropagation(event) {
        event.stopPropagation();
    }
 
    // =========================================================
    // 👉 CHILD MODAL VALIDATION ENGINE
    // Automatically respects hidden and dynamically disabled fields!
    // =========================================================
    // Resolve a human-readable label for a field. Some inputs carry an empty
    // label (their caption lives on a sibling header field), so never fall back
    // to the raw apiName in the toast until every option is exhausted.
    _prettyLabel(sec, field) {
        if (field.label && field.label.trim() !== '') return field.label.trim();
        // 1) sibling header by this engine's naming convention: <apiName>_header
        const hdr = sec.fields.find(f =>
            f.apiName === field.apiName + '_header' && f.label && f.label.trim() !== '');
        if (hdr) return hdr.label.trim();
        // 2) nearest preceding header field in the same section
        const idx = sec.fields.indexOf(field);
        for (let i = idx - 1; i >= 0; i--) {
            const f = sec.fields[i];
            if (f.type === 'header' && f.label && f.label.trim() !== '') return f.label.trim();
        }
        // 3) last resort
        return field.apiName;
    }

    // =========================================================
    // CRASH BARRIER - Accessories row validation
    // ---------------------------------------------------------
    // A row of ACCESSORIES DETAILS is only "in use" once its W/T BEAM
    // picklist has a value. Such a row must then also have UOM, RATE and
    // QUANTITY (NO.). Rows with no beam selected are left completely alone,
    // and nothing is ever hidden - the JSON required/controllingField route
    // would have hidden the three cells instead.
    //
    // Scoping: the loop keys off acc_section_w_t_beam_input*, which only
    // exists in the Crash Barrier Accessories section logic. Departments
    // whose accessories table has no W/T BEAM column contribute no fields
    // here and the method returns an empty array - same "no fields, no
    // effect" guard used by _validateTelecomTowerComposition.
    //
    // Row keys are irregular: row 1 has NO numeric suffix
    // (acc_section_uom_input) while rows 2-10 do (acc_section_uom_input2 ...
    // acc_section_uom_input10), so the suffix list starts with ''.
    // =========================================================
    // ADDITIONAL ACCESSORIES block, Segment Above 5 - Deepanjan (6th September 2026,
    // widened 8th September 2026). Wherever the block is on screen, it must carry RATE and
    // at least ONE of TYPE OF WINCH / DRUM TYPE / TYPE OF POWER TOOL / TYPE OF WIRE ROPE.
    //   - Stadium Mast: the quote-level block (bare lm_acc_rate), on screen only while Man
    //     Riding Lift is ticked. RATE there is a plain required flag in segmentGenerator.js,
    //     so this method only adds the "one of four" rule (no duplicate RATE message).
    //   - Lighting Mast / LCLM: the block is cloned PER ROW (r{n}_lm_acc_rate) and is always
    //     on screen for every mast row, so both RATE and "one of four" are checked here,
    //     per row, labelled "Additional Accessories <row>" like the section header.
    //   - Flag Mast prices its accessories in its own fm_ac_ grid; its lm_ block is not the
    //     priced one, so a recipe that carries any fm_ac_ field is skipped entirely.
    // An "any one of four" rule cannot be a per-field required flag, hence this method -
    // same shape as the Crash Barrier precedent below. Other departments have no
    // lm_acc_rate field and return [] on the first pass.
    _validateAccessoryBlock() {
        const problems = [];
        const sections = Array.isArray(this.accordionSections) ? this.accordionSections : [];
        const byApi = new Map();
        sections.forEach(sec => {
            if (!sec || !sec.isVisible || !Array.isArray(sec.fields)) return;
            sec.fields.forEach(f => {
                if (f && f.apiName && !byApi.has(f.apiName)) byApi.set(f.apiName, f);
            });
        });

        for (const api of byApi.keys()) {
            if (/^(r\d+_)?fm_ac_/.test(api)) return problems;   // Flag Mast: own accessory grid
        }

        const hasValue = (f) => {
            if (!f) return false;
            const v = f.value;
            if (v === '' || v === null || v === undefined) return false;
            return String(v).trim() !== '';
        };
        const TYPES = ['lm_type_of_winch', 'lm_winch_drum', 'lm_type_of_power_tool', 'lm_type_of_wire_rope'];

        byApi.forEach((rate, api) => {
            const m = api.match(/^(r(\d+)_)?lm_acc_rate$/);
            if (!m || !rate.isVisible) return;
            const pfx   = m[1] || '';
            const label = '[Additional Accessories' + (m[2] ? ' ' + m[2] : '') + ']';

            // RATE: only when the field is not already a required flag (Stadium copy is).
            if (rate.required !== true && !hasValue(rate)) {
                problems.push(label + ' RATE');
            }
            const anyType = TYPES.some(k => hasValue(byApi.get(pfx + k)));
            if (!anyType) {
                problems.push(label + ' TYPE OF WINCH / DRUM TYPE / TYPE OF POWER TOOL / TYPE OF WIRE ROPE (at least one)');
            }
        });
        return problems;
    }


       /* Octagonal / Custom Pole (High Mast): FOUNDATION BOLT DIAMETER = N.R. means the
       bolts are NOT in our scope, but the offer still prints their dimensions - N.R FB
       DIAMETER, FOUNDATION BOLT LENGTH and BOLT QUANTITY. HighMastSOWController drops
       each one when blank, so a half-filled N.R. foundation saved cleanly and then
       printed a sentence with pieces missing (seen on a quote with
       c1_s1_cus_op_nr_fb_diameter and _foundation_bolt_length both empty). Make all
       three mandatory once N.R. is picked.

       Column-repeater fields are flattened into sec.fields by _expandFields as
       c{n}_<api>, each carrying isColRepeaterInput + columnCountIndex, so siblings are
       matched on columnCountIndex - the same idiom as the dependent-picklist wake-up.

       Matching on the VALUE, not on isVisible: an unused column saves as '' while an
       in-use N.R. column saves 'N.R.', so columns 2-10 fall out on their own and this
       never depends on how a disabled-but-shown repeater input reports visibility.
       Covers Standard (s1_foundation_bolt_diameter) and Custom (s1_cus_op_...) alike -
       both end in the same suffix. Deepanjan (16th September 2026) */
       _validateOctagonalNrFoundation() {
        const missing = [];
        const NR_REQUIRED = [
            { suffix: 'nr_fb_diameter',         label: 'N.R FB DIAMETER' },
            { suffix: 'foundation_bolt_length', label: 'FOUNDATION BOLT LENGTH' },
            { suffix: 'bolt_quantity',          label: 'BOLT QUANTITY' }
        ];

        const resolve = this._fieldResolver([]);   // global apiName -> field

        this.accordionSections.forEach(sec => {
            if (!sec.isVisible) return;

            sec.fields.forEach(dia => {
                if (dia.type === 'header' || !dia.isColRepeaterInput) return;
                if (!dia.apiName || !dia.apiName.endsWith('foundation_bolt_diameter')) return;

                // Only columns the user actually opened. Every column carries the
                // defaultValue "N.R." in memory, so without this all 10 report errors -
                // the saved JSON hides it because unused columns are stripped on write.
                // Deepanjan (16th September 2026)
                const cnt   = resolve(dia.columnCountApi);
                const inUse = parseInt(cnt && cnt.value, 10) || 0;
                if (!dia.columnCountIndex || dia.columnCountIndex > inUse) return;

                if (String(dia.value || '').trim().toUpperCase() !== 'N.R.') return;

                NR_REQUIRED.forEach(req => {
                    const t = sec.fields.find(f => f.apiName
                                               && f.apiName.endsWith(req.suffix)
                                               && f.columnCountIndex === dia.columnCountIndex);
                    if (!t) return;                     // field not on this layout
                    if (t.value === '' || t.value === null || t.value === undefined) {
                        missing.push(`[${sec.label}] Column ${dia.columnCountIndex}: ${req.label} (required when FOUNDATION BOLT is N.R.)`);
                    }
                });
            });
        });

        return missing;
    }

    _validateCrashBarrierAccessoryRows() {
        const problems = [];

        // Flatten every visible field once, keyed by apiName.
        const byApi = new Map();
        const sections = Array.isArray(this.accordionSections) ? this.accordionSections : [];
        sections.forEach(sec => {
            if (!sec || !sec.isVisible || !Array.isArray(sec.fields)) return;
            sec.fields.forEach(f => {
                if (f && f.apiName && !byApi.has(f.apiName)) byApi.set(f.apiName, f);
            });
        });

        const hasValue = (f) => {
            if (!f) return false;
            const v = f.value;
            if (v === '' || v === null || v === undefined) return false;
            return String(v).trim() !== '';
        };

        // '' = row 1, then '2' .. '10'
        const suffixes = ['', '2', '3', '4', '5', '6', '7', '8', '9', '10'];

        suffixes.forEach((sfx, idx) => {
            const beam = byApi.get('acc_section_w_t_beam_input' + sfx);

            // Not a Crash Barrier accessories row, or the row is not visible.
            if (!beam || !beam.isVisible) return;

            // No beam picked - this row is unused, leave it alone.
            if (!hasValue(beam)) return;

            const rowNo = idx + 1;
            [
                ['acc_section_uom_input' + sfx, 'UOM'],
                ['acc_section_rate_input' + sfx, 'RATE'],
                ['acc_section_quantity_no_input' + sfx, 'QUANTITY (NO.)']
            ].forEach(([api, label]) => {
                const f = byApi.get(api);
                if (!f || !f.isVisible || f.readOnly) return;
                if (!hasValue(f)) {
                    problems.push(`[Accessories Details] Row ${rowNo} - ${label}`);
                }
            });
        });

        return problems;

        
    }

        // ── CROSS PRODUCT: the freight TERM must agree across every product on the quote ──
    // Deepanjan (10th September 2026)
    //
    // One quote can now carry several MBCB types, each with its own "Trans.in offer?"
    // picklist. Ex-works / F.O.R is a commercial term of the whole offer (the T&C prints
    // one sentence for it), so it must be the same everywhere: the FIRST product's
    // choice is the master and every other product must match it.
    //
    // Deliberately NOT validated: types of freight and the Transportation KG / Full
    // Vehicle Freight amounts. Those are per-product costs that legitimately differ
    // with weight and quantity, and each PDF section prints its own.
    //
    // Field names differ per product, so fields are matched by ROLE, not by name:
    // any visible picklist whose apiName contains "trans_in_offer".
    //
    // "Master" = the value already saved by ANY OTHER modal (read from _lastValues,
    // excluding this modal's own fields). If nothing is saved yet, this modal's first
    // visible value is the master and the others in this modal must agree with it.
    //
    // Scope: Crash Barrier only, detected by MBCB_Type in the saved data - no other
    // department carries that key. Returns [] everywhere else.
    _validateCrashBarrierFreightConsistency() {
        const problems = [];
        const saved = this._lastValues || {};
        if (!saved.MBCB_Type) return problems;

        const R1 = /trans_in_offer/i;
        const isBlank = v => v === '' || v === null || v === undefined || String(v).trim() === '';
        const norm = v => String(v).trim();

                const mine = [];
        const mineApi = new Set();
        (Array.isArray(this.accordionSections) ? this.accordionSections : []).forEach(sec => {
            if (!sec || !Array.isArray(sec.fields)) return;
            sec.fields.forEach(f => {
                if (!f || !f.apiName || f.type === 'header') return;
                // every field of THIS modal (hidden sections too) is "mine", never another product
                mineApi.add(f.apiName);
                if (sec.isVisible && f.isVisible && f.type === 'picklist' && R1.test(f.apiName)) mine.push({ f, sec });
            });
        });
        if (mine.length === 0) return problems;          // this modal has no freight term

        // Master from OTHER products already saved on this quote.
        let master = null;
                Object.keys(saved).forEach(k => {
            if (master !== null) return;
            if (!R1.test(k) || mineApi.has(k) || /_header$/i.test(k)) return;
            // skip internal flags (<api>__cleared / <api>__manual) - they hold true/false, not a freight term
            if (/__(cleared|manual)$/i.test(k)) return;
            const v = saved[k];
            if (typeof v === 'boolean') return;
            if (!isBlank(v)) master = norm(v);
        });
        const where = master !== null ? 'the product entered first' : 'the first section above';

        // Nothing saved elsewhere yet: this modal's first chosen value is the master.
        if (master === null) {
            const first = mine.find(x => !isBlank(x.f.value));
            if (!first) return problems;
            master = norm(first.f.value);
        }

        mine.forEach(x => {
            if (isBlank(x.f.value)) return;                // blanks are the required-check's job
            if (norm(x.f.value) !== master) {
                problems.push(`[${x.sec.label}] Trans.in offer? must be "${master}" - same as ${where}`);
            }
        });
        return problems;
    }

    validateRequiredFields() {
        let missingFields = [];
 
        this.accordionSections.forEach(sec => {
            // Only check sections that are currently visible
            if (sec.isVisible) {
                sec.fields.forEach(field => {
                    // Ignore headers
                    if (field.type === 'header') return;
 
                    // Check fields that are Visible, Required, and NOT locked as Read-Only
                    if (field.isVisible && field.required && !field.readOnly) {
                        if (field.value === '' || field.value === null || field.value === undefined) {
                            // Grab the label (fallback to API name if label is blank like in grid spaces)
                            let fLabel = this._prettyLabel(sec, field);
 
                            // Push the section name and field name so the user knows exactly where to look
                            missingFields.push(`[${sec.label}] ${fLabel}`);
                        }
                    }

                    // 👉 Positive-value guard: a min-flagged field must not hold 0 /
                    //    negative / below-min. Label may be blank on some inputs, so
                    //    fall back to apiName for the message.
                    if (field.isVisible && !field.readOnly &&
                        field.min !== null && field.min !== undefined) {
                        const raw = field.value;
                        if (raw !== '' && raw !== null && raw !== undefined) {
                            const num = parseFloat(raw);
                            if (isNaN(num) || num < Number(field.min)) {
                                let fLabel = this._prettyLabel(sec, field);
                                missingFields.push(`[${sec.label}] ${fLabel} (must be >= ${field.min})`);
                            }
                        }
                    }
                });
            }
        });

        // Crash Barrier only: an accessory row that has a W/T BEAM picked must also
        // carry UOM, RATE and QUANTITY (NO.). Rows with no beam stay optional, and
        // no field is hidden - see _validateCrashBarrierAccessoryRows.
        missingFields = missingFields.concat(this._validateCrashBarrierAccessoryRows());

        // Crash Barrier cross product: Ex-works / F.O.R must match what other products
        // on this quote already saved - see _validateCrashBarrierFreightConsistency.
        missingFields = missingFields.concat(this._validateCrashBarrierFreightConsistency());


        // Segment Above 5 Additional Accessories (Stadium quote-level block, Lighting Mast /
        // LCLM per-row blocks): RATE + at least one accessory type - see _validateAccessoryBlock.
        missingFields = missingFields.concat(this._validateAccessoryBlock());

        // Octagonal Pole: N.R. foundation must carry dia / length / bolt quantity -
        // see _validateOctagonalNrFoundation. Faizan (16th September 2026)
        missingFields = missingFields.concat(this._validateOctagonalNrFoundation());
 
        if (missingFields.length > 0) {
            // Remove duplicates (Grid rows often have the same column labels repeatedly)
            let uniqueFields = [...new Set(missingFields)];
 
            // Fire the Toast error
            this.dispatchEvent(new ShowToastEvent({
                title: 'Validation Error',
                message: `Please fill in the following required fields:\n${uniqueFields.join('\n')}`,
                variant: 'error'
            }));
            return false; // Tells the apply function to STOP
        }
        return true; // Everything is good, proceed!
    }
 
    // =========================================================
    // 👉 DYNAMIC COLUMN-BY-COLUMN TOTAL CALCULATOR
    // =========================================================
    _calculateGridTotals() {
        let totalsByCol = {};
        let maxActiveCol = 1;
 
        // 1. Loop through all fields to find the max columns and sum the weights
        this.accordionSections.forEach(sec => {
            if (!sec.isVisible) return;
            sec.fields.forEach(f => {
                if (!f.isVisible) return;
 
                // Find the absolute maximum active columns across ANY repeater section
                if (f.isColRepeaterInput) {
                    let colIndex = f.columnCountIndex || 1;
                    if (colIndex > maxActiveCol) {
                        maxActiveCol = colIndex; // Locks in the widest grid
                    }
                }
 
                // Sum up the weights using your JSON flag
                if (f.isWeightTotal === true) {
                    let colIndex = f.columnCountIndex || 1;
                    if (!totalsByCol[colIndex]) totalsByCol[colIndex] = 0;
                    totalsByCol[colIndex] += (Number(f.value) || 0);
                }
 
                // 👉 ADD THIS: Sum up the secret weights!Abhishek saxena
                if (f.secretWeight !== undefined) {
                    let colIndex = f.columnCountIndex || 1;
                    if (!totalsByCol[colIndex]) totalsByCol[colIndex] = 0;
                    totalsByCol[colIndex] += f.secretWeight;
                }
                //end
            });
        });
 
        // 2. 👉 THE FIX: Calculate the exact span sizes ONCE based on maxActiveCol
        let lblSpan = 12;
        let inpSpan = 12;
 
        if (maxActiveCol === 1) { lblSpan = 6; inpSpan = 6; }
        else if (maxActiveCol === 2) { lblSpan = 4; inpSpan = 4; }
        else if (maxActiveCol === 3) { lblSpan = 3; inpSpan = 3; }
        else if (maxActiveCol === 4) { lblSpan = 4; inpSpan = 2; }
        else if (maxActiveCol === 5) { lblSpan = 2; inpSpan = 2; }
        else {
            inpSpan = 1;
            lblSpan = 12 - (maxActiveCol * inpSpan);
            if (lblSpan < 1) lblSpan = 1;
        }
 
        // 3. Build the array for the HTML to render the grid perfectly
        let totalsUI = [];
 
        totalsUI.push({
            id: 'label_total',
            isLabel: true,
            spanClass: `slds-col slds-size_${lblSpan}-of-12`,
            text: 'TOTAL WEIGHT (KG)'
        });
 
        for (let c = 1; c <= maxActiveCol; c++) {
            let colWeight = totalsByCol[c] || 0;
            totalsUI.push({
                id: `col_${c}_total`,
                isLabel: false,
                spanClass: `slds-col slds-size_${inpSpan}-of-12`,
                value: Math.round(colWeight * 1000) / 1000
            });
        }
 
        this.columnTotalsArray = totalsUI;
    }
    // =========================================================
    // 👉 3. ADD THIS FETCH METHOD
    // =========================================================
   // =========================================================
   // 👉 THE DYNAMIC PRICING INJECTOR
   // =========================================================
   async _fetchRateCardData(departmentName) {
    if (!departmentName) return;
 
    try {
        const jsonString = await getRateCardJson({ departmentName: departmentName });
        if (jsonString) {
            const parsedCard = JSON.parse(jsonString);
 
            // 👉 ROUTER: Handle both older arrays and modern dictionaries
            if (Array.isArray(parsedCard)) {
                const rateCardFields = parsedCard.map(field => ({
                    ...field,
                    type: 'hidden'
                }));
 
                if (!this._modalConfig.modalFields) {
                    this._modalConfig.modalFields = [];
                }
                this._modalConfig.modalFields.push({
                    name: 'hidden_rate_card_section',
                    label: 'System Rate Cards',
                    isVisible: false,
                    fields: rateCardFields
                });
            } else {
                // Extracts baseRates into the modal's global state
                const extractedRates = parsedCard.baseRatesMap || parsedCard.baseRates || parsedCard.BASE_RATES || parsedCard;
                this.baseRates = { ...this.baseRates, ...extractedRates };
            }
 
            console.log('✅ Rate Card injected into Math Engine successfully!');
 
            // 👉 FIX 2: DEEP CLONE - Forces LWC to redraw the UI instantly!
            let clonedSections = JSON.parse(JSON.stringify(this.accordionSections));
            
            // Swap array momentarily for calculations
            this.accordionSections = clonedSections;
 
            this._evaluateLookups();
            this._evaluateAllFormulas();
            this._evaluateSectionVisibility();
            this._evaluateAllFormulas();
            this._evaluateDynamicColSpans();
 
            // Apply visual updates
            clonedSections.forEach(sec => {
                sec.fields.forEach(f => this._updateFieldUI(f));
                this._updateSectionUI(sec);
            });
 
            // Reassign the clean cloned array to trigger the HTML to render
            this.accordionSections = [...clonedSections];
        }
    } catch (error) {
        console.error('❌ Failed to fetch Rate Card JSON:', error);
    }
}
// ─────────────────Reetabrata (7th July)────────────────────────────────────────
_clearSegmentCount() {
    this._lastValues.lm_no_of_segment = '';
    this.accordionSections.forEach(sec =>
        sec.fields.forEach(f => {
            if (f.apiName === 'lm_no_of_segment') { f.value = ''; f.userCleared = true; }
        })
    );
    if (this._modalConfig) {
        this._modalConfig.modalFields =
            generateSegmentModal(this._modalConfig.mastType, this._lastValues);
        this.accordionSections =
            this._buildSections(this._modalConfig.modalFields);
    }
}

// ─────────────────Reetabrata (7th July)────────────────────────────────────────


// ========================================================= rajeev 21-july
    // 👉 CROSS-MODAL HEADLESS RECOMPUTE
    // Rebuilds this modal from its cached config + the LATEST combined savedData,
    // runs the SAME math the CALCULATE button runs, and extracts values + line
    // items via the SAME extractor APPLY uses - all without opening/showing the
    // modal, dispatching events, or hitting Apex. Reuses the live instance so
    // _lastValues (and its __manual/__cleared flags) is preserved.
    // =========================================================
    @api
    recomputeHeadless(config, savedData) {
        if (!config) return null;

        const snap = {
            cfg: this._modalConfig,
            sections: this.accordionSections,
            title: this.modalTitle,
            baseRates: this.baseRates,
            structural: this._structuralApis,
            open: this.isModalOpen
        };

        try {
            const cfg = JSON.parse(JSON.stringify(config, (key, value) => {
                if ((key === 'controllingField' || key === 'disableControllingField') && Array.isArray(value)) {
                    return value.join(',');
                }
                return value;
            }));

            this._modalConfig = cfg;
            this.modalTitle = cfg.title || 'ESTIMATOR';
            this.baseRates = cfg.baseRates || {};

            // Merge the latest combined data, exactly like openModal does. Because we
            // reuse the same instance, prior __manual/__cleared flags in _lastValues
            // are preserved (manual overrides are not lost).
            this._lastValues = { ...this._lastValues, ...(savedData || {}) };
            if (cfg.preRegisterApis) {
                Object.keys(cfg.preRegisterApis).forEach(a => {
                    if (!(a in this._lastValues)) this._lastValues[a] = cfg.preRegisterApis[a];
                });
            }

            this.accordionSections = this._buildSections(cfg.modalFields || []);
            this._buildStructuralApiSet();

            // Identical to the CALCULATE button. No async pricing/blueprint/PV fetch -
            // those rates are already in savedData from the original apply and reused.
            this._calculateNow();

            this._headlessMode = true;
            this._headlessResult = null;
            this._applyNow();               // fills _headlessResult, no event, no reset
            return this._headlessResult;

        } catch (e) {
            console.error('recomputeHeadless error:', e);
            return null;
        } finally {
            this._headlessMode = false;
            this._headlessResult = null;
            // _lastValues intentionally NOT restored (recomputed values must persist).
            this._modalConfig = snap.cfg;
            this.accordionSections = snap.sections;
            this.modalTitle = snap.title;
            this.baseRates = snap.baseRates;
            this._structuralApis = snap.structural;
            this.isModalOpen = snap.open;
        }
    }
// per-subtype checkbox tick/untick (compact per-column widget)
    handleSubtypeCheckToggle(event) {
        const fieldApi = event.currentTarget.dataset.name;
        const subtype  = event.currentTarget.dataset.subtype;
        const checked  = event.target.checked === true;
        let rows = this._sqgGetSelection(fieldApi);
        if (checked) {
            if (!rows.some(r => r.subtype === subtype)) rows.push({ subtype: subtype, qty: null });
        } else {
            rows = rows.filter(r => r.subtype !== subtype);
        }
        this._sqgSaveSelection(fieldApi, rows);
        const field = this._sqgFindField(fieldApi);
        if (field) {
            this._sqgEnrich(field);
            this._sqgWriteTargets(field);
            this.accordionSections = [...this.accordionSections];
        }
    }

}
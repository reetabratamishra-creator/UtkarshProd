import { LightningElement, track, api } from 'lwc';
import getRateCardJson from '@salesforce/apex/CreateQuoteController.getRateCardJson';

/*
 * SOLAR STRUCTURE CONFIG — Deepanjan (1st August 2026)
 *
 * WHAT CHANGED IN THIS PASS
 *   1. "HDG MMS/Carport Structure" split into two separate materials with
 *      identical options and identical calculation.
 *   2. "PS" removed from the HDG material list.
 *   3. HBM -> H-Beam and WBM -> W-Beam, value as well as label.
 *   4. "Minimum Micron Specified (Auto +20 Average)" moved from a single global
 *      checkbox to one checkbox per line, shown only on HDG MMS lines.
 *   5. Location removed everywhere - field, line state and saved payload.
 *   6. Four Black variants added to the Galvalume & Black section. They price
 *      off the Black Metal base rate and carry NO zinc, exactly like Black
 *      Metal itself.
 *   +  The hardcoded 73083.2 beam quote and the hardcoded zincRatio 4.5 are
 *      gone. Verified against the client rate card: the I-Beam block uses the
 *      same base-rate + micron formula as HDG MMS, so beams now run through the
 *      one HDG calculation instead of a special case.
 *   +  Contribution for thickness >= 3.0 corrected from 3000 to 2000, which is
 *      what the client rate card shows for both the 3.0 MM and 4.0 MM blocks.
 *
 * Everything else is byte-for-byte the behaviour it had before.
 */
export default class SolarStructureConfig extends LightningElement {

    // ── Material name constants ──────────────────────────────────────────────
    // Rename here and the whole component follows; nothing else hardcodes them.
    static HDG_MMS   = 'HDG MMS Structure';
    static CARPORT   = 'Carport Structure';
    static PIERS     = 'Piers (W-Beam) for Tracker';

    // The Black variants added to the Galvalume section. All four price off the
    // Black Metal base rate and, being black, take no zinc cost.
    static BLACK_METAL    = 'Black Metal';
    static GALV_STRUCTURE = 'Galvalume Structure';
    static BLACK_VARIANTS = [
        'I-Beam (Black)',
        'W-Beam (Black)',
        'H-Beam (Black)',
        'Piers for Tracker (Black)'
    ];

    /*
     * Rate-card fallbacks. A renamed or newly split material has no BASE_RATES
     * key until the client re-saves the rate card, and a missing key means
     * steelRate 0, which means a quote of 0. Falling back to the old key keeps
     * existing quotes pricing correctly in the meantime. Delete an entry once
     * its real rate has been entered in the Rate Card Manager.
     */
    static LEGACY_RATE_FALLBACK = {
        'HDG MMS Structure': 'HDG MMS/Carport Structure',
        'Carport Structure': 'HDG MMS/Carport Structure',
        'H-Beam':            'HBM',
        'W-Beam':            'WBM',
        // Piers was renamed for the label only - the rate card still holds the
        // old key, so keep pricing off it until the client re-saves the card.
        'Piers (W-Beam) for Tracker': 'Piers for Tracker'
    };

    // Saved lines from before the rename still carry the old material values.
    static LEGACY_MATERIAL_ALIAS = {
        'HBM': 'H-Beam',
        'WBM': 'W-Beam',
        'Piers for Tracker': 'Piers (W-Beam) for Tracker'
    };

    /*
     * Galvalume grade: shown and stored as YSD 350 / YSD 550 from 9th August
     * 2026. The rate card is still keyed on the old strings, so the lookup maps
     * forward; quotes saved before the rename map backward on load.
     */
    static GALV_GRADE_RATE_KEY = {
        'YSD 350': 'AZ150 GSM (350 MPA)',
        'YSD 550': 'AZ200 GSM (550 MPA)'
    };

    static LEGACY_GALV_GRADE_ALIAS = {
        'AZ150 GSM (350 MPA)': 'YSD 350',
        'AZ200 GSM (550 MPA)': 'YSD 550'
    };

    @track includeHdg = false;
    @track includeGalv = false;

    get toggleHdgLabel() { return this.showHdgCalculations ? 'Hide Internal Costing' : 'Show Internal Costing'; }
    get toggleHdgIcon() { return this.showHdgCalculations ? 'utility:hide' : 'utility:preview'; }
    get toggleGalvLabel() { return this.showGalvCalculations ? 'Hide Internal Costing' : 'Show Internal Costing'; }
    get toggleGalvIcon() { return this.showGalvCalculations ? 'utility:hide' : 'utility:preview'; }

    _uom = 'Weight';
    @api savedData = null;
    @api isReadOnly = false;

    @api
    get uom() {
        return this._uom;
    }
    set uom(value) {
        this._uom = value;
        // Refetch rates when UoM changes dynamically
        if (this.hasConnected) {
            this.fetchBaseRates();
        }
    }

    hasConnected = false;

    get isPCs() {
        return this._uom && this._uom.toLowerCase() === 'pcs';
    }

    get modalTitle() {
        return this.isPCs ? 'SOLAR STRUCTURE (PCS ESTIMATOR)' : 'SOLAR STRUCTURE (WEIGHT ESTIMATOR)';
    }

    @track dynamicBaseRates = {};
    @track zincRateFromCard = 0;  // pulled from Global Zinc Rate in rate card

    @track hdgCount = 1;
    @track galvCount = 1;

    @track hdgLines = [];
    @track galvLines = [];

    @track showHdgCalculations = false;
    @track showGalvCalculations = false;

    toggleHdgCalculations() {
        this.showHdgCalculations = !this.showHdgCalculations;
    }

    toggleGalvCalculations() {
        this.showGalvCalculations = !this.showGalvCalculations;
    }

    // Dropdown Options
    // "HDG MMS/Carport Structure" is now two entries; "PS" removed; HBM/WBM
    // renamed to their full names.
    @track hdgMaterialOptions = [
        { label: SolarStructureConfig.HDG_MMS, value: SolarStructureConfig.HDG_MMS },
        { label: SolarStructureConfig.CARPORT, value: SolarStructureConfig.CARPORT },
        { label: SolarStructureConfig.PIERS,   value: SolarStructureConfig.PIERS },
        { label: 'I-BEAM',                     value: 'I-BEAM' },
        { label: 'RSJ',                        value: 'RSJ' },
        { label: 'H-Beam',                     value: 'H-Beam' }
    ];
    @track hdgThicknessOptions = [
        { label: '2.0', value: '2' },
        { label: '2.5', value: '2.5' },
        { label: '3.0', value: '3' },
        { label: '4.0', value: '4' }
    ];
    @track hdgMicronOptions = [
        { label: '60', value: '60' },
        { label: '70', value: '70' },
        { label: '80', value: '80' },
        { label: '90', value: '90' },
        { label: '100', value: '100' },
        { label: '110', value: '110' },
        { label: '120', value: '120' },
        { label: '130', value: '130' },
        { label: '140', value: '140' },
        { label: '150', value: '150' }
    ];
    // Four Black variants added below the two originals.
    @track galvMaterialOptions = [
        { label: 'Black Metal',                value: 'Black Metal' },
        { label: 'Galvalume Structure',        value: 'Galvalume Structure' },
        { label: 'I-Beam (Black)',             value: 'I-Beam (Black)' },
        { label: 'W-Beam (Black)',             value: 'W-Beam (Black)' },
        { label: 'H-Beam (Black)',             value: 'H-Beam (Black)' },
        { label: 'Piers for Tracker (Black)',  value: 'Piers for Tracker (Black)' }
    ];
    @track galvThicknessOptions = [
        { label: '0.9', value: '0.9' },
        { label: '1.0', value: '1.0' },
        { label: '1.1', value: '1.1' },
        { label: '1.2', value: '1.2' },
        { label: '1.3', value: '1.3' },
        { label: '1.4', value: '1.4' },
        { label: '1.5', value: '1.5' },
        { label: '1.6', value: '1.6' },
        { label: '1.7', value: '1.7' },
        { label: '1.8', value: '1.8' },
        { label: '1.9', value: '1.9' },
        { label: '2.0', value: '2.0' },
        { label: '2.5', value: '2.5' },
        { label: '3.0', value: '3' }
    ];
    @track hdgGradeMap = {};
    @track galvGradeMap = {};

    connectedCallback() {
        this.hasConnected = true;
        this.fetchBaseRates();
        if (this.savedData && this.savedData.Internal_State) {
            let state = this.savedData.Internal_State;
            this.hdgLines = JSON.parse(JSON.stringify(state.hdgLines));
            this.galvLines = JSON.parse(JSON.stringify(state.galvLines));
            this.includeHdg = state.includeHdg;
            this.includeGalv = state.includeGalv;
            this.hdgCount = state.hdgCount;
            this.galvCount = state.galvCount;

            /*
             * Migration for lines saved before this release:
             *   - HBM / WBM become H-Beam / W-Beam
             *   - the old single global isMinimumMicron becomes a per-line flag
             *   - Location is dropped
             */
            let legacyGlobalMinMicron = !!state.isMinimumMicron;
            this.hdgLines.forEach(line => {
                let alias = SolarStructureConfig.LEGACY_MATERIAL_ALIAS[line.material];
                if (alias) line.material = alias;
                if (line.isMinimumMicron === undefined) {
                    line.isMinimumMicron = legacyGlobalMinMicron;
                }
                if (line.isCustomMode === undefined) line.isCustomMode = false;
                if (line.customSteelRate === undefined) line.customSteelRate = 0;
                // Pre-existing Custom lines still hold a grade; clear it so the
                // locked field reads blank everywhere, not just after a toggle.
                this.applyCustomModeGrade(line, this.getHdgGradeOptions(line.material));
                delete line.location;
            });
            this.galvLines.forEach(line => {
                // Saved before the YSD rename - move the internal grade across.
                // displayGrade (Print YSD) is left exactly as it was, so an old
                // quote keeps printing whatever it printed before.
                let gAlias = SolarStructureConfig.LEGACY_GALV_GRADE_ALIAS[line.materialGrade];
                if (gAlias) line.materialGrade = gAlias;
                if (line.isCustomMode === undefined) line.isCustomMode = false;
                if (line.customSteelRate === undefined) line.customSteelRate = 0;
            });
        } else {
            this.hdgLines = [this.createEmptyHdgLine(0)];
            this.galvLines = [this.createEmptyGalvLine(0)];
        }
        this.reindexHdg();
        this.reindexGalv();
    }

    fetchBaseRates() {
        // Query the parent department where quoteRateCard saves the JSON payload
        let dept = 'Solar Structure - Department';
        getRateCardJson({ departmentName: dept })
            .then(result => {
                if (result) {
                    try {
                        let config = typeof result === 'string' ? JSON.parse(result) : result;

                        if (Array.isArray(config)) {
                            let targetApiName = this.isPCs ? 'rate_pcs' : 'rate_wt';
                            let baseRateObj = config.find(c => c.apiName === targetApiName);
                            // ❌ No generic fallback — Pcs and Weight must never bleed into each other
                            this.dynamicBaseRates = baseRateObj ? (baseRateObj.BASE_RATES || {}) : {};

                            // Extract Global Zinc Rate (stored as {apiName:'hdg_zinc_rate', formula: '<value>'})
                            let zincEntry = config.find(c => c.apiName === 'hdg_zinc_rate');
                            if (zincEntry && zincEntry.formula) {
                                this.zincRateFromCard = Number(zincEntry.formula) || 0;
                            }

                            let mergedConfig = {};
                            config.forEach(c => Object.assign(mergedConfig, c));
                            config = mergedConfig;
                        } else {
                            this.dynamicBaseRates = config.BASE_RATES || config;
                        }

                        if (config.HDG_MATERIAL_OPTIONS) this.hdgMaterialOptions = config.HDG_MATERIAL_OPTIONS.map(opt => ({label: opt, value: opt}));
                        if (config.HDG_THICKNESS_OPTIONS) this.hdgThicknessOptions = config.HDG_THICKNESS_OPTIONS.map(opt => ({label: opt, value: opt}));
                        if (config.HDG_MICRON_OPTIONS) this.hdgMicronOptions = config.HDG_MICRON_OPTIONS.map(opt => ({label: opt, value: opt}));
                        if (config.GALV_MATERIAL_OPTIONS) this.galvMaterialOptions = config.GALV_MATERIAL_OPTIONS.map(opt => ({label: opt, value: opt}));
                        if (config.GALV_THICKNESS_OPTIONS) this.galvThicknessOptions = config.GALV_THICKNESS_OPTIONS.map(opt => ({label: opt, value: opt}));
                        if (config.HDG_GRADE_MAP) this.hdgGradeMap = config.HDG_GRADE_MAP;
                        if (config.GALV_GRADE_MAP) this.galvGradeMap = config.GALV_GRADE_MAP;

                        this.hdgLines.forEach(line => {
                            line.gradeOptions = this.getHdgGradeOptions(line.material);
                            // A Custom line's grade is free-typed - never snap it
                            // back to the picklist on a rates refresh.
                            if (!line.isCustomMode && !line.gradeOptions.find(o => o.value === line.materialGrade)) {
                                line.materialGrade = line.gradeOptions.length ? line.gradeOptions[0].value : '';
                            }
                            this.calculateHdg(line);
                        });
                        this.reindexHdg();

                        this.galvLines.forEach(line => {
                            line.gradeOptions = this.getGalvGradeOptions(line.material);
                            /*
                             * Map an old AZ-style grade across BEFORE the snap
                             * below. Without this an AZ200 line would fail the
                             * find(), fall to gradeOptions[0] and silently drop
                             * from YSD 550 to YSD 350.
                             */
                            let gAlias = SolarStructureConfig.LEGACY_GALV_GRADE_ALIAS[line.materialGrade];
                            if (gAlias) line.materialGrade = gAlias;
                            // A Custom line's grade is free-typed - never snap it
                            // back to the picklist on a rates refresh.
                            if (!line.isCustomMode && !line.gradeOptions.find(o => o.value === line.materialGrade)) {
                                line.materialGrade = line.gradeOptions.length ? line.gradeOptions[0].value : '';
                            }
                            this.calculateGalv(line);
                        });
                        this.reindexGalv();
                    } catch (e) {
                        console.error('Failed to parse dynamic base rates', e);
                    }
                }
            })
            .catch(error => {
                console.error('Error fetching base rates', error);
            });
    }

    // ── Per-line display flags ───────────────────────────────────────────────
    // The Minimum Micron checkbox is shown only on HDG MMS lines, so the flag
    // has to be recomputed whenever a material changes.
    stampHdgFlags(line) {
        line.isPiersForTracker = (line.material === SolarStructureConfig.PIERS);
        /*
         * Minimum Micron applies to the HDG MMS material only. The checkbox is
         * hidden on every other material, and the +20 is gated on the material
         * in calculateHdg as well, so a hidden checkbox can never quietly feed
         * the calculation. The stored tick is deliberately NOT wiped — switch
         * material away and back and the user's choice is still there.
         */
        line.showMinMicron = (line.material === SolarStructureConfig.HDG_MMS);
        this.stampModeFlags(line);
    }

    /*
     * Template helpers. LWC templates cannot negate, so the inverse flag has to
     * be stamped here. The costing panel is forced open on a Custom line -
     * otherwise the user would have no way to reach the inputs they just
     * switched on.
     */
    stampModeFlags(line) {
        if (line.isCustomMode === undefined) line.isCustomMode = false;
        if (line.customSteelRate === undefined) line.customSteelRate = 0;
        line.modeLabel = line.isCustomMode ? 'Custom Mode' : 'Standard Mode';
    }

    reindexHdg() {
        // displayIndex was never assigned anywhere, so every card header read
        // "Item " with a blank number. With a toggle on each card now, the
        // number matters.
        this.hdgLines.forEach((line, i) => {
            line.displayIndex = i + 1;
            this.stampHdgFlags(line);
        });
        this.hdgLines = [...this.hdgLines];
    }

    reindexGalv() {
        this.galvLines.forEach((line, i) => {
            line.displayIndex = i + 1;
            line.isNotGalvalume = (line.material !== SolarStructureConfig.GALV_STRUCTURE);
            this.stampModeFlags(line);
        });
        this.galvLines = [...this.galvLines];
    }

    createEmptyHdgLine(index) {
        return {
            id: index,
            key: `hdg_${index}`,
            material: SolarStructureConfig.HDG_MMS,
            materialGrade: 'E350',
            displayGrade: 'E350',
            gradeOptions: [{label: 'E350', value: 'E350'}, {label: 'E250', value: 'E250'}],
            description: '',
            thickness: '-',
            micronThickness: '-',
            isMinimumMicron: false,
            isCustomMode: false,
            customSteelRate: 0,
            showMinMicron: true,
            zincRate: 0,
            isPiersForTracker: false,
            totalWeight: 0,
            unitWeight: 0,
            quantity: 1,
            freight: 0,
            discount: 0,
            steelRate: 0,
            totalSteelRate: 0,
            zincRatio: 0,
            giCostTotal: 0,
            miscTotal: 0,
            otherCostTotal: 0,
            totalCost: 0,
            quoteMt: 0,
            totalQuoteValue: 0
        };
    }

    createEmptyGalvLine(index) {
        return {
            id: index,
            key: `galv_${index}`,
            material: SolarStructureConfig.GALV_STRUCTURE,
            materialGrade: 'E550',
            displayGrade: 'E550',
            gradeOptions: [{label: 'E550', value: 'E550'}, {label: 'E450', value: 'E450'}, {label: 'E350', value: 'E350'}, {label: 'E250', value: 'E250'}],
            coating: 'AZ150',
            coatingOptions: [{label: 'AZ150', value: 'AZ150'}, {label: 'AZ200', value: 'AZ200'}, {label: 'AZ250', value: 'AZ250'}, {label: 'AZ300', value: 'AZ300'}],
            isNotGalvalume: false,
            isCustomMode: false,
            customSteelRate: 0,
            description: '',
            thickness: '-',
            totalWeight: 0,
            unitWeight: 0,
            quantity: 1,
            freight: 0,
            discount: 0,
            steelRate: 0,
            totalSteelRate: 0,
            miscTotal: 0,
            otherCostTotal: 0,
            totalCost: 0,
            quoteMt: 0,
            finalMtRate: 0,
            finalQuoteBlack: 0,
            finalQuoteInclThickness: 0,
            totalQuoteValue: 0
        };
    }

    // ── Rate-card key resolution ─────────────────────────────────────────────
    // Returns the first key that actually exists in the rate card, so a split
    // or renamed material keeps pricing off its old key until the client
    // re-saves the Rate Card Manager with the new names.
    /*
     * Base rate. The Rate Card Manager grid writes EVERY row it knows about,
     * so a material the client has not priced yet is stored as 0 rather than
     * being absent — which means "key exists" is not a safe test here. A base
     * rate of 0 is never meaningful anyway (the steelRate > 0 guard would zero
     * the quote), so a zero is treated as unset and the fallback key is tried.
     */
    resolveBase(...keys) {
        for (let k of keys) {
            let v = k && this.dynamicBaseRates ? Number(this.dynamicBaseRates[k] || 0) : 0;
            if (v) return v;
        }
        return 0;
    }

    /*
     * Grade delta. Unlike a base rate, 0 IS a meaningful delta (E250 = base
     * + 0), so this one only falls through when the key is genuinely absent.
     * Falling through on a zero would silently re-apply the old material's
     * delta and overcharge.
     */
    resolveDelta(...keys) {
        for (let k of keys) {
            if (k && this.dynamicBaseRates && this.dynamicBaseRates[k] !== undefined) {
                return Number(this.dynamicBaseRates[k] || 0);
            }
        }
        return 0;
    }

    hdgRateKeys(material) {
        let legacy = SolarStructureConfig.LEGACY_RATE_FALLBACK[material];
        return legacy ? [material, legacy] : [material];
    }

    // All four Black variants price off the Black Metal base rate.
    /*galvRateKeys(material) {
        return SolarStructureConfig.BLACK_VARIANTS.includes(material)
             ? [SolarStructureConfig.BLACK_METAL]
             : [material];
    }*/

    // All Black variants now price off their own distinct base rates and deltas
    galvRateKeys(material) {
        return [material];
    }

    // Black Metal and the four Black variants share every black-specific rule:
    // no zinc, the higher other-cost figure, and no thickness uplift.
    isBlackMaterial(material) {
        return material === SolarStructureConfig.BLACK_METAL
            || SolarStructureConfig.BLACK_VARIANTS.includes(material);
    }

    getHdgGradeOptions(material) {
        if (this.hdgGradeMap && this.hdgGradeMap[material]) {
            return this.hdgGradeMap[material].map(opt => ({label: opt, value: opt}));
        }
        if (['I-BEAM', 'H-Beam', 'W-Beam', 'RSJ'].includes(material)) {
            return [{label: 'E350', value: 'E350'}, {label: 'E450', value: 'E450'}, {label: 'E550', value: 'E550'}];
        }
        if (material === SolarStructureConfig.HDG_MMS || material === SolarStructureConfig.CARPORT) {
            return [{label: 'E250', value: 'E250'}, {label: 'E350', value: 'E350'}, {label: 'E450', value: 'E450'}, {label: 'E550', value: 'E550'}];
        }
        // Special Grade dropped; Piers now carries the same three grades as the beams.
        if (material === SolarStructureConfig.PIERS) {
            return [{label: 'E350', value: 'E350'}, {label: 'E450', value: 'E450'}, {label: 'E550', value: 'E550'}];
        }
        return [{label: 'E250', value: 'E250'}, {label: 'E350', value: 'E350'}, {label: 'E450', value: 'E450'}, {label: 'E550', value: 'E550'}];
    }

    getGalvGradeOptions(material) {
        if (this.galvGradeMap && this.galvGradeMap[material]) {
            return this.galvGradeMap[material].map(opt => ({label: opt, value: opt}));
        }

        if (SolarStructureConfig.BLACK_VARIANTS.includes(material)) {
            return [
                {label: 'E350', value: 'E350'}, 
                {label: 'E450', value: 'E450'}, 
                {label: 'E550', value: 'E550'}
            ];
        }
        // The Black variants inherit Black Metal's grade list.
        if (this.isBlackMaterial(material)) {
            return [{label: 'E250', value: 'E250'}, {label: 'E350', value: 'E350'}, {label: 'E450', value: 'E450'}, {label: 'E550', value: 'E550'}];
        }
        // Renamed to YSD 350 / YSD 550 - label AND value. The value has to change
        // as well because Custom Mode renders this as a free-text input bound to
        // materialGrade, which shows the raw value rather than the label. The
        // rate card still holds the old strings, so GALV_GRADE_RATE_KEY below
        // maps back to them at lookup time. Deepanjan (9th August 2026)
        if (material === SolarStructureConfig.GALV_STRUCTURE) return [{label: 'YSD 350', value: 'YSD 350'}, {label: 'YSD 550', value: 'YSD 550'}];
        return [{label: 'E250', value: 'E250'}, {label: 'E350', value: 'E350'}, {label: 'E450', value: 'E450'}, {label: 'E550', value: 'E550'}];
    }

    handleIncludeHdg(event) { if (this.isReadOnly) return; this.includeHdg = event.target.checked; }
    handleIncludeGalv(event) { if (this.isReadOnly) return; this.includeGalv = event.target.checked; }

    // Minimum Micron is now per line rather than one switch for the whole modal.
    handleHdgMinMicronToggle(event) {
        if (this.isReadOnly) return;
        const index = parseInt(event.target.dataset.index, 10);
        let line = this.hdgLines[index];
        line.isMinimumMicron = event.target.checked;
        this.calculateHdg(line);
        this.reindexHdg();
    }

    // Standard <-> Custom. In Custom the base steel rate is typed on the item
    // row; switching back to Standard makes it come from the rate card again.
    handleHdgModeToggle(event) {
        if (this.isReadOnly) return;
        const index = parseInt(event.target.dataset.index, 10);
        let line = this.hdgLines[index];
        line.isCustomMode = event.target.checked;
        // Entering Custom seeds the box with whatever the rate card was giving,
        // so the user edits a real number instead of starting from blank.
        if (line.isCustomMode && !line.customSteelRate) {
            line.customSteelRate = line.steelRate || 0;
        }
        this.applyCustomModeGrade(line, this.getHdgGradeOptions(line.material));
        this.calculateHdg(line);
        this.reindexHdg();
    }

    handleGalvModeToggle(event) {
        if (this.isReadOnly) return;
        const index = parseInt(event.target.dataset.index, 10);
        let line = this.galvLines[index];
        line.isCustomMode = event.target.checked;
        // Entering Custom seeds the box with whatever the rate card was giving,
        // so the user edits a real number instead of starting from blank.
        if (line.isCustomMode && !line.customSteelRate) {
            line.customSteelRate = line.steelRate || 0;
        }
        this.calculateGalv(line);
        this.reindexGalv();
    }

    /*
     * HDG ONLY. Custom Mode locks the HDG "Price Grade" field and leaves it
     * blank - the
     * grade means nothing there, because the steel rate is typed on the row
     * instead of being looked up. The value in force before the switch is kept
     * on the line so coming back to Standard restores exactly what the user had.
     *
     * Standard Mode behaviour is unchanged, with one guard: it must never be
     * left on a blank grade. The rate-card delta key is `material|grade`, so a
     * blank grade resolves to 0 and the line would quietly lose its grade
     * uplift. If nothing can be restored, the first option is used - the same
     * fallback the rates refresh already applies. Deepanjan (9th August 2026)
     *
     * Print Grade / Print YSD (displayGrade) is NOT touched: that is the field
     * the offer PDF prints, and blanking it would empty the document.
     */
    applyCustomModeGrade(line, gradeOptions) {
        let options = gradeOptions || [];
        if (line.isCustomMode) {
            if (line.materialGrade) line.gradeBeforeCustom = line.materialGrade;
            line.materialGrade = '';
            return;
        }
        if (line.materialGrade) return;
        let restored = line.gradeBeforeCustom;
        let isValid  = restored && options.some(o => o.value === restored);
        line.materialGrade = isValid ? restored : (options.length ? options[0].value : '');
    }

    handleHdgCountChange(event) {
        if (this.isReadOnly) return;
        let newCount = parseInt(event.target.value) || 1;
        if (newCount < 1) newCount = 1;
        this.hdgCount = newCount;

        while (this.hdgLines.length < this.hdgCount) {
            this.hdgLines.push(this.createEmptyHdgLine(this.hdgLines.length));
        }
        if (this.hdgLines.length > this.hdgCount) {
            this.hdgLines = this.hdgLines.slice(0, this.hdgCount);
        }
        this.reindexHdg();
    }

    handleGalvCountChange(event) {
        if (this.isReadOnly) return;
        let newCount = parseInt(event.target.value) || 1;
        if (newCount < 1) newCount = 1;
        this.galvCount = newCount;

        while (this.galvLines.length < this.galvCount) {
            this.galvLines.push(this.createEmptyGalvLine(this.galvLines.length));
        }
        if (this.galvLines.length > this.galvCount) {
            this.galvLines = this.galvLines.slice(0, this.galvCount);
        }
        this.reindexGalv();
    }

    handleHdgFieldChange(event) {
        if (this.isReadOnly) return;
        const index = parseInt(event.target.dataset.index);
        const field = event.target.dataset.field;
        const value = event.target.value;

        let line = this.hdgLines[index];
        line[field] = value;

        if (['totalWeight', 'unitWeight', 'quantity', 'freight', 'discount', 'customSteelRate'].includes(field)) {
            line[field] = parseFloat(value) || 0;
        }

        if (field === 'material') {
            const gradeOptions = this.getHdgGradeOptions(line.material);
            line.gradeOptions = gradeOptions;
            line.materialGrade = gradeOptions[0].value;
            line.displayGrade = line.materialGrade;
            // Both halves of the old combined material behave the same way here.
            if (line.material === SolarStructureConfig.HDG_MMS
                    || line.material === SolarStructureConfig.CARPORT) {
                line.thickness = '-';
            }
            this.stampHdgFlags(line);
        }

        if (field === 'materialGrade') {
            line.displayGrade = value;
        }

        this.calculateHdg(line);
        this.reindexHdg();
    }

    calculateHdg(line) {
        /*
         * ONE calculation for every HDG material. Verified against the client
         * rate card: the "I BEAM HDG E350 4.0 MM" block uses the same base-rate
         * and micron-based zinc formula as the HDG MMS blocks, so the old flat
         * 73083.2 beam quote and the flat zincRatio 4.5 have both been removed.
         *
         * Base rate = plain material key (e.g. "HDG MMS Structure")
         * Delta     = material|grade key  (e.g. "HDG MMS Structure|E350")
         * Final     = base + delta
         */
        let keys     = this.hdgRateKeys(line.material);
        let baseRate = this.resolveBase(...keys);
        let delta    = this.resolveDelta(...keys.map(k => `${k}|${line.materialGrade}`));
        /*
         * Custom Mode: the base steel rate is typed on the item row instead of
         * coming from the rate card. Nothing else about the calculation moves.
         */
        line.steelRate = line.isCustomMode
                       ? (parseFloat(line.customSteelRate) || 0)
                       : (baseRate + delta);

        line.totalSteelRate = ((line.material === SolarStructureConfig.PIERS ? 0.01 : 0.005) + 1) * line.steelRate;

        // zinc percent — the +20 minimum-to-average conversion is now driven by
        // this line's own checkbox, which only appears on HDG MMS lines.
        let micron = parseFloat(line.micronThickness) || 0;
        if (line.isMinimumMicron && line.material === SolarStructureConfig.HDG_MMS && micron > 0) {
            micron += 20; // Auto convert min to avg — HDG MMS only
        }
        let thickness = parseFloat(line.thickness) || 1;
        let zincMultiplier = (line.thickness === '2.5') ? 1.4 : (line.thickness === '3.0' || line.thickness === '3') ? 1.5 : (line.thickness === '4.0' || line.thickness === '4') ? 1.4 : 1.303;

        /*
         * One shared zinc formula for the section — the old flat 4.5 for beams
         * is gone, so I-Beam / H-Beam / W-Beam / RSJ now derive zinc the same
         * way HDG MMS does, which is what the client rate card's I-Beam block
         * shows.
         *
         * Piers for Tracker keeps its original flat 5.0. Nothing in the rate
         * card covers Piers, so there was no evidence to replace it with — left
         * exactly as it was.
         */
        let computedZinc = (line.material === SolarStructureConfig.PIERS)
                         ? 5.0
                         : ((255 / thickness) * (7.093 * micron) / 10000) * zincMultiplier;
        line.zincRatio = computedZinc;

        line.zincRate = this.zincRateFromCard || 0;
        line.giCostTotal = (line.zincRate * (line.zincRatio / 100)) + 2000;
        line.miscTotal = line.freight + 3000;
        line.otherCostTotal = (line.thickness === '2') ? 1500 : 2000;

        line.totalCost = 300 + line.miscTotal + line.giCostTotal + line.totalSteelRate;

        // Rate card shows 1000 at 2.0 MM and 2000 at 2.5, 3.0 and 4.0 MM.
        let hdg_contribution = (line.thickness === '2.0' || line.thickness === '2') ? 1000 : (line.thickness === '2.5') ? 2000 : (thickness >= 3.0) ? 2000 : 1000;

        line.quoteMt = (line.totalCost + hdg_contribution) - line.discount;

        if (line.steelRate > 0) {
            line.finalMtRate = line.quoteMt;
            if (this.isPCs) {
                line.totalQuoteValue = Math.round(line.finalMtRate * line.unitWeight * line.quantity * 10) / 10;
            } else {
                line.totalQuoteValue = Math.round(line.finalMtRate * 10) / 10;
            }
        } else {
            line.finalMtRate = 0;
            line.totalQuoteValue = 0;
        }
    }

    handleGalvFieldChange(event) {
        if (this.isReadOnly) return;
        const index = parseInt(event.target.dataset.index);
        const field = event.target.dataset.field;
        const value = event.target.value;

        let line = this.galvLines[index];
        line[field] = value;

        if (['totalWeight', 'unitWeight', 'quantity', 'freight', 'discount', 'customSteelRate'].includes(field)) {
            line[field] = parseFloat(value) || 0;
        }

        if (field === 'material') {
            const gradeOptions = this.getGalvGradeOptions(line.material);
            line.gradeOptions = gradeOptions;
            line.materialGrade = gradeOptions[0].value;
            line.displayGrade = line.materialGrade;
            line.isNotGalvalume = (line.material !== SolarStructureConfig.GALV_STRUCTURE);
        }

        if (field === 'materialGrade') {
            line.displayGrade = value;
        }

        this.calculateGalv(line);
        this.reindexGalv();
    }

    calculateGalv(line) {
        // Base rate = plain material key (e.g. "Black Metal")
        // Delta     = material|grade key  (e.g. "Black Metal|E350")
        // For Galvalume: base = material|grade, delta = material|grade|coating
        // The four Black variants resolve to the Black Metal key, so they price
        // off Black Metal while still printing their own material name.
        let baseRate = 0;
        let delta    = 0;
        let isBlack  = this.isBlackMaterial(line.material);

        if (line.material === SolarStructureConfig.GALV_STRUCTURE) {
            // Base = "Galvalume Structure|YSD 350", falling back to the old
            // "Galvalume Structure|AZ150 GSM (350 MPA)" the rate card still uses.
            let rates       = this.dynamicBaseRates || {};
            let safeCoating = line.coating === 'AZ 150' ? 'AZ150' : line.coating;
            let oldGrade    = SolarStructureConfig.GALV_GRADE_RATE_KEY[line.materialGrade];
            let gradeKey    = `${line.material}|${line.materialGrade}`;
            let coatingKey  = `${line.material}|${line.materialGrade}|${safeCoating}`;
            baseRate = Number(rates[gradeKey]
                           || (oldGrade ? rates[`${line.material}|${oldGrade}`] : 0) || 0);
            delta    = Number(rates[coatingKey]
                           || (oldGrade ? rates[`${line.material}|${oldGrade}|${safeCoating}`] : 0) || 0);
        } else {
            // Black Metal, the Black variants and others: base = plain material
            // key, delta = material|grade.
            let keys = this.galvRateKeys(line.material);
            baseRate = this.resolveBase(...keys);
            delta    = this.resolveDelta(...keys.map(k => `${k}|${line.materialGrade}`));
        }

        // Custom Mode: base steel rate typed on the item row, not looked up.
        line.steelRate = line.isCustomMode
                       ? (parseFloat(line.customSteelRate) || 0)
                       : (baseRate + delta);

        line.totalSteelRate = 1.005 * line.steelRate;
        line.miscTotal = line.freight + 3000 + 300;
        line.otherCostTotal = (isBlack ? 2000 : 1500);

        line.totalCost = line.miscTotal + line.totalSteelRate;
        line.quoteMt = (line.totalCost + 1000) - line.discount;

        /*
         * Grade pricing now lives ENTIRELY in the rate card deltas
         * (E250 +0 / E350 +3000 / E450 +4000 / E550 +5000, per the client
         * sheet), so the old hardcoded +3000 for E350 is gone — keeping it
         * would double-charge E350 to base + 6000.
         */
        line.finalQuoteBlack = line.quoteMt;

        // No zinc anywhere in this path — black and galvalume both price on
        // steel plus misc plus contribution, exactly as the rate card shows.
        let thicknessNum = parseFloat(line.thickness) || 0;
        line.finalQuoteInclThickness = (!isBlack && thicknessNum > 1.1) ? (line.finalQuoteBlack + 3000) : line.finalQuoteBlack;

        if (line.steelRate > 0) {
            // Thickness uplift stays (it is not grade pricing); the E350
            // grade bump is gone for the same rate-card reason as above.
            line.finalMtRate = line.quoteMt +
                               ((!isBlack && thicknessNum > 1.1) ? 3000 : 0);

            if (this.isPCs) {
                line.totalQuoteValue = Math.round(line.finalMtRate * line.unitWeight * line.quantity * 10) / 10;
            } else {
                line.totalQuoteValue = Math.round(line.finalMtRate * 10) / 10;
            }
        } else {
            line.finalMtRate = 0;
            line.totalQuoteValue = 0;
        }
    }

    // Modal Actions
    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    buildLinePayload(line, category) {
        let quantity = this.isPCs ? (parseFloat(line.quantity) || 0) : 1;
        let unitWeight = this.isPCs ? (parseFloat(line.unitWeight) || 0) : 1;

        let weight = this.isPCs ? (quantity * unitWeight) : (parseFloat(line.totalWeight) || 0);

        // Unit_Price__c expects Price per Piece (if PCS) or Price per MT (if Weight)
        let unitPrice = this.isPCs ? (line.finalMtRate * unitWeight) : line.finalMtRate;

        /*
         * Effective micron for the offer document. When Minimum Micron is
         * ticked on an HDG MMS line the calculation runs on micron + 20, and
         * the client sheet says the document must show that average
         * ("70 Minimum = 90 Average") - so the printed figure gets the same
         * +20, while Micron_Thickness__c keeps what the user actually picked.
         */
        let effMicron = line.micronThickness;
        let micNum = parseFloat(line.micronThickness);
        if (line.isMinimumMicron
                && line.material === SolarStructureConfig.HDG_MMS
                && !isNaN(micNum) && micNum > 0) {
            effMicron = String(micNum + 20);
        }

        // Location__c removed — no offer document, PDF page or Word page reads it.
        return {
            Category__c: category,
            Material__c: line.material,
            Material_Grade__c: line.displayGrade,
            Description__c: line.description,
            Thickness__c: line.thickness,
            Micron_Thickness__c: line.micronThickness,
            Effective_Micron__c: effMicron,
            Is_Minimum_Micron__c: !!line.isMinimumMicron,
            Is_Custom_Mode__c: !!line.isCustomMode,
            Total_Weight__c: weight,
            Unit_Weight__c: unitWeight,
            Quantity__c: quantity,
            Freight__c: line.freight,
            Discount__c: line.discount,
            Unit_Price__c: Math.round(unitPrice * 10) / 10,
            _SolarCustomApproval: line.isCustomMode ? 1 : 0
        };
    }

    handleSave() {
        let finalData = {
            Department__c: 'Solar Structure - Department',
            Unit_Of_Measurement__c: this.uom,
            Lines: [],
            Internal_State: {
                hdgLines: this.hdgLines,
                galvLines: this.galvLines,
                includeHdg: this.includeHdg,
                includeGalv: this.includeGalv,
                hdgCount: this.hdgCount,
                galvCount: this.galvCount
            }
        };

        if (this.includeHdg) {
            this.hdgLines.forEach(line => finalData.Lines.push(this.buildLinePayload(line, 'HDG MMS Structure')));
        }
        if (this.includeGalv) {
            this.galvLines.forEach(line => finalData.Lines.push(this.buildLinePayload(line, 'Galvalume & Black Structure')));
        }

        this.dispatchEvent(new CustomEvent('save', { detail: finalData }));
    }
}
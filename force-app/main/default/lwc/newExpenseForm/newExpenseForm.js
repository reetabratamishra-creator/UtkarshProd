import { LightningElement, track, wire } from 'lwc';
import saveExpenseData from '@salesforce/apex/NewExpenseFormController.saveExpenseData';
import getEligibility from '@salesforce/apex/NewExpenseFormController.getEligibility';
import getPrivateVehicleExpenseLines from '@salesforce/apex/NewExpenseFormController.getPrivateVehicleExpenseLines';
import discardFile from '@salesforce/apex/NewExpenseFormController.discardFile';
import getMyExpenseIdByName from '@salesforce/apex/NewExpenseFormController.getMyExpenseIdByName';
import getExpenseForEdit from '@salesforce/apex/NewExpenseFormController.getExpenseForEdit';
import resubmitExpenseData from '@salesforce/apex/NewExpenseFormController.resubmitExpenseData';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import USER_ID from '@salesforce/user/Id';

export default class NewExpenseForm extends NavigationMixin(LightningElement) {

    @track isSaving = false;
    @track isLoadingEligibility = true;
    @track eligibility = null;
    @track eligibilityError = null;

    stagingRecordId = USER_ID;

    // Private Vehicle state
    @track isPrivateVehicleSelected = false;
    @track privateVehicleLines = [];
    @track isLoadingPrivateVehicle = false;
    @track selectedPrivateVehicleLineIds = [];

    // UIL eligibility matrix city classification (w.e.f. 01 Jul 2026)
    tier1Cities = [
        'Mumbai', 'Bangalore', 'Bengaluru', 'Chennai', 'Kolkata', 'Hyderabad',
        'Pune', 'Ahmedabad', 'Guwahati', 'Delhi', 'Gurugram', 'Gurgaon', 'Noida', 'NCR'
    ];

    tier2Cities = [
        'Jaipur', 'Lucknow', 'Chandigarh', 'Indore', 'Surat', 'Nagpur', 'Coimbatore',
        'Kochi', 'Visakhapatnam', 'Vadodara', 'Bhopal', 'Ludhiana', 'Nashik', 'Rajkot',
        'Madurai', 'Varanasi', 'Mysore', 'Mysuru', 'Patna', 'Ranchi', 'Thiruvananthapuram',
        'Jodhpur', 'Amritsar', 'Kanpur', 'Agra', 'Vijayawada', 'Jamshedpur', 'Faridabad',
        'Ghaziabad', 'Srinagar', 'Jammu', 'Aizawl', 'Goa', 'Pondicherry', 'Puducherry'
    ];

    @track formData = {
        subject: '',
        startDate: null,
        endDate: null,
        city: '',
        cityTier: ''
    };

    @track expenseTypeOptions = [
        { label: 'Fooding', value: 'Fooding' },
        { label: 'Lodging', value: 'Lodging' },
        { label: 'Air', value: 'Air' },
        { label: 'Train', value: 'Train' },
        { label: 'Roadways', value: 'Roadways' },
        { label: 'Private Vehicle', value: 'Private Vehicle' },
        { label: 'Miscellaneous', value: 'Miscellaneous' }
    ];

    // All picklists available to all users
    airClassOptions = [
        { label: 'Economy', value: 'Economy' },
        { label: 'Business', value: 'Business' }
    ];

    trainClassOptions = [
        { label: '1AC', value: '1AC' },
        { label: '2AC', value: '2AC' },
        { label: '3AC', value: '3AC' },
        { label: 'Sleeper', value: 'Sleeper' }
    ];

    roadwayOptions = [
        { label: 'OLA/UBER', value: 'OLA/UBER' },
        { label: 'Car Rental', value: 'Car Rental' },
        { label: 'Taxi', value: 'Taxi' },
        { label: 'Auto', value: 'Auto' },
        { label: 'Bus', value: 'Bus' }
    ];

    ownVehicleOptions = [
        { label: '2-Wheeler', value: '2-Wheeler' },
        { label: '4-Wheeler', value: '4-Wheeler' }
    ];

    @track lineDataMap = {};
    @track selectedTypesArray = [];

    @wire(getEligibility)
    wiredEligibility({ error, data }) {
        this.isLoadingEligibility = false;
        if (data) {
            this.eligibility = data;
            this.eligibilityError = null;

            // Set default selected values for any existing rows if not set
            Object.keys(this.lineDataMap).forEach(type => {
                this.lineDataMap[type].forEach(row => {
                    if (!row.selectedValue) {
                        row.selectedValue = this.getDefaultSelectedValue(type);
                    }
                });
            });

            this.refreshAllRowCalculations();
            this.tryLoadExpenseForEdit();
        } else if (error) {
            this.eligibility = null;
            this.eligibilityError = this.getErrorMessage(error);
            this.showToast('Error', this.eligibilityError, 'error');
        }
    }

    get minTravelEndDate() {
        return this.formData.startDate || null;
    }

    get hasTravelDates() {
        return Boolean(this.formData.startDate && this.formData.endDate);
    }

    get showPrivateVehicleSection() {
        return this.isPrivateVehicleSelected && this.hasTravelDates;
    }

    get hasPrivateVehicleLines() {
        return this.privateVehicleLines && this.privateVehicleLines.length > 0;
    }

    get isAllPrivateVehicleSelected() {
        return this.hasPrivateVehicleLines && this.privateVehicleLines.every(row => row.selected);
    }

    get selectedPrivateVehicleRows() {
        return this.privateVehicleLines.filter(row => row.selected);
    }

    get selectedPrivateVehicleCount() {
        return this.selectedPrivateVehicleRows.length;
    }

    get totalPrivateVehicleDistance() {
        const total = this.selectedPrivateVehicleRows.reduce((sum, row) => sum + Number(row.AI_Extracted_Distance__c || 0), 0);
        return total.toFixed(2);
    }

    get totalPrivateVehicleAmount() {
        const total = this.selectedPrivateVehicleRows.reduce((sum, row) => sum + Number(row.Amount__c || 0), 0);
        return total.toFixed(2);
    }

    get showPrivateVehicleSummary() {
        return this.selectedPrivateVehicleCount > 0;
    }

    get hasSelectedTypes() {
        return this.selectedTypesArray.length > 0 || this.showPrivateVehicleSection;
    }

    get hasEligibility() {
        return this.eligibility != null;
    }

    get isSubmitDisabled() {
        return this.isSaving || !this.hasEligibility || this.isLoadingEligibility || this.isEditBlocked;
    }

    get allCitySuggestions() {
        return [...this.tier1Cities, ...this.tier2Cities];
    }

    get tripDays() {
        if (!this.formData.startDate || !this.formData.endDate) {
            return 0;
        }
        const start = new Date(this.formData.startDate);
        const end = new Date(this.formData.endDate);
        if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || end < start) {
            return 0;
        }
        const msPerDay = 24 * 60 * 60 * 1000;
        return Math.floor((end - start) / msPerDay) + 1;
    }

    get foodingDailyLimit() {
        return this.getDailyLimit('Fooding');
    }

    get lodgingDailyLimit() {
        return this.getDailyLimit('Lodging');
    }

    get foodingMaxAllowed() {
        return this.foodingDailyLimit * this.tripDays;
    }

    get lodgingMaxAllowed() {
        return this.lodgingDailyLimit * this.tripDays;
    }

    getDailyLimit(expenseType) {
        if (!this.eligibility || !this.formData.cityTier) {
            return 0;
        }
        const e = this.eligibility;
        const tier = this.formData.cityTier;
        if (expenseType === 'Fooding') {
            if (tier === 'Tier 1') return Number(e.Fooding_Tier_1__c || 0);
            if (tier === 'Tier 2') return Number(e.Fooding_Tier_2__c || 0);
            return Number(e.Fooding_Tier_3__c || 0);
        }
        if (expenseType === 'Lodging') {
            if (tier === 'Tier 1') return Number(e.Lodging_Tier_1__c || 0);
            if (tier === 'Tier 2') return Number(e.Lodging_Tier_2__c || 0);
            return Number(e.Lodging_Tier_3__c || 0);
        }
        return 0;
    }

    getOwnVehicleRate(vehicleType) {
        if (!this.eligibility || !vehicleType) {
            return 0;
        }
        if (vehicleType === '2-Wheeler') {
            return Number(this.eligibility.Own_2_Wheeler_Rate_per_KM__c || 0);
        }
        if (vehicleType === '4-Wheeler') {
            return Number(this.eligibility.Own_4_Wheeler_Rate_per_KM__c || 0);
        }
        return 0;
    }

    getDefaultSelectedValue(type) {
        if (!this.eligibility) return '';
        const e = this.eligibility;
        if (type === 'Air') {
            if (e.Air_Economy_Class__c) return 'Economy';
            if (e.Air_Business_Class__c) return 'Business';
            return 'Economy';
        }
        if (type === 'Train') {
            if (e.Train_3AC__c) return '3AC';
            if (e.Train_2AC__c) return '2AC';
            if (e.Train_1AC__c) return '1AC';
            if (e.Train_Sleeper__c) return 'Sleeper';
            return '3AC';
        }
        if (type === 'Roadways') {
            if (e.Ola_Uber_Taxi__c) return 'OLA/UBER';
            if (e.Car_Rental__c) return 'Car Rental';
            if (e.Auto__c) return 'Auto';
            if (e.Bus__c) return 'Bus';
            return 'OLA/UBER';
        }
        if (type === 'Own Vehicle') {
            if (Number(e.Own_2_Wheeler_Rate_per_KM__c || 0) > 0) return '2-Wheeler';
            if (Number(e.Own_4_Wheeler_Rate_per_KM__c || 0) > 0) return '4-Wheeler';
            return '2-Wheeler';
        }
        return '';
    }

    resolveCityTier(inputCity) {
        if (!inputCity || !inputCity.trim()) {
            return '';
        }
        const city = inputCity.trim().toLowerCase();
        if (this.tier1Cities.some(c => c.toLowerCase() === city)) {
            return 'Tier 1';
        }
        if (this.tier2Cities.some(c => c.toLowerCase() === city)) {
            return 'Tier 2';
        }
        return 'Tier 3';
    }

    validateTravelEndDate(endDateStr, showToastNotification = true) {
        if (!endDateStr) return true;

        const travelEnd = new Date(endDateStr + 'T00:00:00');
        if (Number.isNaN(travelEnd.getTime())) return true;

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const currentYear = today.getFullYear();
        const currentMonth = today.getMonth(); // 0-indexed (0 = Jan, 8 = Sept)
        const currentDay = today.getDate();

        const endYear = travelEnd.getFullYear();
        const endMonth = travelEnd.getMonth();

        const monthDiff = (currentYear - endYear) * 12 + (currentMonth - endMonth);

        if (monthDiff === 1) {
            // Past month (e.g. August when today is September)
            if (currentDay > 5) {
                if (showToastNotification) {
                    this.showToast(
                        'Error',
                        'Expenses for the previous month can only be submitted up to the 5th of the current month.',
                        'error'
                    );
                }
                return false;
            }
        } else if (monthDiff > 1) {
            // Older than previous month (e.g. July or older when today is September)
            if (showToastNotification) {
                this.showToast(
                    'Error',
                    'Expenses for past months can only be submitted up to the 5th of the immediately following month.',
                    'error'
                );
            }
            return false;
        }

        return true;
    }

    handleInputChange(event) {
        const fieldName = event.target.name;
        const val = event.target.value;
        this.formData[fieldName] = val;

        if (fieldName === 'endDate' && val && !this.isEditMode) {
            this.validateTravelEndDate(val, true);
        }

        if (fieldName === 'startDate' || fieldName === 'endDate') {
            if (this.isPrivateVehicleSelected) {
                if (this.hasTravelDates) {
                    this.fetchPrivateVehicleExpenses();
                } else {
                    this.privateVehicleLines = [];
                    this.selectedPrivateVehicleLineIds = [];
                }
            }
        }

        this.refreshAllRowCalculations();
    }

    handleCityChange(event) {
        const inputCity = event.target.value;
        this.formData.city = inputCity;
        this.formData.cityTier = this.resolveCityTier(inputCity);
        this.refreshAllRowCalculations();
    }

    handleTypeSelection(event) {
        const type = event.target.value || event.target.dataset.type || event.target.label;
        const isChecked = event.target.checked;

        if (type === 'Private Vehicle' || type === 'Own Vehicle') {
            this.isPrivateVehicleSelected = isChecked;
            if (isChecked) {
                if (this.hasTravelDates) {
                    this.fetchPrivateVehicleExpenses();
                }
            } else {
                this.privateVehicleLines = [];
                this.selectedPrivateVehicleLineIds = [];
            }
            this.refreshAllRowCalculations();
            return;
        }

        if (isChecked) {
            this.lineDataMap[type] = [this.createNewRow(type)];
        } else {
            if (this.lineDataMap[type]) {
                this.lineDataMap[type].forEach(row => this.discardRowFiles(row));
            }
            delete this.lineDataMap[type];
        }
        this.refreshAllRowCalculations();
    }

    fetchPrivateVehicleExpenses() {
        if (!this.formData.startDate || !this.formData.endDate) {
            this.privateVehicleLines = [];
            return;
        }

        this.isLoadingPrivateVehicle = true;
        getPrivateVehicleExpenseLines({
            startDate: this.formData.startDate,
            endDate: this.formData.endDate
        })
            .then(data => {
                const records = this.isEditMode ? this.mergeExistingPvLines(data) : (data || []);
                this.privateVehicleLines = records.map(item => {
                    const isSelected = this.selectedPrivateVehicleLineIds.includes(item.Id);
                    const travelDate = item.Date__c || item.Start_Date__c || '';
                    return {
                        ...item,
                        selected: isSelected,
                        rowClass: isSelected ? 'pv-row pv-row-selected' : 'pv-row',
                        formattedDate: travelDate,
                        aiDistanceFormatted: item.AI_Extracted_Distance__c != null ? `${item.AI_Extracted_Distance__c} KM` : '-',
                        manualDistanceFormatted: item.Manually_Extracted_Distance__c != null ? `${item.Manually_Extracted_Distance__c} KM` : '-',
                        vehicleType: item.Vehicle_Type__c || '-',
                        amountFormatted: item.Amount__c != null ? `₹${Number(item.Amount__c).toFixed(2)}` : '₹0.00'
                    };
                });
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load Private Vehicle expenses: ' + this.getErrorMessage(error), 'error');
                this.privateVehicleLines = [];
            })
            .finally(() => {
                this.isLoadingPrivateVehicle = false;
            });
    }

    handleSelectAllPrivateVehicle(event) {
        const isChecked = event.target.checked;
        this.privateVehicleLines = this.privateVehicleLines.map(row => ({
            ...row,
            selected: isChecked,
            rowClass: isChecked ? 'pv-row pv-row-selected' : 'pv-row'
        }));
        this.selectedPrivateVehicleLineIds = isChecked ? this.privateVehicleLines.map(r => r.Id) : [];
    }

    handlePrivateVehicleRowSelect(event) {
        const rowId = event.target.dataset.id;
        const isChecked = event.target.checked;
        this.privateVehicleLines = this.privateVehicleLines.map(row => {
            if (row.Id === rowId) {
                return {
                    ...row,
                    selected: isChecked,
                    rowClass: isChecked ? 'pv-row pv-row-selected' : 'pv-row'
                };
            }
            return row;
        });

        if (isChecked) {
            if (!this.selectedPrivateVehicleLineIds.includes(rowId)) {
                this.selectedPrivateVehicleLineIds = [...this.selectedPrivateVehicleLineIds, rowId];
            }
        } else {
            this.selectedPrivateVehicleLineIds = this.selectedPrivateVehicleLineIds.filter(id => id !== rowId);
        }
    }

    createNewRow(type) {
        const defaultVal = this.getDefaultSelectedValue(type);
        let isBillMandatory = true;
        if (type === 'Fooding') {
            isBillMandatory = false;
        } else if (type === 'Roadways') {
            isBillMandatory = (defaultVal === 'OLA/UBER' || defaultVal === 'Car Rental');
        }

        const row = {
            id: Date.now() + Math.random().toString(),
            name: type,
            amount: null,
            startDate: this.formData.startDate || null,
            endDate: type === 'Lodging' ? (this.formData.endDate || null) : null,
            selectedValue: defaultVal,
            distanceKm: null,
            ratePerKm: 0,
            justification: '',
            miscellaneousCost: '',
            bills: [],
            proofs: [],
            limitLabel: '',
            showLimitLabel: false,
            isOverLimit: false,
            isOutOfCriteria: false,
            requiresJustificationAndProof: false,
            isBillMandatory: isBillMandatory,
            amountClass: 'amount-field',
            limitHintClass: 'limit-hint',
            isAir: type === 'Air',
            isTrain: type === 'Train',
            isRoadways: type === 'Roadways',
            isOwnVehicle: type === 'Own Vehicle',
            isFooding: type === 'Fooding',
            isLodging: type === 'Lodging',
            isMiscellaneous: type === 'Miscellaneous'
        };
        return row;
    }

    handleAddMoreRow(event) {
        const type = event.target.dataset.type;
        this.lineDataMap[type].push(this.createNewRow(type));
        this.refreshAllRowCalculations();
    }

    handleRemoveRow(event) {
        const type = event.target.dataset.type;
        const index = parseInt(event.target.dataset.index, 10);
        const removedRow = this.lineDataMap[type][index];
        if (removedRow) {
            this.discardRowFiles(removedRow);
        }
        this.lineDataMap[type].splice(index, 1);
        this.refreshAllRowCalculations();
    }

    handleLineDataChange(event) {
        const { type, index } = event.target.dataset;
        this.lineDataMap[type][index].selectedValue = event.target.value;
        this.refreshAllRowCalculations();
    }

    handleStartDateChange(event) {
        const { type, index } = event.target.dataset;
        const row = this.lineDataMap[type][index];
        row.startDate = event.target.value;
        this.refreshAllRowCalculations();
    }

    handleEndDateChange(event) {
        const { type, index } = event.target.dataset;
        this.lineDataMap[type][index].endDate = event.target.value;
        this.refreshAllRowCalculations();
    }

    handleDistanceChange(event) {
        const { type, index } = event.target.dataset;
        this.lineDataMap[type][index].distanceKm = event.target.value;
        this.refreshAllRowCalculations();
    }

    handleAmountChange(event) {
        const { type, index } = event.target.dataset;
        this.lineDataMap[type][index].amount = event.target.value;
        this.refreshAllRowCalculations();
    }

    handleJustificationChange(event) {
        const { type, index } = event.target.dataset;
        this.lineDataMap[type][index].justification = event.target.value;
    }

    handleMiscellaneousCostChange(event) {
        const { type, index } = event.target.dataset;
        this.lineDataMap[type][index].miscellaneousCost = event.target.value;
    }

    isCriteriaEligible(type, selectedValue) {
        if (!this.eligibility || !selectedValue) return true;
        const e = this.eligibility;

        if (type === 'Air') {
            if (selectedValue === 'Business') return !!e.Air_Business_Class__c;
            if (selectedValue === 'Economy') return !!e.Air_Economy_Class__c;
        }
        if (type === 'Train') {
            if (selectedValue === '1AC') return !!e.Train_1AC__c;
            if (selectedValue === '2AC') return !!e.Train_2AC__c;
            if (selectedValue === '3AC') return !!e.Train_3AC__c;
            if (selectedValue === 'Sleeper') return !!e.Train_Sleeper__c;
        }
        if (type === 'Roadways') {
            if (selectedValue === 'OLA/UBER') return !!e.Ola_Uber_Taxi__c;
            if (selectedValue === 'Taxi') return !!e.Ola_Uber_Taxi__c;
            if (selectedValue === 'Car Rental') return !!e.Car_Rental__c;
            if (selectedValue === 'Auto') return !!e.Auto__c;
            if (selectedValue === 'Bus') return !!e.Bus__c;
        }
        if (type === 'Own Vehicle') {
            if (selectedValue === '2-Wheeler') return Number(e.Own_2_Wheeler_Rate_per_KM__c || 0) > 0;
            if (selectedValue === '4-Wheeler') return Number(e.Own_4_Wheeler_Rate_per_KM__c || 0) > 0;
        }
        return true;
    }

    refreshAllRowCalculations() {
        Object.keys(this.lineDataMap).forEach(type => {
            this.lineDataMap[type].forEach(row => {
                this.evaluateRow(type, row);
            });
        });
        this.applyLodgingOverlapFlags();
        this.updateIterableArray();
    }

    evaluateRow(type, row) {
        const amount = Number(row.amount || 0);

        if (type === 'Miscellaneous') {
            row.isOverLimit = false;
            row.isOutOfCriteria = false;
            row.limitLabel = '';
            row.showLimitLabel = false;
            row.requiresJustificationAndProof = false;
            row.isBillMandatory = true;
            row.amountClass = 'amount-field';
            row.limitHintClass = 'limit-hint';
            return;
        }

        // 1. Check out-of-criteria for picklists
        let isOutOfCriteria = false;
        if (row.selectedValue) {
            isOutOfCriteria = !this.isCriteriaEligible(type, row.selectedValue);
        }
        row.isOutOfCriteria = isOutOfCriteria;

        // 2. Check over-limit based on expense type
        let isOverLimit = false;
        let limitLabel = '';

        if (type === 'Fooding') {
            const dailyLimit = this.foodingDailyLimit;
            if (dailyLimit > 0) {
                limitLabel = `Eligible Daily Limit: ₹${dailyLimit}`;
                if (amount > dailyLimit) {
                    isOverLimit = true;
                    limitLabel = `⚠️ Exceeds eligible limit of ₹${dailyLimit}/day. Justification & Proof required.`;
                }
            } else if (this.formData.cityTier) {
                limitLabel = 'No Fooding eligibility defined for this level.';
                if (amount > 0) isOverLimit = true;
            }
            row.isBillMandatory = amount > 500;
        } else if (type === 'Lodging') {
            const dailyLimit = this.lodgingDailyLimit;
            let days = 1;
            if (row.startDate && row.endDate) {
                const s = new Date(row.startDate);
                const e = new Date(row.endDate);
                if (!Number.isNaN(s.getTime()) && !Number.isNaN(e.getTime()) && e >= s) {
                    days = Math.floor((e - s) / (24 * 60 * 60 * 1000)) + 1;
                }
            }
            const allowed = dailyLimit * days;
            if (dailyLimit > 0) {
                limitLabel = `Eligible Limit: ₹${allowed} (₹${dailyLimit}/day × ${days} day${days > 1 ? 's' : ''})`;
                if (amount > allowed) {
                    isOverLimit = true;
                    limitLabel = `⚠️ Exceeds eligible limit of ₹${allowed}. Justification & Proof required.`;
                }
            } else if (this.formData.cityTier) {
                limitLabel = 'No Lodging eligibility defined for this level.';
                if (amount > 0) isOverLimit = true;
            }
            row.isBillMandatory = true;
        } else if (type === 'Own Vehicle') {
            const rate = this.getOwnVehicleRate(row.selectedValue);
            row.ratePerKm = rate;
            const km = Number(row.distanceKm || 0);
            const maxAllowed = rate * km;

            if (row.selectedValue && rate > 0) {
                if (km > 0) {
                    limitLabel = `Rate: ₹${rate}/KM · Max allowed: ₹${maxAllowed}`;
                    if (amount > maxAllowed) {
                        isOverLimit = true;
                        limitLabel = `⚠️ Exceeds calculated limit of ₹${maxAllowed} (${km} KM × ₹${rate}/KM). Justification & Proof required.`;
                    }
                } else {
                    limitLabel = `Rate: ₹${rate}/KM · Enter distance to compute max`;
                }
            } else if (row.selectedValue) {
                limitLabel = `No rate configured for ${row.selectedValue}`;
                if (amount > 0) isOverLimit = true;
            }
            row.isBillMandatory = true;
        } else if (type === 'Roadways') {
            if (isOutOfCriteria) {
                limitLabel = `⚠️ ${row.selectedValue} is outside your standard entitlement. Justification & Proof required.`;
            }
            row.isBillMandatory = (row.selectedValue === 'OLA/UBER' || row.selectedValue === 'Car Rental');
        } else {
            // Air / Train
            if (isOutOfCriteria) {
                limitLabel = `⚠️ ${row.selectedValue} is outside your standard entitlement. Justification & Proof required.`;
            }
            row.isBillMandatory = true;
        }

        row.isOverLimit = isOverLimit;
        row.limitLabel = limitLabel;
        row.showLimitLabel = !!limitLabel;
        row.limitHintClass = isOverLimit ? 'limit-hint-danger' : 'limit-hint';
        row.requiresJustificationAndProof = isOverLimit || isOutOfCriteria;
        row.amountClass = isOverLimit ? 'amount-field amount-exceeded' : 'amount-field';
    }

    // ---------- Lodging overlapping dates ----------
    // Overlapping Lodging stays are allowed but need a justification. Runs after evaluateRow,
    // so the existing limit-exceeded rule (justification + approval upload) is left untouched.
    applyLodgingOverlapFlags() {
        const rows = this.lineDataMap.Lodging || [];
        const isValidRange = r => r.startDate && r.endDate && r.endDate >= r.startDate;

        rows.forEach((row, i) => {
            const overlaps = [];
            if (isValidRange(row)) {
                rows.forEach((other, j) => {
                    // Only compare with earlier rows: the later (repeating) entry carries the justification
                    if (j >= i || !isValidRange(other)) return;
                    // ISO yyyy-mm-dd strings compare chronologically; ranges are inclusive (same as day count)
                    if (row.startDate <= other.endDate && other.startDate <= row.endDate) {
                        const from = row.startDate > other.startDate ? row.startDate : other.startDate;
                        const to = row.endDate < other.endDate ? row.endDate : other.endDate;
                        const period = from === to
                            ? this.formatDisplayDate(from)
                            : `${this.formatDisplayDate(from)} to ${this.formatDisplayDate(to)}`;
                        overlaps.push(`${period} (with Row ${j + 1})`);
                    }
                });
            }

            row.hasDateOverlap = overlaps.length > 0;
            row.overlapMessage = row.hasDateOverlap
                ? `These dates are overlapping: ${overlaps.join(', ')}. Are you sure you want to proceed?`
                : '';
            row.requiresJustificationOnly = row.hasDateOverlap && !row.requiresJustificationAndProof;
        });
    }

    formatDisplayDate(isoDate) {
        const d = new Date(isoDate + 'T00:00:00');
        if (Number.isNaN(d.getTime())) return isoDate;
        return d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
    }

    updateIterableArray() {
        this.selectedTypesArray = Object.keys(this.lineDataMap).map(key => {
            const items = this.lineDataMap[key].map(item => {
                return {
                    ...item,
                    hasBills: item.bills && item.bills.length > 0,
                    hasProofs: item.proofs && item.proofs.length > 0,
                    showJustificationSection: !!(item.requiresJustificationAndProof || item.requiresJustificationOnly)
                };
            });
            return {
                name: key,
                items,
                isFooding: key === 'Fooding',
                isLodging: key === 'Lodging',
                isMiscellaneous: key === 'Miscellaneous'
            };
        });
    }

    // ---------- Multi-File Upload Handling (Supports up to 25MB via lightning-file-upload) ----------
    handleBillUpload(event) {
        const { type, index } = event.target.dataset;
        const uploadedFiles = event.detail.files || [];
        if (!uploadedFiles || uploadedFiles.length === 0) return;
        this.processUploadedFiles(type, parseInt(index, 10), uploadedFiles, 'bills');
    }

    handleProofUpload(event) {
        const { type, index } = event.target.dataset;
        const uploadedFiles = event.detail.files || [];
        if (!uploadedFiles || uploadedFiles.length === 0) return;
        this.processUploadedFiles(type, parseInt(index, 10), uploadedFiles, 'proofs');
    }

    processUploadedFiles(type, index, files, targetArrayKey) {
        const row = this.lineDataMap[type][index];
        if (!row[targetArrayKey]) {
            row[targetArrayKey] = [];
        }

        const existingDocIds = new Set(row[targetArrayKey].map(f => f.documentId).filter(Boolean));

        for (let file of files) {
            if (existingDocIds.has(file.documentId)) {
                continue;
            }
            const ext = file.name && file.name.includes('.') ? file.name.split('.').pop() : '';
            const fileObj = {
                id: Date.now() + Math.random().toString(),
                fileName: file.name,
                documentId: file.documentId,
                extension: ext,
                fileType: targetArrayKey === 'bills' ? 'Bill' : 'Proof'
            };
            row[targetArrayKey].push(fileObj);
        }
        this.updateIterableArray();
    }

    handleRemoveBill(event) {
        const { type, index, fileId, documentId } = event.target.dataset;
        const row = this.lineDataMap[type][parseInt(index, 10)];
        const removedFile = row && row.bills ? row.bills.find(f => f.id === fileId) : null;
        if (row && row.bills) {
            row.bills = row.bills.filter(f => f.id !== fileId && (!documentId || f.documentId !== documentId));
            this.updateIterableArray();
        }
        if (removedFile && removedFile.isExisting) {
            this.markExistingFileRemoved(removedFile.documentId);
        } else if (documentId) {
            discardFile({ documentId }).catch(() => {});
        }
    }

    handleRemoveProof(event) {
        const { type, index, fileId, documentId } = event.target.dataset;
        const row = this.lineDataMap[type][parseInt(index, 10)];
        const removedFile = row && row.proofs ? row.proofs.find(f => f.id === fileId) : null;
        if (row && row.proofs) {
            row.proofs = row.proofs.filter(f => f.id !== fileId && (!documentId || f.documentId !== documentId));
            this.updateIterableArray();
        }
        if (removedFile && removedFile.isExisting) {
            this.markExistingFileRemoved(removedFile.documentId);
        } else if (documentId) {
            discardFile({ documentId }).catch(() => {});
        }
    }

    discardRowFiles(row) {
        if (!row) return;
        if (this.isEditMode) {
            this.markRowRemovedForEdit(row);
        }
        const docIds = [
            ...(row.bills || []).filter(f => !f.isExisting).map(f => f.documentId),
            ...(row.proofs || []).filter(f => !f.isExisting).map(f => f.documentId)
        ].filter(Boolean);

        docIds.forEach(documentId => {
            discardFile({ documentId }).catch(() => {});
        });
    }

    // ---------- Form Submission & Validation ----------
    saveExpense() {
        if (!this.hasEligibility) {
            this.showToast('Error', this.eligibilityError || 'Eligibility not loaded', 'error');
            return;
        }

        if (!this.formData.subject || !this.formData.subject.trim()) {
            this.showToast('Error', 'Please enter a Subject for this expense claim', 'error');
            return;
        }

        if (!this.formData.startDate || !this.formData.endDate || !this.formData.city) {
            this.showToast('Error', 'Please fill all required travel details (Dates & City)', 'error');
            return;
        }

        const travelStart = new Date(this.formData.startDate + 'T00:00:00');
        const travelEnd = new Date(this.formData.endDate + 'T00:00:00');

        if (travelEnd < travelStart) {
            this.showToast('Error', 'Travel End Date must be on or after Travel Start Date', 'error');
            return;
        }

        if (!this.isEditMode && !this.validateTravelEndDate(this.formData.endDate, true)) {
            return;
        }

        let flattenedLines = [];

        for (let key in this.lineDataMap) {
            let linesForType = this.lineDataMap[key];

            // Duplicate date validation for Fooding and Miscellaneous only
            if (key === 'Fooding' || key === 'Miscellaneous') {
                const seenDates = new Set();
                for (let i = 0; i < linesForType.length; i++) {
                    const rowDate = linesForType[i].startDate;
                    if (rowDate) {
                        if (seenDates.has(rowDate)) {
                            this.showToast(
                                'Duplicate Date Error',
                                `Multiple entries for the same date (${rowDate}) are not allowed for ${key}. Please select different dates or merge the entries.`,
                                'error'
                            );
                            return;
                        }
                        seenDates.add(rowDate);
                    }
                }
            }

            for (let i = 0; i < linesForType.length; i++) {
                let item = linesForType[i];
                const rowLabel = `${item.name} (Row ${i + 1})`;

                // 1. Picklist validation
                if (item.isAir || item.isTrain || item.isRoadways || item.isOwnVehicle) {
                    if (!item.selectedValue) {
                        this.showToast('Error', `Please select Class/Type for ${rowLabel}`, 'error');
                        return;
                    }
                }

                if (item.isOwnVehicle) {
                    const km = Number(item.distanceKm);
                    if (!km || km <= 0) {
                        this.showToast('Error', `Please enter Distance (KM) for ${rowLabel}`, 'error');
                        return;
                    }
                }

                // 2. Miscellaneous Cost text field validation
                if (item.isMiscellaneous) {
                    if (!item.miscellaneousCost || !item.miscellaneousCost.trim()) {
                        this.showToast('Error', `Please enter Miscellaneous Cost for ${rowLabel}`, 'error');
                        return;
                    }
                }

                // 3. Date validation
                if (item.isLodging) {
                    if (!item.startDate || !item.endDate) {
                        this.showToast('Error', `Please select From and To dates for ${rowLabel}`, 'error');
                        return;
                    }
                    const lineStart = new Date(item.startDate + 'T00:00:00');
                    const lineEnd = new Date(item.endDate + 'T00:00:00');

                    if (lineStart < travelStart || lineStart > travelEnd) {
                        this.showToast('Error', `From Date for ${rowLabel} must be between Travel Start Date and Travel End Date`, 'error');
                        return;
                    }
                    if (lineEnd < travelStart || lineEnd > travelEnd) {
                        this.showToast('Error', `To Date for ${rowLabel} must be between Travel Start Date and Travel End Date`, 'error');
                        return;
                    }
                    if (lineEnd < lineStart) {
                        this.showToast('Error', `To Date cannot be before From Date for ${rowLabel}`, 'error');
                        return;
                    }
                } else {
                    // Single date types: Fooding, Miscellaneous, Air, Train, Roadways
                    const dateFieldLabel = (item.isAir || item.isTrain || item.isRoadways) ? 'Journey Date' : 'Date';
                    if (!item.startDate) {
                        this.showToast('Error', `Please select ${dateFieldLabel} for ${rowLabel}`, 'error');
                        return;
                    }
                    const lineDate = new Date(item.startDate + 'T00:00:00');
                    if (lineDate < travelStart || lineDate > travelEnd) {
                        this.showToast('Error', `${dateFieldLabel} for ${rowLabel} must be between Travel Start Date (${this.formData.startDate}) and Travel End Date (${this.formData.endDate})`, 'error');
                        return;
                    }
                }

                // 4. Amount validation
                const amount = Number(item.amount);
                if (!item.amount && item.amount !== 0) {
                    this.showToast('Error', `Please enter Amount for ${rowLabel}`, 'error');
                    return;
                }
                if (amount <= 0) {
                    this.showToast('Error', `Amount must be greater than zero for ${rowLabel}`, 'error');
                    return;
                }

                // 5. Bill Upload validation
                const billFiles = item.bills || [];
                if (item.isBillMandatory && billFiles.length === 0) {
                    if (item.isFooding) {
                        this.showToast('Error', `Upload Bill / Receipt is mandatory for ${rowLabel} when amount exceeds ₹500`, 'error');
                    } else if (item.isRoadways) {
                        this.showToast('Error', `Upload Bill / Receipt is mandatory for ${rowLabel} when selecting ${item.selectedValue}`, 'error');
                    } else {
                        this.showToast('Error', `Upload Bill / Receipt is mandatory for ${rowLabel}`, 'error');
                    }
                    return;
                }

                // 6. Justification & Proof validation
                const proofFiles = item.proofs || [];
                if (item.requiresJustificationAndProof) {
                    if (!item.justification || !item.justification.trim()) {
                        this.showToast('Error', `Justification is mandatory for ${rowLabel}`, 'error');
                        return;
                    }
                    if (proofFiles.length === 0) {
                        this.showToast('Error', `Proof upload is mandatory for ${rowLabel}`, 'error');
                        return;
                    }
                } else if (item.requiresJustificationOnly) {
                    // Lodging with overlapping dates (within limit): justification only, approval upload optional
                    if (!item.justification || !item.justification.trim()) {
                        this.showToast('Error', `Justification is mandatory for ${rowLabel} as its dates overlap with another Lodging entry`, 'error');
                        return;
                    }
                }

                // Combine all files for this line
                const allFiles = [
                    ...billFiles.map(b => ({
                        fileName: b.fileName,
                        documentId: b.documentId,
                        base64Data: b.base64Data,
                        extension: b.extension,
                        fileType: 'Bill',
                        isExisting: !!b.isExisting
                    })),
                    ...proofFiles.map(p => ({
                        fileName: p.fileName,
                        documentId: p.documentId,
                        base64Data: p.base64Data,
                        extension: p.extension,
                        fileType: 'Proof',
                        isExisting: !!p.isExisting
                    }))
                ];

                flattenedLines.push({
                    lineId: item.lineId || null,
                    expenseType: item.name === 'Private Vehicle' ? 'Own Vehicle' : item.name,
                    amount: amount,
                    startDate: item.startDate,
                    endDate: item.isLodging ? item.endDate : null,
                    justification: item.justification ? item.justification.trim() : null,
                    miscellaneousCost: item.isMiscellaneous ? (item.miscellaneousCost ? item.miscellaneousCost.trim() : null) : null,
                    travelClass: (item.isAir || item.isTrain) ? item.selectedValue : null,
                    vehicleType: (item.isRoadways || item.isOwnVehicle) ? item.selectedValue : null,
                    distanceKm: item.isOwnVehicle ? Number(item.distanceKm) : null,
                    files: allFiles
                });
            }
        }

        if (flattenedLines.length === 0 && this.selectedPrivateVehicleLineIds.length === 0) {
            this.showToast('Error', 'Please add at least one expense line item or select a Private Vehicle trip', 'error');
            return;
        }

        const payload = {
            subject: this.formData.subject.trim(),
            startDate: this.formData.startDate,
            endDate: this.formData.endDate,
            city: this.formData.city,
            cityTier: this.formData.cityTier,
            lines: flattenedLines,
            privateVehicleLineIds: this.selectedPrivateVehicleLineIds
        };

        if (this.isEditMode) {
            this.resubmitExpense(payload);
            return;
        }

        this.isSaving = true;
        saveExpenseData({ payload: JSON.stringify(payload) })
            .then((result) => {
                this.showToast('Success', `Expense claim ${result} created successfully`, 'success');
                this.resetForm();
                this.navigateToNewExpense(result);
            })
            .catch(error => {
                this.showToast('Error saving record', this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    // After a new submission, open the created Expense record (same as after a resubmit).
    // Navigation is best-effort: if the lookup fails the user simply stays on the reset form.
    navigateToNewExpense(expenseName) {
        getMyExpenseIdByName({ expenseName })
            .then(expenseId => {
                if (!expenseId) return;
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: expenseId,
                        objectApiName: 'Expense__c',
                        actionName: 'view'
                    }
                });
            })
            .catch(() => {});
    }

    resetForm() {
        this.formData = { subject: '', startDate: null, endDate: null, city: '', cityTier: '' };
        this.lineDataMap = {};
        this.selectedTypesArray = [];
        this.isPrivateVehicleSelected = false;
        this.privateVehicleLines = [];
        this.selectedPrivateVehicleLineIds = [];
        this.template.querySelectorAll('lightning-input').forEach(input => {
            if (input.type === 'toggle' || input.type === 'checkbox') {
                input.checked = false;
            } else {
                input.value = '';
            }
        });
        this.template.querySelectorAll('lightning-textarea').forEach(input => {
            input.value = '';
        });
    }

    getErrorMessage(error) {
        if (error?.body?.message) return error.body.message;
        if (Array.isArray(error?.body)) return error.body.map(e => e.message).join(', ');
        return error?.message || 'Unknown error';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // =====================================================================
    // ===== EDIT MODE (rejected expense resubmission) =====================
    // Active only when opened from myExpenses with ?c__expenseId=<Expense__c Id>.
    // =====================================================================

    editExpenseId = null;
    @track isLoadingEdit = false;
    @track editLoadError = null;
    @track editExpenseName = '';
    @track editExpenseStatus = '';
    @track editExpenseRemark = '';
    editDataLoaded = false;
    existingPvLines = [];
    removedLineIds = [];
    removedDocumentIds = [];

    @wire(CurrentPageReference)
    wiredPageReference(pageRef) {
        const expenseId = pageRef && pageRef.state ? pageRef.state.c__expenseId : null;
        if (expenseId && expenseId !== this.editExpenseId) {
            this.editExpenseId = expenseId;
            this.editDataLoaded = false;
            this.editLoadError = null;
            this.tryLoadExpenseForEdit();
        }
    }

    get isEditMode() {
        return !!this.editExpenseId;
    }

    // Submit stays disabled until the rejected expense is loaded (never falls back to create)
    get isEditBlocked() {
        return this.isEditMode && (!this.editDataLoaded || this.isLoadingEdit);
    }

    get cardTitle() {
        return this.isEditMode ? `Edit Expense Claim ${this.editExpenseName || ''}` : 'Expense Claim';
    }

    get cardSubtitle() {
        return this.isEditMode
            ? 'Correct the details below and resubmit for approval'
            : 'Submit your travel & reimbursement details';
    }

    get submitButtonLabel() {
        return this.isEditMode ? 'Resubmit Expense Claim' : 'Submit Expense Claim';
    }

    get showEditBanner() {
        return this.isEditMode && this.editDataLoaded;
    }

    get hasEditRemark() {
        return !!this.editExpenseRemark;
    }

    // Eligibility is needed first so defaults and limits evaluate exactly as in create mode
    tryLoadExpenseForEdit() {
        if (!this.editExpenseId || !this.eligibility || this.editDataLoaded || this.isLoadingEdit) {
            return;
        }
        this.loadExpenseForEdit();
    }

    loadExpenseForEdit() {
        this.isLoadingEdit = true;
        getExpenseForEdit({ expenseId: this.editExpenseId })
            .then(data => {
                this.applyExpenseForEdit(data);
            })
            .catch(error => {
                this.editLoadError = this.getErrorMessage(error);
                this.showToast('Error', this.editLoadError, 'error');
            })
            .finally(() => {
                this.isLoadingEdit = false;
            });
    }

    applyExpenseForEdit(data) {
        const exp = data.expense || {};
        const lines = data.lines || [];

        const lineWithCity = lines.find(l => !l.isPrivateVehicle && l.line.City__c);
        const city = lineWithCity ? lineWithCity.line.City__c : '';

        this.formData = {
            subject: exp.Subject__c || '',
            startDate: exp.Travel_Start_Date__c || null,
            endDate: exp.Travel_End_Date__c || null,
            city: city,
            cityTier: this.resolveCityTier(city)
        };
        this.editExpenseName = exp.Name || '';
        this.editExpenseStatus = exp.Status__c || '';
        this.editExpenseRemark = exp.Remark__c || '';
        this.removedLineIds = [];
        this.removedDocumentIds = [];

        const lineDataMap = {};
        const pvLines = [];
        lines.forEach(editLine => {
            if (editLine.isPrivateVehicle) {
                pvLines.push(editLine.line);
                return;
            }
            const type = editLine.line.Expense_Type__c;
            if (!lineDataMap[type]) {
                lineDataMap[type] = [];
            }
            lineDataMap[type].push(this.mapLineToRow(editLine.line, editLine.files || []));
        });

        this.lineDataMap = lineDataMap;
        this.existingPvLines = pvLines;
        this.selectedPrivateVehicleLineIds = pvLines.map(l => l.Id);
        this.isPrivateVehicleSelected = pvLines.length > 0;
        this.privateVehicleLines = [];

        const activeTypes = new Set(Object.keys(lineDataMap));
        if (pvLines.length > 0) {
            activeTypes.add('Private Vehicle');
        }
        this.expenseTypeOptions = this.expenseTypeOptions.map(opt => ({
            ...opt,
            checked: activeTypes.has(opt.value)
        }));

        this.editDataLoaded = true;
        this.refreshAllRowCalculations();

        if (this.isPrivateVehicleSelected && this.hasTravelDates) {
            this.fetchPrivateVehicleExpenses();
        }
    }

    // Builds a UI row exactly like createNewRow, then overlays the saved line values
    mapLineToRow(line, files) {
        const type = line.Expense_Type__c;
        const row = this.createNewRow(type);
        row.lineId = line.Id;
        row.amount = line.Amount__c;
        row.startDate = line.Start_Date__c || line.Date__c || null;
        row.endDate = type === 'Lodging' ? (line.End_Date__c || null) : null;
        if (row.isAir || row.isTrain) {
            row.selectedValue = line.Travel_Class__c || row.selectedValue;
        } else if (row.isRoadways) {
            row.selectedValue = line.Vehicle_Type__c || row.selectedValue;
        }
        row.distanceKm = line.Distance_KM__c != null ? line.Distance_KM__c : null;
        row.justification = line.Justification__c || '';
        row.miscellaneousCost = line.Miscellaneous_Cost__c || '';

        files.forEach(f => {
            const fileObj = {
                id: Date.now() + Math.random().toString(),
                fileName: f.fileName,
                documentId: f.documentId,
                extension: f.extension,
                fileType: f.fileType,
                isExisting: true
            };
            if (f.fileType === 'Proof') {
                row.proofs.push(fileObj);
            } else {
                row.bills.push(fileObj);
            }
        });
        return row;
    }

    // Private Vehicle lines already on the rejected expense are not returned by the New/Draft query
    mergeExistingPvLines(data) {
        const fetched = data || [];
        const fetchedIds = new Set(fetched.map(item => item.Id));
        const existing = this.existingPvLines.filter(item => !fetchedIds.has(item.Id));
        return [...existing, ...fetched];
    }

    // Existing files are only deleted on resubmit, so leaving the page without saving loses nothing
    markExistingFileRemoved(documentId) {
        if (documentId && !this.removedDocumentIds.includes(documentId)) {
            this.removedDocumentIds = [...this.removedDocumentIds, documentId];
        }
    }

    markRowRemovedForEdit(row) {
        if (row.lineId && !this.removedLineIds.includes(row.lineId)) {
            this.removedLineIds = [...this.removedLineIds, row.lineId];
        }
        [...(row.bills || []), ...(row.proofs || [])]
            .filter(f => f.isExisting)
            .forEach(f => this.markExistingFileRemoved(f.documentId));
    }

    resubmitExpense(payload) {
        const editPayload = {
            ...payload,
            expenseId: this.editExpenseId,
            removedLineIds: this.removedLineIds,
            removedDocumentIds: this.removedDocumentIds
        };

        this.isSaving = true;
        resubmitExpenseData({ payload: JSON.stringify(editPayload) })
            .then(result => {
                this.showToast('Success', `Expense claim ${result} resubmitted successfully`, 'success');
                // Expense is no longer Rejected: block a second resubmit from this page
                this.editDataLoaded = false;
                this.navigateToExpenseRecord();
            })
            .catch(error => {
                this.showToast('Error resubmitting record', this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isSaving = false;
            });
    }

    navigateToExpenseRecord() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.editExpenseId,
                objectApiName: 'Expense__c',
                actionName: 'view'
            }
        });
    }

    // ===== END EDIT MODE =================================================
}
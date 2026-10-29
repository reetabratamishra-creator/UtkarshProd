import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCurrentStateForUser from '@salesforce/apex/PunchController.getCurrentStateForUser';
import punchNowAsUser from '@salesforce/apex/PunchController.punchNowAsUser';
import submitWFHRequest from '@salesforce/apex/PunchController.submitWFHRequest';
import extractOdometerReading from '@salesforce/apex/OdometerExtractionService.extractOdometerReading';
import savePeriodicLocation from '@salesforce/apex/PunchController.savePeriodicLocation';
import checkLocationData from '@salesforce/apex/PunchController.checkLocationData';
import updatePunchTypeAndOdometer from '@salesforce/apex/PunchController.updatePunchTypeAndOdometer';

export default class UserPunch extends LightningElement {

    // ── State ──────────────────────────────────────────────────────────────
    @track loading      = true;
    @track stateLoaded  = false;
    @track isPunching   = false;
    @track error;

    @track employeeName;
    @track userId;
    @track currentStatus; // 'IN' | 'OUT'
    @track lastPunchTime;
    @track lastBattery;
    @track lastOdometerUrl;
    @track lastPunchType;
    @track lastLat;
    @track lastLng;
    @track lastTransportType;
    @track lastVehicleType;

    @track punchType = '';
    @track wfhActivity = '';
    @track transportType = ''; // 'Public', 'Private'
    @track vehicleType = ''; // 'Two', 'Four'
    @track odometerReading = '';
    @track extractedOdometer = '';

    @track selfiePreview = '';
    @track odometerPreview = '';
    @track showImageModal = false;
    @track isSelfieCameraOpen = false;
    @track isOdoCameraOpen = false;

    // AI Extraction State
    @track isExtractingOdometer = false;
    @track isUpdatingMode = false;
    @track isEditingMode = false;

    // WFH Request
    @track isWFHApprovedForToday = false;
    @track isWFOApproved = false;
    @track requestedDate = null;
    @track wfhStartTime = null;
    @track wfhEndTime = null;
    @track wfhRequestStatusTomorrow = '';
    @track wfhReqStart = '09:00:00.000';
    @track wfhReqEnd = '18:00:00.000';
    @track varReqDate = new Date().toISOString().split('T')[0]; 
    @track isSubmittingReq = false;
    @track selectedValue = 'WFO';
    @track wfhRequests = [];
    @track hasActiveCheckIn = false;
    @track hasUnclosedWfhWfo = false;
    @track requestNote = '';
    @track isWfhRequestExpanded = true;

    @track showActivationModal = false;
    @track activeDeviceTab = 'Android';
    @track dataVerified = false;
    @track isCheckingData = false;
    @track showSetupInstructions = false;

    // Day Activity Log (required when ending WFH / WFO)
    @track showDayActivityModal = false;
    @track dayActivityPhoneCalls = '';
    @track dayActivityEmails = '';
    @track dayActivityOffersSent = '';
    @track dayActivityMeetings = '';
    @track dayActivityOpenNotes = '';
    @track isSubmittingDayActivity = false;

    picklistValues = [
        { label: 'WFO', value: 'WFO' },
        { label: 'WFH', value: 'WFH' },
    ];

    handleChange(event) {
        this.selectedValue = event.detail.value;
    }

    odoStream;
    trackingIntervalId;

    // ── Lifecycle ──────────────────────────────────────────────────────────
    connectedCallback() {
        this.loadState();
    }

    disconnectedCallback() {
        this.stopStreams();
        this.stopTracking();
    }

    renderedCallback() {
        if (this.isSelfieCameraOpen) {
            const selfieVideo = this.template.querySelector('.up-video-selfie');
            if (selfieVideo && selfieVideo.srcObject !== this.selfieStream) {
                selfieVideo.setAttribute('playsinline', 'true');
                selfieVideo.setAttribute('webkit-playsinline', 'true');
                selfieVideo.setAttribute('muted', 'true');
                selfieVideo.playsInline = true;
                selfieVideo.muted = true;
                selfieVideo.srcObject = this.selfieStream;
                selfieVideo.play().catch(err => console.warn('Play error:', err));
            }
        }
        if (this.isOdoCameraOpen) {
            const odoVideo = this.template.querySelector('.up-video-odometer');
            if (odoVideo && odoVideo.srcObject !== this.odoStream) {
                odoVideo.setAttribute('playsinline', 'true');
                odoVideo.setAttribute('webkit-playsinline', 'true');
                odoVideo.setAttribute('muted', 'true');
                odoVideo.playsInline = true;
                odoVideo.muted = true;
                odoVideo.srcObject = this.odoStream;
                odoVideo.play().catch(err => console.warn('Play error:', err));
            }
        }
        // lightning-input has no inputmode attribute, so the numeric keypad has
        // to be requested on the underlying input element.
        this.template.querySelectorAll('.up-number-input').forEach((cmp) => {
            const input = cmp.querySelector ? cmp.querySelector('input') : null;
            if (input && input.inputMode !== 'numeric') {
                input.inputMode = 'numeric';
            }
        });
    }

    // ── Data load ──────────────────────────────────────────────────────────
    loadState() {
        this.loading = true;
        this.error   = undefined;

        getCurrentStateForUser()
            .then((data) => {
                if (data) {
                    this.employeeName    = data.employeeName;
                    this.userId          = data.userId;
                    this.currentStatus   = data.currentStatus || 'OUT';
                    this.lastPunchTime   = data.lastPunchTime;
                    this.lastBattery     = data.lastBattery;
                    this.lastOdometerUrl = data.lastOdometerUrl;
                    this.lastPunchType   = data.lastPunchType;
                    this.lastLat         = data.lastLat;
                    this.lastLng         = data.lastLng;
                    this.lastTransportType = data.lastTransportType;
                    this.lastVehicleType = data.lastVehicleType;
                    
                    this.isWFHApprovedForToday = data.isWFHApprovedForToday;
                    this.isWFOApproved   = data.isWFOApproved;
                    this.requestedDate   = data.requestedDate;
                    this.wfhStartTime    = data.wfhStartTime;
                    this.wfhEndTime      = data.wfhEndTime;
                    this.wfhRequestStatusTomorrow = data.wfhRequestStatusTomorrow;
                    this.wfhRequests     = this.formatWfhRequests(data.wfhRequests || []);
                    this.hasActiveCheckIn = data.hasActiveCheckIn || false;
                    this.hasUnclosedWfhWfo = data.hasUnclosedWfhWfo || false;

                    this.stateLoaded     = true;

                    // Initialize punch/mode inputs if already punched in
                    this.punchType = this.isPunchedIn ? (data.lastPunchType || '') : '';
                    if (this.isPunchedIn) {
                        this.transportType = data.lastTransportType || '';
                        this.vehicleType = data.lastVehicleType || '';
                        this.isEditingMode = !data.lastPunchType;
                    } else {
                        this.isEditingMode = true;
                    }
                }
                console.log('UserPunch - loadState data', JSON.stringify(data));
                console.log('UserPunch - loadState data', JSON.stringify(data.currentStatus));
                this.loading = false;
                
                // Start tracking if already punched in
                if (this.isPunchedIn) {
                    this.startTracking();
                }
                else{
                    this.stopTracking();
                }
            })
            .catch((err) => {
                console.error('UserPunch - loadState error', err);
                this.error   = 'Failed to load your punch status.';
                this.loading = false;
            });
    }

    get hasWfhRequests() {
        return this.wfhRequests && this.wfhRequests.length > 0;
    }

    formatWfhRequests(requests) {
        return (requests || []).map(req => {
            const type = (req.type || 'WFH').toLowerCase();
            const status = (req.status || 'Pending').toLowerCase();
            const remarks = (req.remarks || '').trim();
            const approverName = (req.approverName || '').trim();
            return {
                ...req,
                type: req.type || 'WFH',
                status: req.status || 'Pending',
                remarks,
                approverName,
                hasRemarks: remarks.length > 0,
                hasApprover: approverName.length > 0,
                formattedDate: this.formatDateString(req.requestDate),
                typeBorderClass: `up-wfh-border-${type}`,
                typeBadgeClass: `up-type-badge type-${type}`,
                statusBadgeClass: `up-status-badge status-${status}`
            };
        });
    }

    formatDateString(dateStr) {
        if (!dateStr) return '';
        try {
            const raw = String(dateStr);
            const isoDate = raw.includes('T') ? raw.split('T')[0] : raw;
            const parts = isoDate.split('-');
            if (parts.length === 3) {
                const year = parts[0];
                const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                const month = monthNames[parseInt(parts[1], 10) - 1];
                const day = parseInt(parts[2], 10);
                if (!month || isNaN(day)) return raw;
                return `${day} ${month} ${year}`;
            }
            return raw;
        } catch (e) {
            return String(dateStr);
        }
    }

    // ── Image Modal ────────────────────────────────────────────────────────
    openImageModal() {
        this.showImageModal = true;
    }

    closeImageModal() {
        this.showImageModal = false;
    }

    // ── Category Handlers ──────────────────────────────────────────────────
    selectWFO() { 
        this.punchType = this.punchType === 'WFO' ? '' : 'WFO'; 
    }
    selectWFH() { 
        this.punchType = this.punchType === 'WFH' ? '' : 'WFH'; 
    }
    selectMarketVisit() { 
        if (this.punchType === 'Market Visit') {
            this.punchType = '';
            this.transportType = '';
            this.vehicleType = '';
            this.odometerReading = '';
            this.extractedOdometer = '';
            this.odometerPreview = '';
        } else {
            this.punchType = 'Market Visit';
            if (this.lastPunchType !== 'Market Visit') {
                this.transportType = '';
                this.vehicleType = '';
                this.odometerReading = '';
                this.extractedOdometer = '';
                this.odometerPreview = '';
            } else {
                this.transportType = this.lastTransportType || '';
                this.vehicleType = this.lastVehicleType || '';
            }
        }
    }

    setWfoRequest() {
        this.selectedValue = 'WFO';
    }
    setWfhRequest() {
        this.selectedValue = 'WFH';
    }

    toggleWfhRequestSection() {
        this.isWfhRequestExpanded = !this.isWfhRequestExpanded;
    }

    get wfhRequestCollapseHeaderClass() {
        return 'up-wfh-collapse-header' + (this.isWfhRequestExpanded ? ' up-wfh-collapse-open' : '');
    }

    get wfhRequestChevronIcon() {
        return this.isWfhRequestExpanded ? 'utility:chevronup' : 'utility:chevrondown';
    }

    handleWFHActivityChange(event) {
        this.wfhActivity = event.target.value;
    }

    handleRequestNoteChange(event) {
        this.requestNote = event.target.value;
    }

    selectPublicTransport() { 
        this.transportType = 'Public Transport'; 
        this.vehicleType = '';
    }
    selectPrivateVehicle() { 
        this.transportType = 'Private Vehicle'; 
    }

    selectTwoWheeler() { 
        if (this.vehicleType !== 'Two Wheeler') {
            this.vehicleType = 'Two Wheeler';
        }
    }
    selectFourWheeler() { 
        if (this.vehicleType !== 'Four Wheeler') {
            this.vehicleType = 'Four Wheeler';
        }
    }

    clearOdometerData() {
        this.odometerReading = '';
        this.extractedOdometer = '';
    }

    handleOdometerChange(event) {
        const digitsOnly = (event.target.value || '').replace(/\D/g, '');
        this.odometerReading = digitsOnly;
        if (event.target.value !== digitsOnly) {
            event.target.value = digitsOnly;
        }
    }

    // WFH Request Handlers
    handleReqDateChange(event) { 
        this.varReqDate = event.target.value;
     }
    handleWfhReqStartChange(event) { 
        this.wfhReqStart = event.target.value; 
    }
    handleWfhReqEndChange(event) { 
        this.wfhReqEnd = event.target.value; 
    }

    validateAllFields() {
        let isValid = true;

        const today = new Date();
        const todayStr = today.toISOString().split('T')[0];

        // Past Date Validation
        if (this.varReqDate && this.varReqDate < todayStr) {
            this.showToast('Error', 'Past date selection is not allowed', 'error');
            isValid = false;
        }

        // Required validation
        if (!this.varReqDate) {
            this.showToast('Error', 'Please select a date', 'error');
            isValid = false;
        }

        if (!this.wfhReqStart) {
            this.showToast('Error', 'Please select a start time', 'error');
            isValid = false;
        }

        if (!this.wfhReqEnd) {
            this.showToast('Error', 'Please select an end time', 'error');
            isValid = false;
        }

        // Past Time Validation (only for today)
        if (this.varReqDate === todayStr && this.wfhReqStart) {
            const now = new Date();
            const currentMinutes = now.getHours() * 60 + now.getMinutes();

            const [h, m] = this.wfhReqStart.split(':').map(Number);
            const selectedMinutes = h * 60 + m;

            if (selectedMinutes < currentMinutes) {
                this.showToast('Error', 'Start time cannot be in the past', 'error');
                isValid = false;
            }
        }

        // End > Start Validation
        if (this.wfhReqStart && this.wfhReqEnd) {
            const [sh, sm] = this.wfhReqStart.split(':').map(Number);
            const [eh, em] = this.wfhReqEnd.split(':').map(Number);

            const startMin = sh * 60 + sm;
            const endMin = eh * 60 + em;

            if (endMin <= startMin) {
                this.showToast('Error', 'End time must be after start time', 'error');
                isValid = false;
            }
        }

        return isValid;
    }

    handleWfhRequestSubmit() {
        if (!this.wfhReqStart || !this.wfhReqEnd) {
            this.showToast('Validation Error', 'Please provide both start and end times.', 'error');
            return;
        }
        if (!this.requestNote || !this.requestNote.trim()) {
            this.showToast('Validation Error', 'Please enter a Reason / Note for this request.', 'error');
            return;
        }

        const isValid = this.validateAllFields();
        if (!isValid) {
            return;
        }

        this.isSubmittingReq = true;

        this.detectDevice();

        submitWFHRequest({
            reqDate: this.varReqDate,
            startTimeStr: this.wfhReqStart,
            endTimeStr: this.wfhReqEnd,
            catagory : this.selectedValue,
            requestNote: this.requestNote,
            deviceOS: this.deviceOS,
            deviceModel: this.deviceModel
        })
        .then(() => {
            this.showToast('Success', `${this.selectedValue} request submitted successfully.`, 'success');
            this.requestNote = '';
            return this.loadState(); // Refresh status
        })
        .catch(err => {
            console.error('Error submitting request', err);
            const msg = err?.body?.message || err?.message || 'Failed to submit request.';
            this.showToast('Error', msg, 'error');
        })
        .finally(() => {
            this.isSubmittingReq = false;
        });
    }

    // ── Computed properties ────────────────────────────────────────────────
    get isPunchedIn() {
        return this.currentStatus === 'IN';
    }

    get isIOS() {
        return /iPad|iPhone|iPod/.test(navigator.userAgent) || 
            (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    }

    get androidTabClass() {
        return 'up-device-tab ' + (this.activeDeviceTab === 'Android' ? 'up-device-tab-active' : '');
    }

    get iosTabClass() {
        return 'up-device-tab ' + (this.activeDeviceTab === 'iOS' ? 'up-device-tab-active' : '');
    }

    get isAndroidTabActive() {
        return this.activeDeviceTab === 'Android';
    }

    get isIosTabActive() {
        return this.activeDeviceTab === 'iOS';
    }

    selectAndroidTab() {
        this.activeDeviceTab = 'Android';
    }

    selectIosTab() {
        this.activeDeviceTab = 'iOS';
    }

    get step2Instruction() {
        return this.activeDeviceTab === 'iOS' 
            ? 'Copy the URL below and paste it into the Receiver/Endpoint URL field in Overland GPS Tracker.'
            : 'Copy the URL below and paste it into the custom URL field in GPS Logger.';
    }

    get isWFH() { return this.punchType === 'WFH'; }
    get isMarketVisit() { return this.punchType === 'Market Visit'; }
    get isPrivateVehicle() { 
        return this.punchType === 'Market Visit' && this.transportType === 'Private Vehicle'; 
    }
    // Mode/odometer capture is only after Day In (via mode start/end), never bundled with Day In
    get showTopMarketVisitFlow() {
        return false;
    }
    get showTopOdometerCapture() {
        return false;
    }
    get hasActiveMode() {
        return !!this.lastPunchType;
    }
    /* get isWFHApprovedForToggle() { return this.isWFHApprovedForToday; }
    get isWFOApprovedForToggle() { return this.isWFOApproved; } */

    get isMarketVisitActiveMode() {
        return this.lastPunchType === 'Market Visit';
    }

    get isPrivateVehicleActiveMode() {
        return this.lastTransportType === 'Private Vehicle';
    }

    get activeModeButtonLabel() {
        if (this.punchType === 'Market Visit') {
            return 'Start Market Visit';
        } else if (this.punchType === 'WFO') {
            return 'Start WFO';
        } else if (this.punchType === 'WFH') {
            return 'Start WFH';
        }
        return 'Start Mode';
    }

    get endActiveModeButtonLabel() {
        if (this.lastPunchType === 'Market Visit') {
            return 'End Market Visit';
        } else if (this.lastPunchType === 'WFO') {
            return 'End WFO';
        } else if (this.lastPunchType === 'WFH') {
            return 'End WFH';
        }
        return 'End Mode';
    }

    get dayActivityTitle() {
        if (this.lastPunchType === 'WFO') {
            return 'Work From Office Activity';
        }
        return 'Work From Home Activity';
    }

    get isEndingWfhOrWfo() {
        return this.lastPunchType === 'WFH' || this.lastPunchType === 'WFO';
    }

    get buttonLabel() {
        return this.isPunchedIn ? 'Day Out' : 'Day In';
    }

    get punchBtnIcon() {
        return this.isPunchedIn ? 'utility:logout' : 'utility:login';
    }

    get punchBtnClass() {
        return 'up-punch-btn ' + (this.isPunchedIn ? 'up-punch-out' : 'up-punch-in');
    }

    get statusLabel() {
        if (this.isPunchedIn) {
            return this.punchType ? `DAY IN - ${this.punchType}` : 'DAY IN';
        }
        return 'DAY OUT';
    }

    get statusBadgeClass() {
        return 'up-badge ' + (this.isPunchedIn ? 'up-badge-in' : 'up-badge-out');
    }

    get statusRingClass() {
        return this.isPunchedIn ? 'up-ring-in' : 'up-ring-out';
    }

    // Class getters for selection UI
    get wfoClass() { return 'up-toggle-item ' + (this.punchType === 'WFO' ? 'up-active up-active-wfo' : ''); }
    get wfhClass() { return 'up-toggle-item ' + (this.punchType === 'WFH' ? 'up-active up-active-wfh' : ''); }
    get marketVisitClass() { return 'up-toggle-item ' + (this.punchType === 'Market Visit' ? 'up-active up-active-market' : ''); }

    get publicTransportClass() { return 'up-toggle-item ' + (this.transportType === 'Public Transport' ? 'up-active' : ''); }
    get privateVehicleClass() { return 'up-toggle-item ' + (this.transportType === 'Private Vehicle' ? 'up-active' : ''); }

    get twoWheelerClass() { return 'up-toggle-item ' + (this.vehicleType === 'Two Wheeler' ? 'up-active' : ''); }
    get fourWheelerClass() { return 'up-toggle-item ' + (this.vehicleType === 'Four Wheeler' ? 'up-active' : ''); }

    get wfoReqToggleClass() {
        return 'up-toggle-item ' + (this.selectedValue === 'WFO' ? 'up-active up-active-wfo' : '');
    }
    get wfhReqToggleClass() {
        return 'up-toggle-item ' + (this.selectedValue === 'WFH' ? 'up-active up-active-wfh' : '');
    }
    get updateModeButtonLabel() {
        return this.isEditingMode ? 'Update Mode' : 'Change Mode';
    }
    get setupInstructionsButtonLabel() {
        return this.showSetupInstructions ? 'Hide Setup Instructions' : 'How to Setup';
    }



    get captureStepLabel() {
        return (this.isPrivateVehicle && !this.isPunchedIn) ? '(Steps 1 & 2)' : '(Process)';
    }

    get captureGridClass() {
        return 'up-capture-grid ' + ((this.isPrivateVehicle && !this.isPunchedIn) ? 'up-dual-grid' : 'up-single-grid');
    }

    get lastPunchDisplay() {
        if (!this.lastPunchTime) return '';
        try {
            return new Date(this.lastPunchTime).toLocaleString('en-IN', {
                dateStyle: 'medium',
                timeStyle: 'short'
            });
        } catch (e) {
            return this.lastPunchTime;
        }
    }

    get lastLocationDisplay() {
        if (this.lastLat != null && this.lastLng != null) {
            const latNum = Number(this.lastLat);
            const lngNum = Number(this.lastLng);
            
            if (!isNaN(latNum) && !isNaN(lngNum)) {
                return `${latNum.toFixed(4)}, ${lngNum.toFixed(4)}`;
            }
        }
        return '';
    }

    get lastBatteryDisplay() {
        return this.lastBattery ? Math.round(this.lastBattery) : null;
    }

    get showWFHRequestForm() {
        return this.punchType !== 'Market Visit';
    }

    get showTodayApprovalBanner() {
        return this.isWFHApprovedForToday || this.isWFOApproved;
    }

    get todayApprovalMessage() {
        if (this.isWFHApprovedForToday) {
            return 'WFH approved for today — you can punch in as WFH during the approved window.';
        }
        if (this.isWFOApproved) {
            return 'WFO approved for today — you can punch in as WFO during the approved window.';
        }
        return '';
    }

    get hasWFHRequestTomorrow() {
        return this.wfhRequestStatusTomorrow && (this.wfhRequestStatusTomorrow === 'Pending' || this.wfhRequestStatusTomorrow === 'Approved');
    }

    get isWFHRequestApprovedTomorrow() {
        return this.wfhRequestStatusTomorrow === 'Approved';
    }

    /* get isWFHTimely() {
        if (!this.isWFHApprovedForToday || !this.wfhStartTime || !this.wfhEndTime) return false;
        
        const now = new Date();
        const currentMillis = (now.getHours() * 3600000) + (now.getMinutes() * 60000) + (now.getSeconds() * 1000) + now.getMilliseconds();
        
        const start = this.parseTime(this.wfhStartTime);
        const end   = this.parseTime(this.wfhEndTime);
        
        return currentMillis >= start && currentMillis <= end;
    }

    get wfhButtonDisabled() {
        return !this.isWFHApprovedForToday || !this.isWFHTimely;
    } */


    get isWFHApprovedForToggle() {
        return this.isWFHApprovedForToday && this.isWFHTimely;
    }

    get isWFOApprovedForToggle() {
        return this.isWFOApproved && this.isWFOTimely;
    }

    get isWFHTimely() {
        return this.isApprovedRequestActive('WFH');
    }

    get isWFOTimely() {
        return this.isApprovedRequestActive('WFO');
    }

    isApprovedRequestActive(type) {
        const today = new Date().toISOString().split('T')[0];

        const now = new Date();
        const currentMillis =
            (now.getHours() * 3600000) +
            (now.getMinutes() * 60000) +
            (now.getSeconds() * 1000);

        return (this.wfhRequests || []).some(req => {
            if (
                req.type !== type ||
                req.status !== 'Approved' ||
                req.requestDate !== today ||
                !req.startTime ||
                !req.endTime
            ) {
                return false;
            }

            const start = this.parseTime(req.startTime);
            const end = this.parseTime(req.endTime);

            return currentMillis >= start && currentMillis <= end;
        });
    }


    get wfhButtonTitle() {
        if (!this.isWFHApprovedForToday) return 'WFH is only available if approved for today.';
        if (!this.isWFHTimely) return `WFH is only available between ${this.formatTime(this.wfhStartTime)} and ${this.formatTime(this.wfhEndTime)}.`;
        return 'Punch in as WFH';
    }

    parseTime(val) {
        if (typeof val === 'number') return val;
        if (typeof val === 'string') {
            const parts = val.split(':');
            if (parts.length >= 2) {
                return (parseInt(parts[0], 10) * 3600000) + (parseInt(parts[1], 10) * 60000);
            }
        }
        return 0;
    }

    formatTime(val) {
        if (val == null) return '';
        if (typeof val === 'string') return val.substring(0, 5);
        
        const date = new Date(val);
        const h = date.getUTCHours().toString().padStart(2, '0');
        const m = date.getUTCMinutes().toString().padStart(2, '0');
        return `${h}:${m}`;
    }

    /* get activationUrl() {
        const baseUrl = 'https://momentum-customer-397--utkarshuat.sandbox.my.salesforce-sites.com/logging/services/apexrest/updatelocation?';
        return `${baseUrl}myId=${this.userId}`;
    } */
    get activationUrl() {
        const hostname = window.location.hostname;

        const siteDomain = hostname
            .replace('.lightning.force.com', '.my.salesforce-sites.com');

        return `https://${siteDomain}/logging/services/apexrest/updatelocation?myId=${this.userId}`;
    }

    get doneButtonDisabled() {
        return !this.dataVerified;
    }

    // ── Punch handler ──────────────────────────────────────────────────────
    handlePunch() {
        if (this.isPunchedIn) {
            this.isPunching = true;
            getCurrentStateForUser()
                .then((data) => {
                    this.hasActiveCheckIn = data.hasActiveCheckIn || false;
                    this.hasUnclosedWfhWfo = data.hasUnclosedWfhWfo || false;
                    this.isPunching = false;
                    this.continuePunchAfterCheckInValidation();
                })
                .catch((err) => {
                    this.isPunching = false;
                    console.error('Error verifying active visit status:', err);
                    this.showToast('Error', 'Failed to verify active visit status.', 'error');
                });
        } else {
            this.continuePunchAfterCheckInValidation();
        }
    }

    continuePunchAfterCheckInValidation() {
        // Day In / Day Out only — mode of work is a separate nested step
        if (!this.isPunchedIn) {
            if (!this.selfiePreview) {
                this.showToast('Action Required', 'Please capture a selfie before Day In.', 'error');
                return;
            }
        } else {
            if (this.hasActiveMode) {
                this.showToast('Action Blocked', 'Please end your active mode of work before Day Out.', 'error');
                return;
            }
            if (this.hasActiveCheckIn) {
                this.showToast('Action Blocked', 'You have an active visit check-in. Please check out of your active visit before Day Out.', 'error');
                return;
            }
            if (this.hasUnclosedWfhWfo) {
                this.showToast('Action Blocked', 'You cannot Day Out because your approved WFH/WFO request for today is not closed (checked in and checked out).', 'error');
                return;
            }
            if (!this.selfiePreview) {
                this.showToast('Action Required', 'Please capture a selfie before Day Out.', 'error');
                return;
            }
        }

        if (!navigator.geolocation) {
            this.showToast('Error', 'Geolocation is not supported on this device.', 'error');
            return;
        }

        this.isPunching = true;
        this.error      = undefined;

        navigator.geolocation.getCurrentPosition(
            (pos) => {
                const lat = pos.coords.latitude;
                const lng = pos.coords.longitude;

                this.fetchBattery()
                    .then((battery) => {
                        this.callPunchNow(lat, lng, battery);
                    })
                    .catch(() => {
                        this.callPunchNow(lat, lng, null);
                    });
            },
            (err) => {
                console.error('Geolocation error', err);
                this.isPunching = false;
                
                let errorMsg = 'Unable to get device location. Please allow location access.';
                if (err.code === 1) {
                    errorMsg = 'Location permission denied. Please enable location services in your browser or device settings.';
                } else if (err.code === 2) {
                    errorMsg = 'Location unavailable. Ensure your GPS is turned on.';
                } else if (err.code === 3) {
                    errorMsg = 'Location request timed out. Please try again.';
                }
                
                this.error = errorMsg;
                this.showToast('Location Error', errorMsg, 'error');
            },
            { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
        );
    }

    fetchBattery() {
        if (navigator.getBattery) {
            return navigator.getBattery().then((b) => Math.round(b.level * 100));
        }
        return Promise.resolve(null);
    }

    detectDevice() {
        const ua = navigator.userAgent;
        let os = 'Unknown OS';
        let device = 'Unknown Device';

        if (/Android/i.test(ua)) {
            os = 'Android';
            const modelMatch = ua.match(/\(([^;]+);\s*([^;]+);\s*([^;)]+)\)/);
            device = (modelMatch && modelMatch.length > 3)
                ? modelMatch[3].trim()
                : 'Android Phone';
        } else if (/iPhone/i.test(ua)) {
            os = 'iOS';
            device = 'iPhone';
        } else if (/iPad/i.test(ua)) {
            os = 'iOS';
            device = 'iPad';
        } else if (/Macintosh/i.test(ua)) {
            os = 'macOS';
            device = 'Mac';
        } else if (/Windows/i.test(ua)) {
            os = 'Windows';
            device = 'PC';
        }

        this.deviceOS = os;
        this.deviceModel = device;

        return {
            os,
            device
        };
    }

    callPunchNow(lat, lng, battery) {
        const ua = navigator.userAgent;
        /* let os = 'Unknown OS';
        let device = 'Unknown Device';

        if (/Android/i.test(ua)) {
            os = 'Android';
            const modelMatch = ua.match(/\(([^;]+);\s*([^;]+);\s*([^;)]+)\)/);
            device = (modelMatch && modelMatch.length > 3) ? modelMatch[3].trim() : 'Android Phone';
        } else if (/iPhone/i.test(ua)) {
            os = 'iOS';
            device = 'iPhone';
        } else if (/iPad/i.test(ua)) {
            os = 'iOS';
            device = 'iPad';
        } else if (/Macintosh/i.test(ua)) {
            os = 'macOS';
            device = 'Mac';
        } else if (/Windows/i.test(ua)) {
            os = 'Windows';
            device = 'PC';
        }

        this.deviceOS = os;
        this.deviceModel = device; */
        const { os, device } = this.detectDevice();

        punchNowAsUser({
            latitude:             lat,
            longitude:            lng,
            battery:              battery,
            selfieImageBase64:    this.selfiePreview || null,
            odometerImageBase64:  null,
            fileName:             'punch_' + Date.now() + '.jpg',
            punchType:            '',
            wfhActivity:          null,
            transportType:        null,
            vehicleType:          null,
            odometerReading:      null,
            extractedOdometer:    null,
            deviceOS:             os,
            deviceModel:          device,
            userAgent:            ua
        })
            .then((state) => {
                this.currentStatus   = state.currentStatus;
                this.lastPunchTime   = state.lastPunchTime;
                this.lastBattery     = state.lastBattery;
                this.lastLat         = state.lastLat;
                this.lastLng         = state.lastLng;
                this.lastOdometerUrl = state.lastOdometerUrl;
                this.lastPunchType   = state.lastPunchType;
                this.lastTransportType = state.lastTransportType;
                this.lastVehicleType = state.lastVehicleType;
                this.isPunching      = false;

                // Sync punchType inputs and editing mode
                this.punchType = this.isPunchedIn ? (state.lastPunchType || '') : '';
                if (this.isPunchedIn) {
                    this.transportType = state.lastTransportType || '';
                    this.vehicleType = state.lastVehicleType || '';
                    this.isEditingMode = !state.lastPunchType;
                } else {
                    this.punchType = '';
                    this.transportType = '';
                    this.vehicleType = '';
                    this.isEditingMode = true;
                }
                
                // Clear state after successful punch
                this.selfiePreview = '';
                this.odometerPreview = '';
                this.wfhActivity = '';
                this.odometerReading = '';
                this.extractedOdometer = '';
                
                // Start or stop tracking based on new status
                if (this.isPunchedIn) {
                    this.startTracking();
                } else {
                    this.stopTracking();
                }

                const action = this.isPunchedIn ? 'started your day (Day In)' : 'ended your day (Day Out)';
                this.showToast('Success', `You have successfully ${action}.`, 'success');

                // If punched in, show the activation modal
                if (this.isPunchedIn) {
                    this.showActivationModal = true;
                    this.activeDeviceTab = this.isIOS ? 'iOS' : 'Android';
                    this.dataVerified = false;
                    this.isEditingMode = true;
                }
            })
            .catch((err) => {
                console.error('UserPunch - punchNowAsUser error', err);
                this.isPunching = false;
                const msg = (err.body && err.body.message) ? err.body.message : 'Punch failed. Please try again.';
                this.error = msg;
                this.showToast('Error', msg, 'error');
            });
    }

    // ── Periodic Tracking ──────────────────────────────────────────────────
    handleCopyUrl() {
        const url = this.activationUrl;
        const el = document.createElement('textarea');
        el.value = url;
        document.body.appendChild(el);
        el.select();
        document.execCommand('copy');
        document.body.removeChild(el);
        this.showToast('Copied', 'URL copied to clipboard', 'success');
    }

    checkDataArrival() {
        this.isCheckingData = true;
        checkLocationData({ userId: this.userId })
            .then(result => {
                this.dataVerified = result;
                if (result) {
                    this.showToast('Verified', 'Location data is arriving successfully!', 'success');
                } else {
                    this.showToast('Not Found', 'No data received yet. Please ensure GPS Logger is running.', 'warning');
                }
            })
            .catch(err => {
                console.error('Error checking data arrival', err);
            })
            .finally(() => {
                this.isCheckingData = false;
            });
    }

    openActivationModal() {
        this.showActivationModal = true;
    }

    closeActivationModal() {
        this.showActivationModal = false;
    }

    toggleSetupInstructions() {
        this.showSetupInstructions = !this.showSetupInstructions;
    }

    startTracking() {
        // this.stopTracking();
        //console.log('UserPunch - Starting periodic tracking (1 min)');
        // this.trackingIntervalId = setInterval(() => {
        //     console.log('UserPunch - Tracking location');
        //     this.executePeriodicTracking();
        // }, 60000); 
    }

    stopTracking() {
        if (this.trackingIntervalId) {
            clearInterval(this.trackingIntervalId);
            this.trackingIntervalId = null;
        }
    }

    executePeriodicTracking() {
        if (!this.isPunchedIn) {
            this.stopTracking();
            return;
        }

        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (pos) => {
                    const lat = pos.coords.latitude;
                    const lng = pos.coords.longitude;
                    this.fetchBattery()
                        .then((battery) => this.saveLocation(lat, lng, battery))
                        .catch(() => this.saveLocation(lat, lng, null));
                },
                (err) => console.warn('Periodic tracking error:', err.message),
                { enableHighAccuracy: false, timeout: 10000, maximumAge: 60000 }
            );
        }
    }

    saveLocation(lat, lng, battery) {
        savePeriodicLocation({ latitude: lat, longitude: lng, battery: battery })
            .catch(err => console.error('Failed to save periodic location', err));
    }

    // ── Camera helpers ─────────────────────────────────────────────────────
    openSelfieCamera() {
        this.stopStreams();
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            this.showToast('Error', 'Camera not supported on this device.', 'error');
            return;
        }

        // Slight delay to allow hardware resources to fully release before requesting new stream
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const constraintsList = [
                { video: { facingMode: 'user' }, audio: false },
                { video: { facingMode: { ideal: 'user' } }, audio: false },
                { video: true, audio: false }
            ];

            let attempt = (index) => {
                if (index >= constraintsList.length) {
                    this.showToast('Error', 'Could not open selfie camera: all camera constraints failed.', 'error');
                    return;
                }
                navigator.mediaDevices.getUserMedia(constraintsList[index])
                    .then((stream) => {
                        this.selfieStream = stream;
                        this.isSelfieCameraOpen = true;
                    })
                    .catch((err) => {
                        console.warn(`Selfie camera attempt ${index} failed:`, err);
                        if (index === constraintsList.length - 1) {
                            this.showToast('Error', 'Could not open selfie camera: ' + err.message, 'error');
                        } else {
                            attempt(index + 1);
                        }
                    });
            };
            attempt(0);
        }, 200);
    }

    closeSelfieCamera() {
        try {
            const video = this.template.querySelector('.up-video-selfie');
            if (video) {
                video.srcObject = null;
            }
        } catch (e) {
            console.warn('Error releasing selfie video srcObject:', e);
        }
        if (this.selfieStream) {
            this.selfieStream.getTracks().forEach(track => {
                try {
                    track.stop();
                } catch (e) {
                    console.warn('Error stopping selfie track:', e);
                }
            });
            this.selfieStream = null;
        }
        this.isSelfieCameraOpen = false;
    }

    triggerSelfieCapture() {
        const input = this.template.querySelector('.up-selfie-file-input');
        if (input) {
            input.click();
        }
    }

    handleSelfieFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            const reader = new FileReader();
            reader.onload = () => {
                this.selfiePreview = reader.result;
            };
            reader.readAsDataURL(file);
        }
    }

    triggerOdoCapture() {
        const input = this.template.querySelector('.up-odo-file-input');
        if (input) {
            input.click();
        }
    }

    handleOdoFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            const reader = new FileReader();
            reader.onload = () => {
                this.odometerPreview = reader.result;
                this.handleAIExtraction();
            };
            reader.readAsDataURL(file);
        }
    }

    openOdoCamera() {
        this.stopStreams();
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            this.showToast('Error', 'Camera not supported on this device.', 'error');
            return;
        }

        // Slight delay to allow hardware resources to fully release before requesting new stream
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const constraintsList = [
                { video: { facingMode: { ideal: 'environment' } }, audio: false },
                { video: { facingMode: 'environment' }, audio: false },
                { video: true, audio: false }
            ];

            let attempt = (index) => {
                if (index >= constraintsList.length) {
                    this.showToast('Error', 'Could not open odometer camera: all camera constraints failed.', 'error');
                    return;
                }
                navigator.mediaDevices.getUserMedia(constraintsList[index])
                    .then((stream) => {
                        this.odoStream = stream;
                        this.isOdoCameraOpen = true;
                    })
                    .catch((err) => {
                        console.warn(`Odometer camera attempt ${index} failed:`, err);
                        if (index === constraintsList.length - 1) {
                            this.showToast('Error', 'Could not open odometer camera: ' + err.message, 'error');
                        } else {
                            attempt(index + 1);
                        }
                    });
            };
            attempt(0);
        }, 200);
    }

    closeOdoCamera() {
        try {
            const video = this.template.querySelector('.up-video-odometer');
            if (video) {
                video.srcObject = null;
            }
        } catch (e) {
            console.warn('Error releasing odometer video srcObject:', e);
        }
        if (this.odoStream) {
            this.odoStream.getTracks().forEach(track => {
                try {
                    track.stop();
                } catch (e) {
                    console.warn('Error stopping odometer track:', e);
                }
            });
            this.odoStream = null;
        }
        this.isOdoCameraOpen = false;
    }

    stopStreams() {
        this.closeSelfieCamera();
        this.closeOdoCamera();
        try {
            this.template.querySelectorAll('video').forEach(video => {
                video.srcObject = null;
            });
        } catch (e) {
            console.warn('Error clearing all video elements:', e);
        }
    }

    captureSelfie() {
        const video = this.template.querySelector('.up-video-selfie');
        const canvas = this.template.querySelector('.up-canvas');
        if (!video || !canvas) return;
        this.selfiePreview = this.processCapture(video, canvas, 'SELFIE');
        this.closeSelfieCamera();
    }

    captureOdometer() {
        const video = this.template.querySelector('.up-video-odometer');
        const canvas = this.template.querySelector('.up-canvas');
        if (!video || !canvas) return;
        this.odometerPreview = this.processCapture(video, canvas, 'ODOMETER');
        this.closeOdoCamera();
        
        if (this.isPrivateVehicle) {
            // Call AI extraction instead of mock
            this.handleAIExtraction();
        }
    }

    /*processCapture(video, canvas, type) {
        canvas.width  = video.videoWidth  || 640;
        canvas.height = video.videoHeight || 480;
        const ctx = canvas.getContext('2d');

        ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

        // Timestamp
        const now = new Date();
        const stamp = `${type} - ${now.toLocaleString('en-IN')}`;

        const bannerH = 32;
        ctx.fillStyle = 'rgba(0, 0, 0, 0.6)';
        ctx.fillRect(0, canvas.height - bannerH, canvas.width, bannerH);

        ctx.fillStyle = '#DAA520';
        ctx.font = 'bold 14px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(stamp, canvas.width / 2, canvas.height - bannerH / 2);

        return canvas.toDataURL('image/jpeg');
    }*/
    processCapture(video, canvas, type) {
        console.log('inside processCapture');
        const maxDimension = 1280;

        let width = video.videoWidth || 640;
        let height = video.videoHeight || 480;

        // Resize while maintaining aspect ratio
        if (width > maxDimension || height > maxDimension) {
            const scale = Math.min(
                maxDimension / width,
                maxDimension / height
            );

            width = Math.round(width * scale);
            height = Math.round(height * scale);
        }

        canvas.width = width;
        canvas.height = height;

        const ctx = canvas.getContext('2d');

        ctx.drawImage(video, 0, 0, width, height);

        // Timestamp
        const now = new Date();
        const stamp = `${type} - ${now.toLocaleString('en-IN')}`;

        const bannerH = 32;

        ctx.fillStyle = 'rgba(0, 0, 0, 0.6)';
        ctx.fillRect(0, height - bannerH, width, bannerH);

        ctx.fillStyle = '#DAA520';
        ctx.font = 'bold 14px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';

        ctx.fillText(
            stamp,
            width / 2,
            height - bannerH / 2
        );

        // Compress JPEG
        // return canvas.toDataURL('image/jpeg', 0.7);
        let quality = 0.7;
        let dataUrl = canvas.toDataURL('image/jpeg', quality);

        // Rough estimate: base64 length * 0.75 = byte size
        while (dataUrl.length * 0.75 > 1_000_000 && quality > 0.3) {
            quality -= 0.1;
            dataUrl = canvas.toDataURL('image/jpeg', quality);
        }

        return dataUrl;
    }

    /**
     * NEW METHOD: AI-Powered Odometer Extraction
     * Calls Anthropic Claude API to extract odometer reading from captured image
     */
    handleAIExtraction() {
        if (!this.odometerPreview) {
            this.showToast('Error', 'No odometer image captured', 'error');
            return;
        }

        this.isExtractingOdometer = true;
        this.extractedOdometer = '';
        
        // Show progress toast
        this.showToast('Processing', 'Extracting odometer reading using AI...', 'info');

        extractOdometerReading({ base64Image: this.odometerPreview })
            .then((reading) => {
                this.isExtractingOdometer = false;
                
                if (reading && reading > 0) {
                    this.extractedOdometer = reading;
                    this.showToast(
                        'Success', 
                        `Odometer reading extracted: ${reading} km`, 
                        'success'
                    );
                } else {
                    throw new Error('Invalid reading extracted');
                }
            })
            .catch((error) => {
                console.error('AI Extraction Error:', error);
                this.isExtractingOdometer = false;
                
                const errorMsg = error.body && error.body.message 
                    ? error.body.message 
                    : 'Failed to extract odometer reading. Please retake the photo or enter manually.';
                
                this.showToast('Extraction Failed', errorMsg, 'warning');
                
                // Clear the extracted value on error
                this.extractedOdometer = '';
            });
    }

    /**
     * REMOVED: handleMockExtraction() - replaced by handleAIExtraction()
     */

    retakeSelfie() { this.selfiePreview = ''; }
    retakeOdometer() { 
        this.odometerPreview = ''; 
        this.extractedOdometer = '';
        this.isExtractingOdometer = false;
    }

    handleDiscardActiveMode() {
        this.punchType = this.lastPunchType || '';
        this.transportType = this.lastTransportType || '';
        this.vehicleType = this.lastVehicleType || '';
        this.odometerReading = '';
        this.extractedOdometer = '';
        this.odometerPreview = '';
        this.isExtractingOdometer = false;
        this.isEditingMode = false;
    }

    handleEnableEditingMode() {
        this.isEditingMode = true;
        this.punchType = this.lastPunchType || '';
        this.transportType = this.lastTransportType || '';
        this.vehicleType = this.lastVehicleType || '';
        this.odometerReading = '';
        this.extractedOdometer = '';
        this.odometerPreview = '';
    }

    handleEndActiveMode() {
        if (this.hasActiveCheckIn) {
            this.showToast('Action Blocked', 'You have an active visit check-in. Please check out of your active visit before ending active mode.', 'error');
            return;
        }

        if (this.lastPunchType === 'Market Visit' && this.lastTransportType === 'Private Vehicle') {
            if (!this.odometerPreview) {
                this.showToast('Action Required', 'Please capture an odometer reading.', 'error');
                return;
            }
            if (this.isExtractingOdometer) {
                this.showToast('Action Required', 'Please wait for odometer extraction to complete.', 'error');
                return;
            }
            if (!this.odometerReading) {
                this.showToast('Validation Error', 'Please enter your manual odometer reading.', 'error');
                return;
            }
        }

        // WFH / WFO require Day Activity Log before ending
        if (this.isEndingWfhOrWfo) {
            this.dayActivityPhoneCalls = '';
            this.dayActivityEmails = '';
            this.dayActivityOffersSent = '';
            this.dayActivityMeetings = '';
            this.dayActivityOpenNotes = '';
            this.showDayActivityModal = true;
            // Same as the Check-In modal: keeps the form in view on mobile
            window.scrollTo({ top: 0, behavior: 'smooth' });
            return;
        }

        this.submitEndActiveMode();
    }

    handleDayActivityPhoneCallsChange(event) {
        this.dayActivityPhoneCalls = event.target.value;
    }
    handleDayActivityEmailsChange(event) {
        this.dayActivityEmails = event.target.value;
    }
    handleDayActivityOffersChange(event) {
        this.dayActivityOffersSent = event.target.value;
    }
    handleDayActivityMeetingsChange(event) {
        this.dayActivityMeetings = event.target.value;
    }
    handleDayActivityNotesChange(event) {
        this.dayActivityOpenNotes = event.target.value;
    }

    closeDayActivityModal() {
        this.showDayActivityModal = false;
        this.isSubmittingDayActivity = false;
    }

    submitDayActivityLog() {
        if (this.dayActivityPhoneCalls === '' || this.dayActivityPhoneCalls === null || this.dayActivityPhoneCalls === undefined) {
            this.showToast('Validation Error', 'No of Phone Calls is required.', 'error');
            return;
        }
        if (this.dayActivityEmails === '' || this.dayActivityEmails === null || this.dayActivityEmails === undefined) {
            this.showToast('Validation Error', 'No of Emails is required.', 'error');
            return;
        }
        if (this.dayActivityOffersSent === '' || this.dayActivityOffersSent === null || this.dayActivityOffersSent === undefined) {
            this.showToast('Validation Error', 'No of Offer sent to Customer is required.', 'error');
            return;
        }
        if (this.dayActivityMeetings === '' || this.dayActivityMeetings === null || this.dayActivityMeetings === undefined) {
            this.showToast('Validation Error', 'No of Meetings is required.', 'error');
            return;
        }

        this.isSubmittingDayActivity = true;
        this.submitEndActiveMode({
            noOfPhoneCalls: Number(this.dayActivityPhoneCalls),
            noOfEmails: Number(this.dayActivityEmails),
            noOfOffersSent: Number(this.dayActivityOffersSent),
            noOfMeetings: Number(this.dayActivityMeetings),
            openNotes: this.dayActivityOpenNotes || null
        });
    }

    submitEndActiveMode(dayActivity = {}) {
        this.isUpdatingMode = true;
        this.detectDevice();
        updatePunchTypeAndOdometer({
            punchType: '',
            transportType: '',
            vehicleType: '',
            odometerReading: this.odometerReading ? Number(this.odometerReading) : null,
            extractedOdometer: this.extractedOdometer ? Number(this.extractedOdometer) : null,
            odometerImageBase64: this.odometerPreview || null,
            fileName: 'odometer_end.jpg',
            noOfPhoneCalls: dayActivity.noOfPhoneCalls != null ? dayActivity.noOfPhoneCalls : null,
            noOfEmails: dayActivity.noOfEmails != null ? dayActivity.noOfEmails : null,
            noOfOffersSent: dayActivity.noOfOffersSent != null ? dayActivity.noOfOffersSent : null,
            noOfMeetings: dayActivity.noOfMeetings != null ? dayActivity.noOfMeetings : null,
            openNotes: dayActivity.openNotes || null,
            deviceOS: this.deviceOS,
            deviceModel: this.deviceModel
        })
        .then((result) => {
            const endedMode = this.lastPunchType;
            this.isUpdatingMode = false;
            this.isSubmittingDayActivity = false;
            this.showDayActivityModal = false;
            this.showToast('Success', `${endedMode} successfully ended.`, 'success');
            
            this.isWFHApprovedForToday = result.isWFHApprovedForToday;
            this.isWFOApproved   = result.isWFOApproved;
            this.lastPunchType   = result.lastPunchType;
            this.lastTransportType = result.lastTransportType;
            this.lastVehicleType = result.lastVehicleType;
            this.lastOdometerUrl = result.lastOdometerUrl;
            this.hasActiveCheckIn = result.hasActiveCheckIn || false;

            this.punchType = '';
            this.transportType = '';
            this.vehicleType = '';
            this.odometerReading = '';
            this.extractedOdometer = '';
            this.odometerPreview = '';
            this.dayActivityPhoneCalls = '';
            this.dayActivityEmails = '';
            this.dayActivityOffersSent = '';
            this.dayActivityMeetings = '';
            this.dayActivityOpenNotes = '';

            this.isEditingMode = true;
        })
        .catch((err) => {
            this.isUpdatingMode = false;
            this.isSubmittingDayActivity = false;
            console.error('Error ending active mode:', err);
            const msg = (err.body && err.body.message) ? err.body.message : 'Action failed. Please try again.';
            this.showToast('Error', msg, 'error');
        });
    }

    handleClientActivityChange() {
        this.loadState();
    }

    handleUpdateActiveMode() {
        if (!this.isEditingMode) {
            this.isEditingMode = true;
            return;
        }

        if (!this.punchType) {
            this.showToast('Validation Error', 'Please select an active mode.', 'error');
            return;
        }

        if (this.punchType === 'WFO' && !this.isWFOApproved) {
            this.showToast('Validation Error', 'WFO punch is only allowed if a request for today has been approved by your manager.', 'error');
            return;
        }
        if (this.punchType === 'WFH' && !this.isWFHApprovedForToday) {
            this.showToast('Validation Error', 'WFH punch is only allowed if a request for today has been approved by your manager.', 'error');
            return;
        }

        if (this.punchType === 'Market Visit') {
            if (!this.transportType) {
                this.showToast('Validation Error', 'Please select a transportation type.', 'error');
                return;
            }
            if (this.transportType === 'Private Vehicle') {
                if (!this.vehicleType) {
                    this.showToast('Validation Error', 'Please select a vehicle type.', 'error');
                    return;
                }
                if (!this.odometerPreview) {
                    this.showToast('Action Required', 'Please capture an odometer reading.', 'error');
                    return;
                }
                if (!this.extractedOdometer) {
                    this.showToast(
                        'Action Required',
                        'Please capture a valid odometer image and wait for the reading to be extracted.',
                        'error'
                    );
                    return;
                }
                if (this.isExtractingOdometer) {
                    this.showToast('Action Required', 'Please wait for odometer extraction to complete.', 'error');
                    return;
                }
                if (!this.odometerReading) {
                    this.showToast('Validation Error', 'Please enter your manual odometer reading.', 'error');
                    return;
                }
            }
        }

        this.isUpdatingMode = true;

        if (this.lastPunchType === 'Market Visit' &&
            this.lastTransportType === 'Private Vehicle') {

            if (!this.odometerPreview) {
                this.showToast(
                    'Action Required',
                    'Please capture an odometer image before ending the Market Visit.',
                    'error'
                );
                return;
            }

            if (!this.extractedOdometer) {
                this.showToast(
                    'Action Required',
                    'Please capture a valid odometer image and wait for the reading to be extracted.',
                    'error'
                );
                return;
            }
        }

        this.detectDevice();

        updatePunchTypeAndOdometer({
            punchType: this.punchType,
            transportType: this.transportType,
            vehicleType: this.vehicleType,
            odometerReading: this.odometerReading ? Number(this.odometerReading) : null,
            extractedOdometer: this.extractedOdometer ? Number(this.extractedOdometer) : null,
            odometerImageBase64: this.odometerPreview || null,
            fileName: 'odometer_update.jpg',
            deviceOS: this.deviceOS,
            deviceModel: this.deviceModel
        })
        .then((result) => {
            this.isUpdatingMode = false;
            this.showToast('Success', `Active Mode successfully updated to ${this.punchType}.`, 'success');
            
            // Refresh component state with returned DTO
            this.isWFHApprovedForToday = result.isWFHApprovedForToday;
            this.isWFOApproved   = result.isWFOApproved;
            this.lastPunchType   = result.lastPunchType;
            this.lastTransportType = result.lastTransportType;
            this.lastVehicleType = result.lastVehicleType;
            this.lastOdometerUrl = result.lastOdometerUrl;
            this.hasActiveCheckIn = result.hasActiveCheckIn || false;

            // Sync selections
            this.punchType = result.lastPunchType || '';
            this.transportType = result.lastTransportType || '';
            this.vehicleType = result.lastVehicleType || '';

            // Clear start odometer capture so Active Mode shows a fresh
            // end-odometer form (checkout-ready), not leftover start data.
            this.odometerReading = '';
            this.extractedOdometer = '';
            this.odometerPreview = '';
            this.isExtractingOdometer = false;
            this.closeOdoCamera();

            // Collapse active mode editor on success
            this.isEditingMode = false;
        })
        .catch((err) => {
            this.isUpdatingMode = false;
            console.error('Error updating active mode:', err);
            const msg = (err.body && err.body.message) ? err.body.message : 'Update failed. Please try again.';
            this.showToast('Error', msg, 'error');
        });
    }

    // ── Toast ──────────────────────────────────────────────────────────────
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
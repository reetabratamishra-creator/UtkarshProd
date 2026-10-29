import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAvailableSalespeople from '@salesforce/apex/FieldForceDashboardController.getAvailableSalespeople';
import canCurrentUserApproveWfh from '@salesforce/apex/FieldForceDashboardController.canCurrentUserApproveWfh';
import getDailyDashboardData from '@salesforce/apex/FieldForceDashboardController.getDailyDashboardData';
import getMultipleUsersDailySummary from '@salesforce/apex/FieldForceDashboardController.getMultipleUsersDailySummary';
import getTeamWFHRequests from '@salesforce/apex/FieldForceDashboardController.getTeamWFHRequests';
import getWFHRequestsForUser from '@salesforce/apex/PunchController.getWFHRequestsForUser';
import updateWFHStatus from '@salesforce/apex/EmployeeTracker.updateWFHStatus';
import getAnalyticsSummary from '@salesforce/apex/FieldForceDashboardController.getAnalyticsSummary';
import MAP_CONTAINER from '@salesforce/resourceUrl/mapContainer';

const GOOGLE_API_KEY = 'AIzaSyAF5PF39kVNNf9SVpEeNiInBH__wC9ZAhA';

export default class FieldForceDashboard extends LightningElement {
    @track selectedEmployeeId;
    @track selectedDate = '';
    @track employeeOptions = [];
    @track summary = {};
    @track timelineData = [];
    @track mapMarkers = [];
    @track trackLocations = [];
    @track visitNodes = [];
    @track punchMarkers = [];
    @track isLoading = true;
    @track activeTab = 'overview';
    @track overviewSearchTerm = '';
    @track overviewStatusFilter = 'ALL';

    // Analytics properties
    @track analyticsMode = 'DAILY'; // DAILY, WEEKLY, MONTHLY, CUSTOM
    @track analyticsStartDate = '';
    @track analyticsEndDate = '';
    @track analyticsData = [];
    @track isAnalyticsLoading = false;
    @track showCustomDateRange = false;

    // List and details toggle view tracking
    @track isSingleView = false;
    @track availableUserIds = [];
    @track listSummaryData = [];
    rawSummaries;
    @track searchTerm = '';
    @track statusFilter = 'ALL';

    // Image Zoom Modal Properties
    @track showImageModal = false;
    @track modalImageUrl = '';

    // WFH/WFO Day Activity Log Modal Properties
    @track showActivityModal = false;
    @track activityDetails = {};
    scrollActivityModalIntoView = false;
    activityModalTrigger = null;
    @track showActivityOverlay = false;
    @track activityOverlayStyle = '';

    @track selfWfhRequests = [];
    @track teamWfhRequests = [];
    @track canApproveWfhRequests = false;

    wiredDashboardResult;
    wiredWfhRequestsResult;
    wiredSalespeopleResult;
    wiredSummariesResult;
    isMapInitialized = false;
    _tabOverflowStyled = false;

    get mapUrl() {
        return MAP_CONTAINER;
    }

    connectedCallback() {
        // Initialize with today's date in local YYYY-MM-DD
        const today = new Date();
        const yyyy = today.getFullYear();
        const mm = String(today.getMonth() + 1).padStart(2, '0');
        const dd = String(today.getDate()).padStart(2, '0');
        this.selectedDate = `${yyyy}-${mm}-${dd}`;

        // Listen for MAP_READY from mapContainer iframe
        window.addEventListener('message', this.handleMapMessage);

        canCurrentUserApproveWfh()
            .then(canApprove => {
                this.canApproveWfhRequests = canApprove || false;
                this.applyWfhApprovalFlags();
            })
            .catch(error => {
                console.error('Error fetching WFH approval access:', error);
                this.canApproveWfhRequests = false;
            });
    }

    disconnectedCallback() {
        window.removeEventListener('message', this.handleMapMessage);
    }

    applyTabOverflowStyles() {
        if (this._tabOverflowStyled) {
            return;
        }
        const tabset = this.template.querySelector('.dashboard-tabs');
        if (!tabset || !tabset.shadowRoot) {
            return;
        }
        try {
            if (tabset.shadowRoot.querySelector('#ffd-mobile-tabs')) {
                this._tabOverflowStyled = true;
                return;
            }
            const style = document.createElement('style');
            style.id = 'ffd-mobile-tabs';
            style.textContent = `
                .slds-tabs_scoped__nav,
                .slds-tabs_default__nav {
                    overflow-x: auto !important;
                    overflow-y: hidden;
                    flex-wrap: nowrap !important;
                    -webkit-overflow-scrolling: touch;
                    scrollbar-width: none;
                }
                .slds-tabs_scoped__nav::-webkit-scrollbar,
                .slds-tabs_default__nav::-webkit-scrollbar {
                    display: none;
                }
                .slds-tabs_scoped__item,
                .slds-tabs_default__item {
                    flex-shrink: 0 !important;
                }
            `;
            tabset.shadowRoot.appendChild(style);
            this._tabOverflowStyled = true;
        } catch (e) {
            this._tabOverflowStyled = true;
        }
    }

    handleMapMessage = (event) => {
        if (event.data && event.data.type === 'MAP_READY') {
            this.plotMarkersAndPath();
        }
    };

    // 1. Fetch available salespeople list
    @wire(getAvailableSalespeople)
    wiredSalespeople(result) {
        this.wiredSalespeopleResult = result;
        const { error, data } = result;
        if (data) {
            this.employeeOptions = data.map(item => ({
                label: item.name + (item.phone ? ' (' + item.phone + ')' : ''),
                value: item.id
            }));
            
            this.availableUserIds = this.employeeOptions.map(opt => opt.value);
            
            // Default select the first available salesperson option
            if (this.employeeOptions.length > 0) {
                if (!this.selectedEmployeeId) {
                    this.selectedEmployeeId = this.employeeOptions[0].value;
                }
                // If only 1 salesperson exists, force Single User View
                if (this.employeeOptions.length === 1) {
                    this.isSingleView = true;
                }
            } else {
                this.isLoading = false;
            }
        } else if (error) {
            this.showToast('Error', 'Failed to fetch salespeople: ' + error.body.message, 'error');
            this.isLoading = false;
        }
    }

    // 2. Fetch daily summary details for all reporting team members
    @wire(getMultipleUsersDailySummary, { userIds: '$availableUserIds', statusDate: '$selectedDate' })
    wiredMultipleSummaries(result) {
        this.wiredSummariesResult = result;
        const { error, data } = result;
        if (data) {
            this.rawSummaries = data;
            this.processListSummaryData();
            if (!this.isSingleView) {
                this.isLoading = false;
            }
        } else if (error) {
            this.showToast('Error', 'Failed to fetch team summaries: ' + error.body.message, 'error');
            this.isLoading = false;
        }
    }

    get hasSelfWfhRequests() {
        return this.selfWfhRequests && this.selfWfhRequests.length > 0;
    }

    get hasTeamRequests() {
        return this.teamWfhRequests && this.teamWfhRequests.length > 0;
    }

    handleOverviewTabActive() {
        this.activeTab = 'overview';
        this.isSingleView = false;
    }

    handleTrackingTabActive() {
        this.activeTab = 'tracking';
        this.isSingleView = false;
    }

    handleWfhTabActive() {
        this.activeTab = 'requests';
        this.isSingleView = false;
        this.loadTeamWfhRequests();
    }

    loadTeamWfhRequests() {
        if (!this.availableUserIds || this.availableUserIds.length === 0) {
            return;
        }
        getTeamWFHRequests({ userIds: this.availableUserIds })
            .then(result => {
                this.teamWfhRequests = result.map(req => this.formatDashboardWfhRequest(req));
            })
            .catch(error => {
                console.error('Error loading team WFH requests:', error);
            });
    }

    get activityModalTitle() {
        return `Day Activity Log - ${this.activityDetails.userName || ''}`;
    }

    buildActivityDetails(reqId) {
        const req = (this.teamWfhRequests || []).find(r => r.requestId === reqId);
        if (!req) {
            return null;
        }
        const display = (val) => (val === null || val === undefined ? '—' : val);
        const openNotes = (req.openNotes || '').trim();
        return {
            userName: req.userName,
            type: req.type,
            typeBadgeClass: req.typeBadgeClass,
            formattedDate: req.formattedDate,
            emailsDisplay: display(req.noOfEmails),
            meetingsDisplay: display(req.noOfMeetings),
            offersDisplay: display(req.noOfOffersSent),
            callsDisplay: display(req.noOfPhoneCalls),
            openNotes,
            hasOpenNotes: openNotes.length > 0
        };
    }

    handleViewActivityDetails(event) {
        const details = this.buildActivityDetails(event.currentTarget.dataset.id);
        if (!details) {
            return;
        }
        this.activityDetails = details;
        this.activityModalTrigger = event.currentTarget;
        this.showActivityModal = true;
        this.scrollActivityModalIntoView = true;
    }

    // Mobile cards: open the Day Activity Log over the tapped card instead of a page-level modal
    handleViewActivityDetailsMobile(event) {
        const details = this.buildActivityDetails(event.currentTarget.dataset.id);
        if (!details) {
            return;
        }
        const card = event.currentTarget.closest('.mobile-data-card');
        const top = card ? card.offsetTop : 0;
        this.activityDetails = details;
        this.activityOverlayStyle = `top: ${top}px;`;
        this.showActivityOverlay = true;
    }

    closeActivityOverlay() {
        this.showActivityOverlay = false;
        this.activityDetails = {};
    }

    closeActivityDetails() {
        this.showActivityModal = false;
        this.activityDetails = {};
        // Return the user to the row they opened the modal from (mobile scrolls up to show the modal)
        if (this.activityModalTrigger) {
            this.activityModalTrigger.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
            this.activityModalTrigger = null;
        }
    }

    // Wire to fetch WFH/WFO request applications for the selected salesperson
    @wire(getWFHRequestsForUser, { userId: '$selectedEmployeeId' })
    wiredWfhRequests(result) {
        this.wiredWfhRequestsResult = result;
        const { error, data } = result;
        if (data) {
            this.selfWfhRequests = data.map(req => this.formatDashboardWfhRequest(req));
        } else {
            this.selfWfhRequests = [];
        }
        if (error) {
            console.error('Error loading WFH requests in dashboard:', error);
        }
    }

    formatDashboardWfhRequest(req) {
        const remarks = (req.remarks || '').trim();
        const requestNote = (req.requestNote || '').trim();
        const approverName = (req.approverName || '').trim();
        const type = (req.type || 'WFH').toLowerCase();
        const status = (req.status || 'Pending').toLowerCase();
        return {
            ...req,
            remarks,
            requestNote,
            approverName,
            hasRemarks: remarks.length > 0,
            hasRequestNote: requestNote.length > 0,
            hasApprover: approverName.length > 0,
            formattedDate: this.formatDateString(req.requestDate),
            typeBorderClass: `wfh-border-${type}`,
            typeBadgeClass: `wfh-badge type-${type}`,
            statusBadgeClass: `wfh-status-badge status-${status}`,
            isPending: req.status === 'Pending' && this.canApproveWfhRequests
        };
    }

    applyWfhApprovalFlags() {
        if (this.teamWfhRequests && this.teamWfhRequests.length > 0) {
            this.teamWfhRequests = this.teamWfhRequests.map(req => ({
                ...req,
                isPending: req.status === 'Pending' && this.canApproveWfhRequests
            }));
        }
        if (this.selfWfhRequests && this.selfWfhRequests.length > 0) {
            this.selfWfhRequests = this.selfWfhRequests.map(req => ({
                ...req,
                isPending: req.status === 'Pending' && this.canApproveWfhRequests
            }));
        }
    }

    formatDateString(dateStr) {
        if (!dateStr) return '';
        try {
            const parts = dateStr.split('-');
            if (parts.length === 3) {
                const year = parts[0];
                const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                const month = monthNames[parseInt(parts[1], 10) - 1];
                const day = parseInt(parts[2], 10);
                return `${day} ${month} ${year}`;
            }
            return dateStr;
        } catch (e) {
            return dateStr;
        }
    }

    // 3. Fetch detailed daily dashboard data (Map/Timeline) for the selected representative
    @wire(getDailyDashboardData, { employeeId: '$selectedEmployeeId', statusDate: '$selectedDate' })
    wiredDashboard(result) {
        this.wiredDashboardResult = result;
        const { error, data } = result;
        
        if (data) {
            this.summary = data.attendanceSummary || {};
            this.mapMarkers = data.mapMarkers || [];
            this.timelineData = this.processTimeline(data.timeline || []);
            this.trackLocations = data.trackLocations || [];
            this.visitNodes = data.visitNodes || [];
            this.punchMarkers = data.punchMarkers || [];
        } else {
            this.summary = {};
            this.mapMarkers = [];
            this.timelineData = [];
            this.trackLocations = [];
            this.visitNodes = [];
            this.punchMarkers = [];
        }

        if (error) {
            this.showToast('Error', 'Failed to retrieve dashboard details: ' + error.body.message, 'error');
        }

        // Check if resolved (either data or error is returned/defined)
        if (data !== undefined || error !== undefined) {
            if (this.isSingleView) {
                this.isLoading = false;
            }
        } else {
            if (this.isSingleView) {
                this.isLoading = true;
            }
        }
    }

    processListSummaryData() {
        if (!this.rawSummaries) {
            this.listSummaryData = [];
            return;
        }
        this.listSummaryData = this.rawSummaries.map(usr => {
            let sidebarClass = 'sidebar-user-item hover-lift';
            if (usr.userId === this.selectedEmployeeId) {
                sidebarClass += ' active';
            }
            const status = usr.attendanceStatus ? usr.attendanceStatus.toLowerCase() : '';
            const isActive = status && status !== 'absent' && status !== 'offline' && status !== 'short hours';
            const isShortHours = status === 'short hours';
            const isGpsOffline = !usr.gpsStatus || usr.gpsStatus.toLowerCase() !== 'active';
            
            let badgeClass = 'status-badge ';
            if (isShortHours) {
                badgeClass += 'badge-short-hours';
            } else if (isActive) {
                badgeClass += 'badge-online';
            } else {
                badgeClass += 'badge-offline';
            }

            let accentClass = 'card-accent-bar ';
            if (isShortHours) {
                accentClass += 'accent-short-hours';
            } else if (isActive) {
                accentClass += 'accent-online';
            } else {
                accentClass += 'accent-offline';
            }

            const nameParts = (usr.userName || '').trim().split(/\s+/);
            let initials = '';
            if (nameParts.length >= 2) {
                initials = (nameParts[0][0] + nameParts[nameParts.length - 1][0]).toUpperCase();
            } else if (nameParts.length === 1 && nameParts[0]) {
                initials = nameParts[0].substring(0, 2).toUpperCase();
            }

            let attendanceMeta = '';
            const sinceTime = usr.activeSinceTime || usr.punchInTime;
            if (isActive && sinceTime && sinceTime !== 'N/A') {
                attendanceMeta = 'In since ' + sinceTime;
            } else if (usr.punchOutTime && usr.punchOutTime !== 'N/A') {
                attendanceMeta = 'Out at ' + usr.punchOutTime;
            } else if (usr.lastActivityTime) {
                attendanceMeta = 'Last at ' + usr.lastActivityTime;
            }

            return {
                ...usr,
                totalHours: this.formatHoursLabel(usr.totalHours),
                sidebarClass: sidebarClass,
                dotClass: `sidebar-status-dot ${isShortHours ? 'short-hours' : (isActive ? 'online' : 'offline')}`,
                accentClass: accentClass,
                badgeClass: badgeClass,
                isPunchedIn: isActive,
                isPunchedInInactive: isActive && isGpsOffline,
                initials: initials || '?',
                attendanceMeta: attendanceMeta,
                lastLocationDisplay: usr.lastAddress || 'No location available',
                overviewRowClass: 'overview-emp-row' + (isActive ? ' is-in' : ' is-out')
            };
        });
    }

    // Process file extension type for display
    processTimeline(timeline) {
        return timeline.map(item => {
            let processedFiles = item.files ? item.files.map(file => {
                const ext = file.extension ? file.extension.toLowerCase() : '';
                const isImg = ['jpg', 'jpeg', 'png', 'gif', 'webp'].includes(ext) || 
                              (file.title && file.title.toLowerCase().includes('selfie')) ||
                              (file.title && file.title.toLowerCase().includes('capture'));
                return {
                    ...file,
                    isImage: isImg
                };
            }) : null;

            // Define node point classes dynamically
            let markerDotClass = 'marker-dot-track';
            if (item.type === 'PUNCH_IN') markerDotClass = 'marker-dot-in';
            else if (item.type === 'PUNCH_OUT') markerDotClass = 'marker-dot-out';
            else if (item.type === 'VISIT') {
                markerDotClass = item.isCheckout ? 'marker-dot-visit' : 'marker-dot-checkout';
            }

            let dynamicBadgeLabel = '';
            let dynamicBadgeClass = '';
            let timeHeaderLabel = 'Time';

            if (item.type === 'PUNCH_IN') {
                if (item.punchTypeOfRecord === 'Day In / Out') {
                    dynamicBadgeLabel = 'Day In';
                    dynamicBadgeClass = 'pt-badge pt-badge-checkin';
                } else {
                    dynamicBadgeLabel = (item.punchTypeOfRecord || '') + ' Start';
                    dynamicBadgeClass = 'pt-badge pt-badge-checkin';
                }
                timeHeaderLabel = 'Punch In';
            } else if (item.type === 'PUNCH_OUT') {
                if (item.punchTypeOfRecord === 'Day In / Out') {
                    dynamicBadgeLabel = 'Day Out';
                    dynamicBadgeClass = 'pt-badge pt-badge-red';
                } else {
                    dynamicBadgeLabel = (item.punchTypeOfRecord || '') + ' End';
                    dynamicBadgeClass = 'pt-badge pt-badge-checkout';
                }
                timeHeaderLabel = 'Punch Out';
            } else if (item.type === 'VISIT') {
                if (item.isCheckout) {
                    dynamicBadgeLabel = 'Visit Completed';
                    dynamicBadgeClass = 'pt-badge pt-badge-checkout';
                } else {
                    dynamicBadgeLabel = 'IN PROGRESS';
                    dynamicBadgeClass = 'pt-badge pt-badge-checkin';
                }
                timeHeaderLabel = 'Check-In';
            }

            return {
                ...item,
                files: processedFiles,
                markerDotClass: markerDotClass,
                isVisitType: item.type === 'VISIT',
                isPunchType: item.type === 'PUNCH_IN' || item.type === 'PUNCH_OUT',
                hasTransitMeta: item.type === 'VISIT' && !!(item.odometer || item.transportType),
                isExpanded: false,
                toggleIconName: 'utility:chevronright',
                dynamicBadgeLabel: dynamicBadgeLabel,
                dynamicBadgeClass: dynamicBadgeClass,
                timeHeaderLabel: timeHeaderLabel
            };
        });
    }

    handleToggleExpand(event) {
        event.stopPropagation();
        const itemId = event.currentTarget.dataset.id;
        this.timelineData = this.timelineData.map(item => {
            if (item.id === itemId) {
                const newExpanded = !item.isExpanded;
                return { 
                    ...item, 
                    isExpanded: newExpanded,
                    toggleIconName: newExpanded ? 'utility:chevrondown' : 'utility:chevronright'
                };
            }
            return item;
        });
    }

    renderedCallback() {
        this.applyTabOverflowStyles();

        // In the Salesforce mobile app, position:fixed is anchored to the page container rather than
        // the viewport, so a modal opened far down the list renders off-screen. Bring it into view.
        if (this.scrollActivityModalIntoView) {
            const modal = this.template.querySelector('.activity-modal-content');
            if (modal) {
                this.scrollActivityModalIntoView = false;
                modal.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
            }
        }

        if (!this.isSingleView) {
            this.isMapInitialized = false;
            return;
        }

        const iframe = this.template.querySelector('.map-iframe');
        if (iframe && !this.isMapInitialized) {
            this.isMapInitialized = true;
            iframe.onload = () => {
                this.initializeMap(iframe);
            };
        } else if (this.isMapInitialized) {
            this.plotMarkersAndPath();
        }
    }

    initializeMap(iframe) {
        let lat = 28.5355; // Default center
        let lng = 77.3910;
        if (this.punchMarkers && this.punchMarkers.length > 0) {
            lat = this.punchMarkers[0].latitude;
            lng = this.punchMarkers[0].longitude;
        } else if (this.mapMarkers && this.mapMarkers.length > 0) {
            lat = this.mapMarkers[0].location.Latitude;
            lng = this.mapMarkers[0].location.Longitude;
        } else if (this.trackLocations && this.trackLocations.length > 0) {
            lat = Number(this.trackLocations[0].latitude);
            lng = Number(this.trackLocations[0].longitude);
        }

        iframe.contentWindow.postMessage({
            type: 'INIT_GOOGLE',
            apiKey: GOOGLE_API_KEY,
            center: { lat: lat, lng: lng }
        }, '*');
    }

    plotMarkersAndPath() {
        const iframe = this.template.querySelector('.map-iframe');
        if (iframe) {
            iframe.contentWindow.postMessage({ 
                type: 'PLOT_MARKERS', 
                markers: this.mapMarkers 
            }, '*');

            // Path from periodic track logs only — visits stay as numbered markers
            let path = [];
            if (this.trackLocations && this.trackLocations.length > 0) {
                let lastLat = null;
                let lastLng = null;
                for (const item of this.trackLocations) {
                    const lat = Number(item.latitude);
                    const lng = Number(item.longitude);
                    if (isNaN(lat) || isNaN(lng)) {
                        continue;
                    }
                    if (lastLat !== null && lastLng !== null) {
                        const dist = this.calculateDistanceMeters(lastLat, lastLng, lat, lng);
                        if (dist < 50.0) {
                            continue; // skip jitter/stationary points
                        }
                    }
                    path.push({
                        lat: lat,
                        lng: lng,
                        title: 'Tracking Point'
                    });
                    lastLat = lat;
                    lastLng = lng;
                }

                // If filter was too aggressive (e.g. user stayed stationary all day), keep start and end points
                if (path.length <= 1 && this.trackLocations.length > 0) {
                    path = [];
                    const first = this.trackLocations[0];
                    const last = this.trackLocations[this.trackLocations.length - 1];
                    path.push({ lat: Number(first.latitude), lng: Number(first.longitude), title: 'Start Point' });
                    if (this.trackLocations.length > 1) {
                        path.push({ lat: Number(last.latitude), lng: Number(last.longitude), title: 'End Point' });
                    }
                }
            }

            iframe.contentWindow.postMessage({ 
                type: 'DRAW_PATH', 
                path: path,
                visitNodes: this.visitNodes,
                punchMarkers: this.punchMarkers
            }, '*');
        }
    }

    // Getters for filtered users list and filter pill statuses
    get filteredListSummaryData() {
        if (!this.listSummaryData) {
            return [];
        }
        return this.listSummaryData.filter(usr => {
            const nameMatch = !this.searchTerm || 
                              (usr.userName && usr.userName.toLowerCase().includes(this.searchTerm.toLowerCase()));
            
            const status = usr.attendanceStatus ? usr.attendanceStatus.toLowerCase() : '';
            const isActive = status && status !== 'absent' && status !== 'offline';
            
            let statusMatch = true;
            if (this.statusFilter === 'ACTIVE') {
                statusMatch = isActive;
            } else if (this.statusFilter === 'OFFLINE') {
                statusMatch = !isActive;
            }
            
            return nameMatch && statusMatch;
        });
    }

    get totalCount() {
        return this.listSummaryData ? this.listSummaryData.length : 0;
    }

    get activeCount() {
        if (!this.listSummaryData) return 0;
        return this.listSummaryData.filter(usr => {
            const status = usr.attendanceStatus ? usr.attendanceStatus.toLowerCase() : '';
            return status && status !== 'absent' && status !== 'offline';
        }).length;
    }

    get offlineCount() {
        if (!this.listSummaryData) return 0;
        return this.listSummaryData.filter(usr => {
            const status = usr.attendanceStatus ? usr.attendanceStatus.toLowerCase() : '';
            return !status || status === 'absent' || status === 'offline';
        }).length;
    }

    get allFilterClass() {
        return `filter-pill ${this.statusFilter === 'ALL' ? 'active' : ''}`;
    }

    get activeFilterClass() {
        return `filter-pill ${this.statusFilter === 'ACTIVE' ? 'active' : ''}`;
    }

    get offlineFilterClass() {
        return `filter-pill ${this.statusFilter === 'OFFLINE' ? 'active' : ''}`;
    }

    // Overview realtime dashboard getters
    get punchedInCount() {
        if (!this.listSummaryData) return 0;
        return this.listSummaryData.filter(usr => usr.isPunchedIn).length;
    }

    get punchedOutCount() {
        return Math.max(0, this.totalCount - this.punchedInCount);
    }

    get punchedInInactiveCount() {
        if (!this.listSummaryData) return 0;
        return this.listSummaryData.filter(usr => usr.isPunchedInInactive).length;
    }

    get staffingStrengthLabel() {
        return `${this.punchedInCount} / ${this.totalCount}`;
    }

    get gaugeCssVars() {
        const total = this.totalCount > 0 ? this.totalCount : 1;
        const inPct = (this.punchedInCount / total) * 100;
        return `--in-pct: ${inPct};`;
    }

    get punchedInPercentLabel() {
        if (this.totalCount === 0) return '0%';
        return Math.round((this.punchedInCount / this.totalCount) * 100) + '%';
    }

    get overviewFilteredEmployees() {
        if (!this.listSummaryData) {
            return [];
        }
        return this.listSummaryData.filter(usr => {
            const term = (this.overviewSearchTerm || '').toLowerCase();
            const nameMatch = !term ||
                (usr.userName && usr.userName.toLowerCase().includes(term)) ||
                (usr.userPhone && usr.userPhone.toLowerCase().includes(term));

            let statusMatch = true;
            if (this.overviewStatusFilter === 'IN') {
                statusMatch = usr.isPunchedIn;
            } else if (this.overviewStatusFilter === 'OUT') {
                statusMatch = !usr.isPunchedIn;
            } else if (this.overviewStatusFilter === 'INACTIVE') {
                statusMatch = usr.isPunchedInInactive;
            }

            return nameMatch && statusMatch;
        });
    }

    get overviewEmployeeCountLabel() {
        return `Employees (${this.overviewFilteredEmployees.length})`;
    }

    get hasOverviewEmployees() {
        return this.overviewFilteredEmployees && this.overviewFilteredEmployees.length > 0;
    }

    get overviewAllFilterClass() {
        return `filter-pill ${this.overviewStatusFilter === 'ALL' ? 'active' : ''}`;
    }

    get overviewInFilterClass() {
        return `filter-pill ${this.overviewStatusFilter === 'IN' ? 'active' : ''}`;
    }

    get overviewOutFilterClass() {
        return `filter-pill ${this.overviewStatusFilter === 'OUT' ? 'active' : ''}`;
    }

    get overviewInactiveFilterClass() {
        return `filter-pill ${this.overviewStatusFilter === 'INACTIVE' ? 'active' : ''}`;
    }

    handleOverviewSearchChange(event) {
        this.overviewSearchTerm = event.target.value;
    }

    handleOverviewStatusFilterChange(event) {
        this.overviewStatusFilter = event.currentTarget.dataset.status;
    }

    handleSearchTermChange(event) {
        this.searchTerm = event.target.value;
    }

    handleStatusFilterChange(event) {
        this.statusFilter = event.currentTarget.dataset.status;
    }

    // Getters for conditional rendering and layouts
    get showSidebar() {
        return this.employeeOptions && this.employeeOptions.length > 1;
    }

    get detailsLayoutClass() {
        return this.showSidebar ? 'details-split-layout' : 'details-full-layout';
    }

    get attendanceStatusLabel() {
        return this.summary && this.summary.attendanceStatus ? this.summary.attendanceStatus : 'Absent';
    }

    get attendanceBadgeClass() {
        const status = this.attendanceStatusLabel.toLowerCase();
        if (status === 'in' || status === 'present') return 'badge-status badge-in';
        if (status === 'out' || status === 'absent' || status === 'offline') return 'badge-status badge-out';
        if (status === 'wfh') return 'badge-status badge-wfh';
        if (status === 'wfo') return 'badge-status badge-wfo';
        if (status === 'market visit') return 'badge-status badge-market';
        return 'badge-status badge-track';
    }

    get workingHoursLabel() {
        // Use the team summary (getMultipleUsersDailySummary) hours for the selected employee so the
        // detail view matches the list/cards; fall back to the daily dashboard value if not available
        const listEntry = (this.listSummaryData || []).find(usr => usr.userId === this.selectedEmployeeId);
        if (listEntry && listEntry.totalHours) {
            return listEntry.totalHours;
        }
        return this.summary && this.summary.totalHours ? this.formatHoursLabel(this.summary.totalHours) : 'N/A';
    }

    // Converts decimal hours (e.g. 7.5) to "07h 30m"
    formatHoursMinutes(decimalHours) {
        const totalMinutes = Math.round((Number(decimalHours) || 0) * 60);
        const hours = Math.floor(totalMinutes / 60);
        const minutes = totalMinutes % 60;
        return `${String(hours).padStart(2, '0')}h ${String(minutes).padStart(2, '0')}m`;
    }

    // Converts Apex hour labels (e.g. "7.50 hrs (Active)") to "07h 30m (Active)"; other text (e.g. "N/A") is kept as is
    formatHoursLabel(label) {
        if (!label) {
            return label;
        }
        return String(label).replace(/(\d+(?:\.\d+)?)\s*hrs/, (match, hrs) => this.formatHoursMinutes(hrs));
    }

    get totalDistanceLabel() {
        return this.summary && this.summary.totalDistanceKm != null ? `${this.summary.totalDistanceKm} km` : '0.00 km';
    }

    get odometerDistanceLabel() {
        return this.summary && this.summary.odometerDistanceKm != null
            ? `${this.summary.odometerDistanceKm} km`
            : '0.00 km';
    }

    get distanceDeviationLabel() {
        return this.summary && this.summary.distanceDeviationKm != null
            ? `${this.summary.distanceDeviationKm} km`
            : '0.00 km';
    }

    get distanceDeviationPercentLabel() {
        return this.summary && this.summary.distanceDeviationPercent != null
            ? `${this.summary.distanceDeviationPercent}%`
            : '0.00%';
    }

    get batteryPercentLabel() {
        return this.summary && this.summary.batteryLevel != null ? `${Math.round(this.summary.batteryLevel)}%` : 'N/A';
    }

    get gpsStatusLabel() {
        return this.summary && this.summary.gpsStatus ? this.summary.gpsStatus : 'Offline';
    }

    get gpsBadgeClass() {
        const active = this.gpsStatusLabel.toLowerCase() === 'active';
        return active ? 'gps-badge gps-active' : 'gps-badge gps-inactive';
    }

    get hasPunchedIn() {
        return this.summary && this.summary.punchInTime;
    }

    get hasActivity() {
        const hasTimeline = this.timelineData && this.timelineData.length > 0;
        const hasTracks = this.trackLocations && this.trackLocations.length > 0;
        return hasTimeline || hasTracks;
    }

    get hasMapMarkers() {
        const hasMarkers = this.mapMarkers && this.mapMarkers.length > 0;
        const hasTracks = this.trackLocations && this.trackLocations.length > 0;
        const hasPunches = this.punchMarkers && this.punchMarkers.length > 0;
        const hasVisits = this.visitNodes && this.visitNodes.length > 0;
        return hasMarkers || hasTracks || hasPunches || hasVisits;
    }

    // Action handlers
    handleUserCardClick(event) {
        const uid = event.currentTarget.dataset.id;
        if (uid) {
            this.isSingleView = true;
            if (this.selectedEmployeeId === uid) {
                this.isLoading = false;
                this.processListSummaryData();
                if (this.wiredDashboardResult) {
                    refreshApex(this.wiredDashboardResult);
                }
            } else {
                this.isLoading = true;
                this.isMapInitialized = false;
                this.selectedEmployeeId = uid;
                this.processListSummaryData();
            }
        }
    }

    handleViewTrailClick(event) {
        event.stopPropagation(); // Prevent card bubble click
        const uid = event.currentTarget.dataset.id;
        if (uid) {
            this.isSingleView = true;
            if (this.selectedEmployeeId === uid) {
                this.isLoading = false;
                this.processListSummaryData();
                if (this.wiredDashboardResult) {
                    refreshApex(this.wiredDashboardResult);
                }
            } else {
                this.isLoading = true;
                this.isMapInitialized = false;
                this.selectedEmployeeId = uid;
                this.processListSummaryData();
            }
        }
    }

    handleSidebarSelect(event) {
        const uid = event.currentTarget.dataset.id;
        if (uid && uid !== this.selectedEmployeeId) {
            this.isLoading = true;
            this.isMapInitialized = false;
            this.selectedEmployeeId = uid;
            this.processListSummaryData();
        }
    }

    handleBackToList() {
        this.isSingleView = false;
        this.isMapInitialized = false;
        this.isLoading = false;
    }

    handleDateChange(event) {
        const newVal = event.detail.value;
        if (newVal) {
            if (newVal !== this.selectedDate) {
                this.isLoading = true;
                this.isMapInitialized = false;
                this.selectedDate = newVal;
            }
        } else {
            // Reset to today's date if datepicker is cleared
            const today = new Date();
            const yyyy = today.getFullYear();
            const mm = String(today.getMonth() + 1).padStart(2, '0');
            const dd = String(today.getDate()).padStart(2, '0');
            const todayStr = `${yyyy}-${mm}-${dd}`;
            if (this.selectedDate !== todayStr) {
                this.isLoading = true;
                this.isMapInitialized = false;
                this.selectedDate = todayStr;
            }
        }
    }

    handleRefresh() {
        this.isLoading = true;
        this.isMapInitialized = false;
        const promises = [];
        if (this.wiredDashboardResult) {
            promises.push(refreshApex(this.wiredDashboardResult));
        }
        if (this.wiredSummariesResult) {
            promises.push(refreshApex(this.wiredSummariesResult));
        }
        if (this.wiredWfhRequestsResult) {
            promises.push(refreshApex(this.wiredWfhRequestsResult));
        }
        Promise.all(promises)
            .then(() => {
                this.loadTeamWfhRequests();
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Image Zoom Logic
    openImagePreview(event) {
        this.modalImageUrl = event.currentTarget.dataset.url;
        this.showImageModal = true;
    }

    closeImagePreview() {
        this.showImageModal = false;
        this.modalImageUrl = '';
    }

    stopBubble(event) {
        event.stopPropagation();
    }

    // Utility show toast
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    dashboardRemarksMap = {};

    handleDashboardRemarksChange(event) {
        const reqId = event.target.dataset.id;
        this.dashboardRemarksMap[reqId] = event.target.value;
    }

    async handleApproveWFH(event) {
        const reqId = event.target.dataset.id;
        const remarks = this.dashboardRemarksMap[reqId] || '';
        try {
            await updateWFHStatus({ requestId: reqId, status: 'Approved', remarks: remarks });
            this.applyLocalWfhStatusUpdate(reqId, 'Approved', remarks);
            this.showToast('Success', 'Request Approved Successfully', 'success');
            this.refreshDashboardWfh();
        } catch (error) {
            this.showToast('Error', 'Failed to approve: ' + error.body.message, 'error');
        }
    }

    async handleRejectWFH(event) {
        const reqId = event.target.dataset.id;
        const remarks = this.dashboardRemarksMap[reqId] || '';
        try {
            await updateWFHStatus({ requestId: reqId, status: 'Rejected', remarks: remarks });
            this.applyLocalWfhStatusUpdate(reqId, 'Rejected', remarks);
            this.showToast('Info', 'Request Rejected', 'info');
            this.refreshDashboardWfh();
        } catch (error) {
            this.showToast('Error', 'Failed to reject: ' + error.body.message, 'error');
        }
    }

    applyLocalWfhStatusUpdate(reqId, status, remarks) {
        const patchList = (list) => {
            if (!list || list.length === 0) {
                return list;
            }
            return list.map(req => {
                if (req.requestId !== reqId) {
                    return req;
                }
                return this.formatDashboardWfhRequest({
                    ...req,
                    status,
                    remarks
                });
            });
        };
        this.teamWfhRequests = patchList(this.teamWfhRequests);
        this.selfWfhRequests = patchList(this.selfWfhRequests);
    }

    refreshDashboardWfh() {
        if (this.wiredWfhRequestsResult) {
            refreshApex(this.wiredWfhRequestsResult);
        }
        this.loadTeamWfhRequests();
    }

    calculateDistanceMeters(lat1, lon1, lat2, lon2) {
        if (lat1 === null || lon1 === null || lat2 === null || lon2 === null) {
            return 0.0;
        }
        const radius = 6371000.0; // Earth radius in meters
        const dLat = (lat2 - lat1) * Math.PI / 180.0;
        const dLon = (lon2 - lon1) * Math.PI / 180.0;
        const rLat1 = lat1 * Math.PI / 180.0;
        const rLat2 = lat2 * Math.PI / 180.0;
        const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                   Math.cos(rLat1) * Math.cos(rLat2) *
                   Math.sin(dLon / 2) * Math.sin(dLon / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return radius * c;
    }

    // ─── Analytics & Reports ─────────────────────────────────────────────────

    get isTrackingTab() {
        return this.activeTab === 'tracking' || this.activeTab === 'overview';
    }

    handleAnalyticsTabActive() {
        this.activeTab = 'analytics';
        this.isSingleView = false;
        if (!this.analyticsStartDate || !this.analyticsEndDate) {
            this.calculateDateRange();
        }
        this.loadAnalyticsData();
    }

    handleAnalyticsModeChange(event) {
        this.analyticsMode = event.currentTarget.dataset.mode;
        this.calculateDateRange();
        if (this.analyticsMode !== 'CUSTOM') {
            this.loadAnalyticsData();
        }
    }

    handleAnalyticsStartDateChange(event) {
        this.analyticsStartDate = event.target.value;
        if (this.analyticsStartDate && this.analyticsEndDate) {
            this.loadAnalyticsData();
        }
    }

    handleAnalyticsEndDateChange(event) {
        this.analyticsEndDate = event.target.value;
        if (this.analyticsStartDate && this.analyticsEndDate) {
            this.loadAnalyticsData();
        }
    }

    calculateDateRange() {
        const today = new Date();
        if (this.analyticsMode === 'DAILY') {
            this.analyticsStartDate = this.formatDate(today);
            this.analyticsEndDate = this.formatDate(today);
            this.showCustomDateRange = false;
        } else if (this.analyticsMode === 'WEEKLY') {
            const day = today.getDay();
            const diff = today.getDate() - day + (day === 0 ? -6 : 1);
            const startOfWeek = new Date(today.setDate(diff));
            const endOfWeek = new Date(startOfWeek);
            endOfWeek.setDate(startOfWeek.getDate() + 6);
            this.analyticsStartDate = this.formatDate(startOfWeek);
            this.analyticsEndDate = this.formatDate(endOfWeek);
            this.showCustomDateRange = false;
        } else if (this.analyticsMode === 'MONTHLY') {
            const startOfMonth = new Date(today.getFullYear(), today.getMonth(), 1);
            const endOfMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0);
            this.analyticsStartDate = this.formatDate(startOfMonth);
            this.analyticsEndDate = this.formatDate(endOfMonth);
            this.showCustomDateRange = false;
        } else if (this.analyticsMode === 'CUSTOM') {
            this.showCustomDateRange = true;
        }
    }

    formatDate(date) {
        const yyyy = date.getFullYear();
        const mm = String(date.getMonth() + 1).padStart(2, '0');
        const dd = String(date.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
    }

    loadAnalyticsData() {
        if (!this.availableUserIds || this.availableUserIds.length === 0) {
            return;
        }
        if (!this.analyticsStartDate || !this.analyticsEndDate) {
            return;
        }
        this.isAnalyticsLoading = true;
        getAnalyticsSummary({
            userIds: this.availableUserIds,
            startDate: this.analyticsStartDate,
            endDate: this.analyticsEndDate
        })
        .then(result => {
            this.analyticsData = result.map(row => {
                let outcomeList = [];
                if (row.outcomeBreakdownJson) {
                    try {
                        const parsed = JSON.parse(row.outcomeBreakdownJson);
                        outcomeList = Object.keys(parsed).map(key => `${key}: ${parsed[key]}`);
                    } catch (e) {
                        console.error('Error parsing outcome breakdown JSON:', e);
                    }
                }
                return {
                    ...row,
                    outcomeFormatted: outcomeList.join(', ') || 'None',
                    avgHoursFormatted: this.formatHoursMinutes(row.avgHoursPerDay),
                    totalWorkingHoursFormatted: this.formatHoursMinutes(row.totalWorkingHours),
                    totalDistanceFormatted: row.totalDistanceKm != null ? `${row.totalDistanceKm.toFixed(2)} km` : '0 km',
                    avgVisitsFormatted: row.avgVisitsPerDay != null ? row.avgVisitsPerDay.toFixed(1) : '0'
                };
            });
            this.isAnalyticsLoading = false;
        })
        .catch(error => {
            console.error('Error loading analytics:', error);
            this.showToast('Error', 'Failed to retrieve analytics data: ' + error.body.message, 'error');
            this.isAnalyticsLoading = false;
        });
    }

    // Getters for UI Modes
    get isDailyMode() { return this.analyticsMode === 'DAILY'; }
    get isWeeklyMode() { return this.analyticsMode === 'WEEKLY'; }
    get isMonthlyMode() { return this.analyticsMode === 'MONTHLY'; }
    get isCustomMode() { return this.analyticsMode === 'CUSTOM'; }

    get dailyPillClass() { return `filter-pill ${this.isDailyMode ? 'active' : ''}`; }
    get weeklyPillClass() { return `filter-pill ${this.isWeeklyMode ? 'active' : ''}`; }
    get monthlyPillClass() { return `filter-pill ${this.isMonthlyMode ? 'active' : ''}`; }
    get customPillClass() { return `filter-pill ${this.isCustomMode ? 'active' : ''}`; }

    // Summary calculations for KPI cards
    get analyticsTotalVisits() {
        return this.analyticsData.reduce((sum, row) => sum + (row.totalVisits || 0), 0);
    }

    get analyticsCompletedVisits() {
        return this.analyticsData.reduce((sum, row) => sum + (row.completedVisits || 0), 0);
    }

    get analyticsTotalHours() {
        return this.formatHoursMinutes(this.analyticsData.reduce((sum, row) => sum + (row.totalWorkingHours || 0), 0));
    }

    get analyticsTotalDistance() {
        return this.analyticsData.reduce((sum, row) => sum + (row.totalDistanceKm || 0), 0).toFixed(2);
    }

    get analyticsTotalPresentDays() {
        return this.analyticsData.reduce((sum, row) => sum + (row.presentDays || 0), 0);
    }
}
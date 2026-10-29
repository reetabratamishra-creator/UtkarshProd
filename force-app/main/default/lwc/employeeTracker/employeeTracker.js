import { LightningElement, track, wire } from 'lwc';
import getEmployees from '@salesforce/apex/EmployeeTracker.getEmployees';
import getClients from '@salesforce/apex/EmployeeTracker.getClients';
import getRecentTasksForEmployees from '@salesforce/apex/EmployeeTracker.getRecentTasksForEmployees';
import updateWFHStatus from '@salesforce/apex/EmployeeTracker.updateWFHStatus';
import canAccessForceTracker from '@salesforce/apex/EmployeeTracker.canAccessForceTracker';
import canCurrentUserApproveWfh from '@salesforce/apex/FieldForceDashboardController.canCurrentUserApproveWfh';
import getMultipleUsersDailySummary from '@salesforce/apex/FieldForceDashboardController.getMultipleUsersDailySummary';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import MAP_CONTAINER from '@salesforce/resourceUrl/mapContainer';

const GOOGLE_API_KEY = 'AIzaSyBNUhqtyLy3zqmzyTTxOf-5DJ_0tottSIY'; //'AIzaSyAF5PF39kVNNf9SVpEeNiInBH__wC9ZAhA';

export default class EmployeeTracker extends LightningElement {
    @track employees = [];
    @track clients = [];
    @track tasksByEmployee = {};   
    @track expandedState = {}; 
    @track dailySummariesMap = {};
    @track selectedVendor = 'GOOGLE'; 
    @track fullImageUrl = '';
    @track showImageModal = false;
    
    @track canApproveWfhRequests = false;
    @track hasTrackerAccess = false;
    @track trackerAccessChecked = false;
    @track selectedDate = '';

    selectedEmployeeId = null;
    searchKey = '';
    statusFilter = 'ALL';   
    batteryFilter = 'ALL';  
    gpsFilter = 'ALL';      
    showClients = false;
    showSites = false;      
    isMapInitialized = false;

    mapCenter = {
        location: { Latitude: 23.021969, Longitude: 87.451724 }
    };


    get mapUrl() { return MAP_CONTAINER; }

    get punchedInCount() {
        return (this.employees || []).filter(e => e.currentStatus === 'IN').length;
    }

    get punchedOutCount() {
        return (this.employees || []).filter(e => e.currentStatus !== 'IN').length;
    }

    get allBtnClass() {
        return 'et-status-btn' + (this.statusFilter === 'ALL' ? ' et-selected-all' : '');
    }

    get inBtnClass() {
        return 'et-status-btn' + (this.statusFilter === 'IN' ? ' et-selected-in' : '');
    }

    get outBtnClass() {
        return 'et-status-btn' + (this.statusFilter === 'OUT' ? ' et-selected-out' : '');
    }

    get showAccessDenied() {
        return this.trackerAccessChecked && !this.hasTrackerAccess;
    }

    connectedCallback() {
        const today = new Date();
        const yyyy = today.getFullYear();
        const mm = String(today.getMonth() + 1).padStart(2, '0');
        const dd = String(today.getDate()).padStart(2, '0');
        this.selectedDate = `${yyyy}-${mm}-${dd}`;

        canAccessForceTracker()
            .then(canAccess => {
                this.hasTrackerAccess = canAccess === true;
                this.trackerAccessChecked = true;
                if (!this.hasTrackerAccess) {
                    return;
                }
                canCurrentUserApproveWfh()
                    .then(canApprove => {
                        this.canApproveWfhRequests = canApprove || false;
                    })
                    .catch(error => {
                        console.error('Error fetching WFH approval access:', error);
                        this.canApproveWfhRequests = false;
                    });
                this.loadData();
            })
            .catch(error => {
                console.error('Error checking Force Tracker access:', error);
                this.hasTrackerAccess = false;
                this.trackerAccessChecked = true;
            });

        window.addEventListener('message', this.handleMessage);
    }

    disconnectedCallback() {
        window.removeEventListener('message', this.handleMessage);
    }

    async loadData() {
        try {
            const result = await getEmployees();
            this.employees = result || [];
            const empIds = this.employees.map(e => e.Id);
            
            if (empIds.length > 0) {
                const taskResult = await getRecentTasksForEmployees({
                    employeeIds: empIds,
                    perEmployeeLimit: 5,
                    dateStr: this.selectedDate
                });
                this.processTasks(taskResult);

                // Fetch bulk summaries for cards
                try {
                    const dailySummaries = await getMultipleUsersDailySummary({
                        userIds: empIds,
                        statusDate: this.selectedDate
                    });
                    const summaryMap = {};
                    (dailySummaries || []).forEach(s => {
                        summaryMap[s.userId] = s;
                    });
                    this.dailySummariesMap = summaryMap;
                } catch (summaryError) {
                    console.error('Error fetching bulk daily summaries:', summaryError);
                }
            }

            this.clients = await getClients();
        } catch (error) {
            console.error('Error loading data:', error);
        }
    }


    processTasks(taskResult) {
        if (!taskResult) return;
        const map = {};
        taskResult.forEach(row => {
            const d = new Date(row.timeLabel);
            const time = d.toLocaleString('en-IN', { dateStyle: 'short', timeStyle: 'short' });
            const isPunch = row.type === 'PUNCH';
            const isTrack = row.type === 'TRACK';
            const isTask = !isPunch && !isTrack;

            let badgeLabel = row.type || 'Activity';
            let badgeClass = 'timeline-badge-task';
            if (isPunch) {
                badgeLabel = row.action === 'OUT' ? 'PUNCH OUT' : 'PUNCH IN';
                badgeClass = row.action === 'OUT' ? 'timeline-badge-punch-out' : 'timeline-badge-punch';
            } else if (isTrack) {
                badgeLabel = 'TRACK';
                badgeClass = 'timeline-badge-track';
            } else if (row.isCheckout) {
                badgeLabel = 'CHECKED OUT';
                badgeClass = 'timeline-badge-checkout';
            } else {
                badgeLabel = 'IN PROGRESS';
                badgeClass = 'timeline-badge-task';
            }

            const hasTransport = !!(row.transportType || row.vehicleType);
            const transportLabel = hasTransport
                ? [row.transportType, row.vehicleType].filter(Boolean).join(' · ')
                : '';
            const hasOdometer = row.odometer != null && row.odometer !== '';
            const hasVisitDetails = !!(row.reasonForVisit || row.visitType || row.visitCategory
                || row.visitOutcome || row.mom || row.nextAction || row.checkInTime || row.visitDuration);
            const hasMedia = !!(row.selfieUrl || row.odometerUrl);
            const hasDetails = !!(row.client || hasTransport || hasOdometer || row.address
                || hasVisitDetails || hasMedia);

            if (!map[row.employeeId]) map[row.employeeId] = [];
            map[row.employeeId].push({
                id: row.taskId,
                time: time,
                rawTime: row.timeLabel,
                text: row.description || row.reasonForVisit || '',
                client: row.client,
                lat: row.latitude,
                lng: row.longitude,
                address: row.address,
                type: row.type,
                punchType: row.punchType,
                action: row.action,
                transportType: row.transportType,
                vehicleType: row.vehicleType,
                transportLabel: transportLabel,
                hasTransport: hasTransport,
                odometer: row.odometer,
                hasOdometer: hasOdometer,
                selfieUrl: row.selfieUrl,
                odometerUrl: row.odometerUrl,
                isCheckout: row.isCheckout,
                visitCategory: row.visitCategory,
                visitType: row.visitType,
                reasonForVisit: row.reasonForVisit,
                visitOutcome: row.visitOutcome,
                mom: row.mom,
                nextAction: row.nextAction,
                checkInTime: row.checkInTime,
                checkOutTime: row.checkOutTime,
                visitDuration: row.visitDuration,
                hasVisitDetails: hasVisitDetails,
                hasMedia: hasMedia,
                hasDetails: hasDetails,
                isPunch: isPunch,
                isTask: isTask,
                isTrack: isTrack,
                badgeLabel: badgeLabel,
                badgeClass: badgeClass,
                iconName: isPunch ? 'utility:announcement' : (isTrack ? 'utility:routing_offline' : 'utility:record'),
                iconVariant: row.action === 'IN' ? 'success' : (row.action === 'OUT' ? 'error' : (row.isCheckout ? 'inverse' : 'warning'))
            });
        });

        Object.keys(map).forEach(empId => {
            map[empId].sort((a, b) => new Date(b.rawTime) - new Date(a.rawTime));
        });

        this.tasksByEmployee = map;
        this.employees = [...this.employees];
    }

    get filteredEmployees() {
        let data = [...this.employees];
        const key = this.searchKey.trim().toLowerCase();
        if (key) data = data.filter(e => e.employeeName.toLowerCase().includes(key) || e.phone.toLowerCase().includes(key));
        if (this.statusFilter !== 'ALL') data = data.filter(e => e.currentStatus === this.statusFilter);
        
        const todayStr = new Date().toISOString().split('T')[0];
        const isToday = (this.selectedDate === todayStr || !this.selectedDate);

        return data.map(e => {
            const d = new Date(e.lastPunchTime);
            const allItems = this.tasksByEmployee[e.Id] || [];
            const timeline = this.withNodeDistances(
                allItems.filter(t => t.type !== 'TRACK'),
                allItems.filter(t => t.type === 'TRACK')
            );
            const isExpanded = !!this.expandedState[e.Id];
            
            const formattedPending = (e.pendingRequests || []).map(req => {
                return {
                    ...req,
                    formattedDate: this.formatDateString(req.requestDate),
                    formattedStartTime: this.formatRequestTime(req.startTime),
                    formattedEndTime: this.formatRequestTime(req.endTime)
                };
            });

            let statusLabel = (e.currentStatus === 'IN' ? 'Punched IN' : 'Punched OUT') + 
                             (e.lastPunchTime ? ' : ' + d.toLocaleString() : '');
            let statusClass = 'et-status-pill ' + (e.currentStatus === 'IN' ? 'et-pill-in-bg' : 'et-pill-out-bg');
            let lastKnownAddress = e.lastKnownAddress;

            if (!isToday) {
                // Determine status from the last punch on that date
                const tasks = this.tasksByEmployee[e.Id] || [];
                const lastPunch = tasks.find(t => t.type === 'PUNCH');
                if (lastPunch) {
                    // statusLabel = `Punched ${lastPunch.action} on ${this.selectedDate} at ${lastPunch.time}`;
                    const punchTime = new Date(lastPunch.rawTime).toLocaleTimeString('en-IN', {
                        hour: '2-digit',
                        minute: '2-digit'
                    });

                    statusLabel = `Punched ${lastPunch.action} on ${this.selectedDate} at ${punchTime}`;
                    statusClass = 'et-status-pill ' + (lastPunch.action === 'IN' ? 'et-pill-in-bg' : 'et-pill-out-bg');
                } else {
                    statusLabel = `No Punch recorded on ${this.selectedDate}`;
                    statusClass = 'et-status-pill et-pill-out-bg';
                }

                // Determine last known location/address on that date
                const lastLoc = tasks.find(t => t.lat && t.lng);
                if (lastLoc) {
                    lastKnownAddress = `Last active at ${lastLoc.time}`;
                } else {
                    lastKnownAddress = 'No location recorded';
                }
            }

            // Get summary data
            const summary = this.dailySummariesMap[e.Id] || {
                attendanceStatus: 'Absent',
                punchInTime: 'N/A',
                punchOutTime: 'N/A',
                totalHours: '0.00 hrs',
                distanceKm: 0.00,
                batteryLevel: 'N/A',
                gpsStatus: 'Offline',
                visitsCount: 0
            };

            const hasPunchedIn = summary.punchInTime && summary.punchInTime !== 'N/A';
            const hasPunchedOut = summary.punchOutTime && summary.punchOutTime !== 'N/A';

            let attendanceBadgeClass = 'et-badge-status ';
            const attStatus = summary.attendanceStatus;
            if (attStatus === 'Present') {
                attendanceBadgeClass += 'et-badge-in';
            } else if (attStatus === 'Absent') {
                attendanceBadgeClass += 'et-badge-out';
            } else if (attStatus === 'Short Hours') {
                attendanceBadgeClass += 'et-badge-out';
            } else if (attStatus === 'Offline') {
                attendanceBadgeClass += 'et-badge-out';
            } else if (attStatus === 'WFH') {
                attendanceBadgeClass += 'et-badge-wfh';
            } else if (attStatus === 'WFO') {
                attendanceBadgeClass += 'et-badge-wfo';
            } else if (attStatus === 'Market Visit') {
                attendanceBadgeClass += 'et-badge-market';
            } else {
                attendanceBadgeClass += 'et-badge-in';
            }

            let gpsBadgeClass = 'et-gps-badge ';
            const gpsStat = summary.gpsStatus;
            if (gpsStat === 'Active') {
                gpsBadgeClass += 'et-gps-active';
            } else {
                gpsBadgeClass += 'et-gps-inactive';
            }

            const distance = summary.distanceKm;
            const formattedDistance = (distance != null) ? (distance.toFixed(2) + ' km') : '0.00 km';

            return {
                ...e,
                statusLabel: statusLabel,
                statusClass: statusClass,
                lastKnownAddress: lastKnownAddress,
                timeline: timeline,
                isExpanded: isExpanded,
                expandLabel: isExpanded ? 'Collapse' : 'Expand',
                pendingRequests: formattedPending,
                hasPendingRequests: formattedPending.length > 0,
                summary: summary,
                hasPunchedIn: hasPunchedIn,
                hasPunchedOut: hasPunchedOut,
                attendanceBadgeClass: attendanceBadgeClass,
                gpsBadgeClass: gpsBadgeClass,
                formattedDistance: formattedDistance,
                formattedHours: this.formatHours(summary.totalHours),
                hasBattery: e.batteryPercentage !== null && e.batteryPercentage !== undefined
            };
        });
    }

    toggleExpand(event) {
        const id = event.currentTarget.dataset.id;
        this.expandedState = { ...this.expandedState, [id]: !this.expandedState[id] };
        if (this.expandedState[id]) {
            this.selectedEmployeeId = id;
            this.drawHistoricalPath(id);
        } else {
            this.clearHistoricalPath();
        }
        this.employees = [...this.employees];
    }

    openFullImage(event) {
        this.fullImageUrl = event.currentTarget.dataset.url;
        this.showImageModal = true;
    }

    closeImageModal() {
        this.showImageModal = false;
        this.fullImageUrl = '';
    }

    stopBubble(event) { event.stopPropagation(); }


    handleDateChange(event) {
        this.selectedDate = event.target.value;
        this.expandedState = {};
        this.selectedEmployeeId = null;
        this.clearHistoricalPath();
        this.loadData();
    }

    handleSearchChange(event) { this.searchKey = event.target.value; }
    handleStatusFilter(event) { this.statusFilter = event.currentTarget.dataset.value; }
    handleBatteryChange(event) { this.batteryFilter = event.detail.value; }
    handleGpsChange(event) { this.gpsFilter = event.detail.value; }
    handleToggleClients(event) { this.showClients = event.target.checked; }
    handleToggleSites(event) { this.showSites = event.target.checked; }

    get mapMarkers() {
        const todayStr = new Date().toISOString().split('T')[0];
        const isToday = (this.selectedDate === todayStr || !this.selectedDate);

        return this.filteredEmployees
            .map(e => {
                let lat = Number(e.latitude);
                let lng = Number(e.longitude);
                let address = e.lastKnownAddress;

                if (!isToday) {
                    // Find last known location from the selected date's tasks
                    const tasks = this.tasksByEmployee[e.Id] || [];
                    const locTask = tasks.find(t => t.lat && t.lng);
                    if (locTask) {
                        lat = Number(locTask.lat);
                        lng = Number(locTask.lng);
                        address = `Last location on ${this.selectedDate} at ${locTask.time}`;
                    } else {
                        lat = null;
                        lng = null;
                    }
                }

                if (!lat || !lng) return null;

                return {
                    location: { Latitude: lat, Longitude: lng },
                    title: e.employeeName,
                    description: address,
                    value: e.Id
                };
            })
            .filter(marker => marker !== null);
    }

    handleMessage = (event) => {
        if (event && event.data && event.data.type === 'MAP_READY') {
            this.plotMarkers();
            if (this.selectedEmployeeId) this.drawHistoricalPath(this.selectedEmployeeId);
        }
    };

    renderedCallback() {
        const iframe = this.template.querySelector('.map-iframe');
        if (iframe && !this.isMapInitialized) {
            this.isMapInitialized = true;
            iframe.onload = () => {
                this.initializeMap(iframe);
            };
        } else if (this.isMapInitialized) {
            this.plotMarkers();
        }
    }

    async initializeMap(iframe) {
        if (iframe && iframe.contentWindow) {
            iframe.contentWindow.postMessage({
                type: 'INIT_GOOGLE',
                apiKey: GOOGLE_API_KEY,
                center: { lat: this.mapCenter.location.Latitude, lng: this.mapCenter.location.Longitude }
            }, '*');
        }
    }

    plotMarkers() {
        const iframe = this.template.querySelector('.map-iframe');
        if (iframe && iframe.contentWindow) {
            iframe.contentWindow.postMessage({ type: 'PLOT_MARKERS', markers: this.mapMarkers }, '*');
        }
    }

    drawHistoricalPath(empId) {
        const tasks = this.tasksByEmployee[empId] || [];

        // 1. Path from periodic track logs only (same as fieldForceDashboard)
        const trackItems = [...tasks]
            .filter(t => t.isTrack && t.lat != null && t.lng != null)
            .reverse(); // chronological ASC
        
        let path = [];
        if (trackItems.length > 0) {
            let lastLat = null;
            let lastLng = null;
            for (const item of trackItems) {
                const lat = Number(item.lat);
                const lng = Number(item.lng);
                if (isNaN(lat) || isNaN(lng)) {
                    continue;
                }
                if (lastLat !== null && lastLng !== null) {
                    const dist = this.calculateDistanceMeters(lastLat, lastLng, lat, lng);
                    if (dist < 50.0) {
                        continue;
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

            // Keep start and end if filter is too aggressive
            if (path.length <= 1 && trackItems.length > 0) {
                path = [];
                const first = trackItems[0];
                const last = trackItems[trackItems.length - 1];
                path.push({ lat: Number(first.lat), lng: Number(first.lng), title: 'Start Point' });
                if (trackItems.length > 1) {
                    path.push({ lat: Number(last.lat), lng: Number(last.lng), title: 'End Point' });
                }
            }
        }

        // 2. Build numbered visit nodes from TASK-type items only (chronological)
        const taskItems = [...tasks]
            .filter(t => t.isTask && t.lat && t.lng)
            .reverse(); // chronological
        const visitNodes = taskItems.map((t, idx) => ({
            nodeNumber: idx + 1,
            latitude: Number(t.lat),
            longitude: Number(t.lng),
            clientName: t.client || 'Visit',
            checkInTime: t.checkInTime || t.time,
            checkOutTime: t.checkOutTime || (t.isCheckout ? '' : 'Active'),
            visitDuration: t.visitDuration || '',
            visitCategory: t.type + (t.visitCategory ? ' - ' + t.visitCategory : ''),
            isActive: !t.isCheckout
        }));

        // 3. Build Punch Markers (Day In -> DI, Market Visit Start -> S, Market Visit End -> E, Day Out -> DO)
        const punchItems = [...tasks]
            .filter(t => t.isPunch)
            .reverse(); // chronological ASC

        const punchMarkers = [];
        for (const p of punchItems) {
            let lat = p.lat != null ? Number(p.lat) : null;
            let lng = p.lng != null ? Number(p.lng) : null;

            if ((lat == null || lng == null || isNaN(lat) || isNaN(lng)) && trackItems.length > 0) {
                if (p.action === 'IN') {
                    lat = Number(trackItems[0].lat);
                    lng = Number(trackItems[0].lng);
                } else if (p.action === 'OUT') {
                    lat = Number(trackItems[trackItems.length - 1].lat);
                    lng = Number(trackItems[trackItems.length - 1].lng);
                }
            }

            if (lat == null || lng == null || isNaN(lat) || isNaN(lng)) {
                continue;
            }

            const pType = p.punchType || '';
            const action = p.action || '';
            const timeStr = p.rawTime
                ? new Date(p.rawTime).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })
                : (p.time || '');

            let label = '';
            let title = '';
            let color = '';

            if (pType === 'Day In / Out') {
                if (action === 'IN') {
                    label = 'DI';
                    title = 'Day In';
                    color = '#10B981';
                } else if (action === 'OUT') {
                    label = 'DO';
                    title = 'Day Out';
                    color = '#EF4444';
                }
            } else if (pType === 'Market Visit') {
                if (action === 'IN') {
                    label = 'S';
                    title = 'Market Visit Start';
                    color = '#2563EB';
                } else if (action === 'OUT') {
                    label = 'E';
                    title = 'Market Visit End';
                    color = '#DC2626';
                }
            }

            if (label) {
                punchMarkers.push({
                    id: p.id,
                    punchType: pType,
                    action: action,
                    latitude: lat,
                    longitude: lng,
                    label: label,
                    title: title,
                    color: color,
                    address: p.address || '',
                    timeLabel: timeStr
                });
            }
        }

        const iframe = this.template.querySelector('.map-iframe');
        if (iframe && iframe.contentWindow) {
            iframe.contentWindow.postMessage({
                type: 'DRAW_PATH',
                path: path,
                visitNodes: visitNodes,
                punchMarkers: punchMarkers
            }, '*');
        }
    }

    clearHistoricalPath() {
        const iframe = this.template.querySelector('.map-iframe');
        if (iframe && iframe.contentWindow) iframe.contentWindow.postMessage({ type: 'DRAW_PATH', path: [] }, '*');
    }



    remarksMap = {};

    handleRemarksChange(event) {
        const reqId = event.target.dataset.id;
        this.remarksMap[reqId] = event.target.value;
    }

    // WFH Approval
    async handleApproveWFH(event) {
        if (!this.canApproveWfhRequests) {
            this.showToast('Error', 'Only HOD or Admin can approve or reject WFH/WFO requests.', 'error');
            return;
        }
        const reqId = event.target.dataset.id;
        const remarks = this.remarksMap[reqId] || '';
        try {
            await updateWFHStatus({ requestId: reqId, status: 'Approved', remarks: remarks });
            this.showToast('Success', 'WFH/WFO Request Approved', 'success');
            this.loadData(); // Refresh list
        } catch (error) {
            this.showToast('Error', 'Failed to approve: ' + this.getErrorMessage(error), 'error');
        }
    }

    async handleRejectWFH(event) {
        if (!this.canApproveWfhRequests) {
            this.showToast('Error', 'Only HOD or Admin can approve or reject WFH/WFO requests.', 'error');
            return;
        }
        const reqId = event.target.dataset.id;
        const remarks = this.remarksMap[reqId] || '';
        try {
            await updateWFHStatus({ requestId: reqId, status: 'Rejected', remarks: remarks });
            this.showToast('Info', 'WFH/WFO Request Rejected', 'info');
            this.loadData(); // Refresh list
        } catch (error) {
            this.showToast('Error', 'Failed to reject: ' + this.getErrorMessage(error), 'error');
        }
    }

    getErrorMessage(error) {
        return (error && error.body && error.body.message) ? error.body.message : 'Unknown error';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    formatRequestTime(timeStr) {
        if (!timeStr) return '';
        try {
            const parts = timeStr.split(':');
            if (parts.length >= 2) {
                let hh = parseInt(parts[0], 10);
                const mm = parts[1];
                const ampm = hh >= 12 ? 'PM' : 'AM';
                hh = hh % 12;
                hh = hh ? hh : 12;
                const formattedHour = String(hh).padStart(2, '0');
                return `${formattedHour}:${mm} ${ampm}`;
            }
            return timeStr;
        } catch (e) {
            return timeStr;
        }
    }

    // Converts "8.50 hrs (Active)" -> "08h 30m (Active)"; returns other values (e.g. "N/A") unchanged
    formatHours(hoursStr) {
        if (hoursStr == null) return '';
        const match = String(hoursStr).match(/^\s*(\d+(?:\.\d+)?)\s*hrs(.*)$/);
        if (!match) return hoursStr;
        const totalMinutes = Math.round(parseFloat(match[1]) * 60);
        const hh = String(Math.floor(totalMinutes / 60)).padStart(2, '0');
        const mm = String(totalMinutes % 60).padStart(2, '0');
        return `${hh}h ${mm}m${match[2]}`;
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

    calculateDistanceKm(lat1, lon1, lat2, lon2) {
        return this.calculateDistanceMeters(lat1, lon1, lat2, lon2) / 1000.0;
    }

    withNodeDistances(items, tracks) {
        if (!items || !items.length) {
            return items || [];
        }
        const chronological = [...items].sort((a, b) => {
            const ta = new Date(a.rawTime || 0).getTime();
            const tb = new Date(b.rawTime || 0).getTime();
            return ta - tb;
        });
        const trackChrono = [...(tracks || [])]
            .filter(t => t.lat != null && t.lng != null && t.rawTime)
            .sort((a, b) => new Date(a.rawTime).getTime() - new Date(b.rawTime).getTime());

        let prevItem = null;
        let isFirst = true;
        const distById = {};
        chronological.forEach(item => {
            if (isFirst) {
                distById[item.id] = 'Start';
                isFirst = false;
            } else if (this.hasCoords(item) && prevItem && this.hasCoords(prevItem)) {
                distById[item.id] = this.sumActualTravelKm(prevItem, item, trackChrono).toFixed(1) + ' KM';
            } else {
                distById[item.id] = '0 KM';
            }
            if (this.hasCoords(item)) {
                prevItem = item;
            }
        });
        return items.map(item => ({
            ...item,
            nodeDistance: distById[item.id] || ''
        }));
    }

    hasCoords(item) {
        if (!item) return false;
        const lat = Number(item.lat);
        const lng = Number(item.lng);
        return item.lat != null && item.lng != null && !isNaN(lat) && !isNaN(lng);
    }

    sumActualTravelKm(startItem, endItem, tracks) {
        const startLat = Number(startItem.lat);
        const startLng = Number(startItem.lng);
        const endLat = Number(endItem.lat);
        const endLng = Number(endItem.lng);
        const startTime = new Date(startItem.rawTime).getTime();
        const endTime = new Date(endItem.rawTime).getTime();

        const path = [{ lat: startLat, lng: startLng }];
        if (!isNaN(startTime) && !isNaN(endTime)) {
            tracks.forEach(t => {
                const tt = new Date(t.rawTime).getTime();
                const lat = Number(t.lat);
                const lng = Number(t.lng);
                if (isNaN(tt) || isNaN(lat) || isNaN(lng)) {
                    return;
                }
                if (tt > startTime && tt <= endTime) {
                    path.push({ lat, lng });
                }
            });
        }
        path.push({ lat: endLat, lng: endLng });

        let total = 0;
        let prevLat = null;
        let prevLng = null;
        path.forEach(p => {
            if (prevLat != null && prevLng != null) {
                const seg = this.calculateDistanceKm(prevLat, prevLng, p.lat, p.lng);
                if (seg < 0.03) {
                    return;
                }
                total += seg;
            }
            prevLat = p.lat;
            prevLng = p.lng;
        });
        return total;
    }
}
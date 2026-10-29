import { LightningElement , track , wire} from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { deleteRecord } from 'lightning/uiRecordApi';
import { loadScript } from 'lightning/platformResourceLoader';
import chartjs from '@salesforce/resourceUrl/ChartJs';

import getAvailableEntities from '@salesforce/apex/TargetManagerController.getAvailableEntities';
import saveTargetData from '@salesforce/apex/TargetManagerController.saveTargetData';
import getPunchData from '@salesforce/apex/TargetManagerController.getPunchData';
import getDynamicPicklists from '@salesforce/apex/TargetManagerController.getDynamicPicklists';
import getExistingTargets from '@salesforce/apex/TargetManagerController.getExistingTargets';
import getFullTargetDetails from '@salesforce/apex/TargetManagerController.getFullTargetDetails';
import getTeamMembers from '@salesforce/apex/TargetManagerController.getTeamMembers';
import getDashboardStats from '@salesforce/apex/TargetManagerController.getDashboardStats';

export default class TargetManager extends LightningElement {

 @track activeTab = 'overview';

    @track isCreatingTarget = false;
    @track currentStep = '1';
    @track isLoadingEntities = false;
    @track isEditing = false;
    @track editRecordId = null;
    
    // ==========================================
    // CHART VARIABLES (UPDATED HERE)
    // ==========================================
    trendChart;
    barChart;
    doughnutChart;
    // chartjsInitialized = false;
    chartjsLoaded = false;
    @track trendDataList = [];

    @track isTargetManager = false; 

    // --- OVERVIEW DASHBOARD VARIABLES ---
    @track selectedDashboardTarget = null; 
    @track targetDropdownOptions = [];
    @track selectedTargetId = null;
    
    // Cycle Dropdown
    @track cycleDropdownOptions = [
        { label: 'Current Cycle', value: '0' },
        { label: 'Previous Cycle (1)', value: '1' },
        { label: 'Previous Cycle (2)', value: '2' },
        { label: 'Previous Cycle (3)', value: '3' },
        { label: 'Previous Cycle (4)', value: '4' },
        { label: 'Previous Cycle (5)', value: '5' }
    ];
    @track selectedCycle = '0';
    
    @track currentCycleDisplay = '';
    @track dashboardEmployees = [];
    @track topPerformers = [];
    @track bottomPerformers = [];
    @track overallAchievement = 0;

    @track moduleOptions = [];
    @track frequencyOptions = [];
    @track metricOptions = [];
    @track assignToOptions = [];

    @track existingTargets = [];
    wiredTargetsResult;

    targetObjectName = 'Target__c';
    targetPicklistFields = ['Target_Module__c', 'Frequency__c', 'Metric__c', 'Assign_To_Type__c'];

    @wire(getDynamicPicklists, { objectApiName: '$targetObjectName', fieldApiNames: '$targetPicklistFields' })
    wiredPicklists({ error, data }) {
        if (data) {
            this.moduleOptions = data['Target_Module__c'] || [];
            this.frequencyOptions = data['Frequency__c'] || [];
            this.metricOptions = data['Metric__c'] || [];
            this.assignToOptions = data['Assign_To_Type__c'] || [];
        } else if (error) {
            this.showToast('Error loading picklists', error.body?.message, 'error');
        }
    }

    @wire(getExistingTargets)
    wiredTargets(result) {
        this.wiredTargetsResult = result;
        if (result.data) {
            this.isTargetManager = result.data.isManager;
            this.activeTab = this.isTargetManager ? 'targets' : 'overview';
            
            this.targetDropdownOptions = result.data.targets.map(t => {
                return { label: t.Name, value: t.Id };
            });

            this.existingTargets = result.data.targets.map(record => {
                let assignedNames = [];
                if (record.Target_Assignments__r) {
                    record.Target_Assignments__r.forEach(assignment => {
                        if (assignment.User__r) assignedNames.push(assignment.User__r.Name);
                        else assignedNames.push('Team/Group'); 
                    });
                }
                
                let displayNames = assignedNames.slice(0, 2).join(', ');
                let extraCount = assignedNames.length > 2 ? assignedNames.length - 2 : 0;
                let d = new Date(record.CreatedDate);
                let formattedDate = `${d.getDate().toString().padStart(2, '0')}-${(d.getMonth()+1).toString().padStart(2, '0')}-${d.getFullYear()}`;

                return {
                    ...record,
                    assignedToDisplay: displayNames,
                    hasExtra: extraCount > 0,
                    extraCountText: `+${extraCount}`,
                    createdByName: record.CreatedBy ? record.CreatedBy.Name : 'Unknown',
                    createdOnDisplay: `Created on:${formattedDate}`,
                    statusClass: record.Status__c === 'Active' ? 'status-badge-active' : 'status-badge-draft'
                };
            });

            if (this.existingTargets.length > 0 && !this.selectedTargetId) {
                this.selectedTargetId = this.existingTargets[0].Id;
                this.loadDashboardData(this.selectedTargetId);
            }
        } else if (result.error) {
            this.showToast('Error loading targets', result.error.body?.message, 'error');
        }
    }

    /* renderedCallback() {
        if (this.chartjsInitialized) return;
        this.chartjsInitialized = true;
        
        loadScript(this, chartjs)
            .then(() => {
                if (this.trendDataList.length > 0 || this.dashboardEmployees.length > 0) {
                    this.renderChart();
                }
            })
            .catch(error => {
                console.error('Error loading Chart.js', error);
            });
    } */
    renderedCallback() {
        if (this.chartjsLoaded) return;

        loadScript(this, chartjs)
            .then(() => {
                this.chartjsLoaded = true;

                if (typeof window.Chart === 'function') {
                    if (
                        this.trendDataList.length > 0 ||
                        this.dashboardEmployees.length > 0
                    ) {
                        this.renderChart();
                    }
                }
            })
            .catch(error => {
                console.error('Error loading Chart.js', error);
            });
    }

    handleTargetChange(event) {
        this.selectedTargetId = event.detail.value;
        this.selectedCycle = '0';
        this.loadDashboardData(this.selectedTargetId);
    }
    
    handleCycleChange(event) {
        this.selectedCycle = event.detail.value;
        this.loadDashboardData(this.selectedTargetId);
    }

    loadDashboardData(targetId) {
        if (!targetId) return;
        this.selectedDashboardTarget = this.existingTargets.find(t => t.Id === targetId);
        
        let freq = this.selectedDashboardTarget.Frequency__c;
        let dates = this.getPastPeriodDates(freq, parseInt(this.selectedCycle));
        
        let startStr = this.formatDateForApex(dates.start);
        let endStr = this.formatDateForApex(dates.end);

        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        let formatUI = (d) => `${d.getDate().toString().padStart(2,'0')}-${months[d.getMonth()]}-${d.getFullYear()}`;
        this.currentCycleDisplay = `${formatUI(dates.start)} to ${formatUI(dates.end)}`;

        this.dashboardEmployees = [];
        this.topPerformers = [];
        this.bottomPerformers = [];
        this.overallAchievement = 0;

        getDashboardStats({ targetId: targetId, startDateStr: startStr, endDateStr: endStr })
            .then(data => {
                this.overallAchievement = data.overallAchievement;
                
                if (data.employees && data.employees.length > 0) {
                    let sortedEmps = [...data.employees].sort((a, b) => b.percentage - a.percentage);
                    this.dashboardEmployees = sortedEmps;

                    this.topPerformers = sortedEmps.slice(0, 3).map(e => ({ id: e.id, name: e.name, perc: e.percentage + '%' }));
                    
                    let bottomEmps = [...sortedEmps].sort((a, b) => a.percentage - b.percentage);
                    this.bottomPerformers = bottomEmps.slice(0, 3).map(e => ({ id: e.id, name: e.name, perc: e.percentage + '%' }));
                }
                /* if (data.trendLines) {
                    this.trendDataList = data.trendLines;
                    if (this.chartjsInitialized) {
                        this.renderChart();
                    }
                } */
                if (data.trendLines) {
                    this.trendDataList = data.trendLines;

                    if (this.chartjsLoaded && typeof window.Chart === 'function') {
                        this.renderChart();
                    }
                }
            })
            .catch(error => {
                this.showToast('Dashboard Error', 'Could not load metrics for this target.', 'warning');
            });
    }

    // ==========================================
    // ALL 3 CHARTS DRAWN HERE
    // ==========================================
    renderChart() {
        if (!this.chartjsLoaded || typeof window.Chart !== 'function') {
            return;
        }

        requestAnimationFrame(() => {
            
            // 1. TREND LINE CHART
            const trendCanvas = this.template.querySelector('.trend-chart');
            if (trendCanvas && this.trendDataList.length > 0) {
                const ctxTrend = trendCanvas.getContext('2d');
                if (this.trendChart) this.trendChart.destroy();
                
                const labels = this.trendDataList.map(t => t.label);
                const values = this.trendDataList.map(t => t.value);

                this.trendChart = new window.Chart(ctxTrend, {
                    type: 'line',
                    data: {
                        labels: labels,
                        datasets: [{
                            label: 'Tasks Completed',
                            data: values,
                            borderColor: '#4CAF50',
                            backgroundColor: 'rgba(76, 175, 80, 0.05)',
                            borderWidth: 2,
                            fill: true,
                            tension: 0.4, 
                            pointBackgroundColor: '#4CAF50',
                            pointRadius: 4,
                            pointHoverRadius: 6
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        scales: {
                            y: { beginAtZero: true, grid: { borderDash: [5, 5] }, ticks: { precision: 0 } },
                            x: { grid: { borderDash: [5, 5] } }
                        },
                        plugins: {
                            legend: { display: false },
                            tooltip: { callbacks: { label: function(context) { return ` ${context.parsed.y} Tasks`; } } }
                        }
                    }
                });
            }

            // 2. BAR CHART: TEAM COMPARISON
            const barCanvas = this.template.querySelector('.bar-chart');
            if (barCanvas && this.dashboardEmployees.length > 0) {
                const ctxBar = barCanvas.getContext('2d');
                if (this.barChart) this.barChart.destroy();
                
                const empNames = this.dashboardEmployees.map(e => e.initials); 
                const empTargets = this.dashboardEmployees.map(e => e.target);
                const empActuals = this.dashboardEmployees.map(e => e.actual);

                this.barChart = new window.Chart(ctxBar, {
                    type: 'bar',
                    data: {
                        labels: empNames,
                        datasets: [
                            { label: 'Achieved', data: empActuals, backgroundColor: '#1a237e', borderRadius: 4 },
                            { label: 'Target', data: empTargets, backgroundColor: '#d3d3d3', borderRadius: 4 }
                        ]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        scales: { y: { beginAtZero: true, ticks: { precision: 0 } } },
                        plugins: { 
                            legend: { position: 'top' },
                            tooltip: { callbacks: { title: (context) => { return this.dashboardEmployees[context[0].dataIndex].name; } } }
                        }
                    }
                });
            }

            // 3. DOUGHNUT CHART: OVERALL COMPLETION
            const doughnutCanvas = this.template.querySelector('.doughnut-chart');
            if (doughnutCanvas && this.dashboardEmployees.length > 0) {
                const ctxDoughnut = doughnutCanvas.getContext('2d');
                if (this.doughnutChart) this.doughnutChart.destroy();

                let totalTarget = 0;
                let totalActual = 0;
                this.dashboardEmployees.forEach(e => {
                    totalTarget += e.target;
                    totalActual += e.actual;
                });
                
                let remaining = totalTarget - totalActual;
                if(remaining < 0) remaining = 0; 

                this.doughnutChart = new window.Chart(ctxDoughnut, {
                    type: 'doughnut',
                    data: {
                        labels: ['Total Achieved', 'Remaining Target'],
                        datasets: [{
                            data: [totalActual, remaining],
                            backgroundColor: ['#F89B29', '#f3f3f3'], 
                            borderWidth: 0,
                            hoverOffset: 4
                        }]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        cutout: '75%', 
                        plugins: {
                            legend: { position: 'bottom' }
                        }
                    }
                });
            }

        });
    }

    // ==========================================
    // WIZARD LOGIC
    // ==========================================

    @track targetRecord = {
        sobjectType: 'Target__c', Id: undefined, Name: '', Target_Module__c: '', Frequency__c: '', Metric__c: '', Assign_To_Type__c: '', Status__c: 'Active'
    };

    @track availableEntities = []; 
    @track filteredAvailableEntities = [];
    @track selectedEntities = [];
    @track periodColumns = [];
    @track step3Rows = []; 
    teamMembersMap = {}; 
    searchTerm = '';

    get isStep1() { return this.currentStep === '1'; }
    get isStep2() { return this.currentStep === '2'; }
    get isStep3() { return this.currentStep === '3'; }
    
    get showPrevious() { 
        if (this.targetRecord.Id && this.currentStep === '2') return false;
        return this.currentStep !== '1'; 
    }

    get isTeamTarget() { return this.targetRecord.Assign_To_Type__c === 'Team'; }

    handleAddTarget() {
        this.resetForm(); this.isCreatingTarget = true; this.currentStep = '1';
    }

    handleCancel() {
        this.isCreatingTarget = false; this.resetForm();
    }

    resetForm() {
        this.targetRecord = { sobjectType: 'Target__c', Id: undefined, Name: '', Target_Module__c: '', Frequency__c: '', Metric__c: '', Assign_To_Type__c: '', Status__c: 'Active' };
        this.selectedEntities = []; this.availableEntities = []; this.filteredAvailableEntities = [];
        this.periodColumns = []; this.step3Rows = []; this.teamMembersMap = {}; this.searchTerm = '';
    }

    handleInputChange(event) {
        this.targetRecord[event.target.dataset.field] = event.detail.value;
    }

    handleNext() {
        if (this.currentStep === '1') {
            if(!this.targetRecord.Name || !this.targetRecord.Target_Module__c || !this.targetRecord.Assign_To_Type__c || !this.targetRecord.Frequency__c) {
                this.showToast('Error', 'Please fill in all required fields.', 'error'); return;
            }
            this.currentStep = '2';
            this.fetchEntities();
        } else if (this.currentStep === '2') {
            if(this.selectedEntities.length === 0) {
                this.showToast('Error', 'Please select at least one Employee or Team.', 'error'); return;
            }
            
            const entityIds = this.selectedEntities.map(e => e.Id);
            
            if (this.isTeamTarget) {
                getTeamMembers({ groupIds: entityIds })
                .then(membersMap => {
                    this.teamMembersMap = membersMap;
                    return getPunchData({ entityIds: entityIds, assignType: 'Team' });
                })
                .then(punchData => {
                    this.currentStep = '3';
                    this.prepareStep3Table(punchData);
                })
                .catch(error => { this.showToast('Error', error.body?.message, 'warning'); });
            } else {
                getPunchData({ entityIds: entityIds, assignType: 'Users' })
                .then(punchData => {
                    this.teamMembersMap = {}; this.currentStep = '3'; this.prepareStep3Table(punchData);
                });
            }
        }
    }

    handlePrevious() {
        if (this.currentStep === '3') {
            this.currentStep = '2'; this.searchTerm = ''; this.filterEntities();
        } else if (this.currentStep === '2') {
            this.currentStep = '1';
        }
    }

    handleEdit(event) {
        const targetId = event.target.dataset.id;
        getFullTargetDetails({ targetId: targetId })
            .then(result => {
                this.targetRecord = result.target; 
                this.selectedEntities = result.assignments.map(assg => ({ Id: assg.entityId, Name: assg.entityName, SubText: assg.entitySubText, savedPeriods: assg.periods }));
                this.isCreatingTarget = true; this.currentStep = '2'; this.fetchEntities();
            })
            .catch(error => { this.showToast('Error loading edit data', error.body?.message, 'error'); });
    }

    handleDelete(event) {
        const recordId = event.target.dataset.id;
        if (window.confirm('Are you sure you want to delete this Target? All related assignments and tracking data will be permanently removed.')) {
            deleteRecord(recordId).then(() => { this.showToast('Success', 'Target deleted successfully', 'success'); return refreshApex(this.wiredTargetsResult); });
        }
    }

    fetchEntities() {
        this.isLoadingEntities = true;
        getAvailableEntities({ assignType: this.targetRecord.Assign_To_Type__c })
            .then(result => { this.availableEntities = result; this.filterEntities(); })
            .finally(() => { this.isLoadingEntities = false; });
    }

    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase(); this.filterEntities();
    }

    filterEntities() {
        let unselected = this.availableEntities.filter(avail => !this.selectedEntities.some(sel => sel.Id === avail.Id));
        if (this.searchTerm) this.filteredAvailableEntities = unselected.filter(e => e.Name.toLowerCase().includes(this.searchTerm));
        else this.filteredAvailableEntities = [...unselected];
    }

    handleSelectEntity(event) {
        const entityId = event.target.dataset.id;
        const entity = this.availableEntities.find(e => e.Id === entityId);
        if (!this.selectedEntities.find(e => e.Id === entityId)) { this.selectedEntities = [...this.selectedEntities, { ...entity }]; this.filterEntities(); }
    }

    handleSelectAll() {
        const newSelections = this.filteredAvailableEntities.filter(available => !this.selectedEntities.some(selected => selected.Id === available.Id));
        this.selectedEntities = [...this.selectedEntities, ...newSelections]; this.filterEntities();
    }

    handleRemoveEntity(event) {
        const entityId = event.target.dataset.id;
        this.selectedEntities = this.selectedEntities.filter(e => e.Id !== entityId);
        this.step3Rows = this.step3Rows.filter(r => r.Id !== entityId && r.parentId !== entityId);
        this.filterEntities();
    }

    formatDateForApex(dateObj) {
        let y = dateObj.getFullYear(); let m = (dateObj.getMonth() + 1).toString().padStart(2, '0'); let d = dateObj.getDate().toString().padStart(2, '0');
        return `${y}-${m}-${d}`;
    }

    getPastPeriodDates(frequency, stepsBack) {
        let today = new Date(); 
        today.setHours(0,0,0,0);
        let start, end;

        if (frequency === 'Daily') {
            start = new Date(today);
            start.setDate(today.getDate() - stepsBack);
            end = new Date(start);
        } else if (frequency === 'Weekly') {
            let day = today.getDay(); 
            let diffToMonday = day === 0 ? -6 : 1 - day; 
            let currentMonday = new Date(today);
            currentMonday.setDate(today.getDate() + diffToMonday);

            start = new Date(currentMonday);
            start.setDate(currentMonday.getDate() - (stepsBack * 7));
            
            end = new Date(start);
            end.setDate(start.getDate() + 6);
        } else if (frequency === 'Monthly') {
            start = new Date(today.getFullYear(), today.getMonth() - stepsBack, 1);
            end = new Date(start.getFullYear(), start.getMonth() + 1, 0); 
        } else if (frequency === 'Quarterly') {
            let currentQStartMonth = Math.floor(today.getMonth() / 3) * 3;
            let targetMonth = currentQStartMonth - (stepsBack * 3);
            start = new Date(today.getFullYear(), targetMonth, 1);
            end = new Date(start.getFullYear(), start.getMonth() + 3, 0); 
        }
        return { start, end };
    }

    prepareStep3Table(punchData) {
        const freq = this.targetRecord.Frequency__c;
        let periodName = freq === 'Weekly' ? 'Week' : (freq === 'Monthly' ? 'Month' : (freq === 'Quarterly' ? 'Quarter' : 'Day'));
        this.periodColumns = [];
        
        for(let i = 5; i >= 1; i--) {
            let dates = this.getPastPeriodDates(freq, i);
            this.periodColumns.push({ id: `prev-${i}`, label: `Prev ${periodName} (${i})`, isPast: true, startDate: dates.start, endDate: dates.end, startDateStr: this.formatDateForApex(dates.start), endDateStr: this.formatDateForApex(dates.end) });
        }
        let currentDates = this.getPastPeriodDates(freq, 0);
        this.periodColumns.push({ id: `current`, label: `Current ${periodName}`, isPast: false, startDate: currentDates.start, endDate: currentDates.end, startDateStr: this.formatDateForApex(currentDates.start), endDateStr: this.formatDateForApex(currentDates.end) });
        
        for(let i = 1; i <= 5; i++) {
            let dates = this.getPastPeriodDates(freq, -i); 
            this.periodColumns.push({ id: `next-${i}`, label: `Next ${periodName} (${i})`, isPast: false, startDate: dates.start, endDate: dates.end, startDateStr: this.formatDateForApex(dates.start), endDateStr: this.formatDateForApex(dates.end) });
        }

        let tempRows = [];
        this.selectedEntities.forEach(empOrTeam => {
            let members = this.teamMembersMap[empOrTeam.Id] || [];
            
            let headerRow = { ...empOrTeam, rowKey: empOrTeam.Id, isTeamMember: false, indentStyle: '' };
            headerRow.periods = this.periodColumns.map((col) => {
                let achievedCount = 0;
                if (col.isPast && punchData && punchData.length > 0) {
                    punchData.forEach(p => {
                        let isMatch = (!this.isTeamTarget) ? (p.userId === empOrTeam.Id) : members.some(m => m.Id === p.userId); 
                        if (isMatch) {
                            let pDate = new Date(p.punchDate); pDate.setHours(0,0,0,0);
                            if (pDate >= col.startDate && pDate <= col.endDate) achievedCount += p.count; 
                        }
                    });
                }
                
                let preFilledValue = '';
                if (empOrTeam.savedPeriods && empOrTeam.savedPeriods.length > 0) {
                    let matchingSavedPeriod = empOrTeam.savedPeriods.find(p => {
                        let sDate = p.Start_Date__c ? p.Start_Date__c.substring(0, 10) : '';
                        let eDate = p.End_Date__c ? p.End_Date__c.substring(0, 10) : '';
                        return sDate === col.startDateStr && eDate === col.endDateStr;
                    });
                    if (matchingSavedPeriod) preFilledValue = matchingSavedPeriod.Target_Quantity__c.toString();
                }

                let targetCount = preFilledValue ? parseInt(preFilledValue) : 10; 
                let barWidth = achievedCount >= targetCount ? 100 : (achievedCount / targetCount) * 100;
                return {
                    ...col, 
                    startDate: col.startDateStr, 
                    endDate: col.endDateStr,     
                    inputValue: preFilledValue, 
                    isDisabled: false, 
                    progressAchieved: achievedCount, 
                    progressTarget: targetCount,
                    widthStyle: `width: ${barWidth}%;`, 
                    progressClass: (achievedCount >= targetCount) ? 'progress-bar-green' : 'progress-bar-orange'
                };
            });
            tempRows.push(headerRow);

            if (this.isTeamTarget && members.length > 0) {
                members.forEach(member => {
                    let memberRow = { ...member, parentId: empOrTeam.Id, rowKey: empOrTeam.Id + '_' + member.Id, isTeamMember: true, indentStyle: 'padding-left: 2.5rem; border-left: 3px solid #e5e5e5; display: block;' };
                    memberRow.periods = this.periodColumns.map((col) => {
                        let achievedCount = 0;
                        if (col.isPast && punchData && punchData.length > 0) {
                            punchData.forEach(p => {
                                if (p.userId === member.Id) {
                                    let pDate = new Date(p.punchDate); pDate.setHours(0,0,0,0);
                                    if (pDate >= col.startDate && pDate <= col.endDate) achievedCount += p.count; 
                                }
                            });
                        }
                        let parentP = headerRow.periods.find(p => p.id === col.id);
                        let preFilledValue = parentP ? parentP.inputValue : '';
                        let targetCount = preFilledValue ? parseInt(preFilledValue) : 10; 
                        let barWidth = achievedCount >= targetCount ? 100 : (achievedCount / targetCount) * 100;
                        return {
                            ...col, 
                            startDate: col.startDateStr, 
                            endDate: col.endDateStr,     
                            inputValue: preFilledValue, 
                            isDisabled: true, 
                            progressAchieved: achievedCount, 
                            progressTarget: targetCount,
                            widthStyle: `width: ${barWidth}%;`, 
                            progressClass: (achievedCount >= targetCount) ? 'progress-bar-green' : 'progress-bar-orange'
                        };
                    });
                    tempRows.push(memberRow);
                });
            }
        });
        this.step3Rows = tempRows;
    }

    handlePeriodInput(event) {
        const rowId = event.target.dataset.empid;
        const periodId = event.target.dataset.periodid;
        const val = event.detail.value;

        let editedRow = this.step3Rows.find(r => r.rowKey === rowId && !r.isTeamMember);
        if (editedRow) {
            let period = editedRow.periods.find(p => p.id === periodId);
            if (period) period.inputValue = val;
            
            if (this.isTeamTarget) {
                this.step3Rows.filter(r => r.parentId === rowId).forEach(childRow => {
                    let childPeriod = childRow.periods.find(p => p.id === periodId);
                    if (childPeriod) childPeriod.inputValue = val;
                });
            }
        }
    }

    handleSave() {
        const payloadToSave = this.step3Rows.filter(r => !r.isTeamMember).map(row => { return { Id: row.Id, periods: row.periods }; });
        saveTargetData({ targetRecord: this.targetRecord, assignmentsJSON: JSON.stringify(payloadToSave), assignType: this.targetRecord.Assign_To_Type__c })
        .then(result => {
            if(result === 'Success') {
                this.showToast('Success', 'Target Configuration Saved Successfully!', 'success');
                this.isCreatingTarget = false; this.resetForm(); return refreshApex(this.wiredTargetsResult); 
            }
        })
        .catch(error => { this.showToast('Error saving Target', error.body.message, 'error'); });
    }

    showToast(title, message, variant) { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }
}
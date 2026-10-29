import { LightningElement, api, track } from 'lwc';

export default class EmployeeTimelineModal extends LightningElement {

    @api open = false;
    @api employeeId;

    @track employeeName = '';
    @track punchRecord = null;
    @track taskLogs = [];

    // STATIC data for demo
    allPunchRecords = {
        'p1': {
            id: 'p1',
            status: 'Punched OUT',
            time: 'Last Tuesday at 8:11 PM',
            tasks: [
                { id: 't1', time: '8:05 PM', description: 'Checked in at location' },
                { id: 't2', time: '8:08 PM', description: 'Met client for discussion' },
                { id: 't3', time: '8:10 PM', description: 'Completed follow-up task' }
            ]
        },
        'p2': {
            id: 'p2',
            status: 'Punched OUT',
            time: 'Last Tuesday at 8:24 PM',
            tasks: [
                { id: 't4', time: '8:15 PM', description: 'Reached work location' },
                { id: 't5', time: '8:20 PM', description: 'Submitted report' }
            ]
        },
        'p3': {
            id: 'p3',
            status: 'Punched IN',
            time: 'Today at 6:43 PM',
            tasks: [
                { id: 't6', time: '6:00 PM', description: 'Started shift' },
                { id: 't7', time: '6:20 PM', description: 'Completed inspection' },
                { id: 't8', time: '6:40 PM', description: 'Uploaded documents' }
            ]
        }
    };

    allEmployees = {
        'p1': 'Sample User 1',
        'p2': 'Sample User 2',
        'p3': 'Sample User 3'
    };



    @api
    loadEmployee(employeeId) {
        this.employeeId = employeeId;
        this.open = true;

        console.log('Loading data for employee ID:', employeeId);

        this.employeeName = this.allEmployees[employeeId] || 'Unknown';

        const punch = this.allPunchRecords[employeeId];

        if (punch) {
            this.punchRecord = {
                status: punch.status,
                time: punch.time
            };
            this.taskLogs = punch.tasks;
        } else {
            this.punchRecord = null;
            this.taskLogs = [];
        }
    }

    closeModal() {
        this.open = false;
    }
}
import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';

import getDashboard from '@salesforce/apex/PODashboardController.getDashboard';

export default class PoDashboard extends LightningElement {

    @api recordId;

    dashboard = {};

    dashboardResult;

    isLoading = true;

    showManualReviewModal = false;

    selectedRecordId;

    /*
    ===========================================================
    Dashboard Data
    ===========================================================
    */

    @wire(getDashboard, {
        opportunityId: '$recordId'
    })
    wiredDashboard(result) {

        this.dashboardResult = result;

        this.isLoading = false;

        if (result.data) {

            this.dashboard = result.data;

        } else if (result.error) {

            console.error(result.error);

        }

    }

    /*
    ===========================================================
    Helpers
    ===========================================================
    */

    get hasRecords() {

        return this.dashboard.records &&
            this.dashboard.records.length > 0;

    }

    get existingItems() {

        if (!this.dashboard.records) {

            return [];

        }

        return this.dashboard.records.map(item => {

            /*
            Show Approval Status if available.
            Otherwise Processing Status.
            */

            const displayStatus =

                item.Approval_Status__c &&
                item.Approval_Status__c !== 'None'

                    ? item.Approval_Status__c

                    : item.Status__c;

            /*
            Show Review Button
            */

            const showManualReview =

                item.Status__c === 'Manual Review Required' &&

                (
                    !item.Approval_Status__c ||

                    item.Approval_Status__c === 'None'
                );

            return {

                ...item,

                displayStatus,

                showManualReview,

                recordUrl: '/' + item.Id,

                formattedDate:

                    item.CreatedDate

                        ? new Date(
                            item.CreatedDate
                        ).toLocaleDateString()

                        : '',

                badgeClass:

                    'badge ' +

                    this.getBadgeClass(displayStatus)

            };

        });

    }

    /*
    ===========================================================
    Badge Colors
    ===========================================================
    */

    getBadgeClass(status) {

        switch (status) {

            case 'Completed':
                return 'badge-completed';

            case 'Failed':
                return 'badge-failed';

            case 'Processing':
                return 'badge-processing';

            case 'Queued':
                return 'badge-queued';

            case 'Manual Review Required':
                return 'badge-review';

            case 'Submit for Approval':
                return 'badge-approval';

            case 'Approved':
                return 'badge-approved';

            case 'Rejected':
                return 'badge-rejected';

            default:
                return 'badge-queued';

        }

    }

    /*
    ===========================================================
    Manual Review
    ===========================================================
    */

    handleManualReview(event) {

        this.selectedRecordId =
            event.currentTarget.dataset.id;

        this.showManualReviewModal = true;

    }

    handleModalClose() {

        this.showManualReviewModal = false;

        this.selectedRecordId = null;

    }

    handleReviewSuccess() {

        this.showManualReviewModal = false;

        this.selectedRecordId = null;

        refreshApex(this.dashboardResult);

    }

}
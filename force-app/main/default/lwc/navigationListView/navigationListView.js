import { LightningElement, api } from 'lwc';

export default class ExploreNavigationToList extends LightningElement {

    @api listViewId;
    @api objectApiName = 'Account';

    connectedCallback() {
        // Small delay ensures Flow screen is fully rendered
        setTimeout(() => {
            this.navigateToListView();
        }, 2000);
    }

    navigateToListView() {
        if (!this.listViewId || !this.objectApiName) {
            console.error('Missing inputs:', this.listViewId, this.objectApiName);
            return;
        }

        const url = `/lightning/o/${this.objectApiName}/list?filterName=${this.listViewId}`;
        window.location.href = url;
    }
}
import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMyEligibility from '@salesforce/apex/ExpenseController.getMyEligibility';

export default class EligibilityCalculator extends LightningElement {
    @track eligibility;
    @track error;
    @track isLoading = true;

    @wire(getMyEligibility)
    wiredEligibility({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.eligibility = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.eligibility = undefined;
            this.showToast('Error', 'Error loading eligibility: ' + this.getErrorMessage(error), 'error');
        }
    }

    getErrorMessage(error) {
        if (error.body) {
            if (Array.isArray(error.body)) {
                return error.body.map(e => e.message).join(', ');
            } else if (error.body.message) {
                return error.body.message;
            }
        }
        return error.message || 'Unknown error';
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    get hasEligibility() {
        return this.eligibility != null;
    }

    get levelInfo() {
        if (!this.eligibility) return '';
        return `${this.eligibility.Level__c || ''} - ${this.eligibility.Grade__c || ''}`;
    }

    get designationInfo() {
        return this.eligibility ? this.eligibility.Designation__c || 'N/A' : 'N/A';
    }

    // Lodging
    get lodgingTier1() {
        return this.eligibility ? this.eligibility.Lodging_Tier1__c || 0 : 0;
    }

    get lodgingTier2() {
        return this.eligibility ? this.eligibility.Lodging_Tier2__c || 0 : 0;
    }

    // Fooding
    get foodingTier1() {
        return this.eligibility ? this.eligibility.Fooding_Tier1__c || 0 : 0;
    }

    get foodingTier2() {
        return this.eligibility ? this.eligibility.Fooding_Tier2__c || 0 : 0;
    }

    // Air Travel
    get airBusiness() {
        return this.eligibility && this.eligibility.Air_Business__c;
    }

    get airEconomy() {
        return this.eligibility && this.eligibility.Air_Economy__c;
    }

    get airEligibility() {
        if (this.airBusiness) return 'Business Class';
        if (this.airEconomy) return 'Economy Class';
        return 'Not Allowed';
    }

    get airClass() {
        if (this.airBusiness) return 'slds-text-color_success';
        if (this.airEconomy) return 'slds-text-color_default';
        return 'slds-text-color_error';
    }

    // Train Travel
    get train1AC() {
        return this.eligibility && this.eligibility.Train_1AC__c;
    }

    get train2AC() {
        return this.eligibility && this.eligibility.Train_2AC__c;
    }

    get train3AC() {
        return this.eligibility && this.eligibility.Train_3AC__c;
    }

    get trainSleeper() {
        return this.eligibility && this.eligibility.Train_Sleeper__c;
    }

    get trainEligibility() {
        const classes = [];
        if (this.train1AC) classes.push('1AC');
        if (this.train2AC) classes.push('2AC');
        if (this.train3AC) classes.push('3AC');
        if (this.trainSleeper) classes.push('Sleeper');
        return classes.length > 0 ? classes.join(', ') : 'Not Allowed';
    }

    // Own Vehicle
    get ownVehicleRate() {
        return this.eligibility ? this.eligibility.Own_Vehicle_Rate__c || 0 : 0;
    }

    get hasOwnVehicle() {
        return this.ownVehicleRate > 0;
    }
}
import { LightningElement, api, wire, track } from 'lwc';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import PROD_CAT_FIELD from '@salesforce/schema/Lead.Product_Category__c';
import UOM_FIELD from '@salesforce/schema/Lead.UOM__c';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';

export default class DependentPicklistRow extends LightningElement {

    @api
    get deptValue() {
        return this._deptValue;
    }
    set deptValue(value) {
        this._deptValue = value;
        console.log('deptValue setter fired — value:', value);
        this.filterProdCatOptions();
    }

    @api selectedProdCat;
    @api selectedUOM;
    @api quantity;

    @track prodCatOptions = [];
    @track uomOptions = [];
    @track recordTypeId;

    _deptValue;
    _allProdCatData;

    @wire(getObjectInfo, { objectApiName: 'Lead' })
    objectInfo({ data, error }) {
        if (data) {
            this.recordTypeId = data.defaultRecordTypeId;
            console.log('recordTypeId:', this.recordTypeId);
        }
        if (error) {
            console.log('objectInfo error:', JSON.stringify(error));
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$recordTypeId',
        fieldApiName: PROD_CAT_FIELD
    })
    wiredProdCatValues({ data, error }) {
        if (data) {
            this._allProdCatData = data;
            console.log('prodCat wire fired');
            this.filterProdCatOptions();
        }
        if (error) {
            console.log('prodCat wire error:', JSON.stringify(error));
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$recordTypeId',
        fieldApiName: UOM_FIELD
    })
    wiredUOMValues({ data, error }) {
        if (data) {
            this.uomOptions = data.values.map(opt => ({
                label: opt.label,
                value: opt.value
            }));
            console.log('uomOptions:', JSON.stringify(this.uomOptions));
        }
        if (error) {
            console.log('UOM wire error:', JSON.stringify(error));
        }
    }

    filterProdCatOptions() {
        if (this._allProdCatData && this._deptValue) {
            const controllerMap = this._allProdCatData.controllerValues;
            const controllerIndex = controllerMap[this._deptValue];

            console.log('controllerIndex:', controllerIndex);

            if (controllerIndex === undefined) {
                console.log('MISMATCH — available keys:', Object.keys(controllerMap));
                return;
            }

            this.prodCatOptions = this._allProdCatData.values
                .filter(opt => opt.validFor.includes(controllerIndex))
                .map(opt => ({ label: opt.label, value: opt.value }));

            console.log('prodCatOptions:', JSON.stringify(this.prodCatOptions));
        } else {
            console.log('filterProdCatOptions guard failed — deptValue:', this._deptValue, '| allProdCatData:', !!this._allProdCatData);
        }
    }

    handleProdCatChange(event) {
        this.selectedProdCat = event.detail.value;
        this.dispatchEvent(
            new FlowAttributeChangeEvent('selectedProdCat', this.selectedProdCat)
        );
    }

    handleUOMChange(event) {
        this.selectedUOM = event.detail.value;
        this.dispatchEvent(
            new FlowAttributeChangeEvent('selectedUOM', this.selectedUOM)
        );
    }

    handleQuantityChange(event) {
        const rawValue = event.detail.value;
        const numericValue = rawValue !== '' && rawValue !== null ? String(parseFloat(rawValue)) : '';
        this.quantity = numericValue;
        this.dispatchEvent(
            new FlowAttributeChangeEvent('quantity', this.quantity)
        );
    }
}
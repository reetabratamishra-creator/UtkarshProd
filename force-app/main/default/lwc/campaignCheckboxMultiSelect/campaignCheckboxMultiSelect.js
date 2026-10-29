import { LightningElement, api } from 'lwc';

export default class CampaignCheckboxMultiSelect extends LightningElement {
    @api label = '';
    @api options = [];

    _value = [];
    filterText = '';

    @api
    get value() {
        return this._value;
    }

    set value(next) {
        this._value = Array.isArray(next) ? [...next] : [];
    }

    get selectedCount() {
        return (this._value || []).length;
    }

    get hasSelection() {
        return this.selectedCount > 0;
    }

    get selectedChips() {
        const labels = new Map(
            (this.options || []).map((option) => [option.value, option.label])
        );
        return (this._value || []).map((value) => ({
            value,
            label: labels.get(value) || value
        }));
    }

    get optionRows() {
        const selected = new Set(this._value || []);
        const term = (this.filterText || '').trim().toLowerCase();
        return (this.options || [])
            .filter((option) => {
                if (!term) {
                    return true;
                }
                return (option.label || '').toLowerCase().includes(term);
            })
            .map((option) => ({
                label: option.label,
                value: option.value,
                checked: selected.has(option.value)
            }));
    }

    get hasVisibleOptions() {
        return this.optionRows.length > 0;
    }

    get searchPlaceholder() {
        const noun = (this.label || 'options').toLowerCase();
        return `Type to filter ${noun}`;
    }

    get matchSummary() {
        const total = (this.options || []).length;
        const noun = (this.label || 'options').toLowerCase();
        if (!(this.filterText || '').trim()) {
            return `${total} ${noun}`;
        }
        const shown = this.optionRows.length;
        const matchLabel = shown === 1 ? 'match' : 'matches';
        return `${shown} ${matchLabel} · type to filter ${total} ${noun}`;
    }

    handleFilterTextChange(event) {
        this.filterText = event.target.value || '';
    }

    handleCheckboxChange(event) {
        const optionValue = event.target.value;
        const checked = event.target.checked;
        let next = [...(this._value || [])];

        if (checked && !next.includes(optionValue)) {
            next.push(optionValue);
        } else if (!checked) {
            next = next.filter((item) => item !== optionValue);
        }

        this.publish(next);
    }

    handleRemoveChip(event) {
        const optionValue = event.currentTarget.dataset.value;
        this.publish((this._value || []).filter((item) => item !== optionValue));
    }

    handleSelectAll() {
        const next = new Set(this._value || []);
        this.optionRows.forEach((option) => next.add(option.value));
        this.publish([...next]);
    }

    handleClear() {
        this.publish([]);
    }

    publish(next) {
        this._value = next;
        this.dispatchEvent(
            new CustomEvent('change', {
                detail: { value: next },
                bubbles: true,
                composed: true
            })
        );
    }
}
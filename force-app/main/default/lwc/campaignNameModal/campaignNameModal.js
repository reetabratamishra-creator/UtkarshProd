import { LightningElement, api } from 'lwc';

export default class CampaignNameModal extends LightningElement {
    @api isOpen = false;
    @api isSending = false;
    @api sendButtonLabel = 'Send';
    @api collectSchedule = false;

    campaignName = '';
    scheduleDate = '';
    scheduleTime = '';
    step = 'name';

    get isNameStep() {
        return this.step !== 'schedule';
    }

    get modalTitle() {
        return this.isNameStep ? 'Campaign Name' : 'Schedule';
    }

    get modalSubtitle() {
        return this.isNameStep
            ? 'Enter a campaign name. A Campaign record and Custom Campaign Member records will be created for successfully sent recipients.'
            : 'Choose the date and time in Indian Standard Time.';
    }

    get primaryLabel() {
        if (this.isNameStep && this.collectSchedule) {
            return 'Next';
        }
        return this.sendButtonLabel;
    }

    get primaryIcon() {
        return this.isNameStep && this.collectSchedule ? 'utility:forward' : 'utility:send';
    }

    get isConfirmDisabled() {
        if (this.isSending) {
            return true;
        }
        if (this.isNameStep) {
            return !(this.campaignName || '').trim();
        }
        return !this.scheduleDate || !this.scheduleTime;
    }

    handleCampaignNameChange(event) {
        this.campaignName = event.target.value;
    }

    handleScheduleDateChange(event) {
        this.scheduleDate = event.target.value;
    }

    handleScheduleTimeChange(event) {
        this.scheduleTime = event.target.value;
    }

    handleCancel() {
        if (!this.isSending) {
            this.reset();
            this.dispatchEvent(new CustomEvent('cancel'));
        }
    }

    handleBack() {
        if (!this.isSending) {
            this.step = 'name';
        }
    }

    handleConfirm() {
        if (this.isSending || this.isConfirmDisabled) {
            return;
        }

        const trimmedName = (this.campaignName || '').trim();
        if (this.isNameStep && this.collectSchedule) {
            this.step = 'schedule';
            return;
        }

        this.dispatchEvent(
            new CustomEvent('confirm', {
                detail: {
                    campaignName: trimmedName,
                    scheduledDateTime: this.collectSchedule
                        ? this.formatScheduledDateTime()
                        : null
                }
            })
        );
    }

    formatScheduledDateTime() {
        let timeValue = (this.scheduleTime || '').trim().replace(/Z$/i, '');
        timeValue = timeValue.split('.')[0];
        const parts = timeValue.split(':');
        const hours = Number(parts[0] || 0);
        const minutes = Number(parts[1] || 0);
        const seconds = Number(parts[2] || 0);
        const dateParts = (this.scheduleDate || '').split('-').map((part) => Number(part));
        const utcMillis =
            Date.UTC(dateParts[0], dateParts[1] - 1, dateParts[2], hours, minutes, seconds) -
            (5 * 60 + 30) * 60 * 1000;
        const utc = new Date(utcMillis);
        const pad = (value) => String(value).padStart(2, '0');
        return `${utc.getUTCFullYear()}-${pad(utc.getUTCMonth() + 1)}-${pad(utc.getUTCDate())}T${pad(utc.getUTCHours())}:${pad(utc.getUTCMinutes())}:${pad(utc.getUTCSeconds())}Z`;
    }

    stopModalClick(event) {
        event.stopPropagation();
    }

    @api
    reset() {
        this.campaignName = '';
        this.scheduleDate = '';
        this.scheduleTime = '';
        this.step = 'name';
    }
}
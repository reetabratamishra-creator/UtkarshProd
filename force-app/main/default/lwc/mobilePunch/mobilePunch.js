// import { LightningElement } from 'lwc';

// export default class MobilePunch extends LightningElement {}


import { LightningElement, api, track } from 'lwc';
import getCurrentState from '@salesforce/apex/PunchController.getCurrentState';
import punchNow from '@salesforce/apex/PunchController.punchNow';
import saveSelfieForAccount from '@salesforce/apex/PunchController.saveSelfieForAccount'; // ADDED
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class MobilePunch extends LightningElement {
    _recordId;
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (this._recordId) {
            this.loadState();
        }
    }

    @track stateLoaded = false;
    @track loading = true;
    @track isPunching = false;
    @track error;

    @track employeeName;
    @track currentStatus; // IN / OUT
    @track lastPunchTime;
    @track lastBattery;


    previewImage;
    capturedFile;
    fileName;
    fileExtension;
    extensionOnly;

    @track isViewMode = true;

    @track selfiePreview = '';
    @track selfieUrl = '';

    @track videoInitialized = false;
    @track isSaving = false; 


    renderedCallback() {

        if (!this.videoInitialized) {
            const video = this.template.querySelector('video');
        console.log('Initializing camera...  ', video);
            this.initCamera();
            this.videoInitialized = true;
            
        }

    }




    loadState() {
        this.loading = true;
        getCurrentState({ employeeId: this.recordId })
            .then((data) => {
                console.log('Imperative data:', data);
                if (data) {
                    this.error = undefined;
                    this.loading = false;
                    this.stateLoaded = true;
                    this.employeeName = data.employeeName;
                    this.currentStatus = data.currentStatus;
                    this.lastPunchTime = data.lastPunchTime;
                    this.lastBattery = data.lastBattery;
                }
            })
            .catch((error) => {
                // eslint-disable-next-line no-console
                console.error(error);
                this.error = 'Failed to load punch state';
                this.loading = false;
                this.stateLoaded = false;
            });
    }

    // --- computed labels ---
    get isPunchedIn() {
        return this.currentStatus === 'IN';
    }

    get buttonLabel() {
        return this.isPunchedIn ? 'Punch Out' : 'Punch In';
    }

    get statusLabel() {
        return this.isPunchedIn ? 'PUNCHED IN' : 'PUNCHED OUT';
    }

    get statusBadgeClass() {
        return 'mp-status ' + (this.isPunchedIn ? 'mp-status-in' : 'mp-status-out');
    }

    get lastPunchDisplay() {
        if (!this.lastPunchTime) return '';
        try {
            const d = new Date(this.lastPunchTime);
            return d.toLocaleString('en-IN', {
                dateStyle: 'medium',
                timeStyle: 'short'
            });
        } catch (e) {
            return this.lastPunchTime;
        }
    }

    get lastBatteryDisplay() {
        return this.lastBattery != null ? Math.round(this.lastBattery) : '';
    }

    // --- main punch handler ---
    handlePunch() {
        if (!navigator.geolocation) {
            this.showToast('Location not supported', 'This device does not support geolocation.', 'error');
            return;
        }

        this.isPunching = true;
        this.error = undefined;

        console.log('handlePunch: getting location...');


        navigator.geolocation.getCurrentPosition(
            (pos) => {
                const lat = pos.coords.latitude;
                const lng = pos.coords.longitude;

                this.fetchBatteryLevel()
                    .then((battery) => { 
                        // this.callPunch(lat, lng, battery)
                        console.log('Location obtained:', lat, lng, 'Battery:', battery);
                        // this.convertFileToBase64(this.selfiePreview)
                        // .then(base64 => {
                            console.log('Base64 String - ', this.fileName, this.selfiePreview);
                            
//base64
                            this.callPunch(lat, lng, battery, this.selfiePreview, this.fileName? this.fileName : 'selfie.jpg');
                        // });
                    })
                    .catch(() => this.callPunch(lat, lng, null));
            },
            (err) => {
                // eslint-disable-next-line no-console
                console.error(err);
                this.isPunching = false;
                this.showToast('Location error', 'Unable to get device location. Please allow location access.', 'error');
            },
            {
                enableHighAccuracy: true,
                timeout: 15000,
                maximumAge: 0
            }
        );


    }

    // Try to get battery level; fallback to null if not supported
    fetchBatteryLevel() {
        if (navigator.getBattery) {
            return navigator.getBattery().then((batt) => Math.round(batt.level * 100));
        }
        return Promise.resolve(null);
    }

    // Call Apex with location + battery
    callPunch(lat, lng, battery, base64, fileName) {




        punchNow({
            employeeId: this.recordId,
            latitude: lat,
            longitude: lng,
            battery: battery,
            odometerImageBase64: base64,
            fileName: fileName
        })
            .then((state) => {
                this.currentStatus = state.currentStatus;
                this.lastPunchTime = state.lastPunchTime;
                this.lastBattery = state.lastBattery;
                this.isPunching = false;
                this.showToast('Success', `You have successfully ${this.isPunchedIn ? 'punched in' : 'punched out'}.`, 'success');
            })
            .catch((error) => {
                // eslint-disable-next-line no-console
                console.error(error);
                this.error = 'Error while punching. Try again.';
                this.isPunching = false;
                this.showToast('Error', 'Punch failed. Please try again.', 'error');
            });
    }

    

    handleImageCapture(event) {
        const file = event.target.files[0];
        this.capturedFile = file;

         // File name
        this.fileName = file.name;

        // File format / extension
        this.fileExtension = file.type; // e.g. "image/jpeg"
        // OR
        this.extensionOnly = file.name.split('.').pop(); // "jpg" or "png"

        const reader = new FileReader();
        reader.onload = () => {
            this.previewImage = reader.result; // base64 preview
        };
        reader.readAsDataURL(file);
    }

    convertFileToBase64(file) {
    return new Promise((resolve, reject) => {
        const reader = new FileReader();

        reader.onload = () => {
            let base64 = reader.result.split(',')[1];
            resolve(base64);
        };
        reader.onerror = reject;

        reader.readAsDataURL(file);
    });
}



    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }



    initCamera() {
        const video = this.template.querySelector('video');
        const canvas = this.template.querySelector('canvas');
        console.log('Initializing camera...  ', video, canvas);
        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            alert('Camera not supported on this device.');
            return;
        }

        const constraints = {
            video: {
                facingMode: { ideal: 'environment' } 
            },
            audio: false
        };
        // { video: true }

        navigator.mediaDevices.getUserMedia(constraints)
            .then(stream => {
                console.log('Camera stream obtained::: ', stream);
                console.log('Video element::: ', video);
                video.setAttribute('playsinline', 'true');
                video.setAttribute('webkit-playsinline', 'true');
                video.setAttribute('muted', 'true');
                video.playsInline = true;
                video.muted = true;
                video.srcObject = stream;
                video.play();
            })
            .catch(err => {
                console.error('Camera error:', err, err.name, err.message);
                alert('Unable to access camera. Please allow camera permission.');
            });
    }

    capturePhoto() {
        const video = this.template.querySelector('video');
        const canvas = this.template.querySelector('canvas');
        if (!video || !canvas) {
            alert('Camera not ready.');
            return;
        }
        canvas.width = video.videoWidth;
        canvas.height = video.videoHeight;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
        this.selfiePreview = canvas.toDataURL('image/jpeg');
    }



    saveSelfie() {
        if (!this.selfiePreview) {
            alert('Please capture a selfie first.');
            return;
        }

        if (!navigator.geolocation) {
            alert('Geolocation not supported on this device.');
            return;
        }
    this.isSaving = true; //


        navigator.geolocation.getCurrentPosition(
            position => {
                const lat = parseFloat(position.coords.latitude);
                const lon = parseFloat(position.coords.longitude);

                saveSelfieForAccount({
                    accountId: this.recordId,
                    base64Photo: this.selfiePreview,
                    userLat: lat,
                    userLon: lon
                })
                .then(url => {
                    alert('✅ Selfie saved successfully!');
                    this.selfieUrl = url;
                    this.selfiePreview = '';
                    this.isSaving= false;
                })
                .catch(error => {
                    console.error('Error saving selfie:', error);
                    let message = 'Unknown error';
                    if (error?.body?.message) message = error.body.message;
                    else if (error?.message) message = error.message;
                    alert('❌ GeoLocation should be within 50 meters you are outside the allowd location');
                    this.isSaving = false;
                });
            },
            error => {
                console.error('GPS error:', error);
                alert('⚠️ Unable to get location. Enable GPS and allow location access.');
                this.isSaving = false;
            },
            { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 } // Increased timeout
        );
    }



}
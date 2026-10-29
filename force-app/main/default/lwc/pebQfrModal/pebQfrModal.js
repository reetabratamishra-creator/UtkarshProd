import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PebQfrModule extends LightningElement {
    @api isReadOnly = false;
    @api quoteId; 
    @track specialNotes = ''; 

    _savedData = [];
    _isInitialized = false;

    @api
    set savedData(value) {

        this._savedData = value ? JSON.parse(JSON.stringify(value)) : [];

        // Only hydrate if the component has finished loading
        if (this._isInitialized) {
            this.hydrateData();
        }
    }
    get savedData() {
        return this._savedData;
    }

    connectedCallback() {
        this._isInitialized = true;
        this.hydrateData();
    }

    @track tableData = [
        { id: '1', slNo: '1', description: 'LOCATION OF BUILDING', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        { id: '2', slNo: '2', description: 'UTILITY OF THE BUILDING', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        { id: '3', slNo: '3', description: 'DESIGN CODE', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        { id: '4', slNo: '4', description: 'DESIGN LIVE LOAD (ON ROOF)', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        { id: '5', slNo: '5', description: 'WIND SPEED', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        { id: '6', slNo: '6', description: 'SESIMIC ZONE', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        { id: '7', slNo: '7', description: 'COLLATERAL LOAD', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        
        { id: '8', slNo: '8', description: 'WELDING', specification: '', requirement: '', isPicklist: true, isStatic: false, isInput: false, options: [{ label: 'Single Side', value: 'single_side' }, { label: 'Double Side', value: 'double_side' }] },
        
        { id: '9', slNo: '9', description: 'PAINT SPECIFICATION', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'Standard cleaning + one coat of Epoxy Primer+ 2 coat Epoxy Paint at plant + Touch up at site.' },
        
        { id: '10', slNo: '10', description: 'LENGTH OF BUILDING', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        { id: '11', slNo: '11', description: 'WIDTH OF BUILDING', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        { id: '12', slNo: '12', description: 'SLOPE OF THE BUILDING', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        
        { id: '13_1', slNo: '13', description: 'HEIGHT OF BUILDING', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'CLEAR HEIGHT (side wall Height)' },
        { id: '13_2', slNo: '', description: '', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'OVERALL HEIGHT (SIDW WALL SIDE)' },
        { id: '13_3', slNo: '', description: '', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'RIDGE HEIGHT (TOP OF THE BUILDING)' },

        { 
            id: '14', 
            slNo: '14', 
            description: 'FRAME TYPE', 
            specification: '', 
            requirement: '', 
            isPicklist: true, 
            isStatic: false, 
            isInput: false, 
            options: [
                { label: 'RIGID FRAME', value: 'RIGID FRAME' },
                { label: 'BC-I / BC-II / BC-III', value: 'BC-I / BC-II / BC-III' },
                { label: 'MONO SLOPE', value: 'MONO SLOPE' },
                { label: 'MULTI SPAN', value: 'MULTI SPAN' }
            ] 
        },

        { id: '15', slNo: '15', description: 'BRICK WORK', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        { id: '16', slNo: '16', description: 'ROOF SHEET', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        { id: '17', slNo: '17', description: 'WALL SHEET', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        
        { id: '18_1', slNo: '18', description: 'FFL Level', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        { id: '18_2', slNo: '18', description: 'FASCIA', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        
        { id: '19', slNo: '19', description: 'FRAME OPENING NOS.', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        { id: '20', slNo: '20', description: 'CANOPY', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        
        { id: '21_1', slNo: '21', description: 'MINIMUM COLUMN SPACING -Sidewall (IF ANY)', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'C/C' },
        { id: '21_2', slNo: '', description: 'End wall -Bay Spacing.', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'C/C' },

        { id: '22', slNo: '22', description: 'CRANE TYPE', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        
        { id: '23_1', slNo: '23', description: 'CRANE CAPACITY', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'standard crane Data consider.' },
        { id: '23_2', slNo: '', description: '', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'B.O.B Height' },

        { id: '24', slNo: '24', description: 'MEZZANINE SIZE', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        
        { id: '25_1', slNo: '25', description: 'MEZZANINE TOP', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'DECK SHEET WITH CONCRETE' },
        { id: '25_2', slNo: '', description: '', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'CHEQUERED PLATE' },

        { id: '26', slNo: '26', description: 'Mezzanien Height (FFL to 1st Floor.)', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        { id: '27', slNo: '27', description: 'Mezzanien Height (1st Floor to 2nd Floor.)', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        { id: '27_1', slNo: '', description: '2nd Floor to bottom of Beam', specification: '', requirement: '', isPicklist: false, isStatic: false, isInput: true },
        
        { id: '28', slNo: '28', description: 'MEZZANINE LOAD (IF ANY)', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'Live Load' },

        { id: '29_1', slNo: '29', description: 'ACCESSORIES OF BUILDING', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'INSULATION' },
        { id: '29_2', slNo: '', description: '', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'TURBOVENT (600 mm dia)' },
        { id: '29_3', slNo: '', description: '', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'POLYCARBONATE (1.1 m x 3.305 m x 2 mm)' },
        { id: '29_4', slNo: '', description: '', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'ROOF MONITOR (1 m x 1.5 m)' },
        { id: '29_5', slNo: '', description: '', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'RIDGEVENT (600 mm Throat x 3 m length)' },
        { id: '29_6', slNo: '', description: '', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'CAGE LADDER' },
        { id: '29_7', slNo: '', description: '', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'LIFE LINE POST' },
        { id: '29_8', slNo: '', description: '', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'PIPE RAKE' },
        { id: '29_9', slNo: '', description: '', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'S-type Louver (1 m x 1 m) (At Grid Line)' },
        { id: '29_10', slNo: '', description: '', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'INDUSTRIAL LOUVER' },
        { id: '29_11', slNo: '', description: '', specification: '', requirement: '', isPicklist: false, isStatic: true, isInput: false, staticText: 'PARTITION WALL' }
    ];

    hydrateData() {
        if (this._savedData && this._savedData.length > 0) {
            this.tableData = this.tableData.map(row => {
                const savedRow = this._savedData.find(sr => String(sr.id) === String(row.id));
                if (savedRow) {
                    return { 
                        ...row, 
                        // Safety check to ensure we map back the saved values correctly
                        specification: savedRow.specification !== undefined ? savedRow.specification : row.specification, 
                        requirement: savedRow.requirement !== undefined ? savedRow.requirement : row.requirement 
                    };
                }
                return row;
            });
            
            const notesRow = this._savedData.find(sr => sr.id === 'special_notes');
            if (notesRow) {
                this.specialNotes = notesRow.specialNotes || '';
            }
        }
    }

    handleInputChange(event) {
        if (this.isReadOnly) return;
        
        const field = event.target.dataset.field;
        const id = event.target.dataset.id;
        const value = event.target.value;

        this.tableData = this.tableData.map(row => {
            if (row.id === id) {
                return { ...row, [field]: value };
            }
            return row;
        });
    }

    handleSpecialNotesChange(event) {
        if (this.isReadOnly) return;
        this.specialNotes = event.target.value;
    }

    handleSave() {
        const cleanData = this.tableData.map(row => {
            let finalSpec = row.specification;
            if (row.isStatic) {
                finalSpec = row.staticText;
            }

            const { isPicklist, isStatic, isInput, options, staticText, ...rest } = row;
            rest.specification = finalSpec;
            return rest;
        });

        cleanData.push({ id: 'special_notes', specialNotes: this.specialNotes });

        const saveEvent = new CustomEvent('saveqfr', {
            detail: cleanData
        });
        this.dispatchEvent(saveEvent);
    }

    // 👉 Secure Browser Print-to-PDF Generator (LockerService Compliant)
    // 👉 Seamless Native PDF Generator (Auto-Saves and Opens PDF)
    // 👉 Synchronous Native PDF Generator (Saves first, then opens PDF)
    // 👉 Direct Data-Passing PDF Generator
    generatePDF() {
        // 1. Collect live data straight from the screen inputs
        const cleanData = this.tableData.map(row => {
            let finalSpec = row.specification;
            if (row.isStatic) {
                finalSpec = row.staticText;
            }
            const { isPicklist, isStatic, isInput, options, staticText, ...rest } = row;
            rest.specification = finalSpec;
            return rest;
        });
        cleanData.push({ id: 'special_notes', specialNotes: this.specialNotes });

        // 2. Convert to JSON and encode for a URL string
        const jsonData = encodeURIComponent(JSON.stringify(cleanData));

        // 3. Build the URL. If a quoteId exists, pass it along with the data payload.
        let pdfUrl = `/apex/GenerateQfrDoc?data=${jsonData}`;
        if (this.quoteId) {
            pdfUrl += `&id=${this.quoteId}`;
        }

        // 4. Open the PDF instantly with all live values populated
        window.open(pdfUrl, '_blank');
    }
}
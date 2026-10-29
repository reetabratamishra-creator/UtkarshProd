import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import SHEETJS from '@salesforce/resourceUrl/sheetjs';
import LightningAlert from 'lightning/alert';
import saveToMetadata from '@salesforce/apex/QuoteRateCardController.saveToMetadata';
import getExistingRates from '@salesforce/apex/QuoteRateCardController.getExistingRates';
import getRateCardJson from '@salesforce/apex/CreateQuoteController.getRateCardJson';
import savePriceCalculatorMetadata from '@salesforce/apex/QuoteRateCardController.savePriceCalculatorMetadata';
import getHighMastAmounts from '@salesforce/apex/QuoteRateCardController.getHighMastAmounts';
import saveHighMastAmounts from '@salesforce/apex/QuoteRateCardController.saveHighMastAmounts';


export default class QuoteRateCard extends LightningElement {
    @api recordId;
    valueA = '';
    valueB = '';
    
    isModalOpen = false;
    showDataGrid = false;
    isSaving = false;
    sheetJsLoaded = false;

    @track optionsB = [];
    @track verificationResults = [];
    
    // Grid State
    @track currentColumns = [];
    @track gridData = [];
    @track fullExistingDatabaseConfig = [];

    columns = [
        { label: 'Row', fieldName: 'id', initialWidth: 80 },
        { label: 'Status', fieldName: 'status', initialWidth: 120 },
        { label: 'Message', fieldName: 'message', type: 'text' }
    ];

   // ==========================================
    // COMPLETE PICKLIST DATA
    // ==========================================
    picklistData = {
        'Crash Barrier - Department': ['MBCB type - Conventional Type','MBCB type - Railway','MBCB type - Crash Tested','MBCB type - Non-Spacer Design','MBCB type - Noise Barrier'], // 👉 ADDED NOISE BARRIER
        'HDPE Pipe - Department': ['Standard - IS 4984', 'Standard - PLB Duct', 'Standard - Pipe & Duct', 'Standard - MDPE Pipe'],
        'High Mast - Department': ['Standard Mast - Transmission Pole','Standard Mast - Lighting Mast','Customized Mast - STADIUM MAST','Customized Mast - FLAG MAST', 'Octagonal Pole - Standard Pole', 'Octagonal Pole - Customized Pole', 'Octagonal Pole - Mid Hinge Pole', 'Lighting Cum Lighting Mast','Signage Mast', 'Latching Mast', 'Custom Lighting Mast'],
        'Solar Structure - Department': ['Unit of Measurement - Pcs','Unit of Measurement - Weight', 'Global Zinc Rate'],
        'Steel Pipes - Department': ['Domestic', 'Export', 'Core Pipes'], // 👉 ADDED Core Pipes
        'Steel Tubular Pole - Department': ['Type of Pole - Standard','Type of Pole - Customized'],
        'Transmission Tower - Department': ['Type of Product - Tower','Type of Product - Substation','Nuts & Bolts Details'],
        'Telecom Tower - Department': ['Generalized value']
    };

    // ==========================================
    // COMPLETE VALIDATION SCHEMAS
    // ==========================================
    validationSchemas = {
    'Steel Pipes - Department|Domestic': ['Item', 'Rate'],
    'Steel Pipes - Department|Export': ['Item', 'Rate'],
    'Steel Pipes - Department|Core Pipes': ['Item', 'Rate'], // 👉 ADDED Core Pipes Schema
        'Crash Barrier - Department|MBCB type - Conventional Type': ['Item','Rate'],
        'Crash Barrier - Department|MBCB type - Noise Barrier': ['Item','Rate'], // 👉 ADDED NOISE BARRIER SCHEMA
        'Crash Barrier - Department|MBCB type - Railway': ['Item','Rate'],
        'Crash Barrier - Department|MBCB type - Crash Tested': ['Item','Rate'],
        'Crash Barrier - Department|MBCB type - Non-Spacer Design': ['Item','Rate'],
        'HDPE Pipe - Department|Standard - IS 4984': ['Item','Value'],
        'HDPE Pipe - Department|Standard - PLB Duct': ['Item','Value'],
        'HDPE Pipe - Department|Standard - Pipe & Duct': ['Item','Value'],
        'HDPE Pipe - Department|Standard - MDPE Pipe': ['Item','Value'],
        'High Mast - Department|Standard Mast - Transmission Pole': ['Item','Value'],
        'High Mast - Department|Standard Mast - Lighting Mast': ['Item','Value'],
        'High Mast - Department|Customized Mast - STADIUM MAST': ['Item','Value'],
        'High Mast - Department|Customized Mast - FLAG MAST': ['Item','Value'],
        'High Mast - Department|Octagonal Pole - Standard Pole': ['Item','Value'],
        'High Mast - Department|Octagonal Pole - Customized Pole': ['Item','Value'],
        'High Mast - Department|Octagonal Pole - Mid Hinge Pole': ['Item','Value'],
        'High Mast - Department|Lighting Cum Lighting Mast': ['Item','Value'],
        'High Mast - Department|Signage Mast': ['Item','Value'],
        'High Mast - Department|Latching Mast': ['Item','Value'],
        'High Mast - Department|Custom Lighting Mast': ['Item','Value'],
        'Solar Structure - Department|Unit of Measurement - Pcs': ['Item', 'Rate'],
        'Solar Structure - Department|Unit of Measurement - Weight': ['Item', 'Rate'],
        'Solar Structure - Department|Global Zinc Rate': ['Item', 'Rate'], 
        'Transmission Tower - Department|Type of Product - Tower': ['Item','Value'],
        'Transmission Tower - Department|Type of Product - Substation': ['Item','Value'],
        'Transmission Tower - Department|Nuts & Bolts Details': ['Item','Value'],
        'Transmission Tower - Department|Price Variation Calculation': ['Base Month','Current Month Price','Steel Index','Final Calculated Rate'],
        'Steel Tubular Pole - Department|Type of Pole - Standard': ['Item', 'Rate'],
        'Steel Tubular Pole - Department|Type of Pole - Customized': ['Item', 'Rate'] ,
        'Telecom Tower - Department|Generalized value': ['Item', 'Rate'],
        'Steel Pipes - Department|Domestic': ['Item','Rate'],
        'Steel Pipes - Department|Export': ['Item','Rate']
    };
    mdpePipe ={
        'Pipe Base Rate' : 'mdpe_pipe_b_rate',
        'Pipe GST %' : 'mdpe_pipe_gst'
    };

    reversemdpePipe ={
        'mdpe_pipe_b_rate' : 'Pipe Base Rate',
        'mdpe_pipe_gst' : 'Pipe GST %'
    };

    hdpepipeAndDuct = {
        'Pipe Base Rate' : 'pipe_b_rate',
        'Duct Base Rate' : 'duct_b_rate',
        'Pipe GST %' : 'pipe_gst',
        'Duct GST %' : 'duct_gst'
    };

    reversehdpepipeAndDuct = {
        'pipe_b_rate' : 'Pipe Base Rate',
        'duct_b_rate' : 'Duct Base Rate',
        'pipe_gst' : 'Pipe GST %',
        'duct_gst' : 'Duct GST %'
    };

    hdpeIs4984 ={
        'Pipe Base Rate':'is_pipe_b_rate',
        'Pipe GST %':'is_pipe_gst'
    };

    reversehdpeIs4984 ={
        'is_pipe_b_rate':'Pipe Base Rate',
        'is_pipe_gst':'Pipe GST %'
    };

    hdpePlbDuct = {
        'Duct Base Rate':'plb_duct_b_rate',
        'Duct GST %':'plb_duct_gst',
    };

    reversehdpePlbDuct = {
        'plb_duct_b_rate':'Duct Base Rate',
        'plb_duct_gst':'Duct GST %'
    };
    crashBarrierConvMap = {
        'Base Rate': 'b_rate',
        'W-Beam SSSB': 'w_SSSB',
        'W-Beam SSDB': 'w_SSDB',
        'W-Beam DSSB': 'w_DSSB',
        'W-Beam DSDB': 'w_DSDB',
        'Thrie-Beam SSSB': 't_SSSB',
        'Thrie-Beam SSDB': 't_SSDB',
        'Thrie-Beam DSSB': 't_DSSB',
        'Thrie-Beam DSDB': 't_DSDB',
        'Regular (Zinc Coating)': 'zinc_reg',
        'Medium 55 micron (Zinc Coating)': 'zinc_medium_55_delta',
        'Average 77 micron (Zinc Coating)': 'zinc_avg_77',
        'Minimum 77 micron (Zinc Coating)': 'zinc_min_77',
        'Consumption Zinc Regular': 'con_zinc_reg',
        'Consumption Zinc Medium 55 micron': 'con_zinc_medium_55',
        'Consumption Zinc Average 77 micron': 'con_zinc_avg_77',
        'Consumption Zinc Minimum 77 micron': 'con_zinc_min_77'
    };

        highMastRecordMap = {
        'Standard Mast - Transmission Pole': 'Transmission_Pole_Price_Details',
        'Standard Mast - Lighting Mast'    : 'Lighting_Mast_Price',
        'Customized Mast - STADIUM MAST'   : 'STADIUM_MAST_Price',
        'Customized Mast - FLAG MAST'      : 'FLAG_MAST_Price',
        'Octagonal Pole - Standard Pole'   : 'Lightning_Pole_Price',   // ⚠️ verify
        'Octagonal Pole - Customized Pole' : 'Custom_Lightning_Pole',         // ⚠️ verify — clashes
        'Octagonal Pole - Mid Hinge Pole'  : 'Mid_Hinge_Pole',
        'Lighting Cum Lighting Mast'       : 'LCLM_Price', // ⚠️ verify
        'Signage Mast'                     : 'Signage_Mast_Price',
        'Latching Mast'                    : 'Latching_Mast_Price',
        'Custom Lighting Mast'             : 'Custom_Lighting_Mast'
    };

    reverseHighMastRecordMap = {
        'Transmission_Pole_Price_Details': 'Standard Mast - Transmission Pole',
        'Lighting_Mast_Price': 'Standard Mast - Lighting Mast',
        'STADIUM_MAST_Price': 'Customized Mast - STADIUM MAST',
        'FLAG_MAST_Price': 'Customized Mast - FLAG MAST',
        'Lightning_Pole_Price': 'Octagonal Pole - Standard Pole',
        'Custom_Lightning_Pole': 'Octagonal Pole - Customized Pole',
        'Mid_Hinge_Pole': 'Octagonal Pole - Mid Hinge Pole',
        'LCLM_Price': 'Lighting Cum Lighting Mast',
        'Signage_Mast_Price': 'Signage Mast',
        'Latching_Mast_Price': 'Latching Mast',
        'Custom_Lighting_Mast': 'Custom Lighting Mast'
    };

    reverseCrashBarrierConvMap = {
        'b_rate': 'Base Rate',
        'w_SSSB': 'W-Beam SSSB',
        'w_SSDB': 'W-Beam SSDB',
        'w_DSSB': 'W-Beam DSSB',
        'w_DSDB': 'W-Beam DSDB',
        't_SSSB': 'Thrie-Beam SSSB',
        't_SSDB': 'Thrie-Beam SSDB',
        't_DSSB': 'Thrie-Beam DSSB',
        't_DSDB': 'Thrie-Beam DSDB',
        'zinc_reg': 'Regular (Zinc Coating)',
        'zinc_medium_55_delta': 'Medium 55 micron (Zinc Coating)',
        'zinc_avg_77': 'Average 77 micron (Zinc Coating)',
        'zinc_min_77': 'Minimum 77 micron (Zinc Coating)',
        'con_zinc_reg': 'Consumptionn Zinc Regular',
        'con_zinc_medium_55': 'Consumption Zinc Medium 55 micron',
        'con_zinc_avg_77': 'Consumption Zinc Average 77 micron',
        'con_zinc_min_77': 'Consumption Zinc Minimum 77 micron'
    };

    // 👉 ADDED NOISE BARRIER MAPS
    noiseBarrierMap = {
        "Reflective Column": "r_Column_Base_Rate",
        "Reflective Base Plate": "r_Base_Plate_Base_Rate",
        "Reflective Stiffener Plate": "r_Stiffener_Plate_Base_Rate",
        "Reflective Purlin": "r_Purlin_Base_Rate",
        "Reflective Polycarbonate Sheet": "r_Polycarbonate_Sheet_Base_Rate",
        "Reflective GI Fixing Strip": "r_GI_Fixing_Strip_Base_Rate",
        "Reflective Anchor Bolt": "r_Anchor_Bolt_Rate",
        "Reflective Self Tapping Screw": "r_Self_Tapping_Screw_Rate",
        "Absorptive Perforated Sheet": "Perforated_Sheet_Base_Rate",
        "Absorptive GI Sheet Top Bottom": "GI_Sheet_top_bottom_Base_Rate",
        "Absorptive GI Sheet Side": "GI_Sheet_side_Base_Rate",
        "Absorptive Roll Formed Sheet Back": "Roll_formed_sheet_back_Base_Rate",
        "Absorptive Rockwool": "Rockwool_Base_Rate",
        "Absorptive Screw": "Screw_Base_Rate",
        "Absorptive Column": "Column_Base_Rate",
        "Absorptive Base Plate": "Base_Plate_Base_Rate",
        "Absorptive Stiffner": "Stiffner_Base_Rate",
        "Absorptive Fabrication": "Fabrication_Base_Rate",
        "Absorptive Paint": "Paint_Base_Rate"
    };

    reverseNoiseBarrierMap = {
        "r_Column_Base_Rate": "Reflective Column",
        "r_Base_Plate_Base_Rate": "Reflective Base Plate",
        "r_Stiffener_Plate_Base_Rate": "Reflective Stiffener Plate",
        "r_Purlin_Base_Rate": "Reflective Purlin",
        "r_Polycarbonate_Sheet_Base_Rate": "Reflective Polycarbonate Sheet",
        "r_GI_Fixing_Strip_Base_Rate": "Reflective GI Fixing Strip",
        "r_Anchor_Bolt_Rate": "Reflective Anchor Bolt",
        "r_Self_Tapping_Screw_Rate": "Reflective Self Tapping Screw",
        "Perforated_Sheet_Base_Rate": "Absorptive Perforated Sheet",
        "GI_Sheet_top_bottom_Base_Rate": "Absorptive GI Sheet Top Bottom",
        "GI_Sheet_side_Base_Rate": "Absorptive GI Sheet Side",
        "Roll_formed_sheet_back_Base_Rate": "Absorptive Roll Formed Sheet Back",
        "Rockwool_Base_Rate": "Absorptive Rockwool",
        "Screw_Base_Rate": "Absorptive Screw",
        "Column_Base_Rate": "Absorptive Column",
        "Base_Plate_Base_Rate": "Absorptive Base Plate",
        "Stiffner_Base_Rate": "Absorptive Stiffner",
        "Fabrication_Base_Rate": "Absorptive Fabrication",
        "Paint_Base_Rate": "Absorptive Paint"
    };

    poleApiMap = {
        'Galvanized Price': 'galvanized_price',
        'Mild Steel Price': 'mild_steel_price',
        'Base Plate Price': 'base_plate_price',
        'Sister Plate Price': 'sister_plate_price',
        'Cast Iron Price': 'cast_iron_price',
        'Commercial Price': 'commercial_price',
        'Foundation Bolt Price': 'foundation_bolt_price',
        'Cable Entry Pipe Price': 'cable_entry_pipe_price'
    };

    reversePoleApiMap = {
        'galvanized_price': 'Galvanized Price',
        'mild_steel_price': 'Mild Steel Price',
        'base_plate_price': 'Base Plate Price',
        'sister_plate_price': 'Sister Plate Price',
        'cast_iron_price': 'Cast Iron Price',
        'commercial_price': 'Commercial Price',
        'foundation_bolt_price': 'Foundation Bolt Price',
        'cable_entry_pipe_price': 'Cable Entry Pipe Price'
    };
    
    telecomMap = {
        'Raw Material Cost': 'ang_rmc',
        'Zinc Value': 'ang_zinc_value',
        'Zinc Conversion %': 'ang_zinc_conversion_percent',
        'Fabrication Cost': 'ang_fabrication_cost',
        'Labour Cost': 'ang_labour_cost',
        'Against LC Margin %': 'against_LC_percent',
        'Against VFS Margin %': 'against_VFS_percent',
        'Without BOM Value': 'tub_without_bom_value1',
        'Pipe Rate': 'tub_pipe_rate',
        'Plate Rate': 'tub_plate_rate',
        'Angle/Channel Rate': 'tub_ang_chan_rate',
        'Misc Rate': 'tub_misc_chan_rate'
    };

    reverseTelecomMap = {
        'ang_rmc': 'Raw Material Cost',
        'ang_zinc_value': 'Zinc Value',
        'ang_zinc_conversion_percent': 'Zinc Conversion %',
        'ang_fabrication_cost': 'Fabrication Cost',
        'ang_labour_cost': 'Labour Cost',
        'against_LC_percent': 'Against LC Margin %',
        'against_VFS_percent': 'Against VFS Margin %',
        'tub_without_bom_value1': 'Without BOM Value',
        'tub_pipe_rate': 'Pipe Rate',
        'tub_plate_rate': 'Plate Rate',
        'tub_ang_chan_rate': 'Angle/Channel Rate',
        'tub_misc_chan_rate': 'Misc Rate'
    };

    crashTestedMap = {
        'Base Rate': 'common_base_rate',
        'Regular (Zinc Coating)': 'zinc_regular_delta',
        'Medium 55 micron (Zinc Coating)':'zinc_medium_55_delta',
        'Average 77 micron (Zinc Coating)': 'zinc_average_delta',
        'Minimum 77 micron (Zinc Coating)': 'zinc_minimum_delta',
        'W-Beam Natrax (Delta)': 'wb_natrax_rate_rm',
        'W-Beam Alka Type - 2 c/c (Delta)': 'wb_alka_2cc_rate',
        'W-Beam Alka Type - 4 c/c (Delta)': 'wb_alka_4cc_rate',
        'W-Beam Transpolis (Delta)': 'wb_trans_rate_rm',
        'Thrie-Beam Natrax (Delta)': 'tb_natrax_rate_rm',
        'Thrie-Beam Alka Type - 2 c/c (Delta)': 'tb_alka_2cc_rate',
        'Thrie-Beam Alka Type - 2.66 c/c (Delta)': 'tb_alka_266cc_rate',
        'Consumption Zinc Regular': 'con_zinc_reg',
        'Consumption Zinc Medium 55 micron': 'con_zinc_medium_55',
        'Consumption Zinc Average 77 micron': 'con_zinc_avg_77',
        'Consumption Zinc Minimum 77 micron': 'con_zinc_min_77'
    };

    reverseCrashTestedMap = {
        'common_base_rate': 'Base Rate',
        'zinc_regular_delta': 'Regular (Zinc Coating)',
        'zinc_medium_55_delta': 'Medium 55 micron (Zinc Coating)',
        'zinc_average_delta': 'Average 77 micron (Zinc Coating)',
        'zinc_minimum_delta': 'Minimum 77 micron (Zinc Coating)',
        'wb_natrax_rate_rm': 'W-Beam Natrax (Delta)',
        'wb_alka_2cc_rate': 'W-Beam Alka Type - 2 c/c (Delta)',
        'wb_alka_4cc_rate': 'W-Beam Alka Type - 4 c/c (Delta)',
        'wb_trans_rate_rm': 'W-Beam Transpolis (Delta)',
        'tb_natrax_rate_rm': 'Thrie-Beam Natrax (Delta)',
        'tb_alka_2cc_rate': 'Thrie-Beam Alka Type - 2 c/c (Delta)',
        'tb_alka_266cc_rate': 'Thrie-Beam Alka Type - 2.66 c/c (Delta)',
        'con_zinc_reg': 'Consumptionn Zinc Regular',
        'con_zinc_medium_55': 'Consumption Zinc Medium 55 micron',
        'con_zinc_avg_77': 'Consumption Zinc Average 77 micron',
        'con_zinc_min_77': 'Consumption Zinc Minimum 77 micron'
    };
    railwayMap = {
        'Base Rate': 'common_base_rate',
        'Regular (Zinc Coating)': 'zinc_regular_delta',
        'Medium 55 micron (Zinc Coating)':'zinc_medium_55_delta',
        'Average 77 micron (Zinc Coating)': 'zinc_average_delta',
        'Minimum 77 micron (Zinc Coating)': 'zinc_minimum_delta',
        'Railway Graded (Delta)(1.8)': 'railway_graded_delta1_8',
        'Railway Graded (Delta)(2.0)': 'railway_graded_delta2',
        'Railway Non-Graded (Delta)(1.8)': 'railway_nongraded_delta1_8',
        'Railway Non-Graded (Delta)(2.0)': 'railway_nongraded_delta2',
        'Consumption Zinc Regular': 'con_zinc_reg',
        'Consumption Zinc Medium 55 micron': 'con_zinc_medium_55',
        'Consumption Zinc Average 77 micron': 'con_zinc_avg_77',
        'Consumption Zinc Minimum 77 micron': 'con_zinc_min_77'
    };

    reverseRailwayMap = {
        'common_base_rate': 'Base Rate',
        'zinc_regular_delta': 'Regular (Zinc Coating)',
        'zinc_medium_55_delta': 'Medium 55 micron (Zinc Coating)',
        'zinc_average_delta': 'Average 77 micron (Zinc Coating)',
        'zinc_minimum_delta': 'Minimum 77 micron (Zinc Coating)',
        'railway_graded_delta1_8': 'Railway Graded (Delta)(1.8)',
        'railway_graded_delta2': 'Railway Graded (Delta)(2.0)',   
        'railway_nongraded_delta1_8': 'Railway Non-Graded (Delta)(1.8)',
        'railway_nongraded_delta2': 'Railway Non-Graded (Delta)(2.0)',
        'con_zinc_reg': 'Consumptionn Zinc Regular',
        'con_zinc_medium_55': 'Consumption Zinc Medium 55 micron',
        'con_zinc_avg_77': 'Consumption Zinc Average 77 micron',
        'con_zinc_min_77': 'Consumption Zinc Minimum 77 micron'
    };
    nonSpacerMap = {
        'Base Rate': 'common_base_rate',
        'Regular (Zinc Coating)': 'zinc_regular_delta',
        'Medium 55 micron (Zinc Coating)':'zinc_medium_55_delta',
        'Average 77 micron (Zinc Coating)': 'zinc_average_delta',
        'Minimum 77 micron (Zinc Coating)': 'zinc_minimum_delta',
        'W-Beam Non Spacer (Delta)': 'wb_non_spacer_delta',
        'Thrie-Beam Non Spacer (Delta)': 'tb_non_spacer_delta',
        'Consumption Zinc Regular': 'con_zinc_reg',
        'Consumption Zinc Medium 55 micron': 'con_zinc_medium_55',
        'Consumption Zinc Average 77 micron': 'con_zinc_avg_77',
        'Consumption Zinc Minimum 77 micron': 'con_zinc_min_77'
    };

    reverseNonSpacerMap = {
        'common_base_rate': 'Base Rate',
        'zinc_regular_delta': 'Regular (Zinc Coating)',
        'zinc_medium_55_delta': 'Medium 55 micron (Zinc Coating)',
        'zinc_average_delta': 'Average 77 micron (Zinc Coating)',
        'zinc_minimum_delta': 'Minimum 77 micron (Zinc Coating)',
        'wb_non_spacer_delta': 'W-Beam Non Spacer (Delta)',
        'tb_non_spacer_delta': 'Thrie-Beam Non Spacer (Delta)',
        'con_zinc_reg': 'Consumptionn Zinc Regular',
        'con_zinc_medium_55': 'Consumption Zinc Medium 55 micron',
        'con_zinc_avg_77': 'Consumption Zinc Average 77 micron',
        'con_zinc_min_77': 'Consumption Zinc Minimum 77 micron'
    };

    // 👉 ADDED CORE PIPES MAP (Baseline Default Rates)
    corePipesMap = {
        "Supply of Galvanized STAY & REGISTER ARM Small Tube(33.7X28.40mm),As per specification ETI/OHE/11(5/89)& ETI/OHE/13(4/84).": 140,
        "Supply of Galvanized Large Tube (49.00X40.90mm),As per specification ETI/OHE/11(5/89)& ETI/OHE/13(4/84)": 335,
        "Supply of Galvanized BRACKET Standard Tube (38.00X29.90mm),As per specification ETI/OHE/11(5/89)& ETI/OHE/13(4/84).": 250,
        "Supply of Galvanized GUIDE Counter Weight Tube 25mm(NB),Length- 5.6MTR. Drawing No. ETI/OHE/P/5060-2 Rev-C": 900
    };

   // ==========================================
    // STEEL PIPES DOMESTIC MAPS
    // ==========================================
    domesticPipesMap = {
        "Black Steel": 62.5,
        "Galvanized Iron (GI)": 70,
        "Stainless Steel": 150
    };

    // 👉 CLEANUP: Standardized to 'exportPipesMap'
   exportPipesMap = {
        "Black Steel": 0.65,
        "Galvanized Iron (GI)": 0.75,
        "Stainless Steel": 2.00,
        "RODTEP (%)": 0.45,
        "Incentive (%)": 1.5,
        "Light Series Delta (USD)": 0,
        "Light Series Delta (EUR)": 0,
        "Light Series Delta (GBP)": 0,
        "Light Series Delta (AED)": 0
    };

    domesticWeightMap = {
        "IS 1239|Light|2|15mm": 0.947, "IS 1239|Light|2.3|20mm": 1.38, "IS 1239|Light|2.6|25mm": 1.98, "IS 1239|Light|2.6|32mm": 2.54, "IS 1239|Light|2.9|40mm": 3.23, "IS 1239|Light|2.9|50mm": 4.08, "IS 1239|Light|3.2|65mm": 5.71, "IS 1239|Light|3.2|80mm": 6.72, "IS 1239|Light|3.6|100mm": 9.75, "IS 1239|Medium|2.6|15mm": 1.21, "IS 1239|Medium|2.6|20mm": 1.56, "IS 1239|Medium|3.2|25mm": 2.41, "IS 1239|Medium|3.2|32mm": 3.1, "IS 1239|Medium|3.2|40mm": 3.56, "IS 1239|Medium|3.6|50mm": 5.03, "IS 1239|Medium|3.6|65mm": 6.42, "IS 1239|Medium|4|80mm": 8.36, "IS 1239|Medium|4.5|100mm": 12.2, "IS 1239|Heavy|3.2|15mm": 1.44, "IS 1239|Heavy|3.2|20mm": 1.87, "IS 1239|Heavy|4|25mm": 2.93, "IS 1239|Heavy|4|32mm": 3.79, "IS 1239|Heavy|4|40mm": 4.37, "IS 1239|Heavy|4.5|50mm": 6.19, "IS 1239|Heavy|4.5|65mm": 7.93, "IS 1239|Heavy|4.8|80mm": 9.9, "IS 1239|Heavy|5.4|100mm": 14.5, "IS 1161|Default|2|15mm": 0.95, "IS 1161|Default|2.5|15mm": 1.16, "IS 1161|Default|3|15mm": 1.35, "IS 1161|Default|2|20mm": 1.23, "IS 1161|Default|2.5|20mm": 1.5, "IS 1161|Default|3|20mm": 1.77, "IS 1161|Default|2|25mm": 1.56, "IS 1161|Default|2.5|25mm": 1.92, "IS 1161|Default|3|25mm": 2.27, "IS 1161|Default|2|32mm": 1.99, "IS 1161|Default|2.5|32mm": 2.46, "IS 1161|Default|3|32mm": 2.91, "IS 1161|Default|4|32mm": 3.79, "IS 1161|Default|2|40mm": 2.28, "IS 1161|Default|2.5|40mm": 2.82, "IS 1161|Default|3|40mm": 3.35, "IS 1161|Default|4|40mm": 4.37, "IS 1161|Default|2|50mm": 2.88, "IS 1161|Default|2.5|50mm": 3.56, "IS 1161|Default|3|50mm": 4.24, "IS 1161|Default|4|50mm": 5.55, "IS 1161|Default|2|65mm": 3.65, "IS 1161|Default|2.5|65mm": 4.54, "IS 1161|Default|3|65mm": 5.41, "IS 1161|Default|4|65mm": 7.11, "IS 1161|Default|5|65mm": 8.77, "IS 1161|Default|2|80mm": 4.29, "IS 1161|Default|2.5|80mm": 5.33, "IS 1161|Default|3|80mm": 6.36, "IS 1161|Default|4|80mm": 8.38, "IS 1161|Default|5|80mm": 10.35, "IS 1161|Default|2|90mm": 4.91, "IS 1161|Default|2.5|90mm": 6.11, "IS 1161|Default|3|90mm": 7.29, "IS 1161|Default|4|90mm": 9.63, "IS 1161|Default|5|90mm": 11.91, "IS 1161|Default|2.5|100mm": 6.89, "IS 1161|Default|3|100mm": 8.23, "IS 1161|Default|4|100mm": 10.88, "IS 1161|Default|5|100mm": 13.48, "IS 1161|Default|6|100mm": 16.03, "IS 1161|Default|6.3|100mm": 16.78, "IS 1161|Default|2.9|110mm": 8.88, "IS 1161|Default|3.2|110mm": 9.77, "IS 1161|Default|3.6|110mm": 10.96, "IS 1161|Default|4|110mm": 12.13, "IS 1161|Default|5|110mm": 15.04, "IS 1161|Default|3|125mm": 10.11, "IS 1161|Default|4|125mm": 13.39, "IS 1161|Default|5|125mm": 16.61, "IS 1161|Default|6|125mm": 19.78, "IS 1161|Default|6.3|125mm": 20.73, "IS 1161|Default|3|135mm": 11.05, "IS 1161|Default|4|135mm": 14.64, "IS 1161|Default|5|135mm": 18.18, "IS 1161|Default|6|135mm": 21.66, "IS 1161|Default|6.3|135mm": 22.7, "IS 1161|Default|3|150mm": 11.99, "IS 1161|Default|4|150mm": 15.89, "IS 1161|Default|5|150mm": 19.74, "IS 1161|Default|6|150mm": 23.54, "IS 1161|Default|6.3|150mm": 24.67, "IS 1161|Default|4|175mm": 18.71, "IS 1161|Default|5|175mm": 23.27, "IS 1161|Default|6|175mm": 27.77, "IS 1161|Default|6.3|175mm": 29.12, "IS 1161|Default|4|200mm": 21.22, "IS 1161|Default|5|200mm": 26.4, "IS 1161|Default|6|200mm": 31.53, "IS 1161|Default|6.3|200mm": 33.06, "IS 1161|Default|8|200mm": 41.65, "IS 1161|Default|5|250mm": 33.05, "IS 1161|Default|6|250mm": 39.51, "IS 1161|Default|6.3|250mm": 41.44, "IS 1161|Default|8|250mm": 52.28, "IS 1161|Default|6|300mm": 47.04, "IS 1161|Default|6.3|300mm": 49.34, "IS 1161|Default|8|300mm": 62.32, "IS 1161|Default|5|350mm": 43.23, "IS 1161|Default|6|350mm": 51.73, "IS 1161|Default|6.3|350mm": 54.27, "IS 1161|Default|8|350mm": 68.58, "IS 3589|Default|4|150mm": 16.207, "IS 3589|Default|4.5|150mm": 18.177, "IS 3589|Default|4.85|150mm": 18.549, "IS 3589|Default|5|150mm": 20.135, "IS 3589|Default|5.4|150mm": 21.692, "IS 3589|Default|5.5|150mm": 22.081, "IS 3589|Default|6|150mm": 24.014, "IS 3589|Default|6.35|150mm": 25.36, "IS 3589|Default|7|150mm": 27.844, "IS 3589|Default|4|200mm": 21.217, "IS 3589|Default|4.5|200mm": 23.814, "IS 3589|Default|4.85|200mm": 25.625, "IS 3589|Default|5|200mm": 26.399, "IS 3589|Default|5.4|200mm": 28.457, "IS 3589|Default|5.5|200mm": 28.971, "IS 3589|Default|6|200mm": 31.53, "IS 3589|Default|6.35|200mm": 33.315, "IS 3589|Default|7|200mm": 36.613, "IS 3589|Default|7.5|200mm": 39.135, "IS 3589|Default|8|200mm": 41.646, "IS 3589|Default|9|200mm": 46.63, "IS 3589|Default|9.5|200mm": 49.103, "IS 3589|Default|10|200mm": 51.564, "IS 3589|Default|10.5|200mm": 54.013, "IS 3589|Default|4|250mm": 26.534, "IS 3589|Default|4.5|250mm": 29.795, "IS 3589|Default|4.85|250mm": 32.071, "IS 3589|Default|5|250mm": 33.044, "IS 3589|Default|5.4|250mm": 35.635, "IS 3589|Default|5.5|250mm": 36.281, "IS 3589|Default|6|250mm": 39.505, "IS 3589|Default|6.35|250mm": 41.755, "IS 3589|Default|7|250mm": 45.917, "IS 3589|Default|7.5|250mm": 49.104, "IS 3589|Default|8|250mm": 52.279, "IS 3589|Default|9|250mm": 58.592, "IS 3589|Default|9.5|250mm": 61.73, "IS 3589|Default|10|250mm": 64.856, "IS 3589|Default|10.5|250mm": 67.969, "IS 3589|Default|4|300mm": 31.555, "IS 3589|Default|4.5|300mm": 35.444, "IS 3589|Default|4.85|300mm": 38.159, "IS 3589|Default|5|300mm": 39.32, "IS 3589|Default|5.4|300mm": 42.413, "IS 3589|Default|5.5|300mm": 43.185, "IS 3589|Default|6|300mm": 47.036, "IS 3589|Default|6.35|300mm": 49.725, "IS 3589|Default|7|300mm": 54.703, "IS 3589|Default|7.5|300mm": 58.518, "IS 3589|Default|8|300mm": 62.321, "IS 3589|Default|9|300mm": 69.889, "IS 3589|Default|9.5|300mm": 73.654, "IS 3589|Default|10|300mm": 77.408, "IS 3589|Default|10.5|300mm": 81.149, "IS 3589|Default|4|350mm": 34.682, "IS 3589|Default|4.5|350mm": 38.962, "IS 3589|Default|4.85|350mm": 41.95, "IS 3589|Default|5|350mm": 43.229, "IS 3589|Default|5.4|350mm": 46.634, "IS 3589|Default|5.5|350mm": 47.484, "IS 3589|Default|6|350mm": 51.727, "IS 3589|Default|6.35|350mm": 54.689, "IS 3589|Default|7|350mm": 60.175, "IS 3589|Default|7.5|350mm": 64.381, "IS 3589|Default|8|350mm": 68.575, "IS 3589|Default|9|350mm": 76.924, "IS 3589|Default|9.5|350mm": 81.081, "IS 3589|Default|10|350mm": 85.225, "IS 3589|Default|10.5|350mm": 89.357, "IS 3589|Default|4|400mm": 39.702, "IS 3589|Default|4.5|400mm": 44.654, "IS 3589|Default|4.85|400mm": 48.086, "IS 3589|Default|5|400mm": 49.554, "IS 3589|Default|5.4|400mm": 53.465, "IS 3589|Default|5.5|400mm": 54.442, "IS 3589|Default|6|400mm": 59.317, "IS 3589|Default|6.35|400mm": 62.723, "IS 3589|Default|7|400mm": 69.031, "IS 3589|Default|7.5|400mm": 73.869, "IS 3589|Default|8|400mm": 78.695, "IS 3589|Default|9|400mm": 88.31, "IS 3589|Default|9.5|400mm": 93.099, "IS 3589|Default|10|400mm": 97.876, "IS 3589|Default|10.5|400mm": 102.64, "IS 4270:2001|Screwed-End-Socket|5|100mm": 13.46, "IS 4270:2001|Screwed-End-Socket|5.4|100mm": 14.5, "IS 4270:2001|Screwed-End-Socket|6|100mm": 16.02, "IS 4270:2001|Screwed-End-Socket|5|125mm": 16.8, "IS 4270:2001|Screwed-End-Socket|5.4|125mm": 18.1, "IS 4270:2001|Screwed-End-Socket|6|125mm": 20.01, "IS 4270:2001|Screwed-End-Socket|6.4|125mm": 21.29, "IS 4270:2001|Screwed-End-Socket|7.1|125mm": 23.5, "IS 4270:2001|Screwed-End-Socket|5|150mm": 20.13, "IS 4270:2001|Screwed-End-Socket|5.4|150mm": 21.6, "IS 4270:2001|Screwed-End-Socket|6|150mm": 24.01, "IS 4270:2001|Screwed-End-Socket|6.4|150mm": 25.55, "IS 4270:2001|Screwed-End-Socket|7.1|150mm": 28.2, "IS 4270:2001|Screwed-End-Socket|5.4|175mm": 25.1, "IS 4270:2001|Screwed-End-Socket|6|175mm": 27.77, "IS 4270:2001|Screwed-End-Socket|6.4|175mm": 29.6, "IS 4270:2001|Screwed-End-Socket|7.1|175mm": 32.67, "IS 4270:2001|Screwed-End-Socket|8|175mm": 36.6, "IS 4270:2001|Screwed-End-Socket|5.4|200mm": 28.46, "IS 4270:2001|Screwed-End-Socket|6|200mm": 31.53, "IS 4270:2001|Screwed-End-Socket|6.4|200mm": 33.6, "IS 4270:2001|Screwed-End-Socket|7.1|200mm": 37.12, "IS 4270:2001|Screwed-End-Socket|8|200mm": 41.6, "IS 4270:2001|Screwed-End-Socket|6|225mm": 35.29, "IS 4270:2001|Screwed-End-Socket|7.1|225mm": 41.6, "IS 4270:2001|Screwed-End-Socket|7.1|250mm": 46.57, "IS 4270:2001|Screwed-End-Socket|8|250mm": 52.3, "IS 4270:2001|Screwed-End-Socket|10|250mm": 64.9, "IS 4270:2001|Screwed-End-Socket|7.1|300mm": 55.47, "IS 4270:2001|Screwed-End-Socket|8|300mm": 62.3, "IS 4270:2001|Screwed-End-Socket|10|300mm": 77.4, "IS 4270:2001|Screwed-flush-Butt-joints|6|100mm": 16.02, "IS 4270:2001|Screwed-flush-Butt-joints|6|125mm": 20.01, "IS 4270:2001|Screwed-flush-Butt-joints|8|150mm": 31.62, "IS 4270:2001|Screwed-flush-Butt-joints|8|175mm": 35.63, "IS 4270:2001|Screwed-flush-Butt-joints|10|200mm": 51.56, "IS 4270:2001|Screwed-flush-Butt-joints|10|225mm": 57.82, "IS 4270:2001|Screwed-flush-Butt-joints|10|250mm": 64.88, "IS 4270:2001|Screwed-flush-Butt-joints|10|300mm": 77.4, "IS 4270:2001|Screwed-flush-Butt-joints|10|350mm": 85.22, "IS 4270:2001|Screwed-flush-Butt-joints|12|400mm": 116.71, "IS 4270:2001|Screwed-flush-Butt-joints|14|400mm": 135.47, "IS 4923 : 2017|Square|1.8|19": 0.91, "IS 4923 : 2017|Square|2|19": 0.99, "IS 4923 : 2017|Square|2.3|19": 1.1, "IS 4923 : 2017|Square|2.6|19": 1.2, "IS 4923 : 2017|Square|3|19": 1.32, "IS 4923 : 2017|Square|3.2|19": 1.38, "IS 4923 : 2017|Square|3.6|19": 1.48, "IS 4923 : 2017|Square|1.8|25": 1.25, "IS 4923 : 2017|Square|2|25": 1.36, "IS 4923 : 2017|Square|2.3|25": 1.53, "IS 4923 : 2017|Square|2.6|25": 1.69, "IS 4923 : 2017|Square|3|25": 1.89, "IS 4923 : 2017|Square|3.2|25": 1.98, "IS 4923 : 2017|Square|3.6|25": 2.16, "IS 4923 : 2017|Square|1.8|32": 1.64, "IS 4923 : 2017|Square|2|32": 1.8, "IS 4923 : 2017|Square|2.3|32": 2.04, "IS 4923 : 2017|Square|2.6|32": 2.26, "IS 4923 : 2017|Square|3|32": 2.55, "IS 4923 : 2017|Square|3.2|32": 2.69, "IS 4923 : 2017|Square|3.6|32": 2.95, "IS 4923 : 2017|Square|1.8|38": 1.98, "IS 4923 : 2017|Square|2|38": 2.18, "IS 4923 : 2017|Square|2.3|38": 2.47, "IS 4923 : 2017|Square|2.6|38": 2.94, "IS 4923 : 2017|Square|3|38": 3.11, "IS 4923 : 2017|Square|3.2|38": 3.29, "IS 4923 : 2017|Square|3.6|38": 3.63, "IS 4923 : 2017|Square|1.8|49.5": 2.63, "IS 4923 : 2017|Square|2|49.5": 2.9, "IS 4923 : 2017|Square|2.3|49.5": 3.3, "IS 4923 : 2017|Square|2.6|49.5": 3.69, "IS 4923 : 2017|Square|3|49.5": 4.2, "IS 4923 : 2017|Square|3.2|49.5": 4.44, "IS 4923 : 2017|Square|3.6|49.5": 4.93, "IS 4923 : 2017|Square|2|60": 3.6, "IS 4923 : 2017|Square|2.3|60": 4.12, "IS 4923 : 2017|Square|2.6|60": 4.63, "IS 4923 : 2017|Square|2.9|60": 5.13, "IS 4923 : 2017|Square|3|60": 5.3, "IS 4923 : 2017|Square|3.2|60": 5.63, "IS 4923 : 2017|Square|3.6|60": 6.29, "IS 4923 : 2017|Square|4|60": 6.92, "IS 4923 : 2017|Square|4.3|60": 7.39, "IS 4923 : 2017|Square|4.5|60": 7.7, "IS 4923 : 2017|Square|4.8|60": 8.16, "IS 4923 : 2017|Square|5|60": 8.46, "IS 4923 : 2017|Square|2.5|72": 5.38, "IS 4923 : 2017|Square|2.6|72": 5.58, "IS 4923 : 2017|Square|2.9|72": 6.18, "IS 4923 : 2017|Square|3|72": 6.38, "IS 4923 : 2017|Square|3.2|72": 6.78, "IS 4923 : 2017|Square|3.6|72": 7.55, "IS 4923 : 2017|Square|4|72": 8.32, "IS 4923 : 2017|Square|4.3|72": 8.89, "IS 4923 : 2017|Square|4.5|72": 9.27, "IS 4923 : 2017|Square|4.8|72": 9.83, "IS 4923 : 2017|Square|5|72": 10.2, "IS 4923 : 2017|Square|2.5|80": 6.01, "IS 4923 : 2017|Square|2.6|80": 6.24, "IS 4923 : 2017|Square|2.9|80": 6.91, "IS 4923 : 2017|Square|3|80": 7.13, "IS 4923 : 2017|Square|3.2|80": 7.58, "IS 4923 : 2017|Square|3.6|80": 8.46, "IS 4923 : 2017|Square|4|80": 9.32, "IS 4923 : 2017|Square|4.3|80": 9.97, "IS 4923 : 2017|Square|4.5|80": 10.39, "IS 4923 : 2017|Square|4.8|80": 11.03, "IS 4923 : 2017|Square|5|80": 11.46, "IS 4923 : 2017|Square|2.5|91.5": 6.91, "IS 4923 : 2017|Square|2.6|91.5": 7.18, "IS 4923 : 2017|Square|2.9|91.5": 7.96, "IS 4923 : 2017|Square|3|91.5": 8.22, "IS 4923 : 2017|Square|3.2|91.5": 8.74, "IS 4923 : 2017|Square|3.6|91.5": 9.76, "IS 4923 : 2017|Square|4|91.5": 10.77, "IS 4923 : 2017|Square|4.3|91.5": 11.52, "IS 4923 : 2017|Square|4.5|91.5": 12.02, "IS 4923 : 2017|Square|4.8|91.5": 12.76, "IS 4923 : 2017|Square|5|91.5": 13.25, "IS 4923 : 2017|Square|3|113.5": 10.29, "IS 4923 : 2017|Square|3.2|113.5": 10.95, "IS 4923 : 2017|Square|3.6|113.5": 12.25, "IS 4923 : 2017|Square|4|113.5": 13.53, "IS 4923 : 2017|Square|4.3|113.5": 14.49, "IS 4923 : 2017|Square|4.5|113.5": 15.13, "IS 4923 : 2017|Square|4.8|113.5": 16.08, "IS 4923 : 2017|Square|5|113.5": 16.71, "IS 4923 : 2017|Square|3.6|132": 14.34, "IS 4923 : 2017|Square|4|132": 15.85, "IS 4923 : 2017|Square|4.3|132": 16.99, "IS 4923 : 2017|Square|4.5|132": 17.74, "IS 4923 : 2017|Square|4.8|132": 18.87, "IS 4923 : 2017|Square|5|132": 19.61, "IS 4923 : 2017|Square|3.6|150": 16.37, "IS 4923 : 2017|Square|4|150": 18.11, "IS 4923 : 2017|Square|4.3|150": 19.42, "IS 4923 : 2017|Square|4.5|150": 20.28, "IS 4923 : 2017|Square|4.8|150": 21.58, "IS 4923 : 2017|Square|5|150": 22.44, "IS 4923 : 2017|Square|3.5|180": 19.68, "IS 4923 : 2017|Square|3.6|180": 19.68, "IS 4923 : 2017|Square|4|180": 21.88, "IS 4923 : 2017|Square|4.3|180": 23.47, "IS 4923 : 2017|Square|4.5|180": 24.52, "IS 4923 : 2017|Square|4.8|180": 26.09, "IS 4923 : 2017|Square|5|180": 27.15, "IS 4923 : 2017|Square|3.6|220": 24.2, "IS 4923 : 2017|Square|4|220": 26.81, "IS 4923 : 2017|Square|4.3|220": 28.75, "IS 4923 : 2017|Square|4.5|220": 30.04, "IS 4923 : 2017|Square|4.8|220": 31.97, "IS 4923 : 2017|Square|5|220": 33.25, "IS 4923 : 2017|Square|3.6|260": 28.72, "IS 4923 : 2017|Square|4|260": 31.83, "IS 4923 : 2017|Square|4.3|260": 34.15, "IS 4923 : 2017|Square|4.5|260": 35.69, "IS 4923 : 2017|Square|4.8|260": 38, "IS 4923 : 2017|Square|5|260": 39.53, "IS 4923 : 2017|Rectangular|1.8|50": 1.95, "IS 4923 : 2017|Rectangular|2|50": 2.15, "IS 4923 : 2017|Rectangular|2.3|50": 2.44, "IS 4923 : 2017|Rectangular|2.5|50": 2.62, "IS 4923 : 2017|Rectangular|2.8|50": 2.89, "IS 4923 : 2017|Rectangular|3|50": 3.07, "IS 4923 : 2017|Rectangular|3.2|50": 3.24, "IS 4923 : 2017|Rectangular|3.6|50": 3.57, "IS 4923 : 2017|Rectangular|1.8|60": 2.66, "IS 4923 : 2017|Rectangular|2|60": 2.93, "IS 4923 : 2017|Rectangular|2.3|60": 3.34, "IS 4923 : 2017|Rectangular|2.5|60": 3.6, "IS 4923 : 2017|Rectangular|2.8|60": 3.99, "IS 4923 : 2017|Rectangular|3|60": 4.25, "IS 4923 : 2017|Rectangular|3.2|60": 4.5, "IS 4923 : 2017|Rectangular|3.6|60": 4.98, "IS 4923 : 2017|Rectangular|1.8|66": 2.63, "IS 4923 : 2017|Rectangular|2|66": 2.9, "IS 4923 : 2017|Rectangular|2.3|66": 3.3, "IS 4923 : 2017|Rectangular|2.5|66": 3.56, "IS 4923 : 2017|Rectangular|2.8|66": 3.95, "IS 4923 : 2017|Rectangular|3|66": 4.2, "IS 4923 : 2017|Rectangular|3.2|66": 4.44, "IS 4923 : 2017|Rectangular|3.6|66": 4.93, "IS 4923 : 2017|Rectangular|2.5|70": 3.6, "IS 4923 : 2017|Rectangular|2.8|70": 3.99, "IS 4923 : 2017|Rectangular|3|70": 4.25, "IS 4923 : 2017|Rectangular|3.2|70": 4.5, "IS 4923 : 2017|Rectangular|3.6|70": 4.98, "IS 4923 : 2017|Rectangular|4|70": 5.45, "IS 4923 : 2017|Rectangular|4.3|70": 5.8, "IS 4923 : 2017|Rectangular|4.5|70": 6.02, "IS 4923 : 2017|Rectangular|2.5|75": 3.6, "IS 4923 : 2017|Rectangular|2.8|75": 3.99, "IS 4923 : 2017|Rectangular|3|75": 4.25, "IS 4923 : 2017|Rectangular|3.2|75": 4.5, "IS 4923 : 2017|Rectangular|3.6|75": 4.98, "IS 4923 : 2017|Rectangular|4|75": 5.45, "IS 4923 : 2017|Rectangular|4.3|75": 5.8, "IS 4923 : 2017|Rectangular|4.5|75": 6.02, "IS 4923 : 2017|Rectangular|2.5|80": 4.39, "IS 4923 : 2017|Rectangular|2.8|80": 4.87, "IS 4923 : 2017|Rectangular|3|80": 5.19, "IS 4923 : 2017|Rectangular|3.2|80": 5.5, "IS 4923 : 2017|Rectangular|3.6|80": 6.11, "IS 4923 : 2017|Rectangular|4|80": 6.71, "IS 4923 : 2017|Rectangular|4.3|80": 7.15, "IS 4923 : 2017|Rectangular|4.5|80": 7.43, "IS 4923 : 2017|Rectangular|3.2|96": 6.71, "IS 4923 : 2017|Rectangular|3.6|96": 7.47, "IS 4923 : 2017|Rectangular|4|96": 8.22, "IS 4923 : 2017|Rectangular|4.3|96": 8.77, "IS 4923 : 2017|Rectangular|4.5|96": 9.13, "IS 4923 : 2017|Rectangular|3.5|100": 7.61, "IS 4923 : 2017|Rectangular|3.6|100": 7.81, "IS 4923 : 2017|Rectangular|4|100": 8.59, "IS 4923 : 2017|Rectangular|4.3|100": 9.17, "IS 4923 : 2017|Rectangular|4.5|100": 9.55, "IS 4923 : 2017|Rectangular|3.5|122": 9.42, "IS 4923 : 2017|Rectangular|3.6|122": 9.67, "IS 4923 : 2017|Rectangular|4|122": 10.67, "IS 4923 : 2017|Rectangular|4.3|122": 11.4, "IS 4923 : 2017|Rectangular|4.5|122": 11.88, "IS 4923 : 2017|Rectangular|5|122": 13.07, "IS 4923 : 2017|Rectangular|3.5|145": 11.84, "IS 4923 : 2017|Rectangular|3.6|145": 12.16, "IS 4923 : 2017|Rectangular|4|145": 13.43, "IS 4923 : 2017|Rectangular|4.3|145": 14.37, "IS 4923 : 2017|Rectangular|4.5|145": 14.99, "IS 4923 : 2017|Rectangular|5|145": 16.53, "IS 4923 : 2017|Rectangular|3.5|172": 13.87, "IS 4923 : 2017|Rectangular|3.6|172": 14.25, "IS 4923 : 2017|Rectangular|4|172": 15.75, "IS 4923 : 2017|Rectangular|4.3|172": 16.87, "IS 4923 : 2017|Rectangular|4.5|172": 17.61, "IS 4923 : 2017|Rectangular|5|172": 19.43,
        "IS 9295 : 1983|Default|3.65|63.5": 5.39, "IS 9295 : 1983|Default|4.5|63.5": 6.55, "IS 9295 : 1983|Default|3.65|76.1": 6.52, "IS 9295 : 1983|Default|4.5|76.1": 7.95, "IS 9295 : 1983|Default|4.05|88.9": 8.47, "IS 9295 : 1983|Default|4.85|88.9": 10.05, "IS 9295 : 1983|Default|6.3|88.9": 12.83, "IS 9295 : 1983|Default|4.05|101.6": 9.74, "IS 9295 : 1983|Default|4.85|101.6": 11.57, "IS 9295 : 1983|Default|6.3|101.6": 14.81, "IS 9295 : 1983|Default|4.5|114.3": 12.19, "IS 9295 : 1983|Default|4.85|114.3": 14.5, "IS 9295 : 1983|Default|6.3|114.3": 16.78, "IS 9295 : 1983|Default|4.5|127": 13.6, "IS 9295 : 1983|Default|4.85|127": 14.61, "IS 9295 : 1983|Default|5.4|127": 16.49, "IS 9295 : 1983|Default|6.3|127": 18.75, "IS 9295 : 1983|Default|4.5|139.7": 15, "IS 9295 : 1983|Default|4.85|139.7": 16.13, "IS 9295 : 1983|Default|5.4|139.7": 17.89, "IS 9295 : 1983|Default|6.3|139.7": 20.73, "IS 9295 : 1983|Default|4.5|152.4": 16.4, "IS 9295 : 1983|Default|4.85|152.4": 17.65, "IS 9295 : 1983|Default|5.4|152.4": 19.58, "IS 9295 : 1983|Default|6.3|152.4": 22.7, "IS 9295 : 1983|Default|4.5|159": 17.1, "IS 9295 : 1983|Default|4.85|159": 18.44, "IS 9295 : 1983|Default|5.4|159": 20.4, "IS 9295 : 1983|Default|6.3|159": 23.72, "IS 9295 : 1983|Default|4.5|165.1": 17.8, "IS 9295 : 1983|Default|4.85|165.1": 19.17, "IS 9295 : 1983|Default|5.4|165.1": 21.27, "IS 9295 : 1983|Default|6.3|165.1": 24.67, "IS 9295 : 1983|Default|4.5|168.3": 18.2, "IS 9295 : 1983|Default|4.85|168.3": 19.55, "IS 9295 : 1983|Default|5.4|168.3": 21.69, "IS 9295 : 1983|Default|6.3|168.3": 25.17, "IS 9295 : 1983|Default|5.4|193.7": 25.1, "IS 9295 : 1983|Default|6.3|193.7": 29.12, "IS 9295 : 1983|Default|7.1|193.7": 32.67, "IS 9295 : 1983|Default|5.4|219.1": 28.5, "IS 9295 : 1983|Default|6.3|219.1": 33.06, "IS 9295 : 1983|Default|7.1|219.1": 37.12,
        "IS 10577 : 1982|Light|2|15mm": 0.952, "IS 10577 : 1982|Light|2.35|20mm": 1.41, "IS 10577 : 1982|Light|2.65|25mm": 2.01, "IS 10577 : 1982|Medium|2.65|15mm": 1.22, "IS 10577 : 1982|Medium|2.65|20mm": 1.58, "IS 10577 : 1982|Medium|3.25|25mm": 2.44, "IS 10577 : 1982|Heavy|3.25|15mm": 1.45, "IS 10577 : 1982|Heavy|3.25|20mm": 1.9, "IS 10577 : 1982|Heavy|4.05|25mm": 2.97
    };
    solarStructureMap = {
        // "HDG MMS/Carport Structure" split into two independently priced
        // materials — Deepanjan (1st August 2026). The old combined rows are
        // kept below so existing saved rates keep resolving until the client
        // enters rates against the two new names.
        "HDG MMS Structure": "HDG MMS Structure",
        "HDG MMS Structure E250": "HDG MMS Structure|E250",
        "HDG MMS Structure E350": "HDG MMS Structure|E350",
        "HDG MMS Structure E450": "HDG MMS Structure|E450",
        "HDG MMS Structure E550": "HDG MMS Structure|E550",
        "Carport Structure": "Carport Structure",
        "Carport Structure E250": "Carport Structure|E250",
        "Carport Structure E350": "Carport Structure|E350",
        "Carport Structure E450": "Carport Structure|E450",
        "Carport Structure E550": "Carport Structure|E550",
        /*"HDG MMS/Carport Structure": "HDG MMS/Carport Structure",
        "HDG MMS/Carport Structure E250": "HDG MMS/Carport Structure|E250",
        "HDG MMS/Carport Structure E350": "HDG MMS/Carport Structure|E350",
        "HDG MMS/Carport Structure E450": "HDG MMS/Carport Structure|E450",
        "HDG MMS/Carport Structure E550": "HDG MMS/Carport Structure|E550",*/
        // Special Grade dropped; Piers now carries E350/E450/E550.
        // Renamed to "Piers (W-Beam) for Tracker" - Deepanjan (9th August 2026).
        // W-Beam is gone from the estimator's material list and folded in here.
        "Piers (W-Beam) for Tracker": "Piers (W-Beam) for Tracker",
        "Piers (W-Beam) for Tracker E350": "Piers (W-Beam) for Tracker|E350",
        "Piers (W-Beam) for Tracker E450": "Piers (W-Beam) for Tracker|E450",
        "Piers (W-Beam) for Tracker E550": "Piers (W-Beam) for Tracker|E550",
        "I-BEAM": "I-BEAM",
        "I-BEAM E350": "I-BEAM|E350",
        "I-BEAM E450": "I-BEAM|E450",
        "I-BEAM E550": "I-BEAM|E550",
        "RSJ": "RSJ",
        "RSJ E350": "RSJ|E350",
        "RSJ E450": "RSJ|E450",
        "RSJ E550": "RSJ|E550",
        "Black Metal": "Black Metal",
        "Black Metal E250": "Black Metal|E250",
        "Black Metal E350": "Black Metal|E350",
        "Black Metal E450": "Black Metal|E450",
        "Black Metal E550": "Black Metal|E550",
        "Galvalume": "Galvalume Structure",
        // Grade renamed AZ150 GSM (350 MPA) -> YSD 350 and AZ200 GSM (550 MPA)
        // -> YSD 550 - Deepanjan (9th August 2026). Rates carried across as-is.
        "Galvalume Structure YSD 350": "Galvalume Structure|YSD 350",
        "Galvalume Structure YSD 350 AZ 150": "Galvalume Structure|YSD 350|AZ150",
        "Galvalume Structure YSD 350 AZ200": "Galvalume Structure|YSD 350|AZ200",
        "Galvalume Structure YSD 350 AZ250": "Galvalume Structure|YSD 350|AZ250",
        "Galvalume Structure YSD 350 AZ300": "Galvalume Structure|YSD 350|AZ300",
        "Galvalume Structure YSD 550": "Galvalume Structure|YSD 550",
        "Galvalume Structure YSD 550 AZ 150": "Galvalume Structure|YSD 550|AZ150",
        "Galvalume Structure YSD 550 AZ200": "Galvalume Structure|YSD 550|AZ200",
        "Galvalume Structure YSD 550 AZ250": "Galvalume Structure|YSD 550|AZ250",
        "Galvalume Structure YSD 550 AZ300": "Galvalume Structure|YSD 550|AZ300",
        // HBM/WBM renamed to their full names, value as well as label. The old
        // keys stay so quotes saved before the rename still price.
        "H-Beam": "H-Beam",
        "H-Beam E350": "H-Beam|E350",
        "H-Beam E450": "H-Beam|E450",
        "H-Beam E550": "H-Beam|E550",
        "W-Beam": "W-Beam",
        "W-Beam E350": "W-Beam|E350",
        "W-Beam E450": "W-Beam|E450",
        "W-Beam E550": "W-Beam|E550",
        "HBM": "HBM",
        "WBM": "WBM",
        // black beam prices
         "I-Beam (Black)": "I-Beam (Black)",
        "I-Beam (Black) E350": "I-Beam (Black)|E350",
        "I-Beam (Black) E450": "I-Beam (Black)|E450",
        "I-Beam (Black) E550": "I-Beam (Black)|E550",
        "W-Beam (Black)": "W-Beam (Black)",
        "W-Beam (Black) E350": "W-Beam (Black)|E350",
        "W-Beam (Black) E450": "W-Beam (Black)|E450",
        "W-Beam (Black) E550": "W-Beam (Black)|E550",
        "H-Beam (Black)": "H-Beam (Black)",
        "H-Beam (Black) E350": "H-Beam (Black)|E350",
        "H-Beam (Black) E450": "H-Beam (Black)|E450",
        "H-Beam (Black) E550": "H-Beam (Black)|E550",
        "Piers for Tracker (Black)": "Piers for Tracker (Black)",
        "Piers for Tracker (Black) E350": "Piers for Tracker (Black)|E350",
        "Piers for Tracker (Black) E450": "Piers for Tracker (Black)|E450",
        "Piers for Tracker (Black) E550": "Piers for Tracker (Black)|E550",
        "Zinc Labour": "Zinc Labour",
        "Labour Contractor": "Labour Contractor",
        "Consumables": "Consumables",
        "Finance Cost": "Finance Cost",
        "Equity Cost": "Equity Cost",
        "Overheads": "Overheads"
    };

    reverseDomesticPipesMap = Object.keys(this.domesticPipesMap).reduce((ret, key) => {
        ret[this.domesticPipesMap[key]] = key;
        return ret;
    }, {});

    // ==========================================
// TRANSMISSION TOWER — LABEL/APINAME MAPS
// ==========================================
transmissionTowerMap = {
    'PV Convergence to Angles': 'pvt_pv_convergence_to_angles',
    'Firm Angles Price': 'pvt_firm_angles',
    'Firm Zinc Price': 'pvt_firm_zinc_price',
    'Interest - Working Capital': 'pvt_int_comp_working_capital',
    'Interest - Carrying Cost': 'pvt_int_carrying_cost',
    'Interest - LC %': 'pvt_int_LC',
    'Interest - VFS %': 'pvt_int_VFS',
    'Proto Value': 'pvt_proto_value',
    'Cost of Production': 'pvt_base_cop',
    'Zinc Consumption %': 'pvt_base_zcp',
    'Scrap %': 'pvt_base_sp'
};

reverseTransmissionTowerMap = {
    'pvt_pv_convergence_to_angles': 'PV Convergence to Angles',
    'pvt_firm_angles': 'Firm Angles Price',
    'pvt_firm_zinc_price': 'Firm Zinc Price',
    'pvt_int_comp_working_capital': 'Interest - Working Capital',
    'pvt_int_carrying_cost': 'Interest - Carrying Cost',
    'pvt_int_LC': 'Interest - LC %',
    'pvt_int_VFS': 'Interest - VFS %',
    'pvt_proto_value': 'Proto Value',
    'pvt_base_cop': 'Cost of Production',
    'pvt_base_zcp': 'Zinc Consumption %',
    'pvt_base_sp': 'Scrap %'
};

transmissionSubstationMap = {
    'PV Conversion to Angle': 'pvs_pv_conversion_to_angle',
    'Firm Angles Price': 'pvs_firm_angles',
    'Firm Zinc Price': 'pvs_firm_zinc_price',
    'Interest - Working Capital': 'pvs_int_comp_working_capital',
    'Interest - Carrying Cost': 'pvs_int_carrying_cost',
    'Interest - LC %': 'pvs_int_LC',
    'Interest - VFS %': 'pvs_int_VFS',
    'Proto Value': 'pvs_proto_value',
    'Cost of Production': 'pvs_base_Cost_of_Production',
    'Zinc Consumption %': 'pvs_base_zcp',
    'Scrap %': 'pvs_base_sp',
    'Composite Structure Rate': 'pvs_composite_st',
    'Equipment Structure Rate': 'pvs_equipment_st',
    'Gantry Structure Rate': 'pvs_gantary_st'
};

reverseTransmissionSubstationMap = {
    'pvs_pv_conversion_to_angle': 'PV Conversion to Angle',
    'pvs_firm_angles': 'Firm Angles Price',
    'pvs_firm_zinc_price': 'Firm Zinc Price',
    'pvs_int_comp_working_capital': 'Interest - Working Capital',
    'pvs_int_carrying_cost': 'Interest - Carrying Cost',
    'pvs_int_LC': 'Interest - LC %',
    'pvs_int_VFS': 'Interest - VFS %',
    'pvs_proto_value': 'Proto Value',
    'pvs_base_Cost_of_Production': 'Cost of Production',
    'pvs_base_zcp': 'Zinc Consumption %',
    'pvs_base_sp': 'Scrap %',
    'pvs_composite_st': 'Composite Structure Rate',
    'pvs_equipment_st': 'Equipment Structure Rate',
    'pvs_gantary_st': 'Gantry Structure Rate'
};

nutsBoltsMap = {
    'Base Price': 'base_price',
    'Foundation Base Price': 'foundation_base_price',
    'PVS Type 5.6 Margin %': 'pvs_type_5_6_margin',
    'PVS Type 6.8 Margin %': 'pvs_type_6_8_margin',
    'PVS Type 8.8 Margin %': 'pvs_type_8_8_margin',
    'Foundation Bolt Margin %': 'pvs_detail_foundation_bolt_margin',
    'MS Template (FIRM) Margin %': 'pvs_detail_ms_template_margin_firm',
    'MS Template (PV) Margin %': 'pvs_detail_ms_template_margin_pv'
};

reverseNutsBoltsMap = {
    'base_price': 'Base Price',
    'foundation_base_price': 'Foundation Base Price',
    'pvs_type_5_6_margin': 'PVS Type 5.6 Margin %',
    'pvs_type_6_8_margin': 'PVS Type 6.8 Margin %',
    'pvs_type_8_8_margin': 'PVS Type 8.8 Margin %',
    'pvs_detail_foundation_bolt_margin': 'Foundation Bolt Margin %',
    'pvs_detail_ms_template_margin_firm':'MS Template (FIRM) Margin %',
    'pvs_detail_ms_template_margin_pv':'MS Template (PV) Margin %'
};

    async connectedCallback() {
        try {
            await loadScript(this, SHEETJS);
            this.sheetJsLoaded = true;
        } catch (error) {
            console.error('SheetJS Load Error:', error);
        }
    }

    get optionsA() {
        return Object.keys(this.picklistData).map(item => ({ label: item, value: item }));
    }

    get isBDisabled() {
        return !this.valueA;
    }

    handleAChange(event) {
        this.valueA = event.detail.value;
        this.valueB = '';
        this.showDataGrid = false;
        this.fullExistingDatabaseConfig = [];
        this.verificationResults = [];
        this.optionsB = (this.picklistData[this.valueA] || []).map(item => ({ label: item, value: item }));
    }

    handleBChange(event) {
        this.valueB = event.detail.value;
        if (this.valueA && this.valueB) {
            this.setupGrid();
        }
    }

   async setupGrid() {
         this.reverseDomesticPipesMap = Object.keys(this.domesticPipesMap || {}).reduce((ret, key) => {
            ret[this.domesticPipesMap[key]] = key;
            return ret;
        }, {});

        // 👉 SAFE FALLBACK: Will not crash if the map doesn't exist
        this.reverseExportPipesMap = Object.keys(this.exportPipesMap || {}).reduce((ret, key) => {
            ret[this.exportPipesMap[key]] = key;
            return ret;
        }, {});
        
        const schemaKey = `${this.valueA}|${this.valueB}`;
        this.currentColumns = this.validationSchemas[schemaKey] || ['Item Name', 'Rate'];
        
        this.showDataGrid = true;
        this.isModalOpen = false;
        this.gridData = [];


        // ===== HIGH MAST: flat Base Amount / Add On Amount, no JSON rate card =====
        if (this.valueA === 'High Mast - Department') {
            const hmDevName = this.highMastRecordMap[this.valueB];
            if (!hmDevName) {
                this.showError('No Price Calculator record mapped for: ' + this.valueB);
                this.showDataGrid = false;
                return;
            }

            let baseVal = '0';
            let addOnVal = '0';
            try {
                const hmRec = await getHighMastAmounts({ recordDeveloperName: hmDevName });
                if (hmRec) {
                    baseVal  = hmRec.Base_Amount__c    != null ? String(hmRec.Base_Amount__c)    : '0';
                    addOnVal = hmRec.Add_On_Amount__c  != null ? String(hmRec.Add_On_Amount__c)  : '0';
                }
            } catch (err) {
                console.error('High Mast amount fetch failed:', err);
            }

            this.gridData = [
                {
                    id: 'hm_row_0', displayIndex: 1,
                    cells: [
                        { column: 'Item',  value: 'Base Amount',   isReadOnly: true },
                        { column: 'Value', value: baseVal,         isReadOnly: false }
                    ]
                },
                {
                    id: 'hm_row_1', displayIndex: 2,
                    cells: [
                        { column: 'Item',  value: 'Add On Amount', isReadOnly: true },
                        { column: 'Value', value: addOnVal,        isReadOnly: false }
                    ]
                }
            ];
            return;
        }
        let targetDeveloperName = '';
        if (this.valueA === 'Solar Structure - Department') targetDeveloperName = 'Solar_Structure';
        else if (this.valueA === 'HDPE Pipe - Department' && this.valueB === 'Standard - PLB Duct') targetDeveloperName = 'PLB_Duct_Price';
        else if (this.valueA === 'HDPE Pipe - Department' && this.valueB === 'Standard - IS 4984') targetDeveloperName = 'IS_4984_Price';
        else if (this.valueA === 'HDPE Pipe - Department' && this.valueB === 'Standard - Pipe & Duct') targetDeveloperName = 'pipe_and_duct_price';
        else if (this.valueA === 'HDPE Pipe - Department' && this.valueB === 'Standard - MDPE Pipe') targetDeveloperName = 'MDPE_Pipe_Price';
        else if (this.valueB === 'Type of Pole - Standard') targetDeveloperName = 'Standard_Pole';
        else if (this.valueB === 'Type of Pole - Customized') targetDeveloperName = 'Customized_Pole';
        else if (this.valueA === 'Crash Barrier - Department' && this.valueB === 'MBCB type - Conventional Type') targetDeveloperName = 'Crash_Barrier_Conventional';
        else if (this.valueA === 'Crash Barrier - Department' && this.valueB === 'MBCB type - Noise Barrier') targetDeveloperName = 'Noise_Barrier'; // 👉 HOOK FOR NOISE BARRIER
        else if (this.valueA === 'Telecom Tower - Department' ) targetDeveloperName = 'Telecom_Tower_Conventional';
        else if (this.valueA === 'Crash Barrier - Department' && this.valueB === 'MBCB type - Crash Tested') targetDeveloperName = 'Crash_Barrier_Crash_Tested';
        else if (this.valueA === 'Crash Barrier - Department' && this.valueB === 'MBCB type - Railway') targetDeveloperName = 'Crash_Barrier_Railway';
        else if (this.valueA === 'Crash Barrier - Department' && this.valueB === 'MBCB type - Non-Spacer Design') targetDeveloperName = 'Crash_Barrier_Non_Spacer';
        else if (this.valueA === 'Steel Pipes - Department' && this.valueB === 'Domestic') targetDeveloperName = 'Steel_Pipe_Domestic_Config';
        else if (this.valueA === 'Steel Pipes - Department' && this.valueB === 'Export') targetDeveloperName = 'Steel_Pipes_Export';
        // 👉 ADDED CORE PIPES (Retrieves from Steel Pipe Domestic Config metadata)
        else if (this.valueA === 'Steel Pipes - Department' && this.valueB === 'Core Pipes') targetDeveloperName = 'Steel_Pipe_Domestic_Config';
        else if (this.valueA === 'Transmission Tower - Department' && this.valueB === 'Type of Product - Tower') targetDeveloperName = 'Transmission_Tower_Product';
        else if (this.valueA === 'Transmission Tower - Department' && this.valueB === 'Type of Product - Substation') targetDeveloperName = 'Transmission_Substation';
        else if (this.valueA === 'Transmission Tower - Department' && this.valueB === 'Nuts & Bolts Details') targetDeveloperName = 'Transmission_Nuts_Bolts';

        if (targetDeveloperName) {
            try {
                const record = await getExistingRates({ recordDeveloperName: targetDeveloperName });
                
                if (record) {
                    if (this.valueA === 'HDPE Pipe - Department' && record.Base_Amount__c) {
                        this.gridData = [{
                            id: 'saved_row_0',
                            displayIndex: 1,
                            cells: [
                                { column: 'Item', value: 'Base Rate', isReadOnly: true }, 
                                { column: 'Value', value: record.Base_Amount__c, isReadOnly: false } 
                            ]
                        }];
                        return; 
                    }

                   let payload = record.JSON_Payload__c || record.rateCard__c;
                    if (payload && (
                        this.valueA === 'Solar Structure - Department' || 
                        this.valueA === 'Steel Tubular Pole - Department' || 
                        (this.valueA === 'Crash Barrier - Department' && (this.valueB === 'MBCB type - Conventional Type' || this.valueB === 'MBCB type - Noise Barrier' || this.valueB === 'MBCB type - Crash Tested' || this.valueB === 'MBCB type - Railway' || this.valueB === 'MBCB type - Non-Spacer Design')) 
                        || (this.valueA === 'Steel Pipes - Department' && (this.valueB === 'Domestic' || this.valueB === 'Export' || this.valueB === 'Core Pipes')) || this.valueA === 'Telecom Tower - Department' ||
                        (this.valueA === 'HDPE Pipe - Department' && (this.valueB === 'Standard - IS 4984' || this.valueB === 'Standard - PLB Duct' || this.valueB === 'Standard - Pipe & Duct' || this.valueB === 'Standard - MDPE Pipe')) ||
                        (this.valueA === 'Transmission Tower - Department' && (this.valueB === 'Type of Product - Tower' || this.valueB === 'Type of Product - Substation' || this.valueB === 'Nuts & Bolts Details'))
                    )){
                        let parsedConfig = JSON.parse(payload);
                        
                        // 👉 CORE PIPES EXTRACTION
                        if (this.valueA === 'Steel Pipes - Department' && this.valueB === 'Core Pipes') {
                            this.fullExistingDatabaseConfig = parsedConfig.CORE_PIPE_RATES || parsedConfig.coreRates || this.corePipesMap;
                        } 
                        else if ((this.valueA === 'Steel Pipes - Department' && (this.valueB === 'Domestic' || this.valueB === 'Export')) || (this.valueA === 'Solar Structure - Department' && this.valueB !== 'Global Zinc Rate')) {
                            // 👉 SAFELY extracts baseRatesMap for BOTH Domestic and Export, and Solar Structure Map
                            if (parsedConfig && (parsedConfig.baseRatesMap !== undefined || parsedConfig.baseRates !== undefined || parsedConfig.BASE_RATES !== undefined)) {
                                this.fullExistingDatabaseConfig = parsedConfig.baseRatesMap || parsedConfig.baseRates || parsedConfig.BASE_RATES;
                            } else {
                                this.fullExistingDatabaseConfig = parsedConfig; 
                            }
                        } else {
                            this.fullExistingDatabaseConfig = Array.isArray(parsedConfig) ? parsedConfig : [parsedConfig];
                        }
                        
                        this.rebuildGridFromConfig(this.fullExistingDatabaseConfig);
                        return; 
                    }
                }
            } catch(err) {
                console.error('No existing rates found, starting fresh.');
            }
        }

        // 👉 DEFAULT GRID: CORE PIPES
        if (this.valueA.includes('Steel Pipe') && this.valueB.includes('Core')) {
            const defaultItems = Object.keys(this.corePipesMap || {});
            this.gridData = defaultItems.map((item, idx) => ({
                id: 'new_row_' + idx,
                displayIndex: idx + 1,
                cells: [
                    { column: 'Item', value: item, isReadOnly: true },
                    { column: 'Rate', value: String(this.corePipesMap[item]), isReadOnly: false }
                ]
            }));
            return;
        }

        // 👉 SOLAR STRUCTURE DEPARTMENT: PRE-POPULATE INDIVIDUAL BASE RATE ROWS
        if (this.valueA === 'Solar Structure - Department' && this.valueB === 'Global Zinc Rate') {
            this.gridData = [{
                id: 'new_row_0',
                displayIndex: 1,
                cells: [
                    { column: 'Item', value: 'Zinc Rate per MT', isReadOnly: true },
                    { column: 'Rate', value: '0', isReadOnly: false }
                ]
            }];
            return;
        }

        // 👉 PRE-POPULATE BLANK GRIDS FOR HDPE PIPE DEPARTMENT TYPE SELECTIONS IF DATABASE RECORD IS NEW
        if (this.valueA === 'HDPE Pipe - Department') {
            let defaultItems = [];
            if (this.valueB === 'Standard - Pipe & Duct') {
                defaultItems = Object.keys(this.hdpepipeAndDuct);
            } else if (this.valueB === 'Standard - IS 4984') {
                defaultItems = Object.keys(this.hdpeIs4984);
            } else if (this.valueB === 'Standard - PLB Duct') {
                defaultItems = Object.keys(this.hdpePlbDuct);
            } else if(this.valueB === 'Standard - MDPE Pipe'){
                defaultItems = Object.keys(this.mdpePipe);
            }

            if (defaultItems.length > 0) {
                this.gridData = defaultItems.map((item, idx) => ({
                    id: 'new_row_' + idx,
                    displayIndex: idx + 1,
                    cells: [
                        { column: 'Item', value: item, isReadOnly: true },
                        { column: 'Value', value: '0', isReadOnly: false }
                    ]
                }));
                return;
            }
        }

       if (this.valueB === 'Type of Pole - Standard' || this.valueB === 'Type of Pole - Customized') {
            const defaultItems = Object.keys(this.poleApiMap);
            this.gridData = defaultItems.map((item, idx) => ({
                id: 'new_row_' + idx,
                displayIndex: idx + 1,
                cells: [
                    { column: 'Item', value: item, isReadOnly: true },
                    { column: 'Rate', value: '0', isReadOnly: false }
                ]
            }));
            return;
        }
        if (this.valueA === 'Crash Barrier - Department' && this.valueB === 'MBCB type - Conventional Type') {
            const defaultItems = Object.keys(this.crashBarrierConvMap);
            this.gridData = defaultItems.map((item, idx) => ({
                id: 'new_row_' + idx,
                displayIndex: idx + 1,
                cells: [
                    { column: 'Item', value: item, isReadOnly: true },
                    { column: 'Rate', value: '0', isReadOnly: false } 
                ]
            }));
            return;
        }
        // 👉 PRE-POPULATE 19 ROWS FOR NOISE BARRIER
        if (this.valueA === 'Crash Barrier - Department' && this.valueB === 'MBCB type - Noise Barrier') {
            const defaultItems = Object.keys(this.noiseBarrierMap);
            this.gridData = defaultItems.map((item, idx) => ({
                id: 'new_row_' + idx,
                displayIndex: idx + 1,
                cells: [
                    { column: 'Item', value: item, isReadOnly: true },
                    { column: 'Rate', value: '0', isReadOnly: false }
                ]
            }));
            return;
        }
        if (this.valueA === 'Telecom Tower - Department') {
            const defaultItems = Object.keys(this.telecomMap);
            this.gridData = defaultItems.map((item, idx) => ({
                id: 'new_row_' + idx,
                displayIndex: idx + 1,
                cells: [
                    { column: 'Item', value: item, isReadOnly: true },
                    { column: 'Rate', value: '0', isReadOnly: false }
                ]
            }));
            return;
        }
        if (this.valueA === 'Crash Barrier - Department' && this.valueB === 'MBCB type - Crash Tested') {
            const defaultItems = Object.keys(this.crashTestedMap);
            this.gridData = defaultItems.map((item, idx) => ({
                id: 'new_row_' + idx,
                displayIndex: idx + 1,
                cells: [
                    { column: 'Item', value: item, isReadOnly: true },
                    { column: 'Rate', value: '0', isReadOnly: false }
                ]
            }));
            return;
        }

        // 👉 ADD THIS right next to your other pre-populators
        if (this.valueA === 'Crash Barrier - Department' && this.valueB === 'MBCB type - Railway') {
            const defaultItems = Object.keys(this.railwayMap);
            this.gridData = defaultItems.map((item, idx) => ({
                id: 'new_row_' + idx,
                displayIndex: idx + 1,
                cells: [
                    { column: 'Item', value: item, isReadOnly: true },
                    { column: 'Rate', value: '0', isReadOnly: false }
                ]
            }));
            return;
        }
        // 👉 ADD THIS right next to your other pre-populators
        if (this.valueA === 'Crash Barrier - Department' && this.valueB === 'MBCB type - Non-Spacer Design') {
            const defaultItems = Object.keys(this.nonSpacerMap);
            this.gridData = defaultItems.map((item, idx) => ({
                id: 'new_row_' + idx,
                displayIndex: idx + 1,
                cells: [
                    { column: 'Item', value: item, isReadOnly: true },
                    { column: 'Rate', value: '0', isReadOnly: false }
                ]
            }));
            return;
        }
       if (this.valueA.includes('Steel Pipe') && this.valueB.includes('Domestic')) {
            const defaultItems = Object.keys(this.domesticPipesMap || {});
            
            this.gridData = defaultItems.map((item, idx) => ({
                id: 'new_row_' + idx,
                displayIndex: idx + 1,
                cells: [ 
                    { column: 'Item', value: item, isReadOnly: true },
                    { column: 'Rate', value: String(this.domesticPipesMap[item]), isReadOnly: false }
                ]
            }));
            return;
        }

        // 👉 ADD THIS: Draw the full Export grid if no prices exist in the database yet
      // 👉 Draws the Export grid using the exact default values you provided above
        if (this.valueA.includes('Steel Pipe') && this.valueB.includes('Export')) {
            const defaultItems = Object.keys(this.exportPipesMap || {});
            
            this.gridData = defaultItems.map((item, idx) => ({
                id: 'new_row_' + idx,
                displayIndex: idx + 1,
                cells: [
                    { column: 'Item', value: item, isReadOnly: true },
                    { column: 'Rate', value: String(this.exportPipesMap[item]), isReadOnly: false } // <--- Now pulls the default price!
                ]
            }));
            return;
        }

        this.handleAddRow();
        this.handleAddRow();
    }

    // ==========================================
    // REVERSE-ENGINEER JSON INTO GRID ROWS
    // ==========================================
    rebuildGridFromConfig(parsedConfig) {
        let reconstructedRows = [];
        let rowIndex = 0;

        const checkIsReadOnly = (colName) => {
            const lowerCol = colName.toLowerCase();
            return !(lowerCol.includes('price') || lowerCol.includes('rate') || lowerCol === 'value' || lowerCol.includes('cost'));
        };

        // 👉 CORE PIPES REBUILD
        if (this.valueA === 'Steel Pipes - Department' && this.valueB === 'Core Pipes') {
            const defaultItems = Object.keys(this.corePipesMap);
            let ratesMap = parsedConfig || {};

            defaultItems.forEach(item => {
                let savedValue = ratesMap[item] !== undefined ? ratesMap[item] : this.corePipesMap[item];
                reconstructedRows.push({
                    id: 'saved_row_' + (rowIndex++),
                    displayIndex: rowIndex,
                    cells: [
                        { column: 'Item', value: item, isReadOnly: true },
                        { column: 'Rate', value: String(savedValue !== undefined ? savedValue : '0'), isReadOnly: false }
                    ]
                });
            });
        }

        // 👉 UPDATED: REBUILD BASE RATES FOR INDIVIDUAL SOLAR STRUCTURE MATERIALS
        else if (this.valueA === 'Solar Structure - Department' && this.valueB !== 'Global Zinc Rate') {
            const defaultItems = Object.keys(this.solarStructureMap);
            
            let actualRatesMap = {};
            if (Array.isArray(parsedConfig)) {
                let suffix = this.valueB.includes('Pcs') ? '_pcs' : '_wt';
                let rateObj = parsedConfig.find(p => p.apiName === ('rate' + suffix));
                // ❌ REMOVED generic fallback — never bleed Weight data into Pcs or vice versa
                if (rateObj) actualRatesMap = rateObj.BASE_RATES || {};
            } else if (parsedConfig && parsedConfig.BASE_RATES) {
                actualRatesMap = parsedConfig.BASE_RATES;
            } else {
                actualRatesMap = parsedConfig || {};
            }

            defaultItems.forEach((item, index) => {
                let apiName = this.solarStructureMap[item];
                let savedValue = actualRatesMap[apiName] !== undefined ? actualRatesMap[apiName] : '0';
                
                reconstructedRows.push({
                    id: 'saved_row_' + index,
                    displayIndex: index + 1,
                    cells: [
                        { column: 'Item', value: item, isReadOnly: true },
                        { column: 'Rate', value: String(savedValue), isReadOnly: false }
                    ]
                });
            });
        }
        else if (this.valueB === 'Global Zinc Rate') {
            let existingZincRate = '0';
            parsedConfig.forEach(field => {
                if (field.apiName === 'hdg_zinc_rate') {
                    existingZincRate = field.formula;
                }
            });

            reconstructedRows.push({ 
                id: 'saved_row_zinc', 
                displayIndex: 1, 
                cells: [
                    { column: 'Item', value: 'Zinc Rate per MT', isReadOnly: true },
                    { column: 'Rate', value: existingZincRate, isReadOnly: false }
                ] 
            });
        }
        else if (this.valueB === 'Type of Pole - Standard' || this.valueB === 'Type of Pole - Customized') {
            parsedConfig.forEach(field => {
                let label = this.reversePoleApiMap[field.apiName] || field.apiName;
                reconstructedRows.push({
                    id: 'saved_row_' + (rowIndex++),
                    displayIndex: rowIndex,
                    cells: [
                        { column: 'Item', value: label, isReadOnly: true },
                        { column: 'Rate', value: field.defaultValue || '0', isReadOnly: false }
                    ]
                });
            });
        }
        else if (this.valueA === 'Crash Barrier - Department' && this.valueB === 'MBCB type - Conventional Type') {
            parsedConfig.forEach(field => {
                let label = this.reverseCrashBarrierConvMap[field.apiName] || field.apiName;
                reconstructedRows.push({
                    id: 'saved_row_' + (rowIndex++),
                    displayIndex: rowIndex,
                    cells: [
                        { column: 'Item', value: label, isReadOnly: true },
                        { column: 'Rate', value: String(field.defaultValue || '0'), isReadOnly: false } 
                    ]
                });
            });
        }
        // 👉 REVERSE ENGINEERING ENGINE FOR NOISE BARRIER
        else if (this.valueA === 'Crash Barrier - Department' && this.valueB === 'MBCB type - Noise Barrier') {
            parsedConfig.forEach(field => {
                let label = this.reverseNoiseBarrierMap[field.apiName] || field.apiName;
                reconstructedRows.push({
                    id: 'saved_row_' + (rowIndex++),
                    displayIndex: rowIndex,
                    cells: [
                        { column: 'Item', value: label, isReadOnly: true },
                        { column: 'Rate', value: String(field.defaultValue || '0'), isReadOnly: false }
                    ]
                });
            });
        }
        // 👉 ADD THIS: Reverse Engineering for Railway
        else if (this.valueA === 'Crash Barrier - Department' && this.valueB === 'MBCB type - Railway') {
            parsedConfig.forEach(field => {
                let label = this.reverseRailwayMap[field.apiName] || field.apiName;
                let savedValue = field.defaultValue !== undefined ? field.defaultValue : (field.formula || '0');

                reconstructedRows.push({
                    id: 'saved_row_' + (rowIndex++),
                    displayIndex: rowIndex,
                    cells: [
                        { column: 'Item', value: label, isReadOnly: true },
                        { column: 'Rate', value: String(savedValue), isReadOnly: false }
                    ]
                });
            });
        }
        // 👉 ADD THIS: Reverse Engineering for Non-Spacer Design
        else if (this.valueA === 'Crash Barrier - Department' && this.valueB === 'MBCB type - Non-Spacer Design') {
            parsedConfig.forEach(field => {
                let label = this.reverseNonSpacerMap[field.apiName] || field.apiName;
                let savedValue = field.defaultValue !== undefined ? field.defaultValue : (field.formula || '0');

                reconstructedRows.push({
                    id: 'saved_row_' + (rowIndex++),
                    displayIndex: rowIndex,
                    cells: [
                        { column: 'Item', value: label, isReadOnly: true },
                        { column: 'Rate', value: String(savedValue), isReadOnly: false }
                    ]
                });
            });
        }
        else if (this.valueA === 'Telecom Tower - Department') {
            const savedByApi = {};
            parsedConfig.forEach(field => {
                if (field && field.apiName) {
                    savedByApi[field.apiName] = field.defaultValue !== undefined
                        ? field.defaultValue
                        : (field.formula || '0');
                }
            });

            Object.keys(this.telecomMap).forEach(label => {
                const apiName = this.telecomMap[label];
                const savedValue = savedByApi[apiName] !== undefined ? savedByApi[apiName] : '0';
                reconstructedRows.push({
                    id: 'saved_row_' + (rowIndex++),
                    displayIndex: rowIndex,
                    cells: [
                        { column: 'Item', value: label, isReadOnly: true },
                        { column: 'Rate', value: String(savedValue), isReadOnly: false }
                    ]
                });
            });
        }
        // 👉 ADD THIS: Reverse Engineering for Crash Tested
        else if (this.valueA === 'Crash Barrier - Department' && this.valueB === 'MBCB type - Crash Tested') {
            parsedConfig.forEach(field => {
                let label = this.reverseCrashTestedMap[field.apiName] || field.apiName;
                
                let savedValue = field.defaultValue !== undefined ? field.defaultValue : (field.formula || '0');

                reconstructedRows.push({
                    id: 'saved_row_' + (rowIndex++),
                    displayIndex: rowIndex,
                    cells: [
                        { column: 'Item', value: label, isReadOnly: true },
                        { column: 'Rate', value: String(savedValue), isReadOnly: false }
                    ]
                });
            });
        }

        else if (this.valueA === 'Steel Pipes - Department' && this.valueB === 'Domestic') {
            // 1. Get the complete default list of pipes so the UI is never empty
            const defaultItems = Object.keys(this.domesticPipesMap);
            let ratesMap = {};

            // 2. Safely extract saved rates from the database (handles both old Arrays and new Objects)
            if (Array.isArray(parsedConfig)) {
                parsedConfig.forEach(field => {
                    if (field.apiName) {
                        ratesMap[field.apiName] = field.defaultValue !== undefined ? field.defaultValue : (field.formula || '0');
                    }
                });
            } else if (parsedConfig && parsedConfig.apiName !== undefined) {
                ratesMap[parsedConfig.apiName] = parsedConfig.defaultValue !== undefined ? parsedConfig.defaultValue : '0';
            } else if (typeof parsedConfig === 'object' && parsedConfig !== null) {
                ratesMap = parsedConfig.baseRatesMap || parsedConfig.baseRates || parsedConfig.BASE_RATES || parsedConfig;
            }

            // 3. Rebuild rows by looking up the exact key
            defaultItems.forEach(item => {
                // 👉 THE FIX: Look up the exact 'item' (e.g., 'Black Steel|MS ERW'), not the mapped label!
                let savedValue = ratesMap[item];
                
                // Fallback for legacy mapped labels just in case older data used it
                if (savedValue === undefined) {
                    let legacyMappedName = this.domesticPipesMap[item];
                    savedValue = ratesMap[legacyMappedName] !== undefined ? ratesMap[legacyMappedName] : '0';
                }

                reconstructedRows.push({
                    id: 'saved_row_' + (rowIndex++),
                    displayIndex: rowIndex,
                    cells: [
                        { column: 'Item', value: item, isReadOnly: true },
                        { column: 'Rate', value: String(savedValue !== undefined ? savedValue : '0'), isReadOnly: false }
                    ]
                });
            });
        }

        else if (this.valueA === 'Steel Pipes - Department' && this.valueB === 'Export') {
            let ratesMap = {};

            if (Array.isArray(parsedConfig)) {
                parsedConfig.forEach(field => {
                    if (field.apiName) {
                        ratesMap[field.apiName] = field.defaultValue !== undefined ? field.defaultValue : (field.formula || '0');
                    }
                });
            } else if (parsedConfig && parsedConfig.apiName !== undefined && parsedConfig.baseRatesMap === undefined) {
                ratesMap[parsedConfig.apiName] = parsedConfig.defaultValue !== undefined ? parsedConfig.defaultValue : '0';
            } else if (typeof parsedConfig === 'object' && parsedConfig !== null) {
                ratesMap = parsedConfig.baseRatesMap || parsedConfig.baseRates || parsedConfig.BASE_RATES || parsedConfig;
            }

            // 👉 CLEANUP: Using 'exportPipesMap' to draw the grid
            const defaultMapKeys = this.exportPipesMap ? Object.keys(this.exportPipesMap) : [];
            const itemsToIterate = defaultMapKeys.length > 0 ? defaultMapKeys : Object.keys(ratesMap).filter(k => k !== 'apiName' && k !== 'label' && k !== 'type');

            itemsToIterate.forEach(item => {
                let savedValue = ratesMap[item];
                
                if (savedValue === undefined && this.exportPipesMap) {
                    let legacyMappedName = this.exportPipesMap[item];
                    savedValue = ratesMap[legacyMappedName] !== undefined ? ratesMap[legacyMappedName] : '0';
                }

                reconstructedRows.push({
                    id: 'saved_row_' + (rowIndex++),
                    displayIndex: rowIndex,
                    cells: [
                        { column: 'Item', value: item, isReadOnly: true },
                        { column: 'Rate', value: String(savedValue !== undefined ? savedValue : '0'), isReadOnly: false }
                    ]
                });
            });
        }

        // 👉 HDPE PIPE DEPARTMENT: RECONSTRUCT DATA FROM METADATA CONFIG
        else if (this.valueA === 'HDPE Pipe - Department') {
            let activeReverseMap = {};
            if (this.valueB === 'Standard - Pipe & Duct') activeReverseMap = this.reversehdpepipeAndDuct;
            else if (this.valueB === 'Standard - IS 4984') activeReverseMap = this.reversehdpeIs4984;
            else if (this.valueB === 'Standard - PLB Duct') activeReverseMap = this.reversehdpePlbDuct;
            else if (this.valueB === 'Standard - MDPE Pipe') activeReverseMap = this.reversemdpePipe;

            parsedConfig.forEach(field => {
                let label = activeReverseMap[field.apiName] || field.apiName;
                let savedValue = field.defaultValue !== undefined ? field.defaultValue : (field.formula || '0');
                reconstructedRows.push({
                    id: 'saved_row_' + (rowIndex++),
                    displayIndex: rowIndex,
                    cells: [
                        { column: 'Item', value: label, isReadOnly: true },
                        { column: 'Value', value: String(savedValue), isReadOnly: false }
                    ]
                });
            });
        }

        else if (this.valueA === 'Transmission Tower - Department' && this.valueB === 'Type of Product - Tower') {
            parsedConfig.forEach(field => {
                let label = this.reverseTransmissionTowerMap[field.apiName] || field.apiName;
                let savedValue = field.defaultValue !== undefined ? field.defaultValue : (field.formula || '0');
                reconstructedRows.push({
                    id: 'saved_row_' + (rowIndex++),
                    displayIndex: rowIndex,
                    cells: [
                        { column: 'Item', value: label, isReadOnly: true },
                        { column: 'Value', value: String(savedValue), isReadOnly: false }
                    ]
                });
            });
        }
        else if (this.valueA === 'Transmission Tower - Department' && this.valueB === 'Type of Product - Substation') {
            parsedConfig.forEach(field => {
                let label = this.reverseTransmissionSubstationMap[field.apiName] || field.apiName;
                let savedValue = field.defaultValue !== undefined ? field.defaultValue : (field.formula || '0');
                reconstructedRows.push({
                    id: 'saved_row_' + (rowIndex++),
                    displayIndex: rowIndex,
                    cells: [
                        { column: 'Item', value: label, isReadOnly: true },
                        { column: 'Value', value: String(savedValue), isReadOnly: false }
                    ]
                });
            });
        }
        else if (this.valueA === 'Transmission Tower - Department' && this.valueB === 'Nuts & Bolts Details') {
            // 1. Index saved values by apiName
            const savedByApi = {};
            parsedConfig.forEach(f => {
                if (f && f.apiName) {
                    savedByApi[f.apiName] = f.defaultValue !== undefined ? f.defaultValue : (f.formula || '0');
                }
            });

            // 2. Build rows from the MAP so newly added fields always appear
            Object.keys(this.nutsBoltsMap).forEach(label => {
                const apiName = this.nutsBoltsMap[label];
                const savedValue = savedByApi[apiName] !== undefined ? savedByApi[apiName] : '0';
                reconstructedRows.push({
                    id: 'saved_row_' + (rowIndex++),
                    displayIndex: rowIndex,
                    cells: [
                        { column: 'Item', value: label, isReadOnly: true },
                        { column: 'Value', value: String(savedValue), isReadOnly: false }
                    ]
                });
            });
        }

        if (reconstructedRows.length > 0) {
            this.gridData = reconstructedRows;
        } else {
            this.handleAddRow();
        }
    }

    handleAddRow() {
        const newCells = this.currentColumns.map(col => {
            const lowerCol = col.toLowerCase();
            const isReadOnly = !(lowerCol.includes('price') || lowerCol.includes('rate') || lowerCol === 'value' || lowerCol.includes('cost'));
            return { column: col, value: '', isReadOnly: isReadOnly };
        });
        
        this.gridData = [
            ...this.gridData, 
            { id: Date.now().toString(), displayIndex: this.gridData.length + 1, cells: newCells }
        ];
    }

    handleDeleteRow(event) {
        const index = event.currentTarget.dataset.index;
        this.gridData.splice(index, 1);
        
        this.gridData.forEach((row, idx) => { row.displayIndex = idx + 1; });
        this.gridData = [...this.gridData];
    }

    handleCellChange(event) {
        const rowIndex = event.currentTarget.dataset.row;
        const colName = event.currentTarget.dataset.col;
        const newVal = event.target.value;

        let newData = JSON.parse(JSON.stringify(this.gridData));
        let cell = newData[rowIndex].cells.find(c => c.column === colName);
        if (cell) cell.value = newVal;
        
        this.gridData = newData;
    }

    getFlatGridData() {
        return this.gridData.map(row => {
            let flatRow = {};
            row.cells.forEach(cell => { flatRow[cell.column] = cell.value; });
            return flatRow;
        });
    }

    openUploadModal() {
        this.isModalOpen = true;
        this.verificationResults = [];
    }

    closeModal() {
        this.isModalOpen = false;
        this.verificationResults = [];
    }

    readFile(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = event => resolve(new Uint8Array(event.target.result));
            reader.onerror = error => reject(error);
            reader.readAsArrayBuffer(file);
        });
    }

    async handleFileChange(event) {
        const file = event.target.files?.[0];
        if (!file) return;

        try {
            const data = await this.readFile(file);
            const workbook = window.XLSX.read(data, { type: 'array' });
            const sheetName = workbook.SheetNames[0];
            const parsedData = window.XLSX.utils.sheet_to_json(workbook.Sheets[sheetName]);
            
            const isValid = await this.verifyData(parsedData);
            
            if (isValid) {
                this.gridData = parsedData.map((row, idx) => {
                    let cells = this.currentColumns.map(col => {
                        const matchedKey = Object.keys(row).find(k => k.trim().toLowerCase() === col.trim().toLowerCase());
                        const lowerCol = col.toLowerCase();
                        const isReadOnly = !(lowerCol.includes('price') || lowerCol.includes('rate') || lowerCol === 'value' || lowerCol.includes('cost'));
                        
                        return { column: col, value: matchedKey ? String(row[matchedKey]) : '', isReadOnly: isReadOnly };
                    });
                    return { id: Date.now().toString() + idx, displayIndex: idx + 1, cells: cells };
                });
                
                this.closeModal();
                this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Excel loaded successfully! Review the grid and click Save.', variant: 'success' }));
            }
        } catch (error) {
            this.showError(error?.message || 'Unknown processing error.');
        }
    }

    async verifyData(data) {
        if (!Array.isArray(data) || data.length === 0) {
            throw new Error('The uploaded Excel sheet is empty.');
        }
        
        let errorCount = 0;
        this.verificationResults = data.map((row, index) => {
            const rowErrors = [];
            this.currentColumns.forEach(column => {
                const matchedKey = Object.keys(row).find(k => k.trim().toLowerCase() === column.trim().toLowerCase());
                const value = matchedKey ? row[matchedKey] : null;

                if (value === null || value === undefined || value === '') {
                    rowErrors.push(`${column} cannot be blank`);
                }
                
            });
            if (rowErrors.length) errorCount++;
            
            return {
                id: index + 1,
                status: rowErrors.length ? '❌ Error': '✅ Valid',
                message: rowErrors.length ? rowErrors.join(' | '): 'Passed validation'
            };
        });

        if (errorCount > 0) {
            await this.showError(`Validation failed. ${errorCount} row(s) contain errors.`);
            return false;
        }
        return true;
    }

    // ==========================================
    // SAVE AND GENERATE CONFIGURATION
    // ==========================================
   async handleSaveGrid() {
        this.isSaving = true;
        const flatData = this.getFlatGridData();

        let hasErrors = false;
        flatData.forEach(row => {
            this.currentColumns.forEach(col => {
                // 👉 FIX: Allow '0' to pass validation safely
                if (row[col] === undefined || row[col] === null || String(row[col]).trim() === '') {
                    hasErrors = true;
                }
            });
        });

        if (hasErrors) {
            this.showError('Please fill in all empty fields, or delete empty rows before saving.');
            this.isSaving = false;
            return;
        }

        // 👉 SAVE CORE PIPES INTO METADATA
        if (this.valueA === 'Steel Pipes - Department' && this.valueB === 'Core Pipes') {
            try {
                let ratesMap = {};
                flatData.forEach(row => {
                    let label = row['Item'];
                    let val = row['Rate'];
                    if (val === undefined || val === null || String(val).trim() === '') {
                        val = '0'; 
                    }
                    ratesMap[String(label).trim()] = Number(val);
                });

                let existingJsonStr = await getRateCardJson({ departmentName: 'Steel Pipe Domestic Config' });
                let parsedData = existingJsonStr ? JSON.parse(existingJsonStr) : {};

                // Attach under CORE_PIPE_RATES
                parsedData.CORE_PIPE_RATES = ratesMap;

                await savePriceCalculatorMetadata({ 
                    developerName: 'Steel_Pipe_Domestic_Config', 
                    jsonString: JSON.stringify(parsedData, null, 2) 
                });
                
                await LightningAlert.open({
                    message: `Successfully processed! The pricing rates for Core Pipes have been deployed to Price Calculator.`,
                    theme: 'success',
                    label: 'Save Complete'
                });
            } catch(e) {
                console.error(e);
                this.showError('Failed to save to Price Calculator: ' + (e.body ? e.body.message : e.message));
            }
        }
        else if (this.valueA === 'Solar Structure - Department') {
            let finalMergedConfig = [];

            if (this.valueB === 'Global Zinc Rate') {
                let flatZincRate = flatData[0] ? flatData[0]['Rate'] : '0';
                
                let zincConfig = {
                    apiName: `hdg_zinc_rate`,
                    label: "ZINC RATE",
                    type: "number",
                    isCalculated: true,
                    readOnly: true,
                    formula: String(flatZincRate),
                    ignoreFormulaIfProvided: true
                };

                if (this.fullExistingDatabaseConfig && this.fullExistingDatabaseConfig.length > 0) {
                    finalMergedConfig = this.fullExistingDatabaseConfig.filter(f => f.apiName !== 'hdg_zinc_rate');
                }
                finalMergedConfig.push(zincConfig);
            } 
            else {
                let ratesMap = {};
                flatData.forEach(row => {
                    let label = row['Item'];
                    let val = row['Rate'];
                    if (val === undefined || val === null || String(val).trim() === '') val = '0';
                    let apiName = this.solarStructureMap[label] || label;
                    ratesMap[apiName] = Number(val);
                });

                let suffix = this.valueB.includes('Pcs') ? '_pcs' : '_wt';
                let baseRatesObj = {
                    apiName: "rate" + suffix,
                    label: "RATE (Rs./MTR)",
                    type: "number",
                    BASE_RATES: ratesMap
                };
                
                if (this.fullExistingDatabaseConfig && this.fullExistingDatabaseConfig.length > 0) {
                    // Filter out any legacy rate fields and any previously saved base rates object
                    finalMergedConfig = this.fullExistingDatabaseConfig.filter(f => f.apiName !== ('rate' + suffix) && f.apiName !== 'rate' && f.apiName !== 'hdg_steel_rate_wt' && f.apiName !== 'galv_steel_rate_wt' && f.apiName !== 'hdg_steel_rate_pcs' && f.apiName !== 'galv_steel_rate_pcs');
                }
                finalMergedConfig.push(baseRatesObj);
            }

            this.fullExistingDatabaseConfig = finalMergedConfig;
            await this.saveJsonToSalesforce(finalMergedConfig, 'Solar_Structure', 'Solar Structure - Department', null, this.valueA);
        }
        
        // 👉 HDPE PIPE DEPARTMENT: MAP VALUES INTO API LABELS AND PROCESS PERSISTENCE
        else if (this.valueA === 'HDPE Pipe - Department') {
            let activeForwardMap = {};
            let metadataGroup = '';
            let metadataLabel = '';
            let department = '';

            if (this.valueB === 'Standard - Pipe & Duct') {
                activeForwardMap = this.hdpepipeAndDuct;
                metadataGroup = 'pipe_and_duct_price';
                metadataLabel = 'Pipe & Duct';
                department = 'Pipe & Duct';
            } else if (this.valueB === 'Standard - IS 4984') {
                activeForwardMap = this.hdpeIs4984;
                metadataGroup = 'IS_4984_Price';
                metadataLabel = 'IS_4984_Price';
                department = 'IS 4984';
            } else if (this.valueB === 'Standard - PLB Duct') {
                activeForwardMap = this.hdpePlbDuct;
                metadataGroup = 'PLB_Duct_Price';
                metadataLabel = 'PLB_Duct_Price';
                department = 'PLB Duct';
            } else if (this.valueB === 'Standard - MDPE Pipe') {
                activeForwardMap = this.mdpePipe;
                metadataGroup = 'MDPE_Pipe_Price';
                metadataLabel = 'MDPE_Pipe_Price';
                department = 'MDPE Pipe';
            }

            let finalMergedConfig = flatData.map(row => {
                let label = row['Item'];
                let val = row['Value'];

                if (val === undefined || val === null || String(val).trim() === '') {
                    val = '0';
                }
                let apiName = activeForwardMap[label] || label;

                return {
                    apiName: apiName,
                    defaultValue: Number(val)
                };
            });

            await this.saveJsonToSalesforce(finalMergedConfig, metadataGroup, metadataLabel, null, department);
        }

        else if (this.valueB === 'Type of Pole - Standard' || this.valueB === 'Type of Pole - Customized') {
            let finalMergedConfig = flatData.map(row => {
                let label = row['Item'];
                let rate = row['Rate'];
                let apiName = this.poleApiMap[label] || label;
                
                return {
                    apiName: apiName,
                    defaultValue: String(rate)
                };
            });

            let devName = this.valueB === 'Type of Pole - Customized' ? 'Customized_Pole' : 'Standard_Pole';
            let labelName = this.valueB === 'Type of Pole - Customized' ? 'Customized Pole' : 'Standard Pole';

            await this.saveJsonToSalesforce(finalMergedConfig, devName, labelName, null, labelName);
        }

        else if (this.valueA === 'Crash Barrier - Department' && this.valueB === 'MBCB type - Conventional Type') {
            let finalMergedConfig = flatData.map(row => {
                let label = row['Item'];
                let val = row['Rate']; 
                
                if (val === undefined || val === null || String(val).trim() === '') {
                    val = '0'; 
                }
                
                let apiName = this.crashBarrierConvMap[label] || label;
                
                return {
                    apiName: apiName,
                    defaultValue: Number(val)
                };
            });

            await this.saveJsonToSalesforce(finalMergedConfig, 'Crash_Barrier_Conventional', 'Crash Barrier Conventional', null, 'Conventional Type');
        }
        // 👉 ROUTER LOGIC FOR NOISE BARRIER SAVE HANDLER
        else if (this.valueA === 'Crash Barrier - Department' && this.valueB === 'MBCB type - Noise Barrier') {
            let finalMergedConfig = flatData.map(row => {
                let label = row['Item'];
                let val = row['Rate'];

                if (val === undefined || val === null || String(val).trim() === '') {
                    val = '0';
                }

                let apiName = this.noiseBarrierMap[label] || label;

                return {
                    apiName: apiName,
                    defaultValue: Number(val)
                };
            });

            await this.saveJsonToSalesforce(finalMergedConfig, 'Noise_Barrier', 'Noise Barrier', null, 'Noise Barrier');
        }
        // 👉 ADD THIS: Save logic for Crash Tested
        else if (this.valueA === 'Crash Barrier - Department' && this.valueB === 'MBCB type - Crash Tested') {
            let finalMergedConfig = flatData.map(row => {
                let label = row['Item'];
                let val = row['Rate'];
                
                if (val === undefined || val === null || String(val).trim() === '') {
                    val = '0'; 
                }

                let apiName = this.crashTestedMap[label] || label;
                
                return {
                    apiName: apiName,
                    defaultValue: Number(val) 
                };
            });

            
            await this.saveJsonToSalesforce(finalMergedConfig, 'Crash_Barrier_Crash_Tested', 'Crash Tested', null, 'Crash Tested');
        }
        // 👉 ADD THIS: Save logic for Railway
        else if (this.valueA === 'Crash Barrier - Department' && this.valueB === 'MBCB type - Railway') {
            let finalMergedConfig = flatData.map(row => {
                let label = row['Item'];
                let val = row['Rate'];
                
                if (val === undefined || val === null || String(val).trim() === '') {
                    val = '0'; 
                }

                let apiName = this.railwayMap[label] || label;
                
                return {
                    apiName: apiName,
                    defaultValue: Number(val) 
                };
            });

            await this.saveJsonToSalesforce(finalMergedConfig, 'Crash_Barrier_Railway', 'Railway', null, 'Railway');
        }
        // 👉 ADD THIS: Save logic for Non-Spacer Design
        else if (this.valueA === 'Crash Barrier - Department' && this.valueB === 'MBCB type - Non-Spacer Design') {
            let finalMergedConfig = flatData.map(row => {
                let label = row['Item'];
                let val = row['Rate'];
                
                if (val === undefined || val === null || String(val).trim() === '') {
                    val = '0'; 
                }

                let apiName = this.nonSpacerMap[label] || label;
                
                return {
                    apiName: apiName,
                    defaultValue: Number(val) 
                };
            });

            await this.saveJsonToSalesforce(finalMergedConfig, 'Crash_Barrier_Non_Spacer', 'Non-Spacer Design', null, 'Non-Spacer Design');
        }
        else if (this.valueA === 'Telecom Tower - Department' ) {
            let finalMergedConfig = flatData.map(row => {
                let label = row['Item'];
                let val = row['Rate'];
                
                if (val === undefined || val === null || String(val).trim() === '') {
                    val = '0'; 
                }

                let apiName = this.telecomMap[label] || label;
                
                return {
                    apiName: apiName,
                    defaultValue: Number(val) 
                };
            });

            await this.saveJsonToSalesforce(finalMergedConfig, 'Telecom_Tower_Conventional', 'Telecom Tower Conventional', null, 'Telecom Tower - Department');
        } 
        else if (this.valueA === 'Steel Pipes - Department' && this.valueB === 'Domestic') {
            try {
                let ratesMap = {};
                flatData.forEach(row => {
                    let label = row['Item'];
                    let val = row['Rate'];
                    if (val === undefined || val === null || String(val).trim() === '') {
                        val = '0'; 
                    }
                    ratesMap[String(label).trim()] = Number(val);
                });

                let existingJsonStr = await getRateCardJson({ departmentName: 'Steel Pipe Domestic Config' });
                let parsedData = existingJsonStr ? JSON.parse(existingJsonStr) : {};

                if (parsedData.BASE_RATES !== undefined) {
                    parsedData.BASE_RATES = ratesMap;
                } else if (parsedData.baseRates !== undefined) {
                    parsedData.baseRates = ratesMap;
                } else {
                    parsedData.BASE_RATES = ratesMap;
                }

                await savePriceCalculatorMetadata({ 
                    developerName: 'Steel_Pipe_Domestic_Config', 
                    jsonString: JSON.stringify(parsedData, null, 2) 
                });
                
                await LightningAlert.open({
                    message: `Successfully processed! The pricing rates for Domestic Steel have been deployed to Price Calculator.`,
                    theme: 'success',
                    label: 'Save Complete'
                });
            } catch(e) {
                console.error(e);
                this.showError('Failed to save to Price Calculator: ' + (e.body ? e.body.message : e.message));
            }
        }

        else if (this.valueA === 'Steel Pipes - Department' && this.valueB === 'Export') {
            try {
                let ratesMap = {};
                flatData.forEach(row => {
                    let label = row['Item'];
                    let val = row['Rate'];
                    if (val === undefined || val === null || String(val).trim() === '') {
                        val = '0'; 
                    }
                    ratesMap[String(label).trim()] = Number(val);
                });

                // 👉 Ensures we don't wipe out Weight Maps when updating Base Rates
                let existingJsonStr = await getRateCardJson({ departmentName: 'Steel Pipe Export Config' });
                let parsedData = existingJsonStr ? JSON.parse(existingJsonStr) : {};

                parsedData.BASE_RATES = ratesMap;

                // 👉 Writes directly to JSON_Payload__c and links to the correct Department
                await this.saveJsonToSalesforce(
                    parsedData, 
                    'Steel_Pipes_Export', 
                    'Export', 
                    null, 
                    'Steel Pipe Export Config'
                );
                
            } catch(e) {
                console.error(e);
                this.showError('Failed to save to Price Calculator: ' + (e.body ? e.body.message : e.message));
            }
        }

        else if (this.valueA === 'Transmission Tower - Department' && this.valueB === 'Type of Product - Tower') {
            let finalMergedConfig = flatData.map(row => {
                let label = row['Item'];
                let val = row['Value'];
                if (val === undefined || val === null || String(val).trim() === '') val = '0';
                let apiName = this.transmissionTowerMap[label] || label;
                return { apiName: apiName, defaultValue: Number(val) };
            });
            await this.saveJsonToSalesforce(finalMergedConfig, 'Transmission_Tower_Product', 'Transmission Tower Product', null, 'Type of Product - Tower');
        }
        else if (this.valueA === 'Transmission Tower - Department' && this.valueB === 'Type of Product - Substation') {
            let finalMergedConfig = flatData.map(row => {
                let label = row['Item'];
                let val = row['Value'];
                if (val === undefined || val === null || String(val).trim() === '') val = '0';
                let apiName = this.transmissionSubstationMap[label] || label;
                return { apiName: apiName, defaultValue: Number(val) };
            });
            await this.saveJsonToSalesforce(finalMergedConfig, 'Transmission_Substation', 'Transmission Substation', null, 'Type of Product - Substation');
        }
        else if (this.valueA === 'Transmission Tower - Department' && this.valueB === 'Nuts & Bolts Details') {
            let finalMergedConfig = flatData.map(row => {
                let label = row['Item'];
                let val = row['Value'];
                if (val === undefined || val === null || String(val).trim() === '') val = '0';
                let apiName = this.nutsBoltsMap[label] || label;
                return { apiName: apiName, defaultValue: Number(val) };
            });
            await this.saveJsonToSalesforce(finalMergedConfig, 'Transmission_Nuts_Bolts', 'Transmission Nuts & Bolts', null, 'Nuts & Bolts Details');
        }
        this.isSaving = false;
    }

    async saveJsonToSalesforce(configObj, targetRecordName, targetLabel, baseAmountValue = null, targetDepartment) {
        try {
            await saveToMetadata({ 
                recordDeveloperName: targetRecordName,
                recordLabel: targetLabel,
                jsonString: configObj ? JSON.stringify(configObj) : '', 
                baseAmount: baseAmountValue,
                departmentName: targetDepartment 
            });
            
            await LightningAlert.open({
                message: `Successfully processed! The pricing rates for ${this.valueB} have been saved to the database.`,
                theme: 'success',
                label: 'Save Complete'
            });

        } catch (error) {
            console.error('Apex Save Error:', error);
            this.showError('Failed to save to Metadata: ' + (error.body ? error.body.message : error.message));
        }
    }

   
   // ==========================================
    // UPDATED SOLAR STRUCTURE CONFIG GENERATOR
    // ==========================================
    generateSolarStructureConfig(parsedExcelData) {
        let hdgSegments = [];
        let galvSegments = [];
        
        let suffix = this.valueB.includes('Pcs') ? '_pcs' : '_wt';

        parsedExcelData.forEach(row => {
            let item = String(row['Item'] || '').trim();
            let rate = row['Rate'] !== undefined && row['Rate'] !== null ? String(row['Rate']).trim() : '0';

            // 1. Build individual formula segments for HDG Materials
            if (['HDG MMS Structure', 'Carport Structure', 'Piers (W-Beam) for Tracker', 'I-BEAM', 'RSJ', 'H-Beam', 'W-Beam'].includes(item)) {
                hdgSegments.push(`(hdg_material == '${item}') ? ${rate}`);
            } 
            // 2. Build individual formula segments for Galvalume & Black Materials
            else if (['Black Metal', 'Galvalume', 'I-Beam (Black)', 'W-Beam (Black)', 'H-Beam (Black)', 'Piers for Tracker (Black)'].includes(item)) {
                let formattedMaterial = item === 'Galvalume' ? 'Galvalume Structure' : item;
                galvSegments.push(`(galv_material == '${formattedMaterial}') ? ${rate}`);
            }
        });

        // Combine segments into the final ternary formula string
        const hdgFormula = hdgSegments.length > 0 ? hdgSegments.join(' : ') + ' : 0' : '0';
        const galvFormula = galvSegments.length > 0 ? galvSegments.join(' : ') + ' : 0' : '0';

        return [
            {
                apiName: `hdg_steel_rate${suffix}`, 
                label: "STEEL RATE",
                type: "number",
                isCalculated: true,
                readOnly: true,
                formula: hdgFormula,
                ignoreFormulaIfProvided: true
            },
            {
                apiName: `galv_steel_rate${suffix}`, 
                label: "STEEL RATE",
                type: "number",
                isCalculated: true,
                readOnly: true,
                formula: galvFormula,
                ignoreFormulaIfProvided: true
            }
        ];
    }

    generateHDPEPipeConfig(parsedExcelData) {
        let suffix = this.valueB.includes('PLB') ? '_plb' : '_is4984';
        let formula = '0';

        if (this.valueB.includes('PLB Duct')) {
            let segments = [];
            parsedExcelData.forEach(row => {
                let item = String(row['Item'] || '').trim();
                let value = String(row['Value'] || '').trim();
                
                if (item && value) {
                    segments.push(`(Diameter_Size == '${item}') ? ${value}`);
                }
            });
            
            formula = segments.length > 0 ? segments.join(' : ') + ' : 0' : '0';

            if (parsedExcelData.length === 1 && parsedExcelData[0]['Value']) {
                formula = String(parsedExcelData[0]['Value']).trim();
            }

        } else {
            let segments = [];
            parsedExcelData.forEach(row => {
                let dia = String(row['Pipe Diameter'] || '').trim();
                let pn = String(row['PN Rating'] || '').trim();
                let pe = String(row['PE Grade'] || '').trim();
                let price = String(row['Price Per Meter'] || '').trim();
                
                if (dia && pn && pe && price) {
                    segments.push(`(Diameter_Size == '${dia}' && Pressure_rating_select == '${pn}' && PE_Grade_select == '${pe}') ? ${price}`);
                }
            });
            formula = segments.length > 0 ? segments.join(' : ') + ' : 0' : '0';
        }

        return [{
            apiName: `Realization_raw_material_conversion_cost_Kg${suffix}`,
            label: "Realization raw material+ conversion cost/ Kg",
            type: "number",
            isCalculated: true,
            isBasePrice: true,
            colSpan: 6,
            readOnly: true,
            formula: formula,
            ignoreFormulaIfProvided: true
        }];
    }

    async showError(message) {
        try {
            await LightningAlert.open({ message, theme: 'error', label: 'Validation Error' });
        } catch (error) {
            console.error('LightningAlert Error:', error);
        }
    }


    // ==========================================
    // HIGH MAST SAVE HANDLER
    // ==========================================

    get isHighMast() {
        return this.valueA === 'High Mast - Department';
    }

    async handleSaveHighMast() {
        this.isSaving = true;
        try {
            const hmDevName = this.highMastRecordMap[this.valueB];
            if (!hmDevName) {
                this.showError('No Price Calculator record mapped for: ' + this.valueB);
                this.isSaving = false;
                return;
            }

            const flatData = this.getFlatGridData();
            let baseAmt = null;
            let addOnAmt = null;

            for (const row of flatData) {
                const label = String(row['Item'] || '').trim();
                const raw = row['Value'];

                if (raw === undefined || raw === null || String(raw).trim() === '') {
                    this.showError(`${label} cannot be blank. Enter 0 if it does not apply.`);
                    this.isSaving = false;
                    return;
                }

                const num = Number(raw);
                if (isNaN(num)) {
                    this.showError(`${label} must be a number.`);
                    this.isSaving = false;
                    return;
                }

                if (label === 'Base Amount')   baseAmt = num;
                if (label === 'Add On Amount') addOnAmt = num;
            }

            await saveHighMastAmounts({
                developerName: hmDevName,
                baseAmount: baseAmt,
                addOn: addOnAmt
            });

            await LightningAlert.open({
                message: `Amounts for ${this.valueB} have been queued for deployment. Allow a minute before they take effect.`,
                theme: 'success',
                label: 'Save Complete'
            });
        } catch (e) {
            console.error('High Mast save error:', e);
            this.showError('Failed to save High Mast amounts: ' + (e.body ? e.body.message : e.message));
        } finally {
            this.isSaving = false;
        }
    }
}
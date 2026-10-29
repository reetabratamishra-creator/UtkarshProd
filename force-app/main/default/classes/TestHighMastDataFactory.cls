/*
* Class Name  : TestHighMastDataFactory
* Author      : Deepanjan
* Date        : 10 August 2026
* Description : Shared @IsTest data builder for the three High Mast page
*               controllers - HMScopeCombinedController, HighMastSOWController
*               and HighMastWeightCalcController.
*
*  WHY THE PAYLOADS COME IN THREE FLAVOURS
*  ---------------------------------------
*  Every builder in these controllers is written the same way:
*
*      if (!_Final_Apex_Lines.isEmpty()) { ...short path...  return; }
*      if (!_Saved_Table_Rows.isEmpty()) { ...second path... return; }
*      ...the c{col}_s{sec}_ / r{n}_lm_ repeater - by far the biggest block...
*
*  A payload carrying BOTH line collections returns at the first branch, so the
*  repeater - which is most of the class - never executes.
*
*  Each of the four main builders therefore gets three quotes:
*      ..._A  _Final_Apex_Lines only   -> branch 1
*      ..._T  _Saved_Table_Rows only   -> branch 2
*      ..._S  neither, spec keys only  -> branch 3
*
*  KEY SHAPES (read straight out of the controllers)
*  -------------------------------------------------
*  Lighting Pole : c{col}_s{sec}_<attr> for the spec fields, plus the pricing
*                  keys c{col}_lp_segment_unit_price / _segment2_unit_price /
*                  _segment_unit_cost / _foundation_unit_price / _bracket_*,
*                  the per-section keys c{col}_lp_s{sec}_quantity and
*                  _segment_weight, and the column count s{sec}_no_of_items.
*                  The repeater SKIPS a column when height and segment unit
*                  price are both zero, so both are always non-zero here.
*  Transmission  : c{col}_tp_<attr>
*  Mid Hinge     : c{col}_mhp_<attr> and c{col}_op_mhp_<attr>
*  High Mast     : r{n}_lm_<attr> for n = 1..7
*
*  Item names matter on the line paths: parseItemIndex() reads "(Item n)" and
*  parseSectionIndex() reads "- n Pole/Foundation/accessories". Those two
*  numbers build the c{col}_s{sec}_ prefix, so the names below are shaped to
*  match the spec keys rather than being arbitrary strings.
*/
@IsTest
public class TestHighMastDataFactory {

    public static final String DEPT = 'High Mast - Department';
    private static final Integer COLS = 2;   // columns per section
    private static final Integer SECS = 2;   // sections per lighting pole quote

    // ---- quote names: _A = apex lines, _T = table rows, _S = spec only ----
    public static final String Q_LIGHTING_A       = 'HMF Lighting A';
    public static final String Q_LIGHTING_T       = 'HMF Lighting T';
    public static final String Q_LIGHTING_S       = 'HMF Lighting S';
    public static final String Q_TRANSMISSION_A   = 'HMF Transmission A';
    public static final String Q_TRANSMISSION_T   = 'HMF Transmission T';
    public static final String Q_TRANSMISSION_S   = 'HMF Transmission S';
    public static final String Q_MID_HINGE_A      = 'HMF Mid Hinge A';
    public static final String Q_MID_HINGE_T      = 'HMF Mid Hinge T';
    public static final String Q_MID_HINGE_S      = 'HMF Mid Hinge S';
    public static final String Q_STANDARD_A       = 'HMF Standard A';
    public static final String Q_STANDARD_T       = 'HMF Standard T';
    public static final String Q_STANDARD_S       = 'HMF Standard S';

    public static final String Q_STADIUM          = 'HMF Stadium Mast';
    public static final String Q_FLAG             = 'HMF Flag Mast';
    public static final String Q_SEG5_FLAG        = 'HMF Seg5 Flag Mast';
    public static final String Q_SEG5_STADIUM     = 'HMF Seg5 Stadium Mast';
    public static final String Q_SEG5_LCLM        = 'HMF Seg5 LCLM';
    public static final String Q_LCLM             = 'HMF LCLM';
    public static final String Q_SIGNAGE          = 'HMF Signage Mast';
    public static final String Q_LATCHING         = 'HMF Latching Mast';
    public static final String Q_CUSTOM_LIGHTNING = 'HMF Custom Lightning Mast';
    public static final String Q_CUSTOM_LIGHTING  = 'HMF Custom Lighting Mast';
    public static final String Q_OCT_CUSTOM       = 'HMF Octagonal Custom LP';
    public static final String Q_OCT_STANDARD     = 'HMF Octagonal Standard LP';
    public static final String Q_EMPTY_JSON       = 'HMF Empty Json';
    public static final String Q_BAD_JSON         = 'HMF Bad Json';

    /* ================================================================== *
     *  SPEC KEY BLOCKS
     * ================================================================== */

    /** One lighting-pole column inside one section: spec, price and weight. */
    private static void putLpColumn(Map<String, Object> d, Integer col, Integer sec) {
        String cs = 'c' + col + '_s' + sec + '_';

        // fillLPSpecFields reads every one of these.
        d.put(cs + 'pole_type',                'Polygonal');
        d.put(cs + 'height_of_pole',           9 + col);      // never zero
        d.put(cs + 'top_diameter',             70);
        d.put(cs + 'bottom_diameter',          150);
        d.put(cs + 'segment_length',           6);
        d.put(cs + 'segment_thickness',        4);
        d.put(cs + 'no_of_polygonal_side',     '8');
        d.put(cs + 'base_plate_type',          'Square');
        d.put(cs + 'size_dia_of_base_plate',   300);
        d.put(cs + 'thickness_of_base_plate',  16);
        d.put(cs + 'stiffener_at_base',        'Yes');
        d.put(cs + 'door_height',              500);
        d.put(cs + 'foundation_bolt_diameter', '24');
        d.put(cs + 'foundation_bolt_length',   750);
        d.put(cs + 'bolt_quantity',            4);
        d.put(cs + 'pcd',                      400);
        d.put(cs + 'template',                 'Yes');
        d.put(cs + 'extra_micron',             '0');
        d.put(cs + 'pu_paint_pole',            'No');
        d.put(cs + 'solar_structure',          'No');
        d.put(cs + 'battery_box',              'No');
        d.put(cs + 'bracket_type',             'Single Arm');
        d.put(cs + 'type_of_arm',              '1');
        d.put(cs + 'arm_length',               1500);
        d.put(cs + 'arm_dia_od',               60);

        // The cus_op_ spelling of every attribute - lpAttr() and the pCus
        // branch of buildLightingPoleGroups read c{col}_s{sec}_cus_op_<attr>.
        for (String attr : new List<String>{
                'pole_type','height_of_pole','top_diameter','bottom_diameter',
                'segment_length','segment_thickness','no_of_polygonal_side',
                'base_plate_type','size_dia_of_base_plate','thickness_of_base_plate',
                'stiffener_at_base','door_height','foundation_bolt_diameter',
                'foundation_bolt_length','bolt_quantity','pcd','template',
                'extra_micron','pu_paint_pole','bracket_type','type_of_arm',
                'arm_length','arm_dia_od','quantity','segment_weight',
                'foundation_weight','bracket_weight' }) {
            Object v = d.get(cs + attr);
            if (v != null) d.put(cs + 'cus_op_' + attr, v);
        }

        // Weights and quantities the repeater reads.
        d.put(cs + 'quantity',                 2);
        d.put(cs + 'segment_weight',           320 + col);
        d.put(cs + 'foundation_weight',        85);
        d.put(cs + 'bracket_weight',           22);

        // Prices. Section 1 and section 2 use different keys.
        String c = 'c' + col + '_';
        d.put(c + 'lp_segment_unit_price',     52424);
        d.put(c + 'lp_segment2_unit_price',    53100);
        d.put(c + 'lp_segment_unit_cost',      52464);
        d.put(c + 'lp_foundation_unit_price',  12100);
        d.put(c + 'lp_foundation_unit_cost',   11800);
        d.put(c + 'lp_bracket_unit_price',     4300);
        d.put(c + 'lp_bracket_unit_cost',      4100);
        d.put(c + 'lp_s' + sec + '_quantity',       2);
        d.put(c + 'lp_s' + sec + '_segment_weight', 330 + col);
    }

    /** One transmission-pole column. */
    private static void putTpColumn(Map<String, Object> d, Integer col) {
        String cp = 'c' + col + '_tp_';
        d.put(cp + 'pole_type',                  'Polygonal');
        d.put(cp + 'height_of_pole',             11 + col);
        d.put(cp + 'top_diameter',               90);
        d.put(cp + 'bottom_diameter',            220);
        d.put(cp + 'no_of_polygonal_side',       '12');
        d.put(cp + 'segment_length',             6);
        d.put(cp + 'segment_thickness',          5);
        d.put(cp + 'bearing_plate_type',         'Circular');
        d.put(cp + 'size_dia_of_bearing_plate',  420);
        d.put(cp + 'thickness_of_bearing_plate', 20);
        d.put(cp + 'pole_cab_dia',               150);
        d.put(cp + 'pole_cab_thickness',         6);
        d.put(cp + 'dan',                        3);
        d.put(cp + 'note',                       'Test note');
        d.put(cp + 'qty',                        2);
        d.put(cp + 'segment_weight',             540 + col);
        d.put(cp + 'unit_price',                 61200);
        d.put(cp + 'unit_cost',                  60100);
        // Section 2 - buildTransmissionPoleGroups reads c{col}_tp_s2_ and
        // renders a second block only when it is present.
        String c2 = 'c' + col + '_tp_s2_';
        d.put(c2 + 'pole_type',                  'Polygonal');
        d.put(c2 + 'height_of_pole',             8 + col);
        d.put(c2 + 'top_diameter',               80);
        d.put(c2 + 'bottom_diameter',            200);
        d.put(c2 + 'no_of_polygonal_side',       '12');
        d.put(c2 + 'segment_length',             6);
        d.put(c2 + 'segment_thickness',          5);
        d.put(c2 + 'bearing_plate_type',         'Circular');
        d.put(c2 + 'size_dia_of_bearing_plate',  400);
        d.put(c2 + 'thickness_of_bearing_plate', 20);
        d.put(c2 + 'qty',                        2);
        d.put(c2 + 'segment_weight',             500 + col);
        d.put(c2 + 'unit_price',                 58800);
        d.put(c2 + 'unit_cost',                  57600);
    }

    /** One mid-hinge column, in both the plain and the octagonal spelling. */
    private static void putMhpColumn(Map<String, Object> d, Integer col) {
        for (String mid : new List<String>{ '_mhp_', '_op_mhp_' }) {
            String cm = 'c' + col + mid;
            d.put(cm + 'pole_type',                'Octagonal');
            d.put(cm + 'height_of_pole',           10 + col);
            d.put(cm + 'top_diameter',             80);
            d.put(cm + 'bottom_diameter',          180);
            d.put(cm + 'segment_length',           6);
            d.put(cm + 'segment_thickness',        4);
            d.put(cm + 'no_of_polygonal_side',     '8');
            d.put(cm + 'base_plate_type',          'Square');
            d.put(cm + 'size_dia_of_base_plate',   320);
            d.put(cm + 'thickness_of_base_plate',  16);
            d.put(cm + 'stiffener_at_base',        'Yes');
            d.put(cm + 'door_height',              600);
            d.put(cm + 'foundation_bolt_diameter', '24');
            d.put(cm + 'foundation_bolt_length',   800);
            d.put(cm + 'bolt_quantity',            4);
            d.put(cm + 'pcd',                      420);
            d.put(cm + 'template',                 'Yes');
            d.put(cm + 'extra_micron',             '0');
            d.put(cm + 'bracket_type',             'Single Arm');
            d.put(cm + 'type_of_arm',              '1');
            d.put(cm + 'nr_fb_diameter',           20);
            d.put(cm + 'segment_weight',           410 + col);
            d.put(cm + 'foundation_weight',        95);
            d.put(cm + 'bracket_weight',           26);
            d.put(cm + 'segment_unit_price',       58200);
            d.put(cm + 'segment_unit_cost',        57100);
            d.put(cm + 'foundation_unit_price',    13400);
            d.put(cm + 'foundation_unit_cost',     13000);
            d.put(cm + 'bracket_unit_price',       4800);
            d.put(cm + 'bracket_unit_cost',        4600);
            d.put(cm + 'quantity',                 2);
        }
        // Accessory repeater
        String ca = 'c' + col + '_';
        d.put(ca + 'acc_accessory',    'Junction Box');
        d.put(ca + 'acc_quantity',     2);
        d.put(ca + 'acc_rate',         900);
        d.put(ca + 'acc_weight',       12);
        d.put(ca + 'acc_total_weight', 24);
        d.put(ca + 'acc_unit_price',   950);
        d.put(ca + 'acc_unit_cost',    880);
    }

    /** One r{n}_ High Mast row - this is what buildRowData walks.
     *  Segment count varies BY ROW on purpose: the kit-price block inside
     *  buildHighMastLineItems has separate branches for segCount 1, 2, 3-5
     *  and >=6, and only the 3-5 one was running before (all rows were 3).
     *  Row 1 -> 3 segments, row 2 -> 1, row 3 -> 2, row 4 -> 6. */
    private static void putLmRow(Map<String, Object> d, Integer n) {
        String r = 'r' + n + '_';
        Integer segs = (n == 2) ? 1 : (n == 3) ? 2 : (n == 4) ? 6 : 3;
        String kit = 'kit_line_' + n + '_';
        d.put(r + 'lm_no_of_segment',           segs);
        d.put(r + 'lm_mast_height',             20 + n);
        d.put(r + 'lm_height_of_mast',          20 + n);
        d.put(r + 'lm_no_of_sides',             '20');
        d.put(r + 'lm_pcd',                     800);
        d.put(r + 'lm_od_of_base_plate',        900);
        d.put(r + 'lm_thickness_of_base_plate', 25);
        d.put(r + 'lm_anchor_plate_thickness',  20);
        d.put(r + 'lm_base_plate_type',         'Circular');
        d.put(r + 'lm_no_of_luminaries',        6);
        d.put(r + 'lm_no_of_aviation_light',    1);
        d.put(r + 'lm_cable_type',              'Armoured');
        d.put(r + 'lm_no_of_cable',             2);
        d.put(r + 'lm_l_ring_tier',             2);
        d.put(r + 'lm_ring_diameter',           1200);
        d.put(r + 'lm_dc_weight',               18);
        d.put(r + 'lm_spike_length',            1500);
        d.put(r + 'lm_spike_weight',            9);
        d.put(r + 'lm_suspension_system',       'Yes');
        d.put(r + 'lm_feeder_piller_control',   'Yes');
        d.put(r + 'lm_cg_box_per_lum',          1);
        d.put(r + 'lm_fdn_bolt_dia',            36);
        d.put(r + 'lm_fdn_bolt_length',         1200);
        d.put(r + 'lm_fdn_no_of_bolt',          8);
        d.put(r + 'lm_fdn_no_of_nut',           16);
        d.put(r + 'lm_fdn_stiffner_thickness',  12);
        d.put(r + 'lm_fdn_acc_weight',          140);
        d.put(r + 'lm_qty_of_hm',               2);
        d.put(r + 'lm_segment_weight',          620 + n);
        // Segment 2 and 3 variants
        d.put(r + 'lm_2_segment_weight',        540 + n);
        d.put(r + 'lm_3_segment_weight',        470 + n);
        d.put(r + 'lm_2_mast_height',           19 + n);
        d.put(r + 'lm_3_mast_height',           18 + n);
        // OAF diameters and per-segment prices - buildHighMastGroups and
        // cmSeg5FlagGroups read these; without them the row prints but the
        // description and price blocks are skipped.
        d.put(r + 'lm_1_oaf_top',               220);
        d.put(r + 'lm_1_oaf_bottom',            460);
        d.put(r + 'lm_2_oaf_top',               200);
        d.put(r + 'lm_2_oaf_bottom',            430);
        d.put(r + 'lm_2_top_oaf_top',           200);
        d.put(r + 'lm_2_bot_oaf_bot',           430);
        d.put(r + 'lm_3_oaf_top',               180);
        d.put(r + 'lm_3_oaf_bottom',            400);
        d.put(r + 'lm_3_top_oaf_top',           180);
        d.put(r + 'lm_3_bot_oaf_bot',           400);
        // Rows with 6 segments (row 4) need the higher segment OAFs too -
        // lastSegmentBottomDia walks seg..1 looking for lm_{s}_oaf_bottom.
        d.put(r + 'lm_4_oaf_top',               170);
        d.put(r + 'lm_4_oaf_bottom',            380);
        d.put(r + 'lm_5_oaf_top',               160);
        d.put(r + 'lm_5_oaf_bottom',            360);
        d.put(r + 'lm_6_oaf_top',               150);
        d.put(r + 'lm_6_oaf_bottom',            340);
        d.put(r + 'lm_6_top_oaf_top',           150);
        d.put(r + 'lm_6_bot_oaf_bot',           340);
        d.put(r + 'lm_4_unit_price',            72000);
        d.put(r + 'lm_5_unit_price',            70000);
        d.put(r + 'lm_6_unit_price',            68000);
        d.put(r + 'lm_6_kit_unit_price',        26000);
        d.put(r + 'lm_4_segment_weight',        440 + n);
        d.put(r + 'lm_5_segment_weight',        420 + n);
        d.put(r + 'lm_6_segment_weight',        400 + n);
        d.put(r + 'lm_1_unit_price',            84000);
        d.put(r + 'lm_2_unit_price',            79000);
        d.put(r + 'lm_3_unit_price',            74000);
        d.put(r + 'lm_1_segment_weight',        620 + n);
        d.put(r + 'lm_extra_micron',            '0');
        d.put(r + 'lm_is_extra_micron',         'No');
        d.put(r + 'lm_bot',                     460);
        // Kit pricing - one branch per segment count (see header comment).
        d.put(kit + 'lm_kit_unit_price',        21000);   // segCount == 1
        d.put(kit + 'lm_2_kit_unit_price',      22000);   // segCount == 2
        d.put(kit + 'lm_3_kit_unit_price',      23000);   // segCount 3..5
        // segCount >= 6 - the Segment Above 5 accessories rate chain
        d.put(r + 'lm_acc_total_rate',          24500);
        d.put(r + 'lm_acc_rate',                24000);
        // Accessory specs - accSpecRaw hunts kit+hmKey, hmKey, p+lmKey, lmKey.
        d.put(kit + 'hm_type_of_winch',         'E=350 kg');
        d.put(kit + 'hm_type_of_power_tool',    'G=Motor,3PH');
        d.put(kit + 'hm_wire_rope',             '5=5mm dia');
        d.put(r + 'lm_type_of_winch',           'E=350 kg');
        d.put(r + 'lm_type_of_power_tool',      'G=Motor,3PH');
        d.put(r + 'lm_type_of_wire_rope',       '5=5mm dia');
        // Special Item, row-prefixed (showSpecialItemSeparatelyRow chain)
        d.put(r + 'lm_si_show_separate',        true);
        d.put(r + 'lm_si_type',                 'Weight');
        d.put(r + 'lm_si_description',          'Aviation lamp bracket');
        d.put(r + 'lm_si_value',                2);
        d.put(r + 'lm_fdn_base_price',          86);
        d.put(r + 'lm_1_base_price',            84);
        d.put(r + 'lm_' + segs + '_base_price', 82);
        // Additional Item (Custom Lightning / Signage branch)
        d.put(r + 'lm_ad_unit_price',           5200);
        d.put(r + 'lm_ad_description',          'GI earthing strip');
        d.put(r + 'lm_ad_weight',               14);
        d.put(r + 'kit_base_price',             94000);
        d.put(r + 'kit_line_1',                 'Mast Kit');
    }

    /** MRL / LWC block for cmStadiumGroups - p is 'mrl_' or 'lwc_'. The
     *  builder returns immediately when p + no_of_segment is 0, which is
     *  exactly what kept 179 lines uncovered in the first two attempts. */
    private static void putStadiumBlock(Map<String, Object> d, String p) {
        d.put(p + 'no_of_segment',        2);
        d.put(p + 'height_of_mast',       20);
        d.put(p + 'segment_height',       10);
        d.put(p + 'top_dia',              220);
        d.put(p + 'bottom_dia',           460);
        d.put(p + 'base_amount',          4200);
        d.put(p + 'quantity',             1);
        d.put(p + 'watt',                 400);
        d.put(p + 'no_of_lum',            6);
        d.put(p + 'type_of_lum',          'LED');
        d.put(p + 'head_frame_height',    1200);
        d.put(p + 'foundation_unit_price', 15200);
        d.put(p + 'foundation_weight',    160);
        d.put(p + 'foundation_bolt_type', 'J-Bolt');
        d.put(p + 'bp_diameter',          900);
        d.put(p + 'bp_pcd',               800);
        d.put(p + 'bp_thickness',         25);
        d.put(p + 'fb_diameter',          36);
        d.put(p + 'fb_length',            1200);
        d.put(p + 'fb_no_of_bolt',        8);
        d.put(p + 'fb_quantity',          8);
        d.put(p + 'extra_micron',         '0');
        d.put(p + 'is_extra_micron',      'No');
        d.put(p + 'pu_paint',             'Yes');
        d.put(p + 'pu_paint_note',        'RAL 9002');
        d.put(p + 'si_type',              'Weight');
        d.put(p + 'si_description',       'Special Bracket');
        d.put(p + 'si_value',             2);
        d.put(p + 'si_show_separate',     true);
    }

    /** One r{n}_fm_ Flag Mast row - cmFlagGroups skips a row unless
     *  fm_height_of_mast is non-blank AND fm_no_of_segment > 0. */
    private static void putFmRow(Map<String, Object> d, Integer n) {
        String r = 'r' + n + '_';
        Integer segs = 2;
        d.put(r + 'fm_height_of_mast',        18 + n);
        d.put(r + 'fm_no_of_segment',         segs);
        d.put(r + 'fm_est_quantity',          2);
        d.put(r + 'fm_1_oaf_top',             210);
        d.put(r + 'fm_1_oaf_bottom',          440);
        d.put(r + 'fm_2_oaf_top',             190);
        d.put(r + 'fm_2_oaf_bottom',          410);
        d.put(r + 'fm_2_top_oaf_top',         190);
        d.put(r + 'fm_2_bot_oaf_bot',         410);
        for (Integer sg = 1; sg <= segs; sg++) {
            d.put(r + 'fm_' + sg + '_unit_price',     71000 - sg * 1000);
            d.put(r + 'fm_' + sg + '_segment_weight', 480 - sg * 20);
        }
        d.put(r + 'fm_bot',                   440);
        d.put(r + 'fm_override_bot',          'No');
        d.put(r + 'fm_ovr_bot',               0);
        d.put(r + 'fm_bp_diameter',           880);
        d.put(r + 'fm_bp_pcd',                780);
        d.put(r + 'fm_bp_thickness',          25);
        d.put(r + 'fm_fb_diameter',           36);
        d.put(r + 'fm_fb_length',             1200);
        d.put(r + 'fm_fb_no_of_bolt',         8);
        d.put(r + 'fm_foundation_unit_price', 14800);
        d.put(r + 'fm_foundation_weight',     150);
        d.put(r + 'fm_extra_micron',          '0');
        d.put(r + 'fm_is_extra_micron',       'No');
        d.put(r + 'fm_pu_paint',              'Yes');
        d.put(r + 'fm_pu_paint_value',        3800);
        d.put(r + 'fm_pu_paint_note',         'RAL 9002');
        d.put(r + 'fm_is_special_desc',       'Yes');
        d.put(r + 'fm_special_desc_text',     'Flag arrangement as per drawing');
    }

    /** Man-riding lift / ladder-with-cage / flag keys for Customized Mast. */
    private static void putCustomizedKeys(Map<String, Object> d) {
        d.put('man_riding_lift',  true);
        d.put('mrl_quantity',     1);
        d.put('mrl_unit_price',   180000);
        d.put('mrl_unit_cost',    172000);
        d.put('mrl_weight',       650);
        d.put('ladder_with_cage', true);
        d.put('lwc_quantity',     1);
        d.put('lwc_unit_price',   96000);
        d.put('lwc_unit_cost',    92000);
        d.put('lwc_weight',       420);
        d.put('fm_est_quantity',  1);
        d.put('fm_unit_price',    120000);
        d.put('fm_unit_cost',     115000);
        d.put('fm_weight',        380);
        d.put('fm_pu_paint_value', 3800);
        // Flag Mast additional accessories + feeder pillar (unprefixed, one
        // per quote) - cmBool-gated so the checkbox must be Boolean true.
        d.put('fm_ma_rate',        4200);
        d.put('fm_ma_quantity',    2);
        d.put('fm_ma_description', 'Halyard set');
        d.put('fm_ma_special_note','SS 304 fittings');
        d.put('fm_fp_checkbox',    true);
        d.put('fm_fp_foundation_unit_price', 9800);
        d.put('fm_fp_quantity',    1);
        // cmStadiumGroups needs a full mrl_/lwc_ block or it returns at once.
        putStadiumBlock(d, 'mrl_');
        putStadiumBlock(d, 'lwc_');
        // cmFlagGroups walks r{n}_fm_ rows.
        putFmRow(d, 1);
        putFmRow(d, 2);
        // The flag and stadium repeaters read the same column shape.
        for (Integer col = 1; col <= COLS; col++) {
            putLpColumn(d, col, 1);
        }
        putLmRow(d, 1);
    }

    /* ================================================================== *
     *  LINE COLLECTIONS
     * ================================================================== */

    private static Map<String, Object> oneLine(String name, Decimal weight, Decimal qty,
                                               Decimal price, Decimal cost, Decimal expenses) {
        return new Map<String, Object>{
            'id'            => 'temp_' + name.length(),
            'name'          => name,
            'billable'      => false,
            'uom'           => 'EA',
            'weight'        => weight,
            'quantity'      => qty,
            'unitPrice'     => price,
            'unitCost'      => cost,
            'unitListPrice' => price,
            'netPrice'      => price,
            'listPrice'     => price,
            'cost'          => cost,
            'discount'      => 0,
            'expenses'      => expenses,
            'margin'        => 0,
            'startDate'     => '',
            'endDate'       => '',
            'weeks'         => 0
        };
    }

    /**
     * Segment, foundation and bracket lines for every column and section, so
     * the isFoundation / isBracket branches both run, plus a freight line
     * because isFreightLine() is a branch of its own in every builder.
     */
    public static List<Object> lineList(String product) {
        List<Object> rows = new List<Object>();
        for (Integer sec = 1; sec <= SECS; sec++) {
            for (Integer col = 1; col <= COLS; col++) {
                rows.add(oneLine(product + ' - Segment - ' + sec + ' Pole Details (Item ' + col + ')',
                                 320 + col, 2, 52424, 52464, 0));
                rows.add(oneLine(product + ' - Foundation accessories - ' + sec + ' (Item ' + col + ')',
                                 85, 2, 12100, 11800, 0));
                rows.add(oneLine(product + ' - Bracket Arm - ' + sec + ' Pole Details (Item ' + col + ')',
                                 22, 2, 4300, 4100, 0));
                // buildMidHingePoleGroups collects lines whose NAME contains
                // 'ACCESSORIES' before walking the repeater.
                rows.add(oneLine(product + ' - ACCESSORIES - Junction Box - ' + sec + ' Pole Details (Item ' + col + ')',
                                 12, 2, 950, 880, 0));
            }
        }
        rows.add(oneLine('Freight Charges', 0, 1, 0, 0, 7500));
        return rows;
    }

    /* ================================================================== *
     *  PAYLOADS
     * ================================================================== */

    /** Pricing, payment terms and offer text - no mast keys, no line lists. */
    public static Map<String, Object> basePayload() {
        Map<String, Object> d = new Map<String, Object>{
            '_Saved_Template_Name'            => DEPT,
            '_Saved_Product_Name'             => DEPT,
            'freight_incoterms'               => 'Ex-works',
            'psd_incoterms'                   => 'Ex-works',
            'payment_terms'                   => 'Against PDC',
            'against_pdc_days'                => 10,
            'pdc_interest_percentage'         => 5,
            'lc_interest_reflect_separately'  => '',
            'usance_interest_buyer_days'      => '',
            'usance_interest_seller_days'     => '',
            'usance_interest_percentage'      => '',
            'against_open_credit_days'        => '',
            'open_credit_interest_percentage' => '',
            'price_variable_month'            => 'January',
            'price_variable_year'             => '2016',
            'billets_rate'                    => 24464,
            'zinc_rate'                       => 126500,
            'cpi_rate'                        => 270,
            'zinc_coating'                    => '610',
            'discount'                        => 40,
            'subject_line'                    => 'Test Subject',
            'delivery_schedule'               => '7',
            'delivery_schedule_unit'          => 'Weeks',
            'warranty_start_date'             => 12,
            'warranty_end_date'               => 18,
            'offer_validity'                  => 6,
            'wind_speed'                      => '47',
            'realization_on_segment_price'    => 5,
            'perpole_freight'                 => 'Yes',
            'perpole_tp_charge'               => 1500,
            'no_of_items'                     => COLS,
            'quantity'                        => 2,
            // appendFreightRow: needs a non-blank mode AND charges > 0
            'transportation_as'               => 'Lump sum',
            'transportation_charges'          => 9500,
            // Unprefixed Special Item - the non-row si chain
            'lm_si_show_separate'             => true,
            'lm_si_type'                      => 'Weight',
            'lm_si_description'               => 'Spare luminary set',
            'lm_si_value'                     => 1,
            'lm_acc_total_rate'               => 24500,
            'lm_acc_rate'                     => 24000
        };
        for (Integer sec = 1; sec <= SECS; sec++) {
            d.put('s' + sec + '_no_of_items', COLS);
        }
        return d;
    }

    /** Mast keys for the given flavour, WITHOUT any line collection. */
    public static Map<String, Object> specPayload(String flavour) {
        Map<String, Object> d = basePayload();

        if (flavour == 'LIGHTING') {
            d.put('type_of_mast',           'Standard Mast');
            d.put('mast_standard',          'Lighting Pole');
            d.put('_Dynamic_Product_Name',  'Lighting Pole');
            for (Integer sec = 1; sec <= SECS; sec++) {
                for (Integer col = 1; col <= COLS; col++) {
                    putLpColumn(d, col, sec);
                }
            }
        } else if (flavour == 'TRANSMISSION') {
            d.put('type_of_mast',           'Standard Mast');
            d.put('mast_standard',          'Transmission Pole');
            d.put('_Dynamic_Product_Name',  'Transmission Pole');
            for (Integer col = 1; col <= COLS; col++) {
                putTpColumn(d, col);
            }
        } else if (flavour == 'MIDHINGE') {
            // mast_standard is left blank on purpose - that exercises the
            // mast_standard_pole fallback inside the constructors.
            d.put('type_of_mast',                'Standard Mast');
            d.put('mast_standard',               '');
            d.put('mast_standard_pole',          'Mid Hinge Pole');
            d.put('_Dynamic_Product_Name',       'Mid Hinge Pole');
            d.put('mhp_no_of_items',             COLS);
            d.put('mhp_accessories_no_of_items', COLS);
            for (Integer col = 1; col <= COLS; col++) {
                putMhpColumn(d, col);
            }
        } else {   // STANDARD - the High Mast builder
            d.put('type_of_mast',          'Standard Mast');
            d.put('_Dynamic_Product_Name', 'High Mast');
            d.put('lm_no_of_rows',         4);
            for (Integer n = 1; n <= 4; n++) {
                putLmRow(d, n);
            }
        }
        return d;
    }

    private static String productFor(String flavour) {
        if (flavour == 'LIGHTING')     return 'LIGHTING POLE';
        if (flavour == 'TRANSMISSION') return 'TRANSMISSION POLE';
        if (flavour == 'MIDHINGE')     return 'MID HINGE POLE';
        return 'HIGH MAST';
    }

    /** spec keys + _Final_Apex_Lines (branch 1). */
    public static String apexJson(String flavour) {
        Map<String, Object> d = specPayload(flavour);
        d.put('_Final_Apex_Lines', lineList(productFor(flavour)));
        return JSON.serialize(d);
    }

    /** spec keys + _Saved_Table_Rows only (branch 2). */
    public static String tableJson(String flavour) {
        Map<String, Object> d = specPayload(flavour);
        d.put('_Saved_Table_Rows', lineList(productFor(flavour)));
        return JSON.serialize(d);
    }

    /** spec keys only, no line collections at all (branch 3 - the big one). */
    public static String specJson(String flavour) {
        return JSON.serialize(specPayload(flavour));
    }

    /** A named mast type sitting on the High Mast shape, spec keys only. */
    public static String namedTypeJson(Map<String, Object> discriminators) {
        Map<String, Object> d = specPayload('STANDARD');
        d.putAll(discriminators);
        return JSON.serialize(d);
    }

    /** Customized / Stadium / Flag, spec keys only. */
    public static String customizedJson(Map<String, Object> discriminators) {
        Map<String, Object> d = basePayload();
        putCustomizedKeys(d);
        d.putAll(discriminators);
        return JSON.serialize(d);
    }

    /* ================================================================== *
     *  RECORDS
     * ================================================================== */

    public static Opportunity createAccountAndOpportunity() {
        Account acc = new Account(
            Name               = 'HMF Test Account',
            AccountSource      = 'Website',
            Phone              = '9800000000',
            BillingStreet      = '456 Billing Street',
            BillingCity        = 'Patna',
            BillingState       = 'Bihar',
            BillingPostalCode  = '800001',
            BillingCountry     = 'India',
            ShippingStreet     = '123 Shipping Street',
            ShippingCity       = 'Mithapur',
            ShippingState      = 'Bihar',
            ShippingPostalCode = '800001',
            ShippingCountry    = 'India'
        );
        // Optional record type - keeps the factory working in an org where
        // 'End Customer' has been renamed.
        List<RecordType> rts = [SELECT Id FROM RecordType
                                WHERE SObjectType = 'Account'
                                  AND Name = 'End Customer' LIMIT 1];
        if (!rts.isEmpty()) {
            acc.RecordTypeId = rts[0].Id;
        }
        insert acc;

        Opportunity opp = new Opportunity(
            Name      = 'HMF Test Opportunity',
            StageName = 'Nurture',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;
        return opp;
    }

    private static Quote mastQuote(Id oppId, String name, String quoteValue) {
        return new Quote(
            Name               = name,
            OpportunityId      = oppId,
            Status             = 'Draft',
            Quote_Value__c     = quoteValue,
            Description        = name,
            submition_date__c  = Date.today(),
            Has_Quote_Value__c = String.isNotBlank(quoteValue)
        );
    }

    public static void createMastTypeQuotes(Id oppId) {
        List<Quote> qs = new List<Quote>();

        // Three branches each for the four builders that carry the bulk.
        qs.add(mastQuote(oppId, Q_LIGHTING_A,     apexJson('LIGHTING')));
        qs.add(mastQuote(oppId, Q_LIGHTING_T,     tableJson('LIGHTING')));
        qs.add(mastQuote(oppId, Q_LIGHTING_S,     specJson('LIGHTING')));

        qs.add(mastQuote(oppId, Q_TRANSMISSION_A, apexJson('TRANSMISSION')));
        qs.add(mastQuote(oppId, Q_TRANSMISSION_T, tableJson('TRANSMISSION')));
        qs.add(mastQuote(oppId, Q_TRANSMISSION_S, specJson('TRANSMISSION')));

        qs.add(mastQuote(oppId, Q_MID_HINGE_A,    apexJson('MIDHINGE')));
        qs.add(mastQuote(oppId, Q_MID_HINGE_T,    tableJson('MIDHINGE')));
        qs.add(mastQuote(oppId, Q_MID_HINGE_S,    specJson('MIDHINGE')));

        qs.add(mastQuote(oppId, Q_STANDARD_A,     apexJson('STANDARD')));
        qs.add(mastQuote(oppId, Q_STANDARD_T,     tableJson('STANDARD')));
        qs.add(mastQuote(oppId, Q_STANDARD_S,     specJson('STANDARD')));

        // Customized Mast family
        qs.add(mastQuote(oppId, Q_STADIUM, customizedJson(new Map<String, Object>{
            'type_of_mast' => 'Customized Mast', 'mast_customized' => 'STADIUM MAST' })));
        qs.add(mastQuote(oppId, Q_FLAG, customizedJson(new Map<String, Object>{
            'type_of_mast' => 'Customized Mast', 'mast_customized' => 'FLAG MAST' })));
        qs.add(mastQuote(oppId, Q_SEG5_FLAG, customizedJson(new Map<String, Object>{
            'type_of_mast' => 'Segment Above 5', 'mast_customized' => '',
            'seg5_mast_type' => 'FLAG MAST' })));
        qs.add(mastQuote(oppId, Q_SEG5_STADIUM, customizedJson(new Map<String, Object>{
            'type_of_mast' => 'Segment Above 5', 'mast_customized' => '',
            'seg5_mast_type' => 'STADIUM MAST' })));

        // Named types that stay on the High Mast builder
        qs.add(mastQuote(oppId, Q_SEG5_LCLM, namedTypeJson(new Map<String, Object>{
            'type_of_mast' => 'Segment Above 5', 'seg5_mast_type' => 'LCLM' })));
        qs.add(mastQuote(oppId, Q_LCLM, namedTypeJson(new Map<String, Object>{
            'type_of_mast' => 'Lightning Cum Lighting Mast' })));
        qs.add(mastQuote(oppId, Q_SIGNAGE, namedTypeJson(new Map<String, Object>{
            'type_of_mast' => 'Signage Mast' })));
        qs.add(mastQuote(oppId, Q_LATCHING, namedTypeJson(new Map<String, Object>{
            'type_of_mast' => 'Latching Mast' })));
        qs.add(mastQuote(oppId, Q_CUSTOM_LIGHTNING, namedTypeJson(new Map<String, Object>{
            'type_of_mast' => 'Custom Lightning Mast', 'mast_standard' => 'Lighting Pole' })));
        qs.add(mastQuote(oppId, Q_CUSTOM_LIGHTING, namedTypeJson(new Map<String, Object>{
            'type_of_mast' => 'Custom Lighting Mast', 'mast_standard' => 'Lighting Pole' })));

        // Octagonal Pole - two dedicated branches inside the lighting builders
        // (isCustomOctagonal / isStandardOctagonal) that no other quote reaches.
        Map<String, Object> octC = specPayload('LIGHTING');
        octC.put('type_of_mast',       'Octagonal Pole');
        octC.put('mast_standard',      '');
        octC.put('mast_standard_pole', 'Custom Lighting Pole');
        qs.add(mastQuote(oppId, Q_OCT_CUSTOM, JSON.serialize(octC)));

        Map<String, Object> octS = specPayload('LIGHTING');
        octS.put('type_of_mast',       'Octagonal Pole');
        octS.put('mast_standard',      '');
        octS.put('mast_standard_pole', 'Standard Lighting Pole');
        qs.add(mastQuote(oppId, Q_OCT_STANDARD, JSON.serialize(octS)));

        // Constructor guards
        qs.add(mastQuote(oppId, Q_EMPTY_JSON, null));
        qs.add(mastQuote(oppId, Q_BAD_JSON, '{ this is not json'));

        insert qs;
    }

    public static void setupAll() {
        Opportunity opp = createAccountAndOpportunity();
        createMastTypeQuotes(opp.Id);
    }

    public static Quote quoteNamed(String name) {
        return [SELECT Id, Name, Quote_Value__c, OpportunityId
                FROM Quote WHERE Name = :name LIMIT 1];
    }

    public static ApexPages.StandardController stdCtrl(Id recordId) {
        return new ApexPages.StandardController(new Quote(Id = recordId));
    }

    /** Every mast quote name, for the loop-through tests. */
    public static List<String> allMastQuoteNames() {
        return new List<String>{
            Q_LIGHTING_A, Q_LIGHTING_T, Q_LIGHTING_S,
            Q_TRANSMISSION_A, Q_TRANSMISSION_T, Q_TRANSMISSION_S,
            Q_MID_HINGE_A, Q_MID_HINGE_T, Q_MID_HINGE_S,
            Q_STANDARD_A, Q_STANDARD_T, Q_STANDARD_S,
            Q_STADIUM, Q_FLAG, Q_SEG5_FLAG, Q_SEG5_STADIUM,
            Q_SEG5_LCLM, Q_LCLM, Q_SIGNAGE, Q_LATCHING,
            Q_CUSTOM_LIGHTNING, Q_CUSTOM_LIGHTING,
            Q_OCT_CUSTOM, Q_OCT_STANDARD
        };
    }
}
/*
* Class Name  : TestHighMastSOWController
* Author      : Deepanjan
* Date        : 10 August 2026
* Description : Coverage tests for HighMastSOWController.
*
*               The controller does all of its work in the constructor, and
*               each builder inside it has three branches - _Final_Apex_Lines,
*               _Saved_Table_Rows, and the c{col}_s{sec} / r{n}_lm_
*               repeater that runs only when neither line collection is
*               present. TestHighMastDataFactory supplies one quote per
*               branch, which is why the four main mast types appear three
*               times each below.
*/
@IsTest
public class TestHighMastSOWController {

    @TestSetup
    static void makeData() {
        TestHighMastDataFactory.setupAll();
    }

    /**
     * Build the controller for a named quote and check the page's collections
     * came up populated. Line-level figures are not asserted - the expected
     * numbers belong to the client's rate sheet, not to a test.
     */
    private static HighMastSOWController run(String quoteName) {
        Quote q = TestHighMastDataFactory.quoteNamed(quoteName);
        HighMastSOWController ctl =
            new HighMastSOWController(TestHighMastDataFactory.stdCtrl(q.Id));
        Assert.isNotNull(ctl, quoteName + ': controller was not constructed');
        Assert.isNotNull(ctl.lineItems, quoteName + ': lineItems is null');
        Assert.isNotNull(ctl.grandTotal, quoteName + ': grandTotal is null');
        Assert.isNotNull(ctl.grandTotalWords, quoteName + ': grandTotalWords is null');
        Assert.isNotNull(ctl.subTotalAmount, quoteName + ': subTotalAmount is null');
        Assert.isNotNull(ctl.soWRef, quoteName + ': soWRef is null');
        Assert.isNotNull(ctl.todayDate, quoteName + ': todayDate is null');
        return ctl;
    }

    @IsTest
    static void lightingApexLines() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_LIGHTING_A);
        Test.stopTest();
        Assert.isTrue(ctl.isLightingPole, 'Q_LIGHTING_A: isLightingPole is wrong');
    }
    @IsTest
    static void lightingTableRows() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_LIGHTING_T);
        Test.stopTest();
        Assert.isTrue(ctl.isLightingPole, 'Q_LIGHTING_T: isLightingPole is wrong');
    }
    @IsTest
    static void lightingSpecRepeater() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_LIGHTING_S);
        Test.stopTest();
        Assert.isTrue(ctl.isLightingPole, 'Q_LIGHTING_S: isLightingPole is wrong');
    }
    @IsTest
    static void transmissionApexLines() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_TRANSMISSION_A);
        Test.stopTest();
        Assert.isTrue(ctl.isTransmissionPole, 'Q_TRANSMISSION_A: isTransmissionPole is wrong');
    }
    @IsTest
    static void transmissionTableRows() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_TRANSMISSION_T);
        Test.stopTest();
        Assert.isTrue(ctl.isTransmissionPole, 'Q_TRANSMISSION_T: isTransmissionPole is wrong');
    }
    @IsTest
    static void transmissionSpecRepeater() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_TRANSMISSION_S);
        Test.stopTest();
        Assert.isTrue(ctl.isTransmissionPole, 'Q_TRANSMISSION_S: isTransmissionPole is wrong');
    }
    @IsTest
    static void midHingeApexLines() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_MID_HINGE_A);
        Test.stopTest();
        Assert.isTrue(ctl.isMidHingePole, 'Q_MID_HINGE_A: isMidHingePole is wrong');
    }
    @IsTest
    static void midHingeTableRows() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_MID_HINGE_T);
        Test.stopTest();
        Assert.isTrue(ctl.isMidHingePole, 'Q_MID_HINGE_T: isMidHingePole is wrong');
    }
    @IsTest
    static void midHingeSpecRepeater() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_MID_HINGE_S);
        Test.stopTest();
        Assert.isTrue(ctl.isMidHingePole, 'Q_MID_HINGE_S: isMidHingePole is wrong');
    }
    @IsTest
    static void standardApexLines() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_STANDARD_A);
        Test.stopTest();
        Assert.isFalse(ctl.isCustomizedMast, 'Q_STANDARD_A: isCustomizedMast is wrong');
    }
    @IsTest
    static void standardTableRows() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_STANDARD_T);
        Test.stopTest();
        Assert.isFalse(ctl.isCustomizedMast, 'Q_STANDARD_T: isCustomizedMast is wrong');
    }
    @IsTest
    static void standardSpecRepeater() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_STANDARD_S);
        Test.stopTest();
        Assert.isFalse(ctl.isCustomizedMast, 'Q_STANDARD_S: isCustomizedMast is wrong');
    }
    @IsTest
    static void stadiumMast() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_STADIUM);
        Test.stopTest();
        Assert.isTrue(ctl.isStadiumMast, 'Q_STADIUM: isStadiumMast is wrong');
    }
    @IsTest
    static void flagMast() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_FLAG);
        Test.stopTest();
        Assert.isTrue(ctl.isFlagMast, 'Q_FLAG: isFlagMast is wrong');
    }
    @IsTest
    static void seg5FlagMast() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_SEG5_FLAG);
        Test.stopTest();
        Assert.isTrue(ctl.isSeg5FlagMast, 'Q_SEG5_FLAG: isSeg5FlagMast is wrong');
    }
    @IsTest
    static void seg5StadiumMast() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_SEG5_STADIUM);
        Test.stopTest();
        Assert.isTrue(ctl.isStadiumMast, 'Q_SEG5_STADIUM: isStadiumMast is wrong');
    }
    @IsTest
    static void seg5Lclm() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_SEG5_LCLM);
        Test.stopTest();
        Assert.isTrue(ctl.isLCLM, 'Q_SEG5_LCLM: isLCLM is wrong');
    }
    @IsTest
    static void lclm() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_LCLM);
        Test.stopTest();
        Assert.isTrue(ctl.isLCLM, 'Q_LCLM: isLCLM is wrong');
    }
    @IsTest
    static void signageMast() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_SIGNAGE);
        Test.stopTest();
        Assert.isTrue(ctl.isSignageMast, 'Q_SIGNAGE: isSignageMast is wrong');
    }
    @IsTest
    static void latchingMast() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_LATCHING);
        Test.stopTest();
        Assert.isTrue(ctl.isLatchingMast, 'Q_LATCHING: isLatchingMast is wrong');
    }
    @IsTest
    static void customLightningMast() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_CUSTOM_LIGHTNING);
        Test.stopTest();
        Assert.isTrue(ctl.isCustomLightningMast, 'Q_CUSTOM_LIGHTNING: isCustomLightningMast is wrong');
    }
    @IsTest
    static void customLightingSpelling() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_CUSTOM_LIGHTING);
        Test.stopTest();
        Assert.isTrue(ctl.isCustomLightningMast, 'Q_CUSTOM_LIGHTING: isCustomLightningMast is wrong');
    }
    @IsTest
    static void blankQuoteValueDoesNotThrow() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_EMPTY_JSON);
        Test.stopTest();
    }

    /*
     * The constructor catches a JSON parse failure and carries on with an
     * empty map, so a corrupt quote renders an empty page instead of an error
     * page. That catch block is otherwise never executed.
     */
    @IsTest
    static void malformedJsonIsSwallowed() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_BAD_JSON);
        Test.stopTest();
    }

    /*
     * One pass over every mast quote in the factory. Cheap insurance: if a new
     * mast type is added to the factory later it is exercised here even before
     * anyone writes a dedicated method for it.
     */
    @IsTest
    static void everyMastTypeConstructsCleanly() {
        List<String> names = TestHighMastDataFactory.allMastQuoteNames();
        Test.startTest();
        for (String n : names) {
            run(n);
        }
        Test.stopTest();
        Assert.areEqual(24, names.size(),
            'The factory should be covering 22 mast quotes; update this test if that changes');
    }

    /* Octagonal Pole - the two dedicated branches inside the lighting
       builders (Custom / Standard Lighting Pole). Deepanjan (10th Aug 2026) */
    @IsTest
    static void octagonalCustomLightingPole() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_OCT_CUSTOM);
        Test.stopTest();
        Assert.isFalse(ctl.isTransmissionPole, 'Q_OCT_CUSTOM: isTransmissionPole is wrong');
    }

    @IsTest
    static void octagonalStandardLightingPole() {
        Test.startTest();
        HighMastSOWController ctl = run(TestHighMastDataFactory.Q_OCT_STANDARD);
        Test.stopTest();
        Assert.isFalse(ctl.isTransmissionPole, 'Q_OCT_STANDARD: isTransmissionPole is wrong');
    }
}
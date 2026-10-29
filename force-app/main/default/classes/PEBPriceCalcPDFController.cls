/**
 * PEBPriceCalcPDFController
 * -------------------------
 * Standard-controller extension for the PEBPriceCalcPDF Visualforce page.
 * Reads the saved calculation JSON from the Opportunity and deserializes it
 * into a typed model so the page (rendered as PDF) can iterate cleanly.
 */
public with sharing class PEBPriceCalcPDFController {

    public Opportunity opp { get; set; }
    public Model model { get; set; }
    public Boolean hasData { get; set; }
    public String todayDate { get; set; }

    public PEBPriceCalcPDFController(ApexPages.StandardController sc) {
        todayDate = Date.today().format();
        hasData = false;
        opp = [
            SELECT Id, Name, Price_Calculation_JSON__c
            FROM Opportunity
            WHERE Id = :sc.getId()
            LIMIT 1
        ];
        if (String.isNotBlank(opp.Price_Calculation_JSON__c)) {
            try {
                model = (Model) JSON.deserialize(opp.Price_Calculation_JSON__c, Model.class);
                hasData = (model != null);
            } catch (Exception e) {
                model = null;
                hasData = false;
            }
        }
    }

    /* ---- Typed JSON model (mirrors the payload written by the LWC) --------
     * Members are properties (get; set;) so Visualforce can bind to them and
     * JSON.deserialize can populate them. */
    public class Model {
        public String projectName { get; set; }
        public String projectLocation { get; set; }
        public String generatedDate { get; set; }
        public List<RowA> sectionA { get; set; }
        public List<RowAcc> accessories { get; set; }
        public List<RowAcc> buyouts { get; set; }
        public List<RowConv> conversion { get; set; }
        public List<RowOther> otherCost { get; set; }
        public List<RowVar> variableCost { get; set; }
        public Totals totals { get; set; }
    }

    public class RowA {
        public Integer slNo { get; set; }
        public String description { get; set; }
        public String unit { get; set; }
        public Decimal totalWeight { get; set; }
        public Decimal additionalWeight { get; set; }
        public String reason { get; set; }
        public Decimal totalCalcWeight { get; set; }
        public Decimal rate { get; set; }
        public Decimal cost { get; set; }
    }

    public class RowAcc {
        public String description { get; set; }
        public String unit { get; set; }
        public Decimal qty { get; set; }
        public Decimal unitWt { get; set; }
        public Decimal totalWeight { get; set; }
        public Decimal rate { get; set; }
        public Decimal cost { get; set; }
    }

    public class RowConv {
        public String description { get; set; }
        public String unit { get; set; }
        public Decimal weight { get; set; }
        public Decimal rate { get; set; }
        public Decimal cost { get; set; }
    }

    public class RowOther {
        public String description { get; set; }
        public String unit { get; set; }
        public Decimal qty { get; set; }
        public Decimal rate { get; set; }
        public Decimal cost { get; set; }
    }

    public class RowVar {
        public String description { get; set; }
        public Decimal cost { get; set; }
    }

    public class Totals {
        public Decimal sectionATotalWeight { get; set; }
        public Decimal sectionATotalCost { get; set; }
        public Decimal accessoriesTotalCost { get; set; }
        public Decimal buyoutsTotalCost { get; set; }
        public Decimal sectionBTotalCost { get; set; }
        public Decimal conversionTotalCost { get; set; }
        public Decimal otherCostTotal { get; set; }
        public Decimal variableCostTotal { get; set; }
        public Decimal totalDirectCost { get; set; }
        public Decimal totalProjectCost { get; set; }
        public Decimal marginPercent { get; set; }
        public Decimal marginRs { get; set; }
        public Decimal totalWithMargin { get; set; }
        public Decimal gstPercent { get; set; }
        public Decimal gstRs { get; set; }
        public Decimal grandTotal { get; set; }
    }
}
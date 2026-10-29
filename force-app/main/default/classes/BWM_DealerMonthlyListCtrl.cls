public with sharing class BWM_DealerMonthlyListCtrl {
  public String dealerName { get; private set; }
  public List<Row> rows { get; private set; }

  public class Row {
    public String name { get; set; }
    public String phone { get; set; }
    public String email { get; set; }
    public String amountDisplay { get; set; }
    public String closeDateDisplay { get; set; }
  }

  public BWM_DealerMonthlyListCtrl() {
    rows = new List<Row>();
    Id accountId = ApexPages.currentPage().getParameters().get('accountId');
    if (accountId == null) {
      dealerName = 'Dealer';
      return;
    }

    Account accountRecord = [
      SELECT Name
      FROM Account
      WHERE Id = :accountId
      LIMIT 1
    ];
    dealerName = accountRecord.Name;

    for (Opportunity opportunityRecord : [
      SELECT Name, Phone__c, Email__c, Amount, CloseDate
      FROM Opportunity
      WHERE DealerAccount__c = :accountId AND IsClosed = FALSE
      ORDER BY Name
    ]) {
      Row row = new Row();
      row.name = opportunityRecord.Name;
      row.phone = opportunityRecord.Phone__c;
      row.email = opportunityRecord.Email__c;
      row.amountDisplay = opportunityRecord.Amount == null
        ? ''
        : String.valueOf(opportunityRecord.Amount);
      row.closeDateDisplay = opportunityRecord.CloseDate == null
        ? ''
        : opportunityRecord.CloseDate.format();
      rows.add(row);
    }
  }
}
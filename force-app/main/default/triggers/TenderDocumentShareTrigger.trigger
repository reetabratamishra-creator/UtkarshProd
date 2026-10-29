trigger TenderDocumentShareTrigger on Tender_Docoment_Details__c (after insert) {

    // Independent toggle from Tender_Share_Trigger - new field on the same mdt type.
    Tender_Trigger_Controll__mdt setting =
        Tender_Trigger_Controll__mdt.getInstance('Tender_Document_Share_Trigger');

    if (setting != null && !setting.Is_Document_Share_Active__c) {
        return;
    }

    TenderDocumentSharingHandler.shareDocuments(Trigger.new);
}
@IsTest
private class OpportunityQuoteEmailServiceTest {
    @IsTest
    static void testBuildAttachmentAndMergeTemplate() {
        ContentVersion versionRecord = new ContentVersion(
            Title = 'Quotation 00000984',
            PathOnClient = 'Quotation 00000984.pdf',
            VersionData = Blob.valueOf('quote pdf')
        );
        insert as system versionRecord;
        versionRecord = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :versionRecord.Id
        ];

        Messaging.EmailFileAttachment attachment =
            OpportunityQuoteEmailService.buildFinalQuoteAttachment(
                String.valueOf(versionRecord.ContentDocumentId)
            );
        System.assertNotEquals(null, attachment);
        System.assertEquals('Quotation 00000984.pdf', attachment.getFileName());
        System.assertEquals('quote pdf', attachment.getBody().toString());
        System.assertEquals('application/pdf', attachment.getContentType());

        String merged = OpportunityQuoteEmailService.mergeTemplate(
            'Dear __CONTACT_NAME__ __QUOTE_NUMBER__ __QUOTATION_DATE__ __VALID_TILL__',
            'Pushpa HDPE',
            '00000984',
            Date.newInstance(2026, 8, 11),
            Date.newInstance(2026, 9, 4)
        );
        System.assertEquals(
            'Dear Pushpa HDPE 00000984 11/08/2026 04/09/2026',
            merged
        );
    }

    @IsTest
    static void testSendToPrimaryContact() {
        Account accountRecord = new Account(Name = 'Quote Email Account');
        insert as system accountRecord;

        Contact contactRecord = new Contact(
            FirstName = 'Pushpa',
            LastName = 'HDPE',
            Email = 'pushpa@example.com',
            AccountId = accountRecord.Id
        );
        insert as system contactRecord;

        Opportunity opportunityRecord = new Opportunity(
            Name = 'Quote Email Opportunity',
            AccountId = accountRecord.Id,
            StageName = 'Nurture',
            CloseDate = Date.newInstance(2026, 9, 4),
            Quotation_Date__c = Date.newInstance(2026, 8, 11),
            Quote_Number__c = '00000984'
        );
        insert as system opportunityRecord;

        Quote quoteRecord = new Quote(
            Name = 'Quote Email Quote',
            OpportunityId = opportunityRecord.Id,
            submition_date__c = Datetime.newInstance(
                Date.newInstance(2026, 8, 11),
                Time.newInstance(12, 0, 0, 0)
            )
        );
        insert as system quoteRecord;

        insert as system new OpportunityContactRole(
            OpportunityId = opportunityRecord.Id,
            ContactId = contactRecord.Id,
            IsPrimary = true,
            Role = 'Decision Maker'
        );

        ContentVersion versionRecord = new ContentVersion(
            Title = 'Quotation 00000984',
            PathOnClient = 'Quotation 00000984.pdf',
            VersionData = Blob.valueOf('quote pdf'),
            FirstPublishLocationId = opportunityRecord.Id
        );
        insert as system versionRecord;
        versionRecord = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :versionRecord.Id
        ];
        update as system new Opportunity(
            Id = opportunityRecord.Id,
            SyncedQuoteId = quoteRecord.Id,
            Final_Quote_Document_ID__c = String.valueOf(
                versionRecord.ContentDocumentId
            )
        );

        Test.startTest();
        Boolean sent = OpportunityQuoteEmailService.sendToPrimaryContact(
            opportunityRecord.Id
        );
        Test.stopTest();

        System.assertEquals(true, sent);
    }

    @IsTest
    static void testSkipsWhenFinalQuoteMissing() {
        System.assertEquals(
            false,
            OpportunityQuoteEmailService.sendToPrimaryContact(null)
        );
    }
}
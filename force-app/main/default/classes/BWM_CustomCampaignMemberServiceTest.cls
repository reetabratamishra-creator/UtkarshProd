@IsTest
private class BWM_CustomCampaignMemberServiceTest {
    @IsTest
    static void testCreateCampaignWithLeadMembers() {
        Lead leadRecord = new Lead(
            LastName = 'Campaign Member Test',
            Company = 'Test Co',
            Email = 'ccm.lead@test.com'
        );
        insert leadRecord;

        Test.startTest();
        BWM_CustomCampaignMemberService.CreateCampaignResult result = BWM_CustomCampaignMemberService.createCampaignWithMembers(
            'Lead Outreach',
            BWM_CustomCampaignMemberService.MEMBER_TYPE_LEAD,
            new List<Id>{ leadRecord.Id }
        );
        Test.stopTest();

        System.assertNotEquals(null, result.campaignId, 'Campaign should be created.');
        System.assertEquals(1, result.memberCount, 'One member should be created.');

        Campaign createdCampaign = [
            SELECT Id, Name, Status, IsActive
            FROM Campaign
            WHERE Id = :result.campaignId
        ];
        System.assertEquals('Lead Outreach', createdCampaign.Name);
        System.assertEquals(true, createdCampaign.IsActive);

        List<Custom_Campaign_Member__c> members = [
            SELECT Id, Campaign__c, Lead__c
            FROM Custom_Campaign_Member__c
            WHERE Campaign__c = :result.campaignId
        ];
        System.assertEquals(1, members.size());
        System.assertEquals(leadRecord.Id, members[0].Lead__c);
    }

    @IsTest
    static void testCreateCampaignWithMultipleOpportunityMembers() {
        Account accountRecord = new Account(Name = 'CCM Account');
        insert accountRecord;

        List<Opportunity> opportunities = new List<Opportunity>();
        for (Integer indexNumber = 0; indexNumber < 2; indexNumber++) {
            opportunities.add(
                new Opportunity(
                    Name = 'CCM Opp ' + indexNumber,
                    StageName = 'Prospecting',
                    CloseDate = Date.today().addDays(30),
                    AccountId = accountRecord.Id
                )
            );
        }
        insert opportunities;

        Test.startTest();
        BWM_CustomCampaignMemberService.CreateCampaignResult result = BWM_CustomCampaignMemberService.createCampaignWithMembers(
            'Dealer Push',
            BWM_CustomCampaignMemberService.MEMBER_TYPE_OPPORTUNITY,
            new List<Id>{ opportunities[0].Id, opportunities[1].Id }
        );
        Test.stopTest();

        System.assertEquals(2, result.memberCount);
        System.assertEquals(
            2,
            [
                SELECT COUNT()
                FROM Custom_Campaign_Member__c
                WHERE Campaign__c = :result.campaignId
            ]
        );
    }

    @IsTest
    static void testBlankCampaignNameThrows() {
        Lead leadRecord = new Lead(
            LastName = 'Invalid Campaign',
            Company = 'Test Co'
        );
        insert leadRecord;

        Boolean threw = false;
        try {
            BWM_CustomCampaignMemberService.createCampaignWithMembers(
                '   ',
                BWM_CustomCampaignMemberService.MEMBER_TYPE_LEAD,
                new List<Id>{ leadRecord.Id }
            );
        } catch (Exception ex) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Blank campaign name should throw.');
    }

    @IsTest
    static void testInvalidMemberTypeThrows() {
        Lead leadRecord = new Lead(
            LastName = 'Invalid Type',
            Company = 'Test Co'
        );
        insert leadRecord;

        Boolean threw = false;
        try {
            BWM_CustomCampaignMemberService.createCampaignWithMembers(
                'Valid Name',
                'UNKNOWN',
                new List<Id>{ leadRecord.Id }
            );
        } catch (Exception ex) {
            threw = true;
        }
        System.assertEquals(true, threw, 'Invalid member type should throw.');
    }

    @IsTest
    static void testControllerCreateCampaignWithMembers() {
        Lead leadRecord = new Lead(
            LastName = 'Controller Test',
            Company = 'Test Co'
        );
        insert leadRecord;

        Test.startTest();
        BWM_CustomCampaignMemberService.CreateCampaignResult result = BWM_CustomCampaignMemberCtrl.createCampaignWithMembers(
            'Controller Campaign',
            BWM_CustomCampaignMemberService.MEMBER_TYPE_LEAD,
            new List<Id>{ leadRecord.Id }
        );
        Test.stopTest();

        System.assertEquals(1, result.memberCount);
    }
}
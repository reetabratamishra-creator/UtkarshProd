@isTest
private class TenderWrappersTest {

    @isTest
    static void testCountResponseDeserialization() {
        String json =
            '{"Success":true,"Message":"OK","TotalRecord":1,' +
            '"Data":[{"count":5}],"StatusCode":200}';

        TenderWrappers.CountResponse resp =
            (TenderWrappers.CountResponse) System.JSON.deserialize(
                json,
                TenderWrappers.CountResponse.class
            );

        System.assertEquals(true, resp.Success);
        System.assertEquals('OK', resp.Message);
        System.assertEquals(1, resp.TotalRecord);
        System.assertEquals(200, resp.StatusCode);
        System.assertEquals(1, resp.Data.size());
        System.assertEquals(5, resp.Data[0].count);
    }

    @isTest
    static void testListingResponseDeserializationWithProbableBidder() {
        String json =
            '{"Success":true,"Message":"OK","TotalRecord":1,"StatusCode":200,' +
            '"Data":[{"tenderid":1,"sourcetenderid":"S1","value":10.5,' +
            '"probable_bidder":["A","B"],' +
            '"documents":[{"documentid":9,"name":"doc","downloadLink":"http://x","type":"pdf"}],' +
            '"location":[{"tenderid":1,"country":"India","state":"WB","city":"Kolkata"}]}]}';

        TenderWrappers.ListingResponse resp =
            (TenderWrappers.ListingResponse) System.JSON.deserialize(
                json,
                TenderWrappers.ListingResponse.class
            );

        System.assertEquals(true, resp.Success);
        System.assertEquals(1, resp.Data.size());
        System.assertEquals(2, resp.Data[0].probable_bidder.size());
        System.assertEquals('A', resp.Data[0].probable_bidder[0]);
        System.assertEquals('B', resp.Data[0].probable_bidder[1]);
        System.assertEquals('doc', resp.Data[0].documents[0].name);
        System.assertEquals('Kolkata', resp.Data[0].location[0].city);
    }

    @isTest
    static void testContactDetailsResponseDeserialization() {
        String json =
            '{"Success":true,"Message":"OK","TotalRecord":1,"StatusCode":200,' +
            '"Data":[{"bidder_name":"Acme","contact_number":"12345",' +
            '"email_id":"a@x.com","pan_no":"PAN1","vendorcode":"V1",' +
            '"seller_id":"S1","gem_id":"G1","msme_number":"M1",' +
            '"category":"Cat","branch_name":"Branch","address":"Addr",' +
            '"pincode":"700001","gst_number":"GST1","phone_number":"9999",' +
            '"alternate_email_id":"b@x.com","designation":"Mgr"}]}';

        TenderWrappers.ContactDetailsResponse resp =
            (TenderWrappers.ContactDetailsResponse) System.JSON.deserialize(
                json,
                TenderWrappers.ContactDetailsResponse.class
            );

        System.assertEquals(true, resp.Success);
        System.assertEquals(1, resp.Data.size());
        System.assertEquals('Acme', resp.Data[0].bidder_name);
        System.assertEquals('700001', resp.Data[0].pincode);
        System.assertEquals('Mgr', resp.Data[0].designation);
    }
}
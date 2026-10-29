/**
 * @description   Test class for ThirdPartyPayloadReceiver REST webhook handling.
 * @author        Anshita Chanda
 * @date          2026-08-06
 */
@IsTest
private class ThirdPartyPayloadReceiverTest {
  @IsTest
  static void storesIncomingPayload() {
    RestRequest request = new RestRequest();
    RestResponse response = new RestResponse();
    request.requestURI = '/services/apexrest/thirdParty/payload/';
    request.httpMethod = 'POST';
    request.requestBody = Blob.valueOf('{"sample":"payload","test":true}');
    RestContext.request = request;
    RestContext.response = response;

    Test.startTest();
    ThirdPartyPayloadReceiver.receivePayload();
    Test.stopTest();

    System.assertEquals(200, response.statusCode);
    System.assert(response.responseBody.toString().contains('"status":"success"'));

    List<Incoming_Payload__c> records = [
      SELECT Raw_Payload__c, Received_At__c, Source__c
      FROM Incoming_Payload__c
    ];
    System.assertEquals(1, records.size());
    System.assert(records[0].Raw_Payload__c.contains('"sample":"payload"'));
    System.assertEquals('ThirdPartyApp', records[0].Source__c);
    System.assertNotEquals(null, records[0].Received_At__c);
  }

  @IsTest
  static void storesSourceHeaderAndOptionalFields() {
    RestRequest request = new RestRequest();
    RestResponse response = new RestResponse();
    request.requestURI = '/services/apexrest/thirdParty/payload/';
    request.httpMethod = 'POST';
    request.addHeader('X-Source', 'Bluewaves');
    request.requestBody = Blob.valueOf(
      '{"messageId":"msg-123","status":"delivered"}'
    );
    RestContext.request = request;
    RestContext.response = response;

    Test.startTest();
    ThirdPartyPayloadReceiver.receivePayload();
    Test.stopTest();

    Incoming_Payload__c record = [
      SELECT Source__c, Message_Id__c, Status__c
      FROM Incoming_Payload__c
      LIMIT 1
    ];
    System.assertEquals('Bluewaves', record.Source__c);
    System.assertEquals('msg-123', record.Message_Id__c);
    System.assertEquals('delivered', record.Status__c);
  }

  @IsTest
  static void storesWhatsAppQuoteReplyPayload() {
    RestRequest request = new RestRequest();
    RestResponse response = new RestResponse();
    request.requestURI = '/services/apexrest/thirdParty/payload/';
    request.httpMethod = 'POST';
    request.addHeader('X-Source', 'Bluewaves');
    request.requestBody = Blob.valueOf(
      '{"biz_opaque_callback_data":"006C200000HE1YjIAL","messages":[{"type":"button","button":{"payload":"Yes","text":"Yes"}}]}'
    );
    RestContext.request = request;
    RestContext.response = response;

    Test.startTest();
    ThirdPartyPayloadReceiver.receivePayload();
    Test.stopTest();

    Incoming_Payload__c record = [
      SELECT Source__c, Message_Id__c, Status__c, Raw_Payload__c
      FROM Incoming_Payload__c
      LIMIT 1
    ];
    System.assertEquals('Bluewaves', record.Source__c);
    System.assertEquals('006C200000HE1YjIAL', record.Message_Id__c);
    System.assertEquals('Yes', record.Status__c);
    System.assert(record.Raw_Payload__c.contains('"payload":"Yes"'));
  }

  @IsTest
  static void storesPostmanStylePayloadFromSourceField() {
    RestRequest request = new RestRequest();
    RestResponse response = new RestResponse();
    request.requestURI = '/services/apexrest/thirdParty/payload/';
    request.httpMethod = 'POST';
    request.requestBody = Blob.valueOf(
      '{"test":"sample payload","source":"Postman"}'
    );
    RestContext.request = request;
    RestContext.response = response;

    Test.startTest();
    ThirdPartyPayloadReceiver.receivePayload();
    Test.stopTest();

    Incoming_Payload__c record = [
      SELECT Source__c, Raw_Payload__c
      FROM Incoming_Payload__c
      LIMIT 1
    ];
    System.assertEquals('Postman', record.Source__c);
    System.assert(record.Raw_Payload__c.contains('"test":"sample payload"'));
  }

  @IsTest
  static void storesFlatYesNoQuoteReplyWithBodySource() {
    RestRequest request = new RestRequest();
    RestResponse response = new RestResponse();
    request.requestURI = '/services/apexrest/thirdParty/payload/';
    request.httpMethod = 'POST';
    request.requestBody = Blob.valueOf(
      '{"source":"Bluewaves","biz_opaque_callback_data":"006C200000HE1YjIAL","status":"No","channel":"WHATSAPP"}'
    );
    RestContext.request = request;
    RestContext.response = response;

    Test.startTest();
    ThirdPartyPayloadReceiver.receivePayload();
    Test.stopTest();

    Incoming_Payload__c record = [
      SELECT Source__c, Message_Id__c, Status__c
      FROM Incoming_Payload__c
      LIMIT 1
    ];
    System.assertEquals('Bluewaves', record.Source__c);
    System.assertEquals('006C200000HE1YjIAL', record.Message_Id__c);
    System.assertEquals('No', record.Status__c);
  }

  @IsTest
  static void returnsErrorForEmptyBody() {
    RestRequest request = new RestRequest();
    RestResponse response = new RestResponse();
    request.requestURI = '/services/apexrest/thirdParty/payload/';
    request.httpMethod = 'POST';
    request.requestBody = Blob.valueOf('');
    RestContext.request = request;
    RestContext.response = response;

    Test.startTest();
    ThirdPartyPayloadReceiver.receivePayload();
    Test.stopTest();

    System.assertEquals(400, response.statusCode);
    System.assert(response.responseBody.toString().contains('"status":"error"'));
    System.assertEquals(0, [SELECT COUNT() FROM Incoming_Payload__c]);
  }
}
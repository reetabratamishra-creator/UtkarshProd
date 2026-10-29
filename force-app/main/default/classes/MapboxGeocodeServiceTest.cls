@isTest
private class MapboxGeocodeServiceTest {

    private class MapboxSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assert(req.getEndpoint().contains('api.mapbox.com'), 'Endpoint should target Mapbox');
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody(
                '{'
                + '"type":"FeatureCollection",'
                + '"features":[{'
                + '"type":"Feature",'
                + '"properties":{'
                + '"feature_type":"postcode",'
                + '"full_address":"713154, Memari, West Bengal, India",'
                + '"name":"713154",'
                + '"context":{'
                + '"locality":{"name":"Merua"},'
                + '"place":{"name":"Memari"},'
                + '"region":{"name":"West Bengal"},'
                + '"country":{"name":"India"},'
                + '"postcode":{"name":"713154"}'
                + '}'
                + '}'
                + '}]'
                + '}'
            );
            return res;
        }
    }

    private class MapboxErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"message":"error"}');
            return res;
        }
    }

    @isTest
    static void testReverseGeocodeSuccess() {
        Test.setMock(HttpCalloutMock.class, new MapboxSuccessMock());
        Test.startTest();
        MapboxGeocodeService.GeocodeResult result =
            MapboxGeocodeService.reverseGeocode(23.1961046507531, 88.09535258452075);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('713154', result.pin);
        System.assertEquals('Memari', result.city);
        System.assertEquals('Merua', result.street);
        System.assertEquals('West Bengal', result.state);
        System.assertEquals('India', result.country);
        System.assert(result.fullAddress.contains('713154'), 'fullAddress should include PIN');
    }

    @isTest
    static void testReverseGeocodeErrorReturnsNull() {
        Test.setMock(HttpCalloutMock.class, new MapboxErrorMock());
        Test.startTest();
        MapboxGeocodeService.GeocodeResult result =
            MapboxGeocodeService.reverseGeocode(23.19, 88.09);
        Test.stopTest();
        System.assertEquals(null, result);
    }

    @isTest
    static void testReverseGeocodeNullCoords() {
        System.assertEquals(null, MapboxGeocodeService.reverseGeocode(null, 88.09));
        System.assertEquals(null, MapboxGeocodeService.reverseGeocode(23.19, null));
    }

    @isTest
    static void testParseResponsePrefersPostcode() {
        String body =
            '{'
            + '"features":['
            + '{"properties":{"feature_type":"place","full_address":"Memari","name":"Memari","context":{"place":{"name":"Memari"}}}},'
            + '{"properties":{"feature_type":"postcode","full_address":"713154, Memari","name":"713154",'
            + '"context":{"postcode":{"name":"713154"},"place":{"name":"Memari"},"locality":{"name":"Merua"},'
            + '"region":{"name":"West Bengal"},"country":{"name":"India"}}}}'
            + ']'
            + '}';
        MapboxGeocodeService.GeocodeResult result = MapboxGeocodeService.parseResponse(body);
        System.assertEquals('713154', result.pin);
        System.assertEquals('Memari', result.city);
    }
}
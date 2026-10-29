public with sharing class MapboxGeocodeService {
    public class GeocodeResult {
        public String pin;
        public String city;
        public String street;
        public String state;
        public String country;
        public String fullAddress;
    }

    public MapboxGeocodeService() {
    }

    /**
     * Reverse-geocode lat/lng via Mapbox Geocoding API v6.
     * Returns null on failure (caller decides fallback). No DML.
     */
    public static GeocodeResult reverseGeocode(Decimal latitude, Decimal longitude) {
        if (latitude == null || longitude == null) {
            return null;
        }

        String token;
        try {
            token = System.Label.Mapbox_Access_Token;
        } catch (Exception e) {
            return null;
        }
        if (String.isBlank(token)) {
            return null;
        }

        String endpoint =
            'https://api.mapbox.com/search/geocode/v6/reverse'
            + '?longitude=' + String.valueOf(longitude)
            + '&latitude=' + String.valueOf(latitude)
            + '&access_token=' + EncodingUtil.urlEncode(token, 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setTimeout(12000);
        req.setHeader('Accept', 'application/json');

        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
                return null;
            }
            return parseResponse(res.getBody());
        } catch (Exception e) {
            return null;
        }
    }

    @TestVisible
    private static GeocodeResult parseResponse(String body) {
        if (String.isBlank(body)) {
            return null;
        }

        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(body);
        List<Object> features = (List<Object>) root.get('features');
        if (features == null || features.isEmpty()) {
            return null;
        }

        Map<String, Object> chosen = null;
        for (Object fObj : features) {
            Map<String, Object> feature = (Map<String, Object>) fObj;
            Map<String, Object> props = (Map<String, Object>) feature.get('properties');
            if (props == null) {
                continue;
            }
            if (props.get('feature_type') == 'postcode') {
                chosen = props;
                break;
            }
        }
        if (chosen == null) {
            Map<String, Object> first = (Map<String, Object>) features[0];
            chosen = (Map<String, Object>) first.get('properties');
        }
        if (chosen == null) {
            return null;
        }

        Map<String, Object> context = (Map<String, Object>) chosen.get('context');
        if (context == null) {
            context = new Map<String, Object>();
        }

        GeocodeResult result = new GeocodeResult();
        result.fullAddress = (String) chosen.get('full_address');

        String pin = contextName(context, 'postcode');
        if (String.isBlank(pin) && chosen.get('feature_type') == 'postcode') {
            pin = (String) chosen.get('name');
        }
        result.pin = pin;
        result.city = contextName(context, 'place');
        String locality = contextName(context, 'locality');
        result.street = String.isNotBlank(locality) ? locality : result.fullAddress;
        result.state = contextName(context, 'region');
        result.country = contextName(context, 'country');

        return result;
    }

    private static String contextName(Map<String, Object> context, String key) {
        if (context == null || !context.containsKey(key)) {
            return null;
        }
        Object node = context.get(key);
        if (!(node instanceof Map<String, Object>)) {
            return null;
        }
        return (String) ((Map<String, Object>) node).get('name');
    }
}
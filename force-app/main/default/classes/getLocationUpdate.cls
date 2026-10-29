@RestResource(urlMapping='/updatelocation')
global class getLocationUpdate {

    @HttpGet
    global static String doGet() {
        RestRequest req = RestContext.request;
        Map<String, String> params = req.params;
        System.debug('GET Location Update Request Params: ' + JSON.serialize(params));
        
        return 'GET success. Received: ' + JSON.serialize(params);
    }

    @HttpPost
    global static String doPost() {
        RestRequest req = RestContext.request;
        if (req.requestBody == null) {
            return 'Error: Request body is empty';
        }
        
        String requestBody = req.requestBody.toString();
        if (requestBody != null) {
            requestBody = requestBody.replace('\u00A0', ' ');
        }
        String myId = req.params.get('myId');
        
        System.debug('=== [POST Location Update] ===');
        System.debug('User ID (myId): ' + myId);
        System.debug('Headers: ' + JSON.serializePretty(req.headers));
        System.debug('Body: ' + requestBody);
        System.debug('==============================');
        
        try {
            if (String.isBlank(myId)) {
                return 'Error: myId parameter is missing';
            }

            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
            
            // Verify user is currently punched in
            List<User_Punch_State__c> curStateList = [
                SELECT Id, Current_Status__c 
                FROM User_Punch_State__c 
                WHERE User__c = :myId 
                LIMIT 1
            ];
            if (curStateList.isEmpty() || curStateList[0].Current_Status__c != 'IN') {
                return 'Error: User is not currently punched in';
            }

            // Find the latest active punch-in for this user
            List<Punch_Record__c> activePunches = [
                SELECT Id FROM Punch_Record__c 
                WHERE User__c = :myId AND Action__c = 'IN' 
                ORDER BY Punch_Time__c DESC LIMIT 1
            ];

            if (activePunches.isEmpty()) {
                return 'Error: No active punch-in found for user ' + myId;
            }

            Id punchRecordId = activePunches[0].Id;

            // Retrieve the latest logged location coordinates from the database for this punch record
            List<Track_Location__c> dbLastLocations = [
                SELECT Latitude__c, Longitude__c 
                FROM Track_Location__c 
                WHERE Punch_Record__c = :punchRecordId 
                ORDER BY Recorded_At__c DESC NULLS LAST, CreatedDate DESC 
                LIMIT 1
            ];
            
            Decimal lastLat = null;
            Decimal lastLng = null;
            Boolean checkDuplicate = true;
            if (!dbLastLocations.isEmpty() && String.isNotBlank(dbLastLocations[0].Latitude__c) && String.isNotBlank(dbLastLocations[0].Longitude__c)) {
                try {
                    lastLat = Decimal.valueOf(dbLastLocations[0].Latitude__c);
                    lastLng = Decimal.valueOf(dbLastLocations[0].Longitude__c);
                } catch (Exception ex) {}
            } else {
                checkDuplicate = false;
                List<Punch_Record__c> prs = [SELECT Latitude__c, Longitude__c FROM Punch_Record__c WHERE Id = :punchRecordId LIMIT 1];
                if (!prs.isEmpty() && prs[0].Latitude__c != null && prs[0].Longitude__c != null) {
                    lastLat = prs[0].Latitude__c;
                    lastLng = prs[0].Longitude__c;
                }
            }

            List<Track_Location__c> tlsToInsert = new List<Track_Location__c>();
            Decimal latestInputLat = null;
            Decimal latestInputLng = null;
            Decimal latestInputBattery = null;

            if (data.containsKey('locations')) {
                // iOS GeoJSON Format - extract coordinates from all locations in the batch
                List<Object> locationsList = (List<Object>) data.get('locations');
                if (locationsList != null) {
                    for (Object locObj : locationsList) {
                        Map<String, Object> loc = (Map<String, Object>) locObj;
                        Map<String, Object> geom = (Map<String, Object>) loc.get('geometry');
                        if (geom != null && geom.containsKey('coordinates')) {
                            List<Object> coords = (List<Object>) geom.get('coordinates');
                            if (coords != null && coords.size() >= 2) {
                                Decimal newLng = Decimal.valueOf(String.valueOf(coords[0]));
                                Decimal newLat = Decimal.valueOf(String.valueOf(coords[1]));
                                
                                latestInputLng = newLng;
                                latestInputLat = newLat;

                                // Calculate distance in meters
                                if (checkDuplicate && lastLat != null && lastLng != null) {
                                    Decimal dist = calculateDistanceMeters(lastLat, lastLng, newLat, newLng);
                                    if (dist <= 20.0) {
                                        continue; // Skip this point as it's within 20 meters of the last valid point
                                    }
                                }
                                
                                Track_Location__c tl = new Track_Location__c();
                                tl.Punch_Record__c = punchRecordId;
                                tl.Longitude__c = String.valueOf(newLng);
                                tl.Latitude__c = String.valueOf(newLat);
                                tl.Source__c = 'AppleApp';
                                Map<String, Object> props = (Map<String, Object>) loc.get('properties');
                                tl.Recorded_At__c = parseRecordedAt(props);
                                tlsToInsert.add(tl);
                                
                                // Update comparison point to this accepted point
                                lastLat = newLat;
                                lastLng = newLng;
                                checkDuplicate = true;
                            }
                        }
                    }
                    if (!locationsList.isEmpty()) {
                        Map<String, Object> lastLoc = (Map<String, Object>) locationsList[locationsList.size() - 1];
                        Map<String, Object> props = (Map<String, Object>) lastLoc.get('properties');
                        if (props != null && props.containsKey('battery_level')) {
                            latestInputBattery = Decimal.valueOf(String.valueOf(props.get('battery_level'))) * 100.0;
                        }
                    }
                }
            } else if (data.containsKey('points') || data.containsKey('point')) {
                // New Android Format (Batch/Bulk or Single)
                List<Object> pointsList = new List<Object>();
                if (data.containsKey('points')) {
                    pointsList = (List<Object>) data.get('points');
                } else if (data.containsKey('point')) {
                    pointsList.add(data.get('point'));
                }
                
                if (pointsList != null) {
                    // Sort by device capture time so bulk uploads draw in journey order
                    pointsList.sort(new PointByRecordedAtComparator());
                    for (Object ptObj : pointsList) {
                        Map<String, Object> point = (Map<String, Object>) ptObj;
                        if (point != null && point.containsKey('latitude') && point.containsKey('longitude')) {
                            Decimal newLng = Decimal.valueOf(String.valueOf(point.get('longitude')));
                            Decimal newLat = Decimal.valueOf(String.valueOf(point.get('latitude')));
                            
                            latestInputLng = newLng;
                            latestInputLat = newLat;

                            // Calculate distance in meters
                            if (checkDuplicate && lastLat != null && lastLng != null) {
                                Decimal dist = calculateDistanceMeters(lastLat, lastLng, newLat, newLng);
                                if (dist <= 20.0) {
                                    continue; // Skip this point as it's within 20 meters of the last valid point
                                }
                            }
                            
                            Track_Location__c tl = new Track_Location__c();
                            tl.Punch_Record__c = punchRecordId;
                            tl.Longitude__c = String.valueOf(newLng);
                            tl.Latitude__c = String.valueOf(newLat);
                            tl.Source__c = 'Logger';
                            tl.Recorded_At__c = parseRecordedAt(point);
                            tlsToInsert.add(tl);
                            
                            // Update comparison point to this accepted point
                            lastLat = newLat;
                            lastLng = newLng;
                            checkDuplicate = true;
                        }
                    }
                    if (!pointsList.isEmpty()) {
                        Map<String, Object> lastPt = (Map<String, Object>) pointsList[pointsList.size() - 1];
                        if (lastPt != null && lastPt.containsKey('batteryPercent')) {
                            latestInputBattery = Decimal.valueOf(String.valueOf(lastPt.get('batteryPercent')));
                        }
                    }
                }
            } else {
                // Legacy Android Format
                if (data.containsKey('latitude'))  latestInputLat = Decimal.valueOf(String.valueOf(data.get('latitude')));
                if (data.containsKey('longitude')) latestInputLng = Decimal.valueOf(String.valueOf(data.get('longitude')));
                if (data.containsKey('battery'))   latestInputBattery = Decimal.valueOf(String.valueOf(data.get('battery')));
                
                Boolean shouldInsert = true;
                if (checkDuplicate && latestInputLat != null && latestInputLng != null && lastLat != null && lastLng != null) {
                    Decimal dist = calculateDistanceMeters(lastLat, lastLng, latestInputLat, latestInputLng);
                    if (dist <= 20.0) {
                        shouldInsert = false; // Skip this point
                    }
                }
                
                if (shouldInsert && latestInputLat != null && latestInputLng != null) {
                    Track_Location__c tl = new Track_Location__c();
                    tl.Punch_Record__c = punchRecordId;
                    tl.Latitude__c  = String.valueOf(latestInputLat);
                    tl.Longitude__c = String.valueOf(latestInputLng);
                    tl.Source__c = 'Logger';
                    tl.Recorded_At__c = parseRecordedAt(data);
                    tlsToInsert.add(tl);
                }
            }

            if (!tlsToInsert.isEmpty()) {
                insert tlsToInsert;
            }

            // Always update live position and battery on User_Punch_State__c
            List<User_Punch_State__c> stateList = [
                SELECT Id FROM User_Punch_State__c WHERE User__c = :myId LIMIT 1
            ];
            User_Punch_State__c state = new User_Punch_State__c();
            if (!stateList.isEmpty()) {
                state.Id = stateList[0].Id;
            } else {
                state.User__c = myId;
            }

            if (latestInputLat != null)     state.Latitude__c = latestInputLat;
            if (latestInputLng != null)     state.Longitude__c = latestInputLng;
            if (latestInputBattery != null) state.Battery_Percentage__c = latestInputBattery;
            state.Last_Punch_Time__c = System.now();
            state.Current_Status__c = 'IN';
            state.Punch_In_Record__c = punchRecordId;

            upsert state;
            if (!tlsToInsert.isEmpty()) {
                return 'POST success. ' + tlsToInsert.size() + ' location(s) logged for user ' + myId;
            } else {
                return 'POST success. Location updates skipped (all points within 20 meters of last logged point)';
            }
        } catch (Exception e) {
            System.debug('Error in POST Location Update: ' + e.getMessage());
            RestContext.response.statusCode = 400;
            return 'Error: ' + e.getMessage();
        }
    }

    private static Decimal calculateDistanceMeters(Decimal lat1, Decimal lon1, Decimal lat2, Decimal lon2) {
        if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
            return 0.0;
        }
        Double radius = 6371000.0; // Earth radius in meters
        Double dLat = Double.valueOf(lat2 - lat1) * Math.PI / 180.0;
        Double dLon = Double.valueOf(lon2 - lon1) * Math.PI / 180.0;
        Double rLat1 = Double.valueOf(lat1) * Math.PI / 180.0;
        Double rLat2 = Double.valueOf(lat2) * Math.PI / 180.0;
        Double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                   Math.cos(rLat1) * Math.cos(rLat2) *
                   Math.sin(dLon / 2) * Math.sin(dLon / 2);
        Double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return Decimal.valueOf(radius * c);
    }

    /**
     * Prefer device capture time (recordedAtEpochMs / recordedAt / timestamp), else now.
     */
    private static Datetime parseRecordedAt(Map<String, Object> source) {
        if (source == null) {
            return System.now();
        }
        try {
            if (source.containsKey('recordedAtEpochMs') && source.get('recordedAtEpochMs') != null) {
                Long ms = Long.valueOf(String.valueOf(source.get('recordedAtEpochMs')));
                return Datetime.newInstance(ms);
            }
            if (source.containsKey('timestamp') && source.get('timestamp') != null) {
                // iOS / GeoJSON often sends epoch seconds or ms
                Decimal raw = Decimal.valueOf(String.valueOf(source.get('timestamp')));
                Long ms = raw > 1000000000000L ? raw.longValue() : (raw * 1000).longValue();
                return Datetime.newInstance(ms);
            }
            if (source.containsKey('recordedAt') && source.get('recordedAt') != null) {
                String iso = String.valueOf(source.get('recordedAt')).trim();
                // "2026-08-04T22:27:20.737+05:30" -> parse via epoch if present elsewhere already handled
                // Fallback: strip offset and treat as local wall time parts
                if (iso.length() >= 19) {
                    String core = iso.substring(0, 19).replace('T', ' ');
                    return Datetime.valueOf(core);
                }
            }
        } catch (Exception e) {
            System.debug('parseRecordedAt failed: ' + e.getMessage());
        }
        return System.now();
    }

    /**
     * Sort bulk Android points by recordedAtEpochMs ascending.
     */
    private class PointByRecordedAtComparator implements Comparator<Object> {
        public Integer compare(Object a, Object b) {
            Long aMs = extractEpochMs((Map<String, Object>) a);
            Long bMs = extractEpochMs((Map<String, Object>) b);
            if (aMs == bMs) return 0;
            return aMs < bMs ? -1 : 1;
        }
        private Long extractEpochMs(Map<String, Object> point) {
            if (point == null) return 0L;
            try {
                if (point.containsKey('recordedAtEpochMs') && point.get('recordedAtEpochMs') != null) {
                    return Long.valueOf(String.valueOf(point.get('recordedAtEpochMs')));
                }
            } catch (Exception e) {}
            return 0L;
        }
    }
}
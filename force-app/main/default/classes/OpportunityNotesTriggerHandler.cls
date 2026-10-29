public class OpportunityNotesTriggerHandler {

    public static void afterUpdate(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {

        List<ContentNote> contentNotes = new List<ContentNote>();
        Map<Integer, Id> parentMap = new Map<Integer, Id>();

        Integer index = 0;

        for (Opportunity opp : newList) {

            String oldValue = oldMap.get(opp.Id).Notes__c;
            String newValue = opp.Notes__c;

            if (oldValue == newValue || String.isBlank(newValue)) {
                continue;
            }

            String diff = null;

            if (String.isBlank(oldValue)) {
                diff = newValue;
            }
            else if (newValue.length() > oldValue.length()) {

                diff = newValue.substring(oldValue.length()).trim();

                if (diff.startsWith('-')) {
                    diff = diff.substring(1).trim();
                }
            }

            if (String.isBlank(diff)) {
                continue;
            }

            ContentNote cn = new ContentNote();
            cn.Title = 'Opportunity Note';
            cn.Content = Blob.valueOf(diff);

            contentNotes.add(cn);
            parentMap.put(index++, opp.Id);
        }

        if (!contentNotes.isEmpty()) {

            insert contentNotes;

            List<ContentDocumentLink> links = new List<ContentDocumentLink>();

            for (Integer i = 0; i < contentNotes.size(); i++) {

                links.add(new ContentDocumentLink(
                    ContentDocumentId = contentNotes[i].Id,
                    LinkedEntityId = parentMap.get(i),
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                ));
            }

            insert links;
        }
    }
}
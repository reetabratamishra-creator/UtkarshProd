public class MetadataService {

    public static String getMetadataPrompt(){

        String prompt = '';

        List<Tender_Key_Words_Final__mdt> records =
        [
            SELECT Department__c,
                   Matched_Positive_Keywords__c,
                   Matched_Negative_Keywords__c
            FROM Tender_Key_Words_Final__mdt
        ];

        for(Tender_Key_Words_Final__mdt rec : records){

            prompt +=
                '\nDepartment : ' +
                rec.Department__c;

            prompt +=
                '\nPositive Keywords : ' +
                rec.Matched_Positive_Keywords__c;

            prompt +=
                '\nNegative Keywords : ' +
                rec.Matched_Negative_Keywords__c;

            prompt +=
                '\n--------------------';
        }

        return prompt;
    }
}
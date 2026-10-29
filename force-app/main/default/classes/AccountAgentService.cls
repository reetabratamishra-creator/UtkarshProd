public with sharing class AccountAgentService {

    @AuraEnabled
    public static AgentResponse askAgent(Id accountId, String userMessage, String sessionId) {
        AgentResponse resp = new AgentResponse();
        try {
            Invocable.Action action = Invocable.Action.createCustomAction(
                'generateAiAgentResponse',
                null,
                'Record_Summary_Agent', // <-- replace with your agent's API name
                '1.0.0'                          // <-- replace with your agent's version
            );

            action.setInvocationParameter('userMessage', userMessage);
            action.setInvocationParameter('accountId', accountId); // context variable

            if (String.isNotBlank(sessionId)) {
                action.setInvocationParameter('sessionId', sessionId);
            }

            List<Invocable.Action.Result> results = action.invoke();
            Invocable.Action.Result result = results[0];

            if (result.isSuccess()) {
                resp.reply = (String) result.getOutputParameters().get('agentResponse');
                resp.sessionId = (String) result.getOutputParameters().get('sessionId');
                resp.success = true;
            } else {
                resp.success = false;
                List<String> errorMessages = new List<String>();
                for (Invocable.Action.Error err : result.getErrors()) {
                    errorMessages.add(err.getMessage());
                }
                resp.errorMessage = String.join(errorMessages, '; ');
            }
        } catch (Exception e) {
            resp.success = false;
            resp.errorMessage = e.getMessage();
        }
        return resp;
    }

    public class AgentResponse {
        @AuraEnabled public String reply;
        @AuraEnabled public String sessionId;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
    }
}
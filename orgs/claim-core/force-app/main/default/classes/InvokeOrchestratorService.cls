public with sharing class InvokeOrchestratorService {

    private static final String CONFIG_NAME =
        'Estimation_Orchestrator_Agent';

    public class OrchestratorInput {
        @InvocableVariable(label='Claim Id' required=true)
        public String claimId;

        @InvocableVariable(label='Claim Number' required=false)
        public String claimNumber;
    }

    public class OrchestratorResult {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Estimated Amount')
        public Decimal estimatedAmount;

        @InvocableVariable(label='Confidence Score')
        public Decimal confidenceScore;

        @InvocableVariable(label='Decision')
        public String decision;

        @InvocableVariable(label='Claim Number')
        public String claimNumber;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Invoke Estimation Orchestrator Agent'
        description='Invokes Agent 2 Estimation Orchestrator via Headless Agent API passing the Claim ID. Agent 2 then calls Agent 3 in claim-estimator and returns the estimation result.'
    )
    public static List<OrchestratorResult> invoke(
        List<OrchestratorInput> inputs
    ) {
        List<OrchestratorResult> results =
            new List<OrchestratorResult>();

        for (OrchestratorInput input : inputs) {
            OrchestratorResult result =
                new OrchestratorResult();

            try {
                // Single line A2A call ✅
                String agentResponse = HeadlessAgentAPI.invoke(
                    CONFIG_NAME, input.claimId
                );

                result.success         = true;
                result.message         = agentResponse;
                result.claimNumber     = input.claimNumber;
                result.estimatedAmount =
                    parseAmount(agentResponse);
                result.confidenceScore =
                    parseConfidence(agentResponse);
                result.decision        =
                    parseDecision(agentResponse);

            } catch (Exception e) {
                System.debug('Orchestrator invoke error: ' +
                    e.getMessage());
                result.success      = false;
                result.errorMessage = e.getMessage();
                result.message      =
                    'Your claim has been submitted. ' +
                    'Our team will provide an estimate shortly.';
            }
            results.add(result);
        }
        return results;
    }

    private static Decimal parseAmount(String response) {
        if (String.isBlank(response)) return 0;
        try {
            Pattern p = Pattern.compile(
                'AUD\\s*([\\d,]+(?:\\.\\d{1,2})?)'
            );
            Matcher m = p.matcher(response);
            if (m.find()) {
                return Decimal.valueOf(
                    m.group(1).replace(',', '')
                );
            }
        } catch (Exception e) {
            System.debug('Amount parse: ' + e.getMessage());
        }
        return 0;
    }

    private static Decimal parseConfidence(String response) {
        if (String.isBlank(response)) return 0;
        try {
            Pattern p = Pattern.compile(
                '([\\d]+(?:\\.\\d{1,2})?)\\s*%'
            );
            Matcher m = p.matcher(response);
            if (m.find()) {
                return Decimal.valueOf(m.group(1));
            }
        } catch (Exception e) {
            System.debug('Confidence parse: ' + e.getMessage());
        }
        return 0;
    }

    private static String parseDecision(String response) {
        if (String.isBlank(response)) return 'Review';
        String upper = response.toUpperCase();
        if (upper.contains('APPROVE')) return 'Approve';
        if (upper.contains('REJECT'))  return 'Reject';
        return 'Review';
    }
}
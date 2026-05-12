public with sharing class EstimationOrchestratorService {

    public class OrchestratorInput {
        @InvocableVariable(label='Claim Id' required=true)
        public String claimId;
    }

    public class OrchestratorResult {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Claim Number')
        public String claimNumber;

        @InvocableVariable(label='Agent Response')
        public String agentResponse;

        @InvocableVariable(label='Estimated Amount')
        public Decimal estimatedAmount;

        @InvocableVariable(label='Confidence Score')
        public Decimal confidenceScore;

        @InvocableVariable(label='Decision')
        public String decision;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    private static final String CONFIG_NAME =
        'Claim_Estimator_Agent';

    @InvocableMethod(
        label='Orchestrate Claim Estimation'
        description='Reads Claim__c record, invokes Claim Estimation Agent via A2A Headless Agent API and updates Claim__c with result.'
    )
    public static List<OrchestratorResult> orchestrate(
        List<OrchestratorInput> inputs
    ) {
        List<OrchestratorResult> results =
            new List<OrchestratorResult>();

        for (OrchestratorInput input : inputs) {
            OrchestratorResult result =
                new OrchestratorResult();
            String accessToken = null;
            String sessionId   = null;
            
            try {
                // Step 1: Read Claim__c
                Claim__c claim = [
                    SELECT Id, Name,
                    RecordType.DeveloperName,
                    Vehicle_Type__c,
                    Damage_Level__c,
                    Incident_Description__c,
                    Vehicle_Registration__c,
                    Claim_Status__c
                    FROM   Claim__c
                    WHERE  Id = :input.claimId
                    OR     Name = :input.claimId
                    LIMIT  1
                ];
                
                String claimType =
                    claim.RecordType.DeveloperName;

                // Step 2: Build message for Agent 3
                String message =
                    'Estimate a ' + claimType + ' claim.' +
                    ' Claim ID: ' + claim.Name +
                    '. Vehicle: ' + claim.Vehicle_Type__c +
                    '. Damage Level: ' + claim.Damage_Level__c +
                    '. Description: ' +
                    (String.isBlank(
                        claim.Incident_Description__c) ?
                    'Not provided' :
                    claim.Incident_Description__c);

                // Step 3: CALLOUTS — no DML before
                accessToken = HeadlessAgentAPI.getAccessToken(CONFIG_NAME);
                sessionId   = HeadlessAgentAPI.createSession(CONFIG_NAME, accessToken);
                String response = HeadlessAgentAPI.sendMessage(
                    accessToken, sessionId, message, 1
                );
                String agentResponse =
                    HeadlessAgentAPI.parseResponse(response);

                // End session
                HeadlessAgentAPI.endSession(
                    accessToken, sessionId
                );

                // Step 4: Parse estimation values
                Decimal estimatedAmount =
                    parseAmount(agentResponse);
                Decimal confidenceScore =
                    parseConfidence(agentResponse);
                String  decision        =
                    parseDecision(agentResponse);

                // Step 5: DML — Update Claim__c
                update new Claim__c(
                    Id                   = claim.Id,
                    Claim_Status__c      = 'Estimated',
                    Estimation_Status__c = 'Completed',
                    Estimated_Cost__c    = estimatedAmount,
                    Confidence_Score__c  = confidenceScore
                );

                // Step 6: Log interaction
                insert new Agent_Interaction__c(
                    Tool_Name__c             =
                        'estimation_orchestrator',
                    Agent_Name__c            =
                        'Claim_Estimation_Agent',
                    Server_Name__c           = 'claim-estimator',
                    Request_Payload__c       = message,
                    Response_Payload__c      = agentResponse,
                    Interaction_Status__c    = 'Success',
                    Interaction_Timestamp__c = System.now(),
                    Claim__c                 = claim.Id,
                    Duration_MS__c           = 0
                );

                result.success         = true;
                result.claimNumber     = claim.Name;
                result.agentResponse   = agentResponse;
                result.estimatedAmount = estimatedAmount;
                result.confidenceScore = confidenceScore;
                result.decision        = decision;
                result.message         =
                    'Claim ' + claim.Name +
                    ' has been assessed by our specialist agent.\n\n' +
                    'Estimated Amount: AUD ' + estimatedAmount +
                    '\nConfidence Score: ' + confidenceScore + '%' +
                    '\nDecision: ' + decision;

            } catch (Exception e) {
                System.debug('Orchestrator error: ' +
                    e.getMessage());
                result.success      = false;
                result.errorMessage = e.getMessage();
                result.message      =
                    'Estimation could not be completed. ' +
                    'Your claim has been received and our ' +
                    'team will review it shortly.';

                if (accessToken != null &&
                    sessionId   != null) {
                    HeadlessAgentAPI.endSession(
                        accessToken, sessionId
                    );
                }

                // Update claim status on failure
                if (!String.isBlank(input.claimId)) {
                    try {
                        update new Claim__c(
                            Id                   = input.claimId,
                            Estimation_Status__c = 'Failed'
                        );
                    } catch (Exception ex) {}
                }
            }
            results.add(result);
        }
        return results;
    }

    // ─────────────────────────────────────────
    // Parse Estimated Amount from response
    // ─────────────────────────────────────────
    private static Decimal parseAmount(String response) {
        if (String.isBlank(response)) return 0;
        try {
            Pattern p = Pattern.compile(
                'AUD\\s*([\\d,]+(?:\\.\\d{1,2})?)'
            );
            Matcher m = p.matcher(response);
            if (m.find()) {
                String amount = m.group(1)
                    .replace(',', '');
                return Decimal.valueOf(amount);
            }
        } catch (Exception e) {
            System.debug('Amount parse error: ' +
                e.getMessage());
        }
        return 0;
    }

    // ─────────────────────────────────────────
    // Parse Confidence Score from response
    // ─────────────────────────────────────────
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
            System.debug('Confidence parse error: ' +
                e.getMessage());
        }
        return 0;
    }

    // ─────────────────────────────────────────
    // Parse Decision from response
    // ─────────────────────────────────────────
    private static String parseDecision(String response) {
        if (String.isBlank(response)) return 'Review';
        String upper = response.toUpperCase();
        if (upper.contains('APPROVE')) return 'Approve';
        if (upper.contains('REJECT'))  return 'Reject';
        return 'Review';
    }
}
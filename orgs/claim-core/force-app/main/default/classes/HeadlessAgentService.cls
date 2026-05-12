public with sharing class HeadlessAgentService {

    private static final String CONFIG_NAME =
        'Claim_Estimator_Agent';

    // ─────────────────────────────────────────
    // Helper: Build Message
    // ─────────────────────────────────────────
    private static String buildMessage(AgentRequest req) {
        return 'Estimate a ' + req.claimType + ' claim.' +
            ' Claim ID: ' +
            (String.isBlank(req.claimId) ? 'NEW' : req.claimId) +
            '. Vehicle: '      + req.vehicleType +
            '. Damage Level: ' + req.damageLevel +
            '. Description: '  + req.incidentDescription;
    }

    // ─────────────────────────────────────────
    // Helper: Create Claim__c
    // ─────────────────────────────────────────
    private static Claim__c createClaimRecord(
        AgentRequest request,
        Boolean estimationSuccess
    ) {
        try {
            Map<String, Schema.RecordTypeInfo> rtMap =
                Schema.SObjectType.Claim__c
                .getRecordTypeInfosByDeveloperName();

            if (!rtMap.containsKey(request.claimType)) {
                System.debug('Invalid claim type: ' +
                    request.claimType);
                return null;
            }

            Claim__c claim = new Claim__c(
                RecordTypeId            = rtMap.get(
                    request.claimType).getRecordTypeId(),
                Claim_Status__c         = estimationSuccess ?
                    'Estimated' : 'Submitted',
                Vehicle_Type__c         = request.vehicleType,
                Damage_Level__c         = request.damageLevel,
                Incident_Description__c =
                    request.incidentDescription,
                Vehicle_Registration__c =
                    request.vehicleRegistration,
                Estimation_Status__c    = estimationSuccess ?
                    'Completed' : 'Failed'
            );
            insert claim;

            return [
                SELECT Id, Name FROM Claim__c
                WHERE Id = :claim.Id
            ];

        } catch (Exception e) {
            System.debug('Claim creation failed: ' +
                e.getMessage());
            return null;
        }
    }

    // ─────────────────────────────────────────
    // Helper: Log Interaction
    // ─────────────────────────────────────────
    private static void logInteraction(
        String requestPayload,
        String responsePayload,
        Boolean success,
        Id claimId
    ) {
        try {
            insert new Agent_Interaction__c(
                Tool_Name__c             = 'headless_agent_api',
                Agent_Name__c            = 'Claim_Estimation_Agent',
                Server_Name__c           = 'claim-estimator',
                Request_Payload__c       = requestPayload,
                Response_Payload__c      = responsePayload,
                Interaction_Status__c    = success ?
                    'Success' : 'Failed',
                Interaction_Timestamp__c = System.now(),
                Claim__c                 = claimId,
                Duration_MS__c           = 0
            );
        } catch (Exception e) {
            System.debug('Logging failed: ' + e.getMessage());
        }
    }

    // ─────────────────────────────────────────
    // Main InvocableMethod
    // ─────────────────────────────────────────
    @InvocableMethod(
        label='Invoke Estimator Agent via Headless API'
        description='Invokes Claim Estimation Agent in claim-estimator org via A2A Headless Agent API. Creates Claim__c and logs Agent_Interaction__c.'
    )
    public static List<AgentEstimationResult> invokeAgent(
        List<AgentRequest> requests
    ) {
        List<AgentEstimationResult> results =
            new List<AgentEstimationResult>();

        for (AgentRequest request : requests) {
            AgentEstimationResult result =
                new AgentEstimationResult();

            try {
                String message = buildMessage(request);

                // Single line A2A call ✅
                String agentResponse = HeadlessAgentAPI.invoke(
                    CONFIG_NAME, message
                );

                result.agentResponse = agentResponse;
                result.claimType     = request.claimType;
                result.success       = true;

                // DML AFTER callout
                Claim__c claim = createClaimRecord(
                    request, true
                );
                String claimNumber = claim != null ?
                    claim.Name : 'PENDING';
                result.claimNumber = claimNumber;

                logInteraction(
                    message, agentResponse, true,
                    claim != null ? claim.Id : null
                );

                result.agentResponse =
                    'Claim ' + claimNumber +
                    ' submitted and assessed.\n\n' +
                    agentResponse;

            } catch (HeadlessAgentAPI.AgentAPIException e) {
                System.debug('Agent API Error: ' +
                    e.getMessage());
                result.success      = false;
                result.errorMessage = e.getMessage();
                result.agentResponse =
                    'Your claim has been received. ' +
                    'Our specialist team will review shortly.';

            } catch (Exception e) {
                System.debug('Unexpected Error: ' +
                    e.getMessage());
                result.success      = false;
                result.errorMessage = e.getMessage();
                result.agentResponse =
                    'An unexpected error occurred. ' +
                    'Please try again.';
            }

            results.add(result);
        }
        return results;
    }

    // ─────────────────────────────────────────
    // Input / Output Classes
    // ─────────────────────────────────────────
    public class AgentRequest {
        @InvocableVariable(label='Claim Type' required=true)
        public String claimType;

        @InvocableVariable(label='Damage Level' required=true)
        public String damageLevel;

        @InvocableVariable(label='Vehicle Type' required=true)
        public String vehicleType;

        @InvocableVariable(label='Incident Description'
                           required=false)
        public String incidentDescription;

        @InvocableVariable(label='Claim Id' required=false)
        public String claimId;

        @InvocableVariable(label='Vehicle Registration'
                           required=false)
        public String vehicleRegistration;
    }

    public class AgentEstimationResult {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Agent Response')
        public String agentResponse;

        @InvocableVariable(label='Claim Number')
        public String claimNumber;

        @InvocableVariable(label='Claim Type')
        public String claimType;

        @InvocableVariable(label='Raw Response')
        public String rawResponse;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
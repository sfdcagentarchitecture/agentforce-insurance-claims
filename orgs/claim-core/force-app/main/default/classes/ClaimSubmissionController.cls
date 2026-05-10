public with sharing class ClaimSubmissionController {

    @InvocableMethod(
        label='Submit Insurance Claim'
        description='Creates a Claim record and calls estimator org via MCP Gateway'
    )
    public static List<ClaimOutput> submitClaim(List<ClaimInput> inputs) {
        List<ClaimOutput> outputs = new List<ClaimOutput>();

        for (ClaimInput input : inputs) {
            ClaimOutput output = new ClaimOutput();
            try {
                if (String.isBlank(input.claimType)) {
                    output.success = false;
                    output.message = 'Claim type is required';
                    outputs.add(output);
                    continue;
                }
                if (String.isBlank(input.incidentDate)) {
                    output.success = false;
                    output.message = 'Incident date is required';
                    outputs.add(output);
                    continue;
                }

                Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Claim__c
                    .getRecordTypeInfosByDeveloperName();
                if (!rtMap.containsKey(input.claimType)) {
                    output.success = false;
                    output.message = 'Invalid claim type: ' + input.claimType;
                    outputs.add(output);
                    continue;
                }
                Id recordTypeId = rtMap.get(input.claimType).getRecordTypeId();

                // Call MCP Gateway FIRST (before DML)
                MCPClaimEstimationService.EstimationResult estimation =
                    MCPClaimEstimationService.estimate(
                        'PENDING',
                        input.claimType,
                        input.damageLevel,
                        input.vehicleType,
                        input.incidentDescription
                    );

                // Create Claim__c
                Claim__c claim = new Claim__c(
                    RecordTypeId            = recordTypeId,
                    Claim_Status__c         = estimation.success ?
                                             'Estimated' : 'Submitted',
                    Incident_Date__c        = Date.valueOf(input.incidentDate),
                    Vehicle_Type__c         = input.vehicleType,
                    Vehicle_Registration__c = input.vehicleRegistration,
                    Damage_Level__c         = input.damageLevel,
                    Incident_Location__c    = input.incidentLocation,
                    Incident_Description__c = input.incidentDescription,
                    Customer_Name__c        = input.customerName,
                    Estimated_Cost__c       = estimation.success ?
                                             estimation.estimatedAmount : null,
                    Confidence_Score__c     = estimation.success ?
                                             estimation.confidenceScore : null,
                    Estimation_Status__c    = estimation.success ?
                                             'Completed' : 'Failed'
                );
                insert claim;

                // Re-query to get claim number
                claim = [SELECT Id, Name FROM Claim__c WHERE Id = :claim.Id];

                // Update Agent Interaction with real Claim Id
                List<Agent_Interaction__c> interactions = [
                    SELECT Id FROM Agent_Interaction__c
                    WHERE Tool_Name__c = 'estimate_claim'
                    AND Claim__c = null
                    AND Interaction_Timestamp__c = TODAY
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                if (!interactions.isEmpty()) {
                    interactions[0].Claim__c = claim.Id;
                    update interactions[0];
                }

                if (estimation.success) {
                    output.success         = true;
                    output.claimNumber     = claim.Name;
                    output.estimatedAmount = estimation.estimatedAmount;
                    output.confidenceScore = estimation.confidenceScore;
                    output.message         = 'Your claim ' + claim.Name +
                        ' has been successfully submitted!' +
                        ' Estimated amount: AUD ' + estimation.estimatedAmount +
                        '. Confidence Score: ' + estimation.confidenceScore + '%.';
                } else {
                    output.success         = true;
                    output.claimNumber     = claim.Name;
                    output.estimatedAmount = 0;
                    output.confidenceScore = 0;
                    output.message         = 'Your claim ' + claim.Name +
                        ' has been submitted. Our team will ' +
                        'process the estimation shortly.';
                }

            } catch (Exception e) {
                output.success  = false;
                output.message  = 'Sorry, we could not submit your claim: ' +
                                   e.getMessage();
            }
            outputs.add(output);
        }
        return outputs;
    }

    public class ClaimInput {
        @InvocableVariable(label='Claim Type' required=true)
        public String claimType;

        @InvocableVariable(label='Incident Date' required=true)
        public String incidentDate;

        @InvocableVariable(label='Vehicle Type' required=true)
        public String vehicleType;

        @InvocableVariable(label='Vehicle Registration' required=false)
        public String vehicleRegistration;

        @InvocableVariable(label='Damage Level' required=true)
        public String damageLevel;

        @InvocableVariable(label='Incident Location' required=false)
        public String incidentLocation;

        @InvocableVariable(label='Incident Description' required=true)
        public String incidentDescription;

        @InvocableVariable(label='Customer Name' required=false)
        public String customerName;
    }

    public class ClaimOutput {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Claim Number')
        public String claimNumber;

        @InvocableVariable(label='Estimated Amount')
        public Decimal estimatedAmount;

        @InvocableVariable(label='Confidence Score')
        public Decimal confidenceScore;

        @InvocableVariable(label='Message')
        public String message;
    }
}
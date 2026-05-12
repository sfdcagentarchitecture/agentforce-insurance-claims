public with sharing class ClaimEstimationMCPTool {

    @InvocableMethod(
        label='Estimate Claim Cost'
        description='Estimates vehicle insurance claim cost in AUD. Returns estimated amount, confidence score and approve/review/reject decision. Claim types: Accident, Theft, Windscreen, Natural_Disaster. Damage levels: Minor, Major, Total Loss, Replace, Repair.'
    )
    public static List<EstimationOutput> estimateClaim(
        List<EstimationInput> inputs
    ) {
        List<EstimationOutput> outputs = new List<EstimationOutput>();

        for (EstimationInput input : inputs) {
            EstimationOutput output = new EstimationOutput();
            Estimate_Request__c req = null;
            try {
                // Step 1: Save Estimate_Request__c
                req = new Estimate_Request__c(
                    Claim_Id__c             = input.claimId,
                    Claim_Type__c           = input.claimType,
                    Damage_Level__c         = input.damageLevel,
                    Vehicle_Type__c         = input.vehicleType,
                    Incident_Description__c = input.incidentDescription,
                    Request_Status__c       = 'Processing',
                    Source_Org__c           = 'claim-core-native-mcp',
                    Request_Timestamp__c    = System.now()
                );
                insert req;

                // Step 2: Calculate
                Decimal baseEstimate    = calculateEstimate(input);
                Decimal confidenceScore = calculateConfidence(input);
                String  decision        = calculateDecision(
                                            baseEstimate, confidenceScore);
                String  ruleApplied     = input.claimType + '_' +
                    (String.isBlank(input.damageLevel) ? 'STANDARD' :
                    input.damageLevel.replaceAll(' ', '_')) + '_RULE';

                // Step 3: Save Estimate_Response__c
                Estimate_Response__c res = new Estimate_Response__c(
                    Estimate_Request__c   = req.Id,
                    Estimated_Amount__c   = baseEstimate,
                    Confidence_Score__c   = confidenceScore,
                    Decision__c           = decision,
                    Rule_Applied__c       = ruleApplied,
                    Response_Status__c    = 'Success',
                    Response_Timestamp__c = System.now()
                );
                insert res;

                // Step 4: Update request
                req.Request_Status__c = 'Completed';
                update req;

                // Step 5: Build output
                output.success         = true;
                output.estimatedAmount = baseEstimate;
                output.confidenceScore = confidenceScore;
                output.decision        = decision;
                output.ruleApplied     = ruleApplied;
                output.claimType       = input.claimType;
                output.message         = 'Estimation completed via Native MCP Agent. ' +
                                         'Estimated Amount: AUD ' + baseEstimate +
                                         '. Confidence: ' + confidenceScore +
                                         '%. Decision: ' + decision;

            } catch (Exception e) {
                output.success      = false;
                output.errorMessage = e.getMessage();
                if (req != null && req.Id != null) {
                    try {
                        req.Request_Status__c = 'Failed';
                        update req;
                    } catch (Exception ex) {}
                }
            }
            outputs.add(output);
        }
        return outputs;
    }

    private static Decimal calculateEstimate(EstimationInput input) {
        Decimal base = 0;
        switch on input.claimType {
            when 'Accident' {
                base = 5000.00;
                if (input.damageLevel == 'Minor')      base = 2000.00;
                if (input.damageLevel == 'Major')      base = 15000.00;
                if (input.damageLevel == 'Total Loss') base = 35000.00;
            }
            when 'Windscreen' {
                base = 500.00;
                if (input.damageLevel == 'Replace')    base = 1200.00;
                if (input.damageLevel == 'Repair')     base = 500.00;
            }
            when 'Theft' {
                base = 20000.00;
            }
            when 'Natural_Disaster' {
                base = 8000.00;
                if (input.damageLevel == 'Minor')      base = 8000.00;
                if (input.damageLevel == 'Major')      base = 25000.00;
                if (input.damageLevel == 'Total Loss') base = 35000.00;
            }
            when else {
                base = 3000.00;
            }
        }
        return base;
    }

    private static Decimal calculateConfidence(EstimationInput input) {
        Decimal confidence = 85.0;
        if (String.isBlank(input.incidentDescription)) confidence -= 10.0;
        if (String.isBlank(input.damageLevel))         confidence -= 10.0;
        if (String.isBlank(input.vehicleType))         confidence -= 5.0;
        return confidence < 0 ? 0 : confidence;
    }

    private static String calculateDecision(
        Decimal amount, Decimal confidence
    ) {
        if (confidence >= 80 && amount <= 20000) return 'Approve';
        if (confidence >= 60 && amount <= 35000) return 'Review';
        return 'Reject';
    }

    public class EstimationInput {
        @InvocableVariable(label='Claim Type' required=true)
        public String claimType;

        @InvocableVariable(label='Damage Level' required=true)
        public String damageLevel;

        @InvocableVariable(label='Vehicle Type' required=true)
        public String vehicleType;

        @InvocableVariable(label='Incident Description' required=false)
        public String incidentDescription;

        @InvocableVariable(label='Claim Id' required=false)
        public String claimId;
    }

    public class EstimationOutput {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Estimated Amount AUD')
        public Decimal estimatedAmount;

        @InvocableVariable(label='Confidence Score')
        public Decimal confidenceScore;

        @InvocableVariable(label='Decision')
        public String decision;

        @InvocableVariable(label='Rule Applied')
        public String ruleApplied;

        @InvocableVariable(label='Claim Type')
        public String claimType;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}
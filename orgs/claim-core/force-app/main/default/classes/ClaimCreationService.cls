public with sharing class ClaimCreationService {

    public class ClaimInput {
        @InvocableVariable(label='Claim Type' required=true)
        public String claimType;

        @InvocableVariable(label='Damage Level' required=true)
        public String damageLevel;

        @InvocableVariable(label='Vehicle Type' required=true)
        public String vehicleType;

        @InvocableVariable(label='Vehicle Registration'
                           required=false)
        public String vehicleRegistration;

        @InvocableVariable(label='Incident Description'
                           required=false)
        public String incidentDescription;

        @InvocableVariable(label='Incident Date'
                           required=false)
        public String incidentDate;

        @InvocableVariable(label='Customer Email'
                           required=false)
        public String customerEmail;

        @InvocableVariable(label='Case Id' required=false)
        public String caseId;

        @InvocableVariable(label='Contact Id'
                           required=false)
        public String contactId;
    }

    public class ClaimResult {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Claim Id')
        public String claimId;

        @InvocableVariable(label='Claim Number')
        public String claimNumber;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Create Claim Record'
        description='Creates Claim__c record linked to Case and Contact after successful validation and verification.'
    )
    public static List<ClaimResult> createClaim(
        List<ClaimInput> inputs
    ) {
        List<ClaimResult> results = new List<ClaimResult>();

        for (ClaimInput input : inputs) {
            ClaimResult result = new ClaimResult();
            try {
                // Get record type
                Map<String, Schema.RecordTypeInfo> rtMap =
                    Schema.SObjectType.Claim__c
                    .getRecordTypeInfosByDeveloperName();

                if (!rtMap.containsKey(input.claimType)) {
                    result.success      = false;
                    result.errorMessage =
                        'Invalid claim type: ' + input.claimType;
                    results.add(result);
                    continue;
                }

                // Build Claim__c
                Claim__c claim = new Claim__c(
                    RecordTypeId            = rtMap.get(
                        input.claimType).getRecordTypeId(),
                    Claim_Status__c         = 'Submitted',
                    Vehicle_Type__c         = input.vehicleType,
                    Damage_Level__c         = input.damageLevel,
                    Vehicle_Registration__c =
                        input.vehicleRegistration,
                    Incident_Description__c =
                        input.incidentDescription,
                    Customer_Email__c       =
                        input.customerEmail,
                    Estimation_Status__c    = 'Pending',
                    Validation_Status__c    = 'Valid'
                );

                // Link Case
                if (!String.isBlank(input.caseId)) {
                    claim.Case__c = input.caseId;
                }

                // Link incident date
                if (!String.isBlank(input.incidentDate)) {
                    try {
                        claim.Incident_Date__c =
                            Date.valueOf(input.incidentDate);
                    } catch (Exception e) {
                        System.debug('Date parse error: ' +
                            e.getMessage());
                    }
                }

                insert claim;

                // Re-query for claim number
                claim = [
                    SELECT Id, Name
                    FROM   Claim__c
                    WHERE  Id = :claim.Id
                ];

                result.success     = true;
                result.claimId     = claim.Id;
                result.claimNumber = claim.Name;
                result.message     =
                    'Claim ' + claim.Name +
                    ' created successfully. ' +
                    'We will now get an estimate for you.';

                System.debug('Claim created: ' + claim.Name);

            } catch (Exception e) {
                result.success      = false;
                result.errorMessage = e.getMessage();
                result.message      =
                    'Failed to create claim: ' + e.getMessage();
            }
            results.add(result);
        }
        return results;
    }
}
public with sharing class CaseManagementService {

    public class CaseInput {
        @InvocableVariable(label='Action' required=true)
        public String action;
        // CREATE_CASE, LINK_CONTACT

        @InvocableVariable(label='Customer Message'
                           required=false)
        public String customerMessage;

        @InvocableVariable(label='Sentiment Label'
                           required=false)
        public String sentimentLabel;

        @InvocableVariable(label='Sentiment Score'
                           required=false)
        public Decimal sentimentScore;

        @InvocableVariable(label='Is Priority'
                           required=false)
        public Boolean isPriority;

        @InvocableVariable(label='Case Id'
                           required=false)
        public String caseId;

        @InvocableVariable(label='Contact Id'
                           required=false)
        public String contactId;

        @InvocableVariable(label='Contact Name'
                           required=false)
        public String contactName;
    }

    public class CaseResult {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Case Id')
        public String caseId;

        @InvocableVariable(label='Case Number')
        public String caseNumber;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Case Management Service'
        description='Creates Case (CREATE_CASE) or links Contact to Case (LINK_CONTACT).'
    )
    public static List<CaseResult> execute(
        List<CaseInput> inputs
    ) {
        List<CaseResult> results = new List<CaseResult>();

        for (CaseInput input : inputs) {
            CaseResult result = new CaseResult();
            try {
                if (input.action == 'CREATE_CASE') {
                    result = createCase(input);
                } else if (input.action == 'LINK_CONTACT') {
                    result = linkContactToCase(input);
                } else {
                    result.success      = false;
                    result.errorMessage =
                        'Invalid action: ' + input.action;
                }
            } catch (Exception e) {
                result.success      = false;
                result.errorMessage = e.getMessage();
            }
            results.add(result);
        }
        return results;
    }

    // ─────────────────────────────────────────
    // CREATE_CASE
    // ─────────────────────────────────────────
    private static CaseResult createCase(CaseInput input) {
        CaseResult result = new CaseResult();

        Case newCase = new Case(
            Subject                = 'Insurance Claim Enquiry',
            Status                 = 'New',
            Origin                 = 'Web',
            Priority               =
                (input.isPriority == true) ?
                'High' : 'Medium',
            Description            = input.customerMessage,
            Sentiment_Label__c     =
                String.isBlank(input.sentimentLabel) ?
                'Neutral' : input.sentimentLabel,
            Sentiment_Score__c     =
                input.sentimentScore != null ?
                input.sentimentScore : 0.5,
            Verification_Status__c = 'Pending'
        );
        insert newCase;

        newCase = [
            SELECT Id, CaseNumber
            FROM   Case
            WHERE  Id = :newCase.Id
        ];

        result.success    = true;
        result.caseId     = newCase.Id;
        result.caseNumber = newCase.CaseNumber;
        result.message    =
            'Case ' + newCase.CaseNumber + ' created.';

        System.debug('Case created: ' + newCase.CaseNumber);
        return result;
    }

    // ─────────────────────────────────────────
    // LINK_CONTACT
    // ─────────────────────────────────────────
    private static CaseResult linkContactToCase(
        CaseInput input
    ) {
        CaseResult result = new CaseResult();

        update new Case(
            Id                     = input.caseId,
            ContactId              = input.contactId,
            Verification_Status__c = 'Verified',
            Subject                =
                'Insurance Claim - ' + input.contactName
        );

        result.success    = true;
        result.caseId     = input.caseId;
        result.message    =
            'Contact linked and case verified.';

        System.debug('Contact linked to case: ' +
            input.caseId);
        return result;
    }
}
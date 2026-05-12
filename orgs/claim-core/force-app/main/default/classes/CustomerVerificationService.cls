public with sharing class CustomerVerificationService {

    private static final Integer OTP_LENGTH      = 6;
    private static final Integer OTP_EXPIRY_MINS = 10;

    public class VerificationInput {
        @InvocableVariable(label='Action' required=true)
        public String action;

        @InvocableVariable(label='Email' required=false)
        public String email;

        @InvocableVariable(label='OTP Code' required=false)
        public String otpCode;

        @InvocableVariable(label='Case Id' required=false)
        public String caseId;
    }

    public class VerificationResult {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Contact Id')
        public String contactId;

        @InvocableVariable(label='Contact Name')
        public String contactName;

        @InvocableVariable(label='Is Verified')
        public Boolean isVerified;

        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }

    @InvocableMethod(
        label='Customer Verification'
        description='Finds Contact by email and sends OTP code to their email address (FIND_AND_SEND) or verifies the 6 digit OTP code entered by the customer (VERIFY_OTP). Only proceeds if Contact exists in Salesforce.'
    )
    public static List<VerificationResult> execute(
        List<VerificationInput> inputs
    ) {
        List<VerificationResult> results =
            new List<VerificationResult>();

        for (VerificationInput input : inputs) {
            VerificationResult result =
                new VerificationResult();
            try {
                if (input.action == 'FIND_AND_SEND') {
                    result = findAndSendOTP(
                        input.email, input.caseId
                    );
                } else if (input.action == 'VERIFY_OTP') {
                    result = verifyOTP(
                        input.caseId, input.otpCode
                    );
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

    private static VerificationResult findAndSendOTP(
        String email,
        String caseId
    ) {
        VerificationResult result = new VerificationResult();

        if (String.isBlank(email)) {
            result.success = false;
            result.message = 'Please provide your email.';
            return result;
        }
System.debug('email==='+email);
        List<Contact> contacts = [
            SELECT Id, Name, Email
            FROM   Contact
            WHERE  Email = :email.trim()
            AND    IsDeleted = false
            LIMIT  1
        ];
system.debug('contacts==='+contacts);
        if (contacts.isEmpty()) {
            result.success    = false;
            result.isVerified = false;
            result.message    =
                'We could not find your details in our system. ' +
                'Please contact us on 1800 CLAIMS to register.';
            return result;
        }

        Contact contact = contacts[0];
        String otp      = generateOTP();
        DateTime expiry =
            System.now().addMinutes(OTP_EXPIRY_MINS);

        if (!String.isBlank(caseId)) {
            update new Case(
                Id                     = caseId,
                ContactId              = contact.Id,
                Verification_Code__c   = otp,
                Verification_Status__c = 'Pending',
                Verification_Expiry__c = expiry
            );
        }

        sendOTPEmail(contact.Email, contact.Name, otp);

        result.success     = true;
        result.contactId   = contact.Id;
        result.contactName = contact.Name;
        result.isVerified  = false;
        result.message     =
            'Hi ' + contact.Name + '! ' +
            'A 6-digit verification code has been sent to ' +
            contact.Email + '. ' +
            'Please enter the code to verify your identity. ' +
            'It expires in ' + OTP_EXPIRY_MINS + ' minutes.';
        return result;
    }

    private static VerificationResult verifyOTP(
        String caseId,
        String otpCode
    ) {
        VerificationResult result = new VerificationResult();

        if (String.isBlank(caseId) ||
            String.isBlank(otpCode)) {
            result.success = false;
            result.message =
                'Please provide your verification code.';
            return result;
        }

        List<Case> cases = [
            SELECT Id, ContactId,
                   Contact.Name,
                   Contact.Email,
                   Verification_Code__c,
                   Verification_Status__c,
                   Verification_Expiry__c
            FROM   Case
            WHERE  Id = :caseId
            LIMIT  1
        ];

        if (cases.isEmpty()) {
            result.success = false;
            result.message =
                'Session not found. Please start again.';
            return result;
        }

        Case c = cases[0];

        if (c.Verification_Status__c == 'Verified') {
            result.success     = true;
            result.isVerified  = true;
            result.contactId   = c.ContactId;
            result.contactName = c.Contact.Name;
            result.message     = 'Already verified.';
            return result;
        }

        if (System.now() > c.Verification_Expiry__c) {
            update new Case(
                Id                     = caseId,
                Verification_Status__c = 'Failed'
            );
            result.success    = false;
            result.isVerified = false;
            result.message    =
                'Your code has expired. ' +
                'Please request a new one.';
            return result;
        }

        if (c.Verification_Code__c != otpCode.trim()) {
            result.success    = false;
            result.isVerified = false;
            result.message    =
                'Invalid code. Please check and try again.';
            return result;
        }

        update new Case(
            Id                     = caseId,
            Verification_Status__c = 'Verified'
        );

        result.success     = true;
        result.isVerified  = true;
        result.contactId   = c.ContactId;
        result.contactName = c.Contact.Name;
        result.message     =
            'Identity verified! Welcome ' +
            c.Contact.Name + '. ' +
            'Please provide your claim details.';
        return result;
    }

    private static String generateOTP() {
        String otp = '';
        for (Integer i = 0; i < OTP_LENGTH; i++) {
            Integer idx = Math.mod(
                Math.abs(Crypto.getRandomInteger()), 10
            );
            otp += String.valueOf(idx);
        }
        return otp;
    }

    private static void sendOTPEmail(
        String toEmail,
        String contactName,
        String otp
    ) {
        List<OrgWideEmailAddress> owas = [
            SELECT Id FROM OrgWideEmailAddress
            WHERE  Address = 'lingarajuntrailhead@gmail.com'
            LIMIT  1
        ];
        
        Messaging.SingleEmailMessage email =
            new Messaging.SingleEmailMessage();
        if (!owas.isEmpty()) {
            email.setOrgWideEmailAddressId(owas[0].Id);
        }
        email.setToAddresses(
            new List<String>{ toEmail }
        );
        email.setSubject(
            'Your Insurance Claims Verification Code'
        );
        email.setHtmlBody(
            '<div style="font-family:Arial,sans-serif;' +
            'max-width:600px;margin:0 auto;">' +
            '<h2 style="color:#1B5E8C;">' +
            'Insurance Claims Portal</h2>' +
            '<p>Dear ' + contactName + ',</p>' +
            '<p>Your verification code is:</p>' +
            '<div style="background:#f0f7ff;padding:20px;' +
            'text-align:center;border-radius:8px;' +
            'margin:20px 0;">' +
            '<h1 style="color:#1B5E8C;' +
            'letter-spacing:8px;font-size:36px;">' +
            otp + '</h1></div>' +
            '<p>This code expires in <strong>' +
            OTP_EXPIRY_MINS + ' minutes</strong>.</p>' +
            '<p>If you did not request this, ' +
            'please contact us immediately.</p>' +
            '</div>'
        );
        email.setSaveAsActivity(false);
        Messaging.sendEmail(
            new List<Messaging.SingleEmailMessage>{ email }
        );
        System.debug('OTP sent to: ' + toEmail);
    }
}
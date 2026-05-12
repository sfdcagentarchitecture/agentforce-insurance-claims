public with sharing class ClaimValidationService {

    public class ValidationInput {
        @InvocableVariable(label='Claim Type' required=true)
        public String claimType;

        @InvocableVariable(label='Damage Level' required=true)
        public String damageLevel;

        @InvocableVariable(label='Vehicle Type' required=true)
        public String vehicleType;

        @InvocableVariable(label='Vehicle Registration'
                           required=false)
        public String vehicleRegistration;

        @InvocableVariable(label='Incident Date'
                           required=false)
        public String incidentDate;

        @InvocableVariable(label='Case Id' required=false)
        public String caseId;
    }

    public class ValidationResult {
        @InvocableVariable(label='Is Valid')
        public Boolean isValid;

        @InvocableVariable(label='Validation Status')
        public String validationStatus;

        @InvocableVariable(label='Validation Reason')
        public String validationReason;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Success')
        public Boolean success;
    }

    // Valid values
    private static final Set<String> VALID_CLAIM_TYPES =
        new Set<String>{
            'Accident', 'Theft',
            'Windscreen', 'Natural_Disaster'
        };

    private static final Set<String> VALID_VEHICLE_TYPES =
        new Set<String>{
            'Sedan', 'SUV', 'Truck',
            'Hatchback', 'Motorcycle', 'Van'
        };

    private static final Map<String, Set<String>>
        VALID_DAMAGE_LEVELS =
        new Map<String, Set<String>>{
            'Accident'         => new Set<String>{
                'Minor', 'Major', 'Total Loss'
            },
            'Natural_Disaster' => new Set<String>{
                'Minor', 'Major', 'Total Loss'
            },
            'Windscreen'       => new Set<String>{
                'Repair', 'Replace'
            },
            'Theft'            => new Set<String>{
                'Major'
            }
        };

    @InvocableMethod(
        label='Validate Claim'
        description='Validates claim details against business rules. Checks claim type, vehicle type, damage level, incident date and duplicate claims.'
    )
    public static List<ValidationResult> validate(
        List<ValidationInput> inputs
    ) {
        List<ValidationResult> results =
            new List<ValidationResult>();

        for (ValidationInput input : inputs) {
            ValidationResult result = new ValidationResult();
            try {
                result = runValidation(input);
                result.success = true;
            } catch (Exception e) {
                result.success           = false;
                result.isValid           = false;
                result.validationStatus  = 'Invalid';
                result.validationReason  = e.getMessage();
                result.message           =
                    'Validation error: ' + e.getMessage();
            }
            results.add(result);
        }
        return results;
    }

    private static ValidationResult runValidation(
        ValidationInput input
    ) {
        ValidationResult result = new ValidationResult();

        // Rule 1: Valid claim type
        if (!VALID_CLAIM_TYPES.contains(input.claimType)) {
            result.isValid          = false;
            result.validationStatus = 'Invalid';
            result.validationReason =
                'Invalid claim type: ' + input.claimType;
            result.message =
                'Sorry, we do not support the claim type ' +
                input.claimType + '. Supported types are: ' +
                'Accident, Theft, Windscreen, Natural Disaster.';
            return result;
        }

        // Rule 2: Valid vehicle type
        if (!VALID_VEHICLE_TYPES.contains(input.vehicleType)) {
            result.isValid          = false;
            result.validationStatus = 'Invalid';
            result.validationReason =
                'Invalid vehicle type: ' + input.vehicleType;
            result.message =
                'Sorry, we do not support vehicle type ' +
                input.vehicleType + '. Supported types are: ' +
                'Sedan, SUV, Truck, Hatchback, Motorcycle, Van.';
            return result;
        }

        // Rule 3: Valid damage level for claim type
        Set<String> validLevels =
            VALID_DAMAGE_LEVELS.get(input.claimType);
        if (validLevels != null &&
            !validLevels.contains(input.damageLevel)) {
            result.isValid          = false;
            result.validationStatus = 'Invalid';
            result.validationReason =
                'Invalid damage level ' + input.damageLevel +
                ' for claim type ' + input.claimType;
            result.message =
                'For a ' + input.claimType + ' claim, ' +
                'valid damage levels are: ' +
                String.join(new List<String>(validLevels), ', ') +
                '.';
            return result;
        }

        // Rule 4: Incident date not in future
        if (!String.isBlank(input.incidentDate)) {
            try {
                Date incDate = Date.valueOf(input.incidentDate);
                if (incDate > Date.today()) {
                    result.isValid          = false;
                    result.validationStatus = 'Invalid';
                    result.validationReason =
                        'Incident date cannot be in the future';
                    result.message =
                        'The incident date cannot be in the ' +
                        'future. Please provide the correct date.';
                    return result;
                }

                // Rule 5: Incident date within last 12 months
                Date cutoff = Date.today().addMonths(-12);
                if (incDate < cutoff) {
                    result.isValid          = false;
                    result.validationStatus = 'Invalid';
                    result.validationReason =
                        'Incident date older than 12 months';
                    result.message =
                        'We can only process claims for incidents ' +
                        'within the last 12 months. Please contact ' +
                        'us directly for older claims.';
                    return result;
                }
            } catch (Exception e) {
                result.isValid          = false;
                result.validationStatus = 'Invalid';
                result.validationReason =
                    'Invalid date format: ' + input.incidentDate;
                result.message =
                    'Please provide the incident date in ' +
                    'YYYY-MM-DD format.';
                return result;
            }
        }

        // Rule 6: Duplicate claim check
        if (!String.isBlank(input.vehicleRegistration)) {
            Date cutoff = Date.today().addDays(-30);
            List<Claim__c> duplicates = [
                SELECT Id, Name
                FROM   Claim__c
                WHERE  Vehicle_Registration__c =
                       :input.vehicleRegistration
                AND    Claim_Status__c NOT IN (
                       'Closed', 'Rejected'
                )
                AND    CreatedDate >= :cutoff
                LIMIT  1
            ];

            if (!duplicates.isEmpty()) {
                result.isValid          = false;
                result.validationStatus = 'Invalid';
                result.validationReason =
                    'Duplicate claim: ' + duplicates[0].Name;
                result.message =
                    'We found an existing open claim ' +
                    duplicates[0].Name + ' for vehicle ' +
                    input.vehicleRegistration +
                    ' within the last 30 days. ' +
                    'Please contact us if you need assistance.';
                return result;
            }
        }

        // All rules passed
        result.isValid          = true;
        result.validationStatus = 'Valid';
        result.validationReason = 'All validation rules passed';
        result.message =
            'Claim details validated successfully.';

        System.debug('Claim validation passed');
        return result;
    }
}
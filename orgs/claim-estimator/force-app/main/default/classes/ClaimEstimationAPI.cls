@RestResource(urlMapping='/claim-estimation/v1/*')
global with sharing class ClaimEstimationAPI {

    @HttpPost
    global static ClaimEstimationResponse estimateClaim() {
        ClaimEstimationResponse response = new ClaimEstimationResponse();
        try {
            RestRequest req = RestContext.request;
            String body = req.requestBody.toString();
            ClaimEstimationRequest request = (ClaimEstimationRequest) JSON.deserialize(
                body, ClaimEstimationRequest.class
            );

            if (request == null || request.claimType == null) {
                response.success = false;
                response.errorMessage = 'Invalid request — claimType is required';
                return response;
            }

            response.estimatedAmount     = calculateEstimate(request);
            response.claimType           = request.claimType;
            response.confidenceScore     = 85.0;
            response.exchangeRate        = 1.0;
            response.estimatedAmountUSD  = response.estimatedAmount * response.exchangeRate;
            response.success             = true;
            response.message             = 'Estimation completed successfully';

        } catch (Exception e) {
            response.success      = false;
            response.errorMessage = e.getMessage();
        }
        return response;
    }

    private static Decimal calculateEstimate(ClaimEstimationRequest request) {
        Decimal baseEstimate = 0;
        switch on request.claimType {
            when 'Accident' {
                baseEstimate = 5000.00;
                if (request.damageLevel == 'Minor')      baseEstimate = 2000.00;
                if (request.damageLevel == 'Major')      baseEstimate = 15000.00;
                if (request.damageLevel == 'Total Loss') baseEstimate = 35000.00;
            }
            when 'Windscreen' {
                baseEstimate = 500.00;
                if (request.damageLevel == 'Replace')    baseEstimate = 1200.00;
            }
            when 'Theft' {
                baseEstimate = 20000.00;
            }
            when 'Natural_Disaster' {
                baseEstimate = 8000.00;
                if (request.damageLevel == 'Major')      baseEstimate = 25000.00;
            }
            when else {
                baseEstimate = 3000.00;
            }
        }
        return baseEstimate;
    }

    global class ClaimEstimationRequest {
        global String claimType           { get; set; }
        global String damageLevel         { get; set; }
        global String vehicleType         { get; set; }
        global String incidentDescription { get; set; }
        global String claimId             { get; set; }
    }

    global class ClaimEstimationResponse {
        global Boolean success            { get; set; }
        global Decimal estimatedAmount    { get; set; }
        global Decimal estimatedAmountUSD { get; set; }
        global Decimal exchangeRate       { get; set; }
        global Decimal confidenceScore    { get; set; }
        global String  claimType         { get; set; }
        global String  message           { get; set; }
        global String  errorMessage      { get; set; }
    }
}
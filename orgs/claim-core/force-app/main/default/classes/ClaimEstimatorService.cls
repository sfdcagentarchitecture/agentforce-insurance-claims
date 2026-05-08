public with sharing class ClaimEstimatorService {

    private static final String NAMED_CREDENTIAL = 'callout:Claim_Estimator_API';
    private static final String ENDPOINT = '/services/apexrest/claim-estimation/v1/';

    public static ClaimEstimationResponse estimateClaim(ClaimEstimationRequest request) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(NAMED_CREDENTIAL + ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(request));
            req.setTimeout(120000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                return (ClaimEstimationResponse) JSON.deserialize(
                    res.getBody(),
                    ClaimEstimationResponse.class
                );
            } else {
                ClaimEstimationResponse errorResponse = new ClaimEstimationResponse();
                errorResponse.success = false;
                errorResponse.errorMessage = 'HTTP ' + res.getStatusCode() + ': ' + res.getBody();
                return errorResponse;
            }
        } catch (Exception e) {
            ClaimEstimationResponse errorResponse = new ClaimEstimationResponse();
            errorResponse.success = false;
            errorResponse.errorMessage = e.getMessage();
            return errorResponse;
        }
    }

    public class ClaimEstimationRequest {
        public String claimType            { get; set; }
        public String damageLevel          { get; set; }
        public String vehicleType          { get; set; }
        public String incidentDescription  { get; set; }
        public String claimId              { get; set; }
    }

    public class ClaimEstimationResponse {
        public Boolean success             { get; set; }
        public Decimal estimatedAmount     { get; set; }
        public Decimal estimatedAmountUSD  { get; set; }
        public Decimal exchangeRate        { get; set; }
        public Decimal confidenceScore     { get; set; }
        public String  claimType          { get; set; }
        public String  message            { get; set; }
        public String  errorMessage       { get; set; }
    }
}
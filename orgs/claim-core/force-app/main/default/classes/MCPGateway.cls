public with sharing class MCPGateway {

    @InvocableMethod(
        label='MCP Gateway'
        description='Generic gateway to route requests to any MCP agent org based on tool name'
    )
    public static List<MCPResponse> execute(List<MCPRequest> requests) {
        List<MCPResponse> responses = new List<MCPResponse>();
        for (MCPRequest request : requests) {
            responses.add(routeRequest(request));
        }
        return responses;
    }

    public static MCPResponse routeRequest(MCPRequest request) {
        MCPResponse response = new MCPResponse();
        Long startTime = System.currentTimeMillis();

        try {
            // Step 1: Look up tool in registry
            List<MCP_Tool_Registry__mdt> tools = [
                SELECT  Agent_Registry__c,
                        Agent_Registry__r.Named_Credential__c,
                        Agent_Registry__r.Endpoint_URL__c,
                        Agent_Registry__r.Timeout_MS__c,
                        Agent_Registry__r.Active__c,
                        Endpoint_Path__c,
                        HTTP_Method__c,
                        Active__c,
                        Description__c
                FROM    MCP_Tool_Registry__mdt
                WHERE   DeveloperName = :request.toolName
                AND     Active__c = true
                LIMIT 1
            ];

            if (tools.isEmpty()) {
                response.success    = false;
                response.error      = 'Tool not found in registry: ' + request.toolName;
                response.toolName   = request.toolName;
                response.durationMS = System.currentTimeMillis() - startTime;
                return response;
            }

            MCP_Tool_Registry__mdt tool = tools[0];

            // Step 2: Validate server is active
            if (!tool.Agent_Registry__r.Active__c) {
                response.success    = false;
                response.error      = 'Agent server is inactive: ' + tool.Agent_Registry__c;
                response.toolName   = request.toolName;
                response.serverName = tool.Agent_Registry__c;
                response.durationMS = System.currentTimeMillis() - startTime;
                return response;
            }

            // Step 3: Build endpoint
            String namedCredential = tool.Agent_Registry__r.Named_Credential__c;
            String endpointPath    = tool.Endpoint_Path__c;
            String fullEndpoint    = 'callout:' + namedCredential + endpointPath;
            Integer timeout        = tool.Agent_Registry__r.Timeout_MS__c != null
                                     ? Integer.valueOf(tool.Agent_Registry__r.Timeout_MS__c)
                                     : 120000;

            // Step 4: Make callout
            HttpRequest req = new HttpRequest();
            req.setEndpoint(fullEndpoint);
            req.setMethod(tool.HTTP_Method__c);
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            req.setBody(request.inputPayload);
            req.setTimeout(timeout);

            Http http       = new Http();
            HttpResponse res = http.send(req);

            // Step 5: Build response
            response.statusCode = res.getStatusCode();
            response.payload    = res.getBody();
            response.toolName   = request.toolName;
            response.serverName = tool.Agent_Registry__c;
            response.durationMS = System.currentTimeMillis() - startTime;
            response.success    = res.getStatusCode() == 200;

            if (!response.success) {
                response.error = 'HTTP ' + res.getStatusCode() +
                                 ': ' + res.getBody();
            }

        } catch (Exception e) {
            response.success    = false;
            response.error      = e.getMessage();
            response.toolName   = request.toolName;
            response.durationMS = System.currentTimeMillis() - startTime;
        }

        return response;
    }

    public class MCPRequest {
        @InvocableVariable(label='Tool Name' required=true)
        public String toolName;

        @InvocableVariable(label='Input Payload' required=true)
        public String inputPayload;

        @InvocableVariable(label='Claim Id' required=false)
        public String claimId;

        @InvocableVariable(label='Agent Name' required=false)
        public String agentName;
    }

    public class MCPResponse {
        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Payload')
        public String payload;

        @InvocableVariable(label='Status Code')
        public Integer statusCode;

        @InvocableVariable(label='Tool Name')
        public String toolName;

        @InvocableVariable(label='Server Name')
        public String serverName;

        @InvocableVariable(label='Error')
        public String error;

        @InvocableVariable(label='Duration MS')
        public Long durationMS;
    }
}
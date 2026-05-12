/**
 * HeadlessAgentAPI
 * Generic reusable A2A Headless Agent API client.
 * Supports any agent-to-agent communication via
 * Salesforce Headless Agent API.
 * Config driven via Agent_API_Config__mdt.
 *
 * Usage:
 * String token = HeadlessAgentAPI.getAccessToken('Config_Name');
 * String sid   = HeadlessAgentAPI.createSession('Config_Name', token);
 * String resp  = HeadlessAgentAPI.sendMessage(token, sid, 'message', 1);
 * String text  = HeadlessAgentAPI.parseResponse(resp);
 * HeadlessAgentAPI.endSession(token, sid);
 *
 * Or use convenience method:
 * String response = HeadlessAgentAPI.invoke('Config_Name', 'message');
 */
public with sharing class HeadlessAgentAPI {

    // ─────────────────────────────────────────
    // Custom Exception
    // ─────────────────────────────────────────
    public class AgentAPIException extends Exception {}

    // ─────────────────────────────────────────
    // Constants
    // ─────────────────────────────────────────
    private static final String AGENT_API_BASE =
        'https://api.salesforce.com/einstein/ai-agent/v1';

    // ─────────────────────────────────────────
    // Config Loader
    // ─────────────────────────────────────────
    private static Agent_API_Config__mdt getConfig(
        String configName
    ) {
        Agent_API_Config__mdt config =
            Agent_API_Config__mdt.getInstance(configName);

        if (config == null || !config.Is_Active__c) {
            throw new AgentAPIException(
                'Agent API Config not found or inactive: ' +
                configName
            );
        }
        return config;
    }

    // ─────────────────────────────────────────
    // STEP 1: Get OAuth Token
    // ─────────────────────────────────────────
    public static String getAccessToken(String configName) {
        Agent_API_Config__mdt config = getConfig(configName);
        System.debug('>>> GET TOKEN: ' + configName);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            config.Org_URL__c + '/services/oauth2/token'
        );
        req.setMethod('POST');
        req.setHeader(
            'Content-Type',
            'application/x-www-form-urlencoded'
        );
        req.setBody(
            'grant_type=client_credentials' +
            '&client_id='     + config.Client_ID__c +
            '&client_secret=' + config.Client_Secret__c
        );
        req.setTimeout(
            config.Timeout_MS__c != null ?
            Integer.valueOf(config.Timeout_MS__c) : 30000
        );

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            throw new AgentAPIException(
                'Token error [' + res.getStatusCode() +
                ']: ' + res.getBody()
            );
        }

        Map<String, Object> data =
            (Map<String, Object>) JSON.deserializeUntyped(
                res.getBody()
            );
        String token = (String) data.get('access_token');
        System.debug('>>> TOKEN obtained ✅ (length: ' +
            token.length() + ')');
        return token;
    }

    // ─────────────────────────────────────────
    // STEP 2: Create Agent Session
    // ─────────────────────────────────────────
    public static String createSession(
        String configName,
        String accessToken
    ) {
        Agent_API_Config__mdt config = getConfig(configName);
        System.debug('>>> CREATE SESSION: ' + configName);

        String sessionKey = 'a2a-' +
            String.valueOf(System.currentTimeMillis());

        Map<String, Object> body = new Map<String, Object>{
            'externalSessionKey'    => sessionKey,
            'instanceConfig'        => new Map<String, Object>{
                'endpoint' => config.Org_URL__c
            },
            'streamingCapabilities' => new Map<String, Object>{
                'chunkTypes' => new List<String>{ 'Text' }
            },
            'bypassUser'            => true
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            AGENT_API_BASE + '/agents/' +
            config.Agent_ID__c + '/sessions'
        );
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setBody(JSON.serialize(body));
        req.setTimeout(
            config.Timeout_MS__c != null ?
            Integer.valueOf(config.Timeout_MS__c) : 30000
        );

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200 &&
            res.getStatusCode() != 201) {
            throw new AgentAPIException(
                'Session error [' + res.getStatusCode() +
                ']: ' + res.getBody()
            );
        }

        Map<String, Object> data =
            (Map<String, Object>) JSON.deserializeUntyped(
                res.getBody()
            );
        String sessionId = (String) data.get('sessionId');
        System.debug('>>> SESSION created ✅ ' + sessionId);
        return sessionId;
    }

    // ─────────────────────────────────────────
    // STEP 3: Send Message
    // ─────────────────────────────────────────
    public static String sendMessage(
        String accessToken,
        String sessionId,
        String message,
        Integer sequenceId
    ) {
        System.debug('>>> SEND MESSAGE Turn ' +
            sequenceId + ': ' + message);

        Map<String, Object> body = new Map<String, Object>{
            'message'   => new Map<String, Object>{
                'sequenceId' => sequenceId,
                'type'       => 'Text',
                'text'       => message
            },
            'variables' => new List<Object>()
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            AGENT_API_BASE +
            '/sessions/' + sessionId + '/messages'
        );
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setBody(JSON.serialize(body));
        req.setTimeout(60000);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200 &&
            res.getStatusCode() != 201) {
            throw new AgentAPIException(
                'Message error [' + res.getStatusCode() +
                ']: ' + res.getBody()
            );
        }

        System.debug('>>> MESSAGE sent ✅');
        return res.getBody();
    }

    // ─────────────────────────────────────────
    // STEP 4: End Session
    // ─────────────────────────────────────────
    public static void endSession(
        String accessToken,
        String sessionId
    ) {
        System.debug('>>> END SESSION: ' + sessionId);
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(
                AGENT_API_BASE + '/sessions/' +
                sessionId + '?reason=UserRequest'
            );
            req.setMethod('DELETE');
            req.setHeader(
                'Authorization', 'Bearer ' + accessToken
            );
            req.setTimeout(30000);

            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() == 200 ||
                res.getStatusCode() == 204) {
                System.debug('>>> SESSION ended ✅');
            } else {
                System.debug(
                    '>>> SESSION end warning [' +
                    res.getStatusCode() + ']: ' +
                    res.getBody()
                );
            }
        } catch (Exception e) {
            System.debug('>>> SESSION end failed: ' +
                e.getMessage());
        }
    }

    // ─────────────────────────────────────────
    // Parse Agent Response
    // ─────────────────────────────────────────
    public static String parseResponse(String responseBody) {
        try {
            Map<String, Object> data =
                (Map<String, Object>) JSON.deserializeUntyped(
                    responseBody
                );
            List<Object> messages =
                (List<Object>) data.get('messages');
            if (messages != null && !messages.isEmpty()) {
                for (Object msg : messages) {
                    Map<String, Object> msgMap =
                        (Map<String, Object>) msg;
                    String type =
                        (String) msgMap.get('type');
                    if (type == 'Inform' || type == 'Text') {
                        return (String) msgMap.get('message');
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Parse error: ' + e.getMessage());
        }
        return 'No response parsed';
    }

    // ─────────────────────────────────────────
    // CONVENIENCE METHOD — Single turn invoke
    // Full lifecycle: token → session → message → end
    // ─────────────────────────────────────────
    public static String invoke(
        String configName,
        String message
    ) {
        String accessToken = null;
        String sessionId   = null;
        try {
            accessToken = getAccessToken(configName);
            sessionId   = createSession(configName, accessToken);
            String response = sendMessage(
                accessToken, sessionId, message, 1
            );
            String parsed = parseResponse(response);
            endSession(accessToken, sessionId);
            return parsed;
        } catch (Exception e) {
            if (accessToken != null && sessionId != null) {
                endSession(accessToken, sessionId);
            }
            throw new AgentAPIException(
                'A2A invoke failed: ' + e.getMessage()
            );
        }
    }

    // ─────────────────────────────────────────
    // CONVENIENCE METHOD — Multi turn invoke
    // Caller manages session lifecycle
    // ─────────────────────────────────────────
    public static A2ASession startSession(String configName) {
        String accessToken = getAccessToken(configName);
        String sessionId   = createSession(
            configName, accessToken
        );
        return new A2ASession(
            configName, accessToken, sessionId
        );
    }

    // ─────────────────────────────────────────
    // A2ASession — wrapper for multi-turn
    // ─────────────────────────────────────────
    public class A2ASession {
        public String configName   { get; private set; }
        public String accessToken  { get; private set; }
        public String sessionId    { get; private set; }
        public Integer sequenceId  { get; private set; }

        public A2ASession(
            String configName,
            String accessToken,
            String sessionId
        ) {
            this.configName  = configName;
            this.accessToken = accessToken;
            this.sessionId   = sessionId;
            this.sequenceId  = 1;
        }

        public String send(String message) {
            String response = sendMessage(
                this.accessToken,
                this.sessionId,
                message,
                this.sequenceId
            );
            this.sequenceId++;
            return parseResponse(response);
        }

        public void end() {
            endSession(this.accessToken, this.sessionId);
        }
    }
}
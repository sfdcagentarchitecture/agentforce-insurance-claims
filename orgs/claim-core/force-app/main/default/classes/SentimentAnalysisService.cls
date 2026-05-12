public with sharing class SentimentAnalysisService {

    // ─────────────────────────────────────────
    // Sentiment Keywords
    // ─────────────────────────────────────────
    private static final Set<String> FRUSTRATED_KEYWORDS =
        new Set<String>{
            'furious', 'outraged', 'livid', 'fuming',
            'disgusted', 'unacceptable', 'ridiculous',
            'appalling', 'pathetic', 'useless', 'incompetent',
            'disaster', 'nightmare', 'catastrophic'
        };

    private static final Set<String> NEGATIVE_KEYWORDS =
        new Set<String>{
            'angry', 'frustrated', 'terrible', 'awful',
            'horrible', 'worst', 'bad', 'upset', 'unhappy',
            'disappointed', 'annoyed', 'hate', 'terrible',
            'stressed', 'worried', 'scared', 'shocked',
            'devastated', 'ruined', 'damaged', 'stolen',
            'broken', 'crashed', 'accident', 'hurt'
        };

    private static final Set<String> POSITIVE_KEYWORDS =
        new Set<String>{
            'happy', 'great', 'excellent', 'wonderful',
            'fantastic', 'pleased', 'satisfied', 'good',
            'thank', 'appreciate', 'helpful', 'amazing',
            'perfect', 'brilliant', 'love', 'glad',
            'fortunate', 'lucky', 'relief', 'relieved'
        };

    // ─────────────────────────────────────────
    // Input / Output
    // ─────────────────────────────────────────
    public class SentimentInput {
        @InvocableVariable(label='Customer Message'
                           required=true)
        public String customerMessage;

        @InvocableVariable(label='Case Id' required=false)
        public String caseId;
    }

    public class SentimentResult {
        @InvocableVariable(label='Sentiment Label')
        public String sentimentLabel;

        @InvocableVariable(label='Sentiment Score')
        public Decimal sentimentScore;

        @InvocableVariable(label='Is Priority')
        public Boolean isPriority;

        @InvocableVariable(label='Recommended Tone')
        public String recommendedTone;

        @InvocableVariable(label='Message')
        public String message;

        @InvocableVariable(label='Success')
        public Boolean success;
    }

    // ─────────────────────────────────────────
    // Main InvocableMethod
    // ─────────────────────────────────────────
    @InvocableMethod(
        label='Analyse Customer Sentiment'
        description='Analyses customer message and classifies sentiment. Updates Case if Case Id provided. Returns label, score and recommended tone.'
    )
    public static List<SentimentResult> analyse(
        List<SentimentInput> inputs
    ) {
        List<SentimentResult> results =
            new List<SentimentResult>();

        for (SentimentInput input : inputs) {
            SentimentResult result = new SentimentResult();
            try {
                // Analyse sentiment
                result = classifySentiment(
                    input.customerMessage
                );
                result.success = true;

                // Update Case if provided
                if (!String.isBlank(input.caseId)) {
                    updateCase(
                        input.caseId,
                        result.sentimentLabel,
                        result.sentimentScore,
                        result.isPriority
                    );
                }

            } catch (Exception e) {
                result.success        = false;
                result.sentimentLabel = 'Neutral';
                result.sentimentScore = 0.5;
                result.isPriority     = false;
                result.recommendedTone = 'Standard';
                result.message        = e.getMessage();
            }
            results.add(result);
        }
        return results;
    }

    // ─────────────────────────────────────────
    // Classify Sentiment
    // ─────────────────────────────────────────
    private static SentimentResult classifySentiment(
        String message
    ) {
        SentimentResult result = new SentimentResult();

        if (String.isBlank(message)) {
            result.sentimentLabel  = 'Neutral';
            result.sentimentScore  = 0.5;
            result.isPriority      = false;
            result.recommendedTone = 'Standard';
            result.message         = 'No message to analyse';
            return result;
        }

        // Tokenise message
        String lower = message.toLowerCase();
        List<String> words = lower.split('\\s+');
        Set<String> wordSet = new Set<String>(words);

        // Count keyword matches
        Integer frustratedCount = 0;
        Integer negativeCount   = 0;
        Integer positiveCount   = 0;

        for (String word : wordSet) {
            // Remove punctuation
            String clean = word.replaceAll(
                '[^a-zA-Z]', ''
            );
            if (FRUSTRATED_KEYWORDS.contains(clean)) {
                frustratedCount++;
            } else if (NEGATIVE_KEYWORDS.contains(clean)) {
                negativeCount++;
            } else if (POSITIVE_KEYWORDS.contains(clean)) {
                positiveCount++;
            }
        }

        // Classify
        if (frustratedCount > 0) {
            result.sentimentLabel  = 'Frustrated';
            result.sentimentScore  = 0.1;
            result.isPriority      = true;
            result.recommendedTone = 'Very Empathetic';
            result.message         =
                'Customer appears highly frustrated. ' +
                'Priority handling recommended.';

        } else if (negativeCount > positiveCount) {
            result.sentimentLabel  = 'Negative';
            result.sentimentScore  = 0.3;
            result.isPriority      = true;
            result.recommendedTone = 'Empathetic';
            result.message         =
                'Customer appears distressed. ' +
                'Handle with extra care.';

        } else if (positiveCount > negativeCount) {
            result.sentimentLabel  = 'Positive';
            result.sentimentScore  = 0.9;
            result.isPriority      = false;
            result.recommendedTone = 'Friendly';
            result.message         =
                'Customer appears positive.';

        } else {
            result.sentimentLabel  = 'Neutral';
            result.sentimentScore  = 0.5;
            result.isPriority      = false;
            result.recommendedTone = 'Standard';
            result.message         =
                'Customer sentiment is neutral.';
        }

        System.debug('Sentiment: ' + result.sentimentLabel +
            ' | Score: ' + result.sentimentScore +
            ' | Priority: ' + result.isPriority);

        return result;
    }

    // ─────────────────────────────────────────
    // Update Case with Sentiment
    // ─────────────────────────────────────────
    private static void updateCase(
        String caseId,
        String label,
        Decimal score,
        Boolean isPriority
    ) {
        try {
            update new Case(
                Id                  = caseId,
                Sentiment_Label__c  = label,
                Sentiment_Score__c  = score,
                Priority            = isPriority ?
                    'High' : 'Medium'
            );
            System.debug('Case updated with sentiment: ' +
                label);
        } catch (Exception e) {
            System.debug('Case sentiment update failed: ' +
                e.getMessage());
        }
    }
}
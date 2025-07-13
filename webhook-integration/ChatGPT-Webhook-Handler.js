// =============================================================================
// SentinelLog ChatGPT Webhook Handler
// =============================================================================
// This Azure Function receives ChatGPT conversations via webhook and 
// processes them through the SentinelLog Power Automate flow
// =============================================================================

const { app } = require('@azure/functions');

// =============================================================================
// CONFIGURATION
// =============================================================================

const config = {
    powerAutomateFlowUrl: process.env.POWER_AUTOMATE_FLOW_URL,
    sharePointSiteUrl: process.env.SHAREPOINT_SITE_URL,
    organizationName: process.env.ORGANIZATION_NAME,
    apiKey: process.env.SENTINELLOG_API_KEY,
    allowedOrigins: [
        'https://chat.openai.com',
        'https://chatgpt.com',
        'https://openai.com'
    ]
};

// =============================================================================
// WEBHOOK HANDLER
// =============================================================================

app.http('chatgpt-webhook', {
    methods: ['POST', 'OPTIONS'],
    authLevel: 'function',
    handler: async (request, context) => {
        
        // Handle CORS preflight
        if (request.method === 'OPTIONS') {
            return {
                status: 200,
                headers: {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-API-Key',
                    'Access-Control-Max-Age': '86400'
                }
            };
        }

        context.log('🛡️ SentinelLog Webhook: Received ChatGPT conversation');

        try {
            // =============================================================================
            // AUTHENTICATION & VALIDATION
            // =============================================================================

            // Validate API key
            const apiKey = request.headers.get('x-api-key') || request.headers.get('authorization')?.replace('Bearer ', '');
            if (!apiKey || apiKey !== config.apiKey) {
                context.log('❌ Unauthorized webhook request');
                return {
                    status: 401,
                    jsonBody: { error: 'Unauthorized' }
                };
            }

            // Parse request body
            const webhookData = await request.json();
            context.log('📦 Webhook data received:', {
                conversationId: webhookData.conversationId,
                messageCount: webhookData.messages?.length || 0,
                timestamp: webhookData.timestamp
            });

            // =============================================================================
            // DATA PROCESSING
            // =============================================================================

            // Extract conversation data
            const conversationData = await processConversationData(webhookData, context);
            
            // Generate compliant filename
            const filename = generateCompliantFilename(conversationData);
            
            // Format transcript for storage
            const formattedTranscript = formatTranscriptForStorage(conversationData);

            // =============================================================================
            // POWER AUTOMATE INTEGRATION
            // =============================================================================

            // Prepare data for Power Automate flow
            const powerAutomatePayload = {
                chatTranscript: formattedTranscript,
                fileName: filename,
                sharePointPath: conversationData.sharePointPath,
                contextCode: conversationData.contextCode,
                functionCode: conversationData.functionCode,
                dependencyCode: conversationData.dependencyCode,
                iterationCode: conversationData.iterationCode,
                flagCode: conversationData.flagCode,
                fileExtension: 'txt',
                description: conversationData.description,
                userEmail: conversationData.userEmail,
                userFullName: conversationData.userFullName,
                timestamp: new Date().toISOString(),
                contextName: conversationData.contextName,
                functionName: conversationData.functionName,
                dependencyName: conversationData.dependencyName,
                iterationName: conversationData.iterationName,
                flagName: conversationData.flagName,
                source: 'ChatGPT-Webhook',
                automated: true
            };

            // Call Power Automate flow
            const flowResponse = await callPowerAutomateFlow(powerAutomatePayload, context);

            // =============================================================================
            // RESPONSE
            // =============================================================================

            if (flowResponse.success) {
                context.log('✅ Successfully processed ChatGPT conversation');
                return {
                    status: 200,
                    headers: {
                        'Access-Control-Allow-Origin': '*',
                        'Content-Type': 'application/json'
                    },
                    jsonBody: {
                        success: true,
                        message: 'Conversation logged successfully',
                        filename: filename,
                        conversationId: webhookData.conversationId,
                        sharePointUrl: flowResponse.fileUrl,
                        timestamp: new Date().toISOString()
                    }
                };
            } else {
                context.log('❌ Failed to process conversation:', flowResponse.error);
                return {
                    status: 500,
                    headers: {
                        'Access-Control-Allow-Origin': '*',
                        'Content-Type': 'application/json'
                    },
                    jsonBody: {
                        success: false,
                        error: 'Failed to process conversation',
                        details: flowResponse.error
                    }
                };
            }

        } catch (error) {
            context.log('❌ Webhook processing error:', error);
            return {
                status: 500,
                headers: {
                    'Access-Control-Allow-Origin': '*',
                    'Content-Type': 'application/json'
                },
                jsonBody: {
                    success: false,
                    error: 'Internal server error',
                    details: error.message
                }
            };
        }
    }
});

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

async function processConversationData(webhookData, context) {
    context.log('🔄 Processing conversation data...');

    // Extract user information (from headers or webhook data)
    const userEmail = webhookData.user?.email || 'unknown@company.com';
    const userFullName = webhookData.user?.name || 'Unknown User';

    // Analyze conversation content for auto-classification
    const classification = await analyzeConversationContent(webhookData.messages, context);

    return {
        conversationId: webhookData.conversationId,
        messages: webhookData.messages,
        timestamp: webhookData.timestamp || new Date().toISOString(),
        userEmail: userEmail,
        userFullName: userFullName,
        
        // Auto-detected or default classification
        contextCode: classification.contextCode || '300', // Default: Production
        contextName: classification.contextName || 'Production',
        functionCode: classification.functionCode || '001', // Default: Analysis
        functionName: classification.functionName || 'Analysis',
        dependencyCode: classification.dependencyCode || '002', // Default: Backend
        dependencyName: classification.dependencyName || 'Backend',
        iterationCode: '001', // Auto-increment could be implemented
        iterationName: 'Initial',
        flagCode: classification.flagCode || '', // Optional
        flagName: classification.flagName || '',
        
        description: classification.description || `Auto-captured ChatGPT conversation`,
        sharePointPath: `/Shared Documents/ChatGPT-Logs/${classification.contextName || 'Production'}/${classification.functionName || 'Analysis'}/${classification.dependencyName || 'Backend'}/`
    };
}

async function analyzeConversationContent(messages, context) {
    context.log('🧠 Analyzing conversation content for classification...');

    // Simple keyword-based classification (could be enhanced with AI)
    const conversationText = messages.map(m => m.content).join(' ').toLowerCase();

    const classification = {
        contextCode: '300',
        contextName: 'Production',
        functionCode: '001',
        functionName: 'Analysis',
        dependencyCode: '002',
        dependencyName: 'Backend',
        description: 'Auto-captured ChatGPT conversation'
    };

    // Analyze keywords for better classification
    if (conversationText.includes('test') || conversationText.includes('testing')) {
        classification.contextCode = '200';
        classification.contextName = 'Testing';
        classification.functionCode = '004';
        classification.functionName = 'Testing';
    }

    if (conversationText.includes('develop') || conversationText.includes('code')) {
        classification.contextCode = '100';
        classification.contextName = 'Development';
        classification.functionCode = '003';
        classification.functionName = 'Implementation';
    }

    if (conversationText.includes('frontend') || conversationText.includes('ui') || conversationText.includes('react')) {
        classification.dependencyCode = '001';
        classification.dependencyName = 'Frontend';
    }

    if (conversationText.includes('database') || conversationText.includes('sql')) {
        classification.dependencyCode = '003';
        classification.dependencyName = 'Database';
    }

    if (conversationText.includes('api') || conversationText.includes('endpoint')) {
        classification.dependencyCode = '004';
        classification.dependencyName = 'API';
    }

    // Priority flag detection
    if (conversationText.includes('urgent') || conversationText.includes('priority')) {
        classification.flagCode = 'P';
        classification.flagName = 'Priority';
    }

    return classification;
}

function generateCompliantFilename(conversationData) {
    const timestamp = new Date().toISOString().replace(/[:\-]/g, '').slice(0, 15);
    
    return `${conversationData.contextCode}${conversationData.functionCode}${conversationData.dependencyCode}${conversationData.iterationCode}${conversationData.flagCode || ''}${timestamp.slice(-3)}.txt`;
}

function formatTranscriptForStorage(conversationData) {
    const header = `=== SENTINELLOG CHAT TRANSCRIPT ===
Generated: ${new Date().toISOString()}
Source: ChatGPT Webhook Integration
User: ${conversationData.userFullName}
Email: ${conversationData.userEmail}
Conversation ID: ${conversationData.conversationId}
Context: ${conversationData.contextName} (${conversationData.contextCode})
Function: ${conversationData.functionName} (${conversationData.functionCode})
Dependency: ${conversationData.dependencyName} (${conversationData.dependencyCode})
Iteration: ${conversationData.iterationName} (${conversationData.iterationCode})
${conversationData.flagName ? `Flag: ${conversationData.flagName} (${conversationData.flagCode})` : ''}
Description: ${conversationData.description}
========================================

CONVERSATION START

`;

    const conversationContent = conversationData.messages.map(message => {
        const timestamp = new Date(message.timestamp || Date.now()).toISOString();
        const role = message.role === 'assistant' ? 'ChatGPT' : 'User';
        return `[${timestamp}] ${role}: ${message.content}`;
    }).join('\n\n');

    const footer = `

CONVERSATION END

========================================
Archive Date: ${new Date().toISOString()}
Compliance: Document Control Standards Applied
Auto-Captured: Yes
Version: 1.0
System: SentinelLog Webhook Integration v1.0`;

    return header + conversationContent + footer;
}

async function callPowerAutomateFlow(payload, context) {
    context.log('🔗 Calling Power Automate flow...');

    try {
        const response = await fetch(config.powerAutomateFlowUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });

        if (response.ok) {
            const result = await response.json();
            context.log('✅ Power Automate flow completed successfully');
            return result;
        } else {
            const errorText = await response.text();
            context.log('❌ Power Automate flow failed:', response.status, errorText);
            return {
                success: false,
                error: `Power Automate flow failed: ${response.status} ${errorText}`
            };
        }
    } catch (error) {
        context.log('❌ Error calling Power Automate flow:', error);
        return {
            success: false,
            error: `Network error: ${error.message}`
        };
    }
}

// =============================================================================
// HEALTH CHECK ENDPOINT
// =============================================================================

app.http('webhook-health', {
    methods: ['GET'],
    authLevel: 'anonymous',
    handler: async (request, context) => {
        return {
            status: 200,
            jsonBody: {
                service: 'SentinelLog ChatGPT Webhook',
                status: 'healthy',
                timestamp: new Date().toISOString(),
                version: '1.0.0'
            }
        };
    }
});

module.exports = { app };
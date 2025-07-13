// =============================================================================
// SentinelLog ChatGPT Content Script
// =============================================================================
// This script monitors ChatGPT conversations and captures them for logging
// =============================================================================

class SentinelLogCapture {
    constructor() {
        this.conversationData = {
            conversationId: this.generateConversationId(),
            messages: [],
            startTime: new Date().toISOString(),
            lastActivity: new Date().toISOString()
        };
        
        this.isCapturing = false;
        this.webhookUrl = '';
        this.apiKey = '';
        this.userInfo = null;
        
        this.init();
    }

    async init() {
        console.log('🛡️ SentinelLog: Initializing conversation capture...');
        
        // Load configuration from storage
        await this.loadConfiguration();
        
        // Add SentinelLog indicator to the page
        this.addIndicator();
        
        // Start monitoring conversations
        this.startMonitoring();
        
        // Listen for messages from popup
        chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
            this.handleMessage(request, sender, sendResponse);
        });
    }

    async loadConfiguration() {
        try {
            const config = await chrome.storage.sync.get([
                'webhookUrl', 
                'apiKey', 
                'userEmail', 
                'userFullName',
                'autoCapture'
            ]);
            
            this.webhookUrl = config.webhookUrl || '';
            this.apiKey = config.apiKey || '';
            this.userInfo = {
                email: config.userEmail || '',
                name: config.userFullName || ''
            };
            this.isCapturing = config.autoCapture !== false; // Default to true
            
            console.log('🛡️ SentinelLog: Configuration loaded', {
                hasWebhook: !!this.webhookUrl,
                hasApiKey: !!this.apiKey,
                autoCapture: this.isCapturing
            });
        } catch (error) {
            console.error('❌ SentinelLog: Failed to load configuration:', error);
        }
    }

    addIndicator() {
        // Create a visual indicator that SentinelLog is active
        const indicator = document.createElement('div');
        indicator.id = 'sentinellog-indicator';
        indicator.innerHTML = `
            <div class="sentinellog-badge">
                🛡️ SentinelLog Active
                <span class="status ${this.isCapturing ? 'capturing' : 'paused'}">
                    ${this.isCapturing ? 'Capturing' : 'Paused'}
                </span>
            </div>
        `;
        document.body.appendChild(indicator);
    }

    updateIndicatorStatus(status) {
        const indicator = document.getElementById('sentinellog-indicator');
        if (indicator) {
            const statusElement = indicator.querySelector('.status');
            statusElement.textContent = status;
            statusElement.className = `status ${status.toLowerCase()}`;
        }
    }

    startMonitoring() {
        console.log('🔍 SentinelLog: Starting conversation monitoring...');
        
        // Monitor for new messages
        this.observeConversation();
        
        // Periodically check for conversation changes
        setInterval(() => {
            this.captureCurrentConversation();
        }, 5000); // Check every 5 seconds
        
        // Monitor for conversation end/navigation
        window.addEventListener('beforeunload', () => {
            this.finalizeConversation();
        });
    }

    observeConversation() {
        // Create a MutationObserver to watch for new messages
        const observer = new MutationObserver((mutations) => {
            mutations.forEach((mutation) => {
                if (mutation.type === 'childList') {
                    mutation.addedNodes.forEach((node) => {
                        if (node.nodeType === 1) { // Element node
                            // Check if this is a new message
                            if (this.isMessageElement(node)) {
                                this.processNewMessage(node);
                            }
                        }
                    });
                }
            });
        });

        // Start observing the conversation container
        const conversationContainer = this.findConversationContainer();
        if (conversationContainer) {
            observer.observe(conversationContainer, {
                childList: true,
                subtree: true
            });
            console.log('👀 SentinelLog: Conversation observer started');
        } else {
            console.warn('⚠️ SentinelLog: Could not find conversation container');
            // Retry after a delay
            setTimeout(() => this.observeConversation(), 2000);
        }
    }

    findConversationContainer() {
        // Try multiple selectors to find the conversation container
        const selectors = [
            '[role="main"]',
            '.conversation-turn',
            '#conversation',
            '.chat-conversation',
            '[data-testid="conversation"]'
        ];

        for (const selector of selectors) {
            const container = document.querySelector(selector);
            if (container) {
                return container;
            }
        }

        return null;
    }

    isMessageElement(element) {
        // Check if element contains a chat message
        const messageSelectors = [
            '.message',
            '[data-message-id]',
            '.conversation-turn',
            '[role="article"]'
        ];

        return messageSelectors.some(selector => 
            element.matches && element.matches(selector) ||
            element.querySelector && element.querySelector(selector)
        );
    }

    processNewMessage(messageElement) {
        if (!this.isCapturing) return;

        try {
            const messageData = this.extractMessageData(messageElement);
            if (messageData) {
                this.conversationData.messages.push(messageData);
                this.conversationData.lastActivity = new Date().toISOString();
                
                console.log('📝 SentinelLog: New message captured:', {
                    role: messageData.role,
                    length: messageData.content.length
                });

                // Update indicator
                this.updateIndicatorStatus(`Captured ${this.conversationData.messages.length} messages`);
            }
        } catch (error) {
            console.error('❌ SentinelLog: Error processing message:', error);
        }
    }

    extractMessageData(messageElement) {
        // Extract message content and metadata
        let role = 'user';
        let content = '';

        // Try to determine if this is a user or assistant message
        if (messageElement.classList.contains('assistant') || 
            messageElement.querySelector('[data-testid="bot-message"]') ||
            messageElement.querySelector('.markdown')) {
            role = 'assistant';
        }

        // Extract text content
        const contentElement = messageElement.querySelector('.markdown, .message-content, p') || messageElement;
        content = contentElement.textContent || contentElement.innerText || '';

        if (!content.trim()) {
            return null; // Skip empty messages
        }

        return {
            role: role,
            content: content.trim(),
            timestamp: new Date().toISOString()
        };
    }

    captureCurrentConversation() {
        if (!this.isCapturing) return;

        // Capture the entire current conversation
        const messages = this.extractAllMessages();
        
        if (messages.length > this.conversationData.messages.length) {
            // New messages detected
            this.conversationData.messages = messages;
            this.conversationData.lastActivity = new Date().toISOString();
            
            console.log(`📊 SentinelLog: Conversation updated - ${messages.length} messages`);
            this.updateIndicatorStatus(`Monitoring ${messages.length} messages`);
        }
    }

    extractAllMessages() {
        const messages = [];
        
        // Find all message elements in the conversation
        const messageElements = document.querySelectorAll(
            '.conversation-turn, [data-message-id], .message, [role="article"]'
        );

        messageElements.forEach((element, index) => {
            const messageData = this.extractMessageData(element);
            if (messageData) {
                messages.push(messageData);
            }
        });

        return messages;
    }

    async finalizeConversation() {
        if (!this.isCapturing || this.conversationData.messages.length === 0) {
            return;
        }

        console.log('🏁 SentinelLog: Finalizing conversation...');
        
        try {
            await this.sendToWebhook();
            console.log('✅ SentinelLog: Conversation logged successfully');
        } catch (error) {
            console.error('❌ SentinelLog: Failed to log conversation:', error);
            // Store locally for retry
            this.storeForRetry();
        }
    }

    async sendToWebhook() {
        if (!this.webhookUrl || !this.apiKey) {
            throw new Error('Webhook URL or API key not configured');
        }

        const payload = {
            conversationId: this.conversationData.conversationId,
            messages: this.conversationData.messages,
            timestamp: this.conversationData.lastActivity,
            user: this.userInfo,
            metadata: {
                url: window.location.href,
                userAgent: navigator.userAgent,
                captureMethod: 'browser-extension'
            }
        };

        const response = await fetch(this.webhookUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-API-Key': this.apiKey
            },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            throw new Error(`Webhook request failed: ${response.status} ${response.statusText}`);
        }

        const result = await response.json();
        return result;
    }

    storeForRetry() {
        // Store conversation data locally for later retry
        const retryData = {
            ...this.conversationData,
            retryCount: 0,
            storedAt: new Date().toISOString()
        };

        chrome.storage.local.set({
            [`retry_${this.conversationData.conversationId}`]: retryData
        });
    }

    generateConversationId() {
        return `chatgpt_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    }

    handleMessage(request, sender, sendResponse) {
        switch (request.action) {
            case 'getStatus':
                sendResponse({
                    isCapturing: this.isCapturing,
                    messageCount: this.conversationData.messages.length,
                    conversationId: this.conversationData.conversationId,
                    lastActivity: this.conversationData.lastActivity
                });
                break;
                
            case 'toggleCapture':
                this.isCapturing = !this.isCapturing;
                this.updateIndicatorStatus(this.isCapturing ? 'Capturing' : 'Paused');
                sendResponse({ isCapturing: this.isCapturing });
                break;
                
            case 'forceCapture':
                this.captureCurrentConversation();
                this.finalizeConversation();
                sendResponse({ success: true });
                break;
                
            case 'updateConfig':
                this.loadConfiguration();
                sendResponse({ success: true });
                break;
                
            default:
                sendResponse({ error: 'Unknown action' });
        }
    }
}

// Initialize SentinelLog capture when the page loads
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        new SentinelLogCapture();
    });
} else {
    new SentinelLogCapture();
}
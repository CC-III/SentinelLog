# SentinelLog Webhook Integration - Deployment Guide

## 🚀 **New Architecture: Automatic ChatGPT Capture**

This guide covers deploying the **webhook-based** SentinelLog system that automatically captures ChatGPT conversations without manual intervention.

### 🏗️ **Architecture Overview**

```
ChatGPT → Webhook Capture → Azure Function → Power Automate → SharePoint Lists
```

**Components:**
1. **ChatGPT Integration** (Custom GPT or Browser Extension)
2. **Azure Function Webhook** (Receives conversations)
3. **Power Automate Flow** (Processes and stores)
4. **SharePoint Lists** (Storage and metadata)

---

## 📋 **Prerequisites**

- Azure Subscription
- Power Platform environment
- SharePoint Online
- ChatGPT Plus (for Custom GPT) OR Chrome browser (for extension)

---

## 🛠️ **Phase 1: Deploy Azure Function Webhook**

### 1.1 Create Azure Function App

```bash
# Create resource group
az group create --name SentinelLog-RG --location "East US"

# Create storage account
az storage account create \
  --name sentinellogstore \
  --resource-group SentinelLog-RG \
  --location "East US" \
  --sku Standard_LRS

# Create Function App
az functionapp create \
  --resource-group SentinelLog-RG \
  --consumption-plan-location "East US" \
  --runtime node \
  --runtime-version 18 \
  --functions-version 4 \
  --name sentinellog-webhook \
  --storage-account sentinellogstore
```

### 1.2 Deploy Webhook Function

1. **Upload Function Code:**
   - Copy `webhook-integration/ChatGPT-Webhook-Handler.js` to your Function App
   - Install dependencies: `npm install @azure/functions`

2. **Configure Environment Variables:**
   ```bash
   az functionapp config appsettings set \
     --name sentinellog-webhook \
     --resource-group SentinelLog-RG \
     --settings \
     POWER_AUTOMATE_FLOW_URL="your-flow-url" \
     SHAREPOINT_SITE_URL="https://yourcompany.sharepoint.com/sites/SentinelLog" \
     ORGANIZATION_NAME="yourcompany" \
     SENTINELLOG_API_KEY="your-secure-api-key"
   ```

3. **Get Webhook URL:**
   ```bash
   az functionapp function show \
     --resource-group SentinelLog-RG \
     --name sentinellog-webhook \
     --function-name chatgpt-webhook
   ```

---

## 🔗 **Phase 2: Deploy SharePoint Infrastructure**

### 2.1 Run SharePoint Lists Deployment

```powershell
# Use the improved Lists version
.\deployment\Deploy-SentinelLog-Lists.ps1 -TenantId "your-tenant-id" -OrganizationName "yourcompany"
```

### 2.2 Configure Power Automate Flow

1. **Import Flow:**
   - Import `power-automate/ProcessChatLogSubmission-Flow-Lists.json`

2. **Update Flow Trigger:**
   - Change trigger from "PowerApps" to "HTTP Request"
   - Use webhook schema from webhook function

3. **Configure Flow URL:**
   - Copy the HTTP trigger URL
   - Update Azure Function environment variable `POWER_AUTOMATE_FLOW_URL`

---

## 💬 **Phase 3: ChatGPT Integration**

### Option A: Custom GPT (Recommended)

1. **Create Custom GPT:**
   - Go to https://chat.openai.com/gpts/editor
   - Use configuration from `chatgpt-integration/SentinelLog-GPT-Actions.json`

2. **Configure Actions:**
   - Add your webhook URL
   - Set API key for authentication
   - Test the integration

3. **Share with Organization:**
   - Make GPT available to your team
   - Provide usage instructions

### Option B: Browser Extension

1. **Install Extension:**
   - Load unpacked extension from `chatgpt-integration/browser-extension/`
   - Configure webhook URL and API key

2. **Configure User Settings:**
   - Set user email and name
   - Enable auto-capture

3. **Test Integration:**
   - Have a ChatGPT conversation
   - Verify automatic logging

---

## 🔧 **Phase 4: Configuration & Testing**

### 4.1 Configure User Authentication

```javascript
// In webhook function, add user identification
const userInfo = {
    email: request.headers.get('x-user-email') || 'unknown@company.com',
    name: request.headers.get('x-user-name') || 'Unknown User'
};
```

### 4.2 Test End-to-End Flow

1. **Custom GPT Test:**
   ```
   User: "Help me with a coding problem"
   GPT: [Provides help and automatically logs conversation]
   ```

2. **Browser Extension Test:**
   - Start conversation in ChatGPT
   - Extension automatically captures
   - Conversation appears in SharePoint

3. **Verify SharePoint Storage:**
   - Check `SentinelLog_MetadataLog` list
   - Verify file stored in document library
   - Confirm audit trail in `SentinelLog_AuditLog`

---

## 📊 **Phase 5: Monitoring & Management**

### 5.1 Set Up Monitoring

```bash
# Enable Application Insights
az monitor app-insights component create \
  --app sentinellog-insights \
  --location "East US" \
  --resource-group SentinelLog-RG
```

### 5.2 Create Dashboard

- **Azure Function Metrics:** Requests, errors, duration
- **SharePoint Activity:** File creation, user activity
- **Power Automate Runs:** Success/failure rates

### 5.3 Configure Alerts

```bash
# Create alert for webhook failures
az monitor metrics alert create \
  --name "SentinelLog Webhook Failures" \
  --resource-group SentinelLog-RG \
  --scopes "/subscriptions/your-sub/resourceGroups/SentinelLog-RG/providers/Microsoft.Web/sites/sentinellog-webhook" \
  --condition "count 'Failed Requests' > 5" \
  --window-size 5m
```

---

## 🎯 **Benefits of Webhook Architecture**

### ✅ **Advantages Over Manual System**

| **Aspect** | **Manual (Original)** | **Webhook (New)** |
|------------|----------------------|-------------------|
| **User Effort** | ❌ Copy/paste required | ✅ Fully automatic |
| **Compliance** | ⚠️ Can be forgotten | ✅ 100% capture rate |
| **Real-time** | ❌ Manual timing | ✅ Instant processing |
| **Classification** | ❌ Manual selection | ✅ AI-powered auto-classification |
| **Error Rate** | ⚠️ Human error prone | ✅ Automated accuracy |
| **Scalability** | ❌ Doesn't scale | ✅ Handles thousands of conversations |

### 🔄 **Workflow Comparison**

**Old Workflow:**
```
User → ChatGPT → Manual copy → Power Apps → Manual metadata → Submit
```

**New Workflow:**
```
User → ChatGPT → Auto-capture → Webhook → AI classification → Auto-storage
```

---

## 🛡️ **Security & Compliance**

### Authentication
- **API Key Protection:** Secure key management in Azure Key Vault
- **Azure AD Integration:** SSO for webhook access
- **CORS Configuration:** Restrict to ChatGPT domains

### Data Protection
- **Encryption in Transit:** HTTPS/TLS for all communications
- **Encryption at Rest:** SharePoint native encryption
- **Audit Trail:** Complete logging in `SentinelLog_AuditLog`

### Compliance Features
- **Automatic Classification:** AI-powered content analysis
- **Retention Management:** 7-year retention policy
- **User Identification:** Azure AD user tracking
- **Data Loss Prevention:** SharePoint DLP policies

---

## 🚀 **Next Steps**

1. **Deploy webhook infrastructure**
2. **Choose ChatGPT integration method**
3. **Configure monitoring and alerts**
4. **Train users on new workflow**
5. **Monitor and optimize performance**

---

## 🔍 **Troubleshooting**

### Common Issues

**Webhook Not Receiving Data:**
- Check Azure Function logs
- Verify CORS configuration
- Test with Postman/curl

**Classification Not Working:**
- Review AI classification logic
- Check conversation content analysis
- Adjust keyword rules

**SharePoint Connection Issues:**
- Verify Power Automate flow status
- Check SharePoint permissions
- Test flow manually

### Support Contacts
- **Technical Support:** support@yourcompany.com
- **Webhook Issues:** webhook-support@yourcompany.com
- **SharePoint Issues:** sharepoint-admin@yourcompany.com

---

**This webhook architecture provides a much more robust, scalable, and user-friendly solution for ChatGPT conversation logging! 🎉**
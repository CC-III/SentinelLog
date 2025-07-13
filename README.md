# SentinelLog - Compliant ChatGPT Conversation Logging System

🧭 **Goal**: Build a compliant, full-stack system to log, name, and store ChatGPT conversations using Power Platform and Azure.

## 🏗️ Architecture Overview

**Stack Components:**
- **Power Apps** (UI Layer) - Frontend for capturing chat transcripts and metadata
- **Power Automate** (Logic & Integration) - Backend processing and storage workflows
- **SharePoint** (Document Storage) - Structured .txt chat log storage
- **Excel/SharePoint Lists** (Metadata) - Traceability and logging
- **Azure AD** (Authentication) - SSO integration
- **Cursor AI** (Development) - Logic authoring and deployment automation

## 📁 Project Structure

```
SentinelLog/
├── power-apps/          # Power Apps UI components and schemas
├── power-automate/      # Flow definitions and logic
├── sharepoint/          # Document library and folder structure
├── excel/              # Metadata logging templates
├── security/           # Authentication and authorization
├── deployment/         # Deployment scripts and configuration
└── docs/              # Documentation and specifications
```

## 🚀 Quick Start

1. **Deploy Infrastructure**: Run deployment scripts to set up SharePoint, Excel, and authentication
2. **Import Power Apps**: Load the UI components into Power Platform
3. **Configure Power Automate**: Import and configure the processing flows
4. **Test Integration**: Verify end-to-end functionality with sample data

## 📋 Features

- ✅ Compliant file naming with context-function-dependency encoding
- ✅ Automated SharePoint storage with dynamic folder structure
- ✅ Metadata logging for full traceability
- ✅ Azure AD SSO integration
- ✅ Timestamped transcript formatting
- ✅ Recent upload history and file linking
- ✅ Version tracking and document control

## 🔐 Security & Compliance

- Azure AD authentication with SSO
- User identity tracing
- Document control standards
- Audit trail through Excel metadata logging
- Secure file storage in SharePoint

Built with Cursor AI for rapid development and deployment.

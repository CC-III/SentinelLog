# =============================================================================
# SentinelLog Desktop Launcher
# =============================================================================
# This script creates a seamless desktop-to-browser experience:
# 1. Click desktop icon
# 2. PowerShell launcher starts
# 3. Browser opens with authentication
# 4. ChatGPT integration for conversation capture
# 5. SharePoint SSO login
# 6. Power Apps interface loads
# =============================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$Environment = "Production",
    
    [Parameter(Mandatory = $false)]
    [string]$OrganizationName = "yourcompany",
    
    [Parameter(Mandatory = $false)]
    [switch]$DebugMode = $false
)

# =============================================================================
# INITIALIZATION & BRANDING
# =============================================================================

Clear-Host
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                              ║" -ForegroundColor Cyan
Write-Host "║                     🛡️  SENTINELLOG  🛡️                     ║" -ForegroundColor Cyan
Write-Host "║                                                              ║" -ForegroundColor Cyan
Write-Host "║            Compliant ChatGPT Conversation Logging           ║" -ForegroundColor Cyan
Write-Host "║                                                              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "🚀 Starting SentinelLog Desktop Launcher..." -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Organization: $OrganizationName" -ForegroundColor Yellow
Write-Host ""

# =============================================================================
# CONFIGURATION & URLS
# =============================================================================

$Config = @{
    SharePointSiteUrl = "https://$OrganizationName.sharepoint.com/sites/SentinelLog"
    PowerAppsUrl = "https://make.powerapps.com/environments/production/apps"
    ChatGPTUrl = "https://chat.openai.com/"
    AzureADLoginUrl = "https://login.microsoftonline.com"
    SentinelLogAppUrl = "https://apps.powerapps.com/play/your-app-id"
}

if ($DebugMode) {
    Write-Host "🔧 Debug Mode - Configuration:" -ForegroundColor Magenta
    $Config | Format-Table -AutoSize
    Write-Host ""
}

# =============================================================================
# SYSTEM CHECKS
# =============================================================================

Write-Host "🔍 Performing System Checks..." -ForegroundColor Blue

# Check if required modules are available
$RequiredModules = @("Microsoft.PowerShell.Utility")
foreach ($Module in $RequiredModules) {
    try {
        Import-Module $Module -ErrorAction Stop
        Write-Host "✅ Module available: $Module" -ForegroundColor Green
    } catch {
        Write-Host "❌ Module missing: $Module" -ForegroundColor Red
        Write-Host "   Installing module..." -ForegroundColor Yellow
        Install-Module $Module -Force -AllowClobber
    }
}

# Check default browser
$DefaultBrowser = Get-ItemProperty HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice -ErrorAction SilentlyContinue
if ($DefaultBrowser) {
    Write-Host "✅ Default browser detected" -ForegroundColor Green
} else {
    Write-Host "⚠️  Default browser not found, using system default" -ForegroundColor Yellow
}

# Check internet connectivity
try {
    $TestConnection = Test-NetConnection -ComputerName "login.microsoftonline.com" -Port 443 -InformationLevel Quiet
    if ($TestConnection) {
        Write-Host "✅ Internet connectivity verified" -ForegroundColor Green
    } else {
        throw "Connection failed"
    }
} catch {
    Write-Host "❌ Internet connectivity issues detected" -ForegroundColor Red
    Write-Host "   Please check your network connection" -ForegroundColor Yellow
    pause
    exit
}

Write-Host ""

# =============================================================================
# AUTHENTICATION PREPARATION
# =============================================================================

Write-Host "🔐 Preparing Authentication Flow..." -ForegroundColor Blue

# Create authentication parameters
$AuthParams = @{
    client_id = "your-azure-ad-app-id"
    response_type = "code"
    redirect_uri = $Config.SharePointSiteUrl
    scope = "https://graph.microsoft.com/.default"
    state = [System.Guid]::NewGuid().ToString()
}

# Build authentication URL
$AuthUrl = "$($Config.AzureADLoginUrl)/common/oauth2/v2.0/authorize?" + 
           ($AuthParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "&"

Write-Host "✅ Authentication URL prepared" -ForegroundColor Green
Write-Host ""

# =============================================================================
# CHATGPT INTEGRATION HELPER
# =============================================================================

Write-Host "💬 ChatGPT Integration Helper..." -ForegroundColor Blue

function Show-ChatGPTInstructions {
    Write-Host ""
    Write-Host "📋 ChatGPT Conversation Capture Instructions:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. 🔗 ChatGPT will open in a new tab" -ForegroundColor White
    Write-Host "2. 💬 Have your conversation as normal" -ForegroundColor White
    Write-Host "3. 📋 Copy the entire conversation (Ctrl+A, Ctrl+C)" -ForegroundColor White
    Write-Host "4. 🔄 Switch to SentinelLog tab" -ForegroundColor White
    Write-Host "5. 📝 Paste conversation into the text area" -ForegroundColor White
    Write-Host "6. 🏷️  Fill in metadata (Context, Function, Dependency)" -ForegroundColor White
    Write-Host "7. 🚀 Submit for compliant logging" -ForegroundColor White
    Write-Host ""
    Write-Host "💡 Tip: Keep both tabs open for easy switching!" -ForegroundColor Yellow
    Write-Host ""
}

Show-ChatGPTInstructions

# =============================================================================
# BROWSER LAUNCH SEQUENCE
# =============================================================================

Write-Host "🌐 Launching Browser Authentication Sequence..." -ForegroundColor Blue

# Create a function to open URLs with delay
function Open-UrlWithDelay {
    param(
        [string]$Url,
        [string]$Description,
        [int]$DelaySeconds = 2
    )
    
    Write-Host "🔗 Opening: $Description" -ForegroundColor Cyan
    Start-Process $Url
    
    if ($DelaySeconds -gt 0) {
        Write-Host "⏳ Waiting $DelaySeconds seconds..." -ForegroundColor Yellow
        Start-Sleep -Seconds $DelaySeconds
    }
}

# Step 1: Open Azure AD Login (for SSO handshake)
Write-Host ""
Write-Host "🔐 Step 1: Azure AD Authentication" -ForegroundColor Magenta
Open-UrlWithDelay -Url $AuthUrl -Description "Azure AD Login" -DelaySeconds 3

# Step 2: Open ChatGPT (for conversation)
Write-Host ""
Write-Host "💬 Step 2: ChatGPT Interface" -ForegroundColor Magenta
Open-UrlWithDelay -Url $Config.ChatGPTUrl -Description "ChatGPT Interface" -DelaySeconds 3

# Step 3: Open SentinelLog Power App (for logging)
Write-Host ""
Write-Host "🛡️ Step 3: SentinelLog Application" -ForegroundColor Magenta
Open-UrlWithDelay -Url $Config.SentinelLogAppUrl -Description "SentinelLog Power App" -DelaySeconds 2

Write-Host ""

# =============================================================================
# USER GUIDANCE & MONITORING
# =============================================================================

Write-Host "👀 Monitoring Session..." -ForegroundColor Blue
Write-Host ""

function Show-SessionStatus {
    Write-Host "📊 Current Session Status:" -ForegroundColor Cyan
    Write-Host "   🔐 Authentication: In Progress" -ForegroundColor Yellow
    Write-Host "   💬 ChatGPT: Available" -ForegroundColor Green
    Write-Host "   🛡️ SentinelLog: Loading" -ForegroundColor Yellow
    Write-Host "   🕒 Session Started: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor White
    Write-Host ""
}

Show-SessionStatus

# =============================================================================
# INTERACTIVE MENU
# =============================================================================

function Show-Menu {
    Write-Host "🎛️ SentinelLog Launcher Menu:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   [1] 🔄 Refresh SentinelLog App" -ForegroundColor White
    Write-Host "   [2] 💬 Open New ChatGPT Tab" -ForegroundColor White
    Write-Host "   [3] 📋 Show Instructions Again" -ForegroundColor White
    Write-Host "   [4] 🔗 Open SharePoint Site" -ForegroundColor White
    Write-Host "   [5] 📊 View Recent Logs" -ForegroundColor White
    Write-Host "   [6] ❓ Help & Support" -ForegroundColor White
    Write-Host "   [Q] 🚪 Quit Launcher" -ForegroundColor White
    Write-Host ""
}

# Main interactive loop
do {
    Show-Menu
    $Choice = Read-Host "Select an option"
    
    switch ($Choice.ToUpper()) {
        "1" {
            Write-Host "🔄 Refreshing SentinelLog App..." -ForegroundColor Yellow
            Open-UrlWithDelay -Url $Config.SentinelLogAppUrl -Description "SentinelLog Refresh" -DelaySeconds 1
        }
        "2" {
            Write-Host "💬 Opening new ChatGPT tab..." -ForegroundColor Yellow
            Open-UrlWithDelay -Url $Config.ChatGPTUrl -Description "New ChatGPT Tab" -DelaySeconds 1
        }
        "3" {
            Show-ChatGPTInstructions
        }
        "4" {
            Write-Host "🔗 Opening SharePoint site..." -ForegroundColor Yellow
            Open-UrlWithDelay -Url $Config.SharePointSiteUrl -Description "SharePoint Site" -DelaySeconds 1
        }
        "5" {
            Write-Host "📊 Opening recent logs view..." -ForegroundColor Yellow
            $RecentLogsUrl = "$($Config.SharePointSiteUrl)/Lists/SentinelLog_MetadataLog"
            Open-UrlWithDelay -Url $RecentLogsUrl -Description "Recent Logs" -DelaySeconds 1
        }
        "6" {
            Write-Host ""
            Write-Host "❓ SentinelLog Help & Support:" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "📧 Technical Support: support@$OrganizationName.com" -ForegroundColor White
            Write-Host "📖 User Guide: https://$OrganizationName.sharepoint.com/sites/SentinelLog/SitePages/Help.aspx" -ForegroundColor White
            Write-Host "🔧 System Status: https://$OrganizationName.sharepoint.com/sites/SentinelLog/Lists/SentinelLog_AuditLog" -ForegroundColor White
            Write-Host ""
        }
        "Q" {
            Write-Host "🚪 Closing SentinelLog Launcher..." -ForegroundColor Yellow
            Write-Host "Thank you for using SentinelLog! 🛡️" -ForegroundColor Green
            break
        }
        default {
            Write-Host "❌ Invalid option. Please try again." -ForegroundColor Red
        }
    }
    
    if ($Choice.ToUpper() -ne "Q") {
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        Clear-Host
        Write-Host ""
        Write-Host "🛡️ SentinelLog Launcher - Session Active" -ForegroundColor Cyan
        Write-Host ""
    }
    
} while ($Choice.ToUpper() -ne "Q")

# =============================================================================
# CLEANUP & EXIT
# =============================================================================

Write-Host ""
Write-Host "🧹 Cleaning up session..." -ForegroundColor Blue
Write-Host "✅ Session completed successfully" -ForegroundColor Green
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "             Thank you for using SentinelLog! 🛡️" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
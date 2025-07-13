# =============================================================================
# SentinelLog Deployment Script - Microsoft Lists Version
# =============================================================================
# This script deploys the SentinelLog system using SharePoint Lists instead of Excel:
# - Azure AD App Registration
# - SharePoint Site and Document Library
# - SharePoint Lists for Metadata, Errors, and Audit
# - Power Platform Components
# - Security Groups and Permissions
# =============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,
    
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$OrganizationName,
    
    [Parameter(Mandatory = $false)]
    [string]$Region = "East US",
    
    [Parameter(Mandatory = $false)]
    [string]$Environment = "Production"
)

# =============================================================================
# INITIALIZATION
# =============================================================================

Write-Host "🚀 Starting SentinelLog Deployment (Lists Version)" -ForegroundColor Green
Write-Host "Tenant ID: $TenantId" -ForegroundColor Yellow
Write-Host "Subscription: $SubscriptionId" -ForegroundColor Yellow
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Organization: $OrganizationName" -ForegroundColor Yellow

# Import required modules
$RequiredModules = @(
    "Az.Accounts",
    "Az.Resources",
    "AzureAD",
    "PnP.PowerShell",
    "Microsoft.PowerApps.Administration.PowerShell"
)

foreach ($Module in $RequiredModules) {
    if (!(Get-Module -ListAvailable -Name $Module)) {
        Write-Host "Installing module: $Module" -ForegroundColor Yellow
        Install-Module -Name $Module -Force -AllowClobber
    }
    Import-Module -Name $Module
}

# =============================================================================
# AUTHENTICATION
# =============================================================================

Write-Host "🔐 Authenticating to Azure and Microsoft 365..." -ForegroundColor Blue

# Connect to Azure
Connect-AzAccount -TenantId $TenantId -SubscriptionId $SubscriptionId

# Connect to Azure AD
Connect-AzureAD -TenantId $TenantId

# Connect to PnP PowerShell
Connect-PnPOnline -Url "https://$OrganizationName.sharepoint.com" -UseWebLogin

# =============================================================================
# AZURE AD APPLICATION REGISTRATION
# =============================================================================

Write-Host "📝 Creating Azure AD Application Registration..." -ForegroundColor Blue

$AppDisplayName = "SentinelLog"
$AppDescription = "Compliant ChatGPT conversation logging system"

# Check if app already exists
$ExistingApp = Get-AzureADApplication -Filter "DisplayName eq '$AppDisplayName'"

if ($ExistingApp) {
    Write-Host "Application already exists. Updating..." -ForegroundColor Yellow
    $App = $ExistingApp
} else {
    # Create new application
    $App = New-AzureADApplication -DisplayName $AppDisplayName -Description $AppDescription
    Write-Host "Created Azure AD Application: $($App.DisplayName)" -ForegroundColor Green
}

# Configure redirect URIs
$RedirectUris = @(
    "https://$OrganizationName.sharepoint.com/sites/SentinelLog",
    "https://make.powerapps.com/",
    "https://make.powerautomate.com/"
)

Set-AzureADApplication -ObjectId $App.ObjectId -ReplyUrls $RedirectUris

# Create service principal
$ServicePrincipal = Get-AzureADServicePrincipal -Filter "AppId eq '$($App.AppId)'"
if (!$ServicePrincipal) {
    $ServicePrincipal = New-AzureADServicePrincipal -AppId $App.AppId
    Write-Host "Created Service Principal" -ForegroundColor Green
}

# =============================================================================
# SECURITY GROUPS
# =============================================================================

Write-Host "👥 Creating Security Groups..." -ForegroundColor Blue

$SecurityGroups = @(
    @{
        Name = "SentinelLog-Administrators"
        Description = "Full administrative access to SentinelLog system"
    },
    @{
        Name = "SentinelLog-Users"
        Description = "Standard users who can submit and view their own chat logs"
    },
    @{
        Name = "SentinelLog-ReadOnly"
        Description = "Read-only access for auditors and compliance officers"
    }
)

foreach ($GroupInfo in $SecurityGroups) {
    $ExistingGroup = Get-AzureADGroup -Filter "DisplayName eq '$($GroupInfo.Name)'"
    
    if ($ExistingGroup) {
        Write-Host "Group already exists: $($GroupInfo.Name)" -ForegroundColor Yellow
    } else {
        $Group = New-AzureADGroup -DisplayName $GroupInfo.Name -Description $GroupInfo.Description -MailEnabled $false -SecurityEnabled $true
        Write-Host "Created Security Group: $($GroupInfo.Name)" -ForegroundColor Green
    }
}

# =============================================================================
# SHAREPOINT SITE CREATION
# =============================================================================

Write-Host "📚 Creating SharePoint Site..." -ForegroundColor Blue

$SiteUrl = "https://$OrganizationName.sharepoint.com/sites/SentinelLog"
$SiteTitle = "SentinelLog"
$SiteDescription = "Compliant ChatGPT conversation logging system"

# Check if site exists
try {
    $ExistingSite = Get-PnPTenantSite -Url $SiteUrl
    Write-Host "SharePoint site already exists: $SiteUrl" -ForegroundColor Yellow
} catch {
    # Create new site
    New-PnPTenantSite -Url $SiteUrl -Title $SiteTitle -Description $SiteDescription -Owner (Get-AzureADUser -Top 1).UserPrincipalName -Template "STS#3"
    Write-Host "Created SharePoint Site: $SiteUrl" -ForegroundColor Green
    
    # Wait for site to be ready
    do {
        Start-Sleep -Seconds 10
        Write-Host "Waiting for site to be ready..." -ForegroundColor Yellow
        $SiteReady = $true
        try {
            Connect-PnPOnline -Url $SiteUrl -UseWebLogin
        } catch {
            $SiteReady = $false
        }
    } while (!$SiteReady)
}

# Connect to the site
Connect-PnPOnline -Url $SiteUrl -UseWebLogin

# =============================================================================
# DOCUMENT LIBRARY CONFIGURATION
# =============================================================================

Write-Host "📁 Configuring Document Library..." -ForegroundColor Blue

$LibraryName = "ChatGPT-Logs"
$LibraryDescription = "Primary storage for ChatGPT conversation transcripts"

# Check if library exists
$ExistingLibrary = Get-PnPList -Identity $LibraryName -ErrorAction SilentlyContinue

if ($ExistingLibrary) {
    Write-Host "Document library already exists: $LibraryName" -ForegroundColor Yellow
} else {
    # Create document library
    New-PnPList -Title $LibraryName -Description $LibraryDescription -Template DocumentLibrary
    Write-Host "Created Document Library: $LibraryName" -ForegroundColor Green
}

# Add custom columns to document library
$CustomColumns = @(
    @{ Name = "SentinelLog_ContextCode"; Type = "Text"; Required = $true },
    @{ Name = "SentinelLog_FunctionCode"; Type = "Text"; Required = $true },
    @{ Name = "SentinelLog_DependencyCode"; Type = "Text"; Required = $true },
    @{ Name = "SentinelLog_IterationCode"; Type = "Text"; Required = $true },
    @{ Name = "SentinelLog_FlagCode"; Type = "Text"; Required = $false },
    @{ Name = "SentinelLog_UserEmail"; Type = "Text"; Required = $true },
    @{ Name = "SentinelLog_UserFullName"; Type = "Text"; Required = $true },
    @{ Name = "SentinelLog_Description"; Type = "Note"; Required = $false },
    @{ Name = "SentinelLog_ProcessedDate"; Type = "DateTime"; Required = $true },
    @{ Name = "SentinelLog_ComplianceStatus"; Type = "Choice"; Required = $true; Choices = @("Compliant", "Pending Review", "Non-Compliant") },
    @{ Name = "SentinelLog_ClassificationLevel"; Type = "Choice"; Required = $true; Choices = @("Public", "Internal", "Confidential", "Restricted") }
)

foreach ($Column in $CustomColumns) {
    $ExistingColumn = Get-PnPField -List $LibraryName -Identity $Column.Name -ErrorAction SilentlyContinue
    
    if ($ExistingColumn) {
        Write-Host "Column already exists: $($Column.Name)" -ForegroundColor Yellow
    } else {
        if ($Column.Type -eq "Choice") {
            Add-PnPField -List $LibraryName -DisplayName $Column.Name -InternalName $Column.Name -Type Choice -Choices $Column.Choices -Required:$Column.Required
        } else {
            Add-PnPField -List $LibraryName -DisplayName $Column.Name -InternalName $Column.Name -Type $Column.Type -Required:$Column.Required
        }
        Write-Host "Created Column: $($Column.Name)" -ForegroundColor Green
    }
}

# =============================================================================
# SHAREPOINT LISTS CREATION
# =============================================================================

Write-Host "📊 Creating SharePoint Lists..." -ForegroundColor Blue

# Create Metadata Log List
$MetadataListName = "SentinelLog_MetadataLog"
$MetadataListDescription = "Primary metadata log for all processed chat transcripts"

$ExistingMetadataList = Get-PnPList -Identity $MetadataListName -ErrorAction SilentlyContinue

if ($ExistingMetadataList) {
    Write-Host "Metadata list already exists: $MetadataListName" -ForegroundColor Yellow
} else {
    New-PnPList -Title $MetadataListName -Description $MetadataListDescription -Template GenericList
    Write-Host "Created Metadata List: $MetadataListName" -ForegroundColor Green
    
    # Add columns to metadata list
    $MetadataColumns = @(
        @{ Name = "FileName"; Type = "Text"; Required = $true },
        @{ Name = "ContextCode"; Type = "Choice"; Required = $true; Choices = @("100", "200", "300", "400") },
        @{ Name = "ContextName"; Type = "Text"; Required = $true },
        @{ Name = "FunctionCode"; Type = "Choice"; Required = $true; Choices = @("001", "002", "003", "004", "005", "006", "007") },
        @{ Name = "FunctionName"; Type = "Text"; Required = $true },
        @{ Name = "DependencyCode"; Type = "Choice"; Required = $true; Choices = @("001", "002", "003", "004", "005", "006", "007") },
        @{ Name = "DependencyName"; Type = "Text"; Required = $true },
        @{ Name = "IterationCode"; Type = "Text"; Required = $true },
        @{ Name = "FlagCode"; Type = "Choice"; Required = $false; Choices = @("P", "U", "R", "D", "F") },
        @{ Name = "UserEmail"; Type = "Text"; Required = $true },
        @{ Name = "UserFullName"; Type = "Text"; Required = $true },
        @{ Name = "Description"; Type = "Note"; Required = $false },
        @{ Name = "FileExtension"; Type = "Choice"; Required = $true; Choices = @("txt", "md", "log") },
        @{ Name = "SharePointPath"; Type = "Text"; Required = $true },
        @{ Name = "FileURL"; Type = "URL"; Required = $true },
        @{ Name = "ProcessedDate"; Type = "DateTime"; Required = $true },
        @{ Name = "ProcessedBy"; Type = "Text"; Required = $true },
        @{ Name = "Status"; Type = "Choice"; Required = $true; Choices = @("Processed", "Error", "Pending") },
        @{ Name = "ComplianceStatus"; Type = "Choice"; Required = $true; Choices = @("Compliant", "Pending Review", "Non-Compliant") },
        @{ Name = "FileSize"; Type = "Number"; Required = $false },
        @{ Name = "ConversationLength"; Type = "Number"; Required = $false },
        @{ Name = "RetentionDate"; Type = "DateTime"; Required = $false }
    )
    
    foreach ($Column in $MetadataColumns) {
        if ($Column.Type -eq "Choice") {
            Add-PnPField -List $MetadataListName -DisplayName $Column.Name -InternalName $Column.Name -Type Choice -Choices $Column.Choices -Required:$Column.Required
        } elseif ($Column.Type -eq "URL") {
            Add-PnPField -List $MetadataListName -DisplayName $Column.Name -InternalName $Column.Name -Type URL -Required:$Column.Required
        } else {
            Add-PnPField -List $MetadataListName -DisplayName $Column.Name -InternalName $Column.Name -Type $Column.Type -Required:$Column.Required
        }
        Write-Host "Created metadata column: $($Column.Name)" -ForegroundColor Green
    }
}

# Create Error Log List
$ErrorListName = "SentinelLog_ErrorLog"
$ErrorListDescription = "Error tracking for failed processing attempts"

$ExistingErrorList = Get-PnPList -Identity $ErrorListName -ErrorAction SilentlyContinue

if ($ExistingErrorList) {
    Write-Host "Error list already exists: $ErrorListName" -ForegroundColor Yellow
} else {
    New-PnPList -Title $ErrorListName -Description $ErrorListDescription -Template GenericList
    Write-Host "Created Error List: $ErrorListName" -ForegroundColor Green
    
    # Add columns to error list
    $ErrorColumns = @(
        @{ Name = "ErrorID"; Type = "Number"; Required = $true },
        @{ Name = "FileName"; Type = "Text"; Required = $false },
        @{ Name = "UserEmail"; Type = "Text"; Required = $true },
        @{ Name = "ErrorMessage"; Type = "Note"; Required = $true },
        @{ Name = "ErrorType"; Type = "Choice"; Required = $true; Choices = @("Validation", "Storage", "Permission", "Network", "System") },
        @{ Name = "ErrorDate"; Type = "DateTime"; Required = $true },
        @{ Name = "Status"; Type = "Choice"; Required = $true; Choices = @("New", "Investigating", "Resolved") },
        @{ Name = "Resolution"; Type = "Note"; Required = $false },
        @{ Name = "ResolvedDate"; Type = "DateTime"; Required = $false },
        @{ Name = "ResolvedBy"; Type = "Text"; Required = $false }
    )
    
    foreach ($Column in $ErrorColumns) {
        if ($Column.Type -eq "Choice") {
            Add-PnPField -List $ErrorListName -DisplayName $Column.Name -InternalName $Column.Name -Type Choice -Choices $Column.Choices -Required:$Column.Required
        } else {
            Add-PnPField -List $ErrorListName -DisplayName $Column.Name -InternalName $Column.Name -Type $Column.Type -Required:$Column.Required
        }
        Write-Host "Created error column: $($Column.Name)" -ForegroundColor Green
    }
}

# Create Audit Log List
$AuditListName = "SentinelLog_AuditLog"
$AuditListDescription = "Audit trail for compliance and security"

$ExistingAuditList = Get-PnPList -Identity $AuditListName -ErrorAction SilentlyContinue

if ($ExistingAuditList) {
    Write-Host "Audit list already exists: $AuditListName" -ForegroundColor Yellow
} else {
    New-PnPList -Title $AuditListName -Description $AuditListDescription -Template GenericList
    Write-Host "Created Audit List: $AuditListName" -ForegroundColor Green
    
    # Add columns to audit list
    $AuditColumns = @(
        @{ Name = "AuditID"; Type = "Number"; Required = $true },
        @{ Name = "FileName"; Type = "Text"; Required = $false },
        @{ Name = "UserEmail"; Type = "Text"; Required = $true },
        @{ Name = "Action"; Type = "Choice"; Required = $true; Choices = @("View", "Edit", "Delete", "Download", "Share", "Submit") },
        @{ Name = "ActionDate"; Type = "DateTime"; Required = $true },
        @{ Name = "IPAddress"; Type = "Text"; Required = $false },
        @{ Name = "Success"; Type = "Boolean"; Required = $true },
        @{ Name = "Details"; Type = "Note"; Required = $false }
    )
    
    foreach ($Column in $AuditColumns) {
        if ($Column.Type -eq "Choice") {
            Add-PnPField -List $AuditListName -DisplayName $Column.Name -InternalName $Column.Name -Type Choice -Choices $Column.Choices -Required:$Column.Required
        } elseif ($Column.Type -eq "Boolean") {
            Add-PnPField -List $AuditListName -DisplayName $Column.Name -InternalName $Column.Name -Type Boolean -Required:$Column.Required
        } else {
            Add-PnPField -List $AuditListName -DisplayName $Column.Name -InternalName $Column.Name -Type $Column.Type -Required:$Column.Required
        }
        Write-Host "Created audit column: $($Column.Name)" -ForegroundColor Green
    }
}

# =============================================================================
# FOLDER STRUCTURE CREATION
# =============================================================================

Write-Host "📂 Creating Folder Structure..." -ForegroundColor Blue

$FolderStructure = @(
    @{ Context = "Development"; Code = "100" },
    @{ Context = "Testing"; Code = "200" },
    @{ Context = "Production"; Code = "300" },
    @{ Context = "Documentation"; Code = "400" }
)

$Functions = @(
    @{ Name = "Analysis"; Code = "001" },
    @{ Name = "Design"; Code = "002" },
    @{ Name = "Implementation"; Code = "003" },
    @{ Name = "Testing"; Code = "004" },
    @{ Name = "Review"; Code = "005" },
    @{ Name = "Debugging"; Code = "006" },
    @{ Name = "Documentation"; Code = "007" }
)

$Dependencies = @(
    @{ Name = "Frontend"; Code = "001" },
    @{ Name = "Backend"; Code = "002" },
    @{ Name = "Database"; Code = "003" },
    @{ Name = "API"; Code = "004" },
    @{ Name = "UI/UX"; Code = "005" },
    @{ Name = "Security"; Code = "006" },
    @{ Name = "DevOps"; Code = "007" }
)

foreach ($Context in $FolderStructure) {
    $ContextPath = "ChatGPT-Logs/$($Context.Context)"
    
    # Create context folder
    $ExistingContextFolder = Get-PnPFolder -Url $ContextPath -ErrorAction SilentlyContinue
    if (!$ExistingContextFolder) {
        Add-PnPFolder -Name $Context.Context -Folder "ChatGPT-Logs"
        Write-Host "Created folder: $ContextPath" -ForegroundColor Green
    }
    
    foreach ($Function in $Functions) {
        $FunctionPath = "$ContextPath/$($Function.Name)"
        
        # Create function folder
        $ExistingFunctionFolder = Get-PnPFolder -Url $FunctionPath -ErrorAction SilentlyContinue
        if (!$ExistingFunctionFolder) {
            Add-PnPFolder -Name $Function.Name -Folder $ContextPath
            Write-Host "Created folder: $FunctionPath" -ForegroundColor Green
        }
        
        foreach ($Dependency in $Dependencies) {
            $DependencyPath = "$FunctionPath/$($Dependency.Name)"
            
            # Create dependency folder
            $ExistingDependencyFolder = Get-PnPFolder -Url $DependencyPath -ErrorAction SilentlyContinue
            if (!$ExistingDependencyFolder) {
                Add-PnPFolder -Name $Dependency.Name -Folder $FunctionPath
                Write-Host "Created folder: $DependencyPath" -ForegroundColor Green
            }
        }
    }
}

# =============================================================================
# PERMISSIONS CONFIGURATION
# =============================================================================

Write-Host "🔒 Configuring Permissions..." -ForegroundColor Blue

# Get security groups
$AdminGroup = Get-AzureADGroup -Filter "DisplayName eq 'SentinelLog-Administrators'"
$UserGroup = Get-AzureADGroup -Filter "DisplayName eq 'SentinelLog-Users'"
$ReadOnlyGroup = Get-AzureADGroup -Filter "DisplayName eq 'SentinelLog-ReadOnly'"

# Configure site permissions
if ($AdminGroup) {
    Set-PnPGroupPermissions -Identity $AdminGroup.DisplayName -AddRole "Full Control"
    Write-Host "Configured admin permissions" -ForegroundColor Green
}

if ($UserGroup) {
    Set-PnPGroupPermissions -Identity $UserGroup.DisplayName -AddRole "Contribute"
    Write-Host "Configured user permissions" -ForegroundColor Green
}

if ($ReadOnlyGroup) {
    Set-PnPGroupPermissions -Identity $ReadOnlyGroup.DisplayName -AddRole "Read"
    Write-Host "Configured read-only permissions" -ForegroundColor Green
}

# =============================================================================
# COMPLETION
# =============================================================================

Write-Host "✅ SentinelLog Deployment Complete (Lists Version)!" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Import the Power Apps application" -ForegroundColor White
Write-Host "2. Import the Power Automate flow (Lists version)" -ForegroundColor White
Write-Host "3. Configure connections in Power Platform" -ForegroundColor White
Write-Host "4. Test the end-to-end functionality" -ForegroundColor White
Write-Host ""
Write-Host "Resources Created:" -ForegroundColor Yellow
Write-Host "- Azure AD Application: $($App.DisplayName)" -ForegroundColor White
Write-Host "- SharePoint Site: $SiteUrl" -ForegroundColor White
Write-Host "- Document Library: $LibraryName" -ForegroundColor White
Write-Host "- Metadata List: $MetadataListName" -ForegroundColor White
Write-Host "- Error List: $ErrorListName" -ForegroundColor White
Write-Host "- Audit List: $AuditListName" -ForegroundColor White
Write-Host "- Security Groups: 3 groups created" -ForegroundColor White
Write-Host "- Folder Structure: Complete hierarchy created" -ForegroundColor White
Write-Host ""
Write-Host "Application ID: $($App.AppId)" -ForegroundColor Cyan
Write-Host "Site URL: $SiteUrl" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎉 Advantages of Lists Version:" -ForegroundColor Green
Write-Host "✅ Better concurrent access" -ForegroundColor White
Write-Host "✅ Real-time updates" -ForegroundColor White
Write-Host "✅ Native SharePoint integration" -ForegroundColor White
Write-Host "✅ No file locking issues" -ForegroundColor White
Write-Host "✅ Improved performance" -ForegroundColor White
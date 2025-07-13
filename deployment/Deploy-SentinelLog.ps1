# =============================================================================
# SentinelLog Deployment Script
# =============================================================================
# This script deploys the complete SentinelLog system including:
# - Azure AD App Registration
# - SharePoint Site and Document Library
# - Excel Metadata Workbook
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

Write-Host "🚀 Starting SentinelLog Deployment" -ForegroundColor Green
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

# Add custom columns
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
# EXCEL METADATA WORKBOOK
# =============================================================================

Write-Host "📊 Creating Excel Metadata Workbook..." -ForegroundColor Blue

$WorkbookName = "SentinelLog-Metadata.xlsx"
$WorkbookPath = "/Shared Documents/$WorkbookName"

# Check if workbook exists
$ExistingWorkbook = Get-PnPFile -Url $WorkbookPath -AsListItem -ErrorAction SilentlyContinue

if ($ExistingWorkbook) {
    Write-Host "Excel workbook already exists: $WorkbookName" -ForegroundColor Yellow
} else {
    # Create Excel workbook with metadata structure
    # Note: This would require Excel Online API or pre-created template
    Write-Host "Excel workbook template needs to be manually created and uploaded" -ForegroundColor Yellow
    Write-Host "Please upload the Excel template to: $WorkbookPath" -ForegroundColor Yellow
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

Write-Host "✅ SentinelLog Deployment Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Upload the Excel metadata template to SharePoint" -ForegroundColor White
Write-Host "2. Import the Power Apps application" -ForegroundColor White
Write-Host "3. Import the Power Automate flow" -ForegroundColor White
Write-Host "4. Configure connections in Power Platform" -ForegroundColor White
Write-Host "5. Test the end-to-end functionality" -ForegroundColor White
Write-Host ""
Write-Host "Resources Created:" -ForegroundColor Yellow
Write-Host "- Azure AD Application: $($App.DisplayName)" -ForegroundColor White
Write-Host "- SharePoint Site: $SiteUrl" -ForegroundColor White
Write-Host "- Document Library: $LibraryName" -ForegroundColor White
Write-Host "- Security Groups: 3 groups created" -ForegroundColor White
Write-Host "- Folder Structure: Complete hierarchy created" -ForegroundColor White
Write-Host ""
Write-Host "Application ID: $($App.AppId)" -ForegroundColor Cyan
Write-Host "Site URL: $SiteUrl" -ForegroundColor Cyan
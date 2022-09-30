@echo off
SETLOCAL ENABLEDELAYEDEXPANSION
color 0a
title WhatsApp Key/DB Extractor 4.7.1 (fork)
set LEGACY_VER=2.11.431
set LEGACY_LEN=18329558
set LEGACY_URL=http://www.cdn.whatsapp.net/android/%LEGACY_VER%/WhatsApp.apk
set LEGACY_APK=tmp\WhatsAppLegacy-%LEGACY_VER%.apk
echo.
echo =========================================================================
echo = This script will extract the WhatsApp Key file and DB on Android 4.0+ =
echo = You DO NOT need root for this to work but you DO need Java installed. =
echo = If your WhatsApp version is greater than %LEGACY_VER% (most likely), then =
echo = a legacy version will be installed temporarily in order to get backup =
echo = permissions. You will NOT lose ANY data and your current version will =
echo = be restored at the end of the extraction process so try not to panic. =
echo = Script by: TripCode (Greets to all who visit: XDA Developers Forums). =
echo = Thanks to: dragomerlin for ABE and to Abinash Bishoyi for being cool. =
echo =         ###         Version: v4.7.1 (2022-09-30)         ###          =
echo =========================================================================
echo.
if not exist bin (
    echo Unable to locate the bin directory! Did you extract all the files from the & echo archive ^(maintaining structure^) and are you running from that directory?
    echo.
    echo Exiting ...
    echo.
    bin\adb.exe kill-server
    pause
    exit
)

echo Please connect your Android device with USB Debugging enabled:
echo.
bin\adb.exe kill-server
bin\adb.exe start-server
bin\adb.exe wait-for-device
bin\adb.exe shell getprop ro.build.version.sdk > tmp\sdkver.txt
set /p sdkver=<tmp\sdkver.txt
echo.
if %sdkver% leq 13 (
    set sdkver=
    echo Unsupported Android Version - this method only works on 4.0 or higher :/
    echo.
    echo Cleaning up temporary files ...
    del tmp\sdkver.txt /s /q
    echo.
    echo Exiting ...
    goto end
)

bin\adb.exe shell pm path com.whatsapp | bin\grep.exe package > tmp\wapath.txt
bin\adb.exe shell "echo $EXTERNAL_STORAGE" > tmp\sdpath.txt
bin\adb.exe shell dumpsys package com.whatsapp | bin\grep.exe versionName > tmp\wapver.txt
bin\curl.exe -sI %LEGACY_URL% | bin\grep.exe Content-Length > tmp\waplen.txt
set /p apkflen=<tmp\waplen.txt
set apkflen=%apkflen:Content-Length: =%
if %apkflen% == %LEGACY_LEN% (
    set apkfurl=%LEGACY_URL%
) else (
    set apkfurl=http://whatcrypt.com/WhatsApp-%LEGACY_VER%.apk
)

set /p apkpath=<tmp\wapath.txt
set /p sdpath=<tmp\sdpath.txt
set apkpath=%apkpath:package:=%
set /p version=<tmp\wapver.txt
for %%A in ("%apkpath%") do (
    set apkname=%%~nxA
)

:nextVar
for /F "tokens=1" %%k in ("%version%") do (
    set %%k
    set version=%%v
)

for %%A in (wapath.txt) do if %%~zA==0 (
    set apkpath=
    echo.
    echo WhatsApp is not installed on the target device
    echo.
    echo Exiting ...
    echo.
    goto clean_temp_files
)

set ORIGINAL_APK=tmp\WhatsAppInstalled-%versionName%.apk
echo WhatsApp %versionName% installed
echo.
if %versionName% equ %LEGACY_VER% goto backup_data
if not exist %LEGACY_APK% (
    echo Downloading legacy WhatsApp %LEGACY_VER% to local folder...
    bin\curl.exe -sS -o %LEGACY_APK% %apkfurl%
) else (
    echo Found legacy WhatsApp %LEGACY_VER% in local folder.
)

echo.
if %sdkver% geq 11 (
    bin\adb.exe shell am force-stop com.whatsapp
) else (
    bin\adb.exe shell am kill com.whatsapp
)

if not exist %ORIGINAL_APK% (
    echo Backing up installed WhatsApp %versionName%...
    bin\adb.exe pull %apkpath% %ORIGINAL_APK%
    echo Backup complete.
) else (
    echo Found installed WhatsApp %versionName% in local folder.
)

echo.
if %sdkver% geq 23 (
    echo Removing WhatsApp %versionName% skipping data
    bin\adb.exe shell pm uninstall -k com.whatsapp
    echo Removal complete
    echo.
)

echo Installing legacy WhatsApp %LEGACY_VER%
if %sdkver% geq 17 (
    bin\adb.exe install -r -d %LEGACY_APK%
) else (
    bin\adb.exe install -r %LEGACY_APK%
)

echo Install complete
echo.

:backup_data
if %sdkver% geq 23 (
    bin\adb.exe backup -f tmp\whatsapp.ab com.whatsapp
) else (
    bin\adb.exe backup -f tmp\whatsapp.ab -noapk com.whatsapp
)

if not exist tmp\whatsapp.ab (
    echo Couldn't backup WhatsApp data!
    echo.
    goto restore_original_version
)

:decrypt
set /p password="Please enter your backup password (leave blank for none) and press Enter: "
echo.
if "!password!" == "" (
    java -jar bin\abe.jar unpack tmp\whatsapp.ab tmp\whatsapp.tar
) else (
    java -jar bin\abe.jar unpack tmp\whatsapp.ab tmp\whatsapp.tar "!password!"
)

set db_files=msgstore.db wa.db axolotl.db chatsettings.db
for %%f in (%db_files%) do (
    bin\tar.exe xvf tmp\whatsapp.tar -C tmp\ apps/com.whatsapp/db/%%f
    if exist tmp\apps\com.whatsapp\%%f (
        echo Extracting %%f...
        copy /y tmp\apps\com.whatsapp\db\%%f extracted\%%f
        echo.
    )
)

bin\tar.exe xvf tmp\whatsapp.tar -C tmp\ apps/com.whatsapp/f/key
if exist tmp\apps\com.whatsapp\f\key (
    echo Extracting whatsapp.cryptkey...
    copy /y tmp\apps\com.whatsapp\f\key extracted\whatsapp.cryptkey
    echo.
)

if exist tmp\apps\com.whatsapp\f\key (
    echo Pushing cipher key to: %sdpath%/WhatsApp/Databases/.nomedia
    bin\adb.exe push tmp\apps\com.whatsapp\f\key %sdpath%/WhatsApp/Databases/.nomedia
    echo.
)

:restore_original_version
if exist %ORIGINAL_APK% (
    echo Restoring WhatsApp %versionName%
    if %sdkver% geq 17 (
        bin\adb.exe install -r -d %ORIGINAL_APK%
    ) else (
        bin\adb.exe install -r %ORIGINAL_APK%
    )

    echo.
    echo Restore complete
    echo.
)

:clean_temp_files
echo Cleaning up temporary files...
set temp_files=waplen.txt sdpath.txt wapath.txt wapver.txt sdkver.txt whatsapp.ab whatsapp.tar
for %%f in (%temp_files%) do (
    if exist tmp\%%f (
        echo    Deleting tmp\%%f
        del /q tmp\%%f
    )
)

if exist tmp\apps (
    echo    Deleting directory tmp\apps
    rmdir /s /q tmp\apps
)

echo.
echo Operation complete

:end
echo.
bin\adb.exe kill-server
pause
exit

@echo off
REM Installs the playtest APK on a USB-connected Android phone (USB debugging enabled).
REM Usage: tools\install_apk.bat   (run from the project folder)
set ADB=C:\code\android-sdk\platform-tools\adb.exe
set APK=build\IronRedoubt-0.10.0-playtest.apk
"%ADB%" devices -l
"%ADB%" install -r "%APK%"
if errorlevel 1 (
  echo Install failed. If the app was signed with a different key before, uninstall it first:
  echo   "%ADB%" uninstall com.ironredoubt.game
  exit /b 1
)
"%ADB%" shell monkey -p com.ironredoubt.game -c android.intent.category.LAUNCHER 1
echo Installed and launched.

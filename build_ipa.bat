@echo off
REM ============================================================
REM  TKFloatKey - 一键编译 + 打包成可安装的 IPA（需在 macOS 上运行）
REM  用法（macOS 终端）:  bash build_ipa.sh 你的TeamID
REM ============================================================
setlocal enabledelayedexpansion

set TEAMID=%~1
if "%TEAMID%"=="" set TEAMID=YOURTEAMID

echo [1/5] 清理旧产物...
if exist build rmdir /S /Q build
if exist Payload rmdir /S /Q Payload
if exist TKFloatKey.ipa del /Q TKFloatKey.ipa
if exist TKFloatKey.zip del /Q TKFloatKey.zip

echo [2/5] 编译 Release (无签名, iphoneos) ...
xcodebuild -project TKFloatKey.xcodeproj ^
           -scheme TKFloatKey ^
           -configuration Release ^
           -sdk iphoneos ^
           -derivedDataPath build ^
           CODE_SIGNING_ALLOWED=NO ^
           CODE_SIGNING_REQUIRED=NO ^
           CODE_SIGN_IDENTITY="" ^
           DEVELOPMENT_TEAM=%TEAMID% ^
           build
if errorlevel 1 goto fail

echo [3/5] 组装 Payload ...
mkdir Payload
xcopy /E /I /Y build\Build\Products\Release-iphoneos\TKFloatKey.app Payload\TKFloatKey.app >nul
if errorlevel 1 goto fail

echo [4/5] 压缩成 ipa ...
powershell -NoProfile -Command "Compress-Archive -Path Payload -DestinationPath TKFloatKey.zip -Force; Move-Item -Force TKFloatKey.zip TKFloatKey.ipa"
if errorlevel 1 goto fail

echo [5/5] 完成: TKFloatKey.ipa
dir TKFloatKey.ipa
goto :eof

:fail
echo 编译失败，检查上面的 xcodebuild 日志。
exit /b 1

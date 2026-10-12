@echo off
:: 作者 startgo (startgo@yia.app)
:: 授權預設 GPLv3
:: 2026-10-12 v6.1.2

title OpenS OrCAD NP 一鍵部署程式
chcp 65001 >nul

:: 1. 測試管理員權限，若無則請求提權
fltmc >nul 2>&1
if %errorlevel% neq 0 (
    echo [*] 正在請求系統管理員身分提權...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
echo [*] 權限確認成功...

:: 2. 徹底解除 Windows 網路下載檔案的安全封鎖 (Mark-of-the-Web)
echo [*] 正在解除檔案安全性鎖定...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -Path '%~dp0' -Recurse | Unblock-File -ErrorAction SilentlyContinue"

:: 3. 以最高權限 Bypass 執行 Deploy.ps1
echo [*] 啟動核心部署腳本...
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Deploy.ps1"

echo.
echo -----------------------------------------------------
echo 請按任意鍵退出...
pause >nul
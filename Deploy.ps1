<#
作者 startgo (startgo@yia.app)
授權預設 GPLv3
2026-10-12 v1.0.0
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "OpenS OrCAD NP 部署核心"

try {
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host "   OpenS OrCAD Capture NP 工具 - 自動探測部署程式    " -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor Cyan

    $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
    Write-Host "[*] 部署程式根目錄: $ScriptRoot" -ForegroundColor DarkGray

    # 1. 自動探測 OrCAD Capture 安裝路徑
    $DetectedSpbRoot = $null

    # A. 系統環境變數 CDSROOT
    if ($env:CDSROOT -and (Test-Path "$env:CDSROOT\tools\capture")) {
        $DetectedSpbRoot = $env:CDSROOT
        Write-Host "[+] 命中系統變數 CDSROOT: $DetectedSpbRoot" -ForegroundColor Green
    }

    # B. 登錄檔探測
    if (-not $DetectedSpbRoot) {
        $RegKeys = @(
            "HKLM:\SOFTWARE\Cadence\SPB_16.6",
            "HKLM:\SOFTWARE\Cadence\SPB_17.2",
            "HKLM:\SOFTWARE\Cadence\SPB_17.4",
            "HKLM:\SOFTWARE\Cadence\SPB_22.1",
            "HKLM:\SOFTWARE\WOW6432Node\Cadence\SPB_16.6"
        )
        foreach ($rk in $RegKeys) {
            if (Test-Path $rk) {
                $val = (Get-ItemProperty -Path $rk -ErrorAction SilentlyContinue).CDSROOT
                if ($val -and (Test-Path "$val\tools\capture")) {
                    $DetectedSpbRoot = $val
                    Write-Host "[+] 命中登錄檔路徑: $DetectedSpbRoot" -ForegroundColor Green
                    break
                }
            }
        }
    }

    # C. 常用磁碟掃描
    if (-not $DetectedSpbRoot) {
        $Drives = @("O:", "C:", "D:", "E:")
        $Candidates = @(
            "Cadence\SPB_16.6",
            "Cadence\SPB_17.2",
            "Cadence\SPB_17.4",
            "Cadence\SPB_22.1"
        )
        foreach ($drv in $Drives) {
            foreach ($cand in $Candidates) {
                $testPath = Join-Path $drv $cand
                if (Test-Path "$testPath\tools\capture\tclscripts") {
                    $DetectedSpbRoot = $testPath
                    Write-Host "[+] 磁碟掃描命中: $DetectedSpbRoot" -ForegroundColor Green
                    break
                }
            }
            if ($DetectedSpbRoot) { break }
        }
    }

    # 未能探測到時提示手動輸入
    if (-not $DetectedSpbRoot) {
        Write-Host "[-] 未能自動偵測到 Cadence SPB 安裝目錄！" -ForegroundColor Yellow
        $UserPath = Read-Host "請直接手動輸入 SPB 根目錄路徑 (例如: O:\Cadence\SPB_16.6)"
        if (Test-Path "$UserPath\tools\capture\tclscripts") {
            $DetectedSpbRoot = $UserPath
        } else {
            Write-Host "[x] 路徑無效或找不到 tools\capture\tclscripts，部署中止。" -ForegroundColor Red
            return
        }
    }

    # 2. 定義目錄
    $TargetTclScripts = Join-Path $DetectedSpbRoot "tools\capture\tclscripts"
    $TargetAutoLoad   = Join-Path $TargetTclScripts "capAutoLoad"
    $TargetOpenS      = Join-Path $TargetTclScripts "OpenS"

    Write-Host "[*] 寫入目標: $TargetTclScripts" -ForegroundColor Cyan

    if (-not (Test-Path $TargetAutoLoad)) { New-Item -ItemType Directory -Path $TargetAutoLoad -Force | Out-Null }
    if (-not (Test-Path $TargetOpenS))    { New-Item -ItemType Directory -Path $TargetOpenS -Force | Out-Null }

    # 3. 定位來源檔
    $SourceCoreTcl = Join-Path $ScriptRoot "OpenS\OpenS_Cap_NP.tcl"
    $SourceLoadTcl = Join-Path $ScriptRoot "OpenS\capAutoLoad\load_tcl.tcl"

    if (-not (Test-Path $SourceCoreTcl)) { $SourceCoreTcl = Join-Path $ScriptRoot "OpenS_Cap_NP.tcl" }
    if (-not (Test-Path $SourceLoadTcl)) { $SourceLoadTcl = Join-Path $ScriptRoot "load_tcl.tcl" }

    if (-not (Test-Path $SourceCoreTcl) -or -not (Test-Path $SourceLoadTcl)) {
        Write-Host "[x] 找不到來源腳本檔案！" -ForegroundColor Red
        Write-Host "    請確認 OpenS 資料夾與腳本是否放置於解壓目錄下。" -ForegroundColor Red
        return
    }

    # 4. 備份既有檔案
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $DestLoadTcl = Join-Path $TargetAutoLoad "load_tcl.tcl"
    $DestCoreTcl = Join-Path $TargetOpenS "OpenS_Cap_NP.tcl"

    if (Test-Path $DestLoadTcl) {
        Copy-Item $DestLoadTcl "$DestLoadTcl.bak_$Timestamp" -Force
        Write-Host "[*] 已備份舊引導檔: load_tcl.tcl.bak_$Timestamp" -ForegroundColor DarkGray
    }
    if (Test-Path $DestCoreTcl) {
        Copy-Item $DestCoreTcl "$DestCoreTcl.bak_$Timestamp" -Force
        Write-Host "[*] 已備份舊核心檔: OpenS_Cap_NP.tcl.bak_$Timestamp" -ForegroundColor DarkGray
    }

    # 5. 複製核心腳本
    Copy-Item -Path $SourceCoreTcl -Destination $DestCoreTcl -Force
    Write-Host "[+] 核心模組已安裝: $DestCoreTcl" -ForegroundColor Green

    # 6. 計算 Tcl 格式路徑並替換寫入 (採用純無 BOM UTF-8 編碼)
    $TclFormattedPath = ($DestCoreTcl -replace '\\', '/')
    $LoadTclRaw = [System.IO.File]::ReadAllText($SourceLoadTcl)

    $PatchedLoadTcl = $LoadTclRaw -replace 'source\s+"[^"]*OpenS_Cap_NP\.tcl"', "source `"$TclFormattedPath`""
    $PatchedLoadTcl = $PatchedLoadTcl -replace 'file exists\s+"[^"]*OpenS_Cap_NP\.tcl"', "file exists `"$TclFormattedPath`""

    # 注意：第二個參數為 $False，嚴格禁止產生 UTF-8 BOM
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllText($DestLoadTcl, $PatchedLoadTcl, $Utf8NoBomEncoding)
    Write-Host "[+] 引導模組已完成路徑連結 (無 BOM 格式): $DestLoadTcl" -ForegroundColor Green

    Write-Host ""
    Write-Host "=====================================================" -ForegroundColor Green
    Write-Host "   [√] 部署成功完成！" -ForegroundColor Green
    Write-Host "   快捷鍵: Shift+X (Set NP) / Shift+Z (Unset NP)" -ForegroundColor White
    Write-Host "   選單: Edit -> Set NP / Unset NP" -ForegroundColor White
    Write-Host "=====================================================" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "[x] 部署過程發生錯誤: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
}
# OpenS OrCAD Capture NP Toggle Tool

* 作者：startgo (startgo@yia.app)
* 授權：GPLv3
* 日期：2026-10-12
* 版本：v1.0.0

---

## 專案簡介
針對 Cadence OrCAD Capture（原生相容 16.6，向上支援 17.x / 22.x）開發的元件 NP（Not Present / 不打件）狀態快速切換擴充套件。

透過底層 C++/Tcl SWIG 介面操作原理圖元件資料結構，消除重複標記的人工失誤。具備無奪焦重繪（No Steal Focus Refresh）架構，並杜絕了頻繁快速切換引起的直譯器記憶體野指標（Dangling Pointer）崩潰問題。

---

## 狀態切換規則

| 處理屬性 / 標的 | Set NP (`Shift+X`) | Unset NP (`Shift+Z`) | 行為細節 |
| :--- | :--- | :--- | :--- |
| **Value** | 增加前綴 `NP/`（例：`NP/10K`） | 移除前綴 `NP/`（還原原值） | 冪等操作，不會重複累加 |
| **Value 顏色** | 深紅色 (`Color 24`) | 深藍色 (`Color 238`) | 標記屬性狀態並即時渲染 |
| **Reference 顏色** | 深紅色 (`Color 24`) | 深藍色 (`Color 238`) | 包含本體標號與階層映射名稱 |
| **Part Number** | 增加前綴 `*`（例：`*GRM188...`） | 移除前綴 `*` | 自動掃描並匹配 8 種常用料號屬性 |
| **BOM_IGNORE** | 寫入 `V` | 清空為空字串 `""` | 供 CIS / BOM 匯出規則過濾 |

---

## 發行包檔案結構

```text
Orcad_NP_Item/
├── Deploy.bat               # [入口] 雙擊執行，自動提權與解鎖
├── Deploy.ps1               # 自動探測、備份與路徑代換核心
├── README.md                # 專案技術與操作手冊
└── OpenS/
    ├── OpenS_Cap_NP.tcl     # 核心功能模組 (封裝 ::ToggleNP 命名空間)
    └── capAutoLoad/
        └── load_tcl.tcl     # 系統導引檔 (註冊 Action、選單與快捷鍵)
```

---

## 一鍵安裝步驟

1. 下載並完整解壓縮 `Orcad_NP_Item.zip`。
2. 直接滑鼠雙擊 **`Deploy.bat`**。
3. 當跳出 Windows 使用者帳戶控制（UAC）時，點選「**是**」。
4. 部署程式將自動執行：
   * **安全解除**：自動抹除 Windows 網路下載附加的 Zone.Identifier 安全封鎖。
   * **路徑探測**：依序由環境變數 `$env:CDSROOT` $\rightarrow$ 註冊表 $\rightarrow$ 實體磁區（`O:`, `C:`, `D:`, `E:`）探測 Cadence 安裝位置。
   * **安全備份**：若目標目錄已有舊版檔案，自動建立 `.bak_時間戳記` 備份檔。
   * **動態組態**：動態換算目標安裝絕對路徑（轉換正斜線 `/` 規格），並安裝至 `tools/capture/tclscripts`。
5. 看到 `[√] 部署成功完成！` 後按任意鍵關閉視窗，重新啟動 OrCAD Capture 即可。

---

## 操作模式

| 操作媒介 | 作用視窗 | 指令 / 操作方式 |
| :--- | :--- | :--- |
| **鍵盤快捷鍵** | 原理圖畫布 (`Schematic`) | **`Shift + X`**：標記 NP<br>**`Shift + Z`**：解除 NP |
| **系統主選單** | OrCAD Capture 主介面 | **`Edit`** $\rightarrow$ **`Set NP`** / **`Unset NP`** |
| **終端命令** | Command 視窗 | 輸入 **`np`** 或 **`unnp`** 直接對當前選取物件批次操作 |
<img width="288" height="585" alt="image" src="https://github.com/user-attachments/assets/ee83d108-a5b5-40c3-9a48-304e9abd4fb4" />



<br>




---

## 核心技術要點

* **記憶體安全性 (Memory Stability)**：
  不手動調用 SWIG 層之析構器（避免手動 `delete_DboState`），交由 Tcl 執行期生命週期進行 GC 回收，防止 C++ 底層發生 `0xC0000005 Access Violation`。
* **非破壞性重繪 (Clean Canvas Redraw)**：
  使用內部原生的 `capRefreshCurrentWindow`，避免調用全域重繪指令（如 `View::Redraw`）導致鍵盤焦點被 Capture 主面板搶奪中斷。

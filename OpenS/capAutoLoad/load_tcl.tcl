# 作者 startgo (startgo@yia.app)
# 授權預設 GPLv3
# 2026-10-12 v5.2.0

# 1. 載入主功能腳本
if { [file exists "O:/Cadence/SPB_16.6/tools/capture/tclscripts/OpenS/OpenS_Cap_NP.tcl"] } {
    source "O:/Cadence/SPB_16.6/tools/capture/tclscripts/OpenS/OpenS_Cap_NP.tcl"
}

# 2. 定義 Enabler
proc OpenS_Cap_True { args } {
    return true
}

# 3. 定義無注入風險的執行回呼
proc OpenS_Run_NP { args } {
    if { [catch { ::np } err] } {
        puts "OpenS Error: $err"
    }
}

proc OpenS_Run_UNNP { args } {
    if { [catch { ::unnp } err] } {
        puts "OpenS Error: $err"
    }
}

# 4. 清除舊註冊
catch {
    UnregisterAction "Action_OpenS_NP"
    UnregisterAction "Action_OpenS_UNNP"
    UnregisterAction "Action_OpenS_NP_Enabler"
    UnregisterAction "Action_OpenS_UNNP_Enabler"
    UnregisterAction "Action_OpenS_NP_Menu"
    UnregisterAction "Action_OpenS_UNNP_Menu"
}

# 5. 註冊快捷鍵與注入選單
catch {
    RegisterAction "Action_OpenS_NP_Enabler"   "OpenS_Cap_True" "" "OpenS_Cap_True" ""
    RegisterAction "Action_OpenS_UNNP_Enabler" "OpenS_Cap_True" "" "OpenS_Cap_True" ""

    RegisterAction "Action_OpenS_NP_Menu"   "OpenS_Cap_True" "" "OpenS_Run_NP"   ""
    RegisterAction "Action_OpenS_UNNP_Menu" "OpenS_Cap_True" "" "OpenS_Run_UNNP" ""

    RegisterAction "Action_OpenS_NP"   "OpenS_Cap_True" "Shift+X" "OpenS_Run_NP"   "Schematic"
    RegisterAction "Action_OpenS_UNNP" "OpenS_Cap_True" "Shift+Z" "OpenS_Run_UNNP" "Schematic"

    InsertXMLMenu [list [list "Edit" "Item_OpenS_NP"]   "1" "EditRotate"    [list "action" "Set &NP"   "0" "Action_OpenS_NP_Menu"   "Action_OpenS_NP_Enabler"   "Shift+X" "" "" "Set Selected Part to NP"] ""]
    InsertXMLMenu [list [list "Edit" "Item_OpenS_UNNP"] "1" "Item_OpenS_NP" [list "action" "&Unset NP" "0" "Action_OpenS_UNNP_Menu" "Action_OpenS_UNNP_Enabler" "Shift+Z" "" "" "Unset Selected Part NP"] ""]
}

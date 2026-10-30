# 作者 startgo (startgo@yia.app)
# 授權預設 GPLv3
# 日期 2026-10-12
# 版本 v6.1.0

package require Tcl 8.4
catch {package require capDesignUtil}

namespace eval ::ToggleNP {
    # 色彩定義 (24: 深紅, 238: 深藍)
    variable COLOR_NP         24
    variable COLOR_NORMAL     238

    variable part_number_props [list \
        "PNUMBER" \
        "Part Number" \
        "PART_NUMBER" \
        "Part_Number" \
        "PARTNUMBER" \
        "PN" \
        "P/N" \
        "P_NUMBER" \
    ]

    variable ref_props [list \
        "Source Package" \
        "Part Reference" \
        "Part_Reference" \
        "Reference" \
    ]

    variable bom_ignore_prop  "BOM_IGNORE"
    variable bom_ignore_val   "V"
}

# 1. 取得屬性 (正確處理回傳值，確保一定讀得到)
proc ::ToggleNP::GetPropValue {pPartInst propName} {
    set res ""
    catch {
        set lName [DboTclHelper_sMakeCString $propName]
        set lVal  [DboTclHelper_sMakeCString ""]
        $pPartInst GetEffectivePropStringValue $lName $lVal
        set res [DboTclHelper_sGetConstCharPtr $lVal]
    }
    return $res
}

# 2. 寫入屬性
proc ::ToggleNP::SetPropValue {pPartInst propName propValue} {
    catch {
        set lName [DboTclHelper_sMakeCString $propName]
        set lVal  [DboTclHelper_sMakeCString $propValue]
        $pPartInst SetEffectivePropStringValue $lName $lVal
    }
}

# 3. 變更色彩 (安全防護：不手動 delete 避免野指標崩潰)
proc ::ToggleNP::SetDisplayPropColor {pPartInst propName colorVal} {
    catch {
        set lName [DboTclHelper_sMakeCString $propName]
        set lState [DboState]
        set lDispProp [$pPartInst GetDisplayProp $lName $lState]
        if {$lDispProp ne "" && $lDispProp ne "NULL"} {
            $lDispProp SetColor $colorVal
        }
    }
}

# 4. 零件單體操作邏輯
proc ::ToggleNP::ProcessPart {pPartInst action} {
    set curValue [::ToggleNP::GetPropValue $pPartInst "Value"]

    if {$action eq "set_np"} {
        # --- Value ---
        if {![string match "NP/*" $curValue]} {
            set newValue "NP/$curValue"
            ::ToggleNP::SetPropValue $pPartInst "Value" $newValue
        }
        ::ToggleNP::SetDisplayPropColor $pPartInst "Value" $::ToggleNP::COLOR_NP

        # --- Reference 顏色 ---
        foreach refKey $::ToggleNP::ref_props {
            ::ToggleNP::SetDisplayPropColor $pPartInst $refKey $::ToggleNP::COLOR_NP
        }

        # --- Part Number ---
        foreach pnKey $::ToggleNP::part_number_props {
            set curPN [::ToggleNP::GetPropValue $pPartInst $pnKey]
            if {$curPN ne ""} {
                if {![string match "\\**" $curPN]} {
                    ::ToggleNP::SetPropValue $pPartInst $pnKey "*$curPN"
                }
                break
            }
        }

        # --- BOM_IGNORE ---
        ::ToggleNP::SetPropValue $pPartInst $::ToggleNP::bom_ignore_prop $::ToggleNP::bom_ignore_val

    } else {
        # --- Value ---
        if {[string match "NP/*" $curValue]} {
            set newValue [string range $curValue 3 end]
            ::ToggleNP::SetPropValue $pPartInst "Value" $newValue
        }
        ::ToggleNP::SetDisplayPropColor $pPartInst "Value" $::ToggleNP::COLOR_NORMAL

        # --- Reference 顏色 ---
        foreach refKey $::ToggleNP::ref_props {
            ::ToggleNP::SetDisplayPropColor $pPartInst $refKey $::ToggleNP::COLOR_NORMAL
        }

        # --- Part Number ---
        foreach pnKey $::ToggleNP::part_number_props {
            set curPN [::ToggleNP::GetPropValue $pPartInst $pnKey]
            if {$curPN ne ""} {
                if {[string match "\\**" $curPN]} {
                    ::ToggleNP::SetPropValue $pPartInst $pnKey [string range $curPN 1 end]
                }
                break
            }
        }

        # --- BOM_IGNORE ---
        ::ToggleNP::SetPropValue $pPartInst $::ToggleNP::bom_ignore_prop ""
    }
    return 1
}

# 5. 批次處理
proc ::ToggleNP::ExecuteSelected {action} {
    set selList [GetSelectedObjects]
    if {[llength $selList] == 0} {
        return 0
    }

    foreach obj $selList {
        set objType 0
        catch {set objType [$obj GetObjectType]}
        if {$objType == 13 || $objType == 12} {
            ::ToggleNP::ProcessPart $obj $action
        }
    }

    # 輕量刷新當前原理圖視窗，不搶奪焦點
    catch {capRefreshCurrentWindow}
    return 0
}

interp alias {} np   {} ::ToggleNP::ExecuteSelected "set_np"
interp alias {} unnp {} ::ToggleNP::ExecuteSelected "remove_np"

catch {
    AddAccessoryMenu "Toggle NP/Set NP" "np" ""
    AddAccessoryMenu "Toggle NP/Unset NP" "unnp" ""
}

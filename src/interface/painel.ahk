#Requires AutoHotkey v2.0
; Painel de texto (tooltip no canto da janela do jogo) e orquestracao da interface.
; O quadrado colorido do centro esta em quadrado_central.ahk.

AtualizarTooltipsControle(connected := true) {
    static lastError := ""
    try {
        if !connected {
            AtualizarHoenn222CentralTooltip()
            if WinExist(GameWindow) {
                WinGetPos(&winX, &winY, , , GameWindow)
                CoordMode("ToolTip", "Screen")
                ToolTip("Controle Desconectado", winX + 210, winY)
            } else {
                ToolTip("Controle Desconectado", 210, 0)
            }
        } else if WinExist(GameWindow) {
            WinGetPos(&winX, &winY, , , GameWindow)
            CoordMode("ToolTip", "Screen")
            textoExibicao := StatusText
            if (ModoAtual == "Hoenn222") {
                textoExibicao := GetHoenn222Tooltip()
                textoCentral := GetHoenn222CentralTooltip(&corCentral)
                AtualizarHoenn222CentralTooltip(textoCentral, winX + PlayerOriginX + Hoenn222CenterOffsetX,
                    winY + PlayerOriginY + Hoenn222CenterOffsetY, corCentral)
            } else {
                AtualizarHoenn222CentralTooltip()
            }
            ToolTip(textoExibicao, winX + 210, winY + 30, 1)
        } else {
            AtualizarHoenn222CentralTooltip()
        }
        lastError := ""
    } catch as e {
        ; Registrar só a primeira ocorrência de uma falha persistente, não cada frame.
        errorId := e.What ":" e.Line ":" e.Message
        if (errorId != lastError) {
            lastError := errorId
            SwitchDebug("SWITCH_ERROR", "phase=tooltip", e)
        }
    }
}

GetHoenn222Tooltip() {
    global TimeAtual, Hoenn222_State, Hoenn222_ComboArmed, Hoenn222_SwitchArmed

    str := "HOENN 2-2-2 | TIME " TimeAtual "`n`n"

    if (Hoenn222_State == "WAITING_FIRST_COMBO") {
        str .= "Aguardando sincronizacao`n(execute 1 combo)`n"
    } else if (Hoenn222_State == "WAITING_TEAM_SWITCH") {
        str .= "TROCAR TIME`n`n"

        nextTeam := (TimeAtual >= 3) ? 1 : (TimeAtual + 1)
        str .= "Próx: TIME " nextTeam "`n"
    } else if (Hoenn222_State == "WAITING_COMBO") {
        str .= "COMBAR`n`n"
        str .= "Tank: " GetHoenn222TierText(TimeAtual, "tank") "`n"
        str .= "Sec:  " GetHoenn222TierText(TimeAtual, "second") "`n"
    }

    if (Hoenn222_SwitchArmed) {
        str .= "`nTROCA ARMADA`n"
    }
    if (Hoenn222_ComboArmed) {
        str .= "`nCOMBO ARMADO`n"
        ; Antecipacao segura: o macro avisa QUEM falta e o quanto o secundario
        ; ficaria atrasado, sem inventar cooldown nem estender a espera interna.
        if (Hoenn222_State == "WAITING_COMBO" && Hoenn222_CdOptimizerEnabled) {
            bloqueio := GetHoenn222ComboBloqueio(TimeAtual)
            if (bloqueio == "secundario") {
                str .= "secundario CD +" Round(Hoenn222SecondaryPendenteMs(TimeAtual, 0) / 1000, 1) "s`n"
            } else if (bloqueio == "tank") {
                str .= "tank em CD`n"
            } else if (bloqueio == "primeira_volta") {
                str .= "ritmo da 1a volta`n"
            }
        }
    }

    return str
}

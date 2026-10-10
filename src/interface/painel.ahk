#Requires AutoHotkey v2.0
; Painel de texto (tooltip no canto da janela do jogo) e orquestracao da interface.
; O quadrado colorido do centro esta em quadrado_central.ahk.

AtualizarInterface(connected := true) {
    static lastError := ""
    try {
        if !connected {
            DesenharQuadradoCentral()
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
            textoExibicao := TextoDeStatus
            if (ModoAtual == "Hoenn222") {
                textoExibicao := TextoDoPainel()
                textoCentral := TextoDoQuadradoCentral(&corCentral)
                DesenharQuadradoCentral(textoCentral, winX + PlayerOriginX + Hoenn222CenterOffsetX,
                    winY + PlayerOriginY + Hoenn222CenterOffsetY, corCentral)
            } else {
                DesenharQuadradoCentral()
            }
            ToolTip(textoExibicao, winX + 210, winY + 30, 1)
        } else {
            DesenharQuadradoCentral()
        }
        lastError := ""
    } catch as e {
        ; Registrar só a primeira ocorrência de uma falha persistente, não cada frame.
        errorId := e.What ":" e.Line ":" e.Message
        if (errorId != lastError) {
            lastError := errorId
            LogDiagnostico("SWITCH_ERROR", "phase=tooltip", e)
        }
    }
}

TextoDoPainel() {
    global TimeAtual, FaseAtual, ComboArmado, TrocaArmada

    str := "HOENN 2-2-2 | TIME " TimeAtual "`n`n"

    if (FaseAtual == "WAITING_FIRST_COMBO") {
        str .= "Aguardando sincronizacao`n(execute 1 combo)`n"
    } else if (FaseAtual == "WAITING_TEAM_SWITCH") {
        str .= "TROCAR TIME`n`n"

        nextTeam := (TimeAtual >= 3) ? 1 : (TimeAtual + 1)
        str .= "Próx: TIME " nextTeam "`n"
    } else if (FaseAtual == "WAITING_COMBO") {
        str .= "COMBAR`n`n"
        str .= "Tank: " RotuloDoTier(TimeAtual, "tank") "`n"
        str .= "Sec:  " RotuloDoTier(TimeAtual, "second") "`n"
    }

    if (TrocaArmada) {
        str .= "`nTROCA ARMADA`n"
    }
    if (ComboArmado) {
        str .= "`nCOMBO ARMADO`n"
        ; Antecipacao segura: o macro avisa QUEM falta e o quanto o secundario
        ; ficaria atrasado, sem inventar cooldown nem estender a espera interna.
        if (FaseAtual == "WAITING_COMBO" && Hoenn222_CdOptimizerEnabled) {
            bloqueio := QuemBloqueiaOCombo(TimeAtual)
            if (bloqueio == "secundario") {
                str .= "secundario CD +" Round(CooldownPendenteDoSecundarioMs(TimeAtual, 0) / 1000, 1) "s`n"
            } else if (bloqueio == "tank") {
                str .= "tank em CD`n"
            } else if (bloqueio == "primeira_volta") {
                str .= "ritmo da 1a volta`n"
            }
        }
    }

    return str
}

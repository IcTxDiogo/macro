#Requires AutoHotkey v2.0
; Painel de texto (tooltip no canto da janela do jogo) e orquestracao da interface.
; O quadrado colorido do centro esta em quadrado_central.ahk.

; Chamado a cada volta do laco. Nunca lanca excecao: falha de interface so vai para o log
; (uma vez por tipo de erro, nao a cada frame).
AtualizarInterface(controleConectado := true) {
    static ultimoErro := ""
    try {
        if !controleConectado {
            DesenharQuadradoCentral()
            if WinExist(GameWindow) {
                WinGetPos(&janelaX, &janelaY, , , GameWindow)
                CoordMode("ToolTip", "Screen")
                ToolTip("Controle Desconectado", janelaX + 210, janelaY)
            } else {
                ToolTip("Controle Desconectado", 210, 0)
            }
        } else if WinExist(GameWindow) {
            WinGetPos(&janelaX, &janelaY, , , GameWindow)
            CoordMode("ToolTip", "Screen")
            texto := TextoDeStatus
            if (ModoAtual == "Hoenn222") {
                texto := TextoDoPainel()
                textoCentral := TextoDoQuadradoCentral(&corCentral)
                DesenharQuadradoCentral(textoCentral, janelaX + PlayerOriginX + Hoenn222CenterOffsetX,
                    janelaY + PlayerOriginY + Hoenn222CenterOffsetY, corCentral)
            } else {
                DesenharQuadradoCentral()
            }
            ToolTip(texto, janelaX + 210, janelaY + 30, 1)
        } else {
            DesenharQuadradoCentral()
        }
        ultimoErro := ""
    } catch as e {
        idDoErro := e.What ":" e.Line ":" e.Message
        if (idDoErro != ultimoErro) {
            ultimoErro := idDoErro
            LogDiagnostico("SWITCH_ERROR", "phase=tooltip", e)
        }
    }
}

; Texto do painel no modo 2-2-2: fase atual, tiers do time e pedidos armados.
TextoDoPainel() {
    global TimeAtual, FaseAtual, ComboArmado, TrocaArmada

    texto := "HOENN 2-2-2 | TIME " TimeAtual "`n`n"

    if (FaseAtual == "WAITING_FIRST_COMBO") {
        texto .= "Aguardando sincronizacao`n(execute 1 combo)`n"
    } else if (FaseAtual == "WAITING_TEAM_SWITCH") {
        proximoTime := (TimeAtual >= 3) ? 1 : (TimeAtual + 1)
        texto .= "TROCAR TIME`n`nPróx: TIME " proximoTime "`n"
    } else if (FaseAtual == "WAITING_COMBO") {
        texto .= "COMBAR`n`n"
        texto .= "Tank: " RotuloDoTier(TimeAtual, "tank") "`n"
        texto .= "Sec:  " RotuloDoTier(TimeAtual, "second") "`n"
    }

    if (TrocaArmada)
        texto .= "`nTROCA ARMADA`n"
    if (ComboArmado) {
        texto .= "`nCOMBO ARMADO`n"
        ; Avisa QUEM falta e quanto o secundario atrasaria, sem inventar cooldown.
        if (FaseAtual == "WAITING_COMBO" && Hoenn222_CdOptimizerEnabled) {
            bloqueio := QuemBloqueiaOCombo(TimeAtual)
            if (bloqueio == "secundario") {
                texto .= "secundario CD +" Round(CooldownPendenteDoSecundarioMs(TimeAtual, 0) / 1000, 1) "s`n"
            } else if (bloqueio == "tank") {
                texto .= "tank em CD`n"
            } else if (bloqueio == "primeira_volta") {
                texto .= "ritmo da 1a volta`n"
            }
        }
    }

    return texto
}

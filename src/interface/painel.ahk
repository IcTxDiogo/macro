#Requires AutoHotkey v2.0
; Painel de texto (tooltip no canto da janela do jogo) e orquestracao da interface.
; O quadrado colorido do centro esta em quadrado_central.ahk.

; Chamado a cada volta do laco. Nunca lanca excecao: falha de interface so vai para o log
; (uma vez por tipo de erro, nao a cada frame).
AtualizarInterface(controleConectado := true) {
    static ultimoErro := ""
    try {
        janelaExiste := WinExist(GameWindow)
        if (janelaExiste && !WinActive(GameWindow)) {
            DesenharQuadradoCentral()
            DesenharPainel()
            return
        }
        if !controleConectado {
            DesenharQuadradoCentral()
            if janelaExiste {
                WinGetPos(&janelaX, &janelaY, , , GameWindow)
                DesenharPainel("Controle Desconectado", janelaX + 210, janelaY)
            } else {
                DesenharPainel("Controle Desconectado", 210, 0)
            }
        } else if janelaExiste {
            WinGetPos(&janelaX, &janelaY, , , GameWindow)
            texto := TextoDeStatus
            if (ModoAtual == "Hoenn222") {
                texto := TextoDoPainel()
                textoCentral := TextoDoQuadradoCentral(&corCentral)
                DesenharQuadradoCentral(textoCentral, janelaX + PlayerOriginX + Hoenn222CenterOffsetX,
                    janelaY + PlayerOriginY + Hoenn222CenterOffsetY, corCentral)
            } else {
                DesenharQuadradoCentral()
            }
            DesenharPainel(texto TextoDosProblemasDeConfig(), janelaX + 210, janelaY + 30)
        } else {
            DesenharQuadradoCentral()
            DesenharPainel()
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

; Mesmo principio do quadrado central: redesenhar so se texto/posicao mudarem.
; Ocultar invalida o cache; so confirmar o novo desenho depois de ToolTip funcionar.
DesenharPainel(texto := "", x := 0, y := 0) {
    static visivel := false, ultimoTexto := "", ultimoX := 0, ultimoY := 0
    if (texto == "") {
        if visivel
            ToolTip(, , , 1)
        visivel := false
        ultimoTexto := ""
        return
    }
    if (visivel && texto == ultimoTexto && x == ultimoX && y == ultimoY)
        return
    CoordMode("ToolTip", "Screen")
    ToolTip(texto, x, y, 1)
    visivel := true
    ultimoTexto := texto
    ultimoX := x
    ultimoY := y
}

; Texto do painel no modo 2-2-2: fase atual, tiers do time e pedidos armados.
TextoDoPainel() {
    global TimeAtual, FaseAtual, ComboArmado, TrocaArmada

    texto := "HOENN 2-2-2 | TIME " TimeAtual "`n`n"
    if (FaseAtual == "WAITING_FIRST_COMBO") {
        texto .= "Aguardando primeiro combo`n"
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
                ; Arredondamento so visual: o verde e os pedidos usam milissegundos reais.
                texto .= "secundario CD +" Ceil(CooldownPendenteDoSecundarioMs(TimeAtual, 0) / 1000) "s`n"
            } else if (bloqueio == "tank") {
                texto .= "tank em CD`n"
            } else if (bloqueio == "primeira_volta") {
                texto .= "ritmo da 1a volta`n"
            }
        }
    }

    return texto
}

; Problemas do config.ahk (ver nucleo\validacao_config.ahk), ate 3 linhas, fixos no painel.
TextoDosProblemasDeConfig() {
    global ProblemasDeConfig
    if (ProblemasDeConfig.Length == 0)
        return ""
    texto := "`n!! CONFIG !!`n"
    for problema in ProblemasDeConfig {
        if (A_Index > 3) {
            texto .= "... +" (ProblemasDeConfig.Length - 3) " (ver log)`n"
            break
        }
        texto .= problema "`n"
    }
    return texto
}

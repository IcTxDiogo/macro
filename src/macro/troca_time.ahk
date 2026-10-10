#Requires AutoHotkey v2.0
; Troca de time (2-2-2): validacao, envio da tecla, atualizacao do estado e estatisticas.

; Troca para o proximo time (1 -> 2 -> 3 -> 1). Devolve true se a tecla foi enviada.
; A troca nunca depende de calculo de tempo nem de interface: so validacao, envio e
; atualizacao do estado (essa parte e atomica).
TrocarDeTime() {
    global TimeAtual, TextoDeStatus, FaseAtual, InicioDaFaseTick, UltimaTrocaDeTimeTick
    global GameWindow, KeyPokestop, KeyFullDef

    criticoAnterior := A_IsCritical
    Critical("On")
    try {
        trocaTick := A_TickCount
        timeAnterior := TimeAtual
        LogDiagnostico("SWITCH_REQUESTED", "from=" timeAnterior " total=3 state=" FaseAtual)
        if (timeAnterior < 1 || timeAnterior > 3) {
            LogDiagnostico("SWITCH_REJECTED", "reason=invalid_team total=3 from=" timeAnterior)
            return false
        }
        ; Debounce: duas trocas em menos de 1 s seriam um clique duplicado.
        if (UltimaTrocaDeTimeTick > 0 && trocaTick - UltimaTrocaDeTimeTick < 1000) {
            LogDiagnostico("SWITCH_REJECTED", "reason=debounce elapsed_ms=" (trocaTick - UltimaTrocaDeTimeTick))
            return false
        }
        proximoTime := (timeAnterior >= 3) ? 1 : timeAnterior + 1
        teclaDoTime := proximoTime * 2 - 1   ; {1}, {3}, {5}: o tank de cada time

        ; A janela pode sumir entre a validacao e o ControlSend: tratar os dois casos.
        if !WinExist(GameWindow) {
            LogDiagnostico("SWITCH_REJECTED", "reason=no_window window=" GameWindow)
            return false
        }
        LogDiagnostico("SWITCH_COMMAND_BEGIN", "from=" timeAnterior " to=" proximoTime " key=" teclaDoTime " window=" GameWindow)
        try {
            ControlSend("{" teclaDoTime "}", , GameWindow)
        } catch as e {
            LogDiagnostico("SWITCH_COMMAND_END", "result=failed to=" proximoTime " key=" teclaDoTime)
            LogDiagnostico("SWITCH_ERROR", "phase=primary_command", e)
            LogDiagnostico("SWITCH_REJECTED", "reason=send_failed")
            return false
        }
        LogDiagnostico("SWITCH_COMMAND_END", "result=requested_only to=" proximoTime " key=" teclaDoTime)

        ; Representa o envio solicitado, NAO uma confirmacao visual de entrada no jogo.
        TimeAtual := proximoTime
        UltimaTrocaDeTimeTick := trocaTick
        FaseAtual := "WAITING_COMBO"
        InicioDaFaseTick := trocaTick
        RegistrarTrocaDeTime(timeAnterior, proximoTime, trocaTick)
        LogDiagnostico("SWITCH_STATE_UPDATED", "requested_team=" TimeAtual " visual_confirmation=unknown")
    } finally {
        Critical(criticoAnterior)
    }
    SalvarEstado()

    ; Sequencia original: uma falha auxiliar nao cancela as acoes seguintes.
    for tecla in [KeyPokestop, KeyFullDef] {
        try {
            ControlSend("{" tecla "}", , GameWindow)
        } catch as e {
            LogDiagnostico("SWITCH_ERROR", "phase=post_command key=" tecla, e)
        }
    }
    ; O pedido pendente pertencia ao time que acabou de sair.
    CancelarPedidosArmados("team_switch")
    try {
        TextoDeStatus := "Modo: Hoenn 2-2-2 - Time: " TimeAtual
        RegistrarTrocaNoLog(proximoTime, "2-2-2")
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=team_logger", e)
    }
    return true
}

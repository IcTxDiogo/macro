#Requires AutoHotkey v2.0
; Troca de time (validacao, envio, estado e estatisticas).

TrocarDeTime(totalTimes := 2) {
    global TimeAtual, TankDoTime2Modo33, TextoDeStatus
    global GameWindow, KeyPokestop, KeyFullDef
    global FaseAtual, InicioDaFaseTick, UltimaTrocaDeTimeTick
    global ComboArmado, TimeDoComboArmado

    ; Apenas validação/envio/commit são atômicos. A interface não participa da decisão.
    previousCritical := A_IsCritical
    Critical("On")
    try {
        switchTick := A_TickCount
        previousTeam := TimeAtual
        LogDiagnostico("SWITCH_REQUESTED", "from=" previousTeam " total=" totalTimes " state=" FaseAtual)
        if ((totalTimes != 2 && totalTimes != 3) || previousTeam < 1 || previousTeam > 3) {
            LogDiagnostico("SWITCH_REJECTED", "reason=invalid_team total=" totalTimes " from=" previousTeam)
            return false
        }
        if (totalTimes == 3 && UltimaTrocaDeTimeTick > 0
            && switchTick - UltimaTrocaDeTimeTick < 1000) {
            LogDiagnostico("SWITCH_REJECTED", "reason=debounce elapsed_ms=" (switchTick - UltimaTrocaDeTimeTick))
            return false
        }
        nextTeam := (previousTeam >= totalTimes) ? 1 : previousTeam + 1
        nextKey := (totalTimes == 3) ? (nextTeam * 2 - 1) : ((nextTeam == 1) ? 1 : TankDoTime2Modo33)
        previousSwitchTick := UltimaTrocaDeTimeTick
        previousState := FaseAtual
        previousStateStartTick := InicioDaFaseTick

        ; A janela pode desaparecer entre a validação e ControlSend: tratar ambos os casos.
        if !WinExist(GameWindow) {
            LogDiagnostico("SWITCH_REJECTED", "reason=no_window window=" GameWindow)
            return false
        }
        LogDiagnostico("SWITCH_COMMAND_BEGIN", "from=" previousTeam " to=" nextTeam " key=" nextKey " window=" GameWindow)
        try {
            ControlSend("{" nextKey "}", , GameWindow)
        } catch as e {
            LogDiagnostico("SWITCH_COMMAND_END", "result=failed to=" nextTeam " key=" nextKey)
            LogDiagnostico("SWITCH_ERROR", "phase=primary_command", e)
            LogDiagnostico("SWITCH_REJECTED", "reason=send_failed")
            return false
        }
        LogDiagnostico("SWITCH_COMMAND_END", "result=requested_only to=" nextTeam " key=" nextKey)

        ; Representa o envio solicitado, NÃO uma confirmação visual de entrada no jogo.
        TimeAtual := nextTeam
        if (totalTimes == 3) {
            UltimaTrocaDeTimeTick := switchTick
            FaseAtual := "WAITING_COMBO"
            InicioDaFaseTick := switchTick
            ; A dupla anterior inteira volta para a Ball; so o tank da dupla nova
            ; sai, e LatencyMs depois do comando enviado.
            RegistrarTrocaDeTime(previousTeam, nextTeam, switchTick)
        }
        LogDiagnostico("SWITCH_STATE_UPDATED", "requested_team=" TimeAtual " visual_confirmation=unknown")
    } finally {
        Critical(previousCritical)
    }

    ; Preservar a sequência original; uma falha auxiliar não cancela as ações seguintes.
    for key in [KeyPokestop, KeyFullDef] {
        try {
            ControlSend("{" key "}", , GameWindow)
        } catch as e {
            LogDiagnostico("SWITCH_ERROR", "phase=post_command key=" key, e)
        }
    }
    if (totalTimes == 3) {
        ; O pedido pendente pertencia ao time que acabou de sair.
        CancelarPedidosArmados("team_switch")
        RegistrarEstatisticasDaTroca(nextTeam, previousTeam, switchTick, previousSwitchTick)
    }
    try {
        TextoDeStatus := "Modo: Hoenn " ((totalTimes == 3) ? "2-2-2" : "3-3") " - Time: " TimeAtual
        RegistrarTrocaNoLog(nextTeam, (totalTimes == 3) ? "2-2-2" : "3-3")
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=team_logger", e)
    }
    return true
}

RegistrarEstatisticasDaTroca(nextTeam, previousTeam, switchTick, previousSwitchTick) {
    global DuracaoDoTime, UltimoUsoDoTimeTick, IntervaloEntreUsosDoTime
    global EntradaDoTankTick

    ; A divida global saiu: cada Pokemon carrega seu proprio acumulador de CD e o
    ; alvo de cada fase e rederivado do estado real. Aqui so ficam as estatisticas.
    try {
        if (previousSwitchTick > 0) {
            DuracaoDoTime[previousTeam] := switchTick - previousSwitchTick
        }
        if (UltimoUsoDoTimeTick[nextTeam] > 0) {
            IntervaloEntreUsosDoTime[nextTeam] := switchTick - UltimoUsoDoTimeTick[nextTeam]
        }
        UltimoUsoDoTimeTick[nextTeam] := switchTick
        EntradaDoTankTick[nextTeam] := switchTick
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=timer_statistics", e)
    }
}

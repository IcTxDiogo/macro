#Requires AutoHotkey v2.0
; Troca de time (validacao, envio, estado e estatisticas).

TrocarTimeHoenn(totalTimes := 2) {
    global TimeAtual, TankAtualTime2_33, StatusText
    global GameWindow, KeyPokestop, KeyFullDef
    global Hoenn222_State, Hoenn222_StateStartTick, Hoenn222_LastTeamSwitchTick
    global Hoenn222_ComboArmed, Hoenn222_ComboArmedTeam

    ; Apenas validação/envio/commit são atômicos. A interface não participa da decisão.
    previousCritical := A_IsCritical
    Critical("On")
    try {
        switchTick := A_TickCount
        previousTeam := TimeAtual
        SwitchDebug("SWITCH_REQUESTED", "from=" previousTeam " total=" totalTimes " state=" Hoenn222_State)
        if ((totalTimes != 2 && totalTimes != 3) || previousTeam < 1 || previousTeam > 3) {
            SwitchDebug("SWITCH_REJECTED", "reason=invalid_team total=" totalTimes " from=" previousTeam)
            return false
        }
        if (totalTimes == 3 && Hoenn222_LastTeamSwitchTick > 0
            && switchTick - Hoenn222_LastTeamSwitchTick < 1000) {
            SwitchDebug("SWITCH_REJECTED", "reason=debounce elapsed_ms=" (switchTick - Hoenn222_LastTeamSwitchTick))
            return false
        }
        nextTeam := (previousTeam >= totalTimes) ? 1 : previousTeam + 1
        nextKey := (totalTimes == 3) ? (nextTeam * 2 - 1) : ((nextTeam == 1) ? 1 : TankAtualTime2_33)
        previousSwitchTick := Hoenn222_LastTeamSwitchTick
        previousState := Hoenn222_State
        previousStateStartTick := Hoenn222_StateStartTick

        ; A janela pode desaparecer entre a validação e ControlSend: tratar ambos os casos.
        if !WinExist(GameWindow) {
            SwitchDebug("SWITCH_REJECTED", "reason=no_window window=" GameWindow)
            return false
        }
        SwitchDebug("SWITCH_COMMAND_BEGIN", "from=" previousTeam " to=" nextTeam " key=" nextKey " window=" GameWindow)
        try {
            ControlSend("{" nextKey "}", , GameWindow)
        } catch as e {
            SwitchDebug("SWITCH_COMMAND_END", "result=failed to=" nextTeam " key=" nextKey)
            SwitchDebug("SWITCH_ERROR", "phase=primary_command", e)
            SwitchDebug("SWITCH_REJECTED", "reason=send_failed")
            return false
        }
        SwitchDebug("SWITCH_COMMAND_END", "result=requested_only to=" nextTeam " key=" nextKey)

        ; Representa o envio solicitado, NÃO uma confirmação visual de entrada no jogo.
        TimeAtual := nextTeam
        if (totalTimes == 3) {
            Hoenn222_LastTeamSwitchTick := switchTick
            Hoenn222_State := "WAITING_COMBO"
            Hoenn222_StateStartTick := switchTick
            ; A dupla anterior inteira volta para a Ball; so o tank da dupla nova
            ; sai, e LevancyMs depois do comando enviado.
            Hoenn222CdTrocaTime(previousTeam, nextTeam, switchTick)
        }
        SwitchDebug("SWITCH_STATE_UPDATED", "requested_team=" TimeAtual " visual_confirmation=unknown")
    } finally {
        Critical(previousCritical)
    }

    ; Preservar a sequência original; uma falha auxiliar não cancela as ações seguintes.
    for key in [KeyPokestop, KeyFullDef] {
        try {
            ControlSend("{" key "}", , GameWindow)
        } catch as e {
            SwitchDebug("SWITCH_ERROR", "phase=post_command key=" key, e)
        }
    }
    if (totalTimes == 3) {
        ; O pedido pendente pertencia ao time que acabou de sair.
        CancelarComboArmadoHoenn222("team_switch")
        AtualizarCronometroAposTroca(nextTeam, previousTeam, switchTick, previousSwitchTick)
    }
    try {
        StatusText := "Modo: Hoenn " ((totalTimes == 3) ? "2-2-2" : "3-3") " - Time: " TimeAtual
        LogTeamSwitch(nextTeam, (totalTimes == 3) ? "2-2-2" : "3-3")
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=team_logger", e)
    }
    return true
}

AtualizarCronometroAposTroca(nextTeam, previousTeam, switchTick, previousSwitchTick) {
    global Hoenn222_TeamDuration, Hoenn222_TeamLastUsageTick, Hoenn222_TeamUsageInterval
    global Hoenn222_TankEnterTick

    ; A divida global saiu: cada Pokemon carrega seu proprio acumulador de CD e o
    ; alvo de cada fase e rederivado do estado real. Aqui so ficam as estatisticas.
    try {
        if (previousSwitchTick > 0) {
            Hoenn222_TeamDuration[previousTeam] := switchTick - previousSwitchTick
        }
        if (Hoenn222_TeamLastUsageTick[nextTeam] > 0) {
            Hoenn222_TeamUsageInterval[nextTeam] := switchTick - Hoenn222_TeamLastUsageTick[nextTeam]
        }
        Hoenn222_TeamLastUsageTick[nextTeam] := switchTick
        Hoenn222_TankEnterTick[nextTeam] := switchTick
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=timer_statistics", e)
    }
}

#Requires AutoHotkey v2.0
#Include core_actions.ahk
#Include logger.ahk

global TimeAtual := 1          ; Time solicitado (1, 2 ou 3); entrada visual não confirmada
global isRodizioAtivo := false ; Trava de segurança
global TankAtualTime2_33 := 4  ; Específico para o modo 3-3
global StatusText

; --- VARIÁVEIS DO CRONÔMETRO HOENN 2-2-2 ---
global Hoenn222_State := "WAITING_FIRST_COMBO"
global Hoenn222_StateStartTick := 0
global Hoenn222_ExecutionId := 0
global Hoenn222_DebtMs := 0

global Hoenn222_LastTeamSwitchTick := 0
global Hoenn222_LastComboStartTick := 0
global Hoenn222_P2CallTick := 0

global Hoenn222_TankEnterTick := Map(1, 0, 2, 0, 3, 0)
global Hoenn222_P2EnterTick := Map(1, 0, 2, 0, 3, 0)
global Hoenn222_TeamDuration := Map(1, 0, 2, 0, 3, 0)
global Hoenn222_TeamUsageInterval := Map(1, 0, 2, 0, 3, 0)
global Hoenn222_TeamLastUsageTick := Map(1, 0, 2, 0, 3, 0)

; --- LÓGICA DE TROCA DE TIME (DINÂMICA) ---

TrocarTimeHoenn(totalTimes := 2) {
    global TimeAtual, TankAtualTime2_33, StatusText
    global GameWindow, KeyPokestop, KeyFullDef
    global Hoenn222_State, Hoenn222_StateStartTick, Hoenn222_LastTeamSwitchTick, Hoenn222_DebtMs

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
        previousDebt := Hoenn222_DebtMs

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
        AtualizarCronometroAposTroca(nextTeam, previousTeam, switchTick, previousSwitchTick,
            previousState, previousStateStartTick, previousDebt)
    }
    try {
        StatusText := "Modo: Hoenn " ((totalTimes == 3) ? "2-2-2" : "3-3") " - Time: " TimeAtual
        LogTeamSwitch(nextTeam, (totalTimes == 3) ? "2-2-2" : "3-3")
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=team_logger", e)
    }
    return true
}

AtualizarCronometroAposTroca(nextTeam, previousTeam, switchTick, previousSwitchTick,
    previousState, previousStateStartTick, previousDebt) {
    global Hoenn222_TeamDuration, Hoenn222_TeamLastUsageTick, Hoenn222_TeamUsageInterval
    global Hoenn222_TankEnterTick, Hoenn222_DebtMs

    ; Dívida e estatísticas são independentes; preservar a dívida anterior se o cálculo falhar.
    try {
        if (previousState == "WAITING_TEAM_SWITCH" || previousState == "WAITING_COMBO") {
            targetMs := GetHoenn222BaseTargetMs(previousState, previousTeam) + previousDebt
            Hoenn222_DebtMs := Max(0, targetMs - (switchTick - previousStateStartTick))
        }
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=debt", e)
    }
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

; --- MODO 3-3 (O QUE VOCÊ JÁ TINHA) ---

ComboComplexoHoenn33() {
    global TimeAtual, isRodizioAtivo, TankAtualTime2_33

    if (isRodizioAtivo) {
        return
    }
    isRodizioAtivo := true

    if (TimeAtual == 1) {
        SetTimer(() => ExecutarRodizio33(1, 2, 3), -1)
    } else {
        if (TankAtualTime2_33 == 4) {
            SetTimer(() => ExecutarRodizio33(4, 5, 6), -1)
        } else {
            SetTimer(() => ExecutarRodizio33(5, 4, 6), -1)
        }
    }
}

ExecutarRodizio33(p1, p2, p3) {
    global isRodizioAtivo, TimeAtual, TankAtualTime2_33
    ; isRodizioAtivo já ativado na função pai

    LogComboStart(TimeAtual, "3-3")

    ComboSimples()
    Sleep(SleepAfterCombo)

    ControlSend("{" p2 "}", , GameWindow)
    Sleep(SleepAfterSwitch)
    ComboSimples()
    Sleep(SleepAfterSecondCombo)

    ControlSend("{" p3 "}", , GameWindow)
    Sleep(SleepAfterSwitch)
    ComboSimples()

    if (TimeAtual == 2) {
        TankAtualTime2_33 := (TankAtualTime2_33 == 4) ? 5 : 4
    }

    isRodizioAtivo := false
}

; --- MODO 2-2-2 (NOVO MODO) ---

ComboComplexoHoenn222() {
    global TimeAtual, isRodizioAtivo, Hoenn222_ExecutionId

    if (isRodizioAtivo) {
        return
    }
    isRodizioAtivo := true

    timeOriginal := TimeAtual
    execIdOriginal := Hoenn222_ExecutionId

    if (timeOriginal == 1) {
        SetTimer(() => ExecutarRodizio222(1, 2, timeOriginal, execIdOriginal), -1)
    } else if (timeOriginal == 2) {
        SetTimer(() => ExecutarRodizio222(3, 4, timeOriginal, execIdOriginal), -1)
    } else if (timeOriginal == 3) {
        SetTimer(() => ExecutarRodizio222(5, 6, timeOriginal, execIdOriginal), -1)
    }
}

ExecutarRodizio222(p1, p2, timeOriginal, execIdOriginal) {
    global isRodizioAtivo, TimeAtual, comboMrMime, ModoAtual
    global Hoenn222_State, Hoenn222_StateStartTick, Hoenn222_LastComboStartTick, Hoenn222_P2CallTick
    global Hoenn222_P2EnterTick, Hoenn222_ExecutionId, Hoenn222_DebtMs

    ; isRodizioAtivo já ativado na função pai

    ; Se a execução foi invalidada por F8 ou o time mudou no intervalo de agendamento do SetTimer
    if (timeOriginal != TimeAtual || ModoAtual != "Hoenn222" || execIdOriginal != Hoenn222_ExecutionId) {
        isRodizioAtivo := false
        return
    }

    timeDaExecucao := timeOriginal
    Hoenn222_ExecutionId++
    myExecId := Hoenn222_ExecutionId

    ; Calcula dívida do estado anterior
    if (Hoenn222_State == "WAITING_COMBO") {
        actualElapsedMs := A_TickCount - Hoenn222_StateStartTick
        baseTargetMs := GetHoenn222BaseTargetMs(Hoenn222_State, timeDaExecucao)
        effectiveTargetMs := baseTargetMs + Hoenn222_DebtMs
        Hoenn222_DebtMs := Max(0, effectiveTargetMs - actualElapsedMs)
    }

    Hoenn222_State := "WAITING_TEAM_SWITCH"
    Hoenn222_StateStartTick := A_TickCount
    Hoenn222_LastComboStartTick := A_TickCount
    Hoenn222_P2CallTick := 0

    LogComboStart(timeDaExecucao, "2-2-2")

    try {
        ComboSimples() ; Bate com o p1 (que já está fora)
        Sleep(SleepAfterTankCombo)

        ; Se o time ou modo mudou durante o sleep do tank, cancela o resto da invocação
        if (timeDaExecucao != TimeAtual || ModoAtual != "Hoenn222") {
            return
        }

        ; Atualiza timer do P2 se ainda for a mesma execução
        if (Hoenn222_ExecutionId == myExecId) {
            Hoenn222_P2CallTick := A_TickCount
            Hoenn222_P2EnterTick[timeDaExecucao] := A_TickCount
        }

        ControlSend("{" p2 "}", , GameWindow) ; Chama p2
        Sleep(SleepAfterSwitch)

        ; Verificação extra antes do P2 bater (evita enviar skill para time trocado após chamar P2)
        if (timeDaExecucao != TimeAtual || ModoAtual != "Hoenn222") {
            return
        }

        ComboSimples()

        Sleep(SleepAfterCombo)
    } finally {
        isRodizioAtivo := false
    }
}

GetHoenn222BaseTargetMs(state, timeIndex) {
    if (state == "WAITING_COMBO") {
        return (timeIndex == 1) ? 15000 : ((timeIndex == 2) ? 16000 : 15500)
    } else if (state == "WAITING_TEAM_SWITCH") {
        return (timeIndex == 1) ? 9500 : 11500
    }
    return 0
}

#Requires AutoHotkey v2.0
; Combos dos modos 3-3 e 2-2-2 (rodizio de skills).

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

ComboComplexoHoenn222(origem := "manual") {
    global TimeAtual, isRodizioAtivo, Hoenn222_ExecutionId
    global Hoenn222_ComboArmed, Hoenn222_ComboArmedTeam

    ; Decisao atomica: o botao e a varredura do contador nunca passam juntos pelo
    ; bloqueio, e a trava so e armada quando existe um time valido.
    previousCritical := A_IsCritical
    Critical("On")
    try {
        if (isRodizioAtivo || TimeAtual < 1 || TimeAtual > 3) {
            return
        }
        isRodizioAtivo := true

        ; O combo consome o pedido: nada fica pendente durante a execucao.
        Hoenn222_ComboArmed := false
        Hoenn222_ComboArmedTeam := 0

        timeOriginal := TimeAtual
        execIdOriginal := Hoenn222_ExecutionId
        p1 := (timeOriginal == 1) ? 1 : ((timeOriginal == 2) ? 3 : 5)
        p2 := (timeOriginal == 1) ? 2 : ((timeOriginal == 2) ? 4 : 6)
        SetTimer(() => ExecutarRodizio222(p1, p2, timeOriginal, execIdOriginal, origem), -1)
    } finally {
        Critical(previousCritical)
    }
}

ExecutarRodizio222(p1, p2, timeOriginal, execIdOriginal, origem := "manual") {
    global isRodizioAtivo, TimeAtual, comboMrMime, ModoAtual
    global Hoenn222_State, Hoenn222_StateStartTick, Hoenn222_LastComboStartTick, Hoenn222_P2CallTick
    global Hoenn222_P2EnterTick, Hoenn222_ExecutionId

    ; isRodizioAtivo já ativado na função pai

    ; Se a execução foi invalidada por F8 ou o time mudou no intervalo de agendamento do SetTimer
    if (timeOriginal != TimeAtual || ModoAtual != "Hoenn222" || execIdOriginal != Hoenn222_ExecutionId) {
        isRodizioAtivo := false
        return
    }

    timeDaExecucao := timeOriginal
    Hoenn222_ExecutionId++
    myExecId := Hoenn222_ExecutionId

    Hoenn222_State := "WAITING_TEAM_SWITCH"
    Hoenn222_StateStartTick := A_TickCount
    Hoenn222_LastComboStartTick := A_TickCount
    Hoenn222_P2CallTick := 0

    LogComboStart(timeDaExecucao, "2-2-2", origem)

    try {
        ; O registro do cast vem antes do envio: se o ControlSend falhar, o CD fica
        ; carregado, que e o lado conservador. Contagem e envio nunca divergem.
        Hoenn222CdRegistrarCast(timeDaExecucao)
        ComboSimples() ; Bate com o p1 (que já está fora)
        Sleep(SleepAfterTankCombo) ; animação do jogo: valor original, nunca alterado

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
        Hoenn222CdRegistrarChamada(timeDaExecucao)
        ; Intervalo interno original. Se o CD do secundário não couber aqui, o
        ; macro não estende a espera: ele avisou antes, no verde do combo.
        Sleep(SleepAfterSwitch)

        ; Verificação extra antes do P2 bater (evita enviar skill para time trocado após chamar P2)
        if (timeDaExecucao != TimeAtual || ModoAtual != "Hoenn222") {
            return
        }

        Hoenn222CdRegistrarCast(timeDaExecucao, true)
        ComboSimples()

        Sleep(SleepAfterCombo)
    } finally {
        isRodizioAtivo := false
    }
}

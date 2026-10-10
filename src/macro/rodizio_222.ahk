#Requires AutoHotkey v2.0
; Rodizio do modo Hoenn 2-2-2: 3 duplas (tank + secundario) com cooldown por Pokemon.
; O QUE vem do tempo (quando liberar) esta em src\tempo; aqui so a sequencia de teclas.

IniciarRodizio222(origem := "manual") {
    global TimeAtual, RodizioAtivo, IdDaExecucao
    global ComboArmado, TimeDoComboArmado

    ; Decisao atomica: o botao e a varredura do contador nunca passam juntos pelo
    ; bloqueio, e a trava so e armada quando existe um time valido.
    previousCritical := A_IsCritical
    Critical("On")
    try {
        if (RodizioAtivo || TimeAtual < 1 || TimeAtual > 3) {
            return
        }
        RodizioAtivo := true

        ; O combo consome o pedido: nada fica pendente durante a execucao.
        ComboArmado := false
        TimeDoComboArmado := 0

        timeOriginal := TimeAtual
        execIdOriginal := IdDaExecucao
        p1 := (timeOriginal == 1) ? 1 : ((timeOriginal == 2) ? 3 : 5)
        p2 := (timeOriginal == 1) ? 2 : ((timeOriginal == 2) ? 4 : 6)
        SetTimer(() => ExecutarRodizio222(p1, p2, timeOriginal, execIdOriginal, origem), -1)
    } finally {
        Critical(previousCritical)
    }
}

ExecutarRodizio222(p1, p2, timeOriginal, execIdOriginal, origem := "manual") {
    global RodizioAtivo, TimeAtual, ModoAtual
    global FaseAtual, InicioDaFaseTick, UltimoComboTick, ChamadaDoSecundarioTick
    global EntradaDoSecundarioTick, IdDaExecucao

    ; RodizioAtivo já ativado na função pai

    ; Se a execução foi invalidada por F8 ou o time mudou no intervalo de agendamento do SetTimer
    if (timeOriginal != TimeAtual || ModoAtual != "Hoenn222" || execIdOriginal != IdDaExecucao) {
        RodizioAtivo := false
        return
    }

    timeDaExecucao := timeOriginal
    IdDaExecucao++
    myExecId := IdDaExecucao

    FaseAtual := "WAITING_TEAM_SWITCH"
    InicioDaFaseTick := A_TickCount
    UltimoComboTick := A_TickCount
    ChamadaDoSecundarioTick := 0

    RegistrarInicioDoCombo(timeDaExecucao, "2-2-2", origem)

    try {
        ; O registro do cast vem antes do envio: se o ControlSend falhar, o CD fica
        ; carregado, que e o lado conservador. Contagem e envio nunca divergem.
        RegistrarCast(timeDaExecucao)
        ComboSimples() ; Bate com o p1 (que já está fora)
        Sleep(SleepAfterTankCombo) ; animação do jogo: valor original, nunca alterado

        ; Se o time ou modo mudou durante o sleep do tank, cancela o resto da invocação
        if (timeDaExecucao != TimeAtual || ModoAtual != "Hoenn222") {
            return
        }

        ; Atualiza timer do P2 se ainda for a mesma execução
        if (IdDaExecucao == myExecId) {
            ChamadaDoSecundarioTick := A_TickCount
            EntradaDoSecundarioTick[timeDaExecucao] := A_TickCount
        }

        ControlSend("{" p2 "}", , GameWindow) ; Chama p2
        RegistrarChamadaDoSecundario(timeDaExecucao)
        ; Intervalo interno original. Se o CD do secundário não couber aqui, o
        ; macro não estende a espera: ele avisou antes, no verde do combo.
        Sleep(SleepAfterSwitch)

        ; Verificação extra antes do P2 bater (evita enviar skill para time trocado após chamar P2)
        if (timeDaExecucao != TimeAtual || ModoAtual != "Hoenn222") {
            return
        }

        RegistrarCast(timeDaExecucao, true)
        ComboSimples()

        Sleep(SleepAfterCombo)
    } finally {
        RodizioAtivo := false
    }
}

#Requires AutoHotkey v2.0
; Rodizio do modo Hoenn 2-2-2: cada time e um tank + um secundario, com cooldown por Pokemon.
; QUANDO liberar vem de src\tempo; aqui so a sequencia de teclas e o registro no cooldown.

; Valida e agenda o rodizio do time atual. A decisao e atomica (Critical): o clique e a
; varredura do pedido armado nunca passam juntos, e a trava so e armada com time valido.
IniciarRodizio222(origem := "manual", timeEsperado := 0, idEsperado := -1) {
    global TimeAtual, RodizioAtivo, IdDaExecucao, ComboArmado, TimeDoComboArmado

    criticoAnterior := A_IsCritical
    Critical("On")
    try {
        ; Validar o pedido antigo sob a mesma trava que inicia a execucao.
        if (origem == "antecipado" && (!ComboArmado || TimeDoComboArmado != timeEsperado
            || TimeAtual != timeEsperado || IdDaExecucao != idEsperado || ModoAtual != "Hoenn222"))
            return
        if (RodizioAtivo || TimeAtual < 1 || TimeAtual > 3)
            return
        RodizioAtivo := true

        ; O combo consome o pedido: nada fica pendente durante a execucao.
        ComboArmado := false
        TimeDoComboArmado := 0

        timeDoRodizio := TimeAtual
        idDoRodizio := IdDaExecucao
        ; Teclas do jogo: time 1 = {1}/{2}, time 2 = {3}/{4}, time 3 = {5}/{6}.
        teclaDoTank := timeDoRodizio * 2 - 1
        teclaDoSecundario := timeDoRodizio * 2
        SetTimer(() => ExecutarRodizio222(teclaDoTank, teclaDoSecundario, timeDoRodizio, idDoRodizio, origem), -1)
    } finally {
        Critical(criticoAnterior)
    }
}

; Sequencia do rodizio: cast do tank, chamada do secundario e cast do secundario. Os
; intervalos (SleepAfter*) sao animacao do jogo e nunca sao alterados pelo otimizador.
ExecutarRodizio222(teclaDoTank, teclaDoSecundario, timeDoRodizio, idDoRodizio, origem := "manual") {
    global RodizioAtivo, TimeAtual, ModoAtual, GameWindow
    global FaseAtual, InicioDaFaseTick, IdDaExecucao

    ; Invalidado por F8, troca de time ou de modo entre o agendamento e a execucao.
    if (timeDoRodizio != TimeAtual || ModoAtual != "Hoenn222" || idDoRodizio != IdDaExecucao) {
        RodizioAtivo := false
        return
    }

    idDaSequencia := ++IdDaExecucao
    contextoValido := () => RodizioAindaValido(timeDoRodizio, idDaSequencia)

    FaseAtual := "WAITING_TEAM_SWITCH"
    InicioDaFaseTick := A_TickCount

    RegistrarInicioDoCombo(timeDoRodizio, "2-2-2", origem)

    try {
        ; O registro estimado vem antes do envio: se o ControlSend falhar, o modelo ainda
        ; inicia o CD (lado conservador). Nao e confirmacao de execucao pelo servidor.
        RegistrarCast(timeDoRodizio)
        preparoTankTick := A_TickCount
        if !ComboSimples(contextoValido)
            return
        LogDiagnostico("COMBO_PREPARO", "time=" timeDoRodizio " papel=tank inicio_tick=" preparoTankTick " fim_tick=" A_TickCount " duracao_ms=" (A_TickCount - preparoTankTick) " visual_confirmation=unknown")
        Sleep(SleepAfterTankCombo)

        if !contextoValido.Call()
            return


        ControlSend("{" teclaDoSecundario "}", , GameWindow)
        RegistrarChamadaDoSecundario(timeDoRodizio)
        ; Se o CD do secundario nao couber aqui, o macro nao estende a espera: o verde do
        ; combo ja avisou antes.
        Sleep(SleepAfterSwitch)

        ; Nao bater com o secundario se o time mudou durante a espera.
        if !contextoValido.Call()
            return

        RegistrarCast(timeDoRodizio, true)
        preparoSecTick := A_TickCount
        if !ComboSimples(contextoValido)
            return
        LogDiagnostico("COMBO_PREPARO", "time=" timeDoRodizio " papel=sec inicio_tick=" preparoSecTick " fim_tick=" A_TickCount " duracao_ms=" (A_TickCount - preparoSecTick) " visual_confirmation=unknown")
        Sleep(SleepAfterCombo)
    } finally {
        RodizioAtivo := false
    }
}

RodizioAindaValido(timeDoRodizio, idDaSequencia) {
    return TimeAtual == timeDoRodizio && ModoAtual == "Hoenn222" && IdDaExecucao == idDaSequencia
}

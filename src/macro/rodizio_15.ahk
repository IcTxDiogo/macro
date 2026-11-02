#Requires AutoHotkey v2.0
; Rodizio do modo Hoenn 1,5: cada time e abre + meio + finaliza, e o botao unico pede a
; proxima parte. QUANDO liberar vem de src\tempo\hoenn15.ahk; aqui so as teclas e o
; registro no cooldown.
;   PARTE 1 (fase COMBAR)    abre: combo -> [skill emprestada: chama o meio do outro time ->
;                            Pokestop -> Medicine -> skill -> Hoenn15_GuestSleepAfterMs] ->
;                            chama o meio -> Pokestop -> Medicine -> skills da parte 1
;                            (sem stun) -> Hoenn15_SleepAfterPart1Ms -> pocao
;   PARTE 2 (fase PARTE 2)   meio: skills da parte 2 (stun por ultimo) -> chama o
;                            finalizador -> combo (o combo ja manda o Pokestop)
; Teclas do jogo: time 1 = {1} abre, {2} meio, {3} finaliza; time 2 = {4}, {5}, {6}.

TeclaDaPosicao15(time, posicao) {
    return (Integer(time) - 1) * 3 + posicao
}

; Valida e agenda a proxima parte do time atual. Mesma trava atomica do 2-2-2: o clique e o
; disparo do pedido armado nunca passam juntos.
IniciarRodizio15(origem := "manual", timeEsperado := 0, idEsperado := -1) {
    global TimeAtual, RodizioAtivo, IdDaExecucao, ComboArmado, TimeDoComboArmado

    criticoAnterior := A_IsCritical
    Critical("On")
    try {
        if (origem == "antecipado" && (!ComboArmado || TimeDoComboArmado != timeEsperado
            || TimeAtual != timeEsperado || IdDaExecucao != idEsperado || ModoAtual != "Hoenn15"))
            return
        if (RodizioAtivo || TimeAtual < 1 || TimeAtual > 2)
            return
        RodizioAtivo := true

        ; A parte consome o pedido: nada fica pendente durante a execucao.
        ComboArmado := false
        TimeDoComboArmado := 0

        parte := (FaseAtual == "WAITING_PART2") ? 2 : 1
        timeDoRodizio := TimeAtual
        idDoRodizio := IdDaExecucao
        SetTimer(() => ExecutarParte15(parte, timeDoRodizio, idDoRodizio, origem), -1)
    } finally {
        Critical(criticoAnterior)
    }
}

; Thread descartavel da parte. A fase avanca no inicio (como no 2-2-2): apertar durante a
; parte 2 ja pede a troca de time.
ExecutarParte15(parte, timeDoRodizio, idDoRodizio, origem := "manual") {
    global RodizioAtivo, FaseAtual, InicioDaFaseTick, IdDaExecucao

    ; Invalidado por F8, troca de time ou de modo entre o agendamento e a execucao.
    if (timeDoRodizio != TimeAtual || ModoAtual != "Hoenn15" || idDoRodizio != IdDaExecucao) {
        RodizioAtivo := false
        return
    }

    idDaSequencia := ++IdDaExecucao
    contextoValido := () => Rodizio15AindaValido(timeDoRodizio, idDaSequencia)

    FaseAtual := (parte == 1) ? "WAITING_PART2" : "WAITING_TEAM_SWITCH"
    InicioDaFaseTick := A_TickCount
    RegistrarInicioDoCombo(timeDoRodizio, "1,5 parte " parte, origem)

    try {
        if (parte == 1)
            ExecutarParte1Do15(timeDoRodizio, contextoValido)
        else
            ExecutarParte2Do15(timeDoRodizio, contextoValido)
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=rodizio_15 parte=" parte " team=" timeDoRodizio, e)
    } finally {
        RodizioAtivo := false
    }
}

; Os intervalos (SleepAfter*) sao animacao do jogo e nunca sao alterados pelo otimizador.
ExecutarParte1Do15(time, contextoValido) {
    ; Registro antes do envio: se o ControlSend falhar, o CD comeca assim mesmo (lado seguro).
    RegistrarCast15(time, "abre")
    if !ComboSimples(contextoValido)
        return
    Sleep(SleepAfterTankCombo)
    if !contextoValido.Call()
        return

    ; Skill emprestada: chama o meio do outro time, usa a skill dele e segue.
    convidado := ConvidadoDoTime15(time)
    if convidado {
        ControlSend("{" TeclaDaPosicao15(convidado.FromTeam, 2) "}", , GameWindow)
        RegistrarChamadaConvidado15(time)
        Sleep(SleepAfterSwitch)
        if !PrepararQuemEntrou15(contextoValido)
            return
        RegistrarCast15(time, "convidado")
        ControlSend("{" convidado.Key "}", , GameWindow)
        LogDiagnostico("COMBO15_CONVIDADO", "time=" time " dono=" convidado.FromTeam " tecla=" convidado.Key)
        Sleep(DuracaoDoConvidado15Ms(time) - ForaAteCastDoMeioMs())
        if !contextoValido.Call()
            return
    }

    ControlSend("{" TeclaDaPosicao15(time, 2) "}", , GameWindow)
    RegistrarChamada15(time, 2)
    Sleep(SleepAfterSwitch)
    if !PrepararQuemEntrou15(contextoValido)
        return

    RegistrarCast15(time, "meio1")
    if !EnviarSkillsDaParte15(time, 1, contextoValido)
        return
    ; Espera a parte 1 sair e toma a pocao antes de lurar a 2a.
    Sleep(PausaDepoisDaParte1Ms(time))
    if !contextoValido.Call()
        return
    UsarPocao()
}

ExecutarParte2Do15(time, contextoValido) {
    RegistrarCast15(time, "meio2")
    if !EnviarSkillsDaParte15(time, 2, contextoValido)
        return
    Sleep(PausaDepoisDaParte2Ms(time))
    if !contextoValido.Call()
        return

    ControlSend("{" TeclaDaPosicao15(time, 3) "}", , GameWindow)
    RegistrarChamada15(time, 3)
    Sleep(SleepAfterSwitch)
    if !contextoValido.Call()
        return

    RegistrarCast15(time, "fim")
    if !ComboSimples(contextoValido)
        return
    Sleep(SleepAfterCombo)
}

; Todo Pokemon que entra recebe Pokestop e Medicine antes de agir (como no ComboSimples).
PrepararQuemEntrou15(contextoValido) {
    if !contextoValido.Call()
        return false
    ControlSend("{" KeyPokestop "}", , GameWindow)
    Sleep(50)
    if !contextoValido.Call()
        return false
    ControlSend("{" KeyMedicine "}", , GameWindow)
    Sleep(Max(0, Hoenn15_SkillGapMs))
    return contextoValido.Call()
}

; Envia as skills da parte do meio, na ordem do config, com Hoenn15_SkillGapMs entre elas.
; Se outro time pega uma delas emprestada, o relogio da emprestada reinicia aqui tambem.
EnviarSkillsDaParte15(time, parte, contextoValido) {
    teclas := ""
    timeQueEmpresta := TimeQueEmprestaDe15(time)
    teclaEmprestada := timeQueEmpresta ? ConvidadoDoTime15(timeQueEmpresta).Key : ""
    for skill in SkillsDaParte15(time, parte) {
        if (A_Index > 1)
            Sleep(Max(0, Hoenn15_SkillGapMs))
        if !contextoValido.Call()
            return false
        if (teclaEmprestada != "" && skill.Key = teclaEmprestada)
            RegistrarCast15(timeQueEmpresta, "convidado")
        ControlSend("{" skill.Key "}", , GameWindow)
        teclas .= (A_Index > 1 ? "," : "") skill.Key
    }
    LogDiagnostico("COMBO15_PARTE", "time=" time " parte=" parte " teclas=" teclas)
    return true
}

Rodizio15AindaValido(timeDoRodizio, idDaSequencia) {
    return TimeAtual == timeDoRodizio && ModoAtual == "Hoenn15" && IdDaExecucao == idDaSequencia
}

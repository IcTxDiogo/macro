TestesCancelamentoEMovimento() {
    global
    ResetCase("WAITING_COMBO")
    AplicarCast(1, true, MockTick)
    PedirCombo()
    MockTick += FaltaParaVerdeMs() + Hoenn222_LatencyMs + 1
    VerificarComboArmado()
    Assert(Scheduled.Length == 1, "cancelamento: callback antigo agendado")
    callbackAntigo := Scheduled[1]
    Resincronizar()
    callbackAntigo.Call()
    Assert(Sent.Length == 0 && Scheduled.Length == 1 && !RodizioAtivo, "cancelamento: callback anterior ao F8 nao inicia outro combo")
    ; Um pedido novo depois do F8 tambem nao pode ser consumido pelo callback antigo.
    FaseAtual := "WAITING_COMBO"
    AplicarCast(1, true, MockTick)
    PedirCombo()
    Assert(ComboArmado, "cancelamento: novo pedido armado")
    callbackAntigo.Call()
    Assert(ComboArmado && Scheduled.Length == 1 && Sent.Length == 0, "cancelamento: callback antigo preserva pedido novo")
    Pass("cancelamento: F8 invalida callback do verde e preserva pedido posterior")

    for espera in [50, SleepAfterTankCombo, SleepAfterSwitch] {
        ResetCase()
        MockSleepHook := (ms) => ResincronizarNaEspera(ms, espera)
        IniciarRodizio222()
        Scheduled[1].Call()
        esperado := espera == 50 ? "{y}" : "{y}|{c}|{f}|{i}" (espera == SleepAfterSwitch ? "|{2}" : "")
        Assert(Join(Sent) == esperado, "cancelamento: nenhuma acao apos F8 em Sleep(" espera "): " Join(Sent))
        Assert(!RodizioAtivo && FaseAtual == "WAITING_FIRST_COMBO", "cancelamento: fase e trava apos F8")
        Assert(CooldownRestanteMs[1] == 0 && CooldownRestanteMs[2] == 0, "cancelamento: nenhum cast antigo contamina reset")
    }
    ResetCase()
    contadorSleep := 0
    MockSleepHook := (ms) => CancelarDurantePreparoSecundario(ms, &contadorSleep)
    IniciarRodizio222()
    Scheduled[1].Call()
    Assert(Join(Sent) == "{y}|{c}|{f}|{i}|{2}|{y}", "cancelamento: F8 durante preparo do secundario")
    Assert(CooldownRestanteMs[2] == 0 && !RodizioAtivo, "cancelamento: CD do secundario continua resetado")
    Pass("cancelamento: F8 interrompe rodizio nas esperas curtas e longas sem mudar sleeps")

    ResetCase()
    MockInput.sThumbLY := DeadzoneMove + 1
    MockInput.sThumbLX := -DeadzoneMove - 1
    GameLoop()
    Assert(Join(Sent) == "{w down}|{a down}", "movimento: teclas pressionadas pelo analogico")
    entradaAnterior := MockInput
    MockInput := 0
    GameLoop()
    Assert(Sent.Length == 4 && ((Sent[3] == "{w up}" && Sent[4] == "{a up}") || (Sent[3] == "{a up}" && Sent[4] == "{w up}")), "movimento: desconectar libera ambas as teclas: " Join(Sent))
    quantidade := Sent.Length
    GameLoop()
    Assert(Sent.Length == quantidade, "movimento: nao repete key up depois de liberar")
    MockInput := entradaAnterior
    GameLoop()
    Assert(Sent.Length == quantidade + 2, "movimento: reconectar com analogico ativo envia key down novo")
    WindowAvailable := false
    GameLoop()
    Assert(Sent.Length == quantidade + 2, "movimento: janela ausente nao recebe comandos")
    WindowAvailable := true
    GameLoop()
    Assert(Sent.Length == quantidade + 4, "movimento: janela reaberta nao herda tecla antiga")
    FaultSend := true
    LiberarTeclasDeMovimento(true)
    Assert(EstadoDasTeclasDeMovimento()["w"], "movimento: falha de key up permite repetir")
    FaultSend := false
    LiberarTeclasDeMovimento(true)
    Assert(!EstadoDasTeclasDeMovimento()["w"] && !EstadoDasTeclasDeMovimento()["a"], "movimento: repete liberacao apos falha")
    Pass("movimento: desconexao libera WASD, reconexao/janela rearmam e falha permite repetir")
    ResetCase()
}

ResincronizarNaEspera(ms, espera) {
    global MockSleepHook
    if ms == espera {
        MockSleepHook := false
        Resincronizar()
    }
}

CancelarDurantePreparoSecundario(ms, &contador) {
    global MockSleepHook
    if ms == 50 {
        contador++
        if contador == 4 {
            MockSleepHook := false
            Resincronizar()
        }
    }
}

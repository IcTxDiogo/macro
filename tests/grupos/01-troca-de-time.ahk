; Tema: Troca de time, falhas isoladas, controle e tooltips, diagnostico.
TestesTrocaDeTime() {
    global
    if TestLoggerInitFailure {
        Assert(InStr(FileRead(A_ScriptDir "\debug-init.log"), "phase=logger_init"), "logger initialization failure diagnosed")
        Pass("real DirCreate failure does not abort application initialization")
    }
    ResetCase()
    Assert(TrocarDeTime(), "A first switch accepted")
    Assert(TimeAtual == 2 && Sent[1] == "{3}", "A team2/key3")
    MockTick += 1000
    Assert(TrocarDeTime(), "A second switch accepted at exactly 1000ms")
    Assert(TimeAtual == 3 && Sent[4] == "{5}", "A team3/key5")
    MockTick += 1000
    Assert(TrocarDeTime(), "A wrap accepted")
    Assert(TimeAtual == 1 && Sent[7] == "{1}", "A team1/key1")
    Pass("A normal cycle 1 -> 2 -> 3 -> 1")

    ; TROCAR TIME ja verde (decorrido maior que qualquer janela): troca na hora.
    ResetCase("WAITING_TEAM_SWITCH", 0, 40000)
    UltimaTrocaDeTimeTick := MockTick - 4000
    AplicarCast(1, false, MockTick - 34000)
    AplicarCast(1, true, MockTick - 30500)
    PedirTrocaDeTime("mouse")
    AssertAcceptedSequence()

    Assert(CdRateOf(SlotDoPokemon(1, false)) == 0.5 && CdRateOf(SlotDoPokemon(1, true)) == 0.5, "B dupla anterior na Ball")
    Assert(CdRateOf(SlotDoPokemon(2, false)) == 1.0, "B tank novo fora da Ball")
    Assert(CdRateOf(SlotDoPokemon(2, true)) == 0.5, "B secundario novo continua na Ball")
    Pass("B transicoes de Ball na troca de time")

    ; Todos os valores sao derivados do config: o grupo nao pode quebrar quando o
    ; tier do time muda, e nao deve validar um numero fixo que nao foi medido.
    cdT := CooldownBaseMs(1, false)
    cdS := CooldownBaseMs(1, true)
    Assert(cdT == Hoenn222_CdByTier[Hoenn222_TankTier[1]], "C tank tier " Hoenn222_TankTier[1] " mapeia para " cdT)
    Assert(cdS == Hoenn222_CdByTier[Hoenn222_SecondTier[1]], "C sec tier " Hoenn222_SecondTier[1] " mapeia para " cdS)
    ResetCase("WAITING_TEAM_SWITCH", 0, 40000)
    AplicarCast(1, false, MockTick - 4000)
    AplicarCast(1, true, MockTick - 500)
    PedirTrocaDeTime()
    AssertAcceptedSequence()
    MockTick += 60000
    Assert(CdOf(SlotDoPokemon(2, false)) == 0, "C CD chega a zero e trava em zero")
    ; AcaoGatilhos e uma TROCA DE TIME: a dupla 1 inteira volta para a Ball
    ; a 0,5x. O tank foi criado a 1,0x (fora) e fica 0,5 ate a troca; o
    ; secundario entra a 0,5 desde o inicio.
    ;   tank: (4000 - Lat) a 1,0 + 60000 a 0,5
    ;   sec : (500  - Lat) a 1,0 + 60000 a 0,5
    recT := (4000 - Hoenn222_LatencyMs) + 60000 * Hoenn222_RateInBall
    recS := (500 - Hoenn222_LatencyMs) + 60000 * Hoenn222_RateInBall
    Assert(CdOf(SlotDoPokemon(1, false)) == cdT - recT, "C tank recupera " recT "ms -> " CdOf(SlotDoPokemon(1, false)))
    Assert(CdOf(SlotDoPokemon(1, true)) == cdS - recS, "C secundario recupera " recS "ms -> " CdOf(SlotDoPokemon(1, true)))
    ResetCase("WAITING_COMBO", 0, 16000)
    AplicarCast(1, false, MockTick - 1000)
    MockTick += 5000
    Assert(CdOf(SlotDoPokemon(1, false)) == cdT - 5750, "C recuperacao a 1,0 fora da Ball, latencia de 250 somada")
    Assert(MsAteCastSeguro(SlotDoPokemon(1, false), MockTick) == cdT - 5750 + Hoenn222_MarginMs, "C primeiro instante seguro = CD + margem")
    Pass("C acumulador individual, saturacao em zero e primeiro instante seguro")

    ResetCase("WAITING_TEAM_SWITCH", 0, 5000)
    Assert(TrocarDeTime(), "D state does not block")
    Assert(FaseAtual == "WAITING_COMBO" && InicioDaFaseTick == MockTick, "D state timestamp")
    Pass("D WAITING_TEAM_SWITCH")

    ResetCase("WAITING_COMBO", 0, 2000)
    UltimaTrocaDeTimeTick := MockTick - 1000
    Assert(TrocarDeTime(), "E WAITING_COMBO accepted after debounce")
    Pass("E WAITING_COMBO, only 1000ms debounce")

    ResetCase()
    PedirTrocaDeTime()
    ; Com TROCAR TIME verde a segunda pressao chega ate o debounce de 1000 ms.
    FaseAtual := "WAITING_TEAM_SWITCH"
    InicioDaFaseTick := MockTick - 40000
    MockTick += 999
    PedirTrocaDeTime()
    Assert(Sent.Length == 5 && TimeAtual == 2, "F no commands or advance on duplicate")
    Assert(InStr(DebugText(), "reason=debounce elapsed_ms=999"), "F rejection reason")
    Assert(!A_IsCritical, "F restores thread interruptibility")
    Pass("F duplicate at 999ms rejected")

    ResetCase("WAITING_TEAM_SWITCH", 0, 40000)
    FaultDebt := true
    PedirTrocaDeTime()
    AssertAcceptedSequence()
    Assert(FaseAtual == "WAITING_COMBO", "G state preserved")
    ; O calculo do verde falhou: a troca NUNCA fica presa por isso, vale o comportamento antigo.
    Assert(InStr(DebugText(), "phase=switch_readiness"), "G a falha do calculo foi registrada e a troca saiu mesmo assim")
    Pass("G target calculation throws; the switch does not depend on the target")

    ResetCase()
    FaultLogger := true
    PedirTrocaDeTime()
    AssertAcceptedSequence()
    Assert(InStr(DebugText(), "phase=team_logger"), "H caller isolates logger exception")
    ResetCase()
    ArquivoDoLogDaSessao := A_ScriptDir "\nonexistent\log.txt"
    PedirTrocaDeTime()
    AssertAcceptedSequence()
    Assert(InStr(DebugText(), "phase=session_logger"), "H real FileAppend failure isolated")
    Pass("H thrown logger and real session FileAppend failure")

    ResetCase("WAITING_TEAM_SWITCH", 0, 100)
    AplicarCast(1, false, MockTick - 1000)
    Resincronizar()
    Assert(FaseAtual == "WAITING_FIRST_COMBO", "I F8 reset")
    Assert(IdDaExecucao == 1, "I invalidation")
    Assert(CdOf(1) == 0 && CdRateOf(1) == 0.5, "I F8 zera os cooldowns e deixa tudo na Ball")
    PedirTrocaDeTime()
    AssertAcceptedSequence()
    MockTick += 500
    Resincronizar()
    PedirTrocaDeTime()
    Assert(TimeAtual == 2 && Sent.Length == 5, "I F8 does not bypass debounce")
    MockTick += 500
    PedirTrocaDeTime()
    Assert(TimeAtual == 3 && Sent[6] == "{5}", "I accepts at 1000ms after F8")
    Pass("I F8 resync followed by switch")

    ResetCase("WAITING_TEAM_SWITCH", 500, 40000)
    WindowAvailable := false
    PedirTrocaDeTime()
    Assert(Sent.Length == 0 && TimeAtual == 1 && UltimaTrocaDeTimeTick == 0, "J no-window keeps state")
    Assert(InStr(DebugText(), "reason=no_window") && !InStr(DebugText(), "SWITCH_STATE_UPDATED"), "J no false success")
    ResetCase("WAITING_TEAM_SWITCH", 0, 40000)
    AplicarCast(1, false, MockTick - 1000)
    RealInvalidWindow := true
    PedirTrocaDeTime()
    Assert(Sent.Length == 0 && TimeAtual == 1, "J real failed ControlSend keeps state")
    Assert(CdRateOf(1) == 1.0, "J falha no envio nao move ninguem para fora da Ball")
    Assert(InStr(DebugText(), "result=failed") && InStr(DebugText(), "reason=send_failed") && !InStr(DebugText(), "requested_only"), "J real TargetError diagnosed")
    Assert(!A_IsCritical, "J critical restored on failure")
    Pass("J no window and real ControlSend TargetError to synthetic nonexistent window")

    ResetCase("WAITING_TEAM_SWITCH", 700, 40000)
    ArquivoDiagnostico := A_ScriptDir "\nonexistent\debug.log"
    FaultDebt := true
    FaultLogger := true
    PedirTrocaDeTime()
    AssertAcceptedSequence()
    Pass("debug writer unavailable with simultaneous debt/logger failures")

    ResetCase("WAITING_TEAM_SWITCH", 0, 40000)
    FaultDebt := true
    MockInput.wButtons := 0x0200
    GameLoop()
    Assert(Scheduled.Length == 1, "controller scheduled despite tooltip computation error")
    GameLoop()
    Assert(Scheduled.Length == 1, "held trigger schedules only once")
    Assert(StrSplit(DebugText(), "phase=tooltip").Length == 2, "tooltip error logged once, ocorrencias=" StrSplit(DebugText(), "phase=tooltip").Length " trace=" DebugText())
    Scheduled[1].Call()
    AssertAcceptedSequence()
    Assert(InStr(DebugText(), "source=controller"), "controller source recorded")
    MockInput.bRightTrigger := 0
MockInput.wButtons := 0
    GameLoop()
    MockTick += 1000
    MockInput.wButtons := 0x0200
    GameLoop()
    Assert(Scheduled.Length == 2, "release and repress schedules next switch")
    ; A 1a troca levou a COMBAR; leva TROCAR TIME verde de novo para a 2a.
    FaseAtual := "WAITING_TEAM_SWITCH"
    InicioDaFaseTick := MockTick - 40000
    Scheduled[2].Call()
    Assert(TimeAtual == 3 && Sent[6] == "{5}", "controller next team despite failing UI")
    MockInput.bRightTrigger := 0
MockInput.wButtons := 0
    GameLoop()
    Pass("controller press/hold/release with persistently failing tooltip calculation")

    ResetCase("WAITING_TEAM_SWITCH", 0, 40000)
    FaultTooltip := true
    MockInput.wButtons := 0x0200
    GameLoop()
    Assert(Scheduled.Length == 1, "ToolTip I/O failure still schedules")
    Scheduled[1].Call()
    AssertAcceptedSequence()
    MockInput.bRightTrigger := 0
MockInput.wButtons := 0
    GameLoop()
    Pass("ToolTip I/O throws; controller switch preserved")

    ResetCase("WAITING_COMBO", 2000, 3000)
    AtualizarInterface()
    Assert(Rendered.Length == 2 && Rendered[1].id == 2 && Rendered[2].id == 1, "two tooltips")
    Assert(Rendered[1].x == 946 && Rendered[1].y == 362 && Rendered[2].x == 220 && Rendered[2].y == 50, "original tooltip positions")
    Assert(Rendered[1].text == Chr(0x3000), "central indicator has no numbers or letters")
    Assert(InStr(Rendered[2].text, "COMBAR") && !RegExMatch(Rendered[2].text, "\d+\.\d+s"), "upper tooltip keeps action without elapsed or target time")
    Assert(DebugText() == "", "normal screen updates do not log")
    Assert(SleepAfterTankCombo == 2700 && SleepAfterCombo == 3000 && SleepAfterSwitch == 800, "sleep constants")
    Pass("two tooltip IDs/positions, no visible timers, no frame logs, fixed sleeps")


    ResetCase()
    IniciarRodizio222()
    Assert(Scheduled.Length == 1 && RodizioAtivo, "combo scheduling unchanged")
    Scheduled[1].Call()
    Assert(Join(Sent) == "{y}|{c}|{f}|{i}|{2}|{y}|{c}|{f}|{i}", "2-2-2 skill and P2 sequence")
    Assert(InStr(Join(Timeline), "sleep:2700|send:{2}|sleep:800") && InStr(Join(Timeline), "sleep:3000"), "combo waits unchanged")
    Assert(!RodizioAtivo, "combo lock released")
    RodizioAtivo := true
    InicioDaFaseTick := MockTick - 40000
    PedirTrocaDeTime()
    Assert(TimeAtual == 2 && Sent[10] == "{3}", "switch independent of combo lock")
    RodizioAtivo := false
    Pass("2-2-2 skill sequence and waits preserved; combo lock never gates manual switch")

    ResetCase("WAITING_TEAM_SWITCH", 0, 40000)
    AcaoBumpers("mouse")
    trace := DebugText()
    lastPosition := 0
    for event in ["NEXT_ACTION", "SWITCH_REQUESTED", "SWITCH_COMMAND_BEGIN", "SWITCH_COMMAND_END", "SWITCH_STATE_UPDATED"] {
        position := InStr(trace, event)
        Assert(position > lastPosition, "diagnostic event order: " event)
        lastPosition := position
    }
    Assert(InStr(trace, "result=requested_only") && InStr(trace, "visual_confirmation=unknown"), "request not visual success")
    Pass("ordered diagnostics distinguish requested send from visual entry")
}

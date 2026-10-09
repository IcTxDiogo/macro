; Concatenado pelo runner às funções atuais, sem executar main.ahk ou carregar XInput.
global Sent := [], Timeline := [], Scheduled := [], Rendered := []
global FaultDebt := false, FaultLogger := false, FaultSend := false, FaultTooltip := false
global WindowAvailable := true, RealInvalidWindow := false
global MockInput := {bRightTrigger: 0, bLeftTrigger: 0, wButtons: 0,
    sThumbLX: 0, sThumbLY: 0, sThumbRX: 0, sThumbRY: 0}
global PassCount := 0

if TestBaseline {
    RunBaseline()
} else {
    RunTests()
}
ExitApp(0)

MockControlSend(keys, control := "", window := "") {
    global Sent, Timeline, FaultSend, RealInvalidWindow
    Timeline.Push("send:" keys)
    if RealInvalidWindow {
        ; Único ControlSend real: destino sintético inexistente, nunca a janela do jogo.
        ControlSend(keys, , "ahk_exe __macro_switch_test_nonexistent_8fc21e.exe")
    }
    if FaultSend
        throw Error("simulated ControlSend failure", "MockControlSend")
    Sent.Push(keys)
}
MockSleep(ms) {
    global Timeline
    Timeline.Push("sleep:" ms)
}
MockWinExist(*) {
    global WindowAvailable
    return WindowAvailable ? 123 : 0
}
MockWinGetPos(&x := unset, &y := unset, &width := unset, &height := unset, *) {
    x := 10
    y := 20
    width := 13
    height := 18
}
MockToolTip(text := "", x := 0, y := 0, id := 1) {
    global Rendered, FaultTooltip
    if FaultTooltip
        throw Error("simulated ToolTip failure", "MockToolTip")
    Rendered.Push({text: text, x: x, y: y, id: id})
}
MockCentralTooltip(text := "", x := 0, y := 0, color := "FFE033") {
    ; Manter a coloração nativa isolada do jogo durante os testes.
    MockToolTip(text, x, y, 2)
}
MockSetTimer(callback, period) {
    global Scheduled
    Scheduled.Push(callback)
}
MockXInput(*) {
    global MockInput
    return MockInput
}
MockBaseTarget(state, team) {
    global FaultDebt, Timeline
    Timeline.Push("debt:" state ":" team)
    if FaultDebt
        throw Error("simulated GetHoenn222BaseTargetMs failure", "GetHoenn222BaseTargetMs")
    return RealBaseTarget(state, team)
}
MockTeamLogger(team, mode) {
    global FaultLogger, Timeline
    Timeline.Push("logger:" team)
    if FaultLogger
        throw Error("simulated logger failure", "LogTeamSwitch")
    RealTeamLogger(team, mode)
}
ResetCase(state := "WAITING_FIRST_COMBO", debt := 0, elapsed := 0) {
    global
    TimeAtual := 1
    isRodizioAtivo := false
    TankAtualTime2_33 := 4
    ModoAtual := "Hoenn222"
    Hoenn222_State := state
    Hoenn222_StateStartTick := MockTick - elapsed
    Hoenn222_LastTeamSwitchTick := 0
    Hoenn222_ExecutionId := 0
    Hoenn222_TankEnterTick := Map(1, 0, 2, 0, 3, 0)
    Hoenn222_TeamDuration := Map(1, 0, 2, 0, 3, 0)
    Hoenn222_TeamUsageInterval := Map(1, 0, 2, 0, 3, 0)
    Hoenn222_TeamLastUsageTick := Map(1, 0, 2, 0, 3, 0)
    Hoenn222_ComboArmed := false
    Hoenn222_ComboArmedTeam := 0
    Hoenn222_ComboLastPressTick := 0
    Hoenn222_SwitchArmed := false
    Hoenn222_SwitchArmedTeam := 0
    Hoenn222_SwitchLastPressTick := 0
    Hoenn222_Cd := [0, 0, 0, 0, 0, 0]
    Hoenn222_CdRate := [0, 0, 0, 0, 0, 0]
    Hoenn222_CdSince := [0, 0, 0, 0, 0, 0]
    global Hoenn222_PlanCache := false
    Hoenn222_CdAvisoFeito := false
    Hoenn222_CdOptimizerEnabled := true
    ResetarCooldownsHoenn222(MockTick)
    ; Os testes antigos partem de times que ja fizeram o primeiro cast; a primeira
    ; volta tem os grupos proprios (W) e liga o ritmo com TeamCasted := false.
    Hoenn222_TeamCasted := Map(1, true, 2, true, 3, true)
    ; Os pisos de conforto do config.ahk sao do jogador; os testes legados medem o
    ; plano de volta minima, e os grupos AA-AC ligam os pisos explicitamente.
    Hoenn222_MinLureMs := Map(1, 0, 2, 0, 3, 0)
    Hoenn222_MinSecondaryOutMs := Map(1, 0, 2, 0, 3, 0)
    Sent := [], Timeline := [], Scheduled := [], Rendered := []
    FaultDebt := false, FaultLogger := false, FaultSend := false, FaultTooltip := false
    WindowAvailable := true, RealInvalidWindow := false
    MockInput.bRightTrigger := 0
    StartComboTick := 0
    CurrentSessionLogFile := A_ScriptDir "\session_logs\test-session.txt"
    SwitchDebugEnabled := true
    SwitchDebugFile := A_ScriptDir "\switch-debug.log"
    if FileExist(SwitchDebugFile)
        FileDelete(SwitchDebugFile)
}
CdRateOf(slot) {
    global Hoenn222_CdRate
    Hoenn222CdTouch(slot, MockTick)
    return Hoenn222_CdRate[slot]
}
CdOf(slot) {
    global Hoenn222_Cd
    Hoenn222CdTouch(slot, MockTick)
    return Hoenn222_Cd[slot]
}
Assert(condition, message) {
    if !condition
        throw Error("ASSERT: " message, "Assert")
}
Join(items) {
    result := ""
    for item in items
        result .= (A_Index == 1 ? "" : "|") item
    return result
}
DebugText() {
    global SwitchDebugFile
    return FileExist(SwitchDebugFile) ? FileRead(SwitchDebugFile) : ""
}
Pass(name) {
    global PassCount
    PassCount++
    FileAppend("PASS " name "`n", "*", "UTF-8")
}
AssertAcceptedSequence() {
    global Sent, Timeline, TimeAtual
    Assert(Join(Sent) == "{3}|{c}|{t}|{c}|{e}", "primary + Pokestop + FullDef + trigger Pokestop + Potion")
    Assert(InStr(Join(Timeline), "sleep:800"), "SleepAfterSwitch preserved")
    Assert(TimeAtual == 2, "requested team committed")
}
RunTests() {
    global
    try {
        if TestLoggerInitFailure {
            Assert(InStr(FileRead(A_ScriptDir "\debug-init.log"), "phase=logger_init"), "logger initialization failure diagnosed")
            Pass("real DirCreate failure does not abort application initialization")
        }
        ResetCase()
        Assert(TrocarTimeHoenn(3), "A first switch accepted")
        Assert(TimeAtual == 2 && Sent[1] == "{3}", "A team2/key3")
        MockTick += 1000
        Assert(TrocarTimeHoenn(3), "A second switch accepted at exactly 1000ms")
        Assert(TimeAtual == 3 && Sent[4] == "{5}", "A team3/key5")
        MockTick += 1000
        Assert(TrocarTimeHoenn(3), "A wrap accepted")
        Assert(TimeAtual == 1 && Sent[7] == "{1}", "A team1/key1")
        Pass("A normal cycle 1 -> 2 -> 3 -> 1")

        ; TROCAR TIME ja verde (decorrido maior que qualquer janela): troca na hora.
        ResetCase("WAITING_TEAM_SWITCH", 0, 40000)
        Hoenn222_LastTeamSwitchTick := MockTick - 4000
        Hoenn222_TeamLastUsageTick[2] := MockTick - 50000
        Hoenn222CdCast(1, false, MockTick - 34000)
        Hoenn222CdCast(1, true, MockTick - 30500)
        Acao_Gatilhos("mouse")
        AssertAcceptedSequence()
        Assert(Hoenn222_TeamDuration[1] == 4000 && Hoenn222_TeamUsageInterval[2] == 50000, "B tracking")
        Assert(Hoenn222_TankEnterTick[2] == MockTick, "B tank timestamp")
        Assert(CdRateOf(Hoenn222Slot(1, false)) == 0.5 && CdRateOf(Hoenn222Slot(1, true)) == 0.5, "B dupla anterior na Ball")
        Assert(CdRateOf(Hoenn222Slot(2, false)) == 1.0, "B tank novo fora da Ball")
        Assert(CdRateOf(Hoenn222Slot(2, true)) == 0.5, "B secundario novo continua na Ball")
        Pass("B transicoes de Ball e estatisticas na troca de time")

        ; Todos os valores sao derivados do config: o grupo nao pode quebrar quando o
        ; tier do time muda, e nao deve validar um numero fixo que nao foi medido.
        cdT := GetHoenn222CdMainMs(1, false)
        cdS := GetHoenn222CdMainMs(1, true)
        Assert(cdT == Hoenn222_CdByTier[Hoenn222_TankTier[1]], "C tank tier " Hoenn222_TankTier[1] " mapeia para " cdT)
        Assert(cdS == Hoenn222_CdByTier[Hoenn222_SecondTier[1]], "C sec tier " Hoenn222_SecondTier[1] " mapeia para " cdS)
        ResetCase("WAITING_TEAM_SWITCH", 0, 40000)
        Hoenn222CdCast(1, false, MockTick - 4000)
        Hoenn222CdCast(1, true, MockTick - 500)
        Acao_Gatilhos()
        AssertAcceptedSequence()
        MockTick += 60000
        Assert(CdOf(Hoenn222Slot(2, false)) == 0, "C CD chega a zero e trava em zero")
        ; Acao_Gatilhos e uma TROCA DE TIME: a dupla 1 inteira volta para a Ball
        ; a 0,5x. O tank foi criado a 1,0x (fora) e fica 0,5 ate a troca; o
        ; secundario entra a 0,5 desde o inicio.
        ;   tank: (4000 - Lat) a 1,0 + 60000 a 0,5
        ;   sec : (500  - Lat) a 1,0 + 60000 a 0,5
        recT := (4000 - Hoenn222_LatencyMs) + 60000 * Hoenn222_RateInBall
        recS := (500 - Hoenn222_LatencyMs) + 60000 * Hoenn222_RateInBall
        Assert(CdOf(Hoenn222Slot(1, false)) == cdT - recT, "C tank recupera " recT "ms -> " CdOf(Hoenn222Slot(1, false)))
        Assert(CdOf(Hoenn222Slot(1, true)) == cdS - recS, "C secundario recupera " recS "ms -> " CdOf(Hoenn222Slot(1, true)))
        ResetCase("WAITING_COMBO", 0, 16000)
        Hoenn222CdCast(1, false, MockTick - 1000)
        MockTick += 5000
        Assert(CdOf(Hoenn222Slot(1, false)) == cdT - 5750, "C recuperacao a 1,0 fora da Ball, latencia de 250 somada")
        Assert(Hoenn222CdReadyInMs(Hoenn222Slot(1, false), MockTick) == cdT - 5750 + Hoenn222_MarginMs, "C primeiro instante seguro = CD + margem")
        Pass("C acumulador individual, saturacao em zero e primeiro instante seguro")

        ResetCase("WAITING_TEAM_SWITCH", 0, 5000)
        Assert(TrocarTimeHoenn(3), "D state does not block")
        Assert(Hoenn222_State == "WAITING_COMBO" && Hoenn222_StateStartTick == MockTick, "D state timestamp")
        Pass("D WAITING_TEAM_SWITCH")

        ResetCase("WAITING_COMBO", 0, 2000)
        Hoenn222_LastTeamSwitchTick := MockTick - 1000
        Assert(TrocarTimeHoenn(3), "E WAITING_COMBO accepted after debounce")
        Pass("E WAITING_COMBO, only 1000ms debounce")

        ResetCase()
        Acao_Gatilhos()
        ; Com TROCAR TIME verde a segunda pressao chega ate o debounce de 1000 ms.
        Hoenn222_State := "WAITING_TEAM_SWITCH"
        Hoenn222_StateStartTick := MockTick - 40000
        MockTick += 999
        Acao_Gatilhos()
        Assert(Sent.Length == 5 && TimeAtual == 2, "F no commands or advance on duplicate")
        Assert(InStr(DebugText(), "reason=debounce elapsed_ms=999"), "F rejection reason")
        Assert(!A_IsCritical, "F restores thread interruptibility")
        Pass("F duplicate at 999ms rejected")

        ResetCase("WAITING_TEAM_SWITCH", 0, 40000)
        FaultDebt := true
        Acao_Gatilhos()
        AssertAcceptedSequence()
        Assert(Hoenn222_State == "WAITING_COMBO", "G state preserved")
        ; O calculo do verde falhou: a troca NUNCA fica presa por isso, vale o comportamento antigo.
        Assert(InStr(DebugText(), "phase=switch_readiness"), "G a falha do calculo foi registrada e a troca saiu mesmo assim")
        Pass("G target calculation throws; the switch does not depend on the target")

        ResetCase()
        FaultLogger := true
        Acao_Gatilhos()
        AssertAcceptedSequence()
        Assert(InStr(DebugText(), "phase=team_logger"), "H caller isolates logger exception")
        ResetCase()
        CurrentSessionLogFile := A_ScriptDir "\nonexistent\log.txt"
        Acao_Gatilhos()
        AssertAcceptedSequence()
        Assert(InStr(DebugText(), "phase=session_logger"), "H real FileAppend failure isolated")
        Pass("H thrown logger and real session FileAppend failure")

        ResetCase("WAITING_TEAM_SWITCH", 0, 100)
        Hoenn222_LastComboStartTick := 999
        Hoenn222_P2CallTick := 999
        Hoenn222CdCast(1, false, MockTick - 1000)
        ResincronizarHoenn222()
        Assert(Hoenn222_State == "WAITING_FIRST_COMBO", "I F8 reset")
        Assert(Hoenn222_ExecutionId == 1 && Hoenn222_LastComboStartTick == 0 && Hoenn222_P2CallTick == 0, "I invalidation")
        Assert(CdOf(1) == 0 && CdRateOf(1) == 0.5, "I F8 zera os cooldowns e deixa tudo na Ball")
        Acao_Gatilhos()
        AssertAcceptedSequence()
        MockTick += 500
        ResincronizarHoenn222()
        Acao_Gatilhos()
        Assert(TimeAtual == 2 && Sent.Length == 5, "I F8 does not bypass debounce")
        MockTick += 500
        Acao_Gatilhos()
        Assert(TimeAtual == 3 && Sent[6] == "{5}", "I accepts at 1000ms after F8")
        Pass("I F8 resync followed by switch")

        ResetCase("WAITING_TEAM_SWITCH", 500, 40000)
        WindowAvailable := false
        Acao_Gatilhos()
        Assert(Sent.Length == 0 && TimeAtual == 1 && Hoenn222_LastTeamSwitchTick == 0, "J no-window keeps state")
        Assert(InStr(DebugText(), "reason=no_window") && !InStr(DebugText(), "SWITCH_STATE_UPDATED"), "J no false success")
        ResetCase("WAITING_TEAM_SWITCH", 0, 40000)
        Hoenn222CdCast(1, false, MockTick - 1000)
        RealInvalidWindow := true
        Acao_Gatilhos()
        Assert(Sent.Length == 0 && TimeAtual == 1, "J real failed ControlSend keeps state")
        Assert(CdRateOf(1) == 1.0, "J falha no envio nao move ninguem para fora da Ball")
        Assert(InStr(DebugText(), "result=failed") && InStr(DebugText(), "reason=send_failed") && !InStr(DebugText(), "requested_only"), "J real TargetError diagnosed")
        Assert(!A_IsCritical, "J critical restored on failure")
        Pass("J no window and real ControlSend TargetError to synthetic nonexistent window")

        ResetCase("WAITING_TEAM_SWITCH", 700, 40000)
        SwitchDebugFile := A_ScriptDir "\nonexistent\debug.log"
        FaultDebt := true
        FaultLogger := true
        Acao_Gatilhos()
        AssertAcceptedSequence()
        Pass("debug writer unavailable with simultaneous debt/logger failures")

        ResetCase("WAITING_TEAM_SWITCH", 0, 40000)
        FaultDebt := true
        MockInput.bRightTrigger := 255
        GameLoop()
        Assert(Scheduled.Length == 1, "controller scheduled despite tooltip computation error")
        GameLoop()
        Assert(Scheduled.Length == 1, "held trigger schedules only once")
        Assert(StrSplit(DebugText(), "phase=tooltip").Length == 2, "tooltip error logged once, ocorrencias=" StrSplit(DebugText(), "phase=tooltip").Length " trace=" DebugText())
        Scheduled[1].Call()
        AssertAcceptedSequence()
        Assert(InStr(DebugText(), "source=controller"), "controller source recorded")
        MockInput.bRightTrigger := 0
        GameLoop()
        MockTick += 1000
        MockInput.bRightTrigger := 255
        GameLoop()
        Assert(Scheduled.Length == 2, "release and repress schedules next switch")
        ; A 1a troca levou a COMBAR; leva TROCAR TIME verde de novo para a 2a.
        Hoenn222_State := "WAITING_TEAM_SWITCH"
        Hoenn222_StateStartTick := MockTick - 40000
        Scheduled[2].Call()
        Assert(TimeAtual == 3 && Sent[6] == "{5}", "controller next team despite failing UI")
        MockInput.bRightTrigger := 0
        GameLoop()
        Pass("controller press/hold/release with persistently failing tooltip calculation")

        ResetCase("WAITING_TEAM_SWITCH", 0, 40000)
        FaultTooltip := true
        MockInput.bRightTrigger := 255
        GameLoop()
        Assert(Scheduled.Length == 1, "ToolTip I/O failure still schedules")
        Scheduled[1].Call()
        AssertAcceptedSequence()
        MockInput.bRightTrigger := 0
        GameLoop()
        Pass("ToolTip I/O throws; controller switch preserved")

        ResetCase("WAITING_COMBO", 2000, 3000)
        AtualizarTooltipsControle()
        Assert(Rendered.Length == 2 && Rendered[1].id == 2 && Rendered[2].id == 1, "two tooltips")
        Assert(Rendered[1].x == 946 && Rendered[1].y == 362 && Rendered[2].x == 220 && Rendered[2].y == 50, "original tooltip positions")
        Assert(Rendered[1].text == Chr(0x3000), "central indicator has no numbers or letters")
        Assert(InStr(Rendered[2].text, "COMBAR") && !RegExMatch(Rendered[2].text, "\d+\.\d+s"), "upper tooltip keeps action without elapsed or target time")
        Assert(DebugText() == "", "normal screen updates do not log")
        Assert(SleepAfterTankCombo == 2700 && SleepAfterCombo == 3000 && SleepAfterSwitch == 800, "sleep constants")
        Pass("two tooltip IDs/positions, no visible timers, no frame logs, fixed sleeps")

        ResetCase()
        ModoAtual := "Hoenn33"
        Acao_Gatilhos()
        Assert(Join(Sent) == "{4}|{c}|{t}|{c}|{e}" && TimeAtual == 2, "3-3 tank4")
        Acao_Gatilhos()
        Assert(TimeAtual == 1 && Sent[6] == "{1}", "3-3 no added debounce")
        TankAtualTime2_33 := 5
        Acao_Gatilhos()
        Assert(TimeAtual == 2 && Sent[11] == "{5}", "3-3 tank5 optimization")
        TimeAtual := 3
        Acao_Gatilhos()
        Assert(TimeAtual == 1 && Sent[16] == "{1}", "mode transition from team3")
        Pass("3-3 cycle, alternating tank, original commands, no added debounce")

        ResetCase()
        ComboComplexoHoenn222()
        Assert(Scheduled.Length == 1 && isRodizioAtivo, "combo scheduling unchanged")
        Scheduled[1].Call()
        Assert(Join(Sent) == "{y}|{c}|{f}|{i}|{2}|{y}|{c}|{f}|{i}", "2-2-2 skill and P2 sequence")
        Assert(InStr(Join(Timeline), "sleep:2700|send:{2}|sleep:800") && InStr(Join(Timeline), "sleep:3000"), "combo waits unchanged")
        Assert(!isRodizioAtivo, "combo lock released")
        isRodizioAtivo := true
        Hoenn222_StateStartTick := MockTick - 40000
        Acao_Gatilhos()
        Assert(TimeAtual == 2 && Sent[10] == "{3}", "switch independent of combo lock")
        isRodizioAtivo := false
        Pass("2-2-2 skill sequence and waits preserved; combo lock never gates manual switch")

        ResetCase()
        Acao_Gatilhos("mouse")
        trace := DebugText()
        lastPosition := 0
        for event in ["TRIGGER_RECEIVED", "SWITCH_REQUESTED", "SWITCH_COMMAND_BEGIN", "SWITCH_COMMAND_END", "SWITCH_STATE_UPDATED"] {
            position := InStr(trace, event)
            Assert(position > lastPosition, "diagnostic event order: " event)
            lastPosition := position
        }
        Assert(InStr(trace, "result=requested_only") && InStr(trace, "visual_confirmation=unknown"), "request not visual success")
        Pass("ordered diagnostics distinguish requested send from visual entry")

        ; --- COMBO 2-2-2: NORMAL, ANTECIPADO E EMERGENCIA ---
        ; O alvo do otimizador e "quanto falta a partir de agora" e chega ao
        ; contador como DURACAO a partir do inicio do estado (decorrido + falta),
        ; entao o pendente e exatamente o que falta, sem descontar o decorrido
        ; duas vezes. Nao existe espera artificial: com todos os CD zerados esta
        ; pronto, e com o tank pronto quem segura o verde e o secundario, ate que
        ; o CD dele caia abaixo da tolerancia (1900ms).

        ResetCase("WAITING_COMBO", 0, 0)
        ; Tolerancia = metade da invocacao na Ball + (gap - latencia, o jogo so conta o CD
        ; LatenciaMs depois da chamada) - margem.
        Assert(Hoenn222_SecondaryToleranceMs == 0.5 * SleepAfterTankCombo + (SleepAfterSwitch - Hoenn222_LatencyMs) - Hoenn222_MarginMs, "A tolerancia do secundario inclui a latencia da chamada")
        Assert(GetHoenn222ComboTargetMs(1) == 0, "A sem CD, ja esta pronto")
        Assert(GetHoenn222ComboBloqueio(1) == "", "A com tudo pronto ninguem segura o verde")

        ; Tank pronto, secundario com CD principal em cooldown: o verde e do
        ; secundario. O numero vem do config, nao e fixo.
        cdSecMain := GetHoenn222CdMainMs(1, true)
        Hoenn222CdCast(1, true, MockTick)
        Assert(GetHoenn222ComboTargetMs(1) == cdSecMain - Hoenn222_SecondaryToleranceMs, "A alvo = (CD sec - tolerancia)/taxa -> "
            GetHoenn222ComboTargetMs(1) " esperado " (cdSecMain - Hoenn222_SecondaryToleranceMs))
        Assert(GetHoenn222ComboBloqueio(1) == "secundario", "A secundario segurando o verde")
        Assert(Hoenn222SecondaryPendenteMs(1, 0) > 0, "A antecipar agora deixaria o secundario atrasado")
        SolicitarComboHoenn222()
        Assert(Hoenn222_ComboArmed && Hoenn222_ComboArmedTeam == 1, "A pressa antes do verde arma")
        Assert(Scheduled.Length == 0, "A nada e enviado enquanto armado")
        Assert(InStr(DebugText(), "CD_ANTECIPACAO"), "A avisa a antecipacao")
        Assert(InStr(DebugText(), "bloqueio=secundario"), "A avisa quem esta segurando")
        GameLoop()
        Assert(Scheduled.Length == 0, "A continua esperando")
        ; O verde chega quando o CD do secundario cai a tolerancia, nem antes.
        ; Com taxa 1,0 (cast fora da Ball, contagem comeca LatenciaMs depois):
        ;   falta = cdSec - (decorrido - Lat) - Tolerancia <= 0
        ;   =>  decorrido >= cdSec + Lat - Tol
        ; Contar o decorrido duas vezes acendia o verde na METADE disso, com o
        ; CD ainda correndo no jogo.
        ateVerde := cdSecMain + Hoenn222_LatencyMs - Hoenn222_SecondaryToleranceMs
        MockTick += ateVerde - 1
        GameLoop()
        Assert(Scheduled.Length == 0, "A 1ms antes do instante exato ainda nao dispara (pend="
            GetHoenn222PendingMs() ")")
        MockTick += 1
        GameLoop()
        ; O laco de 30 ms so AGENDA uma thread descartavel; nada de Critical nem do
        ; combo na thread do movimento.
        Assert(Scheduled.Length == 1 && !isRodizioAtivo && Hoenn222_ComboArmed, "A o laco so agenda: agend=" Scheduled.Length " ativo=" isRodizioAtivo
            " pend=" GetHoenn222PendingMs() " alvo=" GetHoenn222ComboTargetMs(1)
            " cdSec=" CdOf(Hoenn222Slot(1, true)) " tol=" Hoenn222_SecondaryToleranceMs)
        GameLoop()
        Assert(Scheduled.Length == 1, "A varreduras seguintes nao agendam de novo")
        Assert(InStr(DebugText(), "COMBO_FIRED"), "A disparo armado registrado")
        Scheduled[1].Call()
        Assert(Scheduled.Length == 2 && isRodizioAtivo, "A a thread descartavel consome o pedido e agenda o rodizio")
        Assert(!Hoenn222_ComboArmed && Hoenn222_ComboArmedTeam == 0, "A pedido armado consumido")
        Scheduled[2].Call()
        Assert(Join(Sent) == "{y}|{c}|{f}|{i}|{2}|{y}|{c}|{f}|{i}", "A sequencia de skills armada")
        Assert(!isRodizioAtivo, "A trava do combo liberada")
        Pass("A pressa antecipada arma; o timer dispara o combo quando tank E secundario ficam viaveis")

        ResetCase("WAITING_COMBO", 0, 20000)
        GameLoop()
        Assert(Scheduled.Length == 0 && Sent.Length == 0, "B green alone never auto-runs")
        Assert(!Hoenn222_ComboArmed, "B nothing armed without a press")
        SolicitarComboHoenn222()
        Assert(Scheduled.Length == 1 && isRodizioAtivo, "B press on green runs now")
        Scheduled[1].Call()
        Assert(Join(Sent) == "{y}|{c}|{f}|{i}|{2}|{y}|{c}|{f}|{i}", "B skill sequence")
        Pass("B green waits for the press")

        ; Sem CD o alvo e so a margem (250ms), entao "ainda nao verde"quer dizer
        ; decorrido menor que a margem. Os grupos C, D e E dependem disso.
        ResetCase("WAITING_COMBO", 0, 0)
        ; CD real no secundario: assim o verde nao chega durante a janela de
        ; emergencia e o teste mede a janela, nao o cronometro.
        Hoenn222CdCast(1, true, MockTick)
        SolicitarComboHoenn222()
        Assert(Hoenn222_ComboArmed && Scheduled.Length == 0, "C first press only arms")
        MockTick += Hoenn222_EmergencyWindowMs + 1
        SolicitarComboHoenn222()
        Assert(Scheduled.Length == 0 && Hoenn222_ComboArmed, "C outside the window only re-arms")
        MockTick += Hoenn222_EmergencyWindowMs
        SolicitarComboHoenn222()
        Assert(Scheduled.Length == 1 && isRodizioAtivo, "C double press is emergency")
        Assert(!Hoenn222_ComboArmed, "C emergency drops the pending request")
        Assert(InStr(DebugText(), "result=emergency"), "C emergency logged")
        Scheduled[1].Call()
        Assert(Join(Sent) == "{y}|{c}|{f}|{i}|{2}|{y}|{c}|{f}|{i}", "C emergency sequence")
        savedWindow := Hoenn222_EmergencyWindowMs
        Hoenn222_EmergencyWindowMs := 0
        ResetCase("WAITING_COMBO", 0, 0)
        Hoenn222CdCast(1, true, MockTick)
        SolicitarComboHoenn222()
        MockTick += 1
        SolicitarComboHoenn222()
        Assert(Scheduled.Length == 0 && Hoenn222_ComboArmed, "C zero window disables emergency")
        Hoenn222_EmergencyWindowMs := savedWindow
        Pass("C double press ignores the timer; zero window disables it")

        ResetCase("WAITING_COMBO", 0, 0)
        ; Com tudo pronto o botao executaria na hora; o secundario em CD faz o pedido armar.
        Hoenn222CdCast(1, true, MockTick)
        SolicitarComboHoenn222()
        Assert(Hoenn222_ComboArmed, "D the press armed")
        Assert(TrocarTimeHoenn(3), "D switch accepted")
        Assert(TimeAtual == 2 && !Hoenn222_ComboArmed && Hoenn222_ComboArmedTeam == 0, "D switch disarms")
        Assert(Sent.Length == 3 && InStr(DebugText(), "reason=team_switch"), "D only the switch keys were sent")
        MockTick += 60000
        GameLoop()
        Assert(Scheduled.Length == 0 && Sent.Length == 3, "D no combo leaks into the next team")
        Pass("D accepted team switch cancels the pending combo")

        ResetCase("WAITING_COMBO", 0, 0)
        Hoenn222CdCast(1, true, MockTick)
        SolicitarComboHoenn222()
        Assert(Hoenn222_ComboArmed, "E the press armed")
        ResincronizarHoenn222()
        Assert(!Hoenn222_ComboArmed && Hoenn222_State == "WAITING_FIRST_COMBO", "E resync disarms")
        Assert(CdOf(1) == 0 && CdRateOf(1) == 0.5, "E resync also resets the six cooldowns")
        MockTick += 60000
        GameLoop()
        Assert(Scheduled.Length == 0, "E nothing runs after resync")
        ResetCase("WAITING_COMBO", 0, 0)
        Hoenn222CdCast(1, true, MockTick)
        SolicitarComboHoenn222()
        Assert(Hoenn222_ComboArmed, "E the press armed")
        TrocarModo()
        Assert(!Hoenn222_ComboArmed && ModoAtual == "Normal", "E mode change disarms")
        MockTick += 60000
        GameLoop()
        Assert(Scheduled.Length == 0 && Sent.Length == 0, "E nothing runs in another mode")
        Pass("E resync and mode change cancel the pending combo")

        ResetCase("WAITING_COMBO", 0, 0)
        ; O mapeamento tier -> CD vem da tabela do config. Cada tier tem de
        ; devolver o valor declarado, e mudar o rotulo muda so o CD.
        for time in [1, 2, 3]
            for papel in [false, true] {
                tier := papel ? Hoenn222_SecondTier[time] : Hoenn222_TankTier[time]
                Assert(GetHoenn222CdMainMs(time, papel) == Hoenn222_CdByTier[tier],
                    "F dupla " time " " (papel ? "secundario" : "tank") " tier " tier " -> " Hoenn222_CdByTier[tier] "ms")
            }
        ; Tier desconhecido cai no padrao, com aviso unico.
        savedTier2 := Hoenn222_TankTier[2]
        Hoenn222_TankTier[2] := "inexistente"
        global Hoenn222_CdAvisoFeito := false
        Assert(GetHoenn222CdMainMs(2, false) == Hoenn222_CdDefaultMs, "F tier desconhecido usa o padrao")
        Hoenn222_TankTier[2] := savedTier2
        savedTankTier := Hoenn222_TankTier[1]
        Hoenn222_TankTier[1] := "Lendário"
        Assert(GetHoenn222CdMainMs(1, false) == Hoenn222_CdByTier["Lendário"], "F mudar so o rotulo muda so o CD")
        Hoenn222_TankTier[1] := savedTankTier
        Assert(GetHoenn222TierText(9, "tank") == "?", "F unknown team falls back")
        PlanHoenn222()
        Assert(Hoenn222_PlanCache.L > 0 && Hoenn222_PlanCache.Janelas.Length == 3, "F plano em cache com tres janelas")
        ; --- A RECUPERACAO E CONTADA ENTRE DOIS CASTS CONSECUTIVOS ---
        ; O CD nasce no cast e precisa zerar antes do proximo. Nesse intervalo
        ; o Pokemon recupera, e cada segundo conta onde acontecer: logo depois
        ; do cast (1,0x), guardado no meio da volta (0,5x) e DE NOVO fora
        ; durante o lure ANTES do proximo cast (1,0x). O lure nao e tempo
        ; perdido: e o cooldown do cast anterior que continua correndo ali.
        ;   F = tempo total fora entre dois casts
        ;   (F - Lat)*1,0 + (L - F)*0,5 >= CD + Margem
        ;   => F >= 2*(CD + Lat + Margem) - L
        ; Para o tank, F = lure + P: ele so pode ficar fora dentro da janela
        ; dele, da troca ate a chamada do p2.
        ; Para o secundario, F = janela - lure - P.
        ; E as tres janelas somam exatamente L.
        margemEfetiva := Hoenn222_LatencyMs + Hoenn222_MarginMs
        minSec := SleepAfterSwitch + SleepAfterCombo
        for k in [1, 2, 3] {
            cdT := GetHoenn222CdMainMs(k, false)
            cdS := GetHoenn222CdMainMs(k, true)
            F_tank := Max(SleepAfterTankCombo, 2 * (cdT + margemEfetiva) - Hoenn222_PlanCache.L)
            F_sec := Max(minSec, 2 * (cdS + margemEfetiva) - Hoenn222_PlanCache.L)
            lure := Hoenn222_PlanCache.Lures[k]
            ; a janela tem de ser exatamente lure + P + tempo do secundario fora
            Assert(Abs(Hoenn222_PlanCache.Janelas[k] - (lure + SleepAfterTankCombo + (Hoenn222_PlanCache.Janelas[k] - lure - SleepAfterTankCombo))) < 1,
                "F janela " k " = lure + P + sec")
            Assert(Abs(Hoenn222_PlanCache.TankFora[k] - (lure + SleepAfterTankCombo)) < 1,
                "F tank fora " k " = lure " Round(lure) " + P " SleepAfterTankCombo " = " Round(Hoenn222_PlanCache.TankFora[k]))
            Assert(F_tank <= Hoenn222_PlanCache.TankFora[k] + 0.5, "F tank da dupla " k
                " tem tempo fora suficiente: " Round(Hoenn222_PlanCache.TankFora[k]) " >= " Round(F_tank))
            Assert(F_sec <= Hoenn222_PlanCache.SecFora[k] + 0.5, "F secundario da dupla " k
                " tem tempo fora suficiente: " Round(Hoenn222_PlanCache.SecFora[k]) " >= " Round(F_sec))
            ; recuperacao efetiva, conferida pela fisica
            Ftotal := Hoenn222_PlanCache.TankFora[k]
            ; O tank perde a latencia na saida da Ball (troca de time) e no cast.
            recT := (Ftotal - 2 * Hoenn222_LatencyMs)
                + (Hoenn222_PlanCache.L - Ftotal) * Hoenn222_RateInBall
            Assert(recT >= cdT + Hoenn222_MarginMs - 0.5, "F tank " k " recupera "
                Round(recT) "ms para um CD de " cdT "ms")
            FtotS := Hoenn222_PlanCache.SecFora[k]
            ; O secundario perde a latencia na saida da Ball (chamada) e no inicio do CD novo.
            recS := (FtotS - 2 * Hoenn222_LatencyMs)
                + (Hoenn222_PlanCache.L - FtotS) * Hoenn222_RateInBall
            Assert(recS >= cdS + Hoenn222_MarginMs - 0.5, "F secundario " k " recupera "
                Round(recS) "ms para um CD de " cdS "ms")
        }
        ; As tres janelas tem de fechar exatamente em L.
        somaJanelas := Hoenn222_PlanCache.Janelas[1] + Hoenn222_PlanCache.Janelas[2] + Hoenn222_PlanCache.Janelas[3]
        Assert(Abs(somaJanelas - Hoenn222_PlanCache.L) < 1, "F soma das janelas " Round(somaJanelas)
            " = L " Round(Hoenn222_PlanCache.L))
        ; E o piso global de 3,5x: o limite inferior real.
        somaCd := 0
        for k in [1, 2, 3]
            somaCd += GetHoenn222CdMainMs(k, false) + GetHoenn222CdMainMs(k, true)
        ; Os seis perdem 2 latencias por intervalo: saida da Ball e inicio do CD novo.
        pisoGlobal := (somaCd + 6 * (margemEfetiva + Hoenn222_LatencyMs)) / (1 + 5 * Hoenn222_RateInBall)
        Assert(Hoenn222_PlanCache.L >= pisoGlobal - 1, "F L=" Round(Hoenn222_PlanCache.L)
            " respeita o piso de 3,5x com margem " Round(pisoGlobal))
        Assert(Abs(Hoenn222_PlanCache.L - pisoGlobal) < 1, "F L atinge o piso idealizado "
            Round(pisoGlobal))
        ; Nenhum tempo fora pode passar da duracao da volta.
        totalFora := 0
        for k in [1, 2, 3]
            totalFora += Hoenn222_PlanCache.TankFora[k] + Hoenn222_PlanCache.SecFora[k]
        Assert(totalFora <= Hoenn222_PlanCache.L + 0.5, "F soma dos tempos fora "
            Round(totalFora) " cabe na volta " Round(Hoenn222_PlanCache.L))
        ; Janela minima: precisa comportar o combo inteiro.
        minimo := SleepAfterTankCombo + minSec
        for k in [1, 2, 3]
            Assert(Hoenn222_PlanCache.Janelas[k] >= minimo, "F janela da dupla " k " comporta 2700+800+3000")
        ; O plano so depende da configuracao, entao e estavel e fica em cache.
        L1 := Hoenn222_PlanCache.L
        janela1 := Hoenn222_PlanCache.Janelas[1]
        global Hoenn222_PlanCache := false
        plano2 := PlanHoenn222()
        Assert(plano2.L == L1 && plano2.Janelas[1] == janela1, "F mesma configuracao, mesmo plano")
        ; Um tank de CD maior tem de aumentar a volta: e o gargalo real.
        savedTier1 := Hoenn222_TankTier[1]
        Hoenn222_TankTier[1] := "T1"
        global Hoenn222_PlanCache := false
        plano3 := PlanHoenn222()
        Assert(plano3.L > L1, "F tank mais lento aumenta a volta: " Round(L1) " -> " Round(plano3.L))
        Hoenn222_TankTier[1] := savedTier1
        global Hoenn222_PlanCache := false
        PlanHoenn222()
        ResetCase("WAITING_COMBO", 0, 1000)
        AtualizarTooltipsControle()
        Assert(Rendered.Length == 2 && InStr(Rendered[2].text, "Tank: ") && InStr(Rendered[2].text, "Sec: "), "F tiers shown")
        Pass("F tiers, CD and windows all come from config")

        ResetCase("WAITING_COMBO", 0, 0)
        cdT1 := GetHoenn222CdMainMs(1, false)
        Hoenn222CdCast(1, false, MockTick)
        ; O CD so comeca a contar LatencyMs depois do comando; ate la ele vale cheio.
        MockTick += Hoenn222_LatencyMs
        Assert(CdOf(Hoenn222Slot(1, false)) == cdT1, "H cast carrega o CD principal e taxa 1,0 fora da Ball")
        Assert(CdRateOf(Hoenn222Slot(1, false)) == Hoenn222_RateOutOfBall, "H usar a skill implica estar fora da Ball")
        Assert(Hoenn222CdReadyInMs(Hoenn222Slot(1, false), MockTick) == cdT1 + Hoenn222_MarginMs, "H pronto = CD + margem")
        Assert(GetHoenn222ComboTargetMs(1) == cdT1 + Hoenn222_MarginMs, "H alvo de COMBAR segue o CD do tank")
        Assert(GetHoenn222ComboBloqueio(1) == "tank", "H tank segurando o verde")
        Hoenn222CdSetRate(Hoenn222Slot(1, false), Hoenn222_RateInBall, MockTick)
        ; 20000ms dentro da Ball a 0,5 tiram 10000ms de CD, nao 20000.
        MockTick += 20000
        Assert(CdOf(Hoenn222Slot(1, false)) == cdT1 - 10000, "H 20000ms a 0,5 tiram 10000ms de CD")
        Assert(Hoenn222CdReadyInMs(Hoenn222Slot(1, false), MockTick)
            == (cdT1 - 10000) / Hoenn222_RateInBall + Hoenn222_MarginMs, "H dentro da Ball o mesmo CD custa o dobro")
        Pass("H target follows the individual CD and the in-ball rate")

; --- INTERVALOS INTERNOS: NUNCA ESTENDIDOS ---
        ; O macro nao estende a espera entre tank, chamada e secundario. Se o
        ; secundario nao couber, o verde simplesmente nao acende e o macro avisa.
        Assert(SleepAfterTankCombo == 2700, "I animacao do tank continua 2700")
        Assert(SleepAfterSwitch == 800, "I intervalo antes do secundario continua 800")
        ResetCase("WAITING_COMBO", 0, 0)
        Hoenn222CdCast(1, true, MockTick)
        Assert(Hoenn222SecondaryPendenteMs(1, 0) > 0, "I secundario em CD aberto e inviável para comecar agora")
        ComboComplexoHoenn222()
        Scheduled[1].Call()
        Assert(InStr(Join(Timeline), "sleep:2700|send:{2}|sleep:800"), "I a sequencia interna nao e estendida pelo CD")
        Assert(InStr(Join(Timeline), "sleep:3000"), "I pos-combo inalterado")
        Pass("I os intervalos internos 2700/800 nunca sao estendidos")

; --- OTIMIZADOR DESLIGADO: VOLTA AOS ALVOS FIXOS ---
        ; Alvos sao sempre DURACOES contadas do inicio do estado, nos dois modos.
        ResetCase("WAITING_COMBO", 0, 0)
        Hoenn222_CdOptimizerEnabled := false
        Assert(RealBaseTarget("WAITING_COMBO", 1) == Hoenn222_ComboTargetMs[1], "J sem otimizador usa o alvo fixo de COMBAR")
        Assert(RealBaseTarget("WAITING_TEAM_SWITCH", 1) == Hoenn222_SwitchTargetMs[1], "J alvo fixo de TROCAR TIME")
        Assert(GetHoenn222PendingMs() == Hoenn222_ComboTargetMs[1], "J o pendente e o alvo menos o decorrido")
        Hoenn222_CdOptimizerEnabled := true
        Assert(RealBaseTarget("WAITING_COMBO", 1) == GetHoenn222ComboTargetMs(1), "J com otimizador COMBAR vem do CD real")
        Assert(RealBaseTarget("WAITING_COMBO", 1) == 0, "J sem CD, COMBAR ja esta pronto")
        janela := GetHoenn222SwitchTargetMs(1)
        ; A janela do plano comeca na troca de time; este estado comeca no cast,
        ; lure depois. O que falta da janela e P + secundario fora.
        Assert(janela == Hoenn222_PlanCache.Janelas[1] - Hoenn222_PlanCache.Lures[1], "J TROCAR TIME usa a janela planejada menos o lure")
        Assert(janela == SleepAfterTankCombo + Hoenn222_PlanCache.SecFora[1], "J ... = P + secundario fora")
        Assert(janela >= SleepAfterTankCombo + SleepAfterSwitch + SleepAfterCombo, "J a janela cobre o combo inteiro")
        Assert(RealBaseTarget("WAITING_TEAM_SWITCH", 1) == janela, "J a janela tambem e uma duracao")
        Assert(GetHoenn222PendingMs() == 0, "J pendente com todos os CD zerados")
        MockTick += 1000
        Assert(GetHoenn222PendingMs() == 0, "J CD zerado nao volta a exigir tempo so porque o relogio andou")
        ; A janela de TROCAR TIME e uma duracao desde o inicio do estado: ai o
        ; decorrido desconta de verdade.
        Hoenn222_State := "WAITING_TEAM_SWITCH"
        Hoenn222_StateStartTick := MockTick - 1000
        Assert(GetHoenn222PendingMs() == janela - 1000, "J 1000ms decorridos tiram 1000ms da janela")
        Pass("J desligar o otimizador volta aos alvos fixos sem nenhuma outra mudanca")

; --- TESTE DA PREMISSA: o lure ANTES do proximo cast recupera o CD ---
        ; Um tank faz o cast, fica fora um tempo, e guardado, volta na volta
        ; seguinte e fica fora de novo durante o lure ANTES do proximo cast.
        ; Os DOIS periodos precisam contar para o mesmo cooldown. Se o
        ; planejador so considerasse o trecho pos-cast, este teste falha.
        ResetCase("WAITING_COMBO", 0, 0)
        cdTeste := 45000.0
        slotTeste := Hoenn222Slot(1, false)
        Hoenn222CdCast(1, false, MockTick)          ; 1) o cast comeca o CD
        Hoenn222CdSetRate(slotTeste, Hoenn222_RateOutOfBall, MockTick)
        MockTick += SleepAfterTankCombo              ; fora durante o P do p2
        Hoenn222CdSetRate(slotTeste, Hoenn222_RateInBall, MockTick)
        MockTick += 30000                             ; 2) guardado a 0,5x
        Hoenn222CdSetRate(slotTeste, Hoenn222_RateOutOfBall, MockTick) ; 3) volta a sair
        duracaoLure := 12871.0
        MockTick += duracaoLure                      ; lure ANTES do proximo cast
        cdRestante := CdOf(slotTeste)
        Assert(cdRestante > 0, "L ainda ha CD a recuperar: " Round(cdRestante))
        Assert(cdRestante < cdTeste, "L o lure reduziu o CD: de " cdTeste " para " Round(cdRestante))
        ganhoDoLure := duracaoLure * Hoenn222_RateOutOfBall
        Assert(ganhoDoLure > 0 && CdOf(slotTeste) < cdRestante + ganhoDoLure,
            "L o lure contribuiu " Round(ganhoDoLure) "ms")
        ; Com o plano real, F do tank = lure + P cobre 2*(CD+Lat+Marg) - L
        ; (o cache e invalido no ResetCase acima, entao recalcula)
        planoL := PlanHoenn222()
        Fplano := planoL.TankFora[1]
        exigido := 2 * (cdTeste + Hoenn222_LatencyMs + Hoenn222_MarginMs) - Hoenn222_PlanCache.L
        Assert(Fplano >= exigido, "L F do tank " Round(Fplano) " cobre o exigido " Round(exigido))
        Assert(Fplano > SleepAfterTankCombo, "L F do tank " Round(Fplano)
            " e maior que so o pos-cast " SleepAfterTankCombo)
        Pass("L o lure antes do proximo cast recupera o cooldown do cast anterior")

        ResetCase()
        ComboComplexoHoenn222()
        Assert(Scheduled.Length == 1 && isRodizioAtivo, "K combo scheduling unchanged")
        Scheduled[1].Call()
        Assert(CdOf(Hoenn222Slot(1, false)) == GetHoenn222CdMainMs(1, false), "K tank CD restarted by its own cast")
        ; A chamada do p2 leva o tank de volta para a Ball: so um Pokemon fora
        ; por vez. Sem isso a capacidade da volta viraria 4,0x em vez de 3,5x.
        Assert(CdRateOf(Hoenn222Slot(1, false)) == Hoenn222_RateInBall, "K tank volta para a Ball quando o p2 e chamado")
        Assert(CdRateOf(Hoenn222Slot(1, true)) == Hoenn222_RateOutOfBall, "K secundario assume o posto fora da Ball")
        ; Invariante: nunca dois fora da Ball ao mesmo tempo.
        fora := 0
        for i in [1, 2, 3, 4, 5, 6]
            fora += CdRateOf(i) >= 1.0 ? 1 : 0
        Assert(fora <= 1, "K no maximo um Pokemon fora da Ball: " fora)
        Assert(InStr(DebugText(), "CD_CAST"), "K cast recorded in the diagnostics")
        ; Entrada em campo (chamada do secundario): o CD que o modelo espera fica no log
        ; para ser comparado com os contadores da barra de golpes do jogo.
        Assert(RegExMatch(DebugText(), "CD_ENTRADA \| slot=2 time=1 papel=sec cd_modelo_ms=\d+ taxa="), "K entrada do secundario registrada")
        Pass("K the combo registers both casts on the right slots")

; --- INDICADOR E DECISAO DO BOTAO: A MESMA RESPOSTA ---
        ; Regra do jogador: verde = o botao executa na hora; qualquer outra cor
        ; = o botao NAO executa na hora (arma e espera). O quadrado e o botao
        ; leem o mesmo pendente, entao nao podem divergir.

        ; Primeiro combo: executa na hora, portanto tem de estar verde. Amarelo
        ; aqui parecia "espere" e o botao executava assim mesmo.
        ResetCase("WAITING_FIRST_COMBO", 0, 0)
        corPrimeiro := ""
        GetHoenn222CentralTooltip(&corPrimeiro)
        Assert(corPrimeiro == "33CC66", "M primeiro combo: indicador verde, cor=" corPrimeiro)
        SolicitarComboHoenn222()
        Assert(Scheduled.Length == 1 && !Hoenn222_ComboArmed, "M primeiro combo executa na hora")

        ; Para varios instantes de uma volta real, cor e acao concordam.
        ResetCase("WAITING_COMBO", 0, 0)
        Hoenn222CdCast(1, false, MockTick - 20000)
        Hoenn222CdSetRate(Hoenn222Slot(1, false), Hoenn222_RateInBall, MockTick - 17000)
        Hoenn222CdTrocaTime(3, 1, MockTick)
        Hoenn222_State := "WAITING_COMBO"
        Hoenn222_StateStartTick := MockTick
        entrada := MockTick
        prontoReal := Hoenn222CdReadyInMs(Hoenn222Slot(1, false), MockTick)
        Assert(prontoReal > 5000, "M cenario: o tank entra com CD correndo (" Round(prontoReal) "ms)")
        divergiu := ""
        verdeEm := -1
        passo := 0
        while (passo <= prontoReal + 2000) {
            MockTick := entrada + passo
            cor := ""
            GetHoenn222CentralTooltip(&cor)
            pend := GetHoenn222PendingMs()
            if ((cor == "33CC66") != (pend <= 0))
                divergiu .= " t=" passo ":cor=" cor "/pend=" Round(pend)
            if (verdeEm < 0 && pend <= 0)
                verdeEm := passo
            passo += 250
        }
        Assert(divergiu == "", "M cor e decisao divergiram:" divergiu)
        ; O verde nunca vem antes de o tank estar de fato pronto. O instante
        ; verdadeiro e CD + margem; a varredura em passos de 250ms so pode
        ; passar dele por menos de um passo.
        Assert(verdeEm >= prontoReal - 1 && verdeEm < prontoReal + 250,
            "M verde em " verdeEm "ms, tank pronto de verdade em " Round(prontoReal) "ms")
        Pass("M o indicador e a decisao do botao leem o mesmo pendente; o verde nao antecipa o CD")

        ; Margem conta desde o instante em que o CD zerou, nao para sempre.
        ResetCase("WAITING_COMBO", 0, 0)
        slotM := Hoenn222Slot(1, false)
        Hoenn222CdCast(1, false, MockTick)
        MockTick += Hoenn222_LatencyMs + GetHoenn222CdMainMs(1, false)   ; CD zera aqui
        Assert(Hoenn222CdReadyInMs(slotM, MockTick) == Hoenn222_MarginMs, "N no instante em que zera ainda falta a margem")
        MockTick += Hoenn222_MarginMs - 50
        Assert(Hoenn222CdReadyInMs(slotM, MockTick) == 50, "N faltam 50ms da margem")
        MockTick += 50
        Assert(Hoenn222CdReadyInMs(slotM, MockTick) == 0, "N margem cumprida: pronto")
        MockTick += 600000
        Assert(Hoenn222CdReadyInMs(slotM, MockTick) == 0, "N CD zerado ha muito tempo continua pronto, sem exigir margem de novo")
        Pass("N a margem conta a partir do instante em que o CD zerou")

        ; Pedido armado e visivel no quadrado: violeta, e vira verde ao disparar.
        ResetCase("WAITING_COMBO", 0, 0)
        Hoenn222CdCast(1, true, MockTick)
        corAntes := ""
        GetHoenn222CentralTooltip(&corAntes)
        Assert(corAntes != "33CC66" && corAntes != "B266FF", "O sem pedido, secundario em CD: cor de espera " corAntes)
        SolicitarComboHoenn222()
        Assert(Hoenn222_ComboArmed, "O pressionar antes do verde arma")
        corArmado := ""
        GetHoenn222CentralTooltip(&corArmado)
        Assert(corArmado == "B266FF", "O armado e visivel no quadrado, cor=" corArmado)
        Pass("O o pedido armado muda a cor do quadrado")

; --- GATILHO DE TROCA: A MESMA REGRA DO COMBO ---
        ; Amarelo nao troca na hora: arma e troca sozinho no instante do verde.
        ; Verde troca na hora. Duplo acionamento troca na hora.

        ; TROCAR TIME amarelo: arma, nada e enviado.
        ResetCase("WAITING_TEAM_SWITCH", 0, 3000)
        janelaP := GetHoenn222SwitchTargetMs(1)
        Assert(GetHoenn222PendingMs() == janelaP - 3000 && janelaP > 3000, "P cenario: TROCAR TIME amarelo")
        Acao_Gatilhos("controller")
        Assert(Hoenn222_SwitchArmed && Hoenn222_SwitchArmedTeam == 1, "P gatilho em amarelo arma a troca")
        Assert(Sent.Length == 0 && TimeAtual == 1, "P nada enviado e o time nao mudou")
        corP := ""
        GetHoenn222CentralTooltip(&corP)
        Assert(corP == "B266FF", "P o quadrado mostra o pedido armado, cor=" corP)
        Assert(InStr(GetHoenn222Tooltip(), "TROCA ARMADA"), "P o tooltip avisa a troca armada")
        Assert(InStr(DebugText(), "SWITCH_ARMED"), "P registrado no diagnostico")
        ; Varredura de 30 ms antes do verde nao dispara; 1 ms antes tambem nao.
        MockTick += janelaP - 3000 - 1
        GameLoop()
        Assert(Scheduled.Length == 0 && Hoenn222_SwitchArmed, "P 1ms antes do verde ainda espera")
        ; No instante exato do verde, dispara sozinho, uma unica vez.
        MockTick += 1
        GameLoop()
        Assert(Scheduled.Length == 1 && Hoenn222_SwitchArmed && Sent.Length == 0, "P no verde o laco so agenda a thread descartavel")
        GameLoop()
        Assert(Scheduled.Length == 1, "P varreduras seguintes nao duplicam")
        Scheduled[1].Call()
        Assert(!Hoenn222_SwitchArmed, "P a thread descartavel consome o pedido")
        AssertAcceptedSequence()
        Assert(Hoenn222_State == "WAITING_COMBO" && InStr(DebugText(), "SWITCH_FIRED"), "P a troca antecipada cumpriu a sequencia de sempre")
        Assert(RegExMatch(DebugText(), "CD_ENTRADA \| slot=3 time=2 papel=tank cd_modelo_ms=\d+ taxa="), "P entrada do tank novo registrada na troca")
        Pass("P gatilho em amarelo arma e troca sozinho no instante do verde")

        ; TROCAR TIME verde: troca na hora, sem armar.
        ResetCase("WAITING_TEAM_SWITCH", 0, 40000)
        Acao_Gatilhos("mouse")
        AssertAcceptedSequence()
        Assert(!Hoenn222_SwitchArmed && InStr(DebugText(), "result=immediate"), "Q verde troca na hora")
        Pass("Q gatilho em verde troca na hora")

        ; Duplo acionamento em amarelo: emergencia, troca na hora e consome o pedido.
        ResetCase("WAITING_TEAM_SWITCH", 0, 3000)
        Acao_Gatilhos("controller")
        Assert(Hoenn222_SwitchArmed && Sent.Length == 0, "R primeira pressao arma")
        MockTick += Hoenn222_EmergencyWindowMs
        Acao_Gatilhos("controller")
        AssertAcceptedSequence()
        Assert(!Hoenn222_SwitchArmed && InStr(DebugText(), "result=emergency"), "R segunda pressao troca na hora e limpa o pedido")
        MockTick += 60000
        GameLoop()
        Assert(Scheduled.Length == 0, "R o pedido consumido nao dispara depois")
        ; Janela 0 desliga a emergencia, so resta o pedido antecipado.
        savedWindow := Hoenn222_EmergencyWindowMs
        Hoenn222_EmergencyWindowMs := 0
        ResetCase("WAITING_TEAM_SWITCH", 0, 3000)
        Acao_Gatilhos("controller")
        MockTick += 1
        Acao_Gatilhos("controller")
        Assert(Sent.Length == 0 && Hoenn222_SwitchArmed, "R janela 0 desliga a emergencia")
        Hoenn222_EmergencyWindowMs := savedWindow
        Pass("R duplo acionamento troca na hora; janela 0 desliga")

        ; Ainda na fase do combo: a troca fica armada e so sai depois do combo e do verde.
        ResetCase("WAITING_COMBO", 0, 1000)
        Hoenn222CdCast(1, true, MockTick)
        Acao_Gatilhos("controller")
        Assert(Hoenn222_SwitchArmed && Sent.Length == 0 && TimeAtual == 1, "S em COMBAR o gatilho arma, nao troca")
        MockTick += 60000
        GameLoop()
        Assert(Scheduled.Length == 0 && Hoenn222_SwitchArmed, "S sem combo feito nao troca, mesmo com o tempo passando")
        ; O combo desta dupla acontece; o pedido de troca sobrevive a ele.
        ComboComplexoHoenn222()
        Assert(Hoenn222_SwitchArmed, "S o combo nao consome o pedido de troca")
        Scheduled[1].Call()
        Assert(Hoenn222_State == "WAITING_TEAM_SWITCH" && Hoenn222_SwitchArmed, "S depois do combo espera o verde de TROCAR TIME")
        GameLoop()
        Assert(Scheduled.Length == 1, "S ainda amarelo: nao agenda troca")
        MockTick += GetHoenn222SwitchTargetMs(1) + 1
        GameLoop()
        Assert(Scheduled.Length == 2 && Hoenn222_SwitchArmed, "S no verde de TROCAR TIME a troca e agendada")
        Scheduled[2].Call()
        Assert(!Hoenn222_SwitchArmed && TimeAtual == 2, "S a thread descartavel faz a troca")
        Pass("S gatilho em COMBAR espera o combo e depois o verde da troca")

        ; Troca armada nunca vale para outro time, modo ou apos F8.
        ResetCase("WAITING_TEAM_SWITCH", 0, 3000)
        Acao_Gatilhos("controller")
        Assert(Hoenn222_SwitchArmed, "T armada")
        ResincronizarHoenn222()
        Assert(!Hoenn222_SwitchArmed && InStr(DebugText(), "SWITCH_DISARMED"), "T F8 desarma")
        ResetCase("WAITING_TEAM_SWITCH", 0, 3000)
        Acao_Gatilhos("controller")
        TrocarModo()
        Assert(!Hoenn222_SwitchArmed, "T troca de modo desarma")
        ResetCase("WAITING_TEAM_SWITCH", 0, 3000)
        Acao_Gatilhos("controller")
        TimeAtual := 2
        MockTick += 60000
        GameLoop()
        Assert(!Hoenn222_SwitchArmed && Scheduled.Length == 0 && Sent.Length == 0, "T time diferente: nao troca em outro time")
        Pass("T troca armada e cancelada por F8, modo e mudanca de time")

        ; Combo armado e troca armada coexistem sem se consumir.
        ResetCase("WAITING_COMBO", 0, 1000)
        Hoenn222CdCast(1, true, MockTick)
        SolicitarComboHoenn222()
        Acao_Gatilhos("controller")
        Assert(Hoenn222_ComboArmed && Hoenn222_SwitchArmed, "U combo e troca armados ao mesmo tempo")
        Pass("U combo armado e troca armada sao independentes")

        ; Modo 3-3 e Normal nao mudam.
        ResetCase("WAITING_TEAM_SWITCH", 0, 3000)
        ModoAtual := "Hoenn33"
        Acao_Gatilhos("controller")
        Assert(!Hoenn222_SwitchArmed && TimeAtual == 2, "V modo 3-3 troca na hora como sempre")
        Pass("V modos 3-3 e Normal inalterados")
; --- PRIMEIRA VOLTA: O RITMO DO PLANO VALE DESDE O PRIMEIRO CICLO ---
        ; Depois do F8 os seis estao com o CD pronto. Sem ritmo, a troca para o time
        ; 2 liberava o combo na hora (CD zero) e a espera inteira caia na volta do
        ; time 1. Ate o primeiro cast do time, o verde respeita o lure do plano.
        ResetCase("WAITING_COMBO", 0, 0)
        Hoenn222_TeamCasted := Map(1, false, 2, false, 3, false)
        lureW := PlanHoenn222().Lures[2]
        Assert(lureW > 10000, "W cenario: lure planejado " Round(lureW) "ms")
        TimeAtual := 2
        Hoenn222_StateStartTick := MockTick
        Assert(GetHoenn222ComboTargetMs(2) == lureW, "W logo apos a troca o CD zerado NAO libera: falta o lure, " GetHoenn222ComboTargetMs(2))
        corW := ""
        GetHoenn222CentralTooltip(&corW)
        Assert(corW != "33CC66", "W o quadrado NAO fica verde ao trocar de time, cor=" corW)
        Assert(GetHoenn222ComboBloqueio(2) == "primeira_volta", "W o tooltip sabe quem segura: " GetHoenn222ComboBloqueio(2))
        ; Azul nos ultimos 10 s, verde no instante exato do lure.
        MockTick += lureW - 10000
        corW := ""
        GetHoenn222CentralTooltip(&corW)
        Assert(corW == "33A3FF", "W faltando 10 s o quadrado fica azul, cor=" corW)
        ; Em amarelo/azul o combo arma em vez de executar.
        SolicitarComboHoenn222()
        Assert(Hoenn222_ComboArmed && Scheduled.Length == 0, "W combo antes do verde arma e espera o ritmo")
        MockTick += 10000 - 1
        GameLoop()
        Assert(Scheduled.Length == 0, "W 1ms antes do lure ainda espera")
        MockTick += 1
        GameLoop()
        Assert(Scheduled.Length == 1 && Hoenn222_ComboArmed, "W no instante do lure o combo armado agenda o disparo")
        Scheduled[1].Call()
        Assert(Scheduled.Length == 2 && isRodizioAtivo, "W e o disparo agenda o rodizio")
        Scheduled[2].Call()
        Assert(Hoenn222_TeamCasted[2], "W o primeiro cast do time encerra o ritmo da primeira volta")
        Pass("W primeira volta: o CD zerado nao libera o combo antes do lure planejado")

        ; Depois do primeiro cast quem manda e so o cooldown real.
        ResetCase("WAITING_COMBO", 0, 0)
        Hoenn222_TeamCasted := Map(1, false, 2, false, 3, false)
        Hoenn222CdCast(1, false, MockTick - 60000)   ; cast ha 60 s: CD 45 s ja zerou
        Assert(Hoenn222_TeamCasted[1], "X o cast marca o time")
        Assert(GetHoenn222ComboTargetMs(1) == 0, "X com o time ja castado e CD zerado esta pronto")
        ; F8 volta a ligar o ritmo para todos.
        ResincronizarHoenn222()
        Assert(!Hoenn222_TeamCasted[1] && !Hoenn222_TeamCasted[2] && !Hoenn222_TeamCasted[3], "X F8 liga o ritmo da primeira volta de novo")
        Pass("X o ritmo da primeira volta acaba no primeiro cast e volta com o F8")

        ; Ciclo completo simulado com as funcoes de producao: o jogador so deixa
        ; o macro agir no verde. Os casts do tank 1 em duas voltas tem de distar L.
        ResetCase("WAITING_FIRST_COMBO", 0, 0)
        Hoenn222_TeamCasted := Map(1, false, 2, false, 3, false)
        ResetarCooldownsHoenn222(MockTick)
        planoY := PlanHoenn222()
        casts1 := []
        eventos := []
        fim := MockTick + 250000
        proxEvento := 0
        while (MockTick < fim && casts1.Length < 3) {
            if (Hoenn222_State == "WAITING_FIRST_COMBO" || (Hoenn222_State == "WAITING_COMBO" && GetHoenn222PendingMs() <= 0)) {
                tm := TimeAtual
                if (tm == 1)
                    casts1.Push(MockTick)
                eventos.Push("t=" Round((MockTick - 100000) / 1000, 1) " COMBO time " tm)
                Hoenn222_State := "WAITING_TEAM_SWITCH"
                Hoenn222_StateStartTick := MockTick
                Hoenn222CdRegistrarCast(tm)
                t0Y := MockTick
                p2Y := t0Y + SleepAfterTankCombo
                c2Y := p2Y + SleepAfterSwitch
                passoY := 0
            }
            if (IsSet(p2Y) && p2Y > 0 && MockTick >= p2Y) {
                Hoenn222CdRegistrarChamada(TimeAtual)
                p2Y := 0
            }
            if (IsSet(c2Y) && c2Y > 0 && MockTick >= c2Y) {
                Hoenn222CdRegistrarCast(TimeAtual, true)
                c2Y := 0
            }
            if (Hoenn222_State == "WAITING_TEAM_SWITCH" && GetHoenn222PendingMs() <= 0) {
                eventos.Push("t=" Round((MockTick - 100000) / 1000, 1) " TROCA do time " TimeAtual)
                TrocarTimeHoenn(3)
            }
            MockTick += 10
        }
        Assert(casts1.Length == 3, "Y tres casts do time 1 simulados: " casts1.Length)
        volta1 := casts1[2] - casts1[1]
        volta2 := casts1[3] - casts1[2]
        resumo := ""
        for ev in eventos
            resumo .= ev " | "
        Assert(Abs(volta1 - planoY.L) < 400, "Y 1a volta = L do plano: " Round(volta1) " vs " Round(planoY.L) " :: " resumo)
        Assert(Abs(volta2 - planoY.L) < 400, "Y 2a volta = L do plano: " Round(volta2) " vs " Round(planoY.L))
        Pass("Y simulacao: a primeira volta ja dura o L do plano, sem a espera acumulada no time 1")
; --- MARGEM RESPEITADA EM TODO CAST (REGRESSAO DO TESTE EM JOGO) ---
        ; Com um jogador que age exatamente no verde, nenhum cast pode acontecer
        ; antes de CD zerado + margem. O secundario perdia a margem inteira porque a
        ; tolerancia ignorava a latencia da chamada: era usado ~10 ms depois do CD
        ; zerar em vez de 250 ms.
        ResetCase("WAITING_FIRST_COMBO", 0, 0)
        Hoenn222_TeamCasted := Map(1, false, 2, false, 3, false)
        ResetarCooldownsHoenn222(MockTick)
        pioresFolgas := Map("tank", 999999, "sec", 999999)
        voltaZ := 0
        p2Z := 0
        c2Z := 0
        tmZ := 1
        fimZ := MockTick + 330000
        while (MockTick < fimZ) {
            if (Hoenn222_State == "WAITING_FIRST_COMBO" || (Hoenn222_State == "WAITING_COMBO" && GetHoenn222PendingMs() <= 0)) {
                tmZ := TimeAtual
                if (tmZ == 1)
                    voltaZ += 1
                if (voltaZ >= 2) {
                    slotZ := Hoenn222Slot(tmZ, false)
                    CdOf(slotZ)
                    folga := (Hoenn222_Cd[slotZ] > 0) ? -Hoenn222_Cd[slotZ] : (MockTick - Hoenn222_CdZeroTick[slotZ] - Hoenn222_MarginMs)
                    pioresFolgas["tank"] := Min(pioresFolgas["tank"], folga)
                }
                Hoenn222_State := "WAITING_TEAM_SWITCH"
                Hoenn222_StateStartTick := MockTick
                Hoenn222CdRegistrarCast(tmZ)
                p2Z := MockTick + SleepAfterTankCombo
                c2Z := p2Z + SleepAfterSwitch
            }
            if (p2Z > 0 && MockTick >= p2Z) {
                Hoenn222CdRegistrarChamada(tmZ)
                p2Z := 0
            }
            if (c2Z > 0 && MockTick >= c2Z) {
                if (voltaZ >= 2) {
                    slotZ := Hoenn222Slot(tmZ, true)
                    CdOf(slotZ)
                    folga := (Hoenn222_Cd[slotZ] > 0) ? -Hoenn222_Cd[slotZ] : (MockTick - Hoenn222_CdZeroTick[slotZ] - Hoenn222_MarginMs)
                    pioresFolgas["sec"] := Min(pioresFolgas["sec"], folga)
                }
                Hoenn222CdRegistrarCast(tmZ, true)
                c2Z := 0
            }
            if (Hoenn222_State == "WAITING_TEAM_SWITCH" && GetHoenn222PendingMs() <= 0)
                TrocarTimeHoenn(3)
            MockTick += 10
        }
        Assert(voltaZ >= 4, "Z simulou voltas suficientes: " voltaZ)
        ; Passo da simulacao e 10 ms: tolera esse arredondamento, nada alem.
        Assert(pioresFolgas["tank"] >= -10, "Z tank respeita a margem (pior folga " Round(pioresFolgas["tank"]) "ms)")
        Assert(pioresFolgas["sec"] >= -10, "Z secundario respeita a margem (pior folga " Round(pioresFolgas["sec"]) "ms)")
        Pass("Z em ciclo perfeito todo cast, tank e secundario, ocorre depois de CD zerado + margem")
; --- PISOS DE CONFORTO: TEMPO FORA MINIMO DO TANK E DO SECUNDARIO ---
        ; O plano de volta minima usa so o cooldown. Os pisos dao ao jogador tempo
        ; para chegar ao ponto e puxar; o planejador acha a menor volta que cabe.
        ResetCase("WAITING_COMBO", 0, 0)
        planoBase := PlanHoenn222()
        LBase := planoBase.L
        secBase := planoBase.SecFora[1]
        ResetCase("WAITING_COMBO", 0, 0)
        Hoenn222_MinLureMs := Map(1, 15000, 2, 15000, 3, 15000)
        Hoenn222_MinSecondaryOutMs := Map(1, 8000, 2, 0, 3, 0)
        planoC := PlanHoenn222()
        for k in [1, 2, 3]
            Assert(planoC.Lures[k] >= 15000 - 0.5, "AA lure da dupla " k " respeita o piso: " Round(planoC.Lures[k]))
        Assert(planoC.SecFora[1] >= 8000 - 0.5, "AA secundario da dupla 1 respeita o piso: " Round(planoC.SecFora[1]))
        Assert(planoC.L > LBase && planoC.L < LBase + 7000, "AA a volta cresce, mas bem menos que a soma dos pisos: " Round(LBase) " -> " Round(planoC.L))
        somaC := planoC.Janelas[1] + planoC.Janelas[2] + planoC.Janelas[3]
        Assert(Abs(somaC - planoC.L) < 1, "AA as tres janelas fecham em L: " Round(somaC) " vs " Round(planoC.L))
        ; Nenhum Pokemon fica sem o CD recuperado so porque o piso mexeu na volta.
        mEf := Hoenn222_LatencyMs + Hoenn222_MarginMs
        for k in [1, 2, 3] {
            FtT := planoC.TankFora[k]
            recT := (FtT - 2 * Hoenn222_LatencyMs) + (planoC.L - FtT) * Hoenn222_RateInBall
            Assert(recT >= GetHoenn222CdMainMs(k, false) + Hoenn222_MarginMs - 0.5, "AA tank " k " continua recuperando o CD: " Round(recT))
            FtS := planoC.SecFora[k]
            recS := (FtS - 2 * Hoenn222_LatencyMs) + (planoC.L - FtS) * Hoenn222_RateInBall
            Assert(recS >= GetHoenn222CdMainMs(k, true) + Hoenn222_MarginMs - 0.5, "AA secundario " k " continua recuperando o CD: " Round(recS))
        }
        ; Piso de lure: o combo nunca e liberado antes dele, mesmo com o CD pronto.
        ResetCase("WAITING_COMBO", 0, 0)
        Hoenn222_MinLureMs := Map(1, 15000, 2, 15000, 3, 15000)
        Assert(GetHoenn222ComboTargetMs(1) == 15000, "AA com CD pronto o combo espera o piso de lure")
        MockTick += 15000 - 1
        Assert(GetHoenn222PendingMs() == 1, "AA falta 1 ms para o piso")
        MockTick += 1
        Assert(GetHoenn222PendingMs() <= 0, "AA no piso libera")
        Pass("AA pisos de conforto: planejador respeita, volta cresce o minimo, CD segue recuperado")

        ; Valores invalidos no config nunca derrubam o plano: valem 0.
        ResetCase("WAITING_COMBO", 0, 0)
        Hoenn222_MinLureMs := Map(1, -5000, 2, "abc", 3, "")
        Hoenn222_MinSecondaryOutMs := 7
        planoI := PlanHoenn222()
        Assert(Abs(planoI.L - LBase) < 1, "AB config invalida volta ao plano minimo: " Round(planoI.L))
        Pass("AB piso invalido no config vale 0 e nao quebra o plano")

        ; Ciclo completo com pisos: a volta medida e a do plano e o lure real e o piso.
        ResetCase("WAITING_FIRST_COMBO", 0, 0)
        Hoenn222_MinLureMs := Map(1, 15000, 2, 15000, 3, 15000)
        Hoenn222_MinSecondaryOutMs := Map(1, 8000, 2, 0, 3, 0)
        Hoenn222_TeamCasted := Map(1, false, 2, false, 3, false)
        ResetarCooldownsHoenn222(MockTick)
        planoS := PlanHoenn222()
        castsS := []
        luresS := []
        trocaS := MockTick
        p2S := 0
        c2S := 0
        tmS := 1
        fimS := MockTick + 400000
        while (MockTick < fimS && castsS.Length < 5) {
            if (Hoenn222_State == "WAITING_FIRST_COMBO" || (Hoenn222_State == "WAITING_COMBO" && GetHoenn222PendingMs() <= 0)) {
                tmS := TimeAtual
                if (tmS == 1)
                    castsS.Push(MockTick)
                if (castsS.Length >= 2)
                    luresS.Push(MockTick - trocaS)
                Hoenn222_State := "WAITING_TEAM_SWITCH"
                Hoenn222_StateStartTick := MockTick
                Hoenn222CdRegistrarCast(tmS)
                p2S := MockTick + SleepAfterTankCombo
                c2S := p2S + SleepAfterSwitch
            }
            if (p2S > 0 && MockTick >= p2S) {
                Hoenn222CdRegistrarChamada(tmS)
                p2S := 0
            }
            if (c2S > 0 && MockTick >= c2S) {
                Hoenn222CdRegistrarCast(tmS, true)
                c2S := 0
            }
            if (Hoenn222_State == "WAITING_TEAM_SWITCH" && GetHoenn222PendingMs() <= 0) {
                trocaS := MockTick
                TrocarTimeHoenn(3)
            }
            MockTick += 10
        }
        Assert(castsS.Length == 5, "AC simulou voltas suficientes")
        Assert(Abs((castsS[3] - castsS[2]) - planoS.L) < 400, "AC a volta medida e a do plano: " Round(castsS[3] - castsS[2]) " vs " Round(planoS.L))
        menorLure := 999999
        for v in luresS
            menorLure := Min(menorLure, v)
        Assert(menorLure >= 15000 - 20, "AC o tank nunca combou antes do piso de lure: menor " menorLure "ms")
        Pass("AC simulacao com pisos: volta = plano e o tank sempre fica fora ao menos o piso")
        FileAppend("RESULT: " PassCount " test groups passed; no game commands executed.`n", "*", "UTF-8")
    } catch as e {
        FileAppend("FAIL: " e.Message " | " e.What " | line=" e.Line "`n", "*", "UTF-8")
        ExitApp(1)
    }
}
RunBaseline() {
    global
    try {
        ResetCase()
        FaultLogger := true
        caught := false
        try TrocarTimeHoenn(3)
        catch as e {
            caught := true
            Assert(e.Message == "simulated logger failure", "baseline logger exception")
        }
        Assert(caught && TimeAtual == 2 && Sent.Length == 0, "baseline advanced team with zero sends")
        Pass("BASELINE logger throws: TimeAtual=2, ControlSend count=0")

        ResetCase()
        CurrentSessionLogFile := A_ScriptDir "\nonexistent\session.log"
        caught := false
        try Acao_Gatilhos()
        catch as e {
            caught := true
            Assert(e.What == "FileAppend", "baseline real logger I/O error source")
        }
        Assert(caught && TimeAtual == 2 && Sent.Length == 0, "baseline actual FileAppend failure blocks switch")
        Pass("BASELINE real FileAppend failure: propagated through Acao_Gatilhos, TimeAtual=2, ControlSend count=0")

        ResetCase("WAITING_COMBO", 1234, 2000)
        FaultDebt := true
        caught := false
        try TrocarTimeHoenn(3)
        catch as e {
            caught := true
            Assert(e.Message == "simulated GetHoenn222BaseTargetMs failure", "baseline debt exception")
        }
        Assert(caught && TimeAtual == 2 && Sent.Length == 0, "baseline debt blocks command after advance")
        Assert(Hoenn222_LastTeamSwitchTick == MockTick, "baseline debounce armed despite zero sends")
        Pass("BASELINE debt throws: TimeAtual=2, ControlSend count=0, debounce already armed")

        ResetCase("WAITING_COMBO", 0, 2000)
        FaultDebt := true
        MockInput.bRightTrigger := 255
        caught := false
        try GameLoop()
        catch {
            caught := true
        }
        Assert(caught && Scheduled.Length == 0 && Sent.Length == 0, "baseline tooltip blocks controller dispatch")
        Pass("BASELINE tooltip calculation throws: controller callbacks scheduled=0")
        FileAppend("RESULT: " PassCount " baseline defects reproduced in AutoHotkey v2.`n", "*", "UTF-8")
    } catch as e {
        FileAppend("FAIL: " e.Message " | line=" e.Line "`n", "*", "UTF-8")
        ExitApp(1)
    }
}

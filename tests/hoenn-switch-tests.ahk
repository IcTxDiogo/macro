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
    Hoenn222_Cd := [0, 0, 0, 0, 0, 0]
    Hoenn222_CdRate := [0, 0, 0, 0, 0, 0]
    Hoenn222_CdSince := [0, 0, 0, 0, 0, 0]
    global Hoenn222_PlanCache := false
    Hoenn222_CdAvisoFeito := false
    Hoenn222_CdOptimizerEnabled := true
    ResetarCooldownsHoenn222(MockTick)
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

        ResetCase("WAITING_TEAM_SWITCH", 0, 3000)
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

        ResetCase("WAITING_COMBO", 0, 16000)
        Assert(GetHoenn222CdMainMs(1, false) == 40000, "C tier Lendario = 40s")
        Assert(GetHoenn222CdMainMs(1, true) == 43000, "C tier UR = 43s")
        Hoenn222CdCast(1, false, MockTick - 4000)
        Hoenn222CdCast(1, true, MockTick - 500)
        Acao_Gatilhos()
        AssertAcceptedSequence()
        MockTick += 60000
        Assert(CdOf(Hoenn222Slot(2, false)) == 0, "C CD chega a zero e trava em zero")
        ; tank: 40000 - 3750 fora (250 de latencia) - 30000 dentro (60s a 0,5) = 6250
        ; sec : 43000 -   250 fora                        - 30000 dentro        = 12750
        Assert(CdOf(Hoenn222Slot(1, false)) == 6250, "C tank fora 1,0 dentro 0,5 -> " CdOf(Hoenn222Slot(1, false)) " rate=" CdRateOf(Hoenn222Slot(1, false)))
        Assert(CdOf(Hoenn222Slot(1, true)) == 12750, "C secundario -> " CdOf(Hoenn222Slot(1, true)))
        ResetCase("WAITING_COMBO", 0, 16000)
        Hoenn222CdCast(1, false, MockTick - 1000)
        MockTick += 5000
        ; cast em MockTick-1000, contagem so comeca em MockTick-750, leitura em +5000:
        ; elapsed = 5750 a 1,0 -> 40000 - 5750 = 34250
        Assert(CdOf(Hoenn222Slot(1, false)) == 34250, "C recuperacao a 1,0 fora da Ball, latencia de 250Somada")
        Assert(Hoenn222CdReadyInMs(Hoenn222Slot(1, false), MockTick) == 34500, "C primeiro instante seguro = CD + margem de 250")
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
        MockTick += 999
        Acao_Gatilhos()
        Assert(Sent.Length == 5 && TimeAtual == 2, "F no commands or advance on duplicate")
        Assert(InStr(DebugText(), "reason=debounce elapsed_ms=999"), "F rejection reason")
        Assert(!A_IsCritical, "F restores thread interruptibility")
        Pass("F duplicate at 999ms rejected")

        ResetCase("WAITING_COMBO", 0, 2000)
        FaultDebt := true
        Acao_Gatilhos()
        AssertAcceptedSequence()
        Assert(Hoenn222_State == "WAITING_COMBO", "G state preserved")
        Assert(!InStr(DebugText(), "phase=cd_target"), "G a troca nao calcula mais alvo, entao nao sofre com ele")
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

        ResetCase("WAITING_TEAM_SWITCH", 500, 100)
        WindowAvailable := false
        Acao_Gatilhos()
        Assert(Sent.Length == 0 && TimeAtual == 1 && Hoenn222_LastTeamSwitchTick == 0, "J no-window keeps state")
        Assert(InStr(DebugText(), "reason=no_window") && !InStr(DebugText(), "SWITCH_STATE_UPDATED"), "J no false success")
        ResetCase("WAITING_TEAM_SWITCH", 0, 100)
        Hoenn222CdCast(1, false, MockTick - 1000)
        RealInvalidWindow := true
        Acao_Gatilhos()
        Assert(Sent.Length == 0 && TimeAtual == 1, "J real failed ControlSend keeps state")
        Assert(CdRateOf(1) == 1.0, "J falha no envio nao move ninguem para fora da Ball")
        Assert(InStr(DebugText(), "result=failed") && InStr(DebugText(), "reason=send_failed") && !InStr(DebugText(), "requested_only"), "J real TargetError diagnosed")
        Assert(!A_IsCritical, "J critical restored on failure")
        Pass("J no window and real ControlSend TargetError to synthetic nonexistent window")

        ResetCase("WAITING_COMBO", 700, 2000)
        SwitchDebugFile := A_ScriptDir "\nonexistent\debug.log"
        FaultDebt := true
        FaultLogger := true
        Acao_Gatilhos()
        AssertAcceptedSequence()
        Pass("debug writer unavailable with simultaneous debt/logger failures")

        ResetCase("WAITING_COMBO", 0, 2000)
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
        Scheduled[2].Call()
        Assert(TimeAtual == 3 && Sent[6] == "{5}", "controller next team despite failing UI")
        MockInput.bRightTrigger := 0
        GameLoop()
        Pass("controller press/hold/release with persistently failing tooltip calculation")

        ResetCase("WAITING_COMBO", 0, 2000)
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
        Acao_Gatilhos()
        Assert(TimeAtual == 2 && Sent[10] == "{3}", "manual switch independent of combo lock")
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
        ; Os alvos do otimizador sao DURACOES a partir do inicio do estado.
        ; Nao existe espera artificial: com todos os CD zerados o verde so
        ; depende da margem (250ms), e com o tank pronto quem segura o verde
        ; e o secundario, ate que o CD dele caia abaixo da tolerancia (1900ms).

        ResetCase("WAITING_COMBO", 0, 0)
        Assert(Hoenn222_SecondaryToleranceMs == 1900, "A tolerancia = 0,5*2700 + 800 - 250")
        Assert(GetHoenn222ComboTargetMs(1) == Hoenn222_MarginMs, "A sem CD o alvo e so a margem")
        Assert(GetHoenn222ComboBloqueio(1) == "", "A com tudo pronto ninguem segura o verde")

        ; Tank pronto, secundario com 43s fora da Ball: o verde e do secundario.
        Hoenn222CdCast(1, true, MockTick)
        Assert(GetHoenn222ComboTargetMs(1) == 43000 - 1900, "A alvo = (CD do secundario - 1900) / taxa")
        Assert(GetHoenn222ComboBloqueio(1) == "secundario", "A secundario segurando o verde")
        Assert(Hoenn222SecondaryPendenteMs(1, 0) > 0, "A antecipar agora deixaria o secundario atrasado")
        SolicitarComboHoenn222()
        Assert(Hoenn222_ComboArmed && Hoenn222_ComboArmedTeam == 1, "A pressa antes do verde arma")
        Assert(Scheduled.Length == 0, "A nada e enviado enquanto armado")
        Assert(InStr(DebugText(), "CD_ANTECIPACAO"), "A avisa a antecipacao")
        Assert(InStr(DebugText(), "bloqueio=secundario"), "A avisa quem esta segurando")
        GameLoop()
        Assert(Scheduled.Length == 0, "A continua esperando")
        ; O alvo tambem encolhe conforme o CD recupera, entao o verde chega antes
        ; dos 43s: com taxa 1,0 e tolerancia 1900, pending = 41350 - 2*decorrido.
        MockTick += 20674
        GameLoop()
        Assert(Scheduled.Length == 0, "A 1ms antes do instante exato ainda nao dispara (pend="
            GetHoenn222PendingMs() ")")
        MockTick += 1
        GameLoop()
        Assert(Scheduled.Length == 1 && isRodizioAtivo, "A agend=" Scheduled.Length " ativo=" isRodizioAtivo
            " pend=" GetHoenn222PendingMs() " alvo=" GetHoenn222ComboTargetMs(1)
            " cdSec=" CdOf(Hoenn222Slot(1, true)) " tol=" Hoenn222_SecondaryToleranceMs
            " inicio=" Hoenn222_StateStartTick " mock=" MockTick)
        Assert(!Hoenn222_ComboArmed && Hoenn222_ComboArmedTeam == 0, "A pedido armado consumido")
        Assert(InStr(DebugText(), "COMBO_FIRED"), "A disparo armado registrado")
        Scheduled[1].Call()
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
        SolicitarComboHoenn222()
        Assert(TrocarTimeHoenn(3), "D switch accepted")
        Assert(TimeAtual == 2 && !Hoenn222_ComboArmed && Hoenn222_ComboArmedTeam == 0, "D switch disarms")
        Assert(Sent.Length == 3 && InStr(DebugText(), "reason=team_switch"), "D only the switch keys were sent")
        MockTick += 60000
        GameLoop()
        Assert(Scheduled.Length == 0 && Sent.Length == 3, "D no combo leaks into the next team")
        Pass("D accepted team switch cancels the pending combo")

        ResetCase("WAITING_COMBO", 0, 0)
        SolicitarComboHoenn222()
        ResincronizarHoenn222()
        Assert(!Hoenn222_ComboArmed && Hoenn222_State == "WAITING_FIRST_COMBO", "E resync disarms")
        Assert(CdOf(1) == 0 && CdRateOf(1) == 0.5, "E resync also resets the six cooldowns")
        MockTick += 60000
        GameLoop()
        Assert(Scheduled.Length == 0, "E nothing runs after resync")
        ResetCase("WAITING_COMBO", 0, 0)
        SolicitarComboHoenn222()
        TrocarModo()
        Assert(!Hoenn222_ComboArmed && ModoAtual == "Normal", "E mode change disarms")
        MockTick += 60000
        GameLoop()
        Assert(Scheduled.Length == 0 && Sent.Length == 0, "E nothing runs in another mode")
        Pass("E resync and mode change cancel the pending combo")

        ResetCase("WAITING_COMBO", 0, 0)
        ; O segundo argumento e booleano: tank = falso, secundario = verdadeiro.
        Assert(GetHoenn222CdMainMs(1, false) == 40000, "F tank tier maps to 40s")
        Assert(GetHoenn222CdMainMs(1, true) == 43000, "F second tier maps to 43s")
        Assert(GetHoenn222CdMainMs(2, false) == 43000 && GetHoenn222CdMainMs(2, true) == 43000, "F team 2 tiers")
        Assert(GetHoenn222CdMainMs(3, false) == 43000 && GetHoenn222CdMainMs(3, true) == 43000, "F team 3 tiers")
        savedTankTier := Hoenn222_TankTier[1]
        Hoenn222_TankTier[1] := "SR"
        Assert(GetHoenn222CdMainMs(1, false) == 45000, "F changing only the tier changes only the CD")
        Hoenn222_TankTier[1] := savedTankTier
        Assert(GetHoenn222TierText(9, "tank") == "?", "F unknown team falls back")
        PlanHoenn222()
        Assert(Hoenn222_PlanCache.L > 0 && Hoenn222_PlanCache.Janelas.Length == 3, "F plan cached with three windows")
        ; Janelas diferentes so quando os CDs por dupla sao diferentes. Com os
        ; tiers atuais todas as duplas exigem o mesmo X, entao todas as janelas
        ; sao iguais e a volta e L = soma(X)/2.
        somaJanelas := 0
        for k in [1, 2, 3]
            somaJanelas += Hoenn222_PlanCache.Janelas[k]
        Assert(Abs(somaJanelas - Hoenn222_PlanCache.L) < 1, "F a soma das janelas e a volta L")
        ; Uma janela menor que a fisica minima do proprio combo seria inviavel.
        minimo := SleepAfterTankCombo + SleepAfterSwitch
        for k in [1, 2, 3]
            Assert(Hoenn222_PlanCache.Janelas[k] >= minimo, "F janela da dupla " k " comporta 2700 + 800")
        ; Sustentabilidade real: cada tank recupera na propria janela a 1,0 e
        ; nas outras duas a 0,5. Se isso nao cobre o CD, a volta nao se sustenta.
        for k in [1, 2, 3] {
            dentro := Hoenn222_PlanCache.L - Hoenn222_PlanCache.Janelas[k]
            recupera := Hoenn222_PlanCache.Janelas[k] + dentro * Hoenn222_RateInBall
            Assert(recupera >= GetHoenn222CdMainMs(k, false), "F tank da dupla " k
                " recupera " Round(recupera) "ms para um CD de " GetHoenn222CdMainMs(k, false) "ms")
        }
        ; O plano so depende da configuracao, entao e estavel e fica em cache.
        janela1 := Hoenn222_PlanCache.Janelas[1]
        global Hoenn222_PlanCache := false
        plano2 := PlanHoenn222()
        Assert(plano2.Janelas[1] == janela1 && plano2.L == Hoenn222_PlanCache.L, "F mesma configuracao, mesmo plano")
        savedTierTime1 := Hoenn222_TankTier[1]
        Hoenn222_TankTier[1] := "SR"
        global Hoenn222_PlanCache := false
        plano3 := PlanHoenn222()
        Assert(plano3.Janelas[1] != janela1, "F tier mais alto da mais janela a dupla 1")
        Hoenn222_TankTier[1] := savedTierTime1
        global Hoenn222_PlanCache := false
        PlanHoenn222()
        ResetCase("WAITING_COMBO", 0, 1000)
        AtualizarTooltipsControle()
        Assert(Rendered.Length == 2 && InStr(Rendered[2].text, "Tank: ") && InStr(Rendered[2].text, "Sec: "), "F tiers shown")
        Pass("F tiers, CD and windows all come from config")

        ResetCase("WAITING_COMBO", 0, 0)
        Hoenn222CdCast(1, false, MockTick)
        ; O CD so comeca a contar LatencyMs depois do comando; ate la ele vale cheio.
        MockTick += Hoenn222_LatencyMs
        Assert(CdOf(Hoenn222Slot(1, false)) == 40000, "H cast loads the CD main and keeps rate out of ball")
        Assert(CdRateOf(Hoenn222Slot(1, false)) == 1.0, "H casting implies out of ball")
        Assert(Hoenn222CdReadyInMs(Hoenn222Slot(1, false), MockTick) == 40250, "H ready = CD + margin")
        Assert(GetHoenn222ComboTargetMs(1) == 40250, "H COMBAR target follows the tank CD, not a constant")
        Assert(GetHoenn222ComboBloqueio(1) == "tank", "H tank segurando o verde")
        Hoenn222CdSetRate(Hoenn222Slot(1, false), Hoenn222_RateInBall, MockTick)
        ; 20000ms dentro da Ball a 0,5 tiram 10000ms de CD, nao 20000.
        MockTick += 20000
        Assert(CdOf(Hoenn222Slot(1, false)) == 30000, "H 20000ms a 0,5 tiram 10000ms de CD")
        Assert(Hoenn222CdReadyInMs(Hoenn222Slot(1, false), MockTick) == 30000 / Hoenn222_RateInBall + Hoenn222_MarginMs, "H dentro da Ball o mesmo CD custa o dobro")
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
        Assert(RealBaseTarget("WAITING_COMBO", 1) == Hoenn222_MarginMs, "J sem CD, COMBAR e so a margem")
        janela := GetHoenn222SwitchTargetMs(1)
        Assert(janela == Hoenn222_PlanCache.Janelas[1], "J TROCAR TIME usa a janela planejada")
        Assert(RealBaseTarget("WAITING_TEAM_SWITCH", 1) == janela, "J a janela tambem e uma duracao")
        Assert(GetHoenn222PendingMs() == Hoenn222_MarginMs, "J pendente com todos os CD zerados")
        MockTick += 1000
        Assert(GetHoenn222PendingMs() == Hoenn222_MarginMs - 1000, "J 1000ms decorridos tiram 1000ms do pendente")
        Pass("J desligar o otimizador volta aos alvos fixos sem nenhuma outra mudanca")

        ResetCase()
        ComboComplexoHoenn222()
        Assert(Scheduled.Length == 1 && isRodizioAtivo, "K combo scheduling unchanged")
        Scheduled[1].Call()
        Assert(CdOf(Hoenn222Slot(1, false)) == 40000, "K tank CD restarted by its own cast")
        Assert(InStr(DebugText(), "CD_CAST"), "K cast recorded in the diagnostics")
        Pass("K the combo registers both casts on the right slots")
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

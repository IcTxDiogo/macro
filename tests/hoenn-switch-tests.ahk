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
    Hoenn222_PlanCache := unset
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
        ; Com o otimizador ligado o alvo de COMBAR e
        ;   t_estado + max(PrepareMs, CD_do_tank + Latency + Margin ja decorridos).
        ; Com o CD zerado sobra so o minimo fisico de preparacao.

        ResetCase("WAITING_COMBO", 0, 1000)
        Assert(GetHoenn222ComboTargetMs(1) == MockTick - 1000 + Hoenn222_PrepareMs, "A alvo = estado + PrepareMs com CD pronto")
        SolicitarComboHoenn222()
        Assert(Hoenn222_ComboArmed && Hoenn222_ComboArmedTeam == 1, "A press before green arms")
        Assert(Sent.Length == 0 && Scheduled.Length == 0, "A nothing sent while armed")
        GameLoop()
        MockTick += Hoenn222_PrepareMs - 1000 - 1
        GameLoop()
        Assert(Scheduled.Length == 0, "A still waiting one ms before green")
        MockTick += 1
        GameLoop()
        Assert(Scheduled.Length == 1 && isRodizioAtivo, "A prepare=" Hoenn222_PrepareMs " margin=" Hoenn222_MarginMs " lat=" Hoenn222_LatencyMs " opt=" Hoenn222_CdOptimizerEnabled " alvo=" GetHoenn222ComboTargetMs(1) " rodizio=" isRodizioAtivo " mock=" MockTick)
        Assert(!Hoenn222_ComboArmed && Hoenn222_ComboArmedTeam == 0, "A armed request consumed")
        Assert(InStr(DebugText(), "COMBO_FIRED"), "A armed fire logged")
        Scheduled[1].Call()
        Assert(Join(Sent) == "{y}|{c}|{f}|{i}|{2}|{y}|{c}|{f}|{i}", "A armed skill sequence")
        Assert(!isRodizioAtivo, "A combo lock released")
        Pass("A early press arms; the timer fires the combo once green")

        ResetCase("WAITING_COMBO", 0, 20000)
        GameLoop()
        Assert(Scheduled.Length == 0 && Sent.Length == 0, "B green alone never auto-runs")
        Assert(!Hoenn222_ComboArmed, "B nothing armed without a press")
        SolicitarComboHoenn222()
        Assert(Scheduled.Length == 1 && isRodizioAtivo, "B press on green runs now")
        Scheduled[1].Call()
        Assert(Join(Sent) == "{y}|{c}|{f}|{i}|{2}|{y}|{c}|{f}|{i}", "B skill sequence")
        Pass("B green waits for the press")

        ResetCase("WAITING_COMBO", 0, 2000)
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
        ResetCase("WAITING_COMBO", 0, 2000)
        SolicitarComboHoenn222()
        MockTick += 1
        SolicitarComboHoenn222()
        Assert(Scheduled.Length == 0 && Hoenn222_ComboArmed, "C zero window disables emergency")
        Hoenn222_EmergencyWindowMs := savedWindow
        Pass("C double press ignores the timer; zero window disables it")

        ResetCase("WAITING_COMBO", 0, 1000)
        SolicitarComboHoenn222()
        Assert(TrocarTimeHoenn(3), "D switch accepted")
        Assert(TimeAtual == 2 && !Hoenn222_ComboArmed && Hoenn222_ComboArmedTeam == 0, "D switch disarms")
        Assert(Sent.Length == 3 && InStr(DebugText(), "reason=team_switch"), "D only the switch keys were sent")
        MockTick += 60000
        GameLoop()
        Assert(Scheduled.Length == 0 && Sent.Length == 3, "D no combo leaks into the next team")
        Pass("D accepted team switch cancels the pending combo")

        ResetCase("WAITING_COMBO", 0, 1000)
        SolicitarComboHoenn222()
        ResincronizarHoenn222()
        Assert(!Hoenn222_ComboArmed && Hoenn222_State == "WAITING_FIRST_COMBO", "E resync disarms")
        Assert(CdOf(1) == 0 && CdRateOf(1) == 0.5, "E resync also resets the six cooldowns")
        MockTick += 60000
        GameLoop()
        Assert(Scheduled.Length == 0, "E nothing runs after resync")
        ResetCase("WAITING_COMBO", 0, 1000)
        SolicitarComboHoenn222()
        TrocarModo()
        Assert(!Hoenn222_ComboArmed && ModoAtual == "Normal", "E mode change disarms")
        MockTick += 60000
        GameLoop()
        Assert(Scheduled.Length == 0 && Sent.Length == 0, "E nothing runs in another mode")
        Pass("E resync and mode change cancel the pending combo")

        ResetCase("WAITING_COMBO", 0, 0)
        Assert(GetHoenn222CdMainMs(1, "tank") == 40000, "F tank tier maps to 40s")
        Assert(GetHoenn222CdMainMs(1, "second") == 43000, "F second tier maps to 43s")
        Assert(GetHoenn222CdMainMs(2, "tank") == 43000 && GetHoenn222CdMainMs(2, "second") == 43000, "F team 2 tiers")
        Assert(GetHoenn222CdMainMs(3, "tank") == 43000 && GetHoenn222CdMainMs(3, "second") == 43000, "F team 3 tiers")
        savedTankTier := Hoenn222_TankTier[1]
        Hoenn222_TankTier[1] := "SR"
        Assert(GetHoenn222CdMainMs(1, "tank") == 45000, "F changing only the tier changes only the CD")
        Hoenn222_TankTier[1] := savedTankTier
        Assert(GetHoenn222TierText(9, "tank") == "?", "F unknown team falls back")
        PlanHoenn222()
        Assert(Hoenn222_PlanCache.L > 0 && Hoenn222_PlanCache.Janelas.Length == 3, "F plan cached with three windows")
        Assert(Hoenn222_PlanCache.Janelas[2] > Hoenn222_PlanCache.Janelas[1], "F higher secondary CD gets a longer window")
        Hoenn222_PrepareMs := 2000
        Hoenn222_PlanCache := unset
        plano2 := PlanHoenn222()
        Assert(plano2.L < Hoenn222_PlanCache.L, "F smaller Prepare shortens the lap")
        Hoenn222_PrepareMs := 4000
        Hoenn222_PlanCache := unset
        ResetCase("WAITING_COMBO", 0, 1000)
        AtualizarTooltipsControle()
        Assert(Rendered.Length == 2 && InStr(Rendered[2].text, "Tank: ") && InStr(Rendered[2].text, "Sec: "), "F tiers shown")
        Pass("F tiers, CD and windows all come from config")

        ResetCase("WAITING_COMBO", 0, 0)
        Hoenn222CdCast(1, false, MockTick)
        Assert(CdOf(Hoenn222Slot(1, false)) == 40000, "H cast loads the CD main and keeps rate out of ball")
        Assert(CdRateOf(Hoenn222Slot(1, false)) == 1.0, "H casting implies out of ball")
        Assert(Hoenn222CdReadyInMs(Hoenn222Slot(1, false), MockTick) == 40250, "H ready = CD + latency + margin")
        Hoenn222_StateStartTick := MockTick
        Assert(GetHoenn222ComboTargetMs(1) == MockTick + 40250, "H COMBAR target follows the CD, not a constant")
        Hoenn222CdSetRate(Hoenn222Slot(1, false), Hoenn222_RateInBall, MockTick)
        MockTick += 20000
        Assert(CdOf(Hoenn222Slot(1, false)) == 30000, "H 40000 - 20000 a 0,5 = 30000")
        Assert(Hoenn222CdReadyInMs(Hoenn222Slot(1, false), MockTick) == 60250, "H in the ball the same CD costs twice the time")
        Pass("H target follows the individual CD and the in-ball rate")

        ResetCase("WAITING_COMBO", 0, 0)
        Assert(GetHoenn222SecondaryWaitMs(1, MockTick) == Hoenn222_SecondaryGapMs, "I animation is the floor")
        Hoenn222CdCast(1, true, MockTick)
        Hoenn222CdSetRate(Hoenn222Slot(1, true), Hoenn222_RateOutOfBall, MockTick, Hoenn222_LatencyMs)
        MockTick += 1000
        espera := GetHoenn222SecondaryWaitMs(1, MockTick)
        Assert(espera == 42000 - 1000 + Hoenn222_MarginMs, "I wait extends to the first safe instant of the secondary")
        Assert(espera > Hoenn222_SecondaryGapMs, "I no fixed multi-second wait")
        Hoenn222_CdOptimizerEnabled := false
        Assert(GetHoenn222SecondaryWaitMs(1, MockTick) == Hoenn222_SecondaryGapMs, "I disabled optimizer keeps 2700/800")
        Hoenn222_CdOptimizerEnabled := true
        Pass("I secondary wait is the animation floor extended by its own CD")

        ResetCase("WAITING_COMBO", 0, 0)
        Hoenn222_CdOptimizerEnabled := false
        Assert(GetHoenn222ComboTargetMs(1) == Hoenn222_StateStartTick + Hoenn222_ComboTargetMs[1], "J fallback uses the fixed target")
        Hoenn222_State := "WAITING_TEAM_SWITCH"
        Assert(GetHoenn222SwitchTargetMs(1) == Hoenn222_StateStartTick + Hoenn222_SwitchTargetMs[1], "J fallback switch target")
        Hoenn222_CdOptimizerEnabled := true
        MockTick += 5000
        Assert(GetHoenn222ComboTargetMs(1) == Hoenn222_StateStartTick + Hoenn222_PrepareMs, "J optimizer target restored")
        Pass("J optimizer off falls back to the fixed targets with no other change")

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

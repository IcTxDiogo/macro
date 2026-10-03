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
    Hoenn222_DebtMs := debt
    Hoenn222_ExecutionId := 0
    Hoenn222_TankEnterTick := Map(1, 0, 2, 0, 3, 0)
    Hoenn222_TeamDuration := Map(1, 0, 2, 0, 3, 0)
    Hoenn222_TeamUsageInterval := Map(1, 0, 2, 0, 3, 0)
    Hoenn222_TeamLastUsageTick := Map(1, 0, 2, 0, 3, 0)
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

        ResetCase("WAITING_TEAM_SWITCH", 2000, 3000)
        Hoenn222_LastTeamSwitchTick := MockTick - 4000
        Hoenn222_TeamLastUsageTick[2] := MockTick - 50000
        Acao_Gatilhos("mouse")
        AssertAcceptedSequence()
        Assert(Hoenn222_DebtMs == 8500, "B 9500+2000-3000=8500")
        Assert(Hoenn222_TeamDuration[1] == 4000 && Hoenn222_TeamUsageInterval[2] == 50000, "B tracking")
        Assert(Hoenn222_TankEnterTick[2] == MockTick, "B tank timestamp")
        Pass("B accumulated debt, duration and usage interval")

        ResetCase("WAITING_COMBO", 0, 16000)
        Acao_Gatilhos()
        AssertAcceptedSequence()
        Assert(Hoenn222_DebtMs == 0, "C debt clamps to zero")
        Pass("C zero debt")

        ResetCase("WAITING_TEAM_SWITCH", 0, 5000)
        Assert(TrocarTimeHoenn(3), "D state does not block")
        Assert(Hoenn222_State == "WAITING_COMBO" && Hoenn222_StateStartTick == MockTick, "D state timestamp")
        Assert(Hoenn222_DebtMs == 4500, "D anticipation preserved")
        Pass("D WAITING_TEAM_SWITCH")

        ResetCase("WAITING_COMBO", 0, 2000)
        Hoenn222_LastTeamSwitchTick := MockTick - 1000
        Assert(TrocarTimeHoenn(3), "E WAITING_COMBO accepted after debounce")
        Assert(Hoenn222_DebtMs == 13000, "E prior team target used")
        Pass("E WAITING_COMBO, only 1000ms debounce")

        ResetCase()
        Acao_Gatilhos()
        MockTick += 999
        Acao_Gatilhos()
        Assert(Sent.Length == 5 && TimeAtual == 2, "F no commands or advance on duplicate")
        Assert(InStr(DebugText(), "reason=debounce elapsed_ms=999"), "F rejection reason")
        Assert(!A_IsCritical, "F restores thread interruptibility")
        Pass("F duplicate at 999ms rejected")

        ResetCase("WAITING_COMBO", 1234, 2000)
        FaultDebt := true
        Acao_Gatilhos()
        AssertAcceptedSequence()
        Assert(Hoenn222_DebtMs == 1234 && Hoenn222_State == "WAITING_COMBO", "G safe debt fallback and state")
        Assert(InStr(DebugText(), "phase=debt") && InStr(DebugText(), "function=GetHoenn222BaseTargetMs") && InStr(DebugText(), "line="), "G error evidence")
        Assert(InStr(Join(Timeline), "send:{3}") < InStr(Join(Timeline), "debt:"), "G primary precedes debt")
        Pass("G target calculation throws; all accepted commands preserved")

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

        ResetCase("WAITING_TEAM_SWITCH", 5000, 100)
        Hoenn222_LastComboStartTick := 999
        Hoenn222_P2CallTick := 999
        ResincronizarHoenn222()
        Assert(Hoenn222_State == "WAITING_FIRST_COMBO" && Hoenn222_DebtMs == 0, "I F8 reset")
        Assert(Hoenn222_ExecutionId == 1 && Hoenn222_LastComboStartTick == 0 && Hoenn222_P2CallTick == 0, "I invalidation")
        Acao_Gatilhos()
        AssertAcceptedSequence()
        Assert(Hoenn222_DebtMs == 0, "I resync switch no new debt")
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
        ResetCase("WAITING_TEAM_SWITCH", 500, 100)
        RealInvalidWindow := true
        Acao_Gatilhos()
        Assert(Sent.Length == 0 && TimeAtual == 1 && Hoenn222_DebtMs == 500, "J real failed ControlSend keeps state")
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
        Assert(StrSplit(DebugText(), "phase=tooltip").Length == 2, "tooltip error logged once")
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

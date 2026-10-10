; Concatenado pelo runner às funções atuais, sem executar main.ahk ou carregar XInput.
global Sent := [], Timeline := [], Scheduled := [], Rendered := []
global FaultDebt := false, FaultLogger := false, FaultSend := false, FaultTooltip := false
global WindowAvailable := true, RealInvalidWindow := false
global WindowFocused := true, MockWindowX := 10, MockWindowY := 20
global MockInput := {bRightTrigger: 0, bLeftTrigger: 0, wButtons: 0,
    sThumbLX: 0, sThumbLY: 0, sThumbRX: 0, sThumbRY: 0}
global PassCount := 0
global MockAdvanceTime := false, MockSendMs := 0, MockCheckCast := false, MockSimCasts := 0
RunTests()
ExitApp(0)

MockControlSend(keys, control := "", window := "") {
    global Sent, Timeline, FaultSend, RealInvalidWindow
    global MockTick
    if MockAdvanceTime
        MockTick += MockSendMs
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
    global Timeline, MockTick
    Timeline.Push("sleep:" ms)
    if MockAdvanceTime
        MockTick += ms
}
MockRegistrarCast(time, secundario := false) {
    global MockSimCasts
    if MockCheckCast {
        Assert(MsAteCastSeguro(SlotDoPokemon(time, secundario), MockTick) <= 0.001, "discreto: cast com CD pendente")
        fora := 0
        loop 6
            fora += TaxaDeRecuperacao[A_Index] == Hoenn222_RateOutOfBall ? 1 : 0
        Assert(fora == 1, "discreto: apenas um Pokemon fora em cada cast")
        MockSimCasts++
    }
    RealRegistrarCast(time, secundario)
}
MockWinExist(*) {
    global WindowAvailable
    return WindowAvailable ? 123 : 0
}
MockWinActive(*) {
    return WindowAvailable && WindowFocused ? 123 : 0
}
MockWinGetPos(&x := unset, &y := unset, &width := unset, &height := unset, *) {
    x := MockWindowX
    y := MockWindowY
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
        throw Error("simulated AlvoDaFaseMs failure", "AlvoDaFaseMs")
    return RealBaseTarget(state, team)
}
MockTeamLogger(team, mode) {
    global FaultLogger, Timeline
    Timeline.Push("logger:" team)
    if FaultLogger
        throw Error("simulated logger failure", "RegistrarTrocaNoLog")
    RealTeamLogger(team, mode)
}
ResetCase(state := "WAITING_FIRST_COMBO", debt := 0, elapsed := 0) {
    global
    FaultTooltip := false
    DesenharPainel() ; invalida tambem o cache visual entre casos isolados
    TimeAtual := 1
    MockAdvanceTime := false, MockSendMs := 0, MockCheckCast := false, MockSimCasts := 0
    RodizioAtivo := false
    ModoAtual := "Hoenn222"
    FaseAtual := state
    InicioDaFaseTick := MockTick - elapsed
    UltimaTrocaDeTimeTick := 0
    IdDaExecucao := 0

    ComboArmado := false
    TimeDoComboArmado := 0
    UltimoCliqueComboTick := 0
    TrocaArmada := false
    TimeDaTrocaArmada := 0
    UltimoCliqueTrocaTick := 0
    CooldownRestanteMs := [0, 0, 0, 0, 0, 0]
    TaxaDeRecuperacao := [0, 0, 0, 0, 0, 0]
    CooldownContaDesdeTick := [0, 0, 0, 0, 0, 0]
    global PlanoEmCache := false
    AvisoDeTierDesconhecidoFeito := false
    Hoenn222_CdOptimizerEnabled := true
    Hoenn222_InBallWholeBlocks := false
    Hoenn222_UseDiscretePlanner := false ; grupos legados verificam o rollback
    ResetarCooldowns(MockTick)
    ; Os testes antigos partem de times que ja fizeram o primeiro cast; a primeira
    ; volta tem os grupos proprios (W) e liga o ritmo com TeamCasted := false.
    TankJaCastou := Map(1, true, 2, true, 3, true)
    ; Os pisos de conforto do config.ahk sao do jogador; os testes legados medem o
    ; plano de volta minima, e os grupos AA-AC ligam os pisos explicitamente.
    Hoenn222_MinLureMs := Map(1, 0, 2, 0, 3, 0)
    Hoenn222_MinSecondaryOutMs := Map(1, 0, 2, 0, 3, 0)
    ; Os testes legados medem um atraso de saida unico (o do tank); o grupo AD e a
    ; repeticao do ciclo perfeito (AE) ligam o atraso proprio do secundario.
    Hoenn222_ExitLatencySecondaryMs := Hoenn222_LatencyMs
    ToleranciaDoSecundarioMs := CalcularToleranciaDoSecundarioMs()
    Sent := [], Timeline := [], Scheduled := [], Rendered := []
    FaultDebt := false, FaultLogger := false, FaultSend := false, FaultTooltip := false
    WindowAvailable := true, RealInvalidWindow := false
    WindowFocused := true, MockWindowX := 10, MockWindowY := 20
    MockInput.bRightTrigger := 0
    MockInput.wButtons := 0
    InicioDoComboTick := 0
    ArquivoDoLogDaSessao := A_ScriptDir "\session_logs\test-session.txt"
    DiagnosticoAtivo := true
    ArquivoDiagnostico := A_ScriptDir "\switch-debug.log"
    if FileExist(ArquivoDiagnostico)
        FileDelete(ArquivoDiagnostico)
}
CdRateOf(slot) {
    global TaxaDeRecuperacao
    AtualizarCooldown(slot, MockTick)
    return TaxaDeRecuperacao[slot]
}
CdOf(slot) {
    global CooldownRestanteMs
    AtualizarCooldown(slot, MockTick)
    return CooldownRestanteMs[slot]
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
    global ArquivoDiagnostico
    return FileExist(ArquivoDiagnostico) ? FileRead(ArquivoDiagnostico) : ""
}
Pass(name) {
    global PassCount
    PassCount++
    FileAppend("PASS " name "`n", "*", "UTF-8")
}
AssertAcceptedSequence() {
    global Sent, Timeline, TimeAtual
    Assert(Join(Sent) == "{3}|{c}|{t}|{c}|{e}", "primary + Pokestop + FullDef + trigger Pokestop + UsarPocao")
    Assert(InStr(Join(Timeline), "sleep:" SleepAfterSwitch), "SleepAfterSwitch preserved")
    Assert(TimeAtual == 2, "requested team committed")
}

; Os grupos estao em tests\grupos\NN-*.ahk, uma funcao Testes* por tema. Todas usam `global`:
; o que um grupo cria, os seguintes podem ler. A ordem importa.
RunTests() {
    try {
        TestesTrocaDeTime()
        TestesComboArmado()
        TestesCooldown()
        TestesIndicador()
        TestesTrocaArmada()
        TestesPrimeiraVolta()
        TestesMargem()
        TestesPisos()
        TestesAtrasoDeSaida()
        TestesBotaoUnico()
        TestesConfig()
        TestesBlocosBall()
        TestesPlanejadorDiscreto()
        TestesPainel()
        FileAppend("RESULT: " PassCount " test groups passed; no game commands executed.`n", "*", "UTF-8")
    } catch as e {
        FileAppend("FAIL: " e.Message " | " e.What " | line=" e.Line "`n", "*", "UTF-8")
        ExitApp(1)
    }
}

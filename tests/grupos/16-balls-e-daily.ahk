; Estado da captura e sequencia de cliques isolados do jogo.
TestesBallsEDaily() {
    global
    ResetCase()
    loop 3
        CapturarAlvo()
    Assert(Join(Sent) == "{p}|{p}|{p}", "ball unica repete a primeira")
    KeyBallSpecial2 := "o", KeyBallSpecial3 := "u"
    UltimaBallEspecial := 0, Sent := []
    loop 7
        AcaoFaceLeft()
    Assert(Join(Sent) == "{p}|{o}|{u}|{p}|{o}|{u}|{p}", "tres balls em ciclo")
    KeyBallSpecial2 := "", UltimaBallEspecial := 0, Sent := []
    loop 4
        CapturarAlvo()
    Assert(Join(Sent) == "{p}|{u}|{p}|{u}", "pula ball 2 vazia")
    KeyBallSpecial2 := "o", KeyBallSpecial3 := "", UltimaBallEspecial := 0, Sent := []
    loop 4
        CapturarAlvo()
    Assert(Join(Sent) == "{p}|{o}|{p}|{o}", "pula ball 3 vazia")
    UltimaBallEspecial := 0, Sent := [], WindowAvailable := false
    CapturarAlvo()
    Assert(Sent.Length == 0 && UltimaBallEspecial == 0, "sem janela nao avanca ball")
    WindowAvailable := true, FaultSend := true
    CapturarAlvo()
    Assert(UltimaBallEspecial == 0, "falha de envio nao avanca ball")
    FaultSend := false
    CapturarAlvo()
    Assert(Join(Sent) == "{p}", "primeiro envio apos falha ainda usa ball 1")
    Pass("balls: rotacao, opcionais e falha de envio")

    ResetCase()
    Assert(!RenovarGuildDaily() && Sent.Length == 0, "daily sem posicoes nao clica")
    GuildDailyRenewPos := {X: 318, Y: 205}
    Assert(!RenovarGuildDaily() && Sent.Length == 0, "daily exige ambas as posicoes")
    GuildDailyConfirmPos := {X: 747, Y: 455}
    Assert(RenovarGuildDaily(), "daily envia sequencia")
    Assert(Join(Timeline) == "click:x318 y205|sleep:300|click:x747 y455", "ordem renovar, espera, confirmar")
    Assert(Join(Sent) == "x318 y205|ahk_id 123|NA Pos|x747 y455|ahk_id 123|NA Pos", "coordenadas cliente e janela fixa")
    Assert(!RenovacaoDailyAtiva, "daily libera trava")
    Sent := [], Timeline := [], FaultSend := true
    Assert(!RenovarGuildDaily() && !RenovacaoDailyAtiva, "erro libera trava")
    FaultSend := false
    MockSleepHook := (*) => RenovarGuildDaily()
    Assert(RenovarGuildDaily() && Sent.Length == 2, "daily nao sobrepoe pedidos")
    MockSleepHook := (*) => WindowAvailable := false
    Sent := []
    Assert(!RenovarGuildDaily() && Sent.Length == 1 && !RenovacaoDailyAtiva, "fechar jogo cancela confirmacao")
    Pass("daily: ordem, configuracao, trava, erros e fechamento do jogo")

    ResetCase()
    GuildDailyRenewPos := {X: 318, Y: 205}, GuildDailyConfirmPos := {X: 747, Y: 455}
    MockInput.wButtons := 0
    DespacharBotoes(MockInput, true)
    Scheduled := []
    MockInput.wButtons := 0x4000
    DespacharBotoes(MockInput, true)
    DespacharBotoes(MockInput, true)
    Assert(Scheduled.Length == 1 && Sent.Length == 0, "X agenda uma acao por pressao")
    Scheduled[1].Call()
    Assert(Sent.Length == 2, "X executa renovacao agendada")
    MockInput.wButtons := 0
    DespacharBotoes(MockInput, true)
    Scheduled := []
    MockInput.wButtons := 0x0008
    DespacharBotoes(MockInput, true)
    Assert(Scheduled.Length == 1, "direcional direito tambem renova")
    MockInput.wButtons := 0
    DespacharBotoes(MockInput, true)
    ResetCase()
    Pass("daily: controle agenda sem bloquear GameLoop")
}

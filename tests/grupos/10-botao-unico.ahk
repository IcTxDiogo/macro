; Tema: Botao unico: a proxima acao do ciclo.
TestesBotaoUnico() {
    global
    ; --- BOTAO UNICO: A PROXIMA ACAO DO CICLO ---
    ; Um botao so: na fase COMBAR (ou antes do 1o combo) pede o combo; na fase TROCAR TIME
    ; pede a troca. So LB/RB (e o botao lateral 1 do mouse); LT/RT ficam livres no 2-2-2.

    ; COMBAR em espera: o pedido vira combo armado, nao troca.
    ResetCase("WAITING_COMBO", 0, 1000)
    AplicarCast(1, true, MockTick)
    AcaoBumpers("controller")
    Assert(ComboArmado && !TrocaArmada && Sent.Length == 0 && TimeAtual == 1, "AE em COMBAR o botao arma o combo")
    Assert(InStr(DebugText(), "NEXT_ACTION | source=controller phase=WAITING_COMBO action=combo"), "AE diagnostico da proxima acao")
    MockTick += 1000
    AcaoGatilhos("controller")
    Assert(ComboArmado && !TrocaArmada && Sent.Length == 0, "AE LT/RT estao livres no 2-2-2: nao pedem nada")

    ; O combo dispara sozinho no verde; durante o rodizio o mesmo botao ja pede a troca.
    MockTick += 60000
    GameLoop()
    Assert(Scheduled.Length == 1, "AE no verde o combo e agendado")
    Scheduled[1].Call()
    Assert(Scheduled.Length == 2 && RodizioAtivo, "AE a thread descartavel inicia o rodizio")
    Scheduled[2].Call()
    Assert(FaseAtual == "WAITING_TEAM_SWITCH" && !ComboArmado, "AE depois do combo a fase e TROCAR TIME")
    Sent := []
    AcaoBumpers("controller")
    Assert(TrocaArmada && !ComboArmado && Sent.Length == 0, "AE em TROCAR TIME em espera o botao arma a troca")
    MockTick += DuracaoDoTrocarTimeMs(1) + 1
    GameLoop()
    Assert(Scheduled.Length == 3, "AE no verde da troca ela e agendada")
    Scheduled[3].Call()
    Assert(TimeAtual == 2 && !TrocaArmada, "AE o botao unico completou combo e troca")

    ; TROCAR TIME verde: troca na hora, com qualquer um dos botoes.
    ResetCase("WAITING_TEAM_SWITCH", 0, 40000)
    AcaoGatilhos("mouse")
    Assert(TimeAtual == 1 && Sent.Length == 0 && !TrocaArmada, "AE gatilho/botao lateral 2 nao trocam no 2-2-2")
    AcaoBumpers("mouse")
    Assert(TimeAtual == 2 && Sent[1] == "{3}" && !TrocaArmada, "AE em TROCAR TIME verde o botao troca na hora")

    ; Antes do 1o combo (F8/inicio) o botao pede o combo, que executa na hora.
    ResetCase("WAITING_FIRST_COMBO", 0, 0)
    AcaoBumpers("mouse")
    Assert(Scheduled.Length == 1 && TimeAtual == 1 && !TrocaArmada, "AE antes do 1o combo o botao pede o combo")

    ; Modo Normal nao muda: bumpers = combo simples, gatilhos = reviver.
    ResetCase()
    ModoAtual := "Normal"
    AcaoBumpers("controller")
    Assert(Join(Sent) == "{y}|{c}|{f}|{i}", "AE Normal: bumpers fazem o combo simples")
    Sent := []
    AcaoGatilhos("controller")
    Assert(Join(Sent) == "{Space}", "AE Normal: gatilhos revivem")
    Pass("AE botao unico: combo em COMBAR, troca em TROCAR TIME, LT/RT livres, Normal inalterado")
}

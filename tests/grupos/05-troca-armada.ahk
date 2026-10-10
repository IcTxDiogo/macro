; Tema: Troca de time armada: mesma regra do combo.
TestesTrocaArmada() {
    global

; --- GATILHO DE TROCA: A MESMA REGRA DO COMBO ---
    ; Amarelo nao troca na hora: arma e troca sozinho no instante do verde.
    ; Verde troca na hora. Duplo acionamento troca na hora.

    ; TROCAR TIME amarelo: arma, nada e enviado.
    ResetCase("WAITING_TEAM_SWITCH", 0, 3000)
    janelaP := DuracaoDoTrocarTimeMs(1)
    Assert(FaltaParaVerdeMs() == janelaP - 3000 && janelaP > 3000, "P cenario: TROCAR TIME amarelo")
    PedirTrocaDeTime("controller")
    Assert(TrocaArmada && TimeDaTrocaArmada == 1, "P gatilho em amarelo arma a troca")
    Assert(Sent.Length == 0 && TimeAtual == 1, "P nada enviado e o time nao mudou")
    corP := ""
    TextoDoQuadradoCentral(&corP)
    Assert(corP == "B266FF", "P o quadrado mostra o pedido armado, cor=" corP)
    Assert(InStr(TextoDoPainel(), "TROCA ARMADA"), "P o tooltip avisa a troca armada")
    Assert(InStr(DebugText(), "SWITCH_ARMED"), "P registrado no diagnostico")
    ; Varredura de 30 ms antes do verde nao dispara; 1 ms antes tambem nao.
    MockTick += janelaP - 3000 - 1
    GameLoop()
    Assert(Scheduled.Length == 0 && TrocaArmada, "P 1ms antes do verde ainda espera")
    ; No instante exato do verde, dispara sozinho, uma unica vez.
    MockTick += 1
    GameLoop()
    Assert(Scheduled.Length == 1 && TrocaArmada && Sent.Length == 0, "P no verde o laco so agenda a thread descartavel")
    GameLoop()
    Assert(Scheduled.Length == 1, "P varreduras seguintes nao duplicam")
    Scheduled[1].Call()
    Assert(!TrocaArmada, "P a thread descartavel consome o pedido")
    AssertAcceptedSequence()
    Assert(FaseAtual == "WAITING_COMBO" && InStr(DebugText(), "SWITCH_FIRED"), "P a troca antecipada cumpriu a sequencia de sempre")
    Assert(RegExMatch(DebugText(), "CD_ENTRADA \| slot=3 time=2 papel=tank cd_modelo_ms=\d+ taxa="), "P entrada do tank novo registrada na troca")
    Pass("P gatilho em amarelo arma e troca sozinho no instante do verde")

    ; TROCAR TIME verde: troca na hora, sem armar.
    ResetCase("WAITING_TEAM_SWITCH", 0, 40000)
    PedirTrocaDeTime("mouse")
    AssertAcceptedSequence()
    Assert(!TrocaArmada && InStr(DebugText(), "result=immediate"), "Q verde troca na hora")
    Pass("Q gatilho em verde troca na hora")

    ; Duplo acionamento em amarelo: emergencia, troca na hora e consome o pedido.
    ResetCase("WAITING_TEAM_SWITCH", 0, 3000)
    PedirTrocaDeTime("controller")
    Assert(TrocaArmada && Sent.Length == 0, "R primeira pressao arma")
    MockTick += Hoenn222_EmergencyWindowMs
    PedirTrocaDeTime("controller")
    AssertAcceptedSequence()
    Assert(!TrocaArmada && InStr(DebugText(), "result=emergency"), "R segunda pressao troca na hora e limpa o pedido")
    MockTick += 60000
    GameLoop()
    Assert(Scheduled.Length == 0, "R o pedido consumido nao dispara depois")
    ; Janela 0 desliga a emergencia, so resta o pedido antecipado.
    savedWindow := Hoenn222_EmergencyWindowMs
    Hoenn222_EmergencyWindowMs := 0
    ResetCase("WAITING_TEAM_SWITCH", 0, 3000)
    PedirTrocaDeTime("controller")
    MockTick += 1
    PedirTrocaDeTime("controller")
    Assert(Sent.Length == 0 && TrocaArmada, "R janela 0 desliga a emergencia")
    Hoenn222_EmergencyWindowMs := savedWindow
    Pass("R duplo acionamento troca na hora; janela 0 desliga")


    ; Troca armada nunca vale para outro time, modo ou apos F8.
    ResetCase("WAITING_TEAM_SWITCH", 0, 3000)
    PedirTrocaDeTime("controller")
    Assert(TrocaArmada, "T armada")
    Resincronizar()
    Assert(!TrocaArmada && InStr(DebugText(), "SWITCH_DISARMED"), "T F8 desarma")
    ResetCase("WAITING_TEAM_SWITCH", 0, 3000)
    PedirTrocaDeTime("controller")
    TrocarModo()
    Assert(!TrocaArmada, "T troca de modo desarma")
    ResetCase("WAITING_TEAM_SWITCH", 0, 3000)
    PedirTrocaDeTime("controller")
    TimeAtual := 2
    MockTick += 60000
    GameLoop()
    Assert(!TrocaArmada && Scheduled.Length == 0 && Sent.Length == 0, "T time diferente: nao troca em outro time")
    Pass("T troca armada e cancelada por F8, modo e mudanca de time")


}

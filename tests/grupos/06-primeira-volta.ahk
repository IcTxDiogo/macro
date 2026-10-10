; Tema: Ritmo do plano desde a primeira volta.
TestesPrimeiraVolta() {
    global
; --- PRIMEIRA VOLTA: O RITMO DO PLANO VALE DESDE O PRIMEIRO CICLO ---
    ; Depois do F8 os seis estao com o CD pronto. Sem ritmo, a troca para o time
    ; 2 liberava o combo na hora (CD zero) e a espera inteira caia na volta do
    ; time 1. Ate o primeiro cast do time, o verde respeita o lure do plano.
    ResetCase("WAITING_COMBO", 0, 0)
    TankJaCastou := Map(1, false, 2, false, 3, false)
    lureW := PlanejarVolta().Lures[2]
    Assert(lureW > 10000, "W cenario: lure planejado " Round(lureW) "ms")
    TimeAtual := 2
    InicioDaFaseTick := MockTick
    Assert(FaltaParaComboViavelMs(2) == lureW, "W logo apos a troca o CD zerado NAO libera: falta o lure, " FaltaParaComboViavelMs(2))
    corW := ""
    TextoDoQuadradoCentral(&corW)
    Assert(corW != "33CC66", "W o quadrado NAO fica verde ao trocar de time, cor=" corW)
    Assert(QuemBloqueiaOCombo(2) == "primeira_volta", "W o tooltip sabe quem segura: " QuemBloqueiaOCombo(2))
    ; Azul nos ultimos 10 s, verde no instante exato do lure.
    MockTick += lureW - 10000
    corW := ""
    TextoDoQuadradoCentral(&corW)
    Assert(corW == "33A3FF", "W faltando 10 s o quadrado fica azul, cor=" corW)
    ; Em amarelo/azul o combo arma em vez de executar.
    PedirCombo()
    Assert(ComboArmado && Scheduled.Length == 0, "W combo antes do verde arma e espera o ritmo")
    MockTick += 10000 - 1
    GameLoop()
    Assert(Scheduled.Length == 0, "W 1ms antes do lure ainda espera")
    MockTick += 1
    GameLoop()
    Assert(Scheduled.Length == 1 && ComboArmado, "W no instante do lure o combo armado agenda o disparo")
    Scheduled[1].Call()
    Assert(Scheduled.Length == 2 && RodizioAtivo, "W e o disparo agenda o rodizio")
    Scheduled[2].Call()
    Assert(TankJaCastou[2], "W o primeiro cast do time encerra o ritmo da primeira volta")
    Pass("W primeira volta: o CD zerado nao libera o combo antes do lure planejado")

    ; Depois do primeiro cast quem manda e so o cooldown real.
    ResetCase("WAITING_COMBO", 0, 0)
    TankJaCastou := Map(1, false, 2, false, 3, false)
    AplicarCast(1, false, MockTick - 60000)   ; cast ha 60 s: CD 45 s ja zerou
    Assert(TankJaCastou[1], "X o cast marca o time")
    Assert(FaltaParaComboViavelMs(1) == 0, "X com o time ja castado e CD zerado esta pronto")
    ; F8 volta a ligar o ritmo para todos.
    Resincronizar()
    Assert(!TankJaCastou[1] && !TankJaCastou[2] && !TankJaCastou[3], "X F8 liga o ritmo da primeira volta de novo")
    Pass("X o ritmo da primeira volta acaba no primeiro cast e volta com o F8")

    ; Ciclo completo simulado com as funcoes de producao: o jogador so deixa
    ; o macro agir no verde. Os casts do tank 1 em duas voltas tem de distar L.
    ResetCase("WAITING_FIRST_COMBO", 0, 0)
    TankJaCastou := Map(1, false, 2, false, 3, false)
    ResetarCooldowns(MockTick)
    planoY := PlanejarVolta()
    casts1 := []
    eventos := []
    fim := MockTick + 250000
    proxEvento := 0
    while (MockTick < fim && casts1.Length < 3) {
        if (FaseAtual == "WAITING_FIRST_COMBO" || (FaseAtual == "WAITING_COMBO" && FaltaParaVerdeMs() <= 0)) {
            tm := TimeAtual
            if (tm == 1)
                casts1.Push(MockTick)
            eventos.Push("t=" Round((MockTick - 100000) / 1000, 1) " COMBO time " tm)
            FaseAtual := "WAITING_TEAM_SWITCH"
            InicioDaFaseTick := MockTick
            RegistrarCast(tm)
            t0Y := MockTick
            p2Y := t0Y + SleepAfterTankCombo
            c2Y := p2Y + SleepAfterSwitch
            passoY := 0
        }
        if (IsSet(p2Y) && p2Y > 0 && MockTick >= p2Y) {
            RegistrarChamadaDoSecundario(TimeAtual)
            p2Y := 0
        }
        if (IsSet(c2Y) && c2Y > 0 && MockTick >= c2Y) {
            RegistrarCast(TimeAtual, true)
            c2Y := 0
        }
        if (FaseAtual == "WAITING_TEAM_SWITCH" && FaltaParaVerdeMs() <= 0) {
            eventos.Push("t=" Round((MockTick - 100000) / 1000, 1) " TROCA do time " TimeAtual)
            TrocarDeTime()
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
}

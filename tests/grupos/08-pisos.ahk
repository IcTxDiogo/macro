; Tema: Pisos de conforto: tempo fora minimo.
TestesPisos() {
    global
; --- PISOS DE CONFORTO: TEMPO FORA MINIMO DO TANK E DO SECUNDARIO ---
    ; O plano de volta minima usa so o cooldown. Os pisos dao ao jogador tempo
    ; para chegar ao ponto e puxar; o planejador acha a menor volta que cabe.
    ResetCase("WAITING_COMBO", 0, 0)
    planoBase := PlanejarVolta()
    LBase := planoBase.L
    secBase := planoBase.SecFora[1]
    ResetCase("WAITING_COMBO", 0, 0)
    Hoenn222_MinLureMs := Map(1, 15000, 2, 15000, 3, 15000)
    Hoenn222_MinSecondaryOutMs := Map(1, 8000, 2, 0, 3, 0)
    planoC := PlanejarVolta()
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
        Assert(recT >= CooldownBaseMs(k, false) + Hoenn222_MarginMs - 0.5, "AA tank " k " continua recuperando o CD: " Round(recT))
        FtS := planoC.SecFora[k]
        recS := (FtS - 2 * Hoenn222_LatencyMs) + (planoC.L - FtS) * Hoenn222_RateInBall
        Assert(recS >= CooldownBaseMs(k, true) + Hoenn222_MarginMs - 0.5, "AA secundario " k " continua recuperando o CD: " Round(recS))
    }
    ; Piso de lure: o combo nunca e liberado antes dele, mesmo com o CD pronto.
    ResetCase("WAITING_COMBO", 0, 0)
    Hoenn222_MinLureMs := Map(1, 15000, 2, 15000, 3, 15000)
    Assert(FaltaParaComboViavelMs(1) == 15000, "AA com CD pronto o combo espera o piso de lure")
    MockTick += 15000 - 1
    Assert(FaltaParaVerdeMs() == 1, "AA falta 1 ms para o piso")
    MockTick += 1
    Assert(FaltaParaVerdeMs() <= 0, "AA no piso libera")
    Pass("AA pisos de conforto: planejador respeita, volta cresce o minimo, CD segue recuperado")

    ; Valores invalidos no config nunca derrubam o plano: valem 0.
    ResetCase("WAITING_COMBO", 0, 0)
    Hoenn222_MinLureMs := Map(1, -5000, 2, "abc", 3, "")
    Hoenn222_MinSecondaryOutMs := 7
    planoI := PlanejarVolta()
    Assert(Abs(planoI.L - LBase) < 1, "AB config invalida volta ao plano minimo: " Round(planoI.L))
    Pass("AB piso invalido no config vale 0 e nao quebra o plano")

    ; Ciclo completo com pisos: a volta medida e a do plano e o lure real e o piso.
    ResetCase("WAITING_FIRST_COMBO", 0, 0)
    Hoenn222_MinLureMs := Map(1, 15000, 2, 15000, 3, 15000)
    Hoenn222_MinSecondaryOutMs := Map(1, 8000, 2, 0, 3, 0)
    TankJaCastou := Map(1, false, 2, false, 3, false)
    ResetarCooldowns(MockTick)
    planoS := PlanejarVolta()
    castsS := []
    luresS := []
    trocaS := MockTick
    p2S := 0
    c2S := 0
    tmS := 1
    fimS := MockTick + 400000
    while (MockTick < fimS && castsS.Length < 5) {
        if (FaseAtual == "WAITING_FIRST_COMBO" || (FaseAtual == "WAITING_COMBO" && FaltaParaVerdeMs() <= 0)) {
            tmS := TimeAtual
            if (tmS == 1)
                castsS.Push(MockTick)
            if (castsS.Length >= 2)
                luresS.Push(MockTick - trocaS)
            FaseAtual := "WAITING_TEAM_SWITCH"
            InicioDaFaseTick := MockTick
            RegistrarCast(tmS)
            p2S := MockTick + SleepAfterTankCombo
            c2S := p2S + SleepAfterSwitch
        }
        if (p2S > 0 && MockTick >= p2S) {
            RegistrarChamadaDoSecundario(tmS)
            p2S := 0
        }
        if (c2S > 0 && MockTick >= c2S) {
            RegistrarCast(tmS, true)
            c2S := 0
        }
        if (FaseAtual == "WAITING_TEAM_SWITCH" && FaltaParaVerdeMs() <= 0) {
            trocaS := MockTick
            TrocarDeTime()
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
}

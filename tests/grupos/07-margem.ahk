; Tema: Margem respeitada em todo cast (ciclo perfeito).
TestesMargem() {
    global
; --- MARGEM RESPEITADA EM TODO CAST (REGRESSAO DO TESTE EM JOGO) ---
    ; Com um jogador que age exatamente no verde, nenhum cast pode acontecer
    ; antes de CD zerado + margem. O secundario perdia a margem inteira porque a
    ; tolerancia ignorava a latencia da chamada: era usado ~10 ms depois do CD
    ; zerar em vez de 250 ms. Roda com o atraso de saida do secundario igual ao do
    ; tank e com o proprio (AD): o verde tem de seguir o atraso que o modelo usa.
    for exitZ in [Hoenn222_LatencyMs, 1100] {
    ResetCase("WAITING_FIRST_COMBO", 0, 0)
    Hoenn222_ExitLatencySecondaryMs := exitZ
    ToleranciaDoSecundarioMs := CalcularToleranciaDoSecundarioMs()
    TankJaCastou := Map(1, false, 2, false, 3, false)
    ResetarCooldowns(MockTick)
    pioresFolgas := Map("tank", 999999, "sec", 999999)
    voltaZ := 0
    p2Z := 0
    c2Z := 0
    tmZ := 1
    fimZ := MockTick + 330000
    while (MockTick < fimZ) {
        if (FaseAtual == "WAITING_FIRST_COMBO" || (FaseAtual == "WAITING_COMBO" && FaltaParaVerdeMs() <= 0)) {
            tmZ := TimeAtual
            if (tmZ == 1)
                voltaZ += 1
            if (voltaZ >= 2) {
                slotZ := SlotDoPokemon(tmZ, false)
                CdOf(slotZ)
                folga := (CooldownRestanteMs[slotZ] > 0) ? -CooldownRestanteMs[slotZ] : (MockTick - CooldownZerouTick[slotZ] - Hoenn222_MarginMs)
                pioresFolgas["tank"] := Min(pioresFolgas["tank"], folga)
            }
            FaseAtual := "WAITING_TEAM_SWITCH"
            InicioDaFaseTick := MockTick
            RegistrarCast(tmZ)
            p2Z := MockTick + SleepAfterTankCombo
            c2Z := p2Z + SleepAfterSwitch
        }
        if (p2Z > 0 && MockTick >= p2Z) {
            RegistrarChamadaDoSecundario(tmZ)
            p2Z := 0
        }
        if (c2Z > 0 && MockTick >= c2Z) {
            if (voltaZ >= 2) {
                slotZ := SlotDoPokemon(tmZ, true)
                CdOf(slotZ)
                folga := (CooldownRestanteMs[slotZ] > 0) ? -CooldownRestanteMs[slotZ] : (MockTick - CooldownZerouTick[slotZ] - Hoenn222_MarginMs)
                pioresFolgas["sec"] := Min(pioresFolgas["sec"], folga)
            }
            RegistrarCast(tmZ, true)
            c2Z := 0
        }
        if (FaseAtual == "WAITING_TEAM_SWITCH" && FaltaParaVerdeMs() <= 0)
            TrocarDeTime()
        MockTick += 10
    }
    Assert(voltaZ >= 4, "Z simulou voltas suficientes: " voltaZ)
    ; Passo da simulacao e 10 ms: tolera esse arredondamento, nada alem.
    Assert(pioresFolgas["tank"] >= -10, "Z tank respeita a margem (pior folga " Round(pioresFolgas["tank"]) "ms, saida sec " exitZ ")")
    Assert(pioresFolgas["sec"] >= -10, "Z secundario respeita a margem (pior folga " Round(pioresFolgas["sec"]) "ms, saida sec " exitZ ")")
    Pass("Z em ciclo perfeito todo cast, tank e secundario, ocorre depois de CD zerado + margem (saida do secundario " exitZ " ms)")
    }
}

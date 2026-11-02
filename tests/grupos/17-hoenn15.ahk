; Tema: modo Hoenn 1,5 (dois times de 3: abre / meio / finaliza, 4 lures por volta).

; Mesmo ponto de partida do plano discreto do 2-2-2, com o time do jogador como exemplo:
; time 1 = 410 Lendario / 330 SR (meio) / 326 SR; time 2 = 360 UR / 358 UR (meio) / 348 SR.
PrepararTeste15(estado := "WAITING_FIRST_COMBO") {
    global
    ResetCase(estado)
    ModoAtual := "Hoenn15"
    Hoenn222_UseDiscretePlanner := true
    Hoenn222_InBallWholeBlocks := true
    Hoenn222_InBallBlockMs := 2000
    Hoenn222_MarginMs := 0
    Hoenn222_ExitLatencySecondaryMs := 0
    Hoenn222_ComboPreparationMs := 235
    Hoenn222_PlannerOutReserveMs := 300
    Hoenn222_PlannerBallReserveMs := 500
    StartMode := "Hoenn222"
    Hoenn15_OpenerTier := Map(1, "Lendário", 2, "UR")
    Hoenn15_FinisherTier := Map(1, "SR", 2, "SR")
    Hoenn15_MiddlePart1Skills := Map(1, [{Key: "f9", CdMs: 45000}, {Key: "f6", CdMs: 20000}], 2, [{Key: "f6", CdMs: 40000}, {Key: "f5", CdMs: 35000}])
    Hoenn15_MiddlePart2Skills := Map(1, [{Key: "f8", CdMs: 40000}, {Key: "f7", CdMs: 40000}, {Key: "f5", CdMs: 35000}], 2, [{Key: "f8", CdMs: 43000}, {Key: "f7", CdMs: 40000}])
    Hoenn15_SkillGapMs := 300
    Hoenn15_SleepAfterPart1Ms := Map(1, 2700, 2, 2700)
    Hoenn15_SleepAfterPart2Ms := Map(1, 2700, 2, 2700)
    Hoenn15_MinLureMs := Map(1, 10000, 2, 10000)
    Hoenn15_MinLure2Ms := Map(1, 14000, 2, 14000)
    Hoenn15_GuestSkill := Map() ; os grupos AR-AX testam sem skill emprestada; o AY liga
    Hoenn15_GuestSleepAfterMs := 1000
    Plano15EmCache := false
    ResetarCooldowns(MockTick)
}

; Time 2 atual do jogador: 358 abre / 360 meio (f7+f5 | f8+stun f6) / 348; a lure 1 do time 2
; pega emprestada a F6 (20 s) do 330, que o time 1 tambem usa na parte 1.
LigarSkillEmprestada15() {
    global
    Hoenn15_MiddlePart1Skills := Map(1, [{Key: "f9", CdMs: 45000}, {Key: "f6", CdMs: 20000}], 2, [{Key: "f7", CdMs: 40000}, {Key: "f5", CdMs: 40000}])
    Hoenn15_MiddlePart2Skills := Map(1, [{Key: "f8", CdMs: 40000}, {Key: "f7", CdMs: 40000}, {Key: "f5", CdMs: 35000}], 2, [{Key: "f8", CdMs: 43000}, {Key: "f6", CdMs: 40000}])
    Hoenn15_GuestSkill := Map(2, {FromTeam: 1, Key: "f6", CdMs: 20000})
    Plano15EmCache := false
    ResetarCooldowns(MockTick)
}

TestesSkillEmprestada15() {
    global
    ; --- AY: teclas da parte 1 do time 2 com a F6 emprestada do 330 ---
    PrepararTeste15()
    LigarSkillEmprestada15()
    Assert(RelogiosDaPosicao15(1, 2).Length == 3 && RelogiosDaPosicao15(1, 2)[3] == 10, "AY o relogio da F6 emprestada anda com o 330")
    plano := PlanejarVolta15()
    ConferirPlano15(plano)
    Assert(Abs(plano.Fora[4] - plano.Lures[2] - SleepAfterTankCombo - plano.PreparoMs - DuracaoDoConvidado15Ms(2)) < 0.01, "AY a skill emprestada entra no periodo de quem abre, nao na lure")
    FileAppend("HOENN15_GUEST_PLAN L=" plano.L " ms_por_lure=" Round(plano.L / 4) " convidado_ms=" DuracaoDoConvidado15Ms(2) " lure1=" Round(plano.Lures[1]) "," Round(plano.Lures[2]) "`n", "*", "UTF-8")
    TimeAtual := 2, FaseAtual := "WAITING_COMBO", InicioDaFaseTick := MockTick - 120000
    AtualizarInterface()
    Assert(InStr(Rendered[-1].text, "Empr: f6 (time 1)"), "AY painel mostra a skill emprestada")
    Sent := [], Timeline := [], Scheduled := []
    AcaoBumpers("controller")
    Scheduled[1].Call()
    Assert(Join(Sent) == "{y}|{c}|{f}|{i}|{2}|{c}|{f}|{f6}|{5}|{c}|{f}|{f7}|{f5}|{e}", "AY parte 1 do time 2: combo, 330 F6, 360 f7 f5, pocao (" Join(Sent) ")")
    Assert(InStr(Join(Timeline), "send:{f6}|sleep:1000|send:{5}"), "AY espera depois da skill emprestada")
    Assert(InStr(DebugText(), "COMBO15_CONVIDADO | time=2 dono=1 tecla=f6"), "AY log da skill emprestada")
    Pass("AY 1,5: parte 1 do time 2 chama o 330 para a F6 e depois o meio")

    ; --- AZ: 200 voltas com a skill emprestada: nenhuma F6 (nem nada) com CD pendente ---
    PrepararTeste15("WAITING_COMBO")
    LigarSkillEmprestada15()
    DefinirTaxaDeRecuperacao(Relogio15(1, "abre"), Hoenn222_RateOutOfBall, MockTick, Hoenn222_LatencyMs)
    plano := PlanejarVolta15()
    MockAdvanceTime := true, MockSendMs := 17, MockCheckCast15 := true
    inicio := MockTick
    loop 400 {
        DiagnosticoAtivo := A_Index <= 3
        for faseEsperada in ["WAITING_PART2", "WAITING_TEAM_SWITCH"] {
            MockTick += Max(0, Ceil(FaltaParaVerdeMs()))
            Scheduled := []
            PedirProximaAcao("simulacao")
            Assert(Scheduled.Length == 1 && RodizioAtivo, "AZ botao agenda a parte")
            Scheduled[1].Call()
            Assert(!RodizioAtivo && FaseAtual == faseEsperada, "AZ parte avanca a fase")
        }
        MockTick += Max(0, Ceil(FaltaParaVerdeMs()))
        Scheduled := []
        PedirProximaAcao("simulacao")
        for callback in Scheduled.Clone()
            callback.Call()
        Assert(FaseAtual == "WAITING_COMBO", "AZ troca devolve a fase PARTE 1")
        Sent := [], Timeline := [], Scheduled := []
    }
    DiagnosticoAtivo := true
    media := (MockTick - inicio) / 200
    ; 8 casts por volta + a F6 emprestada nos dois usos (parte 1 do time 2 e do time 1).
    Assert(MockSimCasts15 == 2000, "AZ 200 voltas, 2000 casts verificados (" MockSimCasts15 ")")
    Assert(media >= plano.L - 1 && media - plano.L < 400, "AZ execucao reproduz o periodo planejado (media=" Round(media) " L=" plano.L ")")
    FileAppend("HOENN15_GUEST_SIM turns=200 casts=" MockSimCasts15 " cycle_mean_ms=" Round(media, 3) " plan_L=" plano.L " pending_casts=0`n", "*", "UTF-8")
    Pass("AZ 1,5 com skill emprestada: 200 voltas sem cast com CD pendente")
    PrepararTeste15()
    ResetCase()
}

; Os seis periodos fora somam a volta, cada Pokemon recupera o CD (com a reserva) e os
; pisos fisicos cabem.
ConferirPlano15(plano) {
    soma := 0
    loop 2 {
        time := A_Index
        loop 3 {
            posicao := A_Index
            f := plano.Fora[(time - 1) * 3 + posicao]
            soma += f
            atraso := (posicao == 1) ? 2 * Hoenn222_LatencyMs : Hoenn222_LatencyMs + Hoenn222_ExitLatencySecondaryMs
            cd := (posicao == 1) ? CooldownDoRelogio15Ms(time, "abre")
                : (posicao == 2) ? Max(CooldownDaParte15Ms(time, 1), CooldownDaParte15Ms(time, 2))
                : CooldownDoRelogio15Ms(time, "fim")
            recuperado := (f - atraso) * Hoenn222_RateOutOfBall + Floor((plano.L - f) / Hoenn222_InBallBlockMs) * CreditoDoBlocoBallMs()
            Assert(recuperado + 0.001 >= cd + Hoenn222_MarginMs + Hoenn222_PlannerOutReserveMs, "AR posicao " posicao " do time " time " recupera o CD")
        }
        Assert(plano.Lures[time] + 0.001 >= Hoenn15_MinLureMs[time], "AR lure 1 do time " time " respeita o minimo")
        foraMeio := plano.Fora[(time - 1) * 3 + 2]
        Assert(foraMeio + 0.001 >= SleepAfterSwitch + 50 + Hoenn15_SkillGapMs + DuracaoDaParte15Ms(time, 1) + PausaDepoisDaParte1Ms(time) + Hoenn15_MinLure2Ms[time] + DuracaoDaParte15Ms(time, 2) + PausaDepoisDaParte2Ms(time), "AR meio do time " time " cabe Pokestop, parte 1, pocao e a lure 2")
    }
    Assert(Abs(soma - plano.L) < 0.01, "AR os seis periodos fora somam a volta")
}

TestesHoenn15() {
    global
    ; --- AR: CD das partes e plano da volta ---
    PrepararTeste15()
    Assert(CooldownDaParte15Ms(1, 1) == 45000, "AR parte 1 do 330: a skill de 45 s manda")
    Assert(CooldownDaParte15Ms(1, 2) == 40300, "AR parte 2 do 330: 40 s enviada 300 ms depois")
    Assert(CooldownDaParte15Ms(2, 1) == 40000 && CooldownDaParte15Ms(2, 2) == 43000, "AR partes do 358")
    Assert(CooldownDoRelogio15Ms(1, "abre") == 40000 && CooldownDoRelogio15Ms(2, "abre") == 43000, "AR abre pelo tier")
    Assert(CooldownDoRelogio15Ms(1, "fim") == 45000 && CooldownDoRelogio15Ms(2, "fim") == 45000, "AR finaliza pelo tier")
    plano := PlanejarVolta15()
    ConferirPlano15(plano)
    Assert(PlanejarVolta15() == plano, "AR plano em cache")
    FileAppend("HOENN15_PLAN L=" plano.L " lures_por_volta=4 ms_por_lure=" Round(plano.L / 4) " fora=" Round(plano.Fora[1]) "," Round(plano.Fora[2]) "," Round(plano.Fora[3]) "," Round(plano.Fora[4]) "," Round(plano.Fora[5]) "," Round(plano.Fora[6]) " lure1=" Round(plano.Lures[1]) "," Round(plano.Lures[2]) "`n", "*", "UTF-8")
    Pass("AR 1,5: CD por parte do meio, plano dos seis e lures minimas")

    ; --- AS: teclas de uma volta inteira pelo botao unico ---
    PrepararTeste15()
    AcaoBumpers("controller")
    Assert(Scheduled.Length == 1 && RodizioAtivo, "AS antes do 1o combo a parte 1 executa na hora")
    Scheduled[1].Call()
    Assert(Join(Sent) == "{y}|{c}|{f}|{i}|{2}|{c}|{f}|{f9}|{f6}|{e}", "AS parte 1 do time 1: combo, chama {2}, Pokestop, Medicine, f9 f6, pocao (" Join(Sent) ")")
    Assert(InStr(Join(Timeline), "send:{2}|sleep:" SleepAfterSwitch "|send:{c}|sleep:50|send:{f}|sleep:300|send:{f9}|sleep:300|send:{f6}|sleep:2700|send:{e}"), "AS esperas da parte 1: " Join(Timeline))
    Assert(FaseAtual == "WAITING_PART2" && !RodizioAtivo, "AS depois da parte 1 a fase e PARTE 2")
    AtualizarInterface()
    Assert(InStr(Rendered[-1].text, "HOENN 1,5 | TIME 1") && InStr(Rendered[-1].text, "PARTE 2") && InStr(Rendered[-1].text, "Meio: f8 f7 f5"), "AS painel da parte 2")
    MockTick += 120000
    Sent := [], Timeline := [], Scheduled := []
    AcaoBumpers("controller")
    Scheduled[1].Call()
    Assert(Join(Sent) == "{f8}|{f7}|{f5}|{3}|{y}|{c}|{f}|{i}", "AS parte 2 do time 1: f8 f7 f5, chama {3}, combo (" Join(Sent) ")")
    Assert(InStr(Join(Timeline), "sleep:2700") && InStr(Join(Timeline), "sleep:" SleepAfterCombo), "AS esperas da parte 2")
    Assert(FaseAtual == "WAITING_TEAM_SWITCH", "AS depois da parte 2 a fase e TROCAR TIME")
    MockTick += 120000
    Sent := [], Timeline := [], Scheduled := []
    AcaoBumpers("controller")
    Assert(TimeAtual == 2 && Sent[1] == "{4}" && FaseAtual == "WAITING_COMBO", "AS troca chama {4}, quem abre o time 2")
    Assert(TextoDeStatus == "Modo: Hoenn 1,5 - Time: 2", "AS status do 1,5")
    MockTick += 120000
    Sent := [], Scheduled := []
    AcaoBumpers("controller")
    Scheduled[1].Call()
    Assert(Join(Sent) == "{y}|{c}|{f}|{i}|{5}|{c}|{f}|{f6}|{f5}|{e}", "AS parte 1 do time 2 (" Join(Sent) ")")
    MockTick += 120000
    Sent := [], Scheduled := []
    AcaoBumpers("controller")
    Scheduled[1].Call()
    Assert(Join(Sent) == "{f8}|{f7}|{6}|{y}|{c}|{f}|{i}", "AS parte 2 do time 2 (" Join(Sent) ")")
    MockTick += 120000
    Sent := []
    AcaoBumpers("controller")
    Assert(TimeAtual == 1 && Sent[1] == "{1}", "AS troca volta ao time 1 com {1}")
    Pass("AS 1,5: volta inteira pelo botao unico (parte 1, parte 2, troca) nos dois times")

    ; --- AT: 200 voltas pela sequencia de producao, com o relogio andando ---
    PrepararTeste15("WAITING_COMBO")
    DefinirTaxaDeRecuperacao(Relogio15(1, "abre"), Hoenn222_RateOutOfBall, MockTick, Hoenn222_LatencyMs)
    plano := PlanejarVolta15()
    MockAdvanceTime := true, MockSendMs := 17, MockCheckCast15 := true
    inicio := MockTick
    loop 400 {
        DiagnosticoAtivo := A_Index <= 3 ; logs de amostra; evitar I/O de 200 voltas no teste
        for faseEsperada in ["WAITING_PART2", "WAITING_TEAM_SWITCH"] {
            MockTick += Max(0, Ceil(FaltaParaVerdeMs()))
            Assert(FaltaParaVerdeMs() <= 0.001, "AT aguardar o verde antes de cada parte")
            Scheduled := []
            PedirProximaAcao("simulacao")
            Assert(Scheduled.Length == 1 && RodizioAtivo, "AT botao agenda a parte")
            Scheduled[1].Call()
            Assert(!RodizioAtivo && FaseAtual == faseEsperada, "AT parte avanca a fase para " faseEsperada)
        }
        MockTick += Max(0, Ceil(FaltaParaVerdeMs()))
        Scheduled := []
        PedirProximaAcao("simulacao")
        for callback in Scheduled.Clone()
            callback.Call()
        Assert(FaseAtual == "WAITING_COMBO", "AT troca devolve a fase PARTE 1")
        Sent := [], Timeline := [], Scheduled := []
    }
    DiagnosticoAtivo := true
    media := (MockTick - inicio) / 200
    Assert(MockSimCasts15 == 1600, "AT 200 voltas, 1600 casts verificados (" MockSimCasts15 ")")
    Assert(media >= plano.L - 1 && media - plano.L < 300, "AT execucao reproduz o periodo planejado (media=" Round(media) " L=" plano.L ")")
    FileAppend("HOENN15_SIM turns=200 casts=" MockSimCasts15 " cycle_mean_ms=" Round(media, 3) " plan_L=" plano.L " pending_casts=0`n", "*", "UTF-8")
    Pass("AT 1,5: 200 voltas, um Pokemon fora por vez e nenhum CD pendente em nenhum cast")

    ; --- AU: parte armada, verde automatico, F8 ---
    PrepararTeste15()
    PedirProximaAcao("controller")
    Scheduled[1].Call()
    MockTick += 1000
    Sent := [], Scheduled := []
    PedirProximaAcao("controller")
    Assert(ComboArmado && Scheduled.Length == 0 && Sent.Length == 0, "AU parte 2 antes do verde arma")
    Assert(InStr(DebugText(), "CD_ANTECIPACAO | time=1 modo=1,5 fase=WAITING_PART2"), "AU diagnostico do 1,5")
    AtualizarInterface()
    Assert(InStr(Rendered[-1].text, "PARTE ARMADA"), "AU painel mostra a parte armada")
    Assert(CorDoQuadrado(FaltaParaVerdeMs(), FaseAtual, true) == "B266FF", "AU quadrado violeta")
    MockTick += Ceil(FaltaParaVerdeMs()) + 1
    GameLoop()
    Assert(Scheduled.Length == 1, "AU no verde a parte armada e agendada")
    Scheduled[1].Call()
    Assert(Scheduled.Length == 2 && RodizioAtivo, "AU a thread descartavel inicia a parte 2")
    Scheduled[2].Call()
    Assert(FaseAtual == "WAITING_TEAM_SWITCH" && Sent[1] == "{f8}", "AU parte 2 executada no verde")
    PedirProximaAcao("controller")
    Assert(TrocaArmada, "AU troca armada em TROCAR TIME")
    Resincronizar()
    Assert(!TrocaArmada && FaseAtual == "WAITING_FIRST_COMBO" && ChamadaDoMeio15Tick[1] == 0 && ChamadaDoFinalizador15Tick[1] == 0, "AU F8 desarma e limpa as ancoras do 1,5")
    Assert(TimeAtual == 1, "AU F8 mantem o time")
    Pass("AU 1,5: parte armada dispara no verde; troca armada; F8 limpa")

    ; --- AV: F12 / Back giram Normal -> 2-2-2 -> 1,5 -> Normal ---
    ResetCase("WAITING_COMBO")
    TimeAtual := 3
    AplicarCast(3, true, MockTick) ; secundario em CD: o combo arma em vez de executar
    PedirCombo()
    Assert(ComboArmado, "AV pedido armado no 2-2-2")
    TrocarModo()
    Assert(ModoAtual == "Hoenn15" && TimeAtual == 1 && FaseAtual == "WAITING_FIRST_COMBO" && !ComboArmado, "AV F12: 2-2-2 -> 1,5 no time 1, ressincronizado e sem armado")
    Assert(TextoDeStatus == "Modo: Hoenn 1,5 - Time: 1", "AV status do 1,5")
    AtualizarInterface()
    Assert(InStr(Rendered[-1].text, "HOENN 1,5 | TIME 1"), "AV painel do 1,5")
    TrocarModo()
    Assert(ModoAtual == "Normal", "AV F12: 1,5 -> Normal")
    AtualizarInterface()
    Assert(Rendered[-1].text == "Modo: Normal", "AV painel do Normal")
    TrocarModo()
    Assert(ModoAtual == "Hoenn222" && FaseAtual == "WAITING_FIRST_COMBO", "AV F12: Normal -> 2-2-2")
    Pass("AV F12 gira Normal -> 2-2-2 -> 1,5 -> Normal")

    ; --- AW: config invalido avisa e nunca prende a troca ---
    PrepararTeste15()
    Hoenn15_MiddlePart1Skills := Map(1, [], 2, [{Key: "f6", CdMs: 40000}])
    StartMode := "Hoenn99"
    problemas := Join(ValidarConfig())
    Assert(InStr(problemas, "1,5: skills da parte 1 do time 1 ausentes"), "AW skills ausentes avisam: " problemas)
    Assert(InStr(problemas, "StartMode invalido: Hoenn99") && ModoInicialDoConfig() == "Hoenn222", "AW StartMode invalido vira 2-2-2")
    Plano15EmCache := false
    FaseAtual := "WAITING_TEAM_SWITCH", InicioDaFaseTick := MockTick
    Assert(FaltaParaVerdeMs() <= 0, "AW plano invalido: troca fica verde (nunca presa)")
    Sent := []
    PedirProximaAcao("controller")
    Assert(TimeAtual == 2 && Sent[1] == "{4}", "AW troca executa com config do 1,5 invalido")
    Pass("AW 1,5: config invalido avisa e a troca nunca fica presa")

    ; --- AX: o 2-2-2 continua com o mesmo plano depois do 1,5 ---
    PrepararTesteDiscreto()
    Assert(PlanejarVolta().L == 76300, "AX plano do 2-2-2 inalterado")
    Pass("AX 2-2-2 inalterado")

    PrepararTeste15()
    ResetCase()
}

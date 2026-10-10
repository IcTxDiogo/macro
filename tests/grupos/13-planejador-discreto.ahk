; Plano novo, rollback e execucao de producao com relogio/teclas simulados.
PrepararTesteDiscreto() {
    global
    ResetCase("WAITING_COMBO")
    Hoenn222_UseDiscretePlanner := true
    Hoenn222_InBallWholeBlocks := true
    Hoenn222_InBallBlockMs := 2000
    Hoenn222_MarginMs := 0
    Hoenn222_ExitLatencySecondaryMs := 0
    Hoenn222_ComboPreparationMs := 235
    Hoenn222_PlannerOutReserveMs := 300
    Hoenn222_PlannerBallReserveMs := 500
    ResetarCooldowns(MockTick)
    DefinirTaxaDeRecuperacao(1, Hoenn222_RateOutOfBall, MockTick, Hoenn222_LatencyMs)
    PlanoEmCache := false
}

ConferirPlanoDiscreto(plano) {
    soma := 0
    loop 3 {
        duplaDoPlano := A_Index
        Assert(Abs(plano.TankFora[duplaDoPlano] - plano.Lures[duplaDoPlano] - SleepAfterTankCombo - plano.PreparoMs) < 0.001, "AK preparo aparece uma vez no tank")
        Assert(Abs(plano.Janelas[duplaDoPlano] - plano.TankFora[duplaDoPlano] - plano.SecFora[duplaDoPlano]) < 0.001, "AK dupla soma seus dois periodos fora")
        for secundario in [false, true] {
            f := secundario ? plano.SecFora[duplaDoPlano] : plano.TankFora[duplaDoPlano]
            atraso := Hoenn222_LatencyMs + (secundario ? Hoenn222_ExitLatencySecondaryMs : Hoenn222_LatencyMs)
            recuperado := (f - atraso) * Hoenn222_RateOutOfBall + Floor((plano.L - f) / Hoenn222_InBallBlockMs) * CreditoDoBlocoBallMs()
            Assert(recuperado + 0.001 >= CooldownBaseMs(duplaDoPlano, secundario) + Hoenn222_MarginMs + Hoenn222_PlannerOutReserveMs, "AK plano garante recuperacao discreta")
        }
        soma += plano.Janelas[duplaDoPlano]
    }
    Assert(Abs(soma - plano.L) < 0.001, "AK soma das seis janelas coincide com a volta")
}

TestesPlanejadorDiscreto() {
    global
    PrepararTesteDiscreto()
    inicioBusca := DllCall("GetTickCount64", "UInt64")
    plano := PlanejarVolta()
    buscaMs := DllCall("GetTickCount64", "UInt64") - inicioBusca
    ConferirPlanoDiscreto(plano)
    Assert(plano.L == 76300, "AK periodo derivado dos CDs, sem timer fixo")
    Assert(PlanejarVolta() == plano, "AK consultas usam o cache, nao repetem a busca")
    FileAppend("DISCRETE_PLAN L=" plano.L " tank=" Round(plano.TankFora[1], 3) "," Round(plano.TankFora[2], 3) "," Round(plano.TankFora[3], 3) " sec=" Round(plano.SecFora[1], 3) "," Round(plano.SecFora[2], 3) "," Round(plano.SecFora[3], 3) " planning_ms=" buscaMs "`n", "*", "UTF-8")
    Pass("AK plano discreto de 76,3 s, seis periodos, preparo unico e cache")
    Hoenn222_PlannerOutReserveMs := 0, Hoenn222_PlannerBallReserveMs := 0, PlanoEmCache := false
    minimo := PlanejarVolta()
    Assert(minimo.L == 75500, "AK sem reservas o algoritmo encontra o minimo matematico de 75,5 s")
    Hoenn222_PlannerOutReserveMs := 300, Hoenn222_PlannerBallReserveMs := 500, PlanoEmCache := false

    tiersTank := Hoenn222_TankTier, tiersSec := Hoenn222_SecondTier
    for tiers in [Map(1, "T1", 2, "SR", 3, "UR"), Map(1, "UR", 2, "T1", 3, "SR")] {
        Hoenn222_TankTier := tiers
        Hoenn222_SecondTier := Map(1, "UR", 2, "Lendário", 3, "T1")
        PlanoEmCache := false
        outro := PlanejarVolta()
        ConferirPlanoDiscreto(outro)
        Assert(outro.L != plano.L, "AL plano deriva outros tiers")
        Assert(Abs(outro.Lures[1] - outro.Lures[2]) > 1, "AL nao impoe lures iguais")
    }
    Hoenn222_TankTier := tiersTank, Hoenn222_SecondTier := tiersSec
    Hoenn222_UseDiscretePlanner := false, PlanoEmCache := false
    legado := PlanejarVolta()
    Assert(Abs(legado.L - 75214.285714) < 1, "AL rollback recupera plano nominal estavel")
    Assert(TempoAteChamadaPrevistoMs() == 2700, "AL rollback recupera previsao anterior")
    Pass("AL outros tiers, lures diferentes e rollback sem mudar o acumulador")

    PrepararTesteDiscreto()
    plano := PlanejarVolta()
    FaseAtual := "WAITING_TEAM_SWITCH"
    InicioDaFaseTick := MockTick
    antes := DuracaoDoTrocarTimeMs(1)
    MockTick += 2700 + 285
    RegistrarChamadaDoSecundario(1)
    depois := DuracaoDoTrocarTimeMs(1)
    Assert(Abs(depois - antes - 50) < 0.001, "AM preparo mais lento estende prazo real, nao rouba tempo fora")
    Assert(Abs(depois - (MockTick - InicioDaFaseTick) - plano.SecFora[1]) < 0.001, "AM janela ancorada na chamada real")
    Resincronizar()
    Assert(FaseAtual == "WAITING_FIRST_COMBO" && ChamadaDoSecundarioTick[1] == 0, "AM F8 limpa ancora real")
    Pass("AM chamada real preserva janela e F8 elimina timestamps antigos")

    PrepararTesteDiscreto()
    plano := PlanejarVolta()
    InicioDaFaseTick := MockTick - Ceil(plano.Lures[1])
    CooldownRestanteMs[2] := 1801
    CooldownFracaoBallMs[2] := 1000
    Assert(FaltaParaSecundarioEmBlocosMs(1) == 150, "AQ verde usa preparo minimo garantido, nao os 235 ms estimados")
    Assert(CooldownPendenteDoSecundarioMs(1, 149) > 0, "AQ nao antecipa para ganhar uma fracao de bloco")
    MockTick += 150 + SleepAfterTankCombo + 150
    RegistrarChamadaDoSecundario(1)
    MockTick += SleepAfterSwitch
    Assert(MsAteCastSeguro(2, MockTick) == 0, "AQ mesmo com preparo de apenas 150 ms o secundario esta pronto")
    Pass("AQ previsao conservadora preserva cast seguro quando o preparo e mais rapido")

    PrepararTesteDiscreto()
    plano := PlanejarVolta()
    ; Simulacao da sequencia REAL: os mocks avancam o relogio em cada Sleep/ControlSend.
    MockAdvanceTime := true, MockSendMs := 17, MockCheckCast := true
    inicio := MockTick
    loop 600 {
        DiagnosticoAtivo := A_Index <= 3 ; logs de amostra; evitar I/O de 200 voltas no teste
        MockTick += Max(0, Ceil(FaltaParaVerdeMs()))
        Assert(FaltaParaVerdeMs() <= 0.001, "AN aguardar o verde antes de cada combo")
        Scheduled := []
        PedirProximaAcao("simulacao")
        Assert(Scheduled.Length == 1 && RodizioAtivo, "AN botao agenda rodizio")
        Scheduled[1].Call()
        Assert(!RodizioAtivo && FaseAtual == "WAITING_TEAM_SWITCH", "AN combo mantem maquina de estados")
        Assert(StrLen(Join(Sent)) > 0, "AN rotina de skills executada nos mocks")
        MockTick += Max(0, Ceil(FaltaParaVerdeMs()))
        Scheduled := []
        PedirProximaAcao("simulacao")
        ; Troca imediata pode rodar direto; verificar time e fase depois de timers, se houver.
        for callback in Scheduled.Clone()
            callback.Call()
        Assert(FaseAtual == "WAITING_COMBO", "AN troca devolve fase COMBAR")
        Sent := [], Timeline := [], Scheduled := []
    }
    media := (MockTick - inicio) / 200
    Assert(MockSimCasts == 1200, "AN 200 voltas completas, 1200 casts verificados")
    Assert(Abs(media - plano.L) < 100, "AN execucao reproduz periodo planejado")
    FileAppend("DISCRETE_SIM turns=200 casts=" MockSimCasts " cycle_mean_ms=" Round(media, 3) " pending_casts=0`n", "*", "UTF-8")
    Pass("AN 200 voltas pela sequencia de producao, apenas um fora e nenhum CD pendente")

    ; Calendario aberto: nao usar o verde para esconder a inviabilidade sob +/-200 ms.
    menor := SimularVariacaoDiscreta(plano, 100, 50)
    maior := SimularVariacaoDiscreta(plano, 200, 50)
    Assert(menor.Falhas == 0, "AP distribuicao suporta +/-100 ms e preparo +/-50 ms")
    Assert(maior.Falhas > 0, "AP calendario de 76,3 s NAO garante +/-200 ms e preparo +/-50 ms")
    FileAppend("DISCRETE_JITTER command_ms=100 prep_ms=50 turns=200 checks=" menor.Casts " pending_casts=" menor.Falhas "`n", "*", "UTF-8")
    FileAppend("DISCRETE_JITTER command_ms=200 prep_ms=50 turns=200 checks=" maior.Casts " pending_casts=" maior.Falhas " worst_pending_ms=" Round(maior.Pior, 3) "`n", "*", "UTF-8")
    Pass("AP variacao temporal: 100 ms passa; 200 ms expõe falta de cooldown sem aumentar reservas")

    PrepararTesteDiscreto()
    PlanoEmCache := false
    ; Cobrir antecipacao, invalidez de contexto, emergencia e modos com o plano ativo.
    PedirProximaAcao("simulacao")
    Assert(ComboArmado && Scheduled.Length == 0, "AO antes do lure arma sem enviar")
    MockTick += Ceil(FaltaParaVerdeMs()) + 500
    VerificarPedidosArmados()
    Assert(Scheduled.Length == 1, "AO atraso libera uma unica acao armada")
    TrocarModo()
    Assert(ModoAtual == "Normal" && !ComboArmado, "AO modo normal cancela armado")
    Scheduled[1].Call()
    if (Scheduled.Length > 1)
        Scheduled[2].Call() ; a thread do rodizio valida modo/contexto antes de enviar
    Assert(!RodizioAtivo, "AO callback antigo nao executa em outro modo")
    TrocarModo()
    Assert(FaseAtual == "WAITING_FIRST_COMBO", "AO voltar ao Hoenn ressincroniza")
    FaseAtual := "WAITING_COMBO", InicioDaFaseTick := MockTick
    Scheduled := []
    PedirCombo()
    MockTick += 50
    PedirCombo()
    Assert(RodizioAtivo && Scheduled.Length == 1, "AO emergencia continua explicitamente ignorando o verde")
    Resincronizar()
    Scheduled[1].Call()
    Assert(!RodizioAtivo && FaseAtual == "WAITING_FIRST_COMBO", "AO F8 invalida rodizio agendado")
    Pass("AO armado, atraso, emergencia, F8 e troca de modos com plano novo")
    ResetCase()
}

DeslocamentoDiagnosticoMs(limite, &semente) {
    semente := Mod(semente * 48271, 2147483647)
    return (2 * semente / 2147483647 - 1) * limite
}

SimularVariacaoDiscreta(plano, variacao, variacaoPreparo) {
    global MockTick, DiagnosticoAtivo
    ResetarCooldowns(MockTick)
    origem := MockTick + 1000
    semente := 1234567
    falhas := 0, castsVariacao := 0, pior := 0
    DiagnosticoAtivo := false
    loop 200 {
        volta := A_Index - 1
        inicioDupla := 0
        loop 3 {
            dupla := A_Index
            entradaVariacao := origem + volta * plano.L + inicioDupla + DeslocamentoDiagnosticoMs(variacao, &semente)
            tank := origem + volta * plano.L + inicioDupla + plano.Lures[dupla] + DeslocamentoDiagnosticoMs(variacao, &semente)
            preparo := plano.PreparoMs + DeslocamentoDiagnosticoMs(variacaoPreparo, &semente)
            MockTick := entradaVariacao
            RegistrarTrocaDeTime(dupla == 1 ? 3 : dupla - 1, dupla, MockTick)
            MockTick := tank
            restante := MsAteCastSeguro(SlotDoPokemon(dupla, false), MockTick)
            if (volta > 0) {
                castsVariacao++
                falhas += restante > 0.001 ? 1 : 0
                pior := Max(pior, restante)
            }
            AplicarCast(dupla, false, MockTick)
            MockTick := tank + SleepAfterTankCombo + preparo
            RegistrarChamadaDoSecundario(dupla)
            MockTick += SleepAfterSwitch
            restante := MsAteCastSeguro(SlotDoPokemon(dupla, true), MockTick)
            if (volta > 0) {
                castsVariacao++
                falhas += restante > 0.001 ? 1 : 0
                pior := Max(pior, restante)
            }
            AplicarCast(dupla, true, MockTick)
            inicioDupla += plano.Janelas[dupla]
        }
    }
    DiagnosticoAtivo := true
    return {Falhas: falhas, Casts: castsVariacao, Pior: pior}
}

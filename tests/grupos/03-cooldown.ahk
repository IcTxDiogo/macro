; Tema: Cooldown individual, tiers, plano, intervalos fixos, otimizador desligado.
TestesCooldown() {
    global

    ResetCase("WAITING_COMBO", 0, 0)
    ; O mapeamento tier -> CD vem da tabela do config. Cada tier tem de
    ; devolver o valor declarado, e mudar o rotulo muda so o CD.
    for time in [1, 2, 3]
        for papel in [false, true] {
            tier := papel ? Hoenn222_SecondTier[time] : Hoenn222_TankTier[time]
            Assert(CooldownBaseMs(time, papel) == Hoenn222_CdByTier[tier],
                "F dupla " time " " (papel ? "secundario" : "tank") " tier " tier " -> " Hoenn222_CdByTier[tier] "ms")
        }
    ; Tier desconhecido cai no padrao, com aviso unico.
    savedTier2 := Hoenn222_TankTier[2]
    Hoenn222_TankTier[2] := "inexistente"
    global AvisoDeTierDesconhecidoFeito := false
    Assert(CooldownBaseMs(2, false) == Hoenn222_CdDefaultMs, "F tier desconhecido usa o padrao")
    Hoenn222_TankTier[2] := savedTier2
    savedTankTier := Hoenn222_TankTier[1]
    Hoenn222_TankTier[1] := "Lendário"
    Assert(CooldownBaseMs(1, false) == Hoenn222_CdByTier["Lendário"], "F mudar so o rotulo muda so o CD")
    Hoenn222_TankTier[1] := savedTankTier
    Assert(RotuloDoTier(9, "tank") == "?", "F unknown team falls back")
    PlanejarVolta()
    Assert(PlanoEmCache.L > 0 && PlanoEmCache.Janelas.Length == 3, "F plano em cache com tres janelas")
    ; --- A RECUPERACAO E CONTADA ENTRE DOIS CASTS CONSECUTIVOS ---
    ; O CD nasce no cast e precisa zerar antes do proximo. Nesse intervalo
    ; o Pokemon recupera, e cada segundo conta onde acontecer: logo depois
    ; do cast (1,0x), guardado no meio da volta (0,5x) e DE NOVO fora
    ; durante o lure ANTES do proximo cast (1,0x). O lure nao e tempo
    ; perdido: e o cooldown do cast anterior que continua correndo ali.
    ;   F = tempo total fora entre dois casts
    ;   (F - Lat)*1,0 + (L - F)*0,5 >= CD + Margem
    ;   => F >= 2*(CD + Lat + Margem) - L
    ; Para o tank, F = lure + P: ele so pode ficar fora dentro da janela
    ; dele, da troca ate a chamada do p2.
    ; Para o secundario, F = janela - lure - P.
    ; E as tres janelas somam exatamente L.
    margemEfetiva := Hoenn222_LatencyMs + Hoenn222_MarginMs
    minSec := SleepAfterSwitch + SleepAfterCombo
    for k in [1, 2, 3] {
        cdT := CooldownBaseMs(k, false)
        cdS := CooldownBaseMs(k, true)
        F_tank := Max(SleepAfterTankCombo, 2 * (cdT + margemEfetiva) - PlanoEmCache.L)
        F_sec := Max(minSec, 2 * (cdS + margemEfetiva) - PlanoEmCache.L)
        lure := PlanoEmCache.Lures[k]
        ; a janela tem de ser exatamente lure + P + tempo do secundario fora
        Assert(Abs(PlanoEmCache.Janelas[k] - (lure + SleepAfterTankCombo + (PlanoEmCache.Janelas[k] - lure - SleepAfterTankCombo))) < 1,
            "F janela " k " = lure + P + sec")
        Assert(Abs(PlanoEmCache.TankFora[k] - (lure + SleepAfterTankCombo)) < 1,
            "F tank fora " k " = lure " Round(lure) " + P " SleepAfterTankCombo " = " Round(PlanoEmCache.TankFora[k]))
        Assert(F_tank <= PlanoEmCache.TankFora[k] + 0.5, "F tank da dupla " k
            " tem tempo fora suficiente: " Round(PlanoEmCache.TankFora[k]) " >= " Round(F_tank))
        Assert(F_sec <= PlanoEmCache.SecFora[k] + 0.5, "F secundario da dupla " k
            " tem tempo fora suficiente: " Round(PlanoEmCache.SecFora[k]) " >= " Round(F_sec))
        ; recuperacao efetiva, conferida pela fisica
        Ftotal := PlanoEmCache.TankFora[k]
        ; O tank perde a latencia na saida da Ball (troca de time) e no cast.
        recT := (Ftotal - 2 * Hoenn222_LatencyMs)
            + (PlanoEmCache.L - Ftotal) * Hoenn222_RateInBall
        Assert(recT >= cdT + Hoenn222_MarginMs - 0.5, "F tank " k " recupera "
            Round(recT) "ms para um CD de " cdT "ms")
        FtotS := PlanoEmCache.SecFora[k]
        ; O secundario perde a latencia na saida da Ball (chamada) e no inicio do CD novo.
        recS := (FtotS - 2 * Hoenn222_LatencyMs)
            + (PlanoEmCache.L - FtotS) * Hoenn222_RateInBall
        Assert(recS >= cdS + Hoenn222_MarginMs - 0.5, "F secundario " k " recupera "
            Round(recS) "ms para um CD de " cdS "ms")
    }
    ; As tres janelas tem de fechar exatamente em L.
    somaJanelas := PlanoEmCache.Janelas[1] + PlanoEmCache.Janelas[2] + PlanoEmCache.Janelas[3]
    Assert(Abs(somaJanelas - PlanoEmCache.L) < 1, "F soma das janelas " Round(somaJanelas)
        " = L " Round(PlanoEmCache.L))
    ; E o piso global de 3,5x: o limite inferior real.
    somaCd := 0
    for k in [1, 2, 3]
        somaCd += CooldownBaseMs(k, false) + CooldownBaseMs(k, true)
    ; Os seis perdem 2 latencias por intervalo: saida da Ball e inicio do CD novo.
    pisoGlobal := (somaCd + 6 * (margemEfetiva + Hoenn222_LatencyMs)) / (1 + 5 * Hoenn222_RateInBall)
    Assert(PlanoEmCache.L >= pisoGlobal - 1, "F L=" Round(PlanoEmCache.L)
        " respeita o piso de 3,5x com margem " Round(pisoGlobal))
    Assert(Abs(PlanoEmCache.L - pisoGlobal) < 1, "F L atinge o piso idealizado "
        Round(pisoGlobal))
    ; Nenhum tempo fora pode passar da duracao da volta.
    totalFora := 0
    for k in [1, 2, 3]
        totalFora += PlanoEmCache.TankFora[k] + PlanoEmCache.SecFora[k]
    Assert(totalFora <= PlanoEmCache.L + 0.5, "F soma dos tempos fora "
        Round(totalFora) " cabe na volta " Round(PlanoEmCache.L))
    ; Janela minima: precisa comportar o combo inteiro.
    minimo := SleepAfterTankCombo + minSec
    for k in [1, 2, 3]
        Assert(PlanoEmCache.Janelas[k] >= minimo, "F janela da dupla " k " comporta 2700+800+3000")
    ; O plano so depende da configuracao, entao e estavel e fica em cache.
    L1 := PlanoEmCache.L
    janela1 := PlanoEmCache.Janelas[1]
    global PlanoEmCache := false
    plano2 := PlanejarVolta()
    Assert(plano2.L == L1 && plano2.Janelas[1] == janela1, "F mesma configuracao, mesmo plano")
    ; Um tank de CD maior tem de aumentar a volta: e o gargalo real.
    savedTier1 := Hoenn222_TankTier[1]
    Hoenn222_TankTier[1] := "T1"
    global PlanoEmCache := false
    plano3 := PlanejarVolta()
    Assert(plano3.L > L1, "F tank mais lento aumenta a volta: " Round(L1) " -> " Round(plano3.L))
    Hoenn222_TankTier[1] := savedTier1
    global PlanoEmCache := false
    PlanejarVolta()
    ResetCase("WAITING_COMBO", 0, 1000)
    AtualizarInterface()
    Assert(Rendered.Length == 2 && InStr(Rendered[2].text, "Tank: ") && InStr(Rendered[2].text, "Sec: "), "F tiers shown")
    Pass("F tiers, CD and windows all come from config")

    ResetCase("WAITING_COMBO", 0, 0)
    cdT1 := CooldownBaseMs(1, false)
    AplicarCast(1, false, MockTick)
    ; O CD so comeca a contar LatencyMs depois do comando; ate la ele vale cheio.
    MockTick += Hoenn222_LatencyMs
    Assert(CdOf(SlotDoPokemon(1, false)) == cdT1, "H cast carrega o CD principal e taxa 1,0 fora da Ball")
    Assert(CdRateOf(SlotDoPokemon(1, false)) == Hoenn222_RateOutOfBall, "H usar a skill implica estar fora da Ball")
    Assert(MsAteCastSeguro(SlotDoPokemon(1, false), MockTick) == cdT1 + Hoenn222_MarginMs, "H pronto = CD + margem")
    Assert(FaltaParaComboViavelMs(1) == cdT1 + Hoenn222_MarginMs, "H alvo de COMBAR segue o CD do tank")
    Assert(QuemBloqueiaOCombo(1) == "tank", "H tank segurando o verde")
    DefinirTaxaDeRecuperacao(SlotDoPokemon(1, false), Hoenn222_RateInBall, MockTick)
    ; 20000ms dentro da Ball a 0,5 tiram 10000ms de CD, nao 20000.
    MockTick += 20000
    Assert(CdOf(SlotDoPokemon(1, false)) == cdT1 - 10000, "H 20000ms a 0,5 tiram 10000ms de CD")
    Assert(MsAteCastSeguro(SlotDoPokemon(1, false), MockTick)
        == (cdT1 - 10000) / Hoenn222_RateInBall + Hoenn222_MarginMs, "H dentro da Ball o mesmo CD custa o dobro")
    Pass("H target follows the individual CD and the in-ball rate")

; --- INTERVALOS INTERNOS: NUNCA ESTENDIDOS ---
    ; O macro nao estende a espera entre tank, chamada e secundario. Se o
    ; secundario nao couber, o verde simplesmente nao acende e o macro avisa.
    Assert(SleepAfterTankCombo == 2700, "I animacao do tank usa 2700 no teste atual")
    Assert(SleepAfterSwitch == 800, "I intervalo antes do secundario usa 800 no teste atual")
    ResetCase("WAITING_COMBO", 0, 0)
    AplicarCast(1, true, MockTick)
    Assert(CooldownPendenteDoSecundarioMs(1, 0) > 0, "I secundario em CD aberto e inviável para comecar agora")
    IniciarRodizio222()
    Scheduled[1].Call()
    Assert(InStr(Join(Timeline), "sleep:2700|send:{2}|sleep:800"), "I a sequencia interna nao e estendida pelo CD")
    Assert(InStr(Join(Timeline), "sleep:3000"), "I pos-combo inalterado")
    Pass("I os intervalos internos 2700/800 nunca sao estendidos")

; --- OTIMIZADOR DESLIGADO: VOLTA AOS ALVOS FIXOS ---
    ; Alvos sao sempre DURACOES contadas do inicio do estado, nos dois modos.
    ResetCase("WAITING_COMBO", 0, 0)
    Hoenn222_CdOptimizerEnabled := false
    Assert(RealBaseTarget("WAITING_COMBO", 1) == Hoenn222_ComboTargetMs[1], "J sem otimizador usa o alvo fixo de COMBAR")
    Assert(RealBaseTarget("WAITING_TEAM_SWITCH", 1) == Hoenn222_SwitchTargetMs[1], "J alvo fixo de TROCAR TIME")
    Assert(FaltaParaVerdeMs() == Hoenn222_ComboTargetMs[1], "J o pendente e o alvo menos o decorrido")
    Hoenn222_CdOptimizerEnabled := true
    Assert(RealBaseTarget("WAITING_COMBO", 1) == FaltaParaComboViavelMs(1), "J com otimizador COMBAR vem do CD real")
    Assert(RealBaseTarget("WAITING_COMBO", 1) == 0, "J sem CD, COMBAR ja esta pronto")
    janela := DuracaoDoTrocarTimeMs(1)
    ; A janela do plano comeca na troca de time; este estado comeca no cast,
    ; lure depois. O que falta da janela e P + secundario fora.
    Assert(janela == PlanoEmCache.Janelas[1] - PlanoEmCache.Lures[1], "J TROCAR TIME usa a janela planejada menos o lure")
    Assert(janela == SleepAfterTankCombo + PlanoEmCache.SecFora[1], "J ... = P + secundario fora")
    Assert(janela >= SleepAfterTankCombo + SleepAfterSwitch + SleepAfterCombo, "J a janela cobre o combo inteiro")
    Assert(RealBaseTarget("WAITING_TEAM_SWITCH", 1) == janela, "J a janela tambem e uma duracao")
    Assert(FaltaParaVerdeMs() == 0, "J pendente com todos os CD zerados")
    MockTick += 1000
    Assert(FaltaParaVerdeMs() == 0, "J CD zerado nao volta a exigir tempo so porque o relogio andou")
    ; A janela de TROCAR TIME e uma duracao desde o inicio do estado: ai o
    ; decorrido desconta de verdade.
    FaseAtual := "WAITING_TEAM_SWITCH"
    InicioDaFaseTick := MockTick - 1000
    Assert(FaltaParaVerdeMs() == janela - 1000, "J 1000ms decorridos tiram 1000ms da janela")
    Pass("J desligar o otimizador volta aos alvos fixos sem nenhuma outra mudanca")

; --- TESTE DA PREMISSA: o lure ANTES do proximo cast recupera o CD ---
    ; Um tank faz o cast, fica fora um tempo, e guardado, volta na volta
    ; seguinte e fica fora de novo durante o lure ANTES do proximo cast.
    ; Os DOIS periodos precisam contar para o mesmo cooldown. Se o
    ; planejador so considerasse o trecho pos-cast, este teste falha.
    ResetCase("WAITING_COMBO", 0, 0)
    cdTeste := 45000.0
    slotTeste := SlotDoPokemon(1, false)
    AplicarCast(1, false, MockTick)          ; 1) o cast comeca o CD
    DefinirTaxaDeRecuperacao(slotTeste, Hoenn222_RateOutOfBall, MockTick)
    MockTick += SleepAfterTankCombo              ; fora durante o P do p2
    DefinirTaxaDeRecuperacao(slotTeste, Hoenn222_RateInBall, MockTick)
    MockTick += 30000                             ; 2) guardado a 0,5x
    DefinirTaxaDeRecuperacao(slotTeste, Hoenn222_RateOutOfBall, MockTick) ; 3) volta a sair
    duracaoLure := 12871.0
    MockTick += duracaoLure                      ; lure ANTES do proximo cast
    cdRestante := CdOf(slotTeste)
    Assert(cdRestante > 0, "L ainda ha CD a recuperar: " Round(cdRestante))
    Assert(cdRestante < cdTeste, "L o lure reduziu o CD: de " cdTeste " para " Round(cdRestante))
    ganhoDoLure := duracaoLure * Hoenn222_RateOutOfBall
    Assert(ganhoDoLure > 0 && CdOf(slotTeste) < cdRestante + ganhoDoLure,
        "L o lure contribuiu " Round(ganhoDoLure) "ms")
    ; Com o plano real, F do tank = lure + P cobre 2*(CD+Lat+Marg) - L
    ; (o cache e invalido no ResetCase acima, entao recalcula)
    planoL := PlanejarVolta()
    Fplano := planoL.TankFora[1]
    exigido := 2 * (cdTeste + Hoenn222_LatencyMs + Hoenn222_MarginMs) - PlanoEmCache.L
    Assert(Fplano >= exigido, "L F do tank " Round(Fplano) " cobre o exigido " Round(exigido))
    Assert(Fplano > SleepAfterTankCombo, "L F do tank " Round(Fplano)
        " e maior que so o pos-cast " SleepAfterTankCombo)
    Pass("L o lure antes do proximo cast recupera o cooldown do cast anterior")

    ResetCase()
    IniciarRodizio222()
    Assert(Scheduled.Length == 1 && RodizioAtivo, "K combo scheduling unchanged")
    Scheduled[1].Call()
    Assert(CdOf(SlotDoPokemon(1, false)) == CooldownBaseMs(1, false), "K tank CD restarted by its own cast")
    ; A chamada do p2 leva o tank de volta para a Ball: so um Pokemon fora
    ; por vez. Sem isso a capacidade da volta viraria 4,0x em vez de 3,5x.
    Assert(CdRateOf(SlotDoPokemon(1, false)) == Hoenn222_RateInBall, "K tank volta para a Ball quando o p2 e chamado")
    Assert(CdRateOf(SlotDoPokemon(1, true)) == Hoenn222_RateOutOfBall, "K secundario assume o posto fora da Ball")
    ; Invariante: nunca dois fora da Ball ao mesmo tempo.
    fora := 0
    for i in [1, 2, 3, 4, 5, 6]
        fora += CdRateOf(i) >= 1.0 ? 1 : 0
    Assert(fora <= 1, "K no maximo um Pokemon fora da Ball: " fora)
    Assert(InStr(DebugText(), "CD_CAST"), "K cast recorded in the diagnostics")
    ; Entrada em campo (chamada do secundario): o CD que o modelo espera fica no log
    ; para ser comparado com os contadores da barra de golpes do jogo.
    Assert(RegExMatch(DebugText(), "CD_ENTRADA \| slot=2 time=1 papel=sec cd_modelo_ms=\d+ taxa="), "K entrada do secundario registrada")
    Pass("K the combo registers both casts on the right slots")
}

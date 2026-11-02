#Requires AutoHotkey v2.0
; Controle de tempo do modo Hoenn 1,5: dois times de 3 Pokemon (abre / meio / finaliza).
;
; CICLO de cada time (2 lures por time, 4 por volta):
;   troca de time .. quem ABRE sai da Ball e lura a 1a
;   PARTE 1 ........ abre: combo; chamada do MEIO; meio: skills da parte 1 (sem o stun)
;   (o meio lura a 2a)
;   PARTE 2 ........ meio: skills da parte 2 (stun por ultimo); chamada do FINALIZADOR; combo
;   troca de time .. o finalizador volta para a Ball
;
; So um Pokemon fica fora por vez, como no 2-2-2, e o modelo (taxas, blocos na Ball,
; atrasos, margem) e o mesmo de cooldown.ahk. Cada Pokemon tem um relogio de CD; o meio tem
; dois, um por parte, que entram e saem da Ball juntos:
;   relogio  = (time - 1) * 4 + 1 abre | 2 meio parte 1 | 3 meio parte 2 | 4 finaliza
;              8 + time: skill emprestada (Hoenn15_GuestSkill) que o time pega do meio do outro
;   posicao  = (time - 1) * 3 + 1 abre | 2 meio | 3 finaliza   (os seis do planejador)
;
; SKILL EMPRESTADA: na parte 1 de um time, depois do combo de quem abre, o macro chama o meio
; do outro time, usa uma skill de CD curto dele e so entao chama o proprio meio. O relogio dela
; anda com o meio dono (entra e sai da Ball com ele) e e reiniciado nos dois usos.

global Plano15EmCache := false
global ChamadaDoMeio15Tick := [0, 0]          ; ancora real da janela fora do meio
global ChamadaDoFinalizador15Tick := [0, 0]   ; e do finalizador

; --- Config -----------------------------------------------------------------------------

Relogio15(time, papel) {
    static deslocamento := Map("abre", 1, "meio1", 2, "meio2", 3, "fim", 4)
    if (papel == "convidado")
        return Integer(8 + Integer(time))
    return Integer((Integer(time) - 1) * 4 + deslocamento[papel])
}

; Relogios do Pokemon da posicao (1 abre, 2 meio, 3 finaliza) do time. O meio leva junto o
; relogio da skill que outro time pega emprestada dele.
RelogiosDaPosicao15(time, posicao) {
    if (posicao == 1)
        return [Relogio15(time, "abre")]
    if (posicao == 2) {
        relogios := [Relogio15(time, "meio1"), Relogio15(time, "meio2")]
        timeQueEmpresta := TimeQueEmprestaDe15(time)
        if timeQueEmpresta
            relogios.Push(Relogio15(timeQueEmpresta, "convidado"))
        return relogios
    }
    return [Relogio15(time, "fim")]
}

; Skill emprestada pelo time (Hoenn15_GuestSkill): {FromTeam, Key, CdMs}, ou false se nao houver.
ConvidadoDoTime15(time) {
    try {
        time := Integer(time)
        mapa := Hoenn15_GuestSkill
        if (!(mapa is Map) || !mapa.Has(time))
            return false
        c := mapa[time]
        if (IsObject(c) && c.HasOwnProp("FromTeam") && c.HasOwnProp("Key") && c.HasOwnProp("CdMs")
            && (c.FromTeam == 1 || c.FromTeam == 2) && c.FromTeam != time
            && c.Key != "" && IsNumber(c.CdMs) && c.CdMs > 0)
            return c
    }
    return false
}

; Time que pega emprestada uma skill do meio do time `dono` (0 se nenhum).
TimeQueEmprestaDe15(dono) {
    loop 2 {
        if (A_Index == Integer(dono))
            continue
        c := ConvidadoDoTime15(A_Index)
        if (c && c.FromTeam == Integer(dono))
            return A_Index
    }
    return 0
}

; Da chamada do meio dono ate a chamada do proprio meio: Pokestop, Medicine, skill e espera.
DuracaoDoConvidado15Ms(time) {
    if !ConvidadoDoTime15(time)
        return 0
    esperaMs := SleepAfterTankCombo
    try {
        if (IsNumber(Hoenn15_GuestSleepAfterMs) && Hoenn15_GuestSleepAfterMs >= 0)
            esperaMs := Hoenn15_GuestSleepAfterMs
    }
    return ForaAteCastDoMeioMs() + esperaMs
}

; Ms do envio da 1a skill da parte ate o envio da skill `tecla` (-1 se nao estiver na parte).
OffsetDaSkillNaParte15(time, parte, tecla) {
    for skill in SkillsDaParte15(time, parte) {
        if (skill.Key = tecla)
            return (A_Index - 1) * Max(0, Hoenn15_SkillGapMs)
    }
    return -1
}

; Skills de uma parte do meio, na ordem de envio. Lanca erro se o config estiver invalido.
SkillsDaParte15(time, parte) {
    mapa := (parte == 1) ? Hoenn15_MiddlePart1Skills : Hoenn15_MiddlePart2Skills
    time := Integer(time)
    if (!(mapa is Map) || !mapa.Has(time) || !(mapa[time] is Array) || mapa[time].Length == 0)
        throw Error("skills da parte " parte " do time " time " nao definidas")
    for skill in mapa[time] {
        if (!IsObject(skill) || !skill.HasOwnProp("Key") || !skill.HasOwnProp("CdMs")
            || skill.Key = "" || !IsNumber(skill.CdMs) || skill.CdMs <= 0)
            throw Error("skill " A_Index " da parte " parte " do time " time " invalida")
    }
    return mapa[time]
}

; Do envio da 1a ate o envio da ultima skill da parte (Hoenn15_SkillGapMs entre elas).
DuracaoDaParte15Ms(time, parte) {
    return (SkillsDaParte15(time, parte).Length - 1) * Max(0, Hoenn15_SkillGapMs)
}

; CD do relogio de uma parte, contado do envio da 1a skill: cada skill comeca o seu CD
; quando e enviada, entao manda a que terminar por ultimo (CD + atraso de envio).
CooldownDaParte15Ms(time, parte) {
    maior := 0
    for skill in SkillsDaParte15(time, parte)
        maior := Max(maior, skill.CdMs + (A_Index - 1) * Max(0, Hoenn15_SkillGapMs))
    return maior
}

; Espera entre a ultima skill da parte 2 e a chamada do finalizador.
PausaDepoisDaParte2Ms(time) {
    try {
        valor := Hoenn15_SleepAfterPart2Ms[Integer(time)]
        if (IsNumber(valor) && valor >= 0)
            return valor
    }
    return SleepAfterTankCombo
}

; Espera entre a ultima skill da parte 1 e a pocao.
PausaDepoisDaParte1Ms(time) {
    try {
        valor := Hoenn15_SleepAfterPart1Ms[Integer(time)]
        if (IsNumber(valor) && valor >= 0)
            return valor
    }
    return SleepAfterTankCombo
}

; Da chamada do meio ate a 1a skill da parte 1: SleepAfterSwitch + Pokestop (50 ms) + Medicine.
ForaAteCastDoMeioMs() {
    return SleepAfterSwitch + 50 + Max(0, Hoenn15_SkillGapMs)
}

; Rotulo do tier de quem abre ("abre") ou finaliza ("fim"). "?" se ausente.
RotuloDoTier15(time, papel) {
    try {
        tiers := (papel == "abre") ? Hoenn15_OpenerTier : Hoenn15_FinisherTier
        time := Integer(time)
        return (IsObject(tiers) && tiers.Has(time) && tiers[time] != "") ? tiers[time] : "?"
    } catch {
        return "?"
    }
}

; CD pelo rotulo do tier: mesma tabela e comparacao do 2-2-2. Fora da tabela, o padrao.
CooldownDoTierMs(rotulo) {
    global AvisoDeTierDesconhecidoFeito
    if IsObject(Hoenn222_CdByTier) {
        for tier, cooldownMs in Hoenn222_CdByTier {
            if (StrLower(tier) = StrLower(rotulo))
                return cooldownMs
        }
    }
    if !AvisoDeTierDesconhecidoFeito {
        AvisoDeTierDesconhecidoFeito := true
        LogDiagnostico("CD_TIER_UNKNOWN", "tier=" rotulo " padrao=" Hoenn222_CdDefaultMs " modo=1,5")
    }
    return Hoenn222_CdDefaultMs
}

CooldownDoRelogio15Ms(time, papel) {
    if (papel == "abre" || papel == "fim")
        return CooldownDoTierMs(RotuloDoTier15(time, papel))
    if (papel == "convidado") {
        c := ConvidadoDoTime15(time)
        if !c
            throw Error("time " time " nao tem skill emprestada")
        return c.CdMs
    }
    return CooldownDaParte15Ms(time, papel == "meio1" ? 1 : 2)
}

; --- Registro de eventos do jogo ---------------------------------------------------------
; Falha aqui nunca cancela a acao: o erro vai para o log e o macro segue.

RegistrarCast15(time, papel) {
    if !Hoenn222_CdOptimizerEnabled
        return
    try {
        AplicarCast15(time, papel, A_TickCount)
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=cd_cast_15 papel=" papel, e)
    }
}

; Mesmo efeito do AplicarCast do 2-2-2, no relogio do papel.
AplicarCast15(time, papel, tick) {
    global CooldownRestanteMs, TaxaDeRecuperacao, CooldownContaDesdeTick, CooldownFracaoBallMs
    relogio := Relogio15(time, papel)
    AtualizarCooldown(relogio, tick)
    restanteAntesMs := CooldownRestanteMs[relogio]
    fracaoAntesMs := CooldownFracaoBallMs[relogio]
    CooldownFracaoBallMs[relogio] := 0
    TaxaDeRecuperacao[relogio] := Hoenn222_RateOutOfBall
    CooldownRestanteMs[relogio] := CooldownDoRelogio15Ms(time, papel)
    CooldownContaDesdeTick[relogio] := tick + Hoenn222_LatencyMs
    prontoTick := tick + Hoenn222_LatencyMs + CooldownRestanteMs[relogio]
    LogDiagnostico("CD_CAST", "slot=" relogio " time=" time " papel=" papel " modo=1,5"
        " cd_main=" CooldownRestanteMs[relogio] " tick=" tick " cd_comeca=" CooldownContaDesdeTick[relogio]
        " pronto=" prontoTick " seguro=" (prontoTick + Hoenn222_MarginMs)
        " modelo_antes_ms=" Round(restanteAntesMs) " fracao_ball_antes_ms=" Round(fracaoAntesMs))
}

; So um Pokemon fora por vez: os relogios de quem e chamado saem da Ball (com `atrasoMs`) e
; todos os outros entram. Quem ja estava na Ball nao muda (a fracao do bloco continua).
ChamarRelogios15(relogiosQueSaem, tick, atrasoMs) {
    loop TotalDeRelogios {
        relogio := A_Index
        sai := false
        for r in relogiosQueSaem {
            if (r == relogio)
                sai := true
        }
        if sai
            DefinirTaxaDeRecuperacao(relogio, Hoenn222_RateOutOfBall, tick, atrasoMs)
        else
            DefinirTaxaDeRecuperacao(relogio, Hoenn222_RateInBall, tick)
    }
}

; Chamada do meio (posicao 2) ou do finalizador (posicao 3): quem estava fora volta para a
; Ball e o chamado sai, com o atraso de saida da chamada (Hoenn222_ExitLatencySecondaryMs).
RegistrarChamada15(time, posicao) {
    global ChamadaDoMeio15Tick, ChamadaDoFinalizador15Tick
    if !Hoenn222_CdOptimizerEnabled
        return
    try {
        tick := A_TickCount
        if (posicao == 2)
            ChamadaDoMeio15Tick[Integer(time)] := tick
        else
            ChamadaDoFinalizador15Tick[Integer(time)] := tick
        ChamarRelogios15(RelogiosDaPosicao15(time, posicao), tick, Hoenn222_ExitLatencySecondaryMs)
        LogarEntradaEmCampo15(time, posicao, tick)
        LogDiagnostico("CD_CHAMADA", "time=" time " posicao=" posicao " modo=1,5 tick=" tick " visual_confirmation=unknown")
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=cd_call_15", e)
    }
}

; Chamada do meio de outro time para a skill emprestada, na parte 1 do `time`.
RegistrarChamadaConvidado15(time) {
    if !Hoenn222_CdOptimizerEnabled
        return
    try {
        c := ConvidadoDoTime15(time)
        if !c
            return
        tick := A_TickCount
        ChamarRelogios15(RelogiosDaPosicao15(c.FromTeam, 2), tick, Hoenn222_ExitLatencySecondaryMs)
        LogarEntradaEmCampo15(c.FromTeam, 2, tick)
        LogDiagnostico("CD_CHAMADA", "time=" time " posicao=convidado dono=" c.FromTeam " modo=1,5 tick=" tick " visual_confirmation=unknown")
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=cd_call_guest_15", e)
    }
}

; Troca de time aceita: todos voltam para a Ball e so quem abre o proximo sai (com o atraso
; de saida da troca, Hoenn222_LatencyMs).
RegistrarTrocaDeTime15(timeAnterior, proximoTime, tick) {
    try {
        ChamarRelogios15([Relogio15(proximoTime, "abre")], tick, Hoenn222_LatencyMs)
        LogarEntradaEmCampo15(proximoTime, 1, tick)
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=cd_team_switch_15", e)
    }
}

; Diagnostico (so log): o CD que o modelo espera de cada relogio quando o Pokemon entra.
LogarEntradaEmCampo15(time, posicao, tick) {
    try {
        for relogio in RelogiosDaPosicao15(time, posicao) {
            AtualizarCooldown(relogio, tick)
            LogDiagnostico("CD_ENTRADA", "slot=" relogio " time=" time " posicao=" posicao " modo=1,5"
                " cd_modelo_ms=" Round(CooldownRestanteMs[relogio]) " taxa=" TaxaDeRecuperacao[relogio]
                " fracao_ball_ms=" Round(CooldownFracaoBallMs[relogio])
                " pronto_em_ms=" Round(MsAteCastSeguro(relogio, tick)))
        }
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=cd_entrada_15", e)
    }
}

; --- Plano da volta ----------------------------------------------------------------------

; Menor volta em que os seis recuperam o CD, pela mesma busca por blocos do 2-2-2.
; Plano: {L, Fora[6], Lures[2], Blocos[6], PreparoMs}; Fora por posicao, em ms. Em cache.
;   abre ...... fora da troca ate a chamada do meio: lure 1 (Hoenn15_MinLureMs) + preparo
;               + SleepAfterTankCombo
;   meio ...... da chamada ate a do finalizador: SleepAfterSwitch + Pokestop + parte 1
;               + PausaDepoisDaParte1Ms (pocao) + lure 2 (Hoenn15_MinLure2Ms) + parte 2
;               + PausaDepoisDaParte2Ms; exige o CD da parte mais lenta
;   finaliza .. da chamada ate a troca: SleepAfterSwitch + preparo + SleepAfterCombo
; A skill emprestada (DuracaoDoConvidado15Ms) entra no periodo de quem abre o time que a usa:
; aumenta a volta pelo tempo real, mas nao a lure. O meio dono fica fora mais um pouco e
; recupera mais do que o plano conta (lado seguro).
PlanejarVolta15() {
    global Plano15EmCache
    if Plano15EmCache
        return Plano15EmCache
    taxa := Hoenn222_RateOutOfBall
    preparo := PreparoPlanejadoMs()
    atrasoAbre := 2 * Hoenn222_LatencyMs                                   ; cast + saida na troca
    atrasoChamado := Hoenn222_LatencyMs + Hoenn222_ExitLatencySecondaryMs  ; cast + saida na chamada
    requisitos := [], pisos := []
    loop 2 {
        time := A_Index
        lureMs := PisoDoConfigMs("Hoenn15_MinLureMs", time)
        lure2Ms := PisoDoConfigMs("Hoenn15_MinLure2Ms", time)
        cdMeio := Max(CooldownDaParte15Ms(time, 1), CooldownDaParte15Ms(time, 2))
        requisitos.Push(CooldownDoRelogio15Ms(time, "abre") + atrasoAbre * taxa + Hoenn222_MarginMs)
        requisitos.Push(cdMeio + atrasoChamado * taxa + Hoenn222_MarginMs)
        requisitos.Push(CooldownDoRelogio15Ms(time, "fim") + atrasoChamado * taxa + Hoenn222_MarginMs)
        pisos.Push(lureMs + preparo + SleepAfterTankCombo + DuracaoDoConvidado15Ms(time))
        pisos.Push(ForaAteCastDoMeioMs() + DuracaoDaParte15Ms(time, 1) + PausaDepoisDaParte1Ms(time) + lure2Ms + DuracaoDaParte15Ms(time, 2) + PausaDepoisDaParte2Ms(time))
        pisos.Push(SleepAfterSwitch + preparo + SleepAfterCombo)
    }
    resolvido := ResolverVoltaEmBlocos(requisitos, pisos)
    fora := resolvido.Fora
    lures := [fora[1] - SleepAfterTankCombo - preparo - DuracaoDoConvidado15Ms(1), fora[4] - SleepAfterTankCombo - preparo - DuracaoDoConvidado15Ms(2)]
    Plano15EmCache := {L: resolvido.Volta, Fora: fora, Lures: lures, Blocos: resolvido.Blocos, PreparoMs: preparo}
    LogDiagnostico("CD_PLAN", "modo=1,5 L=" resolvido.Volta
        " fora=" Round(fora[1]) "," Round(fora[2]) "," Round(fora[3]) "," Round(fora[4]) "," Round(fora[5]) "," Round(fora[6])
        " lure=" Round(lures[1]) "," Round(lures[2]) " preparo_ms=" preparo
        " reserva_fora_ms=" resolvido.ReservaFora " reserva_ball_ms=" resolvido.ReservaBall " visual_confirmation=unknown")
    return Plano15EmCache
}

; --- Cronometro ----------------------------------------------------------------------------

; Duracao da fase contada desde InicioDaFaseTick (mesmo contrato de AlvoDaFaseMs):
;   WAITING_COMBO (PARTE 1) .... comeca na troca de time
;   WAITING_PART2 (PARTE 2) .... comeca no inicio da parte 1
;   WAITING_TEAM_SWITCH ........ comeca no inicio da parte 2
; Otimizador desligado ou falha de calculo: 0 (verde). O pedido executa, e a troca nunca
; fica presa por erro de calculo.
AlvoDaFase15Ms(fase, time) {
    if !Hoenn222_CdOptimizerEnabled
        return 0
    try {
        decorridoMs := A_TickCount - InicioDaFaseTick
        if (fase == "WAITING_COMBO")
            return decorridoMs + FaltaParaParte1Ms(time)
        if (fase == "WAITING_PART2")
            return Max(RitmoDaParte2Ms(time), decorridoMs + FaltaParaParte2PorCdMs(time))
        if (fase == "WAITING_TEAM_SWITCH")
            return DuracaoDoTrocarTime15Ms(time)
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=cd_target_15 state=" fase, e)
    }
    return 0
}

; PARTE 1: ms a partir de agora ate quem abre poder castar, o lure do plano ter passado e a
; parte 1 do meio estar pronta no cast dele (chamada TempoAteChamadaPrevistoMs depois).
FaltaParaParte1Ms(time) {
    time := Integer(time)
    tick := A_TickCount
    abreMs := MsAteCastSeguro(Relogio15(time, "abre"), tick)
    lureMs := PlanejarVolta15().Lures[time] - (tick - InicioDaFaseTick)
    convidadoMs := DuracaoDoConvidado15Ms(time)
    ; Com skill emprestada, o proprio meio so e chamado depois dela.
    meioMs := FaltaParaChamadoMs(Relogio15(time, "meio1"), TempoAteChamadaPrevistoMs() + convidadoMs, ForaAteCastDoMeioMs())
    return Max(0, abreMs, lureMs, meioMs, FaltaParaSkillEmprestadaNaParte1Ms(time))
}

; A skill emprestada precisa estar pronta nos dois usos: na parte 1 do time que a pega (o meio
; dono e chamado logo depois do combo) e na parte do meio dono que tambem a usa.
FaltaParaSkillEmprestadaNaParte1Ms(time) {
    faltaMs := 0
    if ConvidadoDoTime15(time)
        faltaMs := FaltaParaChamadoMs(Relogio15(time, "convidado"), TempoAteChamadaPrevistoMs(), ForaAteCastDoMeioMs())
    timeQueEmpresta := TimeQueEmprestaDe15(time)
    if timeQueEmpresta {
        deslocamentoMs := OffsetDaSkillNaParte15(time, 1, ConvidadoDoTime15(timeQueEmpresta).Key)
        if (deslocamentoMs >= 0)
            faltaMs := Max(faltaMs, FaltaParaChamadoMs(Relogio15(timeQueEmpresta, "convidado"),
                TempoAteChamadaPrevistoMs() + DuracaoDoConvidado15Ms(time), ForaAteCastDoMeioMs() + deslocamentoMs))
    }
    return faltaMs
}

; PARTE 2 pelo CD: a parte 2 do meio (fora da Ball) e o finalizador no cast dele.
FaltaParaParte2PorCdMs(time) {
    tick := A_TickCount
    meioMs := MsAteCastSeguro(Relogio15(time, "meio2"), tick)
    ateChamadaMs := DuracaoDaParte15Ms(time, 2) + PausaDepoisDaParte2Ms(time)
    fimMs := FaltaParaChamadoMs(Relogio15(time, "fim"), ateChamadaMs, SleepAfterSwitch)
    ; A skill que outro time pega emprestada, se o meio a usar tambem na parte 2.
    emprestadaMs := 0
    timeQueEmpresta := TimeQueEmprestaDe15(time)
    if timeQueEmpresta {
        deslocamentoMs := OffsetDaSkillNaParte15(time, 2, ConvidadoDoTime15(timeQueEmpresta).Key)
        if (deslocamentoMs >= 0)
            emprestadaMs := MsAteCastSeguro(Relogio15(timeQueEmpresta, "convidado"), tick) - deslocamentoMs
    }
    return Max(0, meioMs, fimMs, emprestadaMs)
}

; PARTE 2 pelo ritmo do plano (desde o inicio da parte 1): o meio fica fora o periodo
; planejado, contado da chamada real dele, e a chamada do finalizador fecha esse periodo.
RitmoDaParte2Ms(time) {
    time := Integer(time)
    plano := PlanejarVolta15()
    chamada := ChamadaDoMeio15Tick[time]
    ateChamadaMs := (chamada > 0 && chamada >= InicioDaFaseTick)
        ? chamada - InicioDaFaseTick : SleepAfterTankCombo + plano.PreparoMs + DuracaoDoConvidado15Ms(time)
    return ateChamadaMs + plano.Fora[(time - 1) * 3 + 2] - DuracaoDaParte15Ms(time, 2) - PausaDepoisDaParte2Ms(time)
}

; TROCAR TIME (desde o inicio da parte 2): o finalizador fica fora o periodo planejado,
; contado da chamada real dele.
DuracaoDoTrocarTime15Ms(time) {
    time := Integer(time)
    plano := PlanejarVolta15()
    chamada := ChamadaDoFinalizador15Tick[time]
    ateChamadaMs := (chamada > 0 && chamada >= InicioDaFaseTick)
        ? chamada - InicioDaFaseTick : DuracaoDaParte15Ms(time, 2) + PausaDepoisDaParte2Ms(time)
    return ateChamadaMs + plano.Fora[(time - 1) * 3 + 3]
}

; Ms a partir de agora ate poder comecar uma acao que chama o Pokemon do `relogio` (hoje na
; Ball) `ateChamadaMs` depois e o faz castar `foraAteCastMs` apos a chamada. Generaliza a
; previsao do secundario do 2-2-2 (FaltaParaSecundarioEmBlocosMs) para qualquer relogio.
FaltaParaChamadoMs(relogio, ateChamadaMs, foraAteCastMs) {
    tick := A_TickCount
    restanteMs := LerCooldownRestanteMs(relogio, tick)
    if (restanteMs <= 0)
        return Max(0, MsAteCastSeguro(relogio, tick) - ateChamadaMs - foraAteCastMs)
    foraMs := Max(0, foraAteCastMs - Hoenn222_ExitLatencySecondaryMs)
    necessarioMs := restanteMs - foraMs * Hoenn222_RateOutOfBall + Hoenn222_MarginMs
    if (necessarioMs <= 0)
        return 0
    congeladoMs := Max(0, CooldownContaDesdeTick[relogio] - tick)
    if UsarBlocosNaBall(relogio) {
        ateBlocosMs := Ceil(necessarioMs / CreditoDoBlocoBallMs()) * Hoenn222_InBallBlockMs - CooldownFracaoBallMs[relogio]
        return Max(0, congeladoMs + ateBlocosMs - ateChamadaMs)
    }
    taxa := TaxaDeRecuperacao[relogio] > 0 ? TaxaDeRecuperacao[relogio] : 1
    return Max(0, congeladoMs + necessarioMs / taxa - ateChamadaMs)
}

; Quem segura o verde da fase (diagnostico e painel): "abre", "meio", "fim", "ritmo" ou "".
QuemBloqueia15(fase, time) {
    tick := A_TickCount
    if (fase == "WAITING_COMBO") {
        if (MsAteCastSeguro(Relogio15(time, "abre"), tick) > 0)
            return "abre"
        if (FaltaParaChamadoMs(Relogio15(time, "meio1"), TempoAteChamadaPrevistoMs() + DuracaoDoConvidado15Ms(time), ForaAteCastDoMeioMs()) > 0
            || FaltaParaSkillEmprestadaNaParte1Ms(time) > 0)
            return "meio"
        return (FaltaParaParte1Ms(time) > 0) ? "ritmo" : ""
    }
    if (fase == "WAITING_PART2") {
        if (MsAteCastSeguro(Relogio15(time, "meio2"), tick) > 0)
            return "meio"
        if (FaltaParaParte2PorCdMs(time) > 0)
            return "fim"
        return (RitmoDaParte2Ms(time) > tick - InicioDaFaseTick) ? "ritmo" : ""
    }
    return ""
}

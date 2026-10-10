#Requires AutoHotkey v2.0
; Planejador das tres duplas: acha a menor volta sustentavel e a janela de cada dupla.
;
; MODELO. So um Pokemon fica fora da Ball por vez. Na janela da dupla k:
;   troca de time ... o tank k SAI da Ball (o secundario continua dentro)
;   lure ............ o tank espera/puxa fora da Ball; recupera o CD do cast da volta anterior
;   cast do tank .... T0; o CD novo comeca a contar apos o atraso de cast
;   chamada ......... T0 + SleepAfterTankCombo: o tank VOLTA para a Ball, o secundario SAI
;   cast do sec ..... chamada + SleepAfterSwitch
;   proxima troca ... o secundario volta para a Ball
;
; A recuperacao e contada ENTRE DOIS CASTS do mesmo Pokemon. Com F = tempo fora da Ball
; nesse intervalo e L = volta inteira, fora recupera 1,0 e dentro 0,5:
;
;     (F - atrasos) + (L - F) * 0,5  >=  CD + margem
;     F  >=  2 * (CD + atrasos + margem) - L
;
; `atrasos` soma o atraso do cast e o da saida da Ball (tank: Hoenn222_LatencyMs; secundario:
; Hoenn222_ExitLatencySecondaryMs). Cada janela e lure + SleepAfterTankCombo + F_secundario e as
; tres somam L; a menor volta que fecha essa soma e achada por bisseccao.
; O resultado so depende da configuracao, entao fica em cache.
; No experimento por blocos, este plano continuo e um piso nominal de distribuicao das
; janelas. O verde consulta os blocos reais acumulados; a volta observada pode ser maior.

; Rotulo do tier ("SR", "UR"...) do tank ou do secundario ("second") do time. "?" se ausente.
RotuloDoTier(time, papel := "tank") {
    global Hoenn222_TankTier, Hoenn222_SecondTier
    time := Integer(time)
    try {
        tiers := (papel == "second") ? Hoenn222_SecondTier : Hoenn222_TankTier
        return (IsObject(tiers) && tiers.Has(time) && tiers[time] != "") ? tiers[time] : "?"
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=tier_config role=" papel " team=" time, e)
        return "?"
    }
}

; Plano: {L, Janelas[], Lures[], TankFora[], SecFora[], FolgaLure, JanelaMinima, MargemEfetiva},
; tudo em ms e indexado por time (1 a 3).
PlanejarVolta() {
    global PlanoEmCache, Hoenn222_LatencyMs, Hoenn222_MarginMs, Hoenn222_ExitLatencySecondaryMs

    if PlanoEmCache
        return PlanoEmCache

    if UsarPlanejadorDiscreto()
        return PlanejarVoltaEmBlocos()

    atrasoMs := Hoenn222_LatencyMs
    margemMs := Hoenn222_MarginMs
    margemTankMs := 2 * atrasoMs + margemMs                                         ; cast + saida do tank
    margemSecMs := atrasoMs + Hoenn222_ExitLatencySecondaryMs + margemMs            ; cast + saida do secundario
    castAteChamadaMs := SleepAfterTankCombo
    secForaMinimoMs := SleepAfterSwitch + SleepAfterCombo                           ; fica fora ate a troca

    cdTank := [CooldownBaseMs(1, false), CooldownBaseMs(2, false), CooldownBaseMs(3, false)]
    cdSec := [CooldownBaseMs(1, true), CooldownBaseMs(2, true), CooldownBaseMs(3, true)]

    ; Pisos de conforto do config: o que o jogador precisa alem do cooldown.
    pisoTank := []
    pisoSec := []
    loop 3 {
        pisoTank.Push(castAteChamadaMs + PisoDoConfigMs("Hoenn222_MinLureMs", A_Index))
        pisoSec.Push(Max(secForaMinimoMs, PisoDoConfigMs("Hoenn222_MinSecondaryOutMs", A_Index)))
    }

    ; A soma das janelas diminui quando L cresce (CD maior exige menos tempo fora), entao
    ; "soma <= L" vale a partir de um unico ponto: bisseccao.
    janelaMinimaMs := castAteChamadaMs + secForaMinimoMs
    somaPisos := pisoTank[1] + pisoTank[2] + pisoTank[3] + pisoSec[1] + pisoSec[2] + pisoSec[3]
    inferior := Max(janelaMinimaMs * 3, somaPisos)
    superior := 500000.0
    while (superior - inferior > 0.01) {
        meio := (inferior + superior) / 2
        soma := 0.0
        loop 3 {
            soma += Max(pisoTank[A_Index], 2 * (cdTank[A_Index] + margemTankMs) - meio)
            soma += Max(pisoSec[A_Index], 2 * (cdSec[A_Index] + margemSecMs) - meio)
        }
        if (soma <= meio)
            superior := meio
        else
            inferior := meio
    }
    voltaMs := superior

    janelas := [0.0, 0.0, 0.0]
    lures := [0.0, 0.0, 0.0]
    tankFora := [0.0, 0.0, 0.0]
    secFora := [0.0, 0.0, 0.0]
    folgaLure := 0.0
    loop 3 {
        tankFora[A_Index] := Max(pisoTank[A_Index], 2 * (cdTank[A_Index] + margemTankMs) - voltaMs)
        secFora[A_Index] := Max(pisoSec[A_Index], 2 * (cdSec[A_Index] + margemSecMs) - voltaMs)
        lures[A_Index] := tankFora[A_Index] - castAteChamadaMs
        janelas[A_Index] := lures[A_Index] + castAteChamadaMs + secFora[A_Index]
        folgaLure += lures[A_Index]
    }

    ; Literal de objeto em UMA linha: este build do AutoHotkey nao aceita multilinha.
    PlanoEmCache := {L: voltaMs, Janelas: janelas, Lures: lures, TankFora: tankFora, SecFora: secFora, FolgaLure: folgaLure, JanelaMinima: janelaMinimaMs, MargemEfetiva: margemTankMs}
    LogDiagnostico("CD_PLAN", "L=" Round(voltaMs)
        " janelas=" Round(janelas[1]) "," Round(janelas[2]) "," Round(janelas[3])
        " lure=" Round(lures[1]) "," Round(lures[2]) "," Round(lures[3])
        " tank_fora=" Round(tankFora[1]) "," Round(tankFora[2]) "," Round(tankFora[3])
        " sec_fora=" Round(secFora[1]) "," Round(secFora[2]) "," Round(secFora[3])
        " pos_cast=" castAteChamadaMs " gap=" SleepAfterSwitch " pos=" SleepAfterCombo
        " latencia=" atrasoMs " saida_sec=" Hoenn222_ExitLatencySecondaryMs " margem=" margemMs
        " modelo_ball=" (Hoenn222_InBallWholeBlocks ? "blocos_" Format("{:g}", Hoenn222_InBallBlockMs / 1000) "s" : "continuo")
        " bloco_ball_ms=" Hoenn222_InBallBlockMs " credito_ball_ms=" Round(CreditoDoBlocoBallMs())
        " plano_piso_continuo=" (Hoenn222_InBallWholeBlocks ? 1 : 0))
    return PlanoEmCache
}

; A selecao afeta tambem o cronometro; desligar restaura a politica anterior inteira.
UsarPlanejadorDiscreto() {
    return Hoenn222_UseDiscretePlanner && Hoenn222_InBallWholeBlocks
}

PreparoPlanejadoMs() {
    return Max(150, Hoenn222_ComboPreparationMs)
}

; Para o verde, so projetar o preparo fisico garantido (tres Sleep(50)). O envio
; pode demorar mais, mas nao e seguro depender desse tempo futuro para completar um bloco.
TempoAteChamadaPrevistoMs() {
    return SleepAfterTankCombo + (UsarPlanejadorDiscreto() ? 150 : 0)
}

; Resolve F*r + n*credito >= CD + atrasos*r + margem + reserva_fora
; e F + n*bloco + reserva_ball <= L. A soma dos seis F e L.
; O cache evita qualquer busca no GameLoop depois da primeira consulta.
PlanejarVoltaEmBlocos() {
    global PlanoEmCache
    bloco := Hoenn222_InBallBlockMs
    credito := CreditoDoBlocoBallMs()
    taxa := Hoenn222_RateOutOfBall
    if (bloco <= 0 || credito <= 0 || taxa <= Hoenn222_RateInBall)
        throw Error("Parametros invalidos para o planejador discreto")
    preparo := PreparoPlanejadoMs()
    requisitos := [], pisos := []
    somaPisos := 0
    loop 3 {
        time := A_Index
        for secundario in [false, true] {
            atrasos := Hoenn222_LatencyMs + (secundario ? Hoenn222_ExitLatencySecondaryMs : Hoenn222_LatencyMs)
            requisitos.Push(CooldownBaseMs(time, secundario) + atrasos * taxa + Hoenn222_MarginMs)
            piso := secundario
                ? Max(SleepAfterSwitch + preparo + SleepAfterCombo, PisoDoConfigMs("Hoenn222_MinSecondaryOutMs", time))
                : SleepAfterTankCombo + preparo + PisoDoConfigMs("Hoenn222_MinLureMs", time)
            pisos.Push(piso)
            somaPisos += piso
        }
    }
    reservaFora := Max(0, Hoenn222_PlannerOutReserveMs)
    reservaBall := Max(0, Hoenn222_PlannerBallReserveMs)
    inferior := somaPisos
    superior := Max(somaPisos, 1000)
    while !EncontrarDistribuicaoEmBlocos(superior, requisitos, pisos, reservaFora, reservaBall) {
        superior *= 2
        if (superior > 1000000)
            throw Error("Nao foi possivel distribuir as janelas de cooldown")
    }
    while (superior - inferior > 0.001) {
        meio := (superior + inferior) / 2
        if EncontrarDistribuicaoEmBlocos(meio, requisitos, pisos, reservaFora, reservaBall)
            superior := meio
        else
            inferior := meio
    }
    volta := Ceil(superior - 0.001)
    escolhas := EncontrarDistribuicaoEmBlocos(volta, requisitos, pisos, reservaFora, reservaBall)
    if !escolhas {
        volta++
        escolhas := EncontrarDistribuicaoEmBlocos(volta, requisitos, pisos, reservaFora, reservaBall)
    }
    ; Distribuir o excedente maximizando a menor folga, respeitando a capacidade
    ; de cada intervalo. Nao ha restricao de igualdade entre tanks ou lures.
    folgaMin := 0, folgaMax := volta * taxa
    loop 40 {
        folga := (folgaMin + folgaMax) / 2
        soma := 0
        for slot, escolha in escolhas
            soma += Min(escolha.Max, escolha.Min + folga / taxa)
        if (soma <= volta)
            folgaMin := folga
        else
            folgaMax := folga
    }
    fora := [], soma := 0
    for escolha in escolhas {
        valor := Min(escolha.Max, escolha.Min + folgaMin / taxa)
        fora.Push(valor)
        soma += valor
    }
    ; Fechar apenas o erro numerico; nao e uma espera adicional no fim da volta.
    for slot, escolha in escolhas {
        acrescimo := Min(Max(0, volta - soma), Max(0, escolha.Max - fora[slot]))
        fora[slot] += acrescimo
        soma += acrescimo
    }
    janelas := [], lures := [], tanks := [], secundarios := [], blocos := []
    somaLure := 0
    loop 3 {
        slot := 2 * A_Index - 1
        tanks.Push(fora[slot]), secundarios.Push(fora[slot + 1])
        lure := fora[slot] - SleepAfterTankCombo - preparo
        lures.Push(lure), janelas.Push(fora[slot] + fora[slot + 1])
        somaLure += lure
    }
    for escolha in escolhas
        blocos.Push(escolha.N)
    PlanoEmCache := {L: volta, Janelas: janelas, Lures: lures, TankFora: tanks, SecFora: secundarios, FolgaLure: somaLure, JanelaMinima: SleepAfterTankCombo + 2 * preparo + SleepAfterSwitch + SleepAfterCombo, MargemEfetiva: 2 * Hoenn222_LatencyMs + Hoenn222_MarginMs, Discreto: true, PreparoMs: preparo, Blocos: blocos}
    LogDiagnostico("CD_PLAN", "L=" volta " janelas=" Round(janelas[1]) "," Round(janelas[2]) "," Round(janelas[3]) " lure=" Round(lures[1]) "," Round(lures[2]) "," Round(lures[3]) " tank_fora=" Round(tanks[1]) "," Round(tanks[2]) "," Round(tanks[3]) " sec_fora=" Round(secundarios[1]) "," Round(secundarios[2]) "," Round(secundarios[3]) " modelo_ball=blocos_" Format("{:g}", bloco / 1000) "s bloco_ball_ms=" bloco " credito_ball_ms=" Round(credito) " plano_piso_continuo=0 preparo_ms=" preparo " reserva_fora_ms=" reservaFora " reserva_ball_ms=" reservaBall " visual_confirmation=unknown")
    return PlanoEmCache
}

EncontrarDistribuicaoEmBlocos(volta, requisitos, pisos, reservaFora, reservaBall) {
    opcoes := [], minRestante := [0, 0, 0, 0, 0, 0, 0], maxRestante := [0, 0, 0, 0, 0, 0, 0]
    bloco := Hoenn222_InBallBlockMs, credito := CreditoDoBlocoBallMs()
    loop 6 {
        slot := A_Index
        lista := []
        maxBlocos := Floor((volta - pisos[slot] - reservaBall) / bloco)
        if (maxBlocos < 0)
            return false
        loop maxBlocos + 1 {
            n := maxBlocos - A_Index + 1
            minimo := Max(pisos[slot], (requisitos[slot] + reservaFora - n * credito) / Hoenn222_RateOutOfBall)
            maximo := volta - n * bloco - reservaBall
            if (minimo <= maximo + 0.000001)
                lista.Push({N: n, Min: minimo, Max: Max(minimo, maximo)})
        }
        if !lista.Length
            return false
        opcoes.Push(lista)
    }
    loop 6 {
        slot := 7 - A_Index
        minimo := volta, maximo := 0
        for opcao in opcoes[slot] {
            minimo := Min(minimo, opcao.Min)
            maximo := Max(maximo, opcao.Max)
        }
        minRestante[slot] := minRestante[slot + 1] + minimo
        maxRestante[slot] := maxRestante[slot + 1] + maximo
    }
    return ProcurarJanelasEmBlocos(1, 0, 0, [], opcoes, minRestante, maxRestante, volta)
}

ProcurarJanelasEmBlocos(slot, somaMin, somaMax, escolhidas, opcoes, minRestante, maxRestante, volta) {
    if (somaMin + minRestante[slot] > volta + 0.000001 || somaMax + maxRestante[slot] < volta - 0.000001)
        return false
    if (slot == 7)
        return escolhidas.Clone()
    for opcao in opcoes[slot] {
        escolhidas.Push(opcao)
        resultado := ProcurarJanelasEmBlocos(slot + 1, somaMin + opcao.Min, somaMax + opcao.Max, escolhidas, opcoes, minRestante, maxRestante, volta)
        escolhidas.Pop()
        if resultado
            return resultado
    }
    return false
}

; Piso de conforto por dupla lido do config (Map nome -> time). Ausente, negativo ou
; invalido vale 0 e nunca derruba o planejador.
PisoDoConfigMs(nomeMapa, time) {
    try {
        mapa := %nomeMapa%
        valor := (IsObject(mapa) && mapa.Has(time)) ? mapa[time] : 0
        return (IsNumber(valor) && valor > 0) ? valor : 0
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=min_config map=" nomeMapa, e)
        return 0
    }
}

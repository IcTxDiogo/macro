#Requires AutoHotkey v2.0
; Planejador global das tres duplas: menor volta sustentavel e janelas por dupla.

GetHoenn222TierText(timeIndex, role := "tank") {
    global Hoenn222_TankTier, Hoenn222_SecondTier
    timeIndex := Integer(timeIndex)
    try {
        mapaTier := (role == "second") ? Hoenn222_SecondTier : Hoenn222_TankTier
        return (IsObject(mapaTier) && mapaTier.Has(timeIndex) && mapaTier[timeIndex] != "")
            ? mapaTier[timeIndex] : "?"
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=tier_config role=" role " team=" timeIndex, e)
        return "?"
    }
}

; =============================================================================
; PLANEJADOR GLOBAL DAS TRES DUPLAS
; =============================================================================
; Depende so da configuracao, entao o resultado e estavel e fica em cache.
;
; -----------------------------------------------------------------------------
; MODELO
; -----------------------------------------------------------------------------
; Só um Pokémon fica fora da Ball por vez. Dentro da janela da dupla k:
;
;   s_k ........... troca de time; o tank k SAI da Ball, o secundário continua
;                   dentro. A partir daqui é o tank que recupera, e o CD que
;                   ele recupera é o que começou no cast da volta ANTERIOR.
;   T0_k .......... cast do tank; o CD novo passa a contar em T0_k + Λ
;   T1_k = T0_k + P chamada do p2; o tank VOLTA para a Ball, o secundário SAI
;   T2_k = T1_k + G cast do secundário; CD conta a partir de T2_k + Λ
;   s_(k+1) ....... próxima troca; o secundário volta para a Ball
;
; Capacidade conjunta da volta: 1 a 1,0 + 5 a 0,5 = 3,5. Nunca mais que isso.
;
; -----------------------------------------------------------------------------
; PRINCÍPIO: a recuperação é contada ENTRE DOIS CASTS CONSECUTIVOS
; -----------------------------------------------------------------------------
; O cooldown do Pokémon na volta k nasce em T0_k e precisa zerar antes do
; próximo T0. Nesse intervalo inteiro ele recupera, e cada segundo conta onde
; quer que aconteça:
;
;   * logo depois do cast, ainda fora da Ball (1,0×)
;   * guardado no meio da volta, dentro da Ball (0,5×)
;   * na volta seguinte, de novo fora, durante o lure ANTES do próximo cast
;
; O lure não é tempo perdido: ele recupera o cooldown que começou no cast
; anterior. F = tempo total fora da Ball entre dois casts consecutivos.
;
;     recuperação = (F - Λ)·1,0 + (L - F)·0,5
;     (F - Λ) porque o congelamento de Λ fica DENTRO do primeiro trecho fora
;
;     (F - Λ) + (L - F)·0,5  >=  CD + Δ
;     F  >=  2·(CD + Λ + Δ) − L
;
; Λ e Δ entram uma vez cada. Λ porque o CD não corre durante o congelamento;
; Δ como a folga exigida no próximo cast.
;
; -----------------------------------------------------------------------------
; QUEM PODE FICAR FORA, E QUANTO
; -----------------------------------------------------------------------------
; O tank só existe fora da Ball dentro da SUA janela, da troca até a chamada
; do p2. Esse tempo é lure_k + P. Fora da janela ele está guardado, a 0,5.
;     F_tank_k = lure_k + P        e lure_k >= 0
;
; O secundário fica fora de T1_k até a próxima troca, e precisa comportar
; Gap + SleepAfterCombo:
;     F_sec_k = janela_k − lure_k − P   e janela_k − lure_k − P >= Gap + Post
;
; -----------------------------------------------------------------------------
; COMO AS TRÊS PARCELAS FECHAM
; -----------------------------------------------------------------------------
;     janela_k = lure_k + P + F_sec_k
;     L = janela_1 + janela_2 + janela_3
;
; Cada janela é o que o tank e o secundário daquele par exigem, então as três
; janelas têm tamanhos diferentes. O menor L que fecha essa soma é a volta
; mínima sustentável — e ele coincide com o piso 3,5× quando a estrutura couber.
;
PlanHoenn222() {
    global Hoenn222_PlanCache, Hoenn222_LatencyMs, Hoenn222_MarginMs

    if Hoenn222_PlanCache
        return Hoenn222_PlanCache

    lat := Hoenn222_LatencyMs
    marg := Hoenn222_MarginMs
    ; Cada Pokemon perde a latencia duas vezes por intervalo entre casts: na saida
    ; da Ball (troca de time para o tank, chamada do p2 para o secundario) e no
    ; inicio do CD novo (o cast).
    margemEfetiva := 2 * lat + marg
    margemSec := margemEfetiva
    Pp := SleepAfterTankCombo
    minSec := SleepAfterSwitch + SleepAfterCombo   ; secundário precisa ficar fora até a troca

    cdTank := [GetHoenn222CdMainMs(1, false), GetHoenn222CdMainMs(2, false), GetHoenn222CdMainMs(3, false)]
    cdSec := [GetHoenn222CdMainMs(1, true), GetHoenn222CdMainMs(2, true), GetHoenn222CdMainMs(3, true)]
    ; Pisos de conforto do config: o que o jogador precisa alem do cooldown.
    ; O tank fica fora ao menos P + lure minimo; o secundario ao menos o piso dele.
    pisoTank := [Pp + Hoenn222MinFromConfig("Hoenn222_MinLureMs", 1), Pp + Hoenn222MinFromConfig("Hoenn222_MinLureMs", 2), Pp + Hoenn222MinFromConfig("Hoenn222_MinLureMs", 3)]
    pisoSec := [Max(minSec, Hoenn222MinFromConfig("Hoenn222_MinSecondaryOutMs", 1)), Max(minSec, Hoenn222MinFromConfig("Hoenn222_MinSecondaryOutMs", 2)), Max(minSec, Hoenn222MinFromConfig("Hoenn222_MinSecondaryOutMs", 3))]

    ; Soma das janelas em função de L. Diminui quando L cresce (CD maior exige
    ; menos tempo fora), então a condição "soma <= L" vale a partir de um
    ; único ponto. Bisseção acha o menor L que fecha.
    minJanelas := Pp + minSec
    lo := minJanelas * 3
    ; Com pisos o menor L possivel nunca fica abaixo da soma deles.
    somaPisos := pisoTank[1] + pisoTank[2] + pisoTank[3] + pisoSec[1] + pisoSec[2] + pisoSec[3]
    lo := Max(lo, somaPisos)
    hi := 500000.0
    while (hi - lo > 0.01) {
        meio := (lo + hi) / 2
        total := 0.0
        timeIndex := 1
        while timeIndex <= 3 {
            total += Max(pisoTank[timeIndex], 2 * (cdTank[timeIndex] + margemEfetiva) - meio)
            total += Max(pisoSec[timeIndex], 2 * (cdSec[timeIndex] + margemSec) - meio)
            timeIndex += 1
        }
        if (total <= meio)
            hi := meio
        else
            lo := meio
    }
    L := hi

    ; Janelas e lure finais nesse L.
    janelas := [0.0, 0.0, 0.0]
    lures := [0.0, 0.0, 0.0]
    tankFora := [0.0, 0.0, 0.0]
    secFora := [0.0, 0.0, 0.0]
    folgaLure := 0.0
    timeIndex := 1
    while timeIndex <= 3 {
        tankFora[timeIndex] := Max(pisoTank[timeIndex], 2 * (cdTank[timeIndex] + margemEfetiva) - L)
        secFora[timeIndex] := Max(pisoSec[timeIndex], 2 * (cdSec[timeIndex] + margemSec) - L)
        lures[timeIndex] := tankFora[timeIndex] - Pp
        janelas[timeIndex] := lures[timeIndex] + Pp + secFora[timeIndex]
        folgaLure += lures[timeIndex]
        timeIndex += 1
    }

    ; Object literal em UMA linha: este build do AutoHotkey nao aceita
    ; literais multi-linha.
    Hoenn222_PlanCache := {L: L, Janelas: janelas, Lures: lures, TankFora: tankFora, SecFora: secFora, FolgaLure: folgaLure, JanelaMinima: minJanelas, MargemEfetiva: margemEfetiva}
    SwitchDebug("CD_PLAN", "L=" Round(L)
        " janelas=" Round(janelas[1]) "," Round(janelas[2]) "," Round(janelas[3])
        " lure=" Round(lures[1]) "," Round(lures[2]) "," Round(lures[3])
        " tank_fora=" Round(tankFora[1]) "," Round(tankFora[2]) "," Round(tankFora[3])
        " sec_fora=" Round(secFora[1]) "," Round(secFora[2]) "," Round(secFora[3])
        " pos_cast=" Pp " gap=" SleepAfterSwitch " pos=" SleepAfterCombo
        " latencia=" lat " margem=" marg)
    return Hoenn222_PlanCache
}

; Piso de conforto por dupla lido do config (Map nome -> time). Ausente, negativo ou
; invalido vale 0 e nunca derruba o planejador.
Hoenn222MinFromConfig(nomeMapa, timeIndex) {
    try {
        mapa := %nomeMapa%
        valor := (IsObject(mapa) && mapa.Has(timeIndex)) ? mapa[timeIndex] : 0
        return (IsNumber(valor) && valor > 0) ? valor : 0
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=min_config map=" nomeMapa, e)
        return 0
    }
}

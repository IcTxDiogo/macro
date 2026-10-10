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
        " latencia=" atrasoMs " saida_sec=" Hoenn222_ExitLatencySecondaryMs " margem=" margemMs)
    return PlanoEmCache
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

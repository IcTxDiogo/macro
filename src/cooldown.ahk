#Requires AutoHotkey v2.0
; Cooldown individual dos 6 Pokemon: acumulador preguicoso, taxas dentro/fora da Ball, latencia, margem.

; Registro de eventos do CD, isolado: qualquer falha aqui não cancela o combo.
Hoenn222CdRegistrarCast(timeIndex, secundario := false) {
    global Hoenn222_CdOptimizerEnabled
    if !Hoenn222_CdOptimizerEnabled
        return
    try {
        Hoenn222CdCast(timeIndex, secundario, A_TickCount)
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=cd_cast", e)
    }
}

Hoenn222CdRegistrarChamada(timeIndex) {
    global Hoenn222_CdOptimizerEnabled, Hoenn222_RateOutOfBall, Hoenn222_RateInBall
    global Hoenn222_LatencyMs
    if !Hoenn222_CdOptimizerEnabled
        return
    try {
        tick := A_TickCount
        ; APENAS UM POKEMON POR VEZ FORA DA BALL. Ao chamar o p2 o tank sai
        ; de campo: se ele continuasse a 1,0x os dois recuperariam juntos e a
        ; capacidade da volta passaria de 3,5x para 4,0x, inflando o plano.
        Hoenn222CdSetRate(Hoenn222Slot(timeIndex, false), Hoenn222_RateInBall, tick)
        Hoenn222CdLogEntrada(timeIndex, true, tick)
        Hoenn222CdSetRate(Hoenn222Slot(timeIndex, true), Hoenn222_RateOutOfBall,
            tick, Hoenn222_LatencyMs)
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=cd_call", e)
    }
}

; --- COOLDOWN INDIVIDUAL DOS 6 POKEMON ---
; Acumulador preguiçoso: o estado so e atualizado na leitura (CdTouch). Qualquer
; leitura ou escrita chama CdTouch antes, entao nenhum evento precisa propagar
; recuperacao e nao existe risco de esquecer um slot.
;   slot = (time - 1) * 2 + (1 tank, 2 secundario)
global Hoenn222_Cd := [0, 0, 0, 0, 0, 0]
global Hoenn222_CdRate := [0, 0, 0, 0, 0, 0]
global Hoenn222_CdSince := [0, 0, 0, 0, 0, 0]
; Instante estimado em que o CD do slot chegou a zero. A margem de seguranca
; conta a partir dele: sem isso um CD zerado ha minutos continuaria exigindo a
; margem inteira para sempre e o verde nunca acenderia.
global Hoenn222_CdZeroTick := [0, 0, 0, 0, 0, 0]
; Time ja fez o primeiro cast do tank depois do F8/inicio? Enquanto nao fez, o
; verde do COMBAR segue o ritmo do plano (ver Hoenn222FirstLapLureMs).
global Hoenn222_TeamCasted := Map(1, false, 2, false, 3, false)

; Le o CD restante ja com a recuperacao ate `tick` aplicada.
Hoenn222CdTouched(slot, tick) {
    global Hoenn222_Cd
    Hoenn222CdTouch(slot, tick)
    return Hoenn222_Cd[slot]
}

Hoenn222CdRateOf(slot) {
    global Hoenn222_CdRate
    Hoenn222CdTouch(slot, A_TickCount)
    taxa := Hoenn222_CdRate[slot]
    return taxa > 0 ? taxa : 1
}

; Integer() e obrigatorio: neste AutoHotkey um indice Float seria tratado como
; nome de propriedade e o acesso ao array falharia.
Hoenn222Slot(timeIndex, secundario := false) {
    return Integer((Integer(timeIndex) - 1) * 2 + (secundario ? 2 : 1))
}

; CD principal pelo rotulo do tier. Sem correspondencia usa o padrao e avisa uma vez.
GetHoenn222CdMainMs(timeIndex, secundario := false) {
    global Hoenn222_TankTier, Hoenn222_SecondTier, Hoenn222_CdByTier
    global Hoenn222_CdDefaultMs, Hoenn222_CdAvisoFeito
    timeIndex := Integer(timeIndex)
    try {
        tier := secundario ? GetHoenn222TierText(timeIndex, "second") : GetHoenn222TierText(timeIndex, "tank")
        mapa := secundario ? Hoenn222_SecondTier : Hoenn222_TankTier
        if IsObject(Hoenn222_CdByTier) {
            for chave, valor in Hoenn222_CdByTier {
                if (StrLower(chave) = StrLower(tier))
                    return valor
            }
            if mapa.Has(timeIndex) {
                for chave, valor in Hoenn222_CdByTier {
                    if (StrLower(chave) = StrLower(mapa[timeIndex]))
                        return valor
                }
            }
        }
        if !Hoenn222_CdAvisoFeito {
            Hoenn222_CdAvisoFeito := true
            SwitchDebug("CD_TIER_UNKNOWN", "tier=" tier " padrao=" Hoenn222_CdDefaultMs " time=" timeIndex)
        }
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=cd_tier", e)
    }
    return Hoenn222_CdDefaultMs
}

; Atualiza o acumulador ate `tick`. Delta negativo (tick no futuro) nao credita.
Hoenn222CdTouch(slot, tick) {
    global Hoenn222_Cd, Hoenn222_CdRate, Hoenn222_CdSince, Hoenn222_CdZeroTick
    elapsed := tick - Hoenn222_CdSince[slot]
    if (elapsed > 0) {
        restante := Hoenn222_Cd[slot] - elapsed * Hoenn222_CdRate[slot]
        if (restante <= 0) {
            ; O CD zerou dentro deste intervalo: guarda o instante exato.
            if (Hoenn222_Cd[slot] > 0 && Hoenn222_CdRate[slot] > 0)
                Hoenn222_CdZeroTick[slot] := Hoenn222_CdSince[slot] + Hoenn222_Cd[slot] / Hoenn222_CdRate[slot]
            restante := 0
        }
        Hoenn222_Cd[slot] := restante
        Hoenn222_CdSince[slot] := tick
    }
}

; Sair da Ball so conta depois de LatencyMs; voltar e imediato.
; As duas direcoes reduzem a recuperacao creditada, nunca aumentam.
Hoenn222CdSetRate(slot, rate, tick, atrasoMs := 0) {
    global Hoenn222_CdRate, Hoenn222_CdSince
    Hoenn222CdTouch(slot, tick)
    Hoenn222_CdRate[slot] := rate
    if (atrasoMs > 0)
        Hoenn222_CdSince[slot] := tick + atrasoMs
}

; O cast reinicia o cooldown e a contagem so comeca LatencyMs depois do comando.
; O progresso acumulado antes do cast e descartado: nunca e contado duas vezes.
; Usar a skill pressupoe estar fora da Ball, entao a taxa passa a 1,0 aqui.
Hoenn222CdCast(timeIndex, secundario, tick) {
    global Hoenn222_Cd, Hoenn222_CdRate, Hoenn222_CdSince
    global Hoenn222_LatencyMs, Hoenn222_MarginMs, Hoenn222_RateOutOfBall
    global Hoenn222_TeamCasted
    slot := Hoenn222Slot(timeIndex, secundario)
    if !secundario
        Hoenn222_TeamCasted[Integer(timeIndex)] := true
    Hoenn222CdTouch(slot, tick)
    Hoenn222_CdRate[slot] := Hoenn222_RateOutOfBall
    Hoenn222_Cd[slot] := GetHoenn222CdMainMs(timeIndex, secundario)
    Hoenn222_CdSince[slot] := tick + Hoenn222_LatencyMs
    SwitchDebug("CD_CAST", "slot=" slot " time=" timeIndex " papel=" (secundario ? "sec" : "tank")
        " cd_main=" Hoenn222_Cd[slot] " tick=" tick " cd_comeca=" Hoenn222_CdSince[slot]
        " pronto=" (tick + Hoenn222_LatencyMs + Hoenn222_Cd[slot])
        " seguro=" (tick + Hoenn222_LatencyMs + Hoenn222_Cd[slot] + Hoenn222_MarginMs))
}

; Milissegundos ate o primeiro instante seguro: CD zerado mais a margem. Com o
; CD ja zerado, so falta o que sobrar da margem contada desde o instante em que
; ele zerou; passou disso, esta pronto (0).
Hoenn222CdReadyInMs(slot, tick) {
    global Hoenn222_Cd, Hoenn222_CdRate, Hoenn222_MarginMs, Hoenn222_CdZeroTick
    global Hoenn222_CdSince
    Hoenn222CdTouch(slot, tick)
    if (Hoenn222_Cd[slot] <= 0) {
        faltaMargem := Hoenn222_CdZeroTick[slot] + Hoenn222_MarginMs - tick
        return faltaMargem > 0 ? faltaMargem : 0
    }
    taxa := Hoenn222_CdRate[slot] > 0 ? Hoenn222_CdRate[slot] : 1
    ; Congelamento de latencia ainda por vir: o CD nao corre ate la.
    congelado := Hoenn222_CdSince[slot] > tick ? Hoenn222_CdSince[slot] - tick : 0
    return congelado + Hoenn222_Cd[slot] / taxa + Hoenn222_MarginMs
}

; Troca de time aceita: a dupla anterior volta, so o tank da nova sai.
Hoenn222CdTrocaTime(previousTeam, nextTeam, tick) {
    global Hoenn222_RateInBall, Hoenn222_RateOutOfBall, Hoenn222_LatencyMs
    try {
        for secundario in [false, true] {
            Hoenn222CdSetRate(Hoenn222Slot(previousTeam, secundario), Hoenn222_RateInBall, tick)
        }
        ; O tank novo tambem so comeca a recuperar LatencyMs depois da tecla: sair da
        ; Ball leva o mesmo congelamento do secundario na chamada. Creditar 1,0 desde o
        ; instante da tecla deixava os casts de tank ~250 ms otimistas.
        Hoenn222CdSetRate(Hoenn222Slot(nextTeam, false), Hoenn222_RateOutOfBall, tick, Hoenn222_LatencyMs)
        Hoenn222CdLogEntrada(nextTeam, false, tick)
        ; o secundario da dupla nova continua na Ball ate a chamada no combo
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=cd_team_switch", e)
    }
}

; Diagnostico (so log): o CD que o MODELO espera de um Pokemon no instante em que ele entra
; em campo. Compare com os contadores da barra de golpes do jogo no mesmo instante
; para medir o erro do modelo por Pokemon. Nao altera nenhum calculo.
Hoenn222CdLogEntrada(timeIndex, secundario, tick) {
    global Hoenn222_Cd, Hoenn222_CdRate
    try {
        slot := Hoenn222Slot(timeIndex, secundario)
        Hoenn222CdTouch(slot, tick)
        SwitchDebug("CD_ENTRADA", "slot=" slot " time=" timeIndex " papel=" (secundario ? "sec" : "tank")
            " cd_modelo_ms=" Round(Hoenn222_Cd[slot]) " taxa=" Hoenn222_CdRate[slot]
            " pronto_em_ms=" Round(Hoenn222CdReadyInMs(slot, tick)))
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=cd_entrada", e)
    }
}

; F8: nada se sabe do estado do jogo, entao os seis comecam prontos e na Ball.
ResetarCooldownsHoenn222(tick) {
    global Hoenn222_Cd, Hoenn222_CdRate, Hoenn222_CdSince, Hoenn222_RateInBall
    global Hoenn222_CdZeroTick, Hoenn222_TeamCasted
    Hoenn222_TeamCasted := Map(1, false, 2, false, 3, false)
    i := 1
    while i <= 6 {
        Hoenn222_Cd[i] := 0
        Hoenn222_CdRate[i] := Hoenn222_RateInBall
        Hoenn222_CdSince[i] := tick
        Hoenn222_CdZeroTick[i] := 0
        i += 1
    }
}

#Requires AutoHotkey v2.0
; Cooldown individual dos 6 Pokemon: acumulador preguicoso, taxas dentro/fora da Ball, latencia, margem.

; Registro de eventos do CD, isolado: qualquer falha aqui não cancela o combo.
RegistrarCast(timeIndex, secundario := false) {
    global Hoenn222_CdOptimizerEnabled
    if !Hoenn222_CdOptimizerEnabled
        return
    try {
        AplicarCast(timeIndex, secundario, A_TickCount)
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=cd_cast", e)
    }
}

RegistrarChamadaDoSecundario(timeIndex) {
    global Hoenn222_CdOptimizerEnabled, Hoenn222_RateOutOfBall, Hoenn222_RateInBall
    global Hoenn222_ExitLatencySecondaryMs
    if !Hoenn222_CdOptimizerEnabled
        return
    try {
        tick := A_TickCount
        ; APENAS UM POKEMON POR VEZ FORA DA BALL. Ao chamar o p2 o tank sai
        ; de campo: se ele continuasse a 1,0x os dois recuperariam juntos e a
        ; capacidade da volta passaria de 3,5x para 4,0x, inflando o plano.
        DefinirTaxaDeRecuperacao(SlotDoPokemon(timeIndex, false), Hoenn222_RateInBall, tick)
        LogarEntradaEmCampo(timeIndex, true, tick)
        ; A saida do secundario (chamada) tem atraso proprio, maior que o da troca de time.
        DefinirTaxaDeRecuperacao(SlotDoPokemon(timeIndex, true), Hoenn222_RateOutOfBall,
            tick, Hoenn222_ExitLatencySecondaryMs)
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=cd_call", e)
    }
}

; --- COOLDOWN INDIVIDUAL DOS 6 POKEMON ---
; Acumulador preguiçoso: o estado so e atualizado na leitura (CdTouch). Qualquer
; leitura ou escrita chama CdTouch antes, entao nenhum evento precisa propagar
; recuperacao e nao existe risco de esquecer um slot.
;   slot = (time - 1) * 2 + (1 tank, 2 secundario)
global CooldownRestanteMs := [0, 0, 0, 0, 0, 0]
global TaxaDeRecuperacao := [0, 0, 0, 0, 0, 0]
global CooldownContaDesdeTick := [0, 0, 0, 0, 0, 0]
; Instante estimado em que o CD do slot chegou a zero. A margem de seguranca
; conta a partir dele: sem isso um CD zerado ha minutos continuaria exigindo a
; margem inteira para sempre e o verde nunca acenderia.
global CooldownZerouTick := [0, 0, 0, 0, 0, 0]
; Time ja fez o primeiro cast do tank depois do F8/inicio? Enquanto nao fez, o
; verde do COMBAR segue o ritmo do plano (ver FaltaParaLureDaPrimeiraVoltaMs).
global TankJaCastou := Map(1, false, 2, false, 3, false)

; Le o CD restante ja com a recuperacao ate `tick` aplicada.
LerCooldownRestanteMs(slot, tick) {
    global CooldownRestanteMs
    AtualizarCooldown(slot, tick)
    return CooldownRestanteMs[slot]
}

LerTaxaDeRecuperacao(slot) {
    global TaxaDeRecuperacao
    AtualizarCooldown(slot, A_TickCount)
    taxa := TaxaDeRecuperacao[slot]
    return taxa > 0 ? taxa : 1
}

; Integer() e obrigatorio: neste AutoHotkey um indice Float seria tratado como
; nome de propriedade e o acesso ao array falharia.
SlotDoPokemon(timeIndex, secundario := false) {
    return Integer((Integer(timeIndex) - 1) * 2 + (secundario ? 2 : 1))
}

; CD principal pelo rotulo do tier. Sem correspondencia usa o padrao e avisa uma vez.
CooldownBaseMs(timeIndex, secundario := false) {
    global Hoenn222_TankTier, Hoenn222_SecondTier, Hoenn222_CdByTier
    global Hoenn222_CdDefaultMs, AvisoDeTierDesconhecidoFeito
    timeIndex := Integer(timeIndex)
    try {
        tier := secundario ? RotuloDoTier(timeIndex, "second") : RotuloDoTier(timeIndex, "tank")
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
        if !AvisoDeTierDesconhecidoFeito {
            AvisoDeTierDesconhecidoFeito := true
            LogDiagnostico("CD_TIER_UNKNOWN", "tier=" tier " padrao=" Hoenn222_CdDefaultMs " time=" timeIndex)
        }
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=cd_tier", e)
    }
    return Hoenn222_CdDefaultMs
}

; Atualiza o acumulador ate `tick`. Delta negativo (tick no futuro) nao credita.
AtualizarCooldown(slot, tick) {
    global CooldownRestanteMs, TaxaDeRecuperacao, CooldownContaDesdeTick, CooldownZerouTick
    elapsed := tick - CooldownContaDesdeTick[slot]
    if (elapsed > 0) {
        restante := CooldownRestanteMs[slot] - elapsed * TaxaDeRecuperacao[slot]
        if (restante <= 0) {
            ; O CD zerou dentro deste intervalo: guarda o instante exato.
            if (CooldownRestanteMs[slot] > 0 && TaxaDeRecuperacao[slot] > 0)
                CooldownZerouTick[slot] := CooldownContaDesdeTick[slot] + CooldownRestanteMs[slot] / TaxaDeRecuperacao[slot]
            restante := 0
        }
        CooldownRestanteMs[slot] := restante
        CooldownContaDesdeTick[slot] := tick
    }
}

; Sair da Ball so conta depois de LatencyMs; voltar e imediato.
; As duas direcoes reduzem a recuperacao creditada, nunca aumentam.
DefinirTaxaDeRecuperacao(slot, rate, tick, atrasoMs := 0) {
    global TaxaDeRecuperacao, CooldownContaDesdeTick
    AtualizarCooldown(slot, tick)
    TaxaDeRecuperacao[slot] := rate
    if (atrasoMs > 0)
        CooldownContaDesdeTick[slot] := tick + atrasoMs
}

; O cast reinicia o cooldown e a contagem so comeca LatencyMs depois do comando.
; O progresso acumulado antes do cast e descartado: nunca e contado duas vezes.
; Usar a skill pressupoe estar fora da Ball, entao a taxa passa a 1,0 aqui.
AplicarCast(timeIndex, secundario, tick) {
    global CooldownRestanteMs, TaxaDeRecuperacao, CooldownContaDesdeTick
    global Hoenn222_LatencyMs, Hoenn222_MarginMs, Hoenn222_RateOutOfBall
    global TankJaCastou
    slot := SlotDoPokemon(timeIndex, secundario)
    if !secundario
        TankJaCastou[Integer(timeIndex)] := true
    AtualizarCooldown(slot, tick)
    TaxaDeRecuperacao[slot] := Hoenn222_RateOutOfBall
    CooldownRestanteMs[slot] := CooldownBaseMs(timeIndex, secundario)
    CooldownContaDesdeTick[slot] := tick + Hoenn222_LatencyMs
    LogDiagnostico("CD_CAST", "slot=" slot " time=" timeIndex " papel=" (secundario ? "sec" : "tank")
        " cd_main=" CooldownRestanteMs[slot] " tick=" tick " cd_comeca=" CooldownContaDesdeTick[slot]
        " pronto=" (tick + Hoenn222_LatencyMs + CooldownRestanteMs[slot])
        " seguro=" (tick + Hoenn222_LatencyMs + CooldownRestanteMs[slot] + Hoenn222_MarginMs))
}

; Milissegundos ate o primeiro instante seguro: CD zerado mais a margem. Com o
; CD ja zerado, so falta o que sobrar da margem contada desde o instante em que
; ele zerou; passou disso, esta pronto (0).
MsAteCastSeguro(slot, tick) {
    global CooldownRestanteMs, TaxaDeRecuperacao, Hoenn222_MarginMs, CooldownZerouTick
    global CooldownContaDesdeTick
    AtualizarCooldown(slot, tick)
    if (CooldownRestanteMs[slot] <= 0) {
        faltaMargem := CooldownZerouTick[slot] + Hoenn222_MarginMs - tick
        return faltaMargem > 0 ? faltaMargem : 0
    }
    taxa := TaxaDeRecuperacao[slot] > 0 ? TaxaDeRecuperacao[slot] : 1
    ; Congelamento de latencia ainda por vir: o CD nao corre ate la.
    congelado := CooldownContaDesdeTick[slot] > tick ? CooldownContaDesdeTick[slot] - tick : 0
    return congelado + CooldownRestanteMs[slot] / taxa + Hoenn222_MarginMs
}

; Troca de time aceita: a dupla anterior volta, so o tank da nova sai.
RegistrarTrocaDeTime(previousTeam, nextTeam, tick) {
    global Hoenn222_RateInBall, Hoenn222_RateOutOfBall, Hoenn222_LatencyMs
    try {
        for secundario in [false, true] {
            DefinirTaxaDeRecuperacao(SlotDoPokemon(previousTeam, secundario), Hoenn222_RateInBall, tick)
        }
        ; O tank novo tambem so comeca a recuperar LatencyMs depois da tecla: sair da
        ; Ball leva o mesmo congelamento do secundario na chamada. Creditar 1,0 desde o
        ; instante da tecla deixava os casts de tank ~250 ms otimistas.
        DefinirTaxaDeRecuperacao(SlotDoPokemon(nextTeam, false), Hoenn222_RateOutOfBall, tick, Hoenn222_LatencyMs)
        LogarEntradaEmCampo(nextTeam, false, tick)
        ; o secundario da dupla nova continua na Ball ate a chamada no combo
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=cd_team_switch", e)
    }
}

; Diagnostico (so log): o CD que o MODELO espera de um Pokemon no instante em que ele entra
; em campo. Compare com os contadores da barra de golpes do jogo no mesmo instante
; para medir o erro do modelo por Pokemon. Nao altera nenhum calculo.
LogarEntradaEmCampo(timeIndex, secundario, tick) {
    global CooldownRestanteMs, TaxaDeRecuperacao
    try {
        slot := SlotDoPokemon(timeIndex, secundario)
        AtualizarCooldown(slot, tick)
        LogDiagnostico("CD_ENTRADA", "slot=" slot " time=" timeIndex " papel=" (secundario ? "sec" : "tank")
            " cd_modelo_ms=" Round(CooldownRestanteMs[slot]) " taxa=" TaxaDeRecuperacao[slot]
            " pronto_em_ms=" Round(MsAteCastSeguro(slot, tick)))
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=cd_entrada", e)
    }
}

; F8: nada se sabe do estado do jogo, entao os seis comecam prontos e na Ball.
ResetarCooldowns(tick) {
    global CooldownRestanteMs, TaxaDeRecuperacao, CooldownContaDesdeTick, Hoenn222_RateInBall
    global CooldownZerouTick, TankJaCastou
    TankJaCastou := Map(1, false, 2, false, 3, false)
    i := 1
    while i <= 6 {
        CooldownRestanteMs[i] := 0
        TaxaDeRecuperacao[i] := Hoenn222_RateInBall
        CooldownContaDesdeTick[i] := tick
        CooldownZerouTick[i] := 0
        i += 1
    }
}

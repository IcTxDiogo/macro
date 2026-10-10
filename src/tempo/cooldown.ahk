#Requires AutoHotkey v2.0
; Cooldown individual dos 6 Pokemon.
;
; Cada Pokemon tem um "slot": (time - 1) * 2 + 1 para o tank e + 2 para o secundario.
; O cooldown restante de cada slot e um acumulador preguicoso: so e atualizado quando
; alguem le ou escreve (AtualizarCooldown). Nenhum evento precisa propagar recuperacao.
;
; Recuperacao por segundo: Hoenn222_RateOutOfBall fora da Ball, Hoenn222_RateInBall dentro.
; Tres atrasos fisicos congelam a contagem (ver config.ahk):
;   - depois de um cast, o CD novo so comeca a contar apos Hoenn222_LatencyMs;
;   - ao sair da Ball na troca de time (tank): Hoenn222_LatencyMs;
;   - ao sair da Ball na chamada (secundario): Hoenn222_ExitLatencySecondaryMs.

global CooldownRestanteMs := [0, 0, 0, 0, 0, 0]
global TaxaDeRecuperacao := [0, 0, 0, 0, 0, 0]
; Instante a partir do qual CooldownRestanteMs volta a correr (no futuro = congelado).
global CooldownContaDesdeTick := [0, 0, 0, 0, 0, 0]
; Instante estimado em que o CD zerou. A margem de seguranca conta a partir dele: sem
; isso, um CD zerado ha minutos continuaria exigindo a margem inteira e o verde nunca
; acenderia.
global CooldownZerouTick := [0, 0, 0, 0, 0, 0]
; O tank de cada time ja castou desde o F8/inicio? Enquanto nao, o verde do COMBAR segue
; o ritmo do plano (ver FaltaParaLureDaPrimeiraVoltaMs).
global TankJaCastou := Map(1, false, 2, false, 3, false)

; --- Registro de eventos do jogo -------------------------------------------------------
; Falha aqui nunca cancela o combo: o erro vai para o log e o macro segue.

RegistrarCast(time, secundario := false) {
    global Hoenn222_CdOptimizerEnabled
    if !Hoenn222_CdOptimizerEnabled
        return
    try {
        AplicarCast(time, secundario, A_TickCount)
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=cd_cast", e)
    }
}

; A chamada troca quem esta fora: o tank volta para a Ball e o secundario sai. So um
; Pokemon fica fora por vez; se o tank continuasse a 1,0 os dois recuperariam juntos e a
; capacidade da volta passaria de 3,5x para 4,0x.
RegistrarChamadaDoSecundario(time) {
    global Hoenn222_CdOptimizerEnabled, Hoenn222_RateOutOfBall, Hoenn222_RateInBall
    global Hoenn222_ExitLatencySecondaryMs
    if !Hoenn222_CdOptimizerEnabled
        return
    try {
        tick := A_TickCount
        DefinirTaxaDeRecuperacao(SlotDoPokemon(time, false), Hoenn222_RateInBall, tick)
        LogarEntradaEmCampo(time, true, tick)
        DefinirTaxaDeRecuperacao(SlotDoPokemon(time, true), Hoenn222_RateOutOfBall,
            tick, Hoenn222_ExitLatencySecondaryMs)
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=cd_call", e)
    }
}

; Troca de time aceita: a dupla anterior volta para a Ball e so o tank da nova sai (o
; secundario continua na Ball ate a chamada no combo).
RegistrarTrocaDeTime(timeAnterior, proximoTime, tick) {
    global Hoenn222_RateInBall, Hoenn222_RateOutOfBall, Hoenn222_LatencyMs
    try {
        for secundario in [false, true]
            DefinirTaxaDeRecuperacao(SlotDoPokemon(timeAnterior, secundario), Hoenn222_RateInBall, tick)
        DefinirTaxaDeRecuperacao(SlotDoPokemon(proximoTime, false), Hoenn222_RateOutOfBall,
            tick, Hoenn222_LatencyMs)
        LogarEntradaEmCampo(proximoTime, false, tick)
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=cd_team_switch", e)
    }
}

; F8: nada se sabe do estado do jogo, entao os seis comecam prontos e dentro da Ball.
ResetarCooldowns(tick) {
    global CooldownRestanteMs, TaxaDeRecuperacao, CooldownContaDesdeTick, CooldownZerouTick
    global TankJaCastou, Hoenn222_RateInBall
    TankJaCastou := Map(1, false, 2, false, 3, false)
    loop 6 {
        CooldownRestanteMs[A_Index] := 0
        TaxaDeRecuperacao[A_Index] := Hoenn222_RateInBall
        CooldownContaDesdeTick[A_Index] := tick
        CooldownZerouTick[A_Index] := 0
    }
}

; --- Leitura ---------------------------------------------------------------------------

; Integer() e obrigatorio: neste AutoHotkey um indice Float seria tratado como nome de
; propriedade e o acesso ao array falharia.
SlotDoPokemon(time, secundario := false) {
    return Integer((Integer(time) - 1) * 2 + (secundario ? 2 : 1))
}

; CD restante ja com a recuperacao ate `tick` aplicada.
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

; Ms ate o primeiro instante seguro de castar: CD zerado mais a margem. Se o CD ja zerou,
; so falta o que sobrar da margem contada desde o instante em que zerou (0 se passou).
MsAteCastSeguro(slot, tick) {
    global CooldownRestanteMs, TaxaDeRecuperacao, CooldownContaDesdeTick, CooldownZerouTick
    global Hoenn222_MarginMs
    AtualizarCooldown(slot, tick)
    if (CooldownRestanteMs[slot] <= 0) {
        margemRestanteMs := CooldownZerouTick[slot] + Hoenn222_MarginMs - tick
        return margemRestanteMs > 0 ? margemRestanteMs : 0
    }
    taxa := TaxaDeRecuperacao[slot] > 0 ? TaxaDeRecuperacao[slot] : 1
    congeladoMs := CooldownContaDesdeTick[slot] > tick ? CooldownContaDesdeTick[slot] - tick : 0
    return congeladoMs + CooldownRestanteMs[slot] / taxa + Hoenn222_MarginMs
}

; CD principal do Pokemon pelo rotulo do tier (config). Rotulo fora da tabela usa o padrao
; e avisa uma vez no log.
CooldownBaseMs(time, secundario := false) {
    global Hoenn222_CdByTier, Hoenn222_CdDefaultMs, AvisoDeTierDesconhecidoFeito
    time := Integer(time)
    try {
        rotulo := RotuloDoTier(time, secundario ? "second" : "tank")
        if IsObject(Hoenn222_CdByTier) {
            for tier, cooldownMs in Hoenn222_CdByTier {
                if (StrLower(tier) = StrLower(rotulo))
                    return cooldownMs
            }
        }
        if !AvisoDeTierDesconhecidoFeito {
            AvisoDeTierDesconhecidoFeito := true
            LogDiagnostico("CD_TIER_UNKNOWN", "tier=" rotulo " padrao=" Hoenn222_CdDefaultMs " time=" time)
        }
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=cd_tier", e)
    }
    return Hoenn222_CdDefaultMs
}

; --- Acumulador ------------------------------------------------------------------------

; Atualiza o slot ate `tick`. Intervalo negativo (tick no futuro = congelado) nao credita.
AtualizarCooldown(slot, tick) {
    global CooldownRestanteMs, TaxaDeRecuperacao, CooldownContaDesdeTick, CooldownZerouTick
    decorridoMs := tick - CooldownContaDesdeTick[slot]
    if (decorridoMs <= 0)
        return
    restanteMs := CooldownRestanteMs[slot] - decorridoMs * TaxaDeRecuperacao[slot]
    if (restanteMs <= 0) {
        ; Zerou dentro deste intervalo: guarda o instante exato.
        if (CooldownRestanteMs[slot] > 0 && TaxaDeRecuperacao[slot] > 0)
            CooldownZerouTick[slot] := CooldownContaDesdeTick[slot] + CooldownRestanteMs[slot] / TaxaDeRecuperacao[slot]
        restanteMs := 0
    }
    CooldownRestanteMs[slot] := restanteMs
    CooldownContaDesdeTick[slot] := tick
}

; Muda a taxa a partir de `tick`. Com `atrasoMs`, o CD fica congelado ate tick + atrasoMs
; (sair da Ball custa o atraso; voltar para ela e imediato).
DefinirTaxaDeRecuperacao(slot, taxa, tick, atrasoMs := 0) {
    global TaxaDeRecuperacao, CooldownContaDesdeTick
    AtualizarCooldown(slot, tick)
    TaxaDeRecuperacao[slot] := taxa
    if (atrasoMs > 0)
        CooldownContaDesdeTick[slot] := tick + atrasoMs
}

; O cast reinicia o cooldown; a contagem so comeca Hoenn222_LatencyMs depois do comando.
; O progresso anterior e descartado (nunca contado duas vezes). Castar pressupoe estar fora
; da Ball, entao a taxa passa a Hoenn222_RateOutOfBall.
AplicarCast(time, secundario, tick) {
    global CooldownRestanteMs, TaxaDeRecuperacao, CooldownContaDesdeTick, TankJaCastou
    global Hoenn222_LatencyMs, Hoenn222_MarginMs, Hoenn222_RateOutOfBall
    slot := SlotDoPokemon(time, secundario)
    if !secundario
        TankJaCastou[Integer(time)] := true
    AtualizarCooldown(slot, tick)
    TaxaDeRecuperacao[slot] := Hoenn222_RateOutOfBall
    CooldownRestanteMs[slot] := CooldownBaseMs(time, secundario)
    CooldownContaDesdeTick[slot] := tick + Hoenn222_LatencyMs
    prontoTick := tick + Hoenn222_LatencyMs + CooldownRestanteMs[slot]
    LogDiagnostico("CD_CAST", "slot=" slot " time=" time " papel=" (secundario ? "sec" : "tank")
        " cd_main=" CooldownRestanteMs[slot] " tick=" tick " cd_comeca=" CooldownContaDesdeTick[slot]
        " pronto=" prontoTick " seguro=" (prontoTick + Hoenn222_MarginMs))
}

; Diagnostico (so log): o CD que o MODELO espera de um Pokemon quando ele entra em campo.
; Compare com os contadores da barra de golpes do jogo para medir o erro do modelo.
LogarEntradaEmCampo(time, secundario, tick) {
    global CooldownRestanteMs, TaxaDeRecuperacao
    try {
        slot := SlotDoPokemon(time, secundario)
        AtualizarCooldown(slot, tick)
        LogDiagnostico("CD_ENTRADA", "slot=" slot " time=" time " papel=" (secundario ? "sec" : "tank")
            " cd_modelo_ms=" Round(CooldownRestanteMs[slot]) " taxa=" TaxaDeRecuperacao[slot]
            " pronto_em_ms=" Round(MsAteCastSeguro(slot, tick)))
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=cd_entrada", e)
    }
}

#Requires AutoHotkey v2.0
; Cronometro: ate quando esperar, por fase. Alimenta o indicador (verde = 0) e os pedidos
; armados. Tudo aqui e uma DURACAO em ms, nunca um instante absoluto.

; Quanto dura a fase `fase` do time contada desde o inicio dela (InicioDaFaseTick).
; Com o otimizador ligado vem do estado real dos seis Pokemon; desligado, ou se algo
; falhar, usa os alvos fixos do config.ahk.
AlvoDaFaseMs(fase, time) {
    global Hoenn222_CdOptimizerEnabled, Hoenn222_ComboTargetMs, Hoenn222_SwitchTargetMs
    global InicioDaFaseTick

    if (fase != "WAITING_COMBO" && fase != "WAITING_TEAM_SWITCH")
        return 0

    if Hoenn222_CdOptimizerEnabled {
        try {
            ; FaltaParaComboViavelMs e "quanto falta a partir de agora"; somar o decorrido
            ; devolve a duracao desde o inicio da fase. Sem isso o decorrido seria
            ; descontado duas vezes e o verde acenderia na metade do tempo.
            return (fase == "WAITING_COMBO")
                ? (A_TickCount - InicioDaFaseTick) + FaltaParaComboViavelMs(time)
                : DuracaoDoTrocarTimeMs(time)
        } catch as e {
            LogDiagnostico("SWITCH_ERROR", "phase=cd_target state=" fase, e)
        }
    }
    return (fase == "WAITING_COMBO")
        ? AlvoFixoDoConfigMs(Hoenn222_ComboTargetMs, time)
        : AlvoFixoDoConfigMs(Hoenn222_SwitchTargetMs, time)
}

; Alvo fixo do config.ahk por time (otimizador desligado ou falha ao ler o estado real).
AlvoFixoDoConfigMs(alvos, time) {
    try {
        return (IsObject(alvos) && alvos.Has(time)) ? alvos[time] : 0
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=target_config team=" time, e)
        return 0
    }
}

; Quanto falta para a fase atual ficar verde. <= 0 e verde: apertar executa na hora.
FaltaParaVerdeMs() {
    global FaseAtual, InicioDaFaseTick, TimeAtual
    if (FaseAtual == "WAITING_FIRST_COMBO")
        return 0
    return AlvoDaFaseMs(FaseAtual, TimeAtual) - (A_TickCount - InicioDaFaseTick)
}

; COMBAR: ms (a partir de agora) ate o combo INTEIRO ser viavel com os tempos internos
; fixos. Sem espera artificial: so manda o cooldown. O verde acende quando os dois couberem:
;   Tank       CD zerado + margem <= T0
;   Secundario entre T0 e a chamada ele segue na Ball (0,5 x SleepAfterTankCombo); depois
;              da chamada o CD congela Hoenn222_ExitLatencySecondaryMs antes de recuperar
;              a 1,0 ate o cast (SleepAfterSwitch depois). O teto de CD que ele pode ter
;              em T0 e ToleranciaDoSecundarioMs.
FaltaParaComboViavelMs(time) {
    global ToleranciaDoSecundarioMs
    tankMs := MsAteCastSeguro(SlotDoPokemon(time, false), A_TickCount)
    tankMs := Max(tankMs, FaltaParaLureDaPrimeiraVoltaMs(time))

    slotSec := SlotDoPokemon(time, true)
    cdSecMs := LerCooldownRestanteMs(slotSec, A_TickCount)
    secMs := 0
    if (cdSecMs > ToleranciaDoSecundarioMs)
        secMs := (cdSecMs - ToleranciaDoSecundarioMs) / LerTaxaDeRecuperacao(slotSec)
    return Max(0, tankMs, secMs)
}

; Teto de CD que o secundario pode ter no instante T0 (inicio do combo) sem estourar o seu
; cast. Entre T0 e a chamada ele ainda esta na Ball (0,5 x SleepAfterTankCombo); depois da
; chamada o CD congela Hoenn222_ExitLatencySecondaryMs e so recupera a 1,0 pelo que sobrar
; de SleepAfterSwitch; a margem ainda tem de caber antes do cast. Com o atraso medido
; (1100 ms > 800 ms) nada recupera a 1,0: o CD tem de zerar dentro da Ball.
CalcularToleranciaDoSecundarioMs() {
    return 0.5 * SleepAfterTankCombo + Max(0, SleepAfterSwitch - Hoenn222_ExitLatencySecondaryMs)
        - Hoenn222_MarginMs
}

; Lure que ainda falta antes de liberar o combo (contado da troca de time, que e quando a
; fase COMBAR comeca). Na primeira volta apos o F8 os seis estao prontos e nada obrigaria a
; esperar; o macro liberaria os tres times em sequencia e a espera inteira cairia na volta
; do time 1. Por isso, ate o tank do time castar uma vez, vale o lure do plano; depois, so o
; piso de conforto do config (0 = so o cooldown manda).
FaltaParaLureDaPrimeiraVoltaMs(time) {
    global TankJaCastou, InicioDaFaseTick
    time := Integer(time)
    lureMs := TankJaCastou[time]
        ? PisoDoConfigMs("Hoenn222_MinLureMs", time)
        : PlanejarVolta().Lures[time]
    faltaMs := lureMs - (A_TickCount - InicioDaFaseTick)
    return faltaMs > 0 ? faltaMs : 0
}

; Quanto de CD o secundario ainda teria no seu cast se o combo comecasse `emMs` a partir
; de agora. Permite avisar "nao viavel" sem inventar cooldown disponivel.
CooldownPendenteDoSecundarioMs(time, emMs) {
    slot := SlotDoPokemon(time, true)
    taxa := LerTaxaDeRecuperacao(slot)
    restanteMs := Max(0, LerCooldownRestanteMs(slot, A_TickCount) - emMs * taxa)
    ; entre o inicio do combo e a chamada o secundario segue dentro da Ball
    naChamadaMs := Max(0, restanteMs - SleepAfterTankCombo * taxa)
    pendenteMs := naChamadaMs - Max(0, SleepAfterSwitch - Hoenn222_ExitLatencySecondaryMs) + Hoenn222_MarginMs
    return pendenteMs > 0 ? pendenteMs : 0
}

; Quem segura o verde do combo: "secundario", "tank", "primeira_volta" ou "" (viavel).
; Diagnostico: nao altera nenhum alvo, so diz ao jogador o que falta.
QuemBloqueiaOCombo(time) {
    global ToleranciaDoSecundarioMs
    cdSecMs := LerCooldownRestanteMs(SlotDoPokemon(time, true), A_TickCount)
    if (cdSecMs > ToleranciaDoSecundarioMs)
        return "secundario"
    if (MsAteCastSeguro(SlotDoPokemon(time, false), A_TickCount) > 0)
        return "tank"
    if (FaltaParaLureDaPrimeiraVoltaMs(time) > 0)
        return "primeira_volta"
    return ""
}

; TROCAR TIME: quanto tempo depois do CAST a troca pode acontecer. A janela do plano
; comeca na troca de time e o lure vem antes do cast; esta fase comeca no cast, entao
; resta a janela menos o lure (usar a janela inteira contava o lure duas vezes).
DuracaoDoTrocarTimeMs(time) {
    plano := PlanejarVolta()
    return plano.Janelas[time] - plano.Lures[time]
}

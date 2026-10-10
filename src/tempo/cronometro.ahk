#Requires AutoHotkey v2.0
; Cronometro: alvo de cada fase, pendente ate o verde, quem segura o verde.

; Alvo do cronometro para a fase e a dupla informadas. E sempre uma DURACAO em
; ms contada a partir do inicio do estado, nunca um instante absoluto: e assim
; que Hoenn222_ComboTargetMs e Hoenn222_SwitchTargetMs sao definidos no config,
; e e assim que FaltaParaVerdeMs() desconta o tempo ja decorrido.
; Com o otimizador ligado o alvo vem do estado real dos seis Pokemon; desligado,
; ou se qualquer coisa falhar, volta aos alvos fixos do config.ahk.
AlvoDaFaseMs(state, timeIndex) {
    global Hoenn222_CdOptimizerEnabled, Hoenn222_ComboTargetMs, Hoenn222_SwitchTargetMs
    global InicioDaFaseTick

    if (state != "WAITING_COMBO" && state != "WAITING_TEAM_SWITCH")
        return 0

    if Hoenn222_CdOptimizerEnabled {
        try {
            ; FaltaParaComboViavelMs e "quanto falta A PARTIR DE AGORA", e ja
            ; desconta a recuperacao ate este instante. Para obedecer o contrato
            ; "duracao desde o inicio do estado" soma-se o decorrido: o pendente
            ; (alvo - decorrido) volta a ser exatamente o que falta. Sem isso o
            ; decorrido era descontado duas vezes e o verde acendia na metade do
            ; tempo real, com o CD do tank ainda correndo.
            return (state == "WAITING_COMBO")
                ? (A_TickCount - InicioDaFaseTick) + FaltaParaComboViavelMs(timeIndex)
                : DuracaoDoTrocarTimeMs(timeIndex)
        } catch as e {
            LogDiagnostico("SWITCH_ERROR", "phase=cd_target state=" state, e)
        }
    }
    return (state == "WAITING_COMBO")
        ? AlvoFixoDoConfigMs(Hoenn222_ComboTargetMs, timeIndex)
        : AlvoFixoDoConfigMs(Hoenn222_SwitchTargetMs, timeIndex)
}

; Alvos fixos do config.ahk, por dupla. Usado quando o otimizador esta
; desligado e como destino de fallback se o estado real nao puder ser lido.
AlvoFixoDoConfigMs(mapaTarget, timeIndex) {
    try {
        return (IsObject(mapaTarget) && mapaTarget.Has(timeIndex)) ? mapaTarget[timeIndex] : 0
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=target_config team=" timeIndex, e)
        return 0
    }
}

; Quanto falta, em ms, para o alvo da fase atual. E uma DURACAO, nunca um
; instante absoluto; quem compara com o relogio e o alvo da propria fase.
FaltaParaVerdeMs() {
    global FaseAtual, InicioDaFaseTick, TimeAtual
    if (FaseAtual == "WAITING_FIRST_COMBO") {
        return 0
    }
    idealMs := AlvoDaFaseMs(FaseAtual, TimeAtual)
    return idealMs - (A_TickCount - InicioDaFaseTick)
}

; COMBAR: quantos ms ate o combo INTEIRO ser viavel com os tempos internos fixos.
; Nao ha espera artificial: o macro nao impoe nada alem do cooldown.
;   Tank      : CD zerado + margem <= T0
;   Secundario: entre T0 e a chamada ele ainda esta na Ball (0,5 x 2700) e, depois
;               dela, o CD congela ExitLatencySecondary antes de recuperar a 1,0
;               ate o cast (800 ms depois); a margem ainda tem de caber.
;               Dai o teto SEC_TOL = 0,5*SleepAfterTankCombo +
;               max(0, SleepAfterSwitch - ExitLatencySecondary) - Margin, medido
;               em CD que o secundario pode ter em T0.
; E o maior dos dois: o verde so acende quando tank E secundario estao viaveis.
FaltaParaComboViavelMs(timeIndex) {
    global ToleranciaDoSecundarioMs
    tankMs := MsAteCastSeguro(SlotDoPokemon(timeIndex, false), A_TickCount)
    ; Primeira volta: o CD zerado nao pode liberar o combo antes do ritmo do plano.
    tankMs := Max(tankMs, FaltaParaLureDaPrimeiraVoltaMs(timeIndex))
    secSlot := SlotDoPokemon(timeIndex, true)
    cdSec := LerCooldownRestanteMs(secSlot, A_TickCount)
    secMs := 0
    if (cdSec > ToleranciaDoSecundarioMs)
        secMs := (cdSec - ToleranciaDoSecundarioMs) / LerTaxaDeRecuperacao(secSlot)
    return Max(0, Max(tankMs, secMs))
}

; PRIMEIRA VOLTA. Depois do F8 (ou ao ligar) os seis Pokemon estao com o CD
; pronto, entao nada obrigaria a esperar: o macro liberaria os tres times um
; atras do outro e a espera inteira cairia de uma vez na volta do time 1. Para o
; ritmo sustentavel valer desde o primeiro ciclo, o time que ainda nao fez o
; primeiro cast so libera o combo depois do `lure` planejado, contado da troca
; de time (o estado COMBAR comeca na troca). Passado o primeiro cast do time, o
; que manda e so o cooldown real, como sempre.
FaltaParaLureDaPrimeiraVoltaMs(timeIndex) {
    global TankJaCastou, InicioDaFaseTick
    timeIndex := Integer(timeIndex)
    ; Primeira volta: o lure do plano. Depois dela, so o piso de conforto do
    ; config (tempo para chegar ao ponto e puxar); 0 = so o cooldown manda.
    piso := TankJaCastou[timeIndex]
        ? PisoDoConfigMs("Hoenn222_MinLureMs", timeIndex)
        : PlanejarVolta().Lures[timeIndex]
    falta := piso - (A_TickCount - InicioDaFaseTick)
    return falta > 0 ? falta : 0
}

; Quanto de CD o secundario ainda teria no seu cast se o combo comecasse agora.
; E o que permite avisar "nao viavel" sem nunca inventar cooldown disponivel.
CooldownPendenteDoSecundarioMs(timeIndex, offsetMs) {
    global ToleranciaDoSecundarioMs
    slot := SlotDoPokemon(timeIndex, true)
    agora := A_TickCount
    cd := LerCooldownRestanteMs(slot, agora)
    taxa := LerTaxaDeRecuperacao(slot)
    restante := cd - (offsetMs * taxa)
    if (restante < 0)
        restante := 0
    ; entre o inicio do combo e a chamada o secundario segue dentro da Ball
    emT1 := restante - SleepAfterTankCombo * taxa
    if (emT1 < 0)
        emT1 := 0
    pendente := emT1 - Max(0, SleepAfterSwitch - Hoenn222_ExitLatencySecondaryMs) + Hoenn222_MarginMs
    return pendente > 0 ? pendente : 0
}

; Quem esta segurando o verde: "secundario", "tank" ou "" quando ja esta viavel.
; E diagnostico: nao altera nenhum alvo, so diz ao jogador o que falta.
QuemBloqueiaOCombo(timeIndex) {
    global ToleranciaDoSecundarioMs
    secSlot := SlotDoPokemon(timeIndex, true)
    cdSec := LerCooldownRestanteMs(secSlot, A_TickCount)
    if (cdSec > ToleranciaDoSecundarioMs)
        return "secundario"
    if (MsAteCastSeguro(SlotDoPokemon(timeIndex, false), A_TickCount) > 0)
        return "tank"
    if (FaltaParaLureDaPrimeiraVoltaMs(timeIndex) > 0)
        return "primeira_volta"
    return ""
}

; TROCAR TIME: quanto tempo depois do CAST da dupla a troca pode acontecer. E
; sempre uma DURACAO a partir do inicio do estado, nunca um instante absoluto.
; A janela planejada comeca na troca de time (o tank sai) e o lure acontece
; ANTES do cast; este estado comeca no cast. Da troca ate o cast ja passou o
; lure, entao o que falta da janela e P + tempo do secundario fora. Usar a
; janela inteira contava o lure duas vezes e atrasava o verde da troca.
DuracaoDoTrocarTimeMs(timeIndex) {
    plano := PlanejarVolta()
    return plano.Janelas[timeIndex] - plano.Lures[timeIndex]
}

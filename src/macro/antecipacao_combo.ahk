#Requires AutoHotkey v2.0
; Botao de combo 2-2-2: normal, antecipado (armado) e emergencia.

; --- BOTAO DE COMBO 2-2-2: NORMAL, ANTECIPADO E EMERGENCIA ---
;   1a pressao com o contador verde -> combo normal, imediato.
;   1a pressao antes do verde      -> o pedido fica armado e o macro executa
;                                     sozinho assim que o contador ficar verde.
;   2a pressao dentro da janela    -> emergencia: ignora o contador e executa.
SolicitarComboHoenn222() {
    global TimeAtual, isRodizioAtivo, Hoenn222_EmergencyWindowMs
    global Hoenn222_ComboArmed, Hoenn222_ComboArmedTeam, Hoenn222_ComboLastPressTick

    pressTick := A_TickCount
    intervaloMs := (Hoenn222_ComboLastPressTick > 0) ? pressTick - Hoenn222_ComboLastPressTick : -1
    Hoenn222_ComboLastPressTick := pressTick
    emergencia := (intervaloMs >= 0 && intervaloMs <= Hoenn222_EmergencyWindowMs)

    ; Em caso de falha de calculo vale o comportamento antigo: executar.
    faltandoMs := 0
    try {
        faltandoMs := GetHoenn222PendingMs()
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=combo_readiness", e)
    }

    SwitchDebug("COMBO_REQUEST", "team=" TimeAtual " gap_ms=" intervaloMs " missing_ms=" faltandoMs
        " emergency=" emergencia " armed=" (Hoenn222_ComboArmed ? 1 : 0))

    if (isRodizioAtivo) {
        SwitchDebug("COMBO_RESULT", "result=ignored reason=combo_running")
        return
    }
    if (emergencia) {
        SwitchDebug("COMBO_RESULT", "result=emergency")
        ComboComplexoHoenn222("emergencia")
        return
    }
    if (faltandoMs <= 0) {
        SwitchDebug("COMBO_RESULT", "result=immediate")
        ComboComplexoHoenn222("manual")
        return
    }

    ; Pedido antes do verde: o macro arma e espera o instante certo, e registra
    ; quem esta segurando e o quanto o secundario ficaria atrasado no seu cast.
    bloqueio := GetHoenn222ComboBloqueio(TimeAtual)
    SwitchDebug("CD_ANTECIPACAO", "time=" TimeAtual " bloqueio=" bloqueio
        " falta_ms=" Round(faltandoMs) " sec_cast_ms=" Hoenn222SecondaryPendenteMs(TimeAtual, 0))

    ; Antecipado: um pedido por vez, sempre preso ao time em que foi feito.
    previousCritical := A_IsCritical
    Critical("On")
    try {
        Hoenn222_ComboArmed := true
        Hoenn222_ComboArmedTeam := TimeAtual
    } finally {
        Critical(previousCritical)
    }
    SwitchDebug("COMBO_ARMED", "team=" Hoenn222_ComboArmedTeam " missing_ms=" faltandoMs)
}

; Chamado pelo laco de 30 ms. Dispara o pedido armado assim que o contador fica
; verde, sem pressionar o botao de novo.
ProcessarComboArmadoHoenn222() {
    global ModoAtual, TimeAtual, isRodizioAtivo
    global Hoenn222_ComboArmed, Hoenn222_ComboArmedTeam, Hoenn222_ComboFirePending

    if (!Hoenn222_ComboArmed)
        return

    ; O pedido vale para um unico modo e um unico time.
    if (ModoAtual != "Hoenn222" || TimeAtual != Hoenn222_ComboArmedTeam) {
        CancelarComboArmadoHoenn222("context_changed")
        return
    }
    if (isRodizioAtivo) {
        CancelarComboArmadoHoenn222("combo_running")
        return
    }

    ; Sem confianca no calculo, o pedido continua esperando em vez de disparar.
    faltandoMs := 1
    try {
        faltandoMs := GetHoenn222PendingMs()
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=combo_readiness", e)
    }
    if (faltandoMs > 0)
        return

    if (Hoenn222_ComboFirePending)
        return
    Hoenn222_ComboFirePending := true
    SwitchDebug("COMBO_FIRED", "team=" TimeAtual " reason=armed")
    ; NUNCA usar Critical nem executar o combo nesta thread: ela e o laco de 30 ms.
    ; Critical on/off aqui deixa a thread interrompivel e a acao longa sobe POR CIMA
    ; do laco, que nao reinicia enquanto ela dorme (movimento, botoes e quadrado
    ; congelavam durante o combo inteiro). Uma thread descartavel faz o trabalho.
    SetTimer(DispararComboArmadoHoenn222, -1)
}

; Thread descartavel do disparo automatico do combo. ComboComplexoHoenn222 consome
; o pedido junto com a trava.
DispararComboArmadoHoenn222() {
    global Hoenn222_ComboFirePending
    try {
        ComboComplexoHoenn222("antecipado")
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=combo_fire", e)
    } finally {
        Hoenn222_ComboFirePending := false
    }
}

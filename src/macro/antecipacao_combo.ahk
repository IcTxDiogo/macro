#Requires AutoHotkey v2.0
; Botao de combo 2-2-2: normal, antecipado (armado) e emergencia.

; --- BOTAO DE COMBO 2-2-2: NORMAL, ANTECIPADO E EMERGENCIA ---
;   1a pressao com o contador verde -> combo normal, imediato.
;   1a pressao antes do verde      -> o pedido fica armado e o macro executa
;                                     sozinho assim que o contador ficar verde.
;   2a pressao dentro da janela    -> emergencia: ignora o contador e executa.
PedirCombo() {
    global TimeAtual, RodizioAtivo, Hoenn222_EmergencyWindowMs
    global ComboArmado, TimeDoComboArmado, UltimoCliqueComboTick

    pressTick := A_TickCount
    intervaloMs := (UltimoCliqueComboTick > 0) ? pressTick - UltimoCliqueComboTick : -1
    UltimoCliqueComboTick := pressTick
    emergencia := (intervaloMs >= 0 && intervaloMs <= Hoenn222_EmergencyWindowMs)

    ; Em caso de falha de calculo vale o comportamento antigo: executar.
    faltandoMs := 0
    try {
        faltandoMs := FaltaParaVerdeMs()
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=combo_readiness", e)
    }

    LogDiagnostico("COMBO_REQUEST", "team=" TimeAtual " gap_ms=" intervaloMs " missing_ms=" faltandoMs
        " emergency=" emergencia " armed=" (ComboArmado ? 1 : 0))

    if (RodizioAtivo) {
        LogDiagnostico("COMBO_RESULT", "result=ignored reason=combo_running")
        return
    }
    if (emergencia) {
        LogDiagnostico("COMBO_RESULT", "result=emergency")
        IniciarRodizio222("emergencia")
        return
    }
    if (faltandoMs <= 0) {
        LogDiagnostico("COMBO_RESULT", "result=immediate")
        IniciarRodizio222("manual")
        return
    }

    ; Pedido antes do verde: o macro arma e espera o instante certo, e registra
    ; quem esta segurando e o quanto o secundario ficaria atrasado no seu cast.
    bloqueio := QuemBloqueiaOCombo(TimeAtual)
    LogDiagnostico("CD_ANTECIPACAO", "time=" TimeAtual " bloqueio=" bloqueio
        " falta_ms=" Round(faltandoMs) " sec_cast_ms=" CooldownPendenteDoSecundarioMs(TimeAtual, 0))

    ; Antecipado: um pedido por vez, sempre preso ao time em que foi feito.
    previousCritical := A_IsCritical
    Critical("On")
    try {
        ComboArmado := true
        TimeDoComboArmado := TimeAtual
    } finally {
        Critical(previousCritical)
    }
    LogDiagnostico("COMBO_ARMED", "team=" TimeDoComboArmado " missing_ms=" faltandoMs)
}

; Chamado pelo laco de 30 ms. Dispara o pedido armado assim que o contador fica
; verde, sem pressionar o botao de novo.
VerificarComboArmado() {
    global ModoAtual, TimeAtual, RodizioAtivo
    global ComboArmado, TimeDoComboArmado, DisparoDoComboPendente

    if (!ComboArmado)
        return

    ; O pedido vale para um unico modo e um unico time.
    if (ModoAtual != "Hoenn222" || TimeAtual != TimeDoComboArmado) {
        CancelarPedidosArmados("context_changed")
        return
    }
    if (RodizioAtivo) {
        CancelarPedidosArmados("combo_running")
        return
    }

    ; Sem confianca no calculo, o pedido continua esperando em vez de disparar.
    faltandoMs := 1
    try {
        faltandoMs := FaltaParaVerdeMs()
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=combo_readiness", e)
    }
    if (faltandoMs > 0)
        return

    if (DisparoDoComboPendente)
        return
    DisparoDoComboPendente := true
    LogDiagnostico("COMBO_FIRED", "team=" TimeAtual " reason=armed")
    ; NUNCA usar Critical nem executar o combo nesta thread: ela e o laco de 30 ms.
    ; Critical on/off aqui deixa a thread interrompivel e a acao longa sobe POR CIMA
    ; do laco, que nao reinicia enquanto ela dorme (movimento, botoes e quadrado
    ; congelavam durante o combo inteiro). Uma thread descartavel faz o trabalho.
    SetTimer(DispararComboArmado, -1)
}

; Thread descartavel do disparo automatico do combo. IniciarRodizio222 consome
; o pedido junto com a trava.
DispararComboArmado() {
    global DisparoDoComboPendente
    try {
        IniciarRodizio222("antecipado")
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=combo_fire", e)
    } finally {
        DisparoDoComboPendente := false
    }
}

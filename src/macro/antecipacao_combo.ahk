#Requires AutoHotkey v2.0
; Botao de combo 2-2-2: normal, antecipado (armado) e emergencia.

; Clique no botao de combo.
;   1o clique com o contador verde        -> combo na hora.
;   1o clique antes do verde              -> arma o pedido; o macro executa sozinho no verde.
;   2o clique dentro da janela (400 ms)   -> emergencia: ignora o contador e executa.
PedirCombo() {
    global TimeAtual, RodizioAtivo, ComboArmado, TimeDoComboArmado, UltimoCliqueComboTick
    global Hoenn222_EmergencyWindowMs

    cliqueTick := A_TickCount
    intervaloMs := (UltimoCliqueComboTick > 0) ? cliqueTick - UltimoCliqueComboTick : -1
    UltimoCliqueComboTick := cliqueTick
    emergencia := (intervaloMs >= 0 && intervaloMs <= Hoenn222_EmergencyWindowMs)

    ; Falha de calculo: vale o comportamento antigo (executar).
    faltaMs := 0
    try {
        faltaMs := FaltaParaVerdeMs()
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=combo_readiness", e)
    }

    LogDiagnostico("COMBO_REQUEST", "team=" TimeAtual " gap_ms=" intervaloMs " missing_ms=" faltaMs
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
    if (faltaMs <= 0) {
        LogDiagnostico("COMBO_RESULT", "result=immediate")
        IniciarRodizio222("manual")
        return
    }

    ; Antes do verde: arma e registra quem segura e quanto o secundario atrasaria.
    LogDiagnostico("CD_ANTECIPACAO", "time=" TimeAtual " bloqueio=" QuemBloqueiaOCombo(TimeAtual)
        " falta_ms=" Round(faltaMs) " sec_cast_ms=" CooldownPendenteDoSecundarioMs(TimeAtual, 0))

    ; Um pedido por vez, sempre preso ao time em que foi feito.
    criticoAnterior := A_IsCritical
    Critical("On")
    try {
        ComboArmado := true
        TimeDoComboArmado := TimeAtual
    } finally {
        Critical(criticoAnterior)
    }
    LogDiagnostico("COMBO_ARMED", "team=" TimeDoComboArmado " missing_ms=" faltaMs)
}

; Chamado pelo laco de 30 ms. Dispara o pedido armado quando o contador fica verde.
; NUNCA usar Critical nem executar o combo nesta thread: ela e o laco de movimento.
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
    faltaMs := 1
    try {
        faltaMs := FaltaParaVerdeMs()
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=combo_readiness", e)
    }
    if (faltaMs > 0 || DisparoDoComboPendente)
        return

    DisparoDoComboPendente := true
    LogDiagnostico("COMBO_FIRED", "team=" TimeAtual " reason=armed")
    ; Thread descartavel: o combo sobe por cima do laco se rodar aqui, e o movimento congela.
    timeDoPedido := TimeDoComboArmado
    idDoPedido := IdDaExecucao
    SetTimer(() => DispararComboArmado(timeDoPedido, idDoPedido), -1)
}

; Thread descartavel do disparo automatico. IniciarRodizio222 consome o pedido junto com a trava.
DispararComboArmado(timeDoPedido, idDoPedido) {
    global DisparoDoComboPendente
    try {
        IniciarRodizio222("antecipado", timeDoPedido, idDoPedido)
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=combo_fire", e)
    } finally {
        DisparoDoComboPendente := false
    }
}

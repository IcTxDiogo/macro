#Requires AutoHotkey v2.0
; Gatilho de troca de time 2-2-2: normal, antecipado (armado) e emergencia.

; Clique no gatilho (LT/RT ou botao lateral 2 do mouse). O verde e o da fase TROCAR TIME.
;   TROCAR TIME verde                 -> troca na hora.
;   TROCAR TIME amarelo               -> arma; troca sozinho no verde.
;   COMBAR (combo ainda nao feito)    -> arma; so troca depois do combo e do verde da troca.
;   2o clique dentro da janela        -> emergencia: troca na hora, em qualquer fase.
;   Aguardando sincronizacao          -> troca na hora (nao existe ciclo para esperar).
; Falha de calculo nunca prende a troca: vale o comportamento antigo (trocar).
PedirTrocaDeTime(origem := "direct") {
    global TimeAtual, FaseAtual, Hoenn222_EmergencyWindowMs
    global TrocaArmada, TimeDaTrocaArmada, UltimoCliqueTrocaTick

    cliqueTick := A_TickCount
    intervaloMs := (UltimoCliqueTrocaTick > 0) ? cliqueTick - UltimoCliqueTrocaTick : -1
    UltimoCliqueTrocaTick := cliqueTick
    emergencia := (intervaloMs >= 0 && intervaloMs <= Hoenn222_EmergencyWindowMs)

    fase := FaseAtual
    faltaMs := 0
    if (fase == "WAITING_TEAM_SWITCH") {
        try {
            faltaMs := FaltaParaVerdeMs()
        } catch as e {
            LogDiagnostico("SWITCH_ERROR", "phase=switch_readiness", e)
        }
    } else if (fase == "WAITING_COMBO") {
        ; O proximo movimento desta dupla ainda e o combo: nao ha verde de troca.
        faltaMs := 1
    }
    faltaTexto := (fase == "WAITING_COMBO") ? "combo_first" : Round(faltaMs)

    LogDiagnostico("SWITCH_REQUEST", "source=" origem " team=" TimeAtual " state=" fase
        " gap_ms=" intervaloMs " missing_ms=" faltaTexto
        " emergency=" emergencia " armed=" (TrocaArmada ? 1 : 0))

    if (emergencia || faltaMs <= 0) {
        if (TrocaArmada) {
            ; O pedido pendente e consumido por esta troca; nao pode disparar outra depois.
            TrocaArmada := false
            TimeDaTrocaArmada := 0
            LogDiagnostico("SWITCH_DISARMED", "reason=pressed_again")
        }
        LogDiagnostico("SWITCH_RESULT", "result=" (emergencia ? "emergency" : "immediate"))
        ExecutarTrocaDeTime(origem)
        return
    }

    if (TrocaArmada) {
        LogDiagnostico("SWITCH_RESULT", "result=already_armed team=" TimeDaTrocaArmada)
        return
    }
    criticoAnterior := A_IsCritical
    Critical("On")
    try {
        TrocaArmada := true
        TimeDaTrocaArmada := TimeAtual
    } finally {
        Critical(criticoAnterior)
    }
    LogDiagnostico("SWITCH_ARMED", "team=" TimeDaTrocaArmada " state=" fase " missing_ms=" faltaTexto)
}

; Sequencia de sempre do gatilho em 2-2-2: troca, espera, Pokestop, pocao.
; `timeEsperado` > 0 so no disparo automatico: nunca troca fora do time em que o pedido foi feito.
ExecutarTrocaDeTime(origem := "direct", timeEsperado := 0) {
    global TimeAtual, ModoAtual, GameWindow, KeyPokestop
    if (timeEsperado > 0 && (TimeAtual != timeEsperado || ModoAtual != "Hoenn222")) {
        LogDiagnostico("SWITCH_REJECTED", "reason=armed_context_changed expected=" timeEsperado " current=" TimeAtual)
        return
    }
    if (TrocarDeTime(3)) {
        Sleep(SleepAfterSwitch)
        ControlSend("{" KeyPokestop "}", , GameWindow)
        UsarPocao()
    }
}

; Chamado pelo laco de 30 ms. Troca sozinho quando TROCAR TIME fica verde.
VerificarTrocaArmada() {
    global ModoAtual, TimeAtual, FaseAtual
    global TrocaArmada, TimeDaTrocaArmada, DisparoDaTrocaPendente

    if (!TrocaArmada)
        return
    if (ModoAtual != "Hoenn222" || TimeAtual != TimeDaTrocaArmada) {
        CancelarPedidosArmados("context_changed")
        return
    }
    ; Ainda na fase do combo: o pedido espera o combo e depois o verde da troca.
    if (FaseAtual != "WAITING_TEAM_SWITCH")
        return

    ; Sem confianca no calculo, o pedido continua esperando em vez de disparar.
    faltaMs := 1
    try {
        faltaMs := FaltaParaVerdeMs()
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=switch_readiness", e)
    }
    if (faltaMs > 0 || DisparoDaTrocaPendente)
        return

    DisparoDaTrocaPendente := true
    ; Mesma regra do combo: nada de Critical aqui (e o laco de 30 ms).
    SetTimer(DispararTrocaArmada, -1)
}

; Thread descartavel do disparo automatico: consome o pedido sob Critical (aqui pode, e uma
; thread curta propria) e executa a sequencia de sempre.
DispararTrocaArmada() {
    global TrocaArmada, TimeDaTrocaArmada, DisparoDaTrocaPendente
    timeDoPedido := 0
    try {
        criticoAnterior := A_IsCritical
        Critical("On")
        try {
            if (!TrocaArmada)
                return
            timeDoPedido := TimeDaTrocaArmada
            TrocaArmada := false
            TimeDaTrocaArmada := 0
        } finally {
            Critical(criticoAnterior)
        }
        LogDiagnostico("SWITCH_FIRED", "team=" timeDoPedido " reason=armed")
        ExecutarTrocaDeTime("antecipado", timeDoPedido)
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=armed_switch", e)
    } finally {
        DisparoDaTrocaPendente := false
    }
}

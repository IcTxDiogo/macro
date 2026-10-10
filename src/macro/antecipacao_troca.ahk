#Requires AutoHotkey v2.0
; Gatilho de troca de time 2-2-2: normal, antecipado (armado) e emergencia.

; --- GATILHO DE TROCA DE TIME 2-2-2: NORMAL, ANTECIPADO E EMERGENCIA ---
; Mesma regra do combo; o verde da troca e o do estado TROCAR TIME:
;   TROCAR TIME ja verde           -> troca na hora.
;   TROCAR TIME ainda amarelo      -> arma; troca sozinho no instante do verde.
;   COMBAR (combo ainda nao feito) -> arma; so troca depois do combo desta dupla
;                                     e do verde de TROCAR TIME.
;   2a pressao dentro da janela    -> emergencia: troca na hora, em qualquer fase.
;   Aguardando sincronizacao       -> troca na hora (nao existe ciclo para esperar).
; Falha de calculo nunca prende a troca: vale o comportamento antigo (trocar).
PedirTrocaDeTime(source := "direct") {
    global TimeAtual, FaseAtual, Hoenn222_EmergencyWindowMs
    global TrocaArmada, TimeDaTrocaArmada, UltimoCliqueTrocaTick

    pressTick := A_TickCount
    intervaloMs := (UltimoCliqueTrocaTick > 0) ? pressTick - UltimoCliqueTrocaTick : -1
    UltimoCliqueTrocaTick := pressTick
    emergencia := (intervaloMs >= 0 && intervaloMs <= Hoenn222_EmergencyWindowMs)

    estado := FaseAtual
    faltandoMs := 0
    if (estado == "WAITING_TEAM_SWITCH") {
        try {
            faltandoMs := FaltaParaVerdeMs()
        } catch as e {
            LogDiagnostico("SWITCH_ERROR", "phase=switch_readiness", e)
        }
    } else if (estado == "WAITING_COMBO") {
        ; O proximo movimento desta dupla ainda e o combo: nao ha verde de troca.
        faltandoMs := 1
    }

    LogDiagnostico("SWITCH_REQUEST", "source=" source " team=" TimeAtual " state=" estado
        " gap_ms=" intervaloMs " missing_ms=" (estado == "WAITING_COMBO" ? "combo_first" : Round(faltandoMs))
        " emergency=" emergencia " armed=" (TrocaArmada ? 1 : 0))

    if (emergencia || faltandoMs <= 0) {
        if (TrocaArmada) {
            ; O pedido pendente e consumido por esta troca; nao pode disparar outra depois.
            TrocaArmada := false
            TimeDaTrocaArmada := 0
            LogDiagnostico("SWITCH_DISARMED", "reason=pressed_again")
        }
        LogDiagnostico("SWITCH_RESULT", "result=" (emergencia ? "emergency" : "immediate"))
        ExecutarTrocaDeTime(source)
        return
    }

    if (TrocaArmada) {
        LogDiagnostico("SWITCH_RESULT", "result=already_armed team=" TimeDaTrocaArmada)
        return
    }
    previousCritical := A_IsCritical
    Critical("On")
    try {
        TrocaArmada := true
        TimeDaTrocaArmada := TimeAtual
    } finally {
        Critical(previousCritical)
    }
    LogDiagnostico("SWITCH_ARMED", "team=" TimeDaTrocaArmada " state=" estado
        " missing_ms=" (estado == "WAITING_COMBO" ? "combo_first" : Round(faltandoMs)))
}

; Sequencia de sempre do gatilho em 2-2-2: troca, espera, Pokestop, pocao.
; `expectedTeam` > 0 so no disparo automatico: nunca troca fora do time em que
; o pedido foi feito.
ExecutarTrocaDeTime(source := "direct", expectedTeam := 0) {
    global TimeAtual, ModoAtual, GameWindow, KeyPokestop
    if (expectedTeam > 0 && (TimeAtual != expectedTeam || ModoAtual != "Hoenn222")) {
        LogDiagnostico("SWITCH_REJECTED", "reason=armed_context_changed expected=" expectedTeam " current=" TimeAtual)
        return
    }
    if (TrocarDeTime(3)) {
        Sleep(SleepAfterSwitch)
        ControlSend("{" KeyPokestop "}", , GameWindow)
        UsarPocao()
    }
}

; Thread descartavel do disparo automatico da troca: consome o pedido sob Critical
; (aqui pode, e uma thread curta propria) e executa a sequencia de sempre.
DispararTrocaArmada() {
    global TrocaArmada, TimeDaTrocaArmada, DisparoDaTrocaPendente
    equipe := 0
    try {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if (!TrocaArmada)
                return
            equipe := TimeDaTrocaArmada
            TrocaArmada := false
            TimeDaTrocaArmada := 0
        } finally {
            Critical(previousCritical)
        }
        LogDiagnostico("SWITCH_FIRED", "team=" equipe " reason=armed")
        ExecutarTrocaDeTime("antecipado", equipe)
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=armed_switch", e)
    } finally {
        DisparoDaTrocaPendente := false
    }
}

; Chamado pelo laco de 30 ms. Troca sozinho quando o contador de TROCAR TIME
; fica verde, sem pressionar o gatilho de novo.
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
    faltandoMs := 1
    try {
        faltandoMs := FaltaParaVerdeMs()
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=switch_readiness", e)
    }
    if (faltandoMs > 0)
        return

    if (DisparoDaTrocaPendente)
        return
    DisparoDaTrocaPendente := true
    ; Mesma regra do combo: este e o laco de 30 ms, nada de Critical aqui. O consumo
    ; do pedido acontece na thread descartavel.
    SetTimer(DispararTrocaArmada, -1)
}

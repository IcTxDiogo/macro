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
SolicitarTrocaHoenn222(source := "direct") {
    global TimeAtual, Hoenn222_State, Hoenn222_EmergencyWindowMs
    global Hoenn222_SwitchArmed, Hoenn222_SwitchArmedTeam, Hoenn222_SwitchLastPressTick

    pressTick := A_TickCount
    intervaloMs := (Hoenn222_SwitchLastPressTick > 0) ? pressTick - Hoenn222_SwitchLastPressTick : -1
    Hoenn222_SwitchLastPressTick := pressTick
    emergencia := (intervaloMs >= 0 && intervaloMs <= Hoenn222_EmergencyWindowMs)

    estado := Hoenn222_State
    faltandoMs := 0
    if (estado == "WAITING_TEAM_SWITCH") {
        try {
            faltandoMs := GetHoenn222PendingMs()
        } catch as e {
            SwitchDebug("SWITCH_ERROR", "phase=switch_readiness", e)
        }
    } else if (estado == "WAITING_COMBO") {
        ; O proximo movimento desta dupla ainda e o combo: nao ha verde de troca.
        faltandoMs := 1
    }

    SwitchDebug("SWITCH_REQUEST", "source=" source " team=" TimeAtual " state=" estado
        " gap_ms=" intervaloMs " missing_ms=" (estado == "WAITING_COMBO" ? "combo_first" : Round(faltandoMs))
        " emergency=" emergencia " armed=" (Hoenn222_SwitchArmed ? 1 : 0))

    if (emergencia || faltandoMs <= 0) {
        if (Hoenn222_SwitchArmed) {
            ; O pedido pendente e consumido por esta troca; nao pode disparar outra depois.
            Hoenn222_SwitchArmed := false
            Hoenn222_SwitchArmedTeam := 0
            SwitchDebug("SWITCH_DISARMED", "reason=pressed_again")
        }
        SwitchDebug("SWITCH_RESULT", "result=" (emergencia ? "emergency" : "immediate"))
        ExecutarTrocaHoenn222(source)
        return
    }

    if (Hoenn222_SwitchArmed) {
        SwitchDebug("SWITCH_RESULT", "result=already_armed team=" Hoenn222_SwitchArmedTeam)
        return
    }
    previousCritical := A_IsCritical
    Critical("On")
    try {
        Hoenn222_SwitchArmed := true
        Hoenn222_SwitchArmedTeam := TimeAtual
    } finally {
        Critical(previousCritical)
    }
    SwitchDebug("SWITCH_ARMED", "team=" Hoenn222_SwitchArmedTeam " state=" estado
        " missing_ms=" (estado == "WAITING_COMBO" ? "combo_first" : Round(faltandoMs)))
}

; Sequencia de sempre do gatilho em 2-2-2: troca, espera, Pokestop, pocao.
; `expectedTeam` > 0 so no disparo automatico: nunca troca fora do time em que
; o pedido foi feito.
ExecutarTrocaHoenn222(source := "direct", expectedTeam := 0) {
    global TimeAtual, ModoAtual, GameWindow, KeyPokestop
    if (expectedTeam > 0 && (TimeAtual != expectedTeam || ModoAtual != "Hoenn222")) {
        SwitchDebug("SWITCH_REJECTED", "reason=armed_context_changed expected=" expectedTeam " current=" TimeAtual)
        return
    }
    if (TrocarTimeHoenn(3)) {
        Sleep(SleepAfterSwitch)
        ControlSend("{" KeyPokestop "}", , GameWindow)
        Potion()
    }
}

; Thread descartavel do disparo automatico da troca: consome o pedido sob Critical
; (aqui pode, e uma thread curta propria) e executa a sequencia de sempre.
DispararTrocaArmadaHoenn222() {
    global Hoenn222_SwitchArmed, Hoenn222_SwitchArmedTeam, Hoenn222_SwitchFirePending
    equipe := 0
    try {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            if (!Hoenn222_SwitchArmed)
                return
            equipe := Hoenn222_SwitchArmedTeam
            Hoenn222_SwitchArmed := false
            Hoenn222_SwitchArmedTeam := 0
        } finally {
            Critical(previousCritical)
        }
        SwitchDebug("SWITCH_FIRED", "team=" equipe " reason=armed")
        ExecutarTrocaHoenn222("antecipado", equipe)
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=armed_switch", e)
    } finally {
        Hoenn222_SwitchFirePending := false
    }
}

; Chamado pelo laco de 30 ms. Troca sozinho quando o contador de TROCAR TIME
; fica verde, sem pressionar o gatilho de novo.
ProcessarTrocaArmadaHoenn222() {
    global ModoAtual, TimeAtual, Hoenn222_State
    global Hoenn222_SwitchArmed, Hoenn222_SwitchArmedTeam, Hoenn222_SwitchFirePending

    if (!Hoenn222_SwitchArmed)
        return
    if (ModoAtual != "Hoenn222" || TimeAtual != Hoenn222_SwitchArmedTeam) {
        CancelarComboArmadoHoenn222("context_changed")
        return
    }
    ; Ainda na fase do combo: o pedido espera o combo e depois o verde da troca.
    if (Hoenn222_State != "WAITING_TEAM_SWITCH")
        return

    ; Sem confianca no calculo, o pedido continua esperando em vez de disparar.
    faltandoMs := 1
    try {
        faltandoMs := GetHoenn222PendingMs()
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=switch_readiness", e)
    }
    if (faltandoMs > 0)
        return

    if (Hoenn222_SwitchFirePending)
        return
    Hoenn222_SwitchFirePending := true
    ; Mesma regra do combo: este e o laco de 30 ms, nada de Critical aqui. O consumo
    ; do pedido acontece na thread descartavel.
    SetTimer(DispararTrocaArmadaHoenn222, -1)
}

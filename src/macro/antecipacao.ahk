#Requires AutoHotkey v2.0
; Cancelamento comum dos pedidos armados (combo e troca).

; Descarta um pedido pendente apos troca de time, ressincronizacao ou mudanca de
; modo. Nada aqui altera o cronometro nem a rotacao.
CancelarPedidosArmados(reason := "") {
    global ComboArmado, TimeDoComboArmado
    global TrocaArmada, TimeDaTrocaArmada
    motivo := (reason = "" ? "unspecified" : reason)
    ; A troca armada morre junto: troca de time, F8 e mudanca de modo valem para os dois.
    if (TrocaArmada) {
        TrocaArmada := false
        TimeDaTrocaArmada := 0
        LogDiagnostico("SWITCH_DISARMED", "reason=" motivo)
    }
    if (!ComboArmado)
        return
    ComboArmado := false
    TimeDoComboArmado := 0
    LogDiagnostico("COMBO_DISARMED", "reason=" motivo)
}

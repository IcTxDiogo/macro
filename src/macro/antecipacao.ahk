#Requires AutoHotkey v2.0
; Cancelamento comum dos pedidos armados (combo e troca).

; Descarta os pedidos pendentes (troca de time, F8, troca de modo, contexto invalido).
; Nao altera cronometro nem rotacao.
CancelarPedidosArmados(motivo := "") {
    global ComboArmado, TimeDoComboArmado, TrocaArmada, TimeDaTrocaArmada
    motivo := (motivo = "" ? "unspecified" : motivo)
    if (TrocaArmada) {
        TrocaArmada := false
        TimeDaTrocaArmada := 0
        LogDiagnostico("SWITCH_DISARMED", "reason=" motivo)
    }
    if (ComboArmado) {
        ComboArmado := false
        TimeDoComboArmado := 0
        LogDiagnostico("COMBO_DISARMED", "reason=" motivo)
    }
}

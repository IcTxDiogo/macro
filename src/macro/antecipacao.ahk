#Requires AutoHotkey v2.0
; Cancelamento comum dos pedidos armados (combo e troca).

; Descarta um pedido pendente apos troca de time, ressincronizacao ou mudanca de
; modo. Nada aqui altera o cronometro nem a rotacao.
CancelarComboArmadoHoenn222(reason := "") {
    global Hoenn222_ComboArmed, Hoenn222_ComboArmedTeam
    global Hoenn222_SwitchArmed, Hoenn222_SwitchArmedTeam
    motivo := (reason = "" ? "unspecified" : reason)
    ; A troca armada morre junto: troca de time, F8 e mudanca de modo valem para os dois.
    if (Hoenn222_SwitchArmed) {
        Hoenn222_SwitchArmed := false
        Hoenn222_SwitchArmedTeam := 0
        SwitchDebug("SWITCH_DISARMED", "reason=" motivo)
    }
    if (!Hoenn222_ComboArmed)
        return
    Hoenn222_ComboArmed := false
    Hoenn222_ComboArmedTeam := 0
    SwitchDebug("COMBO_DISARMED", "reason=" motivo)
}

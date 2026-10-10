#Requires AutoHotkey v2.0
; Modos do macro (Normal, Hoenn 3-3, Hoenn 2-2-2) e ressincronizacao do 2-2-2.

TrocarModo() {
    global ModoAtual, StatusText, Hoenn222_State, TimeAtual
    ; Sair do 2-2-2 nunca deixa um pedido de combo pendente no modo seguinte.
    CancelarComboArmadoHoenn222("mode_change")
    if (ModoAtual == "Normal") {
        ModoAtual := "Hoenn33"
        StatusText := "Modo: Hoenn 3-3 - Time: " TimeAtual
    } else if (ModoAtual == "Hoenn33") {
        ModoAtual := "Hoenn222"
        StatusText := "Modo: Hoenn 2-2-2 - Time: " TimeAtual
        ResincronizarHoenn222()
    } else {
        ModoAtual := "Normal"
        StatusText := "Modo: Normal"
        AtualizarHoenn222CentralTooltip() ; Limpa o tooltip central ao sair do modo Hoenn 2-2-2
    }
}

; F8: volta ao inicio do ciclo (sem informacao do jogo, os seis comecam prontos).
ResincronizarHoenn222() {
    global Hoenn222_State, ModoAtual, TimeAtual
    global Hoenn222_StateStartTick, Hoenn222_LastComboStartTick, Hoenn222_P2CallTick, Hoenn222_TankEnterTick
    global Hoenn222_ExecutionId

    if (ModoAtual == "Hoenn222") {
        CancelarComboArmadoHoenn222("resync")
        Hoenn222_State := "WAITING_FIRST_COMBO"
        Hoenn222_StateStartTick := A_TickCount
        Hoenn222_LastComboStartTick := 0
        Hoenn222_P2CallTick := 0
        Hoenn222_TankEnterTick[TimeAtual] := 0
        Hoenn222_ExecutionId++ ; Invalida atualizações de interface de callbacks atrasados
        ResetarCooldownsHoenn222(A_TickCount) ; Sem informação do jogo: os seis prontos
    }
}

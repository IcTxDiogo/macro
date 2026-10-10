#Requires AutoHotkey v2.0
; Modos do macro (Normal, Hoenn 3-3, Hoenn 2-2-2) e ressincronizacao do 2-2-2.

TrocarModo() {
    global ModoAtual, TextoDeStatus, FaseAtual, TimeAtual
    ; Sair do 2-2-2 nunca deixa um pedido de combo pendente no modo seguinte.
    CancelarPedidosArmados("mode_change")
    if (ModoAtual == "Normal") {
        ModoAtual := "Hoenn33"
        TextoDeStatus := "Modo: Hoenn 3-3 - Time: " TimeAtual
    } else if (ModoAtual == "Hoenn33") {
        ModoAtual := "Hoenn222"
        TextoDeStatus := "Modo: Hoenn 2-2-2 - Time: " TimeAtual
        Resincronizar()
    } else {
        ModoAtual := "Normal"
        TextoDeStatus := "Modo: Normal"
        DesenharQuadradoCentral() ; Limpa o tooltip central ao sair do modo Hoenn 2-2-2
    }
}

; F8: volta ao inicio do ciclo (sem informacao do jogo, os seis comecam prontos).
Resincronizar() {
    global FaseAtual, ModoAtual, TimeAtual
    global InicioDaFaseTick, UltimoComboTick, ChamadaDoSecundarioTick, EntradaDoTankTick
    global IdDaExecucao

    if (ModoAtual == "Hoenn222") {
        CancelarPedidosArmados("resync")
        FaseAtual := "WAITING_FIRST_COMBO"
        InicioDaFaseTick := A_TickCount
        UltimoComboTick := 0
        ChamadaDoSecundarioTick := 0
        EntradaDoTankTick[TimeAtual] := 0
        IdDaExecucao++ ; Invalida atualizações de interface de callbacks atrasados
        ResetarCooldowns(A_TickCount) ; Sem informação do jogo: os seis prontos
    }
}

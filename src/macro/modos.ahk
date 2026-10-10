#Requires AutoHotkey v2.0
; Modos do macro (Normal e Hoenn 2-2-2) e ressincronizacao do 2-2-2.

; F12 / botao Back: alterna Normal <-> Hoenn 2-2-2. Sair do 2-2-2 nunca deixa pedido armado.
TrocarModo() {
    global ModoAtual, TextoDeStatus, TimeAtual
    CancelarPedidosArmados("mode_change")
    if (ModoAtual == "Normal") {
        ModoAtual := "Hoenn222"
        TextoDeStatus := "Modo: Hoenn 2-2-2 - Time: " TimeAtual
        Resincronizar()
    } else {
        ModoAtual := "Normal"
        TextoDeStatus := "Modo: Normal"
        DesenharQuadradoCentral() ; limpa o quadrado central ao sair do 2-2-2
    }
    SalvarEstado()
}

; F8: volta ao inicio do ciclo (sem informacao do jogo, os seis comecam prontos).
Resincronizar() {
    global FaseAtual, ModoAtual, InicioDaFaseTick, IdDaExecucao

    if (ModoAtual == "Hoenn222") {
        CancelarPedidosArmados("resync")
        FaseAtual := "WAITING_FIRST_COMBO"
        InicioDaFaseTick := A_TickCount
        IdDaExecucao++ ; invalida rodizios agendados antes do F8
        ResetarCooldowns(A_TickCount)
        SalvarEstado()
    }
}

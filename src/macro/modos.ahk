#Requires AutoHotkey v2.0
; Modos do macro (Normal, Hoenn 2-2-2 e Hoenn 1,5) e ressincronizacao dos modos Hoenn.
; O macro abre no modo StartMode do config.

; Os dois modos Hoenn tem rodizio, botao unico, pedidos armados e indicador.
ModoComRodizio() {
    return ModoAtual == "Hoenn222" || ModoAtual == "Hoenn15"
}

TextoDeStatusDoModo() {
    if (ModoAtual == "Hoenn15")
        return "Modo: Hoenn 1,5 - Time: " TimeAtual
    if (ModoAtual == "Hoenn222")
        return "Modo: Hoenn 2-2-2 - Time: " TimeAtual
    return "Modo: Normal"
}

; Agenda a proxima acao de combo do modo (no 1,5, a proxima parte).
IniciarRodizioDoModo(origem := "manual", timeEsperado := 0, idEsperado := -1) {
    if (ModoAtual == "Hoenn15")
        IniciarRodizio15(origem, timeEsperado, idEsperado)
    else
        IniciarRodizio222(origem, timeEsperado, idEsperado)
}

; F12 / botao Back: gira Normal -> Hoenn 2-2-2 -> Hoenn 1,5 -> Normal.
; Trocar de modo nunca deixa pedido armado e cada modo Hoenn comeca ressincronizado.
TrocarModo() {
    global ModoAtual, TextoDeStatus, TimeAtual
    CancelarPedidosArmados("mode_change")
    if (ModoAtual == "Normal") {
        ModoAtual := "Hoenn222"
        if (TimeAtual > TotalDeTimesDoModo())
            TimeAtual := 1
    } else if (ModoAtual == "Hoenn222") {
        ; Os times do 1,5 sao outros (trios): recomeca no time 1.
        ModoAtual := "Hoenn15"
        TimeAtual := 1
        try {
            ; Planejar aqui (thread do atalho), nunca na primeira volta do GameLoop.
            if Hoenn222_CdOptimizerEnabled
                PlanejarVolta15()
        } catch as e {
            LogDiagnostico("SWITCH_ERROR", "phase=plan_15", e)
        }
    } else {
        ModoAtual := "Normal"
        TextoDeStatus := TextoDeStatusDoModo()
        DesenharQuadradoCentral() ; limpa o quadrado central ao sair do modo Hoenn
        LogDiagnostico("MODO", "modo=Normal")
        return
    }
    TextoDeStatus := TextoDeStatusDoModo()
    LogDiagnostico("MODO", "modo=" ModoAtual " team=" TimeAtual)
    Resincronizar()
}

; F8: volta ao inicio do ciclo (sem informacao do jogo, todos comecam prontos).
Resincronizar() {
    global FaseAtual, ModoAtual, InicioDaFaseTick, IdDaExecucao

    if ModoComRodizio() {
        CancelarPedidosArmados("resync")
        FaseAtual := "WAITING_FIRST_COMBO"
        InicioDaFaseTick := A_TickCount
        IdDaExecucao++ ; invalida rodizios agendados antes do F8
        ResetarCooldowns(A_TickCount)
    }
}

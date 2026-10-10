#Requires AutoHotkey v2.0
; Controle (gamepad): laco de 30 ms que le o XInput, mapeia movimento e botoes e
; despacha as acoes de src\macro\acoes.ahk. Os atalhos de teclado estao no main.ahk.
;
; REGRA do laco: nunca usar Critical, Sleep nem executar acao longa direto aqui.
; Este laco roda a cada 30 ms e e a thread do movimento. Critical on/off deixa o
; laco interrompivel e a acao longa sobe por cima dele, congelando movimento e
; botoes ate acabar. Toda acao e agendada numa thread descartavel: SetTimer(fn, -1).

IniciarControle() {
    SetTimer(GameLoop, 30)
}

GameLoop() {
    static ultimoTick := 0
    ; Nenhum timer pode subir POR CIMA desta thread: se uma acao longa (combo,
    ; troca) a interrompesse, o laco ficaria preso embaixo dela e o AutoHotkey nao
    ; reinicia o timer enquanto a instancia antiga existe. As acoes agendadas com
    ; SetTimer(..., -1) comecam logo que esta volta termina.
    Thread("NoTimers")
    ; Diagnostico: registra quando o laco ficou parado (movimento congelado).
    agoraTick := A_TickCount
    if (ultimoTick > 0 && agoraTick - ultimoTick > 400)
        LogDiagnostico("LOOP_STALL", "gap_ms=" (agoraTick - ultimoTick) " state=" FaseAtual " rodizio=" RodizioAtivo)
    ultimoTick := agoraTick

    State := XInput_GetState(0)
    if !State {
        AtualizarInterface(false)
        return
    }

    isGameActive := WinExist(GameWindow)
    if (isGameActive)
        AtualizarMovimento(State)
    DespacharBotoes(State, isGameActive)
    VerificarPedidosArmados()
    AtualizarInterface()
}

; Analogico -> WASD. Cada tecla so e enviada quando o estado muda.
AtualizarMovimento(State) {
    static ativo := Map("w", false, "s", false, "a", false, "d", false)
    AplicarTeclaDeMovimento("w", State.sThumbLY > DeadzoneMove || State.sThumbRY > DeadzoneMove, ativo)
    AplicarTeclaDeMovimento("s", State.sThumbLY < -DeadzoneMove || State.sThumbRY < -DeadzoneMove, ativo)
    AplicarTeclaDeMovimento("a", State.sThumbLX < -DeadzoneMove || State.sThumbRX < -DeadzoneMove, ativo)
    AplicarTeclaDeMovimento("d", State.sThumbLX > DeadzoneMove || State.sThumbRX > DeadzoneMove, ativo)
}

AplicarTeclaDeMovimento(tecla, deveEstarAtiva, ativo) {
    if (deveEstarAtiva) {
        if !ativo[tecla] {
            ControlSend("{" tecla " down}", , GameWindow)
            ativo[tecla] := true
        }
    } else if ativo[tecla] {
        ControlSend("{" tecla " up}", , GameWindow)
        ativo[tecla] := false
    }
}

; Botoes do controle -> acao (src\macro\acoes.ahk). Dispara uma vez por pressao.
DespacharBotoes(State, isGameActive) {
    static pressionados := Map()
    b := State.wButtons

    DispararUmaVez(pressionados, "Triggers", (State.bRightTrigger > 200 || State.bLeftTrigger > 200) && isGameActive,
        () => AcaoGatilhos("controller"))
    DispararUmaVez(pressionados, "Bumpers", (b & 0x0100 || b & 0x0200) && isGameActive, AcaoBumpers)
    DispararUmaVez(pressionados, "FaceDown", (b & 0x1000 || b & 0x0002) && isGameActive, AcaoFaceDown)    ; A / DPad baixo
    DispararUmaVez(pressionados, "FaceRight", (b & 0x4000 || b & 0x0008) && isGameActive, AcaoFaceRight)  ; X / DPad direita
    DispararUmaVez(pressionados, "FaceLeft", (b & 0x2000 || b & 0x0004) && isGameActive, AcaoFaceLeft)    ; B / DPad esquerda
    DispararUmaVez(pressionados, "FaceUp", (b & 0x8000 || b & 0x0001) && isGameActive, AcaoFaceUp)        ; Y / DPad cima
    DispararUmaVez(pressionados, "LeftThumb", (b & 0x0040) && isGameActive, AcaoLeftThumb)
    DispararUmaVez(pressionados, "RightThumb", (b & 0x0080) && isGameActive, AcaoRightThumb)
    DispararUmaVez(pressionados, "Start", (b & 0x0010) && isGameActive, ReiniciarMacro)               ; reinicia o macro
    DispararUmaVez(pressionados, "Back", (b & 0x0020) && isGameActive, TrocarModo)                         ; troca de modo
}

; Agenda `acao` uma unica vez enquanto o botao estiver pressionado; soltar re-arma.
DispararUmaVez(pressionados, nome, ativo, acao) {
    if (ativo) {
        if !pressionados.Has(nome) {
            SetTimer(acao, -1)
            pressionados[nome] := true
        }
    } else if pressionados.Has(nome) {
        pressionados.Delete(nome)
    }
}

; Pedidos antecipados (combo e troca armados). Sao acoes do modo, nao da interface:
; ficam fora do bloco de renderizacao para nunca serem perdidos por falha de tooltip.
VerificarPedidosArmados() {
    try {
        VerificarComboArmado()
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=combo_armed", e)
    }
    try {
        VerificarTrocaArmada()
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=switch_armed", e)
    }
}

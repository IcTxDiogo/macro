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

    leitura := XInput_GetState(0)
    if !leitura {
        AtualizarInterface(false)
        return
    }

    jogoAtivo := WinExist(GameWindow)
    if (jogoAtivo)
        AtualizarMovimento(leitura)
    DespacharBotoes(leitura, jogoAtivo)
    VerificarPedidosArmados()
    AtualizarInterface()
}

; Analogico -> WASD. Cada tecla so e enviada quando o estado muda.
AtualizarMovimento(leitura) {
    static ativo := Map("w", false, "s", false, "a", false, "d", false)
    AplicarTeclaDeMovimento("w", leitura.sThumbLY > DeadzoneMove || leitura.sThumbRY > DeadzoneMove, ativo)
    AplicarTeclaDeMovimento("s", leitura.sThumbLY < -DeadzoneMove || leitura.sThumbRY < -DeadzoneMove, ativo)
    AplicarTeclaDeMovimento("a", leitura.sThumbLX < -DeadzoneMove || leitura.sThumbRX < -DeadzoneMove, ativo)
    AplicarTeclaDeMovimento("d", leitura.sThumbLX > DeadzoneMove || leitura.sThumbRX > DeadzoneMove, ativo)
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
DespacharBotoes(leitura, jogoAtivo) {
    static pressionados := Map()
    botoes := leitura.wButtons

    DispararUmaVez(pressionados, "Triggers", (leitura.bRightTrigger > 200 || leitura.bLeftTrigger > 200) && jogoAtivo,
        () => AcaoGatilhos("controller"))
    DispararUmaVez(pressionados, "Bumpers", (botoes & 0x0100 || botoes & 0x0200) && jogoAtivo, AcaoBumpers)
    DispararUmaVez(pressionados, "FaceDown", (botoes & 0x1000 || botoes & 0x0002) && jogoAtivo, AcaoFaceDown)  ; A / DPad baixo
    DispararUmaVez(pressionados, "FaceRight", (botoes & 0x4000 || botoes & 0x0008) && jogoAtivo, AcaoFaceRight)  ; X / DPad direita
    DispararUmaVez(pressionados, "FaceLeft", (botoes & 0x2000 || botoes & 0x0004) && jogoAtivo, AcaoFaceLeft)    ; B / DPad esquerda
    DispararUmaVez(pressionados, "FaceUp", (botoes & 0x8000 || botoes & 0x0001) && jogoAtivo, AcaoFaceUp)        ; Y / DPad cima
    DispararUmaVez(pressionados, "LeftThumb", (botoes & 0x0040) && jogoAtivo, AcaoLeftThumb)
    DispararUmaVez(pressionados, "RightThumb", (botoes & 0x0080) && jogoAtivo, AcaoRightThumb)
    DispararUmaVez(pressionados, "Start", (botoes & 0x0010) && jogoAtivo, ReiniciarMacro)               ; reinicia o macro
    DispararUmaVez(pressionados, "Back", (botoes & 0x0020) && jogoAtivo, TrocarModo)                         ; troca de modo
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

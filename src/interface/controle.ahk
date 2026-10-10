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
        SwitchDebug("LOOP_STALL", "gap_ms=" (agoraTick - ultimoTick) " state=" Hoenn222_State " rodizio=" isRodizioAtivo)
    ultimoTick := agoraTick

    State := XInput_GetState(0)
    if !State {
        AtualizarTooltipsControle(false)
        return
    }

    isGameActive := WinExist(GameWindow)
    if (isGameActive)
        AtualizarMovimento(State)
    DespacharBotoes(State, isGameActive)
    ProcessarAcoesArmadas()
    AtualizarTooltipsControle()
}

; Analogico -> WASD. Cada tecla so e enviada quando o estado muda.
AtualizarMovimento(State) {
    static ativo := Map("w", false, "s", false, "a", false, "d", false)
    AplicarTecla("w", State.sThumbLY > DeadzoneMove || State.sThumbRY > DeadzoneMove, ativo)
    AplicarTecla("s", State.sThumbLY < -DeadzoneMove || State.sThumbRY < -DeadzoneMove, ativo)
    AplicarTecla("a", State.sThumbLX < -DeadzoneMove || State.sThumbRX < -DeadzoneMove, ativo)
    AplicarTecla("d", State.sThumbLX > DeadzoneMove || State.sThumbRX > DeadzoneMove, ativo)
}

AplicarTecla(tecla, deveEstarAtiva, ativo) {
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

    DisparoUnico(pressionados, "Triggers", (State.bRightTrigger > 200 || State.bLeftTrigger > 200) && isGameActive,
        () => Acao_Gatilhos("controller"))
    DisparoUnico(pressionados, "Bumpers", (b & 0x0100 || b & 0x0200) && isGameActive, Acao_Bumpers)
    DisparoUnico(pressionados, "FaceDown", (b & 0x1000 || b & 0x0002) && isGameActive, Acao_FaceDown)    ; A / DPad baixo
    DisparoUnico(pressionados, "FaceRight", (b & 0x4000 || b & 0x0008) && isGameActive, Acao_FaceRight)  ; X / DPad direita
    DisparoUnico(pressionados, "FaceLeft", (b & 0x2000 || b & 0x0004) && isGameActive, Acao_FaceLeft)    ; B / DPad esquerda
    DisparoUnico(pressionados, "FaceUp", (b & 0x8000 || b & 0x0001) && isGameActive, Acao_FaceUp)        ; Y / DPad cima
    DisparoUnico(pressionados, "LeftThumb", (b & 0x0040) && isGameActive, Acao_LeftThumb)
    DisparoUnico(pressionados, "RightThumb", (b & 0x0080) && isGameActive, Acao_RightThumb)
    DisparoUnico(pressionados, "Start", (b & 0x0010) && isGameActive, InterruptAndReload)               ; reinicia o macro
    DisparoUnico(pressionados, "Back", (b & 0x0020) && isGameActive, TrocarModo)                         ; troca de modo
}

; Agenda `acao` uma unica vez enquanto o botao estiver pressionado; soltar re-arma.
DisparoUnico(pressionados, nome, ativo, acao) {
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
ProcessarAcoesArmadas() {
    try {
        ProcessarComboArmadoHoenn222()
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=combo_armed", e)
    }
    try {
        ProcessarTrocaArmadaHoenn222()
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=switch_armed", e)
    }
}

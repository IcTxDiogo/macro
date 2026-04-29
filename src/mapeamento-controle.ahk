#Requires AutoHotkey v2.0
#Include ..\config.ahk

global StatusText

^Esc:: InterruptAndReload()
SetTimer(GameLoop, 30)

GameLoop() {
    static wasd_active := Map("w", false, "a", false, "s", false, "d", false)
    static buttons_pressed := Map()
    State := XInput_GetState(0)
    if !State {
        ToolTip("Controle Desconectado", 210, 0)
        return
    }

    isGameActive := WinActive(GameWindow)

    if (isGameActive) {
        ToolTip(StatusText, 210, 30)
        ; Movimento analógico
        if (State.sThumbLY > DeadzoneMove || State.sThumbRY > DeadzoneMove) {
            (wasd_active["w"] ? "" : (Send("{w down}"), wasd_active["w"] := true))
        } else if wasd_active["w"] {
            Send("{w up}"), wasd_active["w"] := false
        }
        if (State.sThumbLY < -DeadzoneMove || State.sThumbRY < -DeadzoneMove) {
            (wasd_active["s"] ? "" : (Send("{s down}"), wasd_active["s"] := true))
        } else if wasd_active["s"] {
            Send("{s up}"), wasd_active["s"] := false
        }
        if (State.sThumbLX < -DeadzoneMove || State.sThumbRX < -DeadzoneMove) {
            (wasd_active["a"] ? "" : (Send("{a down}"), wasd_active["a"] := true))
        } else if wasd_active["a"] {
            Send("{a up}"), wasd_active["a"] := false
        }
        if (State.sThumbLX > DeadzoneMove || State.sThumbRX > DeadzoneMove) {
            (wasd_active["d"] ? "" : (Send("{d down}"), wasd_active["d"] := true))
        } else if wasd_active["d"] {
            Send("{d up}"), wasd_active["d"] := false
        }
    }

    ; --- BOTÕES ESPELHADOS ---

    ; Gatilhos (Triggers)
    if ((State.bRightTrigger > 200 || State.bLeftTrigger > 200) && isGameActive) {
        if !buttons_pressed.Has("Triggers") {
            Acao_Gatilhos(), buttons_pressed["Triggers"] := true
        }
    } else if buttons_pressed.Has("Triggers")
        buttons_pressed.Delete("Triggers")

    ; Bumpers
    if ((State.wButtons & 0x0100 || State.wButtons & 0x0200) && isGameActive) {
        if !buttons_pressed.Has("Bumpers") {
            Acao_Bumpers(), buttons_pressed["Bumpers"] := true
        }
    } else if buttons_pressed.Has("Bumpers")
        buttons_pressed.Delete("Bumpers")

    ; FaceDown (Botão A / DPad Down)
    if ((State.wButtons & 0x1000 || State.wButtons & 0x0002) && isGameActive) {
        if !buttons_pressed.Has("FaceDown") {
            Acao_FaceDown(), buttons_pressed["FaceDown"] := true
        }
    } else if buttons_pressed.Has("FaceDown")
        buttons_pressed.Delete("FaceDown")

    ; FaceRight (Botão X / DPad Right)
    if ((State.wButtons & 0x4000 || State.wButtons & 0x0008) && isGameActive) {
        if !buttons_pressed.Has("FaceRight") {
            Acao_FaceRight(), buttons_pressed["FaceRight"] := true
        }
    } else if buttons_pressed.Has("FaceRight")
        buttons_pressed.Delete("FaceRight")

    ; FaceLeft (Botão B / DPad Left)
    if ((State.wButtons & 0x2000 || State.wButtons & 0x0004) && isGameActive) {
        if !buttons_pressed.Has("FaceLeft") {
            Acao_FaceLeft(), buttons_pressed["FaceLeft"] := true
        }
    } else if buttons_pressed.Has("FaceLeft")
        buttons_pressed.Delete("FaceLeft")

    ; FaceUp (Botão Y / DPad Up)
    if ((State.wButtons & 0x8000 || State.wButtons & 0x0001) && isGameActive) {
        if !buttons_pressed.Has("FaceUp") {
            Acao_FaceUp(), buttons_pressed["FaceUp"] := true
        }
    } else if buttons_pressed.Has("FaceUp")
        buttons_pressed.Delete("FaceUp")

    ; Start (Reload)
    if (State.wButtons & 0x0010 && isGameActive) {
        if !buttons_pressed.Has("Start") {
            InterruptAndReload(), buttons_pressed["Start"] := true
        }
    } else if buttons_pressed.Has("Start")
        buttons_pressed.Delete("Start")

    ; Back (Trocar Modo)
    if (State.wButtons & 0x0020 && isGameActive) {
        if !buttons_pressed.Has("Back") {
            TrocarModo(), buttons_pressed["Back"] := true
        }
    } else if buttons_pressed.Has("Back")
        buttons_pressed.Delete("Back")
}

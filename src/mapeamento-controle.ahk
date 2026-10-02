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
        if WinExist(GameWindow) {
            WinGetPos(&winX, &winY, , , GameWindow)
            CoordMode("ToolTip", "Screen")
            ToolTip("Controle Desconectado", winX + 210, winY)
        } else {
            ToolTip("Controle Desconectado", 210, 0)
        }
        return
    }

    isGameActive := WinExist(GameWindow)

    if (isGameActive) {
        ; Pega a posição da janela do jogo para exibir o texto nela
        WinGetPos(&winX, &winY, , , GameWindow)
        CoordMode("ToolTip", "Screen")
        ToolTip(StatusText, winX + 210, winY + 30)
        ; Movimento analógico
        if (State.sThumbLY > DeadzoneMove || State.sThumbRY > DeadzoneMove) {
            (wasd_active["w"] ? "" : (ControlSend("{w down}", , GameWindow), wasd_active["w"] := true))
        } else if wasd_active["w"] {
            ControlSend("{w up}", , GameWindow), wasd_active["w"] := false
        }
        if (State.sThumbLY < -DeadzoneMove || State.sThumbRY < -DeadzoneMove) {
            (wasd_active["s"] ? "" : (ControlSend("{s down}", , GameWindow), wasd_active["s"] := true))
        } else if wasd_active["s"] {
            ControlSend("{s up}", , GameWindow), wasd_active["s"] := false
        }
        if (State.sThumbLX < -DeadzoneMove || State.sThumbRX < -DeadzoneMove) {
            (wasd_active["a"] ? "" : (ControlSend("{a down}", , GameWindow), wasd_active["a"] := true))
        } else if wasd_active["a"] {
            ControlSend("{a up}", , GameWindow), wasd_active["a"] := false
        }
        if (State.sThumbLX > DeadzoneMove || State.sThumbRX > DeadzoneMove) {
            (wasd_active["d"] ? "" : (ControlSend("{d down}", , GameWindow), wasd_active["d"] := true))
        } else if wasd_active["d"] {
            ControlSend("{d up}", , GameWindow), wasd_active["d"] := false
        }
    }

    ; --- BOTÕES ESPELHADOS ---

    ; Gatilhos (Triggers)
    if ((State.bRightTrigger > 200 || State.bLeftTrigger > 200) && isGameActive) {
        if !buttons_pressed.Has("Triggers") {
            SetTimer(() => Acao_Gatilhos(), -1), buttons_pressed["Triggers"] := true
        }
    } else if buttons_pressed.Has("Triggers")
        buttons_pressed.Delete("Triggers")

    ; Bumpers
    if ((State.wButtons & 0x0100 || State.wButtons & 0x0200) && isGameActive) {
        if !buttons_pressed.Has("Bumpers") {
            SetTimer(() => Acao_Bumpers(), -1), buttons_pressed["Bumpers"] := true
        }
    } else if buttons_pressed.Has("Bumpers")
        buttons_pressed.Delete("Bumpers")

    ; FaceDown (Botão A / DPad Down)
    if ((State.wButtons & 0x1000 || State.wButtons & 0x0002) && isGameActive) {
        if !buttons_pressed.Has("FaceDown") {
            SetTimer(() => Acao_FaceDown(), -1), buttons_pressed["FaceDown"] := true
        }
    } else if buttons_pressed.Has("FaceDown")
        buttons_pressed.Delete("FaceDown")

    ; FaceRight (Botão X / DPad Right)
    if ((State.wButtons & 0x4000 || State.wButtons & 0x0008) && isGameActive) {
        if !buttons_pressed.Has("FaceRight") {
            SetTimer(() => Acao_FaceRight(), -1), buttons_pressed["FaceRight"] := true
        }
    } else if buttons_pressed.Has("FaceRight")
        buttons_pressed.Delete("FaceRight")

    ; FaceLeft (Botão B / DPad Left)
    if ((State.wButtons & 0x2000 || State.wButtons & 0x0004) && isGameActive) {
        if !buttons_pressed.Has("FaceLeft") {
            SetTimer(() => Acao_FaceLeft(), -1), buttons_pressed["FaceLeft"] := true
        }
    } else if buttons_pressed.Has("FaceLeft")
        buttons_pressed.Delete("FaceLeft")

    ; FaceUp (Botão Y / DPad Up)
    if ((State.wButtons & 0x8000 || State.wButtons & 0x0001) && isGameActive) {
        if !buttons_pressed.Has("FaceUp") {
            SetTimer(() => Acao_FaceUp(), -1), buttons_pressed["FaceUp"] := true
        }
    } else if buttons_pressed.Has("FaceUp")
        buttons_pressed.Delete("FaceUp")

    ; Left Thumb (Analog Click)
    if ((State.wButtons & 0x0040) && isGameActive) {
        if !buttons_pressed.Has("LeftThumb") {
            SetTimer(() => Acao_LeftThumb(), -1), buttons_pressed["LeftThumb"] := true
        }
    } else if buttons_pressed.Has("LeftThumb")
        buttons_pressed.Delete("LeftThumb")

    ; Right Thumb (Analog Click)
    if ((State.wButtons & 0x0080) && isGameActive) {
        if !buttons_pressed.Has("RightThumb") {
            SetTimer(() => Acao_RightThumb(), -1), buttons_pressed["RightThumb"] := true
        }
    } else if buttons_pressed.Has("RightThumb")
        buttons_pressed.Delete("RightThumb")

    ; Start (Reload)
    if (State.wButtons & 0x0010 && isGameActive) {
        if !buttons_pressed.Has("Start") {
            SetTimer(() => InterruptAndReload(), -1), buttons_pressed["Start"] := true
        }
    } else if buttons_pressed.Has("Start")
        buttons_pressed.Delete("Start")

    ; Back (Trocar Modo)
    if (State.wButtons & 0x0020 && isGameActive) {
        if !buttons_pressed.Has("Back") {
            SetTimer(() => TrocarModo(), -1), buttons_pressed["Back"] := true
        }
    } else if buttons_pressed.Has("Back")
        buttons_pressed.Delete("Back")
}

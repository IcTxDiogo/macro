#Requires AutoHotkey v2.0
; Funcoes mantidas para referencia: NENHUMA e usada pelo respawn atual.
; Ficam isoladas aqui para nao poluir src\macro\teclas.ahk.

; Joga pokebolas em area ao redor do personagem (botao FaceRight, hoje desativado).
ThrowBallAround() {
    if !WinActive(GameWindow) {
        return
    }

    baseX := PlayerOriginX
    ; Desloca o centro da ação 1 SQM para cima do personagem
    baseY := PlayerOriginY - TileSize * 2

    offsets := [
        [-1, -1],
        [0, -1],
        [1, -1],
        [-1, 0],
        [1, 0],
        [-1, 1],
        [0, 1],
        [1, 1]
    ]

    for offset in offsets {
        x := baseX + (offset[1] * TileSize)
        y := baseY + (offset[2] * TileSize)
        MouseMove(x, y, 0)
        Sleep(30)
        ControlSend("{" KeyBall "}", , GameWindow)
        Sleep(250)
    }

    ; Retorna o mouse para o seu personagem (e não para o novo centro)
    MouseMove(PlayerOriginX, PlayerOriginY, 0)
}

; Combo com o Mr. Mime usando o mouse.
MrMimeCombo() {
    if !WinActive(GameWindow) {
        return
    }

    x := PlayerOriginX
    y := PlayerOriginY + (3 * TileSize)
    MouseMove(x, y, 0)
    Sleep(50)
    ControlSend("{" KeyMovePokemon "}", , GameWindow)
    Sleep(50)
    ControlSend("{" KeyPokestop "}", , GameWindow)
    Sleep(50)
    ControlSend("{ctrl down}", , GameWindow)
    Sleep(50)
    ControlSend("{w}", , GameWindow)
    Sleep(50)
    ControlSend("{ctrl up}", , GameWindow)
    Sleep(50)
    ControlSend("{" KeyPokeMoveF3 "}", , GameWindow)
    Sleep(50)
}

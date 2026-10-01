#Requires AutoHotkey v2.0
#Include ..\config.ahk

global pokeState := true

; --- FUNÇÕES DE ATAQUE E MOVIMENTAÇÃO ---

ComboSimples() {
    Send("{" KeyFullAtk "}")
    Sleep(50)
    Send("{" KeyPokestop "}")
    Sleep(50)
    Send("{" KeyMedicine "}")
    Sleep(50)
    Send("{" KeyCombo "}")
}

PokeStop() {
    global pokeState
    if (pokeState) {
        Send("{" KeyPokestop "}")
    } else {
        Send("{" KeyMovePokemon "}")
    }
    pokeState := !pokeState
}

CatchCenter() {
    if WinActive(GameWindow) {
        Send("{" KeyBallSpecial "}")
    }
}

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
        Send("{" KeyBall "}")
        Sleep(250)
    }

    ; Retorna o mouse para o seu personagem (e não para o novo centro)
    MouseMove(PlayerOriginX, PlayerOriginY, 0)
}

MrMimeCombo() {
    if !WinActive(GameWindow) {
        return
    }

    x := PlayerOriginX
    y := PlayerOriginY + (3 * TileSize)
    MouseMove(x, y, 0)
    Sleep(50)
    Send("{" KeyMovePokemon "}")
    Sleep(50)
    Send("{" KeyPokestop "}")
    Sleep(50)
    Send("{ctrl down}")
    Sleep(50)
    Send("{w}")
    Sleep(50)
    Send("{ctrl up}")
    Sleep(50)
    Send("{" KeyPokeMoveF3 "}")
    Sleep(50)
}

Revive() {
    if WinActive(GameWindow) {
        Send("{" KeyRevive "}")
    }
}

; --- FUNÇÕES DE BUFF ---

AtivarBuffLure() {
    if WinActive(GameWindow) {
        Send("{" KeyBuffMove "}")
    }
}

AtivarBuffDrop() {
    if WinActive(GameWindow) {
        Send("{" KeyBuffDrop "}")
    }
}

ChangeTarget() {
    if WinActive(GameWindow) {
        Send("{" KeyChangeTarget "}")
    }
}

Potion() {
    if WinActive(GameWindow) {
        Send("{" KeyPotion "}")
    }
}

InterruptAndReload() {
    if WinActive(GameWindow) {
        Thread "Interrupt"
        Sleep 200
        Reload()
    }
}

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
    baseY := PlayerOriginY

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

    MouseMove(baseX, baseY, 0)
}

PokeMoveDown2AndF3() {
    if !WinActive(GameWindow) {
        return
    }

    x := PlayerOriginX
    y := PlayerOriginY + (3 * TileSize)
    MouseMove(x, y, 0)
    Sleep(30)
    Send("{" KeyMovePokemon "}")
    Sleep(50)
    Send("{" KeyPokeMoveF3 "}")
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

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

    startX := BallOriginX
    startY := BallOriginY

    path := [
        [0, 0],
        [1, 0],
        [1, 0],
        [0, 1],
        [0, 1],
        [-1, 0],
        [-1, 0],
        [0, -1]
    ]

    x := startX
    y := startY
    MouseMove(x, y, 0)
    Sleep(30)
    Send("{" KeyBall "}")
    Sleep(30)
    for step in path {
        x += step[1] * BallMouseSpacing
        y += step[2] * BallMouseSpacing
        MouseMove(x, y, 0)
        Sleep(30)
        Send("{" KeyBall "}")
        Sleep(230)
    }

    MouseMove(startX, startY, 0)
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

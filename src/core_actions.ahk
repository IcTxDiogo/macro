#Requires AutoHotkey v2.0
#Include ..\config.ahk

global pokeState := true

; --- FUNÇÕES DE ATAQUE E MOVIMENTAÇÃO ---

ComboSimples() {
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
        Send("{" KeyBall "}")
    }
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

InterruptAndReload() {
    if WinActive(GameWindow) {
        Thread "Interrupt"
        Sleep 200
        Reload()
    }
}

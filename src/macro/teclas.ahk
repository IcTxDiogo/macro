#Requires AutoHotkey v2.0
; Teclas basicas do jogo: cada funcao envia uma tecla (ou uma sequencia curta) e nada mais.
; Nenhuma decide QUANDO agir: isso e do tempo (src\tempo) e das antecipacoes (src\macro).

ComboSimples() {
    ControlSend("{" KeyFullAtk "}", , GameWindow)
    Sleep(50)
    ControlSend("{" KeyPokestop "}", , GameWindow)
    Sleep(50)
    ControlSend("{" KeyMedicine "}", , GameWindow)
    Sleep(50)
    ControlSend("{" KeyCombo "}", , GameWindow)
}

CatchCenter() {
    if WinExist(GameWindow) {
        ControlSend("{" KeyBallSpecial "}", , GameWindow)
    }
}

Revive() {
    if WinExist(GameWindow) {
        ControlSend("{" KeyRevive "}", , GameWindow)
    }
}

AtivarBuffLure() {
    if WinExist(GameWindow) {
        ControlSend("{" KeyBuffMove "}", , GameWindow)
    }
}

ChangeTarget() {
    if WinExist(GameWindow) {
        ControlSend("{" KeyChangeTarget "}", , GameWindow)
    }
}

Potion() {
    if WinExist(GameWindow) {
        ControlSend("{" KeyPotion "}", , GameWindow)
    }
}

InterruptAndReload() {
    if WinExist(GameWindow) {
        Thread "Interrupt"
        Sleep 200
        Reload()
    }
}

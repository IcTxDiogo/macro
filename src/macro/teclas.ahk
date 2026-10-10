#Requires AutoHotkey v2.0
; Teclas basicas do jogo: cada funcao envia uma tecla (ou uma sequencia curta) e nada mais.
; Nenhuma decide QUANDO agir: isso e do tempo (src\tempo) e das antecipacoes (src\macro).

ComboSimples(contextoValido := false) {
    if (IsObject(contextoValido) && !contextoValido.Call())
        return false
    ControlSend("{" KeyFullAtk "}", , GameWindow)
    Sleep(50)
    if (IsObject(contextoValido) && !contextoValido.Call())
        return false
    ControlSend("{" KeyPokestop "}", , GameWindow)
    Sleep(50)
    if (IsObject(contextoValido) && !contextoValido.Call())
        return false
    ControlSend("{" KeyMedicine "}", , GameWindow)
    Sleep(50)
    if (IsObject(contextoValido) && !contextoValido.Call())
        return false
    ControlSend("{" KeyCombo "}", , GameWindow)
    return true
}

CapturarAlvo() {
    if WinExist(GameWindow) {
        ControlSend("{" KeyBallSpecial "}", , GameWindow)
    }
}

Reviver() {
    if WinExist(GameWindow) {
        ControlSend("{" KeyRevive "}", , GameWindow)
    }
}

AtivarBuffLure() {
    if WinExist(GameWindow) {
        ControlSend("{" KeyBuffMove "}", , GameWindow)
    }
}

TrocarAlvo() {
    if WinExist(GameWindow) {
        ControlSend("{" KeyChangeTarget "}", , GameWindow)
    }
}

UsarPocao() {
    if WinExist(GameWindow) {
        ControlSend("{" KeyPotion "}", , GameWindow)
    }
}

; Recarrega o macro (Ctrl+Esc / Start). Funciona com o jogo fechado: reiniciar nao depende da
; janela. O reload comeca do zero, no time 1, sem pedidos ou cooldowns anteriores.
ReiniciarMacro() {
    Thread "Interrupt"
    Sleep 200
    Reload()
}

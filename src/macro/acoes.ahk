#Requires AutoHotkey v2.0
; Acao de cada botao, conforme o modo. O mapeamento botao -> acao esta em
; src\interface\controle.ahk (controle) e main.ahk (mouse); aqui so o que cada um faz.

; Gatilhos (LT/RT, botao lateral 2 do mouse): revive / troca de time.
Acao_Gatilhos(source := "direct") {
    SwitchDebug("TRIGGER_RECEIVED", "source=" source " mode=" ModoAtual " team=" TimeAtual)
    try {
        if (ModoAtual == "Normal") {
            Revive()
        } else if (ModoAtual == "Hoenn33") {
            if (TrocarTimeHoenn(2)) {
                Sleep(SleepAfterSwitch)
                ControlSend("{" KeyPokestop "}", , GameWindow)
                Potion()
            }
        } else if (ModoAtual == "Hoenn222") {
            ; Troca na hora se TROCAR TIME ja esta verde; senao arma e troca
            ; sozinha no verde. Duplo acionamento troca na hora.
            SolicitarTrocaHoenn222(source)
        }
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=trigger_action source=" source, e)
    }
}

; Bumpers (LB/RB, botao lateral 1 do mouse): combo.
Acao_Bumpers() {
    if (ModoAtual == "Normal") {
        ComboSimples()
    } else if (ModoAtual == "Hoenn33") {
        ComboComplexoHoenn33()
    } else if (ModoAtual == "Hoenn222") {
        SolicitarComboHoenn222()
    }
}

Acao_FaceDown() {
    AtivarBuffLure()
}

Acao_FaceRight() {
    ; ThrowBallAround() ; Desativado para o respawn atual (Botão Livre!)
}

Acao_FaceLeft() {
    CatchCenter()
}

Acao_FaceUp() {
    ChangeTarget()
}

Acao_LeftThumb() {
    Potion()
}

Acao_RightThumb() {
    Potion()
}

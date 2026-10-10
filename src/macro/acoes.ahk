#Requires AutoHotkey v2.0
; Acao de cada botao, conforme o modo. O mapeamento botao -> acao esta em
; src\interface\controle.ahk (controle) e main.ahk (mouse); aqui so o que cada um faz.

; Gatilhos (LT/RT, botao lateral 2 do mouse): revive / troca de time.
AcaoGatilhos(source := "direct") {
    LogDiagnostico("TRIGGER_RECEIVED", "source=" source " mode=" ModoAtual " team=" TimeAtual)
    try {
        if (ModoAtual == "Normal") {
            Reviver()
        } else if (ModoAtual == "Hoenn33") {
            if (TrocarDeTime(2)) {
                Sleep(SleepAfterSwitch)
                ControlSend("{" KeyPokestop "}", , GameWindow)
                UsarPocao()
            }
        } else if (ModoAtual == "Hoenn222") {
            ; Troca na hora se TROCAR TIME ja esta verde; senao arma e troca
            ; sozinha no verde. Duplo acionamento troca na hora.
            PedirTrocaDeTime(source)
        }
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=trigger_action source=" source, e)
    }
}

; Bumpers (LB/RB, botao lateral 1 do mouse): combo.
AcaoBumpers() {
    if (ModoAtual == "Normal") {
        ComboSimples()
    } else if (ModoAtual == "Hoenn33") {
        IniciarRodizio33()
    } else if (ModoAtual == "Hoenn222") {
        PedirCombo()
    }
}

AcaoFaceDown() {
    AtivarBuffLure()
}

AcaoFaceRight() {
    ; LancarBolasAoRedor() ; Desativado para o respawn atual (Botão Livre!)
}

AcaoFaceLeft() {
    CapturarAlvo()
}

AcaoFaceUp() {
    TrocarAlvo()
}

AcaoLeftThumb() {
    UsarPocao()
}

AcaoRightThumb() {
    UsarPocao()
}

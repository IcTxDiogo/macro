#Requires AutoHotkey v2.0
; Acao de cada botao, conforme o modo. O mapeamento botao -> acao esta em
; src\interface\controle.ahk (controle) e main.ahk (mouse); aqui so o que cada um faz.

; BOTAO UNICO do modo 2-2-2 (LB/RB e botao lateral 1 do mouse): pede a PROXIMA acao do ciclo.
;   fase COMBAR (ou antes do 1o combo)  -> combo        (PedirCombo)
;   fase TROCAR TIME                    -> troca de time (PedirTrocaDeTime)
; Cada acao executa na hora se o contador esta verde, arma e executa sozinha no verde se
; ainda esta em espera, e executa na hora com dois cliques seguidos (emergencia).
; Apertar durante o rodizio ja pede a troca: a fase muda para TROCAR TIME no inicio do combo.
PedirProximaAcao(origem := "direct") {
    proximaAcao := (FaseAtual == "WAITING_TEAM_SWITCH") ? "troca" : "combo"
    LogDiagnostico("NEXT_ACTION", "source=" origem " phase=" FaseAtual " action=" proximaAcao " team=" TimeAtual)
    if (proximaAcao == "troca")
        PedirTrocaDeTime(origem)
    else
        PedirCombo()
}

; Bumpers (LB/RB, botao lateral 1 do mouse). Normal: combo simples. 2-2-2: proxima acao.
AcaoBumpers(origem := "direct") {
    try {
        if (ModoAtual == "Normal") {
            ComboSimples()
        } else if (ModoAtual == "Hoenn222") {
            PedirProximaAcao(origem)
        }
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=bumper_action source=" origem, e)
    }
}

; Gatilhos (LT/RT, botao lateral 2 do mouse). Normal: reviver. No 2-2-2 estao livres.
AcaoGatilhos(origem := "direct") {
    try {
        if (ModoAtual == "Normal")
            Reviver()
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=trigger_action source=" origem, e)
    }
}

AcaoFaceDown() {
    AtivarBuffLure()
}

; Botao livre no respawn atual.
AcaoFaceRight() {
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

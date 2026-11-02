#Requires AutoHotkey v2.0
; Acao de cada botao, conforme o modo. O mapeamento botao -> acao esta em
; src\interface\controle.ahk (controle) e main.ahk (mouse); aqui so o que cada um faz.

; BOTAO UNICO dos modos Hoenn (LB/RB e botao lateral 1 do mouse): pede a PROXIMA acao do ciclo.
;   fase COMBAR (ou antes do 1o combo)  -> combo        (PedirCombo; no 1,5, a parte 1)
;   fase PARTE 2 (so no 1,5)            -> combo        (PedirCombo; a parte 2)
;   fase TROCAR TIME                    -> troca de time (PedirTrocaDeTime)
; Cada acao executa na hora se o contador esta verde, arma e executa sozinha no verde se
; ainda esta em espera, e executa na hora com dois cliques seguidos (emergencia).
; Apertar durante o rodizio ja pede a troca: a fase muda para TROCAR TIME no inicio do combo
; (no 1,5, no inicio da parte 2).
PedirProximaAcao(origem := "direct") {
    proximaAcao := (FaseAtual == "WAITING_TEAM_SWITCH") ? "troca" : "combo"
    LogDiagnostico("NEXT_ACTION", "source=" origem " phase=" FaseAtual " action=" proximaAcao " team=" TimeAtual
        (ModoAtual == "Hoenn15" ? " modo=1,5" : ""))
    if (proximaAcao == "troca")
        PedirTrocaDeTime(origem)
    else
        PedirCombo()
}

; Bumpers (LB/RB, botao lateral 1 do mouse). Normal: combo simples. Hoenn: proxima acao.
AcaoBumpers(origem := "direct") {
    try {
        if (ModoAtual == "Normal") {
            ComboSimples()
        } else if ModoComRodizio() {
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

; X / direcional direito: renovar a guild daily.
AcaoFaceRight() {
    RenovarGuildDaily()
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

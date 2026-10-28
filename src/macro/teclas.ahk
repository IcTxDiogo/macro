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
    global UltimaBallEspecial
    if !WinExist(GameWindow)
        return
    teclas := [KeyBallSpecial, KeyBallSpecial2, KeyBallSpecial3]
    loop 3 {
        indice := Mod(UltimaBallEspecial + A_Index - 1, 3) + 1
        if (teclas[indice] = "")
            continue
        try {
            ControlSend("{" teclas[indice] "}", , GameWindow)
            UltimaBallEspecial := indice
            LogDiagnostico("BALL_SPECIAL", "ball=" indice)
            return true
        } catch as e {
            LogDiagnostico("SWITCH_ERROR", "phase=capture ball=" indice, e)
            return false
        }
    }
    return false
}

PosicaoDailyValida(posicao) {
    return IsObject(posicao) && posicao.HasOwnProp("X") && posicao.HasOwnProp("Y")
        && IsInteger(posicao.X) && IsInteger(posicao.Y) && posicao.X > 0 && posicao.Y > 0
}

RenovarGuildDaily() {
    global RenovacaoDailyAtiva
    if RenovacaoDailyAtiva
        return false
    if (!PosicaoDailyValida(GuildDailyRenewPos) || !PosicaoDailyValida(GuildDailyConfirmPos)) {
        LogDiagnostico("DAILY_IGNORADA", "motivo=configure_as_duas_posicoes")
        return false
    }
    if (!IsInteger(GuildDailyConfirmDelayMs) || GuildDailyConfirmDelayMs < 0)
        return false
    janela := WinExist(GameWindow)
    if !janela
        return false
    RenovacaoDailyAtiva := true
    try {
        ControlClick("x" GuildDailyRenewPos.X " y" GuildDailyRenewPos.Y, "ahk_id " janela, , "Left", 1, "NA Pos")
        Sleep(GuildDailyConfirmDelayMs)
        ; Nao confirmar em outra janela se o cliente fechar durante a espera.
        if (WinExist(GameWindow) != janela)
            return false
        ControlClick("x" GuildDailyConfirmPos.X " y" GuildDailyConfirmPos.Y, "ahk_id " janela, , "Left", 1, "NA Pos")
        LogDiagnostico("DAILY_RENOVACAO", "cliques_enviados=2")
        return true
    } catch as e {
        LogDiagnostico("SWITCH_ERROR", "phase=guild_daily", e)
        return false
    } finally {
        RenovacaoDailyAtiva := false
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

#Requires AutoHotkey v2.0
#SingleInstance Force

#Include lib\XInput.ahk
#Include src\hoenn_engine.ahk

try {
    XInput_Init()
} catch as e {
    MsgBox("ERRO XINPUT: " e.Message)
    ExitApp
}

; --- MODO ATUAL ---
global ModoAtual := "Hoenn222"  ; Pode ser "Normal", "Hoenn33", "Hoenn222"
global StatusText := "Modo: Hoenn 2-2-2 - Time: 1"
global comboMrMime := 0

; --- HOTKEY PARA TROCAR MODO E RESYNC ---
F12:: TrocarModo()
F8:: ResincronizarHoenn222()

; --- FUNÇÃO PARA TROCAR MODO ---
TrocarModo() {
    global ModoAtual, StatusText, Hoenn222_State, TimeAtual
    ; Sair do 2-2-2 nunca deixa um pedido de combo pendente no modo seguinte.
    CancelarComboArmadoHoenn222("mode_change")
    if (ModoAtual == "Normal") {
        ModoAtual := "Hoenn33"
        StatusText := "Modo: Hoenn 3-3 - Time: " TimeAtual
    } else if (ModoAtual == "Hoenn33") {
        ModoAtual := "Hoenn222"
        StatusText := "Modo: Hoenn 2-2-2 - Time: " TimeAtual
        ResincronizarHoenn222()
    } else {
        ModoAtual := "Normal"
        StatusText := "Modo: Normal"
        AtualizarHoenn222CentralTooltip() ; Limpa o tooltip central ao sair do modo Hoenn 2-2-2
    }
}

ResincronizarHoenn222() {
    global Hoenn222_State, ModoAtual, TimeAtual
    global Hoenn222_StateStartTick, Hoenn222_LastComboStartTick, Hoenn222_P2CallTick, Hoenn222_TankEnterTick
    global Hoenn222_ExecutionId

    if (ModoAtual == "Hoenn222") {
        CancelarComboArmadoHoenn222("resync")
        Hoenn222_State := "WAITING_FIRST_COMBO"
        Hoenn222_StateStartTick := A_TickCount
        Hoenn222_LastComboStartTick := 0
        Hoenn222_P2CallTick := 0
        Hoenn222_TankEnterTick[TimeAtual] := 0
        Hoenn222_ExecutionId++ ; Invalida atualizações de interface de callbacks atrasados
        ResetarCooldownsHoenn222(A_TickCount) ; Sem informação do jogo: os seis prontos
    }
}

; --- DEFININDO AS AÇÕES BASEADO NO MODO ---

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
            if (TrocarTimeHoenn(3)) {
                Sleep(SleepAfterSwitch)
                ControlSend("{" KeyPokestop "}", , GameWindow)
                Potion()
            }
        }
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=trigger_action source=" source, e)
    }
}

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

; --- HOTKEYS PARA TECLADO E MOUSE ---
#HotIf WinActive(GameWindow)
XButton1:: Acao_Bumpers()  ; Botão lateral 1 do mouse: Combo (depende do modo)
XButton2:: Acao_Gatilhos("mouse") ; Botão lateral 2 do mouse: Revive/Troca Time (depende do modo)
#HotIf

; Carrega o motor do controle
#Include src\mapeamento-controle.ahk

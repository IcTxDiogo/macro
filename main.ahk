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
global ModoAtual := "Normal"  ; Pode ser "Normal", "Hoenn33", "Hoenn222"
global StatusText := "Modo: Normal"

; --- HOTKEY PARA TROCAR MODO ---
F12:: TrocarModo()

; --- FUNÇÃO PARA TROCAR MODO ---
TrocarModo() {
    global ModoAtual, StatusText
    if (ModoAtual == "Normal") {
        ModoAtual := "Hoenn33"
        StatusText := "Modo: Hoenn 3-3 - Time: 1"
    } else if (ModoAtual == "Hoenn33") {
        ModoAtual := "Hoenn222"
        StatusText := "Modo: Hoenn 2-2-2 - Time: 1"
    } else {
        ModoAtual := "Normal"
        StatusText := "Modo: Normal"
    }
}

; --- DEFININDO AS AÇÕES BASEADO NO MODO ---

Acao_Gatilhos() {
    if (ModoAtual == "Normal") {
        Revive()
    } else if (ModoAtual == "Hoenn33") {
        TrocarTimeHoenn(2)
    } else if (ModoAtual == "Hoenn222") {
        TrocarTimeHoenn(3)
    }
}

Acao_Bumpers() {
    if (ModoAtual == "Normal") {
        ComboSimples()
    } else if (ModoAtual == "Hoenn33") {
        ComboComplexoHoenn33()
    } else if (ModoAtual == "Hoenn222") {
        ComboComplexoHoenn222()
    }
}

Acao_FaceDown() {
    AtivarBuffLure()
}

Acao_FaceRight() {
    PokeStop()
}

Acao_FaceLeft() {
    CatchCenter()
}

Acao_FaceUp() {
    AtivarBuffDrop()
}

; --- HOTKEYS PARA TECLADO E MOUSE ---
#HotIf WinActive(GameWindow)
XButton1:: Acao_Bumpers()  ; Botão lateral 1 do mouse: Combo (depende do modo)
XButton2:: Acao_Gatilhos() ; Botão lateral 2 do mouse: Revive/Troca Time (depende do modo)
#HotIf

; Carrega o motor do controle
#Include src\mapeamento-controle.ahk
#Requires AutoHotkey v2.0
#SingleInstance Force

; Ponto de entrada: carrega config e modulos, liga o controle e define os atalhos.
; O comportamento esta em src\ (ver docs\estrutura.md); a configuracao, em config.ahk.
#Include config.ahk
#Include lib\XInput.ahk
#Include src\indice.ahk

try {
    XInput_Init()
} catch as e {
    MsgBox("ERRO XINPUT: " e.Message)
    ExitApp
}

IniciarControle()

; --- ATALHOS DE TECLADO E MOUSE ---
; Reinicia o macro (o botao Start do controle faz o mesmo).
^Esc:: ReiniciarMacro()

; Troca de modo (Normal / Hoenn 3-3 / Hoenn 2-2-2) e ressincronizacao do 2-2-2.
F12:: TrocarModo()
F8:: Resincronizar()

#HotIf WinActive(GameWindow)
; Agendados como no controle: a acao (que pode dormir centenas de ms) roda numa
; thread propria e nunca prende a thread do movimento por baixo dela.
XButton1:: SetTimer(() => AcaoBumpers(), -1)          ; botao lateral 1: combo
XButton2:: SetTimer(() => AcaoGatilhos("mouse"), -1)  ; botao lateral 2: revive / troca de time
#HotIf

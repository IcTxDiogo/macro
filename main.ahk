#Requires AutoHotkey v2.0
#SingleInstance Force

; Ponto de entrada: carrega config e modulos, liga o controle e define os atalhos.
; O comportamento esta em src\ (ver docs\estrutura.md); a configuracao, em config.ahk.
#Include config.ahk
#Include lib\XInput.ahk
#Include src\indice.ahk

; Recusar configuracao aritmetica invalida antes de ligar entradas/timers, sem muda-la.
if !ConfigDeTempoValida {
    MsgBox("Configuracao de tempo invalida. Corrija config.ahk e reabra o macro."
        TextoDosProblemasDeConfig())
    ExitApp()
}

GarantirInstanciaUnica()

try {
    XInput_Init()
} catch as erroAoIniciarXInput {
    MsgBox("ERRO XINPUT: " erroAoIniciarXInput.Message)
    ExitApp
}

; Planejar antes de ligar o timer: a busca discreta nunca ocupa o GameLoop de 30 ms.
try {
    if Hoenn222_CdOptimizerEnabled
        PlanejarVolta()
} catch as erroAoPlanejarInicial {
    LogDiagnostico("SWITCH_ERROR", "phase=initial_plan", erroAoPlanejarInicial)
}
IniciarControle()

; --- ATALHOS DE TECLADO E MOUSE ---
; Reinicia o macro (o botao Start do controle faz o mesmo).
^Esc:: ReiniciarMacro()

; Troca de modo (Normal / Hoenn 2-2-2) e ressincronizacao do 2-2-2.
F12:: TrocarModo()
F8:: Resincronizar()

#HotIf WinActive(GameWindow)
; Agendados como no controle: a acao (que pode dormir centenas de ms) roda numa
; thread propria e nunca prende a thread do movimento por baixo dela.
XButton1:: SetTimer(() => AcaoBumpers("mouse"), -1)     ; botao lateral 1: proxima acao
XButton2:: SetTimer(() => AcaoGatilhos("mouse"), -1)  ; botao lateral 2: revive no Normal (livre no 2-2-2)
#HotIf
; --- INSTANCIA UNICA ---
; O #SingleInstance so cobre o mesmo arquivo. Outra COPIA do macro leria o mesmo controle e
; mandaria teclas em dobro ao jogo, entao ha um mutex da maquina. No reload a instancia
; antiga sai logo em seguida: esperar ate 3 s pelo mutex evita falso positivo.
GarantirInstanciaUnica() {
    static mutex := 0
    mutex := DllCall("CreateMutex", "Ptr", 0, "Int", false, "Str", "Local\PKA_Macro_Hoenn222", "Ptr")
    resultado := DllCall("WaitForSingleObject", "Ptr", mutex, "UInt", 3000, "UInt")
    if (resultado != 0 && resultado != 0x80) {  ; 0 = adquirido, 0x80 = abandonado pela antiga
        LogDiagnostico("INSTANCIA_DUPLICADA", "path=" A_ScriptFullPath)
        ToolTip("Macro ja esta rodando em outra copia. Esta instancia vai fechar.")
        Sleep(3000)
        ExitApp
    }
}

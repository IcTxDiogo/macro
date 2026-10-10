#Requires AutoHotkey v2.0
; Rodizio do modo Hoenn 3-3: tres Pokemon por time, sem controle de cooldown.

IniciarRodizio33() {
    global TimeAtual, RodizioAtivo, TankDoTime2Modo33

    if (RodizioAtivo)
        return
    RodizioAtivo := true

    ; Time 1 usa {1} {2} {3}. No time 2 o tank alterna entre {4} e {5} a cada rodizio.
    if (TimeAtual == 1) {
        SetTimer(() => ExecutarRodizio33(2, 3), -1)
    } else if (TankDoTime2Modo33 == 4) {
        SetTimer(() => ExecutarRodizio33(5, 6), -1)
    } else {
        SetTimer(() => ExecutarRodizio33(4, 6), -1)
    }
}

; O tank (primeira tecla do time) ja esta fora: bate, chama o segundo e o terceiro.
ExecutarRodizio33(teclaDoSegundo, teclaDoTerceiro) {
    global RodizioAtivo, TimeAtual, TankDoTime2Modo33

    RegistrarInicioDoCombo(TimeAtual, "3-3")

    ComboSimples()
    Sleep(SleepAfterCombo)

    ControlSend("{" teclaDoSegundo "}", , GameWindow)
    Sleep(SleepAfterSwitch)
    ComboSimples()
    Sleep(SleepAfterSecondCombo)

    ControlSend("{" teclaDoTerceiro "}", , GameWindow)
    Sleep(SleepAfterSwitch)
    ComboSimples()

    if (TimeAtual == 2)
        TankDoTime2Modo33 := (TankDoTime2Modo33 == 4) ? 5 : 4

    RodizioAtivo := false
}

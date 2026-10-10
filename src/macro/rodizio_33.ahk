#Requires AutoHotkey v2.0
; Rodizio do modo Hoenn 3-3: tres Pokemon por time, sem controle de cooldown.

IniciarRodizio33() {
    global TimeAtual, RodizioAtivo, TankDoTime2Modo33

    if (RodizioAtivo) {
        return
    }
    RodizioAtivo := true

    if (TimeAtual == 1) {
        SetTimer(() => ExecutarRodizio33(1, 2, 3), -1)
    } else {
        if (TankDoTime2Modo33 == 4) {
            SetTimer(() => ExecutarRodizio33(4, 5, 6), -1)
        } else {
            SetTimer(() => ExecutarRodizio33(5, 4, 6), -1)
        }
    }
}

ExecutarRodizio33(p1, p2, p3) {
    global RodizioAtivo, TimeAtual, TankDoTime2Modo33
    ; RodizioAtivo já ativado na função pai

    RegistrarInicioDoCombo(TimeAtual, "3-3")

    ComboSimples()
    Sleep(SleepAfterCombo)

    ControlSend("{" p2 "}", , GameWindow)
    Sleep(SleepAfterSwitch)
    ComboSimples()
    Sleep(SleepAfterSecondCombo)

    ControlSend("{" p3 "}", , GameWindow)
    Sleep(SleepAfterSwitch)
    ComboSimples()

    if (TimeAtual == 2) {
        TankDoTime2Modo33 := (TankDoTime2Modo33 == 4) ? 5 : 4
    }

    RodizioAtivo := false
}

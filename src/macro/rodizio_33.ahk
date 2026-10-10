#Requires AutoHotkey v2.0
; Rodizio do modo Hoenn 3-3: tres Pokemon por time, sem controle de cooldown.

ComboComplexoHoenn33() {
    global TimeAtual, isRodizioAtivo, TankAtualTime2_33

    if (isRodizioAtivo) {
        return
    }
    isRodizioAtivo := true

    if (TimeAtual == 1) {
        SetTimer(() => ExecutarRodizio33(1, 2, 3), -1)
    } else {
        if (TankAtualTime2_33 == 4) {
            SetTimer(() => ExecutarRodizio33(4, 5, 6), -1)
        } else {
            SetTimer(() => ExecutarRodizio33(5, 4, 6), -1)
        }
    }
}

ExecutarRodizio33(p1, p2, p3) {
    global isRodizioAtivo, TimeAtual, TankAtualTime2_33
    ; isRodizioAtivo já ativado na função pai

    LogComboStart(TimeAtual, "3-3")

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
        TankAtualTime2_33 := (TankAtualTime2_33 == 4) ? 5 : 4
    }

    isRodizioAtivo := false
}

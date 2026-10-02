#Requires AutoHotkey v2.0
#Include core_actions.ahk

global TimeAtual := 1          ; Agora pode ser 1, 2 ou 3
global isRodizioAtivo := false ; Trava de segurança
global TankAtualTime2_33 := 4  ; Específico para o modo 3-3
global StatusText

; --- LÓGICA DE TROCA DE TIME (DINÂMICA) ---

TrocarTimeHoenn(totalTimes := 2) {
    global TimeAtual, TankAtualTime2_33, StatusText

    ; Ciclo de troca (1->2->3->1 ou 1->2->1)
    TimeAtual += 1
    if (TimeAtual > totalTimes) {
        TimeAtual := 1
    }

    ; Atualizar status
    if (totalTimes == 2) {
        StatusText := "Modo: Hoenn 3-3 - Time: " TimeAtual
    } else {
        StatusText := "Modo: Hoenn 2-2-2 - Time: " TimeAtual
    }

    ; Manda o primeiro do time para fora
    if (totalTimes == 3) {
        ; Lógica 2-2-2
        if (TimeAtual == 1) {
            ControlSend("{1}", , GameWindow)
        } else if (TimeAtual == 2) {
            ControlSend("{3}", , GameWindow)
        } else if (TimeAtual == 3) {
            ControlSend("{5}", , GameWindow)
        }
    } else {
        ; Lógica 3-3 (Mantendo a otimização de Tank no Time 2)
        if (TimeAtual == 1) {
            ControlSend("{1}", , GameWindow)
        } else {
            ControlSend("{" TankAtualTime2_33 "}", , GameWindow)
        }
    }
    ControlSend("{" KeyPokestop "}", , GameWindow)
    ControlSend("{" KeyFullDef "}", , GameWindow)
}

; --- MODO 3-3 (O QUE VOCÊ JÁ TINHA) ---

ComboComplexoHoenn33() {
    global TimeAtual, isRodizioAtivo, TankAtualTime2_33

    if (isRodizioAtivo) {
        return
    }

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
    isRodizioAtivo := true

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

; --- MODO 2-2-2 (NOVO MODO) ---

ComboComplexoHoenn222() {
    global TimeAtual, isRodizioAtivo

    if (isRodizioAtivo) {
        return
    }

    if (TimeAtual == 1) {
        SetTimer(() => ExecutarRodizio222(1, 2), -1)
    } else if (TimeAtual == 2) {
        SetTimer(() => ExecutarRodizio222(3, 4), -1)
    } else if (TimeAtual == 3) {
        SetTimer(() => ExecutarRodizio222(5, 6), -1)
    }
}

ExecutarRodizio222(p1, p2) {
    global isRodizioAtivo, TimeAtual, comboMrMime
    isRodizioAtivo := true

    ComboSimples() ; Bate com o p1 (que já está fora)
    Sleep(SleepAfterCombo)

    ControlSend("{" p2 "}", , GameWindow) ; Chama p2
    Sleep(SleepAfterSwitch)
    ComboSimples()

    Sleep(SleepAfterCombo)

    ; if (TimeAtual == 1 && comboMrMime == 1) {
    ;     MrMimeCombo()
    ; }

    ; Exclusivo Time 3: lança Pokémon 2 e usa skill F6
    ;if (TimeAtual == 3) {
    ;    ControlSend("{2}", , GameWindow)
    ;    Sleep(SleepAfterSwitch)
    ;    ControlSend("{" KeyPokeMoveF6 "}", , GameWindow)
    ;    ControlSend("{" KeyPokestop "}", , GameWindow)
    ;    Sleep(500)
    ;    ControlSend("{6}", , GameWindow)
    ;    Sleep(50)
    ;    ControlSend("{" KeyPokestop "}", , GameWindow)
    ;}

    isRodizioAtivo := false
}

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
            Send("{1}")
        } else if (TimeAtual == 2) {
            Send("{3}")
        } else if (TimeAtual == 3) {
            Send("{5}")
        }
    } else {
        ; Lógica 3-3 (Mantendo a otimização de Tank no Time 2)
        if (TimeAtual == 1) {
            Send("{1}")
        } else {
            Send("{" TankAtualTime2_33 "}")
        }
    }
    Send("{" KeyPokestop "}")
    Send("{" KeyFullDef "}")
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

    Send("{" p2 "}")
    Sleep(SleepAfterSwitch)
    ComboSimples()
    Sleep(SleepAfterSecondCombo)

    Send("{" p3 "}")
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
    global isRodizioAtivo
    isRodizioAtivo := true

    ComboSimples() ; Bate com o p1 (que já está fora)
    Sleep(SleepAfterCombo)

    Send("{" p2 "}") ; Chama p2
    Sleep(SleepAfterSwitch)
    ComboSimples()

    isRodizioAtivo := false
}

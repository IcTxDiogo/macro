#Requires AutoHotkey v2.0
#Include ..\config.ahk

global StatusText

^Esc:: InterruptAndReload()
SetTimer(GameLoop, 30)

; REGRA: este laco roda a cada 30 ms e e a thread do movimento. Nunca use
; Critical, Sleep nem execute acoes longas diretamente aqui: agende uma thread
; descartavel com SetTimer(..., -1). Critical on/off deixa o laco interrompivel e a
; acao longa sobe por cima dele, congelando movimento e botoes ate acabar.
GameLoop() {
    static wasd_active := Map("w", false, "a", false, "s", false, "d", false)
    static buttons_pressed := Map()
    static ultimoTick := 0
    ; Nenhum timer pode subir POR CIMA desta thread: se uma acao longa (combo,
    ; troca) a interrompesse, o laco ficaria preso embaixo dela e o AutoHotkey nao
    ; reinicia o timer enquanto a instancia antiga existe. As acoes agendadas com
    ; SetTimer(..., -1) comecam logo que esta volta termina.
    Thread("NoTimers")
    ; Diagnostico: registra quando o laco ficou parado (movimento congelado).
    agoraTick := A_TickCount
    if (ultimoTick > 0 && agoraTick - ultimoTick > 400)
        SwitchDebug("LOOP_STALL", "gap_ms=" (agoraTick - ultimoTick) " state=" Hoenn222_State " rodizio=" isRodizioAtivo)
    ultimoTick := agoraTick
    State := XInput_GetState(0)
    if !State {
        AtualizarTooltipsControle(false)
        return
    }

    isGameActive := WinExist(GameWindow)

    if (isGameActive) {
        ; Movimento analógico
        if (State.sThumbLY > DeadzoneMove || State.sThumbRY > DeadzoneMove) {
            (wasd_active["w"] ? "" : (ControlSend("{w down}", , GameWindow), wasd_active["w"] := true))
        } else if wasd_active["w"] {
            ControlSend("{w up}", , GameWindow), wasd_active["w"] := false
        }
        if (State.sThumbLY < -DeadzoneMove || State.sThumbRY < -DeadzoneMove) {
            (wasd_active["s"] ? "" : (ControlSend("{s down}", , GameWindow), wasd_active["s"] := true))
        } else if wasd_active["s"] {
            ControlSend("{s up}", , GameWindow), wasd_active["s"] := false
        }
        if (State.sThumbLX < -DeadzoneMove || State.sThumbRX < -DeadzoneMove) {
            (wasd_active["a"] ? "" : (ControlSend("{a down}", , GameWindow), wasd_active["a"] := true))
        } else if wasd_active["a"] {
            ControlSend("{a up}", , GameWindow), wasd_active["a"] := false
        }
        if (State.sThumbLX > DeadzoneMove || State.sThumbRX > DeadzoneMove) {
            (wasd_active["d"] ? "" : (ControlSend("{d down}", , GameWindow), wasd_active["d"] := true))
        } else if wasd_active["d"] {
            ControlSend("{d up}", , GameWindow), wasd_active["d"] := false
        }
    }

    ; --- BOTÕES ESPELHADOS ---

    ; Gatilhos (Triggers)
    if ((State.bRightTrigger > 200 || State.bLeftTrigger > 200) && isGameActive) {
        if !buttons_pressed.Has("Triggers") {
            SetTimer(() => Acao_Gatilhos("controller"), -1), buttons_pressed["Triggers"] := true
        }
    } else if buttons_pressed.Has("Triggers")
        buttons_pressed.Delete("Triggers")

    ; Bumpers
    if ((State.wButtons & 0x0100 || State.wButtons & 0x0200) && isGameActive) {
        if !buttons_pressed.Has("Bumpers") {
            SetTimer(() => Acao_Bumpers(), -1), buttons_pressed["Bumpers"] := true
        }
    } else if buttons_pressed.Has("Bumpers")
        buttons_pressed.Delete("Bumpers")

    ; FaceDown (Botão A / DPad Down)
    if ((State.wButtons & 0x1000 || State.wButtons & 0x0002) && isGameActive) {
        if !buttons_pressed.Has("FaceDown") {
            SetTimer(() => Acao_FaceDown(), -1), buttons_pressed["FaceDown"] := true
        }
    } else if buttons_pressed.Has("FaceDown")
        buttons_pressed.Delete("FaceDown")

    ; FaceRight (Botão X / DPad Right)
    if ((State.wButtons & 0x4000 || State.wButtons & 0x0008) && isGameActive) {
        if !buttons_pressed.Has("FaceRight") {
            SetTimer(() => Acao_FaceRight(), -1), buttons_pressed["FaceRight"] := true
        }
    } else if buttons_pressed.Has("FaceRight")
        buttons_pressed.Delete("FaceRight")

    ; FaceLeft (Botão B / DPad Left)
    if ((State.wButtons & 0x2000 || State.wButtons & 0x0004) && isGameActive) {
        if !buttons_pressed.Has("FaceLeft") {
            SetTimer(() => Acao_FaceLeft(), -1), buttons_pressed["FaceLeft"] := true
        }
    } else if buttons_pressed.Has("FaceLeft")
        buttons_pressed.Delete("FaceLeft")

    ; FaceUp (Botão Y / DPad Up)
    if ((State.wButtons & 0x8000 || State.wButtons & 0x0001) && isGameActive) {
        if !buttons_pressed.Has("FaceUp") {
            SetTimer(() => Acao_FaceUp(), -1), buttons_pressed["FaceUp"] := true
        }
    } else if buttons_pressed.Has("FaceUp")
        buttons_pressed.Delete("FaceUp")

    ; Left Thumb (Analog Click)
    if ((State.wButtons & 0x0040) && isGameActive) {
        if !buttons_pressed.Has("LeftThumb") {
            SetTimer(() => Acao_LeftThumb(), -1), buttons_pressed["LeftThumb"] := true
        }
    } else if buttons_pressed.Has("LeftThumb")
        buttons_pressed.Delete("LeftThumb")

    ; Right Thumb (Analog Click)
    if ((State.wButtons & 0x0080) && isGameActive) {
        if !buttons_pressed.Has("RightThumb") {
            SetTimer(() => Acao_RightThumb(), -1), buttons_pressed["RightThumb"] := true
        }
    } else if buttons_pressed.Has("RightThumb")
        buttons_pressed.Delete("RightThumb")

    ; Start (Reload)
    if (State.wButtons & 0x0010 && isGameActive) {
        if !buttons_pressed.Has("Start") {
            SetTimer(() => InterruptAndReload(), -1), buttons_pressed["Start"] := true
        }
    } else if buttons_pressed.Has("Start")
        buttons_pressed.Delete("Start")

    ; Back (Trocar Modo)
    if (State.wButtons & 0x0020 && isGameActive) {
        if !buttons_pressed.Has("Back") {
            SetTimer(() => TrocarModo(), -1), buttons_pressed["Back"] := true
        }
    } else if buttons_pressed.Has("Back")
        buttons_pressed.Delete("Back")

    ; Despachar os botões antes de renderizar; falhas da interface ficam isoladas.
    ; Um pedido de combo armed é uma ação do modo, não da interface: fica fora
    ; do bloco de renderização para nunca ser perdido por uma falha de tooltip.
    try {
        ProcessarComboArmadoHoenn222()
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=combo_armed", e)
    }
    try {
        ProcessarTrocaArmadaHoenn222()
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=switch_armed", e)
    }

    AtualizarTooltipsControle()
}

AtualizarTooltipsControle(connected := true) {
    static lastError := ""
    try {
        if !connected {
            AtualizarHoenn222CentralTooltip()
            if WinExist(GameWindow) {
                WinGetPos(&winX, &winY, , , GameWindow)
                CoordMode("ToolTip", "Screen")
                ToolTip("Controle Desconectado", winX + 210, winY)
            } else {
                ToolTip("Controle Desconectado", 210, 0)
            }
        } else if WinExist(GameWindow) {
            WinGetPos(&winX, &winY, , , GameWindow)
            CoordMode("ToolTip", "Screen")
            textoExibicao := StatusText
            if (ModoAtual == "Hoenn222") {
                textoExibicao := GetHoenn222Tooltip()
                textoCentral := GetHoenn222CentralTooltip(&corCentral)
                AtualizarHoenn222CentralTooltip(textoCentral, winX + PlayerOriginX + Hoenn222CenterOffsetX,
                    winY + PlayerOriginY + Hoenn222CenterOffsetY, corCentral)
            } else {
                AtualizarHoenn222CentralTooltip()
            }
            ToolTip(textoExibicao, winX + 210, winY + 30, 1)
        } else {
            AtualizarHoenn222CentralTooltip()
        }
        lastError := ""
    } catch as e {
        ; Registrar só a primeira ocorrência de uma falha persistente, não cada frame.
        errorId := e.What ":" e.Line ":" e.Message
        if (errorId != lastError) {
            lastError := errorId
            SwitchDebug("SWITCH_ERROR", "phase=tooltip", e)
        }
    }
}

; --- FUNÇÕES DO CRONÔMETRO HOENN 2-2-2 ---

GetHoenn222Tooltip() {
    global TimeAtual, Hoenn222_State, Hoenn222_ComboArmed, Hoenn222_SwitchArmed

    str := "HOENN 2-2-2 | TIME " TimeAtual "`n`n"

    if (Hoenn222_State == "WAITING_FIRST_COMBO") {
        str .= "Aguardando sincronizacao`n(execute 1 combo)`n"
    } else if (Hoenn222_State == "WAITING_TEAM_SWITCH") {
        str .= "TROCAR TIME`n`n"

        nextTeam := (TimeAtual >= 3) ? 1 : (TimeAtual + 1)
        str .= "Próx: TIME " nextTeam "`n"
    } else if (Hoenn222_State == "WAITING_COMBO") {
        str .= "COMBAR`n`n"
        str .= "Tank: " GetHoenn222TierText(TimeAtual, "tank") "`n"
        str .= "Sec:  " GetHoenn222TierText(TimeAtual, "second") "`n"
    }

    if (Hoenn222_SwitchArmed) {
        str .= "`nTROCA ARMADA`n"
    }
    if (Hoenn222_ComboArmed) {
        str .= "`nCOMBO ARMADO`n"
        ; Antecipacao segura: o macro avisa QUEM falta e o quanto o secundario
        ; ficaria atrasado, sem inventar cooldown nem estender a espera interna.
        if (Hoenn222_State == "WAITING_COMBO" && Hoenn222_CdOptimizerEnabled) {
            bloqueio := GetHoenn222ComboBloqueio(TimeAtual)
            if (bloqueio == "secundario") {
                str .= "secundario CD +" Round(Hoenn222SecondaryPendenteMs(TimeAtual, 0) / 1000, 1) "s`n"
            } else if (bloqueio == "tank") {
                str .= "tank em CD`n"
            } else if (bloqueio == "primeira_volta") {
                str .= "ritmo da 1a volta`n"
            }
        }
    }

    return str
}

GetHoenn222CentralTooltip(&color := unset) {
    global Hoenn222_State, Hoenn222_ComboArmed, Hoenn222_SwitchArmed

    color := "FFE033"
    ; Espaço largo mantém o tooltip nativo visível sem letras ou números.
    square := Chr(0x3000)
    if (Hoenn222_State == "WAITING_FIRST_COMBO") {
        ; O primeiro combo executa na hora (GetHoenn222PendingMs devolve 0), então
        ; o indicador tem de dizer o mesmo: verde = apertar agora executa agora.
        ; Amarelo aqui mentia: parecia "espere" e o botão executava assim mesmo.
        color := "33CC66"
        return square
    }

    ; O relógio continua interno; a interface mostra somente a cor.
    ; O mesmo cálculo do verde decide o combo antecipado.
    color := GetHoenn222CentralColor(GetHoenn222PendingMs(), Hoenn222_State,
        Hoenn222_ComboArmed || Hoenn222_SwitchArmed)
    return square
}

GetHoenn222CentralColor(pendingMs, state, armed := false) {
    if (pendingMs <= 0)
        return "33CC66" ; Verde com cerca de 80% de intensidade.
    if (armed)
        return "B266FF" ; Violeta: pedido armado, executa sozinho ao ficar verde.
    if (state == "WAITING_COMBO" && pendingMs <= 10000)
        return "33A3FF" ; Azul nos últimos 10 segundos de espera do tank.
    return "FFE033" ; Amarelo com cerca de 80% de intensidade por padrão.
}

AtualizarHoenn222CentralTooltip(text := "", x := 0, y := 0, color := "FFE033") {
    static lastHwnd := 0, lastColor := ""
    static lastText := "", lastX := 0, lastY := 0
    if (text == "") {
        if lastHwnd
            ToolTip(, , , 2)
        lastHwnd := 0
        lastColor := ""
        lastText := ""
        return
    }

    hwnd := lastHwnd
    if (!hwnd || !DllCall("IsWindow", "Ptr", hwnd)) {
        hwnd := ToolTip(text, x, y, 2)
        ; O controle nativo precisa liberar o tema para aceitar a cor de fundo.
        DllCall("UxTheme\SetWindowTheme", "Ptr", hwnd, "Str", "", "Str", "", "Int")
        SendMessage(0x414, 0x000000, 0, , hwnd) ; TTM_SETTIPTEXTCOLOR: preto.
        ; Recalcular após a troca do tema, antes de medir o tamanho natural.
        ToolTip(text, x, y, 2)
        WinGetPos(, , &naturalWidth, &naturalHeight, hwnd)
        margin := Buffer(16, 0)
        SendMessage(0x41B, 0, margin.Ptr, , hwnd) ; TTM_GETMARGIN.
        extraX := Max(0, 30 - naturalWidth)
        extraY := Max(0, 30 - naturalHeight)
        NumPut("Int", NumGet(margin, 0, "Int") + extraX // 2, margin, 0)
        NumPut("Int", NumGet(margin, 4, "Int") + extraY // 2, margin, 4)
        NumPut("Int", NumGet(margin, 8, "Int") + extraX - extraX // 2, margin, 8)
        NumPut("Int", NumGet(margin, 12, "Int") + extraY - extraY // 2, margin, 12)
        SendMessage(0x41A, 0, margin.Ptr, , hwnd) ; TTM_SETMARGIN: área visível quadrada.
        ToolTip(text, x, y, 2)
        lastHwnd := hwnd
        lastColor := ""
        lastText := text
        lastX := x
        lastY := y
    } else if (text != lastText || x != lastX || y != lastY) {
        ; Reposicionar somente se a janela do jogo mudar de lugar.
        ToolTip(text, x, y, 2)
        lastText := text
        lastX := x
        lastY := y
    }
    ; A contagem segue a cada frame; o indicador só repinta ao mudar de cor.
    if (color != lastColor) {
        rgb := Integer("0x" color)
        bgr := ((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 0xFF)
        SendMessage(0x413, bgr, 0, , hwnd) ; TTM_SETTIPBKCOLOR.
        WinRedraw(hwnd)
        lastColor := color
    }
}

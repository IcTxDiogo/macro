#Requires AutoHotkey v2.0
; Quadrado central colorido do indicador (verde / azul / amarelo / violeta).
; So le o tempo (FaltaParaVerdeMs) e o estado dos pedidos; nunca decide nada.

TextoDoQuadradoCentral(&color := unset) {
    global FaseAtual, ComboArmado, TrocaArmada

    color := "FFE033"
    ; Espaço largo mantém o tooltip nativo visível sem letras ou números.
    square := Chr(0x3000)
    if (FaseAtual == "WAITING_FIRST_COMBO") {
        ; O primeiro combo executa na hora (FaltaParaVerdeMs devolve 0), então
        ; o indicador tem de dizer o mesmo: verde = apertar agora executa agora.
        ; Amarelo aqui mentia: parecia "espere" e o botão executava assim mesmo.
        color := "33CC66"
        return square
    }

    ; O relógio continua interno; a interface mostra somente a cor.
    ; O mesmo cálculo do verde decide o combo antecipado.
    color := CorDoQuadrado(FaltaParaVerdeMs(), FaseAtual,
        ComboArmado || TrocaArmada)
    return square
}

CorDoQuadrado(pendingMs, state, armed := false) {
    if (pendingMs <= 0)
        return "33CC66" ; Verde com cerca de 80% de intensidade.
    if (armed)
        return "B266FF" ; Violeta: pedido armado, executa sozinho ao ficar verde.
    if (state == "WAITING_COMBO" && pendingMs <= 10000)
        return "33A3FF" ; Azul nos últimos 10 segundos de espera do tank.
    return "FFE033" ; Amarelo com cerca de 80% de intensidade por padrão.
}

DesenharQuadradoCentral(text := "", x := 0, y := 0, color := "FFE033") {
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

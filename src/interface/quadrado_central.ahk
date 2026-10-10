#Requires AutoHotkey v2.0
; Quadrado central colorido do indicador (verde / azul / amarelo / violeta).
; So le o tempo (FaltaParaVerdeMs) e o estado dos pedidos; nunca decide nada.

; Devolve o texto do quadrado e, em `cor`, a cor de fundo. Um espaco largo mantem o tooltip
; nativo visivel sem letras ou numeros.
TextoDoQuadradoCentral(&cor := unset) {
    global FaseAtual, ComboArmado, TrocaArmada

    quadrado := Chr(0x3000)
    if (FaseAtual == "WAITING_FIRST_COMBO") {
        ; O primeiro combo executa na hora (FaltaParaVerdeMs devolve 0): o indicador tem de
        ; dizer o mesmo. Amarelo aqui mentia, parecia "espere" e o botao executava assim mesmo.
        cor := "33CC66"
        return quadrado
    }
    cor := CorDoQuadrado(FaltaParaVerdeMs(), FaseAtual, ComboArmado || TrocaArmada)
    return quadrado
}

; A cor diz exatamente o que o botao vai fazer: verde executa na hora; violeta ja tem pedido
; armado; azul faltam <= 10 s no COMBAR; amarelo e o demais da espera.
CorDoQuadrado(faltaMs, fase, armado := false) {
    if (faltaMs <= 0)
        return "33CC66"
    if (armado)
        return "B266FF"
    if (fase == "WAITING_COMBO" && faltaMs <= 10000)
        return "33A3FF"
    return "FFE033"
}

; Desenha (ou atualiza) o quadrado. `texto` vazio apaga. So repinta quando a cor muda.
DesenharQuadradoCentral(texto := "", x := 0, y := 0, cor := "FFE033") {
    static ultimoHwnd := 0, ultimaCor := ""
    static ultimoTexto := "", ultimoX := 0, ultimoY := 0
    if (texto == "") {
        if ultimoHwnd
            ToolTip(, , , 2)
        ultimoHwnd := 0
        ultimaCor := ""
        ultimoTexto := ""
        return
    }

    hwnd := ultimoHwnd
    if (!hwnd || !DllCall("IsWindow", "Ptr", hwnd)) {
        hwnd := ToolTip(texto, x, y, 2)
        ; O controle nativo precisa liberar o tema para aceitar a cor de fundo.
        DllCall("UxTheme\SetWindowTheme", "Ptr", hwnd, "Str", "", "Str", "", "Int")
        SendMessage(0x414, 0x000000, 0, , hwnd) ; TTM_SETTIPTEXTCOLOR: preto.
        ; Redesenha depois da troca do tema, antes de medir o tamanho natural.
        ToolTip(texto, x, y, 2)
        TornarTooltipQuadrado(hwnd)
        ToolTip(texto, x, y, 2)
        ultimoHwnd := hwnd
        ultimaCor := ""
        ultimoTexto := texto
        ultimoX := x
        ultimoY := y
    } else if (texto != ultimoTexto || x != ultimoX || y != ultimoY) {
        ; Reposiciona so se a janela do jogo mudar de lugar.
        ToolTip(texto, x, y, 2)
        ultimoTexto := texto
        ultimoX := x
        ultimoY := y
    }
    if (cor != ultimaCor) {
        rgb := Integer("0x" cor)
        bgr := ((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 0xFF)
        SendMessage(0x413, bgr, 0, , hwnd) ; TTM_SETTIPBKCOLOR.
        WinRedraw(hwnd)
        ultimaCor := cor
    }
}

; Aumenta as margens do tooltip ate a area visivel ficar quadrada (minimo 30 x 30).
TornarTooltipQuadrado(hwnd) {
    WinGetPos(, , &larguraNatural, &alturaNatural, hwnd)
    margem := Buffer(16, 0)
    SendMessage(0x41B, 0, margem.Ptr, , hwnd) ; TTM_GETMARGIN.
    extraX := Max(0, 30 - larguraNatural)
    extraY := Max(0, 30 - alturaNatural)
    NumPut("Int", NumGet(margem, 0, "Int") + extraX // 2, margem, 0)
    NumPut("Int", NumGet(margem, 4, "Int") + extraY // 2, margem, 4)
    NumPut("Int", NumGet(margem, 8, "Int") + extraX - extraX // 2, margem, 8)
    NumPut("Int", NumGet(margem, 12, "Int") + extraY - extraY // 2, margem, 12)
    SendMessage(0x41A, 0, margem.Ptr, , hwnd) ; TTM_SETMARGIN.
}

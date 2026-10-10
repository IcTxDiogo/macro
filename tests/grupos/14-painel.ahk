; Cache visual do painel: nenhuma alteracao no relogio, verde ou agenda de acoes.
TestesPainel() {
    global
    ResetCase()
    Hoenn222_InBallWholeBlocks := true
    CoordMode("ToolTip", "Window")
    AtualizarInterface()
    Assert(ContarDesenhosDoPainel() == 1, "painel: primeira exibicao")
    Assert(Rendered[1].id == 2 && Rendered[1].coord == "Screen", "painel: quadrado usa tela antes do desenho do painel")
    loop 100 {
        MockTick += 30
        AtualizarInterface()
    }
    Assert(ContarDesenhosDoPainel() == 1, "painel: 100 ciclos iguais nao redesenham")
    Assert(!RegExMatch(TextoDoPainel(), "i)TESTE|DEBUG|EXPERIMENTAL|calibr"), "painel: sem textos temporarios")
    Assert(InStr(TextoDoPainel(), "Aguardando primeiro combo"), "painel: sincronizacao preservada")
    TimeAtual := 2
    AtualizarInterface()
    Assert(ContarDesenhosDoPainel() == 2 && InStr(Rendered[-1].text, "TIME 2"), "painel: time atualizado")
    FaseAtual := "WAITING_TEAM_SWITCH"
    AtualizarInterface()
    Assert(ContarDesenhosDoPainel() == 3 && InStr(Rendered[-1].text, "TROCAR TIME"), "painel: fase atualizada")
    MockWindowX += 80, MockWindowY += 40
    AtualizarInterface()
    Assert(ContarDesenhosDoPainel() == 4 && Rendered[-1].x == 300 && Rendered[-1].y == 90, "painel: janela movida")
    Pass("painel: cache de texto/posicao e interface limpa")

    WindowFocused := false
    CoordMode("ToolTip", "Window") ; nova thread pode ter voltado ao padrao
    quantidade := ContarDesenhosDoPainel()
    AtualizarInterface()
    Assert(ContarDesenhosDoPainel() == quantidade && Rendered[-1].id == 2 && Rendered[-1].text != "", "painel: indicadores permanecem sem foco")
    Assert(Rendered[-1].coord == "Screen", "painel: coordenadas do quadrado independem do cache do painel")
    TimeAtual := 3
    AtualizarInterface()
    Assert(ContarDesenhosDoPainel() == quantidade + 1 && InStr(Rendered[-1].text, "TIME 3"), "painel: atualiza estado tambem sem foco")
    quantidade := ContarDesenhosDoPainel()
    WindowFocused := true
    AtualizarInterface()
    Assert(ContarDesenhosDoPainel() == quantidade, "painel: retorno do foco nao recria indicador")
    WindowAvailable := false
    AtualizarInterface()
    Assert(Rendered[-1].text == "", "painel: janela ausente limpa texto antigo")
    WindowAvailable := true
    AtualizarInterface()
    Assert(InStr(Rendered[-1].text, "TROCAR TIME"), "painel: janela reaparece")
    Resincronizar()
    AtualizarInterface()
    Assert(InStr(Rendered[-1].text, "Aguardando primeiro combo"), "painel: F8 atualiza sincronizacao")
    TrocarModo()
    AtualizarInterface()
    Assert(Rendered[-1].text == "Modo: Normal", "painel: modo Normal sem informacao antiga")
    TrocarModo()
    AtualizarInterface()
    Assert(InStr(Rendered[-1].text, "HOENN 2-2-2"), "painel: retorno ao Hoenn")
    AtualizarInterface(false)
    Assert(Rendered[-1].text == "Controle Desconectado", "painel: desconexao atualiza")
    quantidade := ContarDesenhosDoPainel()
    AtualizarInterface(false)
    Assert(ContarDesenhosDoPainel() == quantidade, "painel: desconexao estavel nao redesenha")
    AtualizarInterface()
    Assert(InStr(Rendered[-1].text, "HOENN 2-2-2"), "painel: reconexao atualiza")
    Pass("painel: indicadores sem foco, coordenadas de tela, ocultacao, F8 e modos")

    ResetCase("WAITING_COMBO")
    AplicarCast(1, true, MockTick)
    MockTick += Hoenn222_LatencyMs + 123 ; medir depois do congelamento inicial do cast
    PedirCombo()
    AtualizarInterface()
    textoAntes := TextoDoPainel()
    faltaAntes := FaltaParaVerdeMs()
    loop 3 {
        MockTick += 30
        AtualizarInterface()
    }
    Assert(TextoDoPainel() == textoAntes && ContarDesenhosDoPainel() == 1, "painel: contador inteiro evita decimos por ciclo")
    Assert(FaltaParaVerdeMs() == faltaAntes - 90, "painel: milissegundos internos preservados")
    MockTick += 1000
    AtualizarInterface()
    Assert(TextoDoPainel() != textoAntes && ContarDesenhosDoPainel() == 2, "painel: contador atualiza em segundos")
    MockTick += FaltaParaVerdeMs() - 1
    GameLoop()
    Assert(Scheduled.Length == 0, "painel: armado nao dispara cedo")
    MockTick += 1
    GameLoop()
    cor := ""
    TextoDoQuadradoCentral(&cor)
    Assert(cor == "33CC66" && Scheduled.Length == 1, "painel: verde agenda no mesmo ciclo sem atraso")
    Scheduled[1].Call()
    AtualizarInterface()
    Assert(!InStr(TextoDoPainel(), "COMBO ARMADO"), "painel: pedido consumido atualiza")
    Pass("painel: contador visual sem atraso no verde ou pedido armado")

    ResetCase()
    FaultTooltip := true
    AtualizarInterface()
    FaultTooltip := false
    AtualizarInterface()
    Assert(ContarDesenhosDoPainel() == 1, "painel: falha de desenho nao envenena cache")
    Pass("painel: cache so confirma desenho bem sucedido")
}

ContarDesenhosDoPainel() {
    total := 0
    for desenho in Rendered
        if (desenho.id == 1)
            total++
    return total
}

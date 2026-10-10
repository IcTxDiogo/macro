; Tema: Indicador e decisao do botao leem o mesmo pendente.
TestesIndicador() {
    global

; --- INDICADOR E DECISAO DO BOTAO: A MESMA RESPOSTA ---
    ; Regra do jogador: verde = o botao executa na hora; qualquer outra cor
    ; = o botao NAO executa na hora (arma e espera). O quadrado e o botao
    ; leem o mesmo pendente, entao nao podem divergir.

    ; Primeiro combo: executa na hora, portanto tem de estar verde. Amarelo
    ; aqui parecia "espere" e o botao executava assim mesmo.
    ResetCase("WAITING_FIRST_COMBO", 0, 0)
    corPrimeiro := ""
    TextoDoQuadradoCentral(&corPrimeiro)
    Assert(corPrimeiro == "33CC66", "M primeiro combo: indicador verde, cor=" corPrimeiro)
    PedirCombo()
    Assert(Scheduled.Length == 1 && !ComboArmado, "M primeiro combo executa na hora")

    ; Para varios instantes de uma volta real, cor e acao concordam.
    ResetCase("WAITING_COMBO", 0, 0)
    AplicarCast(1, false, MockTick - 20000)
    DefinirTaxaDeRecuperacao(SlotDoPokemon(1, false), Hoenn222_RateInBall, MockTick - 17000)
    RegistrarTrocaDeTime(3, 1, MockTick)
    FaseAtual := "WAITING_COMBO"
    InicioDaFaseTick := MockTick
    entrada := MockTick
    prontoReal := MsAteCastSeguro(SlotDoPokemon(1, false), MockTick)
    Assert(prontoReal > 5000, "M cenario: o tank entra com CD correndo (" Round(prontoReal) "ms)")
    divergiu := ""
    verdeEm := -1
    passo := 0
    while (passo <= prontoReal + 2000) {
        MockTick := entrada + passo
        cor := ""
        TextoDoQuadradoCentral(&cor)
        pend := FaltaParaVerdeMs()
        if ((cor == "33CC66") != (pend <= 0))
            divergiu .= " t=" passo ":cor=" cor "/pend=" Round(pend)
        if (verdeEm < 0 && pend <= 0)
            verdeEm := passo
        passo += 250
    }
    Assert(divergiu == "", "M cor e decisao divergiram:" divergiu)
    ; O verde nunca vem antes de o tank estar de fato pronto. O instante
    ; verdadeiro e CD + margem; a varredura em passos de 250ms so pode
    ; passar dele por menos de um passo.
    Assert(verdeEm >= prontoReal - 1 && verdeEm < prontoReal + 250,
        "M verde em " verdeEm "ms, tank pronto de verdade em " Round(prontoReal) "ms")
    Pass("M o indicador e a decisao do botao leem o mesmo pendente; o verde nao antecipa o CD")

    ; Margem conta desde o instante em que o CD zerou, nao para sempre.
    ResetCase("WAITING_COMBO", 0, 0)
    slotM := SlotDoPokemon(1, false)
    AplicarCast(1, false, MockTick)
    MockTick += Hoenn222_LatencyMs + CooldownBaseMs(1, false)   ; CD zera aqui
    Assert(MsAteCastSeguro(slotM, MockTick) == Hoenn222_MarginMs, "N no instante em que zera ainda falta a margem")
    MockTick += Hoenn222_MarginMs - 50
    Assert(MsAteCastSeguro(slotM, MockTick) == 50, "N faltam 50ms da margem")
    MockTick += 50
    Assert(MsAteCastSeguro(slotM, MockTick) == 0, "N margem cumprida: pronto")
    MockTick += 600000
    Assert(MsAteCastSeguro(slotM, MockTick) == 0, "N CD zerado ha muito tempo continua pronto, sem exigir margem de novo")
    Pass("N a margem conta a partir do instante em que o CD zerou")

    ; Pedido armado e visivel no quadrado: violeta, e vira verde ao disparar.
    ResetCase("WAITING_COMBO", 0, 0)
    AplicarCast(1, true, MockTick)
    corAntes := ""
    TextoDoQuadradoCentral(&corAntes)
    Assert(corAntes != "33CC66" && corAntes != "B266FF", "O sem pedido, secundario em CD: cor de espera " corAntes)
    PedirCombo()
    Assert(ComboArmado, "O pressionar antes do verde arma")
    corArmado := ""
    TextoDoQuadradoCentral(&corArmado)
    Assert(corArmado == "B266FF", "O armado e visivel no quadrado, cor=" corArmado)
    Pass("O o pedido armado muda a cor do quadrado")
}

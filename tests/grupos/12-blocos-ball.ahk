; Tema: experimento por blocos completos, separado dos testes do modelo continuo.
TestesBlocosBall() {
    global
    blocoConfigurado := Hoenn222_InBallBlockMs
    ; Valida o ensaio de 1 s e preserva a possibilidade de voltar ao de 2 s.
    for bloco in [1000, 2000] {
        Hoenn222_InBallBlockMs := bloco
        credito := bloco * Hoenn222_RateInBall
        ResetCase("WAITING_COMBO")
        Hoenn222_InBallWholeBlocks := true
        Hoenn222_MarginMs := 0
        Hoenn222_ExitLatencySecondaryMs := 0
        slot := SlotDoPokemon(1, true)
        CooldownRestanteMs[slot] := 5000
        inicio := MockTick
        loop Floor((bloco - 1) / 30) {
            MockTick += 30
            Assert(CdOf(slot) == 5000, "AG leituras frequentes nao completam nem perdem o bloco")
        }
        MockTick := inicio + bloco - 1
        Assert(CdOf(slot) == 5000, "AG bloco incompleto nao credita cooldown")
        MockTick++
        Assert(CdOf(slot) == 5000 - credito, "AG bloco completo credita o valor proporcional a taxa")
        MockTick := inicio + 1.75 * bloco
        CdOf(slot)
        DefinirTaxaDeRecuperacao(slot, Hoenn222_RateInBall, MockTick)
        Assert(CooldownFracaoBallMs[slot] == 0.75 * bloco, "AG repetir taxa Ball nao reinicia o bloco")
        DefinirTaxaDeRecuperacao(slot, Hoenn222_RateOutOfBall, MockTick)
        Assert(CooldownFracaoBallMs[slot] == 0, "AG sair descarta a fracao sem credita-la")
        MockTick += 500
        Assert(CdOf(slot) == 4500 - credito, "AG fora continua recuperando continuamente")
        DefinirTaxaDeRecuperacao(slot, Hoenn222_RateInBall, MockTick)
        MockTick += bloco - 1
        Assert(CdOf(slot) == 4500 - credito, "AG nova entrada comeca um bloco novo")
        MockTick++
        Assert(CdOf(slot) == 4500 - 2 * credito, "AG nova entrada completa o proprio bloco")
        Pass("AG blocos sobrevivem a leituras, descartam fracao na saida e preservam recuperacao fora (" bloco " ms)")

        ResetCase("WAITING_COMBO")
        Hoenn222_InBallWholeBlocks := true
        Hoenn222_MarginMs := 0
        slot := SlotDoPokemon(1, true)
        CooldownRestanteMs[slot] := 1.5 * credito
        inicio := MockTick
        MockTick += 500
        Assert(MsAteCastSeguro(slot, MockTick) == 2 * bloco - 500, "AH previsao espera dois blocos, descontando a fracao")
        MockTick := inicio + 2 * bloco - 1
        Assert(CdOf(slot) == 0.5 * credito, "AH ainda falta CD antes do segundo bloco")
        MockTick++
        Assert(CdOf(slot) == 0 && CooldownZerouTick[slot] == MockTick, "AH zero registrado na borda exata do bloco")
        Pass("AH previsao e acumulador concordam no instante de zero (" bloco " ms)")

        ResetCase("WAITING_COMBO")
        Hoenn222_InBallWholeBlocks := true
        Hoenn222_MarginMs := 0
        Hoenn222_ExitLatencySecondaryMs := 0
        slot := SlotDoPokemon(1, true)
        blocosNecessarios := Ceil((SleepAfterTankCombo + 300) / bloco)
        CooldownRestanteMs[slot] := (blocosNecessarios - 1) * credito + SleepAfterSwitch + 200
        ; Mantem a borda de liberacao em 300 ms com o intervalo fisico do config.
        CooldownFracaoBallMs[slot] := blocosNecessarios * bloco - SleepAfterTankCombo - 300
        Assert(FaltaParaComboViavelMs(1) == 300, "AI combo espera o bloco que faltaria ao secundario")
        Assert(CooldownPendenteDoSecundarioMs(1, 299) == 200, "AI previsao nao usa uma fracao de bloco")
        Assert(CooldownPendenteDoSecundarioMs(1, 300) == 0, "AI previsao inclui o bloco que completa durante o combo")
        Assert(QuemBloqueiaOCombo(1) == "secundario", "AI painel concorda com a liberacao")
        MockTick += 300
        Assert(FaltaParaComboViavelMs(1) == 0, "AI libera exatamente na previsao")
        MockTick += SleepAfterTankCombo
        RegistrarChamadaDoSecundario(1)
        MockTick += SleepAfterSwitch
        Assert(MsAteCastSeguro(slot, MockTick) == 0, "AI cast do secundario fica viavel com sleeps preservados")
        Pass("AI verde, painel e previsao usam a fracao real do bloco do secundario (" bloco " ms)")

        ; Rotacao inteira: avalia o verde e as transicoes, nao apenas uma formula espelhada.
        ResetCase("WAITING_FIRST_COMBO")
        Hoenn222_InBallWholeBlocks := true
        Hoenn222_MarginMs := 0
        Hoenn222_ExitLatencySecondaryMs := 0
        ResetarCooldowns(MockTick)
        chamada := 0
        castSec := 0
        voltas := 0
        casts := 0
        timeDoCombo := 1
        fim := MockTick + 420000
        while (MockTick < fim) {
            if (FaseAtual == "WAITING_FIRST_COMBO" || (FaseAtual == "WAITING_COMBO" && FaltaParaVerdeMs() <= 0)) {
                timeDoCombo := TimeAtual
                if (TimeAtual == 1)
                    voltas++
                Assert(MsAteCastSeguro(SlotDoPokemon(timeDoCombo, false), MockTick) == 0, "AJ tank liberado com CD modelado pendente")
                FaseAtual := "WAITING_TEAM_SWITCH"
                InicioDaFaseTick := MockTick
                RegistrarCast(timeDoCombo)
                chamada := MockTick + SleepAfterTankCombo
                castSec := chamada + SleepAfterSwitch
                casts++
            }
            if (chamada > 0 && MockTick >= chamada) {
                RegistrarChamadaDoSecundario(timeDoCombo)
                chamada := 0
            }
            if (castSec > 0 && MockTick >= castSec) {
                Assert(MsAteCastSeguro(SlotDoPokemon(timeDoCombo, true), MockTick) == 0, "AJ secundario liberado com CD modelado pendente")
                RegistrarCast(timeDoCombo, true)
                castSec := 0
                casts++
            }
            if (FaseAtual == "WAITING_TEAM_SWITCH" && FaltaParaVerdeMs() <= 0)
                TrocarDeTime()
            MockTick += 10
        }
        Assert(voltas >= 5 && casts >= 30, "AJ rotacao simulou os seis Pokemon em varias voltas")
        Assert(InStr(DebugText(), "modelo_ball=blocos_" Format("{:g}", bloco / 1000) "s"), "AJ log identifica o experimento")
        Assert(InStr(DebugText(), "bloco_ball_ms=" bloco " credito_ball_ms=" Round(credito)), "AJ log registra duracao e credito do bloco")
        Assert(!InStr(TextoDoPainel(), "TESTE:"), "AJ painel de producao sem aviso de teste")
        Pass("AJ rotacao completa por blocos libera tank e secundario somente quando o modelo permite (" bloco " ms)")
        Hoenn222_InBallWholeBlocks := false
    }
    Hoenn222_InBallBlockMs := blocoConfigurado
}

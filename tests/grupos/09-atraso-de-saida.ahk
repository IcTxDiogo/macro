; Tema: Atraso de saida proprio do secundario.
TestesAtrasoDeSaida() {
    global

    ; AD: atraso de saida proprio do secundario (chamada). Congela o CD dele depois da
    ; chamada, entra no plano e na tolerancia do combo; o tank e a margem nao mudam.
    ResetCase("WAITING_COMBO", 0, 0)
    LBaseAD := PlanejarVolta().L
    exitS := 1100
    ResetCase("WAITING_COMBO", 0, 0)
    Hoenn222_ExitLatencySecondaryMs := exitS
    ToleranciaDoSecundarioMs := CalcularToleranciaDoSecundarioMs()
    slotTank := SlotDoPokemon(1, false)
    slotSec := SlotDoPokemon(1, true)
    Assert(ToleranciaDoSecundarioMs == 0.5 * SleepAfterTankCombo + Max(0, SleepAfterSwitch - exitS) - Hoenn222_MarginMs
        , "AD a tolerancia do combo usa o atraso de saida do secundario: " ToleranciaDoSecundarioMs)
    ; Chamada do secundario com CD pendente: so volta a recuperar exitS depois dela.
    AplicarCast(1, true, MockTick)
    cdSecAD := CdOf(slotSec)
    RegistrarChamadaDoSecundario(1)
    Assert(MsAteCastSeguro(slotSec, MockTick) == exitS + cdSecAD + Hoenn222_MarginMs
        , "AD apos a chamada o CD do secundario congela exitS: " MsAteCastSeguro(slotSec, MockTick))
    MockTick += exitS
    Assert(MsAteCastSeguro(slotSec, MockTick) == cdSecAD + Hoenn222_MarginMs, "AD passado o atraso o CD volta a correr")
    ; O tank segue com o atraso da troca de time (LatencyMs), nao com o do secundario.
    ResetCase("WAITING_COMBO", 0, 0)
    Hoenn222_ExitLatencySecondaryMs := exitS
    AplicarCast(1, false, MockTick)
    cdTankAD := CdOf(slotTank)
    RegistrarTrocaDeTime(3, 1, MockTick)
    Assert(MsAteCastSeguro(slotTank, MockTick) == Hoenn222_LatencyMs + cdTankAD + Hoenn222_MarginMs
        , "AD o tank mantem o atraso da troca de time: " MsAteCastSeguro(slotTank, MockTick))
    ; O plano cresce pouco e cada Pokemon recupera CD + o atraso do papel + margem.
    ResetCase("WAITING_COMBO", 0, 0)
    Hoenn222_ExitLatencySecondaryMs := exitS
    planoE := PlanejarVolta()
    Assert(planoE.L > LBaseAD && planoE.L < LBaseAD + 3000, "AD a volta cresce pouco: " Round(LBaseAD) " -> " Round(planoE.L))
    Assert(Abs(planoE.Janelas[1] + planoE.Janelas[2] + planoE.Janelas[3] - planoE.L) < 1, "AD as janelas fecham em L")
    for k in [1, 2, 3] {
        FtS := planoE.SecFora[k]
        recS := (FtS - Hoenn222_LatencyMs - exitS) + (planoE.L - FtS) * Hoenn222_RateInBall
        Assert(recS >= CooldownBaseMs(k, true) + Hoenn222_MarginMs - 0.5, "AD secundario " k " recupera CD + saida + margem: " Round(recS))
        FtT := planoE.TankFora[k]
        recT := (FtT - 2 * Hoenn222_LatencyMs) + (planoE.L - FtT) * Hoenn222_RateInBall
        Assert(recT >= CooldownBaseMs(k, false) + Hoenn222_MarginMs - 0.5, "AD tank " k " recupera CD + margem base: " Round(recT))
    }
    Pass("AD atraso de saida do secundario: congelamento, tolerancia e plano; tank inalterado (volta " Round(LBaseAD) " -> " Round(planoE.L) ")")
}

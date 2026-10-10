; Tema: Persistencia do estado entre recargas.
TestesPersistencia() {
    global
    ; --- PERSISTENCIA: O RELOAD CONTINUA DE ONDE PAROU ---
    ResetCase("WAITING_COMBO", 0, 5000)
    ArquivoDeEstado := A_ScriptDir "\estado-teste.txt"
    if FileExist(ArquivoDeEstado)
        FileDelete(ArquivoDeEstado)
    TimeAtual := 2
    TankJaCastou := Map(1, true, 2, false, 3, true)
    AplicarCast(1, false, MockTick - 30000)
    AplicarCast(1, true, MockTick - 20000)
    cdTankAG := CdOf(SlotDoPokemon(1, false))
    cdSecAG := CdOf(SlotDoPokemon(1, true))
    SalvarEstado()
    Assert(FileExist(ArquivoDeEstado), "AG o estado foi gravado")
    ; Reload simulado: tudo volta ao padrao e o arquivo devolve o modelo.
    ResetCase("WAITING_FIRST_COMBO", 0, 0)
    TimeAtual := 1
    TankJaCastou := Map(1, false, 2, false, 3, false)
    Assert(CdOf(SlotDoPokemon(1, false)) == 0, "AG antes de restaurar o modelo esta zerado")
    Assert(RestaurarEstado(MockTick + 20000, DateAdd(A_Now, 20, "Seconds")), "AG restaurou um estado de 20 s")
    Assert(TimeAtual == 2 && FaseAtual == "WAITING_COMBO" && ModoAtual == "Hoenn222", "AG time, fase e modo voltaram")
    Assert(!TankJaCastou[2] && TankJaCastou[1] && TankJaCastou[3], "AG a 1a volta nao recomeca para quem ja castou")
    Assert(Abs(CooldownRestanteMs[SlotDoPokemon(1, false)] - cdTankAG) < 1 && Abs(CooldownRestanteMs[SlotDoPokemon(1, true)] - cdSecAG) < 1, "AG cooldowns restaurados")
    Assert(InStr(DebugText(), "STATE_RESTORED"), "AG registrado no log")
    ; Estado velho, de outro boot ou corrompido nunca e restaurado.
    ResetCase("WAITING_FIRST_COMBO", 0, 0)
    Assert(!RestaurarEstado(MockTick + 400000, DateAdd(A_Now, 400, "Seconds")) && TimeAtual == 1, "AG estado de 400 s e ignorado")
    Assert(InStr(DebugText(), "reason=too_old"), "AG motivo registrado")
    Assert(!RestaurarEstado(MockTick - 5000, DateAdd(A_Now, 20, "Seconds")), "AG ticks andaram para tras: outro boot")
    FileOpen(ArquivoDeEstado, "w").Write("lixo`nversao=1`n")
    Assert(!RestaurarEstado(MockTick, A_Now) && TimeAtual == 1 && CdOf(1) == 0, "AG arquivo corrompido e ignorado sem alterar nada")
    ; Desligado no config: nao grava nem restaura.
    FileDelete(ArquivoDeEstado)
    Hoenn222_RestoreStateOnReload := false
    SalvarEstado()
    Assert(!FileExist(ArquivoDeEstado), "AG desligado: nao grava")
    Hoenn222_RestoreStateOnReload := true
    Pass("AG o estado do modelo sobrevive ao reload; velho, outro boot e corrompido sao ignorados")
}

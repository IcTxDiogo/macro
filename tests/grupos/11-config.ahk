; Tema: Validacao do config.ahk.
TestesConfig() {
    global
    ; --- VALIDACAO DO CONFIG: PROBLEMAS VIRAM AVISO NO PAINEL ---
    ResetCase()
    problemasAF := ValidarConfig()
    Assert(problemasAF.Length == 0, "AF config padrao sem problemas: " Join(problemasAF))
    tiersTank := Hoenn222_TankTier
    Hoenn222_TankTier := Map(1, "SRR", 2, "SR")
    problemasAF := ValidarConfig()
    Assert(InStr(Join(problemasAF), "'SRR'") && InStr(Join(problemasAF), "time 3 nao definido"), "AF tier errado e time ausente: " Join(problemasAF))
    Hoenn222_TankTier := tiersTank
    margemAF := Hoenn222_MarginMs
    Hoenn222_MarginMs := -5
    Assert(InStr(Join(ValidarConfig()), "Hoenn222_MarginMs invalido"), "AF margem negativa")
    Hoenn222_MarginMs := margemAF
    pisosAF := Hoenn222_MinLureMs
    Hoenn222_MinLureMs := Map(1, "abc", 2, 0, 3, 0)
    Assert(InStr(Join(ValidarConfig()), "Hoenn222_MinLureMs[1] invalido"), "AF piso invalido avisa em vez de valer 0 em silencio")
    Hoenn222_MinLureMs := pisosAF
    teclaAF := KeyCombo
    KeyCombo := ""
    Assert(InStr(Join(ValidarConfig()), "KeyCombo vazia"), "AF tecla vazia")
    KeyCombo := teclaAF
    ; O painel mostra os problemas (ate 3 linhas, fixos).
    ProblemasDeConfig := ["problema um", "problema dois", "problema tres", "problema quatro"]
    Assert(InStr(TextoDosProblemasDeConfig(), "!! CONFIG !!") && InStr(TextoDosProblemasDeConfig(), "+1 (ver log)"), "AF painel mostra 3 e resume o resto")
    ProblemasDeConfig := []
    Assert(TextoDosProblemasDeConfig() == "", "AF sem problemas o painel nao muda")
    Assert(InStr(DebugText(), "CONFIG_PROBLEMA"), "AF problemas vao para o log")
    Pass("AF config invalido vira aviso no painel e linha no log")

    blocoAnterior := Hoenn222_InBallBlockMs
    sleepAnterior := SleepAfterSwitch
    cdAnterior := Hoenn222_CdByTier["SR"]
    for valor in [0, -2000, "abc"] {
        Hoenn222_InBallBlockMs := valor
        Assert(InStr(Join(ValidarConfig()), "Hoenn222_InBallBlockMs invalido"), "config: bloco invalido detectado")
        Assert(!ConfigDeTempoEstaValida(), "config: bloco invalido impede inicializacao")
    }
    Hoenn222_InBallBlockMs := blocoAnterior
    SleepAfterSwitch := -1
    Assert(!ConfigDeTempoEstaValida() && InStr(Join(ValidarConfig()), "SleepAfterSwitch invalido"), "config: sleep negativo recusado")
    SleepAfterSwitch := sleepAnterior
    for valor in [0, -43, "abc"] {
        Hoenn222_CdByTier["SR"] := valor
        Assert(!ConfigDeTempoEstaValida() && InStr(Join(ValidarConfig()), "CD do tier 'SR' invalido"), "config: CD invalido recusado")
    }
    Hoenn222_CdByTier["SR"] := cdAnterior
    Assert(ConfigDeTempoEstaValida(), "config: parametros validos preservados")
    Pass("config: bloco, sleeps e CDs invalidos detectados antes dos calculos")

}

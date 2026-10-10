#Requires AutoHotkey v2.0
; Confere o config.ahk ao carregar. Um valor invalido nao derruba o macro (cada modulo tem
; seu fallback), mas ficava so no log; aqui os problemas viram texto curto para o painel.

global ProblemasDeConfig := ValidarConfig()

; Lista de problemas (textos curtos, no maximo ~60 caracteres). Vazia = config ok.
ValidarConfig() {
    problemas := []
    try {
        ValidarTiers(problemas)
        ValidarNumerosMs(problemas)
        ValidarPisos(problemas)
        ValidarTeclas(problemas)
    } catch as e {
        problemas.Push("config ilegivel: " e.Message)
    }
    for problema in problemas
        LogDiagnostico("CONFIG_PROBLEMA", "detalhe=" problema)
    return problemas
}

ValidarTiers(problemas) {
    global Hoenn222_TankTier, Hoenn222_SecondTier, Hoenn222_CdByTier
    if (!IsObject(Hoenn222_CdByTier) || Hoenn222_CdByTier.Count == 0) {
        problemas.Push("Hoenn222_CdByTier vazio")
        return
    }
    for papel, tiers in Map("tank", Hoenn222_TankTier, "secundario", Hoenn222_SecondTier) {
        for time in [1, 2, 3] {
            if (!IsObject(tiers) || !tiers.Has(time)) {
                problemas.Push("tier do " papel " do time " time " nao definido")
            } else if (!TierExisteNaTabela(tiers[time])) {
                problemas.Push("tier '" tiers[time] "' (" papel " time " time ") fora da tabela")
            }
        }
    }
}

; Mesma comparacao do CooldownBaseMs: sem diferenca de maiusculas.
TierExisteNaTabela(rotulo) {
    global Hoenn222_CdByTier
    for tier, cooldownMs in Hoenn222_CdByTier {
        if (StrLower(tier) = StrLower(rotulo))
            return true
    }
    return false
}

ValidarNumerosMs(problemas) {
    global Hoenn222_LatencyMs, Hoenn222_ExitLatencySecondaryMs, Hoenn222_MarginMs
    global Hoenn222_EmergencyWindowMs, Hoenn222_CdDefaultMs, Hoenn222_RateInBall, Hoenn222_RateOutOfBall
    for nome, valor in Map("Hoenn222_LatencyMs", Hoenn222_LatencyMs,
        "Hoenn222_ExitLatencySecondaryMs", Hoenn222_ExitLatencySecondaryMs,
        "Hoenn222_MarginMs", Hoenn222_MarginMs, "Hoenn222_EmergencyWindowMs", Hoenn222_EmergencyWindowMs) {
        if (!IsNumber(valor) || valor < 0)
            problemas.Push(nome " invalido: " valor)
    }
    for nome, valor in Map("Hoenn222_CdDefaultMs", Hoenn222_CdDefaultMs,
        "Hoenn222_RateInBall", Hoenn222_RateInBall, "Hoenn222_RateOutOfBall", Hoenn222_RateOutOfBall) {
        if (!IsNumber(valor) || valor <= 0)
            problemas.Push(nome " invalido: " valor)
    }
}

; Pisos de conforto: PisoDoConfigMs trata invalido como 0 em silencio; aqui avisa.
ValidarPisos(problemas) {
    global Hoenn222_MinLureMs, Hoenn222_MinSecondaryOutMs
    for nome, mapa in Map("Hoenn222_MinLureMs", Hoenn222_MinLureMs, "Hoenn222_MinSecondaryOutMs", Hoenn222_MinSecondaryOutMs) {
        if (!IsObject(mapa)) {
            problemas.Push(nome " nao e um Map")
            continue
        }
        for time, valor in mapa {
            if (!IsNumber(valor) || valor < 0)
                problemas.Push(nome "[" time "] invalido: " valor)
        }
    }
}

ValidarTeclas(problemas) {
    global KeyPokestop, KeyMedicine, KeyCombo, KeyFullAtk, KeyFullDef, KeyRevive
    global KeyBuffMove, KeyPotion, KeyChangeTarget, KeyBallSpecial
    for nome, valor in Map("KeyPokestop", KeyPokestop, "KeyMedicine", KeyMedicine, "KeyCombo", KeyCombo,
        "KeyFullAtk", KeyFullAtk, "KeyFullDef", KeyFullDef, "KeyRevive", KeyRevive, "KeyBuffMove", KeyBuffMove,
        "KeyPotion", KeyPotion, "KeyChangeTarget", KeyChangeTarget, "KeyBallSpecial", KeyBallSpecial) {
        if (valor = "")
            problemas.Push(nome " vazia")
    }
}

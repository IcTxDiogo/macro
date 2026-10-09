#Requires AutoHotkey v2.0
#Include core_actions.ahk
#Include logger.ahk

global TimeAtual := 1          ; Time solicitado (1, 2 ou 3); entrada visual não confirmada
global isRodizioAtivo := false ; Trava de segurança
global TankAtualTime2_33 := 4  ; Específico para o modo 3-3
global StatusText

; --- VARIÁVEIS DO CRONÔMETRO HOENN 2-2-2 ---
global Hoenn222_State := "WAITING_FIRST_COMBO"
global Hoenn222_StateStartTick := 0
global Hoenn222_ExecutionId := 0

global Hoenn222_LastTeamSwitchTick := 0
global Hoenn222_LastComboStartTick := 0
global Hoenn222_P2CallTick := 0

; --- COMBO 2-2-2: PEDIDO ANTECIPADO E EMERGENCIA ---
; Hoenn222_ComboArmed: existe um pedido de combo aguardando o contador ficar verde.
; Hoenn222_ComboArmedTeam: time para o qual o pedido foi feito; nunca executa em outro.
; Hoenn222_ComboLastPressTick: base do duplo acionamento (emergencia).
global Hoenn222_ComboArmed := false
global Hoenn222_ComboArmedTeam := 0
global Hoenn222_ComboLastPressTick := 0
global Hoenn222_CdAvisoFeito := false
global Hoenn222_PlanCache := unset

global Hoenn222_TankEnterTick := Map(1, 0, 2, 0, 3, 0)
global Hoenn222_P2EnterTick := Map(1, 0, 2, 0, 3, 0)
global Hoenn222_TeamDuration := Map(1, 0, 2, 0, 3, 0)
global Hoenn222_TeamUsageInterval := Map(1, 0, 2, 0, 3, 0)
global Hoenn222_TeamLastUsageTick := Map(1, 0, 2, 0, 3, 0)

; --- LÓGICA DE TROCA DE TIME (DINÂMICA) ---

TrocarTimeHoenn(totalTimes := 2) {
    global TimeAtual, TankAtualTime2_33, StatusText
    global GameWindow, KeyPokestop, KeyFullDef
    global Hoenn222_State, Hoenn222_StateStartTick, Hoenn222_LastTeamSwitchTick
    global Hoenn222_ComboArmed, Hoenn222_ComboArmedTeam

    ; Apenas validação/envio/commit são atômicos. A interface não participa da decisão.
    previousCritical := A_IsCritical
    Critical("On")
    try {
        switchTick := A_TickCount
        previousTeam := TimeAtual
        SwitchDebug("SWITCH_REQUESTED", "from=" previousTeam " total=" totalTimes " state=" Hoenn222_State)
        if ((totalTimes != 2 && totalTimes != 3) || previousTeam < 1 || previousTeam > 3) {
            SwitchDebug("SWITCH_REJECTED", "reason=invalid_team total=" totalTimes " from=" previousTeam)
            return false
        }
        if (totalTimes == 3 && Hoenn222_LastTeamSwitchTick > 0
            && switchTick - Hoenn222_LastTeamSwitchTick < 1000) {
            SwitchDebug("SWITCH_REJECTED", "reason=debounce elapsed_ms=" (switchTick - Hoenn222_LastTeamSwitchTick))
            return false
        }
        nextTeam := (previousTeam >= totalTimes) ? 1 : previousTeam + 1
        nextKey := (totalTimes == 3) ? (nextTeam * 2 - 1) : ((nextTeam == 1) ? 1 : TankAtualTime2_33)
        previousSwitchTick := Hoenn222_LastTeamSwitchTick
        previousState := Hoenn222_State
        previousStateStartTick := Hoenn222_StateStartTick

        ; A janela pode desaparecer entre a validação e ControlSend: tratar ambos os casos.
        if !WinExist(GameWindow) {
            SwitchDebug("SWITCH_REJECTED", "reason=no_window window=" GameWindow)
            return false
        }
        SwitchDebug("SWITCH_COMMAND_BEGIN", "from=" previousTeam " to=" nextTeam " key=" nextKey " window=" GameWindow)
        try {
            ControlSend("{" nextKey "}", , GameWindow)
        } catch as e {
            SwitchDebug("SWITCH_COMMAND_END", "result=failed to=" nextTeam " key=" nextKey)
            SwitchDebug("SWITCH_ERROR", "phase=primary_command", e)
            SwitchDebug("SWITCH_REJECTED", "reason=send_failed")
            return false
        }
        SwitchDebug("SWITCH_COMMAND_END", "result=requested_only to=" nextTeam " key=" nextKey)

        ; Representa o envio solicitado, NÃO uma confirmação visual de entrada no jogo.
        TimeAtual := nextTeam
        if (totalTimes == 3) {
            Hoenn222_LastTeamSwitchTick := switchTick
            Hoenn222_State := "WAITING_COMBO"
            Hoenn222_StateStartTick := switchTick
            ; A dupla anterior inteira volta para a Ball; so o tank da dupla nova
            ; sai, e LevancyMs depois do comando enviado.
            Hoenn222CdTrocaTime(previousTeam, nextTeam, switchTick)
        }
        SwitchDebug("SWITCH_STATE_UPDATED", "requested_team=" TimeAtual " visual_confirmation=unknown")
    } finally {
        Critical(previousCritical)
    }

    ; Preservar a sequência original; uma falha auxiliar não cancela as ações seguintes.
    for key in [KeyPokestop, KeyFullDef] {
        try {
            ControlSend("{" key "}", , GameWindow)
        } catch as e {
            SwitchDebug("SWITCH_ERROR", "phase=post_command key=" key, e)
        }
    }
    if (totalTimes == 3) {
        ; O pedido pendente pertencia ao time que acabou de sair.
        CancelarComboArmadoHoenn222("team_switch")
        AtualizarCronometroAposTroca(nextTeam, previousTeam, switchTick, previousSwitchTick)
    }
    try {
        StatusText := "Modo: Hoenn " ((totalTimes == 3) ? "2-2-2" : "3-3") " - Time: " TimeAtual
        LogTeamSwitch(nextTeam, (totalTimes == 3) ? "2-2-2" : "3-3")
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=team_logger", e)
    }
    return true
}

AtualizarCronometroAposTroca(nextTeam, previousTeam, switchTick, previousSwitchTick) {
    global Hoenn222_TeamDuration, Hoenn222_TeamLastUsageTick, Hoenn222_TeamUsageInterval
    global Hoenn222_TankEnterTick

    ; A divida global saiu: cada Pokemon carrega seu proprio acumulador de CD e o
    ; alvo de cada fase e rederivado do estado real. Aqui so ficam as estatisticas.
    try {
        if (previousSwitchTick > 0) {
            Hoenn222_TeamDuration[previousTeam] := switchTick - previousSwitchTick
        }
        if (Hoenn222_TeamLastUsageTick[nextTeam] > 0) {
            Hoenn222_TeamUsageInterval[nextTeam] := switchTick - Hoenn222_TeamLastUsageTick[nextTeam]
        }
        Hoenn222_TeamLastUsageTick[nextTeam] := switchTick
        Hoenn222_TankEnterTick[nextTeam] := switchTick
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=timer_statistics", e)
    }
}

; --- MODO 3-3 (O QUE VOCÊ JÁ TINHA) ---

ComboComplexoHoenn33() {
    global TimeAtual, isRodizioAtivo, TankAtualTime2_33

    if (isRodizioAtivo) {
        return
    }
    isRodizioAtivo := true

    if (TimeAtual == 1) {
        SetTimer(() => ExecutarRodizio33(1, 2, 3), -1)
    } else {
        if (TankAtualTime2_33 == 4) {
            SetTimer(() => ExecutarRodizio33(4, 5, 6), -1)
        } else {
            SetTimer(() => ExecutarRodizio33(5, 4, 6), -1)
        }
    }
}

ExecutarRodizio33(p1, p2, p3) {
    global isRodizioAtivo, TimeAtual, TankAtualTime2_33
    ; isRodizioAtivo já ativado na função pai

    LogComboStart(TimeAtual, "3-3")

    ComboSimples()
    Sleep(SleepAfterCombo)

    ControlSend("{" p2 "}", , GameWindow)
    Sleep(SleepAfterSwitch)
    ComboSimples()
    Sleep(SleepAfterSecondCombo)

    ControlSend("{" p3 "}", , GameWindow)
    Sleep(SleepAfterSwitch)
    ComboSimples()

    if (TimeAtual == 2) {
        TankAtualTime2_33 := (TankAtualTime2_33 == 4) ? 5 : 4
    }

    isRodizioAtivo := false
}

; --- MODO 2-2-2 (NOVO MODO) ---

ComboComplexoHoenn222(origem := "manual") {
    global TimeAtual, isRodizioAtivo, Hoenn222_ExecutionId
    global Hoenn222_ComboArmed, Hoenn222_ComboArmedTeam

    ; Decisao atomica: o botao e a varredura do contador nunca passam juntos pelo
    ; bloqueio, e a trava so e armada quando existe um time valido.
    previousCritical := A_IsCritical
    Critical("On")
    try {
        if (isRodizioAtivo || TimeAtual < 1 || TimeAtual > 3) {
            return
        }
        isRodizioAtivo := true

        ; O combo consome o pedido: nada fica pendente durante a execucao.
        Hoenn222_ComboArmed := false
        Hoenn222_ComboArmedTeam := 0

        timeOriginal := TimeAtual
        execIdOriginal := Hoenn222_ExecutionId
        p1 := (timeOriginal == 1) ? 1 : ((timeOriginal == 2) ? 3 : 5)
        p2 := (timeOriginal == 1) ? 2 : ((timeOriginal == 2) ? 4 : 6)
        SetTimer(() => ExecutarRodizio222(p1, p2, timeOriginal, execIdOriginal, origem), -1)
    } finally {
        Critical(previousCritical)
    }
}

ExecutarRodizio222(p1, p2, timeOriginal, execIdOriginal, origem := "manual") {
    global isRodizioAtivo, TimeAtual, comboMrMime, ModoAtual
    global Hoenn222_State, Hoenn222_StateStartTick, Hoenn222_LastComboStartTick, Hoenn222_P2CallTick
    global Hoenn222_P2EnterTick, Hoenn222_ExecutionId

    ; isRodizioAtivo já ativado na função pai

    ; Se a execução foi invalidada por F8 ou o time mudou no intervalo de agendamento do SetTimer
    if (timeOriginal != TimeAtual || ModoAtual != "Hoenn222" || execIdOriginal != Hoenn222_ExecutionId) {
        isRodizioAtivo := false
        return
    }

    timeDaExecucao := timeOriginal
    Hoenn222_ExecutionId++
    myExecId := Hoenn222_ExecutionId

    Hoenn222_State := "WAITING_TEAM_SWITCH"
    Hoenn222_StateStartTick := A_TickCount
    Hoenn222_LastComboStartTick := A_TickCount
    Hoenn222_P2CallTick := 0

    LogComboStart(timeDaExecucao, "2-2-2", origem)

    try {
        ; O registro do cast vem antes do envio: se o ControlSend falhar, o CD fica
        ; carregado, que e o lado conservador. Contagem e envio nunca divergem.
        Hoenn222CdRegistrarCast(timeDaExecucao)
        ComboSimples() ; Bate com o p1 (que já está fora)
        Sleep(Max(Hoenn222_SummonMs, 0))

        ; Se o time ou modo mudou durante o sleep do tank, cancela o resto da invocação
        if (timeDaExecucao != TimeAtual || ModoAtual != "Hoenn222") {
            return
        }

        ; Atualiza timer do P2 se ainda for a mesma execução
        if (Hoenn222_ExecutionId == myExecId) {
            Hoenn222_P2CallTick := A_TickCount
            Hoenn222_P2EnterTick[timeDaExecucao] := A_TickCount
        }

        ControlSend("{" p2 "}", , GameWindow) ; Chama p2
        Hoenn222CdRegistrarChamada(timeDaExecucao)
        Sleep(GetHoenn222SecondaryWaitMs(timeDaExecucao, A_TickCount))

        ; Verificação extra antes do P2 bater (evita enviar skill para time trocado após chamar P2)
        if (timeDaExecucao != TimeAtual || ModoAtual != "Hoenn222") {
            return
        }

        Hoenn222CdRegistrarCast(timeDaExecucao, true)
        ComboSimples()

        Sleep(SleepAfterCombo)
    } finally {
        isRodizioAtivo := false
    }
}

; Alvo do cronômetro para a fase e a dupla informadas. É um instante absoluto.
; Com o otimizador ligado o alvo vem do estado real dos seis Pokémon; desligado,
; ou se qualquer coisa falhar, volta aos alvos fixos do config.ahk.
GetHoenn222BaseTargetMs(state, timeIndex) {
    global Hoenn222_CdOptimizerEnabled, Hoenn222_ComboTargetMs, Hoenn222_SwitchTargetMs

    if (state == "WAITING_COMBO" || state == "WAITING_TEAM_SWITCH") {
        if Hoenn222_CdOptimizerEnabled {
            try {
                return (state == "WAITING_COMBO")
                    ? GetHoenn222ComboTargetMs(timeIndex)
                    : GetHoenn222SwitchTargetMs(timeIndex)
            } catch as e {
                SwitchDebug("SWITCH_ERROR", "phase=cd_target state=" state, e)
            }
        }
        return (state == "WAITING_COMBO")
            ? GetHoenn222TargetFromConfig(Hoenn222_ComboTargetMs, timeIndex)
            : GetHoenn222TargetFromConfig(Hoenn222_SwitchTargetMs, timeIndex)
    }
    return 0
}

GetHoenn222ComboTargetMs(timeIndex) {
    global Hoenn222_PrepareMs
    return Max(Hoenn222_PrepareMs, Hoenn222CdReadyInMs(Hoenn222Slot(timeIndex, false), A_TickCount))
}

; TROCAR TIME: menor janela sustainable desta dupla. TargetDuration e sempre
; uma DURACAO a partir do inicio do estado, nunca um instante absoluto.
GetHoenn222SwitchTargetMs(timeIndex) {
    return PlanHoenn222().Janelas[timeIndex]
}

; Planejador da volta. Não depende do estado em execução: usa os CDs principais
; por tier e os parâmetros físicos, então o resultado é estável e pode ser cacheado.
;   tank:      X >= cdTank + 1,5*Latency + Margin
;   secundário:X >= cdSec  + 0,5*Prepare + 0,5*Summon + 1,5*Latency + Margin
;   L = soma(X)/2 e janela = 2*X - L
PlanHoenn222() {
    global Hoenn222_PlanCache, Hoenn222_PrepareMs, Hoenn222_SummonMs
    global Hoenn222_LatencyMs, Hoenn222_MarginMs

    if IsObject(Hoenn222_PlanCache)
        return Hoenn222_PlanCache

    extraTank := 1.5 * Hoenn222_LatencyMs + Hoenn222_MarginMs
    extraSec := 0.5 * Hoenn222_PrepareMs + 0.5 * Hoenn222_SummonMs + 1.5 * Hoenn222_LatencyMs + Hoenn222_MarginMs
    X := []
    timeIndex := 1
    while timeIndex <= 3 {
        cdTank := GetHoenn222CdMainMs(timeIndex, false)
        cdSec := GetHoenn222CdMainMs(timeIndex, true)
        X.Push(Max(cdTank + extraTank, cdSec + extraSec))
        timeIndex += 1
    }
    L := (X[1] + X[2] + X[3]) / 2
    janelas := [2 * X[1] - L, 2 * X[2] - L, 2 * X[3] - L]

    ; Inviabilidade: a janela nem comporta os dois casts.
    minimo := Hoenn222_PrepareMs + Hoenn222_SummonMs + Hoenn222_SecondaryGapMs
    timeIndex := 1
    while timeIndex <= 3 {
        if (janelas[timeIndex] < minimo) {
            SwitchDebug("CD_PLAN_INFEASIVEL", "time=" timeIndex " janela=" Round(janelas[timeIndex])
                " precisa_de=" minimo " L=" Round(L))
            janelas[timeIndex] := minimo
        }
        timeIndex += 1
    }

    Hoenn222_PlanCache := { L: L, X: X, Janelas: janelas }
    SwitchDebug("CD_PLAN", "L=" Round(L) " janelas=" Round(janelas[1]) "," Round(janelas[2]) "," Round(janelas[3])
        " prepare=" Hoenn222_PrepareMs " summon=" Hoenn222_SummonMs " latency=" Hoenn222_LatencyMs
        " margin=" Hoenn222_MarginMs)
    return Hoenn222_PlanCache
}

; Registro de eventos do CD, isolado: qualquer falha aqui não cancela o combo.
Hoenn222CdRegistrarCast(timeIndex, secundario := false) {
    global Hoenn222_CdOptimizerEnabled
    if !Hoenn222_CdOptimizerEnabled
        return
    try {
        Hoenn222CdCast(timeIndex, secundario, A_TickCount)
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=cd_cast", e)
    }
}

Hoenn222CdRegistrarChamada(timeIndex) {
    global Hoenn222_CdOptimizerEnabled, Hoenn222_RateOutOfBall, Hoenn222_LatencyMs
    if !Hoenn222_CdOptimizerEnabled
        return
    try {
        Hoenn222CdSetRate(Hoenn222Slot(timeIndex, true), Hoenn222_RateOutOfBall,
            A_TickCount, Hoenn222_LatencyMs)
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=cd_call", e)
    }
}

; Espera entre chamar e combar com o secundário: a animação do jogo é o piso, e
; o cooldown pode estender. Nunca há espera fixa "porque ainda não está pronto".
GetHoenn222SecondaryWaitMs(timeIndex, tick) {
    global Hoenn222_CdOptimizerEnabled, Hoenn222_SecondaryGapMs
    piso := Hoenn222_SecondaryGapMs
    if !Hoenn222_CdOptimizerEnabled
        return piso
    try {
        faltando := Hoenn222CdReadyInMs(Hoenn222Slot(timeIndex, true), tick)
        if (faltando > piso) {
            SwitchDebug("CD_SEC_ESPERA", "time=" timeIndex " faltava=" Round(faltando) " piso=" piso)
            return faltando
        }
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=cd_secondary_wait", e)
    }
    return piso
}

; Le um alvo do config.ahk. Mapa ausente, invalido ou sem a dupla devolve 0
; em vez de derrubar o cronometro inteiro.
GetHoenn222TargetFromConfig(mapaTarget, timeIndex) {
    try {
        return (IsObject(mapaTarget) && mapaTarget.Has(timeIndex)) ? mapaTarget[timeIndex] : 0
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=target_config team=" timeIndex, e)
        return 0
    }
}

; Rotulo do tier configurado para a dupla. Texto livre: o que estiver no
; config.ahk aparece no indicador, sem nenhuma conversao fixa no codigo.
GetHoenn222TierText(timeIndex, role := "tank") {
    global Hoenn222_TankTier, Hoenn222_SecondTier
    timeIndex := Integer(timeIndex)
    try {
        mapaTier := (role == "second") ? Hoenn222_SecondTier : Hoenn222_TankTier
        return (IsObject(mapaTier) && mapaTier.Has(timeIndex) && mapaTier[timeIndex] != "")
            ? mapaTier[timeIndex] : "?"
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=tier_config role=" role " team=" timeIndex, e)
        return "?"
    }
}

; Milissegundos que ainda faltam para o contador ficar verde (<= 0 = pronto).
; Fonte unica de verdade: o indicador visual e o combo antecipado leem daqui.
GetHoenn222PendingMs() {
    global Hoenn222_State, Hoenn222_StateStartTick, TimeAtual
    if (Hoenn222_State == "WAITING_FIRST_COMBO") {
        return 0
    }
    idealMs := GetHoenn222BaseTargetMs(Hoenn222_State, TimeAtual)
    return idealMs - (A_TickCount - Hoenn222_StateStartTick)
}

; --- COOLDOWN INDIVIDUAL DOS 6 POKEMON ---
; Acumulador preguiçoso: o estado so e atualizado na leitura (CdTouch). Qualquer
; leitura ou escrita chama CdTouch antes, entao nenhum evento precisa propagar
; recuperacao e nao existe risco de esquecer um slot.
;   slot = (time - 1) * 2 + (1 tank, 2 secundario)
global Hoenn222_Cd := [0, 0, 0, 0, 0, 0]
global Hoenn222_CdRate := [0, 0, 0, 0, 0, 0]
global Hoenn222_CdSince := [0, 0, 0, 0, 0, 0]

; Integer() e obrigatorio: neste AutoHotkey um indice Float seria tratado como
; nome de propriedade e o acesso ao array falharia.
Hoenn222Slot(timeIndex, secundario := false) {
    return Integer((Integer(timeIndex) - 1) * 2 + (secundario ? 2 : 1))
}

; CD principal pelo rotulo do tier. Sem correspondencia usa o padrao e avisa uma vez.
GetHoenn222CdMainMs(timeIndex, secundario := false) {
    global Hoenn222_TankTier, Hoenn222_SecondTier, Hoenn222_CdByTier
    global Hoenn222_CdDefaultMs, Hoenn222_CdAvisoFeito
    timeIndex := Integer(timeIndex)
    try {
        tier := secundario ? GetHoenn222TierText(timeIndex, "second") : GetHoenn222TierText(timeIndex, "tank")
        mapa := secundario ? Hoenn222_SecondTier : Hoenn222_TankTier
        if IsObject(Hoenn222_CdByTier) {
            for chave, valor in Hoenn222_CdByTier {
                if (StrLower(chave) = StrLower(tier))
                    return valor
            }
            if mapa.Has(timeIndex) {
                for chave, valor in Hoenn222_CdByTier {
                    if (StrLower(chave) = StrLower(mapa[timeIndex]))
                        return valor
                }
            }
        }
        if !Hoenn222_CdAvisoFeito {
            Hoenn222_CdAvisoFeito := true
            SwitchDebug("CD_TIER_UNKNOWN", "tier=" tier " padrao=" Hoenn222_CdDefaultMs " time=" timeIndex)
        }
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=cd_tier", e)
    }
    return Hoenn222_CdDefaultMs
}

; Atualiza o acumulador ate `tick`. Delta negativo (tick no futuro) nao credita.
Hoenn222CdTouch(slot, tick) {
    global Hoenn222_Cd, Hoenn222_CdRate, Hoenn222_CdSince
    elapsed := tick - Hoenn222_CdSince[slot]
    if (elapsed > 0) {
        restante := Hoenn222_Cd[slot] - elapsed * Hoenn222_CdRate[slot]
        Hoenn222_Cd[slot] := restante > 0 ? restante : 0
        Hoenn222_CdSince[slot] := tick
    }
}

; Sair da Ball so conta depois de LatencyMs; voltar e imediato.
; As duas direcoes reduzem a recuperacao creditada, nunca aumentam.
Hoenn222CdSetRate(slot, rate, tick, atrasoMs := 0) {
    global Hoenn222_CdRate, Hoenn222_CdSince
    Hoenn222CdTouch(slot, tick)
    Hoenn222_CdRate[slot] := rate
    if (atrasoMs > 0)
        Hoenn222_CdSince[slot] := tick + atrasoMs
}

; O cast reinicia o cooldown e a contagem so comeca LatencyMs depois do comando.
; O progresso acumulado antes do cast e descartado: nunca e contado duas vezes.
; Usar a skill pressupoe estar fora da Ball, entao a taxa passa a 1,0 aqui.
Hoenn222CdCast(timeIndex, secundario, tick) {
    global Hoenn222_Cd, Hoenn222_CdRate, Hoenn222_CdSince
    global Hoenn222_LatencyMs, Hoenn222_MarginMs, Hoenn222_RateOutOfBall
    slot := Hoenn222Slot(timeIndex, secundario)
    Hoenn222CdTouch(slot, tick)
    Hoenn222_CdRate[slot] := Hoenn222_RateOutOfBall
    Hoenn222_Cd[slot] := GetHoenn222CdMainMs(timeIndex, secundario)
    Hoenn222_CdSince[slot] := tick + Hoenn222_LatencyMs
    SwitchDebug("CD_CAST", "slot=" slot " time=" timeIndex " papel=" (secundario ? "sec" : "tank")
        " cd_main=" Hoenn222_Cd[slot] " tick=" tick " cd_comeca=" Hoenn222_CdSince[slot]
        " pronto=" (tick + Hoenn222_LatencyMs + Hoenn222_Cd[slot])
        " seguro=" (tick + Hoenn222_LatencyMs + Hoenn222_Cd[slot] + Hoenn222_MarginMs))
}

; Milissegundos ate o primeiro instante seguro: CD zerado mais a margem.
Hoenn222CdReadyInMs(slot, tick) {
    global Hoenn222_Cd, Hoenn222_CdRate, Hoenn222_MarginMs
    Hoenn222CdTouch(slot, tick)
    if (Hoenn222_Cd[slot] <= 0)
        return Hoenn222_MarginMs
    taxa := Hoenn222_CdRate[slot] > 0 ? Hoenn222_CdRate[slot] : 1
    return Hoenn222_Cd[slot] / taxa + Hoenn222_MarginMs
}

; Troca de time aceita: a dupla anterior volta, so o tank da nova sai.
Hoenn222CdTrocaTime(previousTeam, nextTeam, tick) {
    global Hoenn222_RateInBall, Hoenn222_RateOutOfBall, Hoenn222_LatencyMs
    try {
        for secundario in [false, true] {
            Hoenn222CdSetRate(Hoenn222Slot(previousTeam, secundario), Hoenn222_RateInBall, tick)
        }
        Hoenn222CdSetRate(Hoenn222Slot(nextTeam, false), Hoenn222_RateOutOfBall, tick, Hoenn222_LatencyMs)
        ; o secundario da dupla nova continua na Ball ate a chamada no combo
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=cd_team_switch", e)
    }
}

; F8: nada se sabe do estado do jogo, entao os seis comecam prontos e na Ball.
ResetarCooldownsHoenn222(tick) {
    global Hoenn222_Cd, Hoenn222_CdRate, Hoenn222_CdSince, Hoenn222_RateInBall
    i := 1
    while i <= 6 {
        Hoenn222_Cd[i] := 0
        Hoenn222_CdRate[i] := Hoenn222_RateInBall
        Hoenn222_CdSince[i] := tick
        i += 1
    }
}
; --- BOTAO DE COMBO 2-2-2: NORMAL, ANTECIPADO E EMERGENCIA ---
;   1a pressao com o contador verde -> combo normal, imediato.
;   1a pressao antes do verde      -> o pedido fica armado e o macro executa
;                                     sozinho assim que o contador ficar verde.
;   2a pressao dentro da janela    -> emergencia: ignora o contador e executa.
SolicitarComboHoenn222() {
    global TimeAtual, isRodizioAtivo, Hoenn222_EmergencyWindowMs
    global Hoenn222_ComboArmed, Hoenn222_ComboArmedTeam, Hoenn222_ComboLastPressTick

    pressTick := A_TickCount
    intervaloMs := (Hoenn222_ComboLastPressTick > 0) ? pressTick - Hoenn222_ComboLastPressTick : -1
    Hoenn222_ComboLastPressTick := pressTick
    emergencia := (intervaloMs >= 0 && intervaloMs <= Hoenn222_EmergencyWindowMs)

    ; Em caso de falha de calculo vale o comportamento antigo: executar.
    faltandoMs := 0
    try {
        faltandoMs := GetHoenn222PendingMs()
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=combo_readiness", e)
    }

    SwitchDebug("COMBO_REQUEST", "team=" TimeAtual " gap_ms=" intervaloMs " missing_ms=" faltandoMs
        " emergency=" emergencia " armed=" (Hoenn222_ComboArmed ? 1 : 0))

    if (isRodizioAtivo) {
        SwitchDebug("COMBO_RESULT", "result=ignored reason=combo_running")
        return
    }
    if (emergencia) {
        SwitchDebug("COMBO_RESULT", "result=emergency")
        ComboComplexoHoenn222("emergencia")
        return
    }
    if (faltandoMs <= 0) {
        SwitchDebug("COMBO_RESULT", "result=immediate")
        ComboComplexoHoenn222("manual")
        return
    }

    ; Antecipado: um pedido por vez, sempre preso ao time em que foi feito.
    previousCritical := A_IsCritical
    Critical("On")
    try {
        Hoenn222_ComboArmed := true
        Hoenn222_ComboArmedTeam := TimeAtual
    } finally {
        Critical(previousCritical)
    }
    SwitchDebug("COMBO_ARMED", "team=" Hoenn222_ComboArmedTeam " missing_ms=" faltandoMs)
}

; Chamado pelo laco de 30 ms. Dispara o pedido armado assim que o contador fica
; verde, sem pressionar o botao de novo.
ProcessarComboArmadoHoenn222() {
    global ModoAtual, TimeAtual, isRodizioAtivo
    global Hoenn222_ComboArmed, Hoenn222_ComboArmedTeam

    if (!Hoenn222_ComboArmed)
        return

    ; O pedido vale para um unico modo e um unico time.
    if (ModoAtual != "Hoenn222" || TimeAtual != Hoenn222_ComboArmedTeam) {
        CancelarComboArmadoHoenn222("context_changed")
        return
    }
    if (isRodizioAtivo) {
        CancelarComboArmadoHoenn222("combo_running")
        return
    }

    ; Sem confianca no calculo, o pedido continua esperando em vez de disparar.
    faltandoMs := 1
    try {
        faltandoMs := GetHoenn222PendingMs()
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=combo_readiness", e)
    }
    if (faltandoMs > 0)
        return

    SwitchDebug("COMBO_FIRED", "team=" TimeAtual " reason=armed")
    ; ComboComplexoHoenn222 consome o pedido junto com a trava.
    ComboComplexoHoenn222("antecipado")
}

; Descarta um pedido pendente apos troca de time, ressincronizacao ou mudanca de
; modo. Nada aqui altera o cronometro, a divida ou a rotacao.
CancelarComboArmadoHoenn222(reason := "") {
    global Hoenn222_ComboArmed, Hoenn222_ComboArmedTeam
    if (!Hoenn222_ComboArmed)
        return
    Hoenn222_ComboArmed := false
    Hoenn222_ComboArmedTeam := 0
    SwitchDebug("COMBO_DISARMED", "reason=" (reason = "" ? "unspecified" : reason))
}
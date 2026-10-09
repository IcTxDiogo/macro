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
; Cache do plano. Comeca em false (nunca planejado); ler uma variavel `unset`
; e erro neste AutoHotkey, entao nunca usamos `unset` aqui.
global Hoenn222_PlanCache := false
; Teto de CD do secundario no instante T0. Entre T0 e a chamada ele ainda esta
; na Ball (0,5 x 2700); depois recupera 1,0 x 800 ate o cast, e a margem de
; 250ms ainda tem de caber antes dele. 1900ms com os valores atuais.
global Hoenn222_SecondaryToleranceMs := 0.5 * SleepAfterTankCombo + SleepAfterSwitch - Hoenn222_MarginMs

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
        Sleep(SleepAfterTankCombo) ; animação do jogo: valor original, nunca alterado

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
        ; Intervalo interno original. Se o CD do secundário não couber aqui, o
        ; macro não estende a espera: ele avisou antes, no verde do combo.
        Sleep(SleepAfterSwitch)

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

; Alvo do cronometro para a fase e a dupla informadas. E sempre uma DURACAO em
; ms contada a partir do inicio do estado, nunca um instante absoluto: e assim
; que Hoenn222_ComboTargetMs e Hoenn222_SwitchTargetMs sao definidos no config,
; e e assim que GetHoenn222PendingMs() desconta o tempo ja decorrido.
; Com o otimizador ligado o alvo vem do estado real dos seis Pokemon; desligado,
; ou se qualquer coisa falhar, volta aos alvos fixos do config.ahk.
GetHoenn222BaseTargetMs(state, timeIndex) {
    global Hoenn222_CdOptimizerEnabled, Hoenn222_ComboTargetMs, Hoenn222_SwitchTargetMs

    if (state != "WAITING_COMBO" && state != "WAITING_TEAM_SWITCH")
        return 0

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

; Alvos fixos do config.ahk, por dupla. Usado quando o otimizador esta
; desligado e como destino de fallback se o estado real nao puder ser lido.
GetHoenn222TargetFromConfig(mapaTarget, timeIndex) {
    try {
        return (IsObject(mapaTarget) && mapaTarget.Has(timeIndex)) ? mapaTarget[timeIndex] : 0
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=target_config team=" timeIndex, e)
        return 0
    }
}

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

; Quanto falta, em ms, para o alvo da fase atual. E uma DURACAO, nunca um
; instante absoluto; quem compara com o relogio e o alvo da propria fase.
GetHoenn222PendingMs() {
    global Hoenn222_State, Hoenn222_StateStartTick, TimeAtual
    if (Hoenn222_State == "WAITING_FIRST_COMBO") {
        return 0
    }
    idealMs := GetHoenn222BaseTargetMs(Hoenn222_State, TimeAtual)
    return idealMs - (A_TickCount - Hoenn222_StateStartTick)
}

; COMBAR: quantos ms ate o combo INTEIRO ser viavel com os tempos internos fixos.
; Nao ha espera artificial: o macro nao impoe nada alem do cooldown.
;   Tank      : CD zerado + margem <= T0
;   Secundario: entre T0 e a chamada ele ainda esta na Ball (0,5 x 2700) e so
;               recupera 1,0 x 800 ate o cast; a margem ainda tem de caber.
;               Dai o teto SEC_TOL = 0,5*SleepAfterTankCombo + SleepAfterSwitch
;               - Margin, medido em CD que o secundario pode ter em T0.
; E o maior dos dois: o verde so acende quando tank E secundario estao viaveis.
GetHoenn222ComboTargetMs(timeIndex) {
    global Hoenn222_SecondaryToleranceMs
    tankMs := Hoenn222CdReadyInMs(Hoenn222Slot(timeIndex, false), A_TickCount)
    secSlot := Hoenn222Slot(timeIndex, true)
    cdSec := Hoenn222CdTouched(secSlot, A_TickCount)
    secMs := 0
    if (cdSec > Hoenn222_SecondaryToleranceMs)
        secMs := (cdSec - Hoenn222_SecondaryToleranceMs) / Hoenn222CdRateOf(secSlot)
    return Max(0, Max(tankMs, secMs))
}

; Quanto de CD o secundario ainda teria no seu cast se o combo comecasse agora.
; E o que permite avisar "nao viavel" sem nunca inventar cooldown disponivel.
Hoenn222SecondaryPendenteMs(timeIndex, offsetMs) {
    global Hoenn222_SecondaryToleranceMs
    slot := Hoenn222Slot(timeIndex, true)
    agora := A_TickCount
    cd := Hoenn222CdTouched(slot, agora)
    taxa := Hoenn222CdRateOf(slot)
    restante := cd - (offsetMs * taxa)
    if (restante < 0)
        restante := 0
    ; entre o inicio do combo e a chamada o secundario segue dentro da Ball
    emT1 := restante - SleepAfterTankCombo * taxa
    if (emT1 < 0)
        emT1 := 0
    pendente := emT1 - SleepAfterSwitch + Hoenn222_MarginMs
    return pendente > 0 ? pendente : 0
}

; Quem esta segurando o verde: "secundario", "tank" ou "" quando ja esta viavel.
; E diagnostico: nao altera nenhum alvo, so diz ao jogador o que falta.
GetHoenn222ComboBloqueio(timeIndex) {
    global Hoenn222_SecondaryToleranceMs
    secSlot := Hoenn222Slot(timeIndex, true)
    cdSec := Hoenn222CdTouched(secSlot, A_TickCount)
    if (cdSec > Hoenn222_SecondaryToleranceMs)
        return "secundario"
    if (Hoenn222CdTouched(Hoenn222Slot(timeIndex, false), A_TickCount) > 0)
        return "tank"
    return ""
}

; TROCAR TIME: menor janela sustainable desta dupla. E sempre uma DURACAO a
; partir do inicio do estado, nunca um instante absoluto.
GetHoenn222SwitchTargetMs(timeIndex) {
    return PlanHoenn222().Janelas[timeIndex]
}

; =============================================================================
; PLANEJADOR GLOBAL DAS TRES DUPLAS
; =============================================================================
; Depende so da configuracao, entao o resultado e estavel e fica em cache.
;
; -----------------------------------------------------------------------------
; MODELO
; -----------------------------------------------------------------------------
; Só um Pokémon fica fora da Ball por vez. Dentro da janela da dupla k:
;
;   s_k ........... troca de time; o tank k SAI da Ball, o secundário continua
;                   dentro. A partir daqui é o tank que recupera, e o CD que
;                   ele recupera é o que começou no cast da volta ANTERIOR.
;   T0_k .......... cast do tank; o CD novo passa a contar em T0_k + Λ
;   T1_k = T0_k + P chamada do p2; o tank VOLTA para a Ball, o secundário SAI
;   T2_k = T1_k + G cast do secundário; CD conta a partir de T2_k + Λ
;   s_(k+1) ....... próxima troca; o secundário volta para a Ball
;
; Capacidade conjunta da volta: 1 a 1,0 + 5 a 0,5 = 3,5. Nunca mais que isso.
;
; -----------------------------------------------------------------------------
; PRINCÍPIO: a recuperação é contada ENTRE DOIS CASTS CONSECUTIVOS
; -----------------------------------------------------------------------------
; O cooldown do Pokémon na volta k nasce em T0_k e precisa zerar antes do
; próximo T0. Nesse intervalo inteiro ele recupera, e cada segundo conta onde
; quer que aconteça:
;
;   * logo depois do cast, ainda fora da Ball (1,0×)
;   * guardado no meio da volta, dentro da Ball (0,5×)
;   * na volta seguinte, de novo fora, durante o lure ANTES do próximo cast
;
; O lure não é tempo perdido: ele recupera o cooldown que começou no cast
; anterior. F = tempo total fora da Ball entre dois casts consecutivos.
;
;     recuperação = (F - Λ)·1,0 + (L - F)·0,5
;     (F - Λ) porque o congelamento de Λ fica DENTRO do primeiro trecho fora
;
;     (F - Λ) + (L - F)·0,5  >=  CD + Δ
;     F  >=  2·(CD + Λ + Δ) − L
;
; Λ e Δ entram uma vez cada. Λ porque o CD não corre durante o congelamento;
; Δ como a folga exigida no próximo cast.
;
; -----------------------------------------------------------------------------
; QUEM PODE FICAR FORA, E QUANTO
; -----------------------------------------------------------------------------
; O tank só existe fora da Ball dentro da SUA janela, da troca até a chamada
; do p2. Esse tempo é lure_k + P. Fora da janela ele está guardado, a 0,5.
;     F_tank_k = lure_k + P        e lure_k >= 0
;
; O secundário fica fora de T1_k até a próxima troca, e precisa comportar
; Gap + SleepAfterCombo:
;     F_sec_k = janela_k − lure_k − P   e janela_k − lure_k − P >= Gap + Post
;
; -----------------------------------------------------------------------------
; COMO AS TRÊS PARCELAS FECHAM
; -----------------------------------------------------------------------------
;     janela_k = lure_k + P + F_sec_k
;     L = janela_1 + janela_2 + janela_3
;
; Cada janela é o que o tank e o secundário daquele par exigem, então as três
; janelas têm tamanhos diferentes. O menor L que fecha essa soma é a volta
; mínima sustentável — e ele coincide com o piso 3,5× quando a estrutura couber.
;
PlanHoenn222() {
    global Hoenn222_PlanCache, Hoenn222_LatencyMs, Hoenn222_MarginMs

    if Hoenn222_PlanCache
        return Hoenn222_PlanCache

    lat := Hoenn222_LatencyMs
    marg := Hoenn222_MarginMs
    margemEfetiva := lat + marg
    Pp := SleepAfterTankCombo
    minSec := SleepAfterSwitch + SleepAfterCombo   ; secundário precisa ficar fora até a troca

    cdTank := [GetHoenn222CdMainMs(1, false), GetHoenn222CdMainMs(2, false), GetHoenn222CdMainMs(3, false)]
    cdSec := [GetHoenn222CdMainMs(1, true), GetHoenn222CdMainMs(2, true), GetHoenn222CdMainMs(3, true)]

    ; Soma das janelas em função de L. Diminui quando L cresce (CD maior exige
    ; menos tempo fora), então a condição "soma <= L" vale a partir de um
    ; único ponto. Bisseção acha o menor L que fecha.
    minJanelas := Pp + minSec
    lo := minJanelas * 3
    hi := 500000.0
    while (lo < hi) {
        meio := (lo + hi) / 2
        total := 0.0
        timeIndex := 1
        while timeIndex <= 3 {
            total += Max(Pp, 2 * (cdTank[timeIndex] + margemEfetiva) - meio)
            total += Max(minSec, 2 * (cdSec[timeIndex] + margemEfetiva) - meio)
            timeIndex += 1
        }
        if (total <= meio)
            hi := meio
        else
            lo := meio + 1
    }
    L := hi

    ; Janelas e lure finais nesse L.
    janelas := [0.0, 0.0, 0.0]
    lures := [0.0, 0.0, 0.0]
    tankFora := [0.0, 0.0, 0.0]
    secFora := [0.0, 0.0, 0.0]
    folgaLure := 0.0
    timeIndex := 1
    while timeIndex <= 3 {
        tankFora[timeIndex] := Max(Pp, 2 * (cdTank[timeIndex] + margemEfetiva) - L)
        secFora[timeIndex] := Max(minSec, 2 * (cdSec[timeIndex] + margemEfetiva) - L)
        lures[timeIndex] := tankFora[timeIndex] - Pp
        janelas[timeIndex] := lures[timeIndex] + Pp + secFora[timeIndex]
        folgaLure += lures[timeIndex]
        timeIndex += 1
    }

    ; Object literal em UMA linha: este build do AutoHotkey nao aceita
    ; literais multi-linha.
    Hoenn222_PlanCache := {L: L, Janelas: janelas, Lures: lures, TankFora: tankFora, SecFora: secFora, FolgaLure: folgaLure, JanelaMinima: minJanelas, MargemEfetiva: margemEfetiva}
    SwitchDebug("CD_PLAN", "L=" Round(L)
        " janelas=" Round(janelas[1]) "," Round(janelas[2]) "," Round(janelas[3])
        " lure=" Round(lures[1]) "," Round(lures[2]) "," Round(lures[3])
        " tank_fora=" Round(tankFora[1]) "," Round(tankFora[2]) "," Round(tankFora[3])
        " sec_fora=" Round(secFora[1]) "," Round(secFora[2]) "," Round(secFora[3])
        " pos_cast=" Pp " gap=" SleepAfterSwitch " pos=" SleepAfterCombo
        " latencia=" lat " margem=" marg)
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
    global Hoenn222_CdOptimizerEnabled, Hoenn222_RateOutOfBall, Hoenn222_RateInBall
    global Hoenn222_LatencyMs
    if !Hoenn222_CdOptimizerEnabled
        return
    try {
        tick := A_TickCount
        ; APENAS UM POKEMON POR VEZ FORA DA BALL. Ao chamar o p2 o tank sai
        ; de campo: se ele continuasse a 1,0x os dois recuperariam juntos e a
        ; capacidade da volta passaria de 3,5x para 4,0x, inflando o plano.
        Hoenn222CdSetRate(Hoenn222Slot(timeIndex, false), Hoenn222_RateInBall, tick)
        Hoenn222CdSetRate(Hoenn222Slot(timeIndex, true), Hoenn222_RateOutOfBall,
            tick, Hoenn222_LatencyMs)
    } catch as e {
        SwitchDebug("SWITCH_ERROR", "phase=cd_call", e)
    }
}

; --- COOLDOWN INDIVIDUAL DOS 6 POKEMON ---
; Acumulador preguiçoso: o estado so e atualizado na leitura (CdTouch). Qualquer
; leitura ou escrita chama CdTouch antes, entao nenhum evento precisa propagar
; recuperacao e nao existe risco de esquecer um slot.
;   slot = (time - 1) * 2 + (1 tank, 2 secundario)
global Hoenn222_Cd := [0, 0, 0, 0, 0, 0]
global Hoenn222_CdRate := [0, 0, 0, 0, 0, 0]
global Hoenn222_CdSince := [0, 0, 0, 0, 0, 0]

; Le o CD restante ja com a recuperacao ate `tick` aplicada.
Hoenn222CdTouched(slot, tick) {
    global Hoenn222_Cd
    Hoenn222CdTouch(slot, tick)
    return Hoenn222_Cd[slot]
}

Hoenn222CdRateOf(slot) {
    global Hoenn222_CdRate
    Hoenn222CdTouch(slot, A_TickCount)
    taxa := Hoenn222_CdRate[slot]
    return taxa > 0 ? taxa : 1
}

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
        Hoenn222CdSetRate(Hoenn222Slot(nextTeam, false), Hoenn222_RateOutOfBall, tick)
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

    ; Pedido antes do verde: o macro arma e espera o instante certo, e registra
    ; quem esta segurando e o quanto o secundario ficaria atrasado no seu cast.
    bloqueio := GetHoenn222ComboBloqueio(TimeAtual)
    SwitchDebug("CD_ANTECIPACAO", "time=" TimeAtual " bloqueio=" bloqueio
        " falta_ms=" Round(faltandoMs) " sec_cast_ms=" Hoenn222SecondaryPendenteMs(TimeAtual, 0))

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
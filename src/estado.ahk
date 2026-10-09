#Requires AutoHotkey v2.0
; Estado global do macro: time atual, travas, cronometro, pedidos armados.

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
; Mesma ideia para a TROCA DE TIME (gatilho): pedido armado independente do combo,
; preso ao time em que foi feito, e base propria do duplo acionamento.
global Hoenn222_SwitchArmed := false
global Hoenn222_SwitchArmedTeam := 0
global Hoenn222_SwitchLastPressTick := 0
; Disparo automatico ja agendado e ainda nao executado (evita agendar duas vezes entre
; duas execucoes de 30 ms do laco).
global Hoenn222_ComboFirePending := false
global Hoenn222_SwitchFirePending := false
global Hoenn222_CdAvisoFeito := false
; Cache do plano. Comeca em false (nunca planejado); ler uma variavel `unset`
; e erro neste AutoHotkey, entao nunca usamos `unset` aqui.
global Hoenn222_PlanCache := false
; Teto de CD do secundario no instante T0. Entre T0 e a chamada ele ainda esta
; na Ball (0,5 x 2700); depois da chamada o jogo so conta o CD LatencyMs depois
; (o mesmo congelamento que o acumulador aplica na saida da Ball), entao so
; (800 - Latency) ms recuperam a 1,0 ate o cast, e a margem ainda tem de caber
; antes dele. Esquecer a latencia aqui gastava a margem inteira do secundario:
; ele era usado ~10 ms depois do CD zerar em vez de 250 ms.
global Hoenn222_SecondaryToleranceMs := 0.5 * SleepAfterTankCombo + Max(0, SleepAfterSwitch - Hoenn222_LatencyMs) - Hoenn222_MarginMs
global Hoenn222_TankEnterTick := Map(1, 0, 2, 0, 3, 0)
global Hoenn222_P2EnterTick := Map(1, 0, 2, 0, 3, 0)
global Hoenn222_TeamDuration := Map(1, 0, 2, 0, 3, 0)
global Hoenn222_TeamUsageInterval := Map(1, 0, 2, 0, 3, 0)
global Hoenn222_TeamLastUsageTick := Map(1, 0, 2, 0, 3, 0)

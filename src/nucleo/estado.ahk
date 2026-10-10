#Requires AutoHotkey v2.0
; Estado global do macro: time atual, travas, cronometro, pedidos armados.

global ModoAtual := "Hoenn222"  ; "Normal", "Hoenn33" ou "Hoenn222" (F12 / botao Back alternam)
global TextoDeStatus := "Modo: Hoenn 2-2-2 - Time: 1"
global TimeAtual := 1          ; Time solicitado (1, 2 ou 3); entrada visual não confirmada
global RodizioAtivo := false ; Trava de segurança
global TankDoTime2Modo33 := 4  ; Específico para o modo 3-3
; --- VARIÁVEIS DO CRONÔMETRO HOENN 2-2-2 ---
global FaseAtual := "WAITING_FIRST_COMBO"
global InicioDaFaseTick := 0
global IdDaExecucao := 0
global UltimaTrocaDeTimeTick := 0
global UltimoComboTick := 0
global ChamadaDoSecundarioTick := 0
; --- COMBO 2-2-2: PEDIDO ANTECIPADO E EMERGENCIA ---
; ComboArmado: existe um pedido de combo aguardando o contador ficar verde.
; TimeDoComboArmado: time para o qual o pedido foi feito; nunca executa em outro.
; UltimoCliqueComboTick: base do duplo acionamento (emergencia).
global ComboArmado := false
global TimeDoComboArmado := 0
global UltimoCliqueComboTick := 0
; Mesma ideia para a TROCA DE TIME (gatilho): pedido armado independente do combo,
; preso ao time em que foi feito, e base propria do duplo acionamento.
global TrocaArmada := false
global TimeDaTrocaArmada := 0
global UltimoCliqueTrocaTick := 0
; Disparo automatico ja agendado e ainda nao executado (evita agendar duas vezes entre
; duas execucoes de 30 ms do laco).
global DisparoDoComboPendente := false
global DisparoDaTrocaPendente := false
global AvisoDeTierDesconhecidoFeito := false
; Cache do plano. Comeca em false (nunca planejado); ler uma variavel `unset`
; e erro neste AutoHotkey, entao nunca usamos `unset` aqui.
global PlanoEmCache := false
; Teto de CD do secundario no instante T0. Entre T0 e a chamada ele ainda esta
; na Ball (0,5 x 2700); depois da chamada o jogo so conta o CD
; Hoenn222_ExitLatencySecondaryMs depois (o mesmo congelamento que o acumulador aplica
; na chamada), entao so max(0, 800 - ExitLatencySecondary) ms recuperam a 1,0 ate o
; cast, e a margem ainda tem de caber antes dele. Esquecer a latencia aqui gastava a
; margem inteira do secundario (e com o atraso medido de 1100 ms, que e maior que o
; intervalo de 800, nada recupera a 1,0 antes do cast).
global ToleranciaDoSecundarioMs := CalcularToleranciaDoSecundarioMs()
CalcularToleranciaDoSecundarioMs() {
    global SleepAfterTankCombo, SleepAfterSwitch, Hoenn222_ExitLatencySecondaryMs
    global Hoenn222_MarginMs
    return 0.5 * SleepAfterTankCombo + Max(0, SleepAfterSwitch - Hoenn222_ExitLatencySecondaryMs)
        - Hoenn222_MarginMs
}
global EntradaDoTankTick := Map(1, 0, 2, 0, 3, 0)
global EntradaDoSecundarioTick := Map(1, 0, 2, 0, 3, 0)
global DuracaoDoTime := Map(1, 0, 2, 0, 3, 0)
global IntervaloEntreUsosDoTime := Map(1, 0, 2, 0, 3, 0)
global UltimoUsoDoTimeTick := Map(1, 0, 2, 0, 3, 0)

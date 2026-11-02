#Requires AutoHotkey v2.0
; Estado global do macro. Somente dados: a logica esta em src\tempo e src\macro.
; Nota: neste AutoHotkey ler uma variavel `unset` e erro, entao tudo comeca inicializado.

; --- Modo e time ---
; F12 / botao Back giram Normal -> Hoenn222 -> Hoenn15 -> Normal; abre em StartMode.
global ModoAtual := ModoInicialDoConfig() ; "Normal", "Hoenn222" ou "Hoenn15"
global TextoDeStatus := (ModoAtual == "Hoenn15") ? "Modo: Hoenn 1,5 - Time: 1" : "Modo: Hoenn 2-2-2 - Time: 1"
global TimeAtual := 1                 ; time pedido (1 a 3; 1 a 2 no 1,5); a entrada visual nao e confirmada
global RodizioAtivo := false          ; trava: um rodizio por vez
global UltimaBallEspecial := 0         ; somente memoria; reload/reabrir volta para ball 1
global RenovacaoDailyAtiva := false    ; impede renovacoes sobrepostas

; --- Fase do ciclo 2-2-2 ---
; FaseAtual: "WAITING_FIRST_COMBO", "WAITING_COMBO" (COMBAR; PARTE 1 no 1,5),
; "WAITING_PART2" (PARTE 2, so no 1,5) ou "WAITING_TEAM_SWITCH" (TROCAR TIME).
global FaseAtual := "WAITING_FIRST_COMBO"
global InicioDaFaseTick := 0
global IdDaExecucao := 0              ; invalida rodizios agendados quando o F8/troca muda o contexto
global UltimaTrocaDeTimeTick := 0

; --- Pedidos antecipados (armados) ---
; Um pedido fica preso ao time em que foi feito e executa sozinho quando o verde acende.
; UltimoClique*Tick e a base do duplo acionamento (emergencia).
global ComboArmado := false
global TimeDoComboArmado := 0
global UltimoCliqueComboTick := 0
global TrocaArmada := false
global TimeDaTrocaArmada := 0
global UltimoCliqueTrocaTick := 0
; Disparo automatico ja agendado e ainda nao executado (evita agendar duas vezes entre duas
; execucoes de 30 ms do laco).
global DisparoDoComboPendente := false
global DisparoDaTrocaPendente := false

; --- Planejamento ---
global PlanoEmCache := false          ; false = ainda nao planejado
global AvisoDeTierDesconhecidoFeito := false
global ToleranciaDoSecundarioMs := ConfigDeTempoValida ? CalcularToleranciaDoSecundarioMs() : 0


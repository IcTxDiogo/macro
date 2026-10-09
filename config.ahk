#Requires AutoHotkey v2.0

; --- CONFIGURAÇÕES GLOBAIS ---

; Nome da janela do jogo
global GameWindow := "ahk_exe PokeAlliance_dx.exe"

; Deadzone para movimento analógico
global DeadzoneMove := 20000

; Tempos de espera (em ms)
global SleepAfterCombo := 3000
global SleepAfterSwitch := 800
global SleepAfterSecondCombo := 3000
global SleepAfterTankCombo := 2700

; Teclas para ações
global KeyPokestop := "c"
global KeyMedicine := "f"
global KeyCombo := "i"
global KeyMovePokemon := "q"
global KeyBall := "v"
global KeyBallSpecial := "p"
global KeyRevive := "Space"
global KeyBuffMove := "f1"
global KeyPotion := "e"
global KeyChangeTarget := "Tab"
global KeyFullDef := "t"
global KeyFullAtk := "y"
global KeyPokeMoveF3 := "f3"
global KeyPokeMoveF6 := "f6"

; Tamanho do tile (em px)
global TileSize := 70

; Coordenadas do personagem
global PlayerOriginX := 936
global PlayerOriginY := 402

; Offsets para o tooltip central do Hoenn 2-2-2
global Hoenn222CenterOffsetX := 0
global Hoenn222CenterOffsetY := -60

; --- HOENN 2-2-2: DUPLAS, TIERS E ALVOS DE TEMPO ---
; Somente esta secao precisa ser editada para reutilizar o macro em outro respawn.
;
; Hoenn222_TankTier   : tier do Tank/Lurer de cada dupla (1, 2 e 3).
; Hoenn222_SecondTier : tier do Pokemon secundario chamado durante o combo.
;                       Texto livre: e exibido como estiver no indicador.
;                       Exemplos: "Lendario", "UR", "SR", "Normal".
; Hoenn222_ComboTargetMs  : ms dentro do time ate o contador ficar verde (COMBAR).
; Hoenn222_SwitchTargetMs : ms depois do combo ate o contador ficar verde (TROCAR TIME).
;
; Os alvos sao medidas do respawn e NAO sao derivados do tier: o tempo de um Pokemon
; depende do move, do cleanse e da cadencia do alvo, nao apenas da raridade. Por isso
; tiers e tempos sao configurados lado a lado e nenhum valor fica escrito no codigo.
; Alterar um tier sem medir o novo tempo apenas troca o rotulo exibido.
; Composição principal auditada: tank SR nas três duplas.
; O CD do tank é o que limita a volta: L >= 2*CD + 2*Latência + Margem - 2700.
; Com CD 45s isso dá 88,05s de volta mínima sustentável, e não os 68s que a
; fórmula anterior anunciava. Trocar um tank para UR (43s) derruba o piso para
; 84,05s; para Lendário (40s), 80,05s. É o tier do tank que manda.
global Hoenn222_TankTier := Map(1, "SR", 2, "SR", 3, "SR")
global Hoenn222_SecondTier := Map(1, "Lendário", 2, "UR", 3, "UR")
global Hoenn222_ComboTargetMs := Map(1, 15000, 2, 16000, 3, 15500)
global Hoenn222_SwitchTargetMs := Map(1, 9500, 2, 11500, 3, 11500)

; Janela do duplo acionamento (ms). Duas pressoes do botao de combo dentro dela
; formam um combo de emergencia, que ignora o contador e executa na hora.
; Use 0 para desativar a emergencia e deixar apenas o pedido antecipado.
global Hoenn222_EmergencyWindowMs := 400

; --- HOENN 2-2-2: COOLDOWN INDIVIDUAL DOS 6 POKEMON ---
; Cada Pokemon mantem seu proprio acumulador de cooldown restante, atualizado
; pelos eventos reais do macro: cast, entrada e saida da Ball e troca de time.
;
; CdByTier ....... CD principal pelo rotulo do tier (o maior cooldown manda).
;                  Aceita qualquer rotulo; tier desconhecido usa CdDefaultMs.
; RateOut/In ..... recuperacao de CD por segundo real, fora e dentro da Ball.
; LatencyMs ...... o jogo so comeca a contar o CD este tempo depois do comando
;                  da skill. E o unico offset entre a skill e a recuperacao.
; MarginMs ....... a skill so e usavel este tempo depois do CD estimado zerar.
;                  Os dois se somam: com 250 + 250 o modelo tolera ate 500ms de
;                  latencia real antes de qualquer cast antecipado.
;
; Os intervalos internos do combo NAO sao configuraveis aqui de proposito:
; sao SleepAfterTankCombo (2700) e SleepAfterSwitch (800), os mesmos valores
; de sempre. O otimizador nunca os altera; se o secundario nao estiver pronto
; no instante fixo do seu cast, o macro avisa em vez de estender a espera.
;
; Desligue o otimizador para voltar aos alvos fixos de Hoenn222_ComboTargetMs e
; Hoenn222_SwitchTargetMs; nenhuma outra mudanca e necessaria.
global Hoenn222_CdOptimizerEnabled := true
global Hoenn222_CdByTier := Map("Lendário", 40000, "UR", 43000, "SR", 45000, "T1", 50000)
global Hoenn222_CdDefaultMs := 50000
global Hoenn222_RateOutOfBall := 1.0
global Hoenn222_RateInBall := 0.5
global Hoenn222_LatencyMs := 250
global Hoenn222_MarginMs := 250
#Requires AutoHotkey v2.0
; Configuracao do macro. Tempos em ms. Guia de ajuste: CLAUDE.md; detalhes: docs/tiers-e-combo-hoenn222.md.

; --- Jogo e entrada ---
global GameWindow := "ahk_exe PokeAlliance_dx.exe"
global DeadzoneMove := 20000

; --- Esperas internas do combo (animacao do jogo; nao alterar sem medir) ---
global SleepAfterTankCombo := 2700    ; cast do tank -> chamada do secundario
global SleepAfterSwitch := 800        ; chamada do secundario -> inicio das acoes dele
global SleepAfterCombo := 3000        ; depois do combo

; --- Teclas ---
global KeyPokestop := "c"
global KeyMedicine := "f"
global KeyCombo := "i"
global KeyBallSpecial := "p"
global KeyBallSpecial2 := ""          ; opcional: vazio pula esta ball
global KeyBallSpecial3 := ""          ; opcional: vazio pula esta ball
global KeyRevive := "Space"
global KeyBuffMove := "f1"
global KeyPotion := "e"
global KeyChangeTarget := "Tab"
global KeyFullDef := "t"
global KeyFullAtk := "y"

; --- Tela ---
global PlayerOriginX := 936
global PlayerOriginY := 402
global Hoenn222CenterOffsetX := 0     ; quadrado central do indicador
global Hoenn222CenterOffsetY := -60

; --- Guild daily (X / direcional direito, nos dois modos) ---
; Coordenadas da area CLIENTE do jogo (Window Spy: Client), nao da tela.
; Deixar 0 desativa a renovacao ate configurar os dois botoes.
global GuildDailyRenewPos := {X: 0, Y: 0}
global GuildDailyConfirmPos := {X: 0, Y: 0}
global GuildDailyConfirmDelayMs := 300 ; espera entre renovar e confirmar

; --- Hoenn 2-2-2: duplas (editar ao trocar de respawn ou de time) ---
; Tier do tank e do secundario de cada dupla (1, 2 e 3). O rotulo define o CD pela
; tabela Hoenn222_CdByTier abaixo e e exibido como esta no indicador.
global Hoenn222_TankTier := Map(1, "SR", 2, "SR", 3, "SR")
global Hoenn222_SecondTier := Map(1, "Lendário", 2, "UR", 3, "UR")

; --- Hoenn 2-2-2: otimizador de cooldown ---
global Hoenn222_CdOptimizerEnabled := true
; Planejador por blocos validado em gameplay; false restaura a politica anterior.
global Hoenn222_UseDiscretePlanner := true
global Hoenn222_ComboPreparationMs := 235 ; estimativa do preparo ja existente, nao e Sleep
; Restricoes da distribuicao tolerante a +/-100 ms e preparo +/-50 ms.
; Nao alteram recuperacao, latencia ou MarginMs: exigem distancia dos limites no plano.
global Hoenn222_PlannerOutReserveMs := 300
global Hoenn222_PlannerBallReserveMs := 500
global Hoenn222_CdByTier := Map("Mythic", 35000, "Lendário", 40000, "UR", 43000, "SR", 45000, "T1", 50000)
global Hoenn222_CdDefaultMs := 50000  ; rotulo desconhecido
global Hoenn222_RateOutOfBall := 1.0  ; recuperacao de CD por segundo, fora da Ball
global Hoenn222_RateInBall := 0.5     ; e dentro da Ball
; Modelo empirico: dentro da Ball, creditar so blocos completos de 2 s (1 s de CD a 0,5x).
; A fracao e descartada ao sair. false volta ao modelo continuo; nao e regra comprovada.
global Hoenn222_InBallWholeBlocks := true
global Hoenn222_InBallBlockMs := 2000 ; 2 s na Ball recuperam 1 s de cooldown
global Hoenn222_LatencyMs := 250      ; congelamento do CD ao castar e ao sair da Ball na troca de time (tank)
; Congelamento estimado do CD do secundario ao ser chamado, separado da espera fisica.
; A versao por blocos foi validada com zero; a compensacao antiga nao prova latencia.
global Hoenn222_ExitLatencySecondaryMs := 0
global Hoenn222_MarginMs := 0       ; folga depois do CD estimado zerar (cada +50 ms ~ +0,1 s de volta)

; Alvos FIXOS de cada fase: usados so com o otimizador desligado ou se ele falhar.
global Hoenn222_ComboTargetMs := Map(1, 15000, 2, 16000, 3, 15500)    ; COMBAR
global Hoenn222_SwitchTargetMs := Map(1, 9500, 2, 11500, 3, 11500)    ; TROCAR TIME

; --- Hoenn 2-2-2: antecipacao ---
; Duas pressoes do mesmo botao dentro desta janela executam na hora (emergencia). 0 desliga.
global Hoenn222_EmergencyWindowMs := 400

; --- Hoenn 2-2-2: tempo fora minimo por dupla (opcional, 0 = so o que o CD exige) ---
; MinLure: tank fora antes do combo (troca de time -> cast). MinSecondaryOut: secundario
; fora (chamada -> proxima troca). Valores acima do exigido pelo CD aumentam a volta.
global Hoenn222_MinLureMs := Map(1, 0, 2, 0, 3, 0)
global Hoenn222_MinSecondaryOutMs := Map(1, 0, 2, 0, 3, 0)

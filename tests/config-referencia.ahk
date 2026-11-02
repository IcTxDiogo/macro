; CONFIG DE REFERENCIA DOS TESTES (nao e o config do jogo).
; Os runners de logica e de travamento carregam o config.ahk do jogador e, logo depois, este
; arquivo por cima: os testes nunca dependem do que o jogador ajustou (tiers, lures, esperas).
; So o teste de boot (run-config-startup-tests.ps1) usa o config.ahk real, de proposito.
; Toda chave `global` do config.ahk precisa existir aqui (Test-ConfigDeReferencia confere).
; Sem `global`: atribuicao no topo do script ja e global e nao redeclara a variavel.

; --- Jogo e entrada ---
GameWindow := "ahk_exe PokeAlliance_dx.exe"
DeadzoneMove := 20000

; --- Esperas internas do combo (animacao do jogo; nao alterar sem medir) ---
SleepAfterTankCombo := 2700    ; cast do tank -> chamada do secundario
SleepAfterSwitch := 800        ; chamada do secundario -> inicio das acoes dele
SleepAfterCombo := 3000        ; depois do combo

; --- Teclas ---
KeyPokestop := "c"
KeyMedicine := "f"
KeyCombo := "i"
KeyBallSpecial := "p"
KeyBallSpecial2 := ""          ; opcional: vazio pula esta ball
KeyBallSpecial3 := ""          ; opcional: vazio pula esta ball
KeyRevive := "Space"
KeyBuffMove := "f1"
KeyPotion := "e"
KeyChangeTarget := "Tab"
KeyFullDef := "t"
KeyFullAtk := "y"

; --- Tela ---
PlayerOriginX := 936
PlayerOriginY := 402
Hoenn222CenterOffsetX := 0     ; quadrado central do indicador
Hoenn222CenterOffsetY := -60

; --- Guild daily (X / direcional direito, nos dois modos) ---
; Coordenadas da area CLIENTE do jogo (Window Spy: Client), nao da tela.
; Deixar 0 desativa a renovacao ate configurar os dois botoes.
GuildDailyRenewPos := {X: 0, Y: 0}
GuildDailyConfirmPos := {X: 0, Y: 0}
GuildDailyConfirmDelayMs := 300 ; espera entre renovar e confirmar

; --- Hoenn 2-2-2: duplas (editar ao trocar de respawn ou de time) ---
; Tier do tank e do secundario de cada dupla (1, 2 e 3). O rotulo define o CD pela
; tabela Hoenn222_CdByTier abaixo e e exibido como esta no indicador.
Hoenn222_TankTier := Map(1, "SR", 2, "SR", 3, "SR")
Hoenn222_SecondTier := Map(1, "Lendário", 2, "UR", 3, "UR")

; --- Hoenn 2-2-2: otimizador de cooldown ---
Hoenn222_CdOptimizerEnabled := true
; Planejador por blocos validado em gameplay; false restaura a politica anterior.
Hoenn222_UseDiscretePlanner := true
Hoenn222_ComboPreparationMs := 235 ; estimativa do preparo ja existente, nao e Sleep
; Restricoes da distribuicao tolerante a +/-100 ms e preparo +/-50 ms.
; Nao alteram recuperacao, latencia ou MarginMs: exigem distancia dos limites no plano.
Hoenn222_PlannerOutReserveMs := 300
Hoenn222_PlannerBallReserveMs := 500
Hoenn222_CdByTier := Map("Mythic", 35000, "Lendário", 40000, "UR", 43000, "SR", 45000, "T1", 50000)
Hoenn222_CdDefaultMs := 50000  ; rotulo desconhecido
Hoenn222_RateOutOfBall := 1.0  ; recuperacao de CD por segundo, fora da Ball
Hoenn222_RateInBall := 0.5     ; e dentro da Ball
; Modelo empirico: dentro da Ball, creditar so blocos completos de 2 s (1 s de CD a 0,5x).
; A fracao e descartada ao sair. false volta ao modelo continuo; nao e regra comprovada.
Hoenn222_InBallWholeBlocks := true
Hoenn222_InBallBlockMs := 2000 ; 2 s na Ball recuperam 1 s de cooldown
Hoenn222_LatencyMs := 250      ; congelamento do CD ao castar e ao sair da Ball na troca de time (tank)
; Congelamento estimado do CD do secundario ao ser chamado, separado da espera fisica.
; A versao por blocos foi validada com zero; a compensacao antiga nao prova latencia.
Hoenn222_ExitLatencySecondaryMs := 0
Hoenn222_MarginMs := 0       ; folga depois do CD estimado zerar (cada +50 ms ~ +0,1 s de volta)

; Alvos FIXOS de cada fase: usados so com o otimizador desligado ou se ele falhar.
Hoenn222_ComboTargetMs := Map(1, 15000, 2, 16000, 3, 15500)    ; COMBAR
Hoenn222_SwitchTargetMs := Map(1, 9500, 2, 11500, 3, 11500)    ; TROCAR TIME

; --- Hoenn 2-2-2: antecipacao ---
; Duas pressoes do mesmo botao dentro desta janela executam na hora (emergencia). 0 desliga.
Hoenn222_EmergencyWindowMs := 400

; --- Hoenn 2-2-2: tempo fora minimo por dupla (opcional, 0 = so o que o CD exige) ---
; MinLure: tank fora antes do combo (troca de time -> cast). MinSecondaryOut: secundario
; fora (chamada -> proxima troca). Valores acima do exigido pelo CD aumentam a volta.
Hoenn222_MinLureMs := Map(1, 0, 2, 0, 3, 0)
Hoenn222_MinSecondaryOutMs := Map(1, 0, 2, 0, 3, 0)

; --- Hoenn 1,5 (os grupos do 1,5 ainda ajustam o que testam em PrepararTeste15) ---
StartMode := "Hoenn222"
Hoenn15_OpenerTier := Map(1, "Lendário", 2, "UR")
Hoenn15_FinisherTier := Map(1, "SR", 2, "SR")
Hoenn15_MiddlePart1Skills := Map(1, [{Key: "f9", CdMs: 45000}, {Key: "f6", CdMs: 20000}], 2, [{Key: "f6", CdMs: 40000}, {Key: "f5", CdMs: 35000}])
Hoenn15_MiddlePart2Skills := Map(1, [{Key: "f8", CdMs: 40000}, {Key: "f7", CdMs: 40000}, {Key: "f5", CdMs: 35000}], 2, [{Key: "f8", CdMs: 43000}, {Key: "f7", CdMs: 40000}])
Hoenn15_GuestSkill := Map()
Hoenn15_GuestSleepAfterMs := 1000
Hoenn15_SkillGapMs := 300
Hoenn15_SleepAfterPart1Ms := Map(1, 2700, 2, 2700)
Hoenn15_SleepAfterPart2Ms := Map(1, 2700, 2, 2700)
Hoenn15_MinLureMs := Map(1, 10000, 2, 10000)
Hoenn15_MinLure2Ms := Map(1, 14000, 2, 14000)

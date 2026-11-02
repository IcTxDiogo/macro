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
global GuildDailyRenewPos := { X: 0, Y: 0 }
global GuildDailyConfirmPos := { X: 0, Y: 0 }
global GuildDailyConfirmDelayMs := 300 ; espera entre renovar e confirmar

; --- Hoenn 2-2-2: duplas (editar ao trocar de respawn ou de time) ---
; Tier do tank e do secundario de cada dupla (1, 2 e 3). O rotulo define o CD pela
; tabela Hoenn222_CdByTier abaixo e e exibido como esta no indicador.
global Hoenn222_TankTier := Map(1, "Lendário", 2, "UR", 3, "UR")
global Hoenn222_SecondTier := Map(1, "Lendário", 2, "Lendário", 3, "Lendário")

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
global Hoenn222_MinLureMs := Map(1, 10000, 2, 10000, 3, 10000)
global Hoenn222_MinSecondaryOutMs := Map(1, 0, 2, 0, 3, 0)

; --- Hoenn 1,5: dois times de 3 (abre / meio / finaliza), 4 lures por volta ---
; Modo ao abrir/recarregar o macro: "Hoenn222" ou "Hoenn15" (F12 / Back alterna depois).
global StartMode := "Hoenn222"
; Teclas do jogo: time 1 = {1} abre, {2} meio, {3} finaliza; time 2 = {4}, {5}, {6}.
; Quem abre e quem finaliza usam o combo (KeyCombo); o CD sai do tier (Hoenn222_CdByTier).
global Hoenn15_OpenerTier := Map(1, "Lendário", 2, "UR")
global Hoenn15_FinisherTier := Map(1, "SR", 2, "SR")
; Meio: skills de cada parte, na ordem de envio, com o CD de cada uma.
; Parte 1 (lure 1, SEM o stun) e parte 2 (lure 2, stun por ultimo). O CD de cada parte e o
; da skill mais lenta, contado a partir do envio dela.
; Time 1: 410 abre / 330 meio (107+30 | 82+112+stun) / 326 finaliza (berry: 351).
; Time 2: 358 abre / 360 meio (85+85 | 106+stun 88) / 348 finaliza (berry: 366). No jogo: 358 na
; tecla 4 e 360 na tecla 5. A lure 1 do time 2 ganha a F6 (30k) do 330 emprestada (abaixo).
; Medido no dummy: combo 3 = 553 e combo 4 = 540 com 106+85 | 85+stun; agora ~562 / ~561.
global Hoenn15_MiddlePart1Skills := Map(1, [{Key: "f9", CdMs: 45000}, {Key: "f6", CdMs: 20000}], 2, [{Key: "f7", CdMs: 40000}, {Key: "f5", CdMs: 40000}])
global Hoenn15_MiddlePart2Skills := Map(1, [{Key: "f8", CdMs: 40000}, {Key: "f7", CdMs: 40000}, {Key: "f5", CdMs: 35000}], 2, [{Key: "f8", CdMs: 43000}, {Key: "f6", CdMs: 40000}])
; Skill emprestada: na parte 1 do time (chave), depois do combo de quem abre, o macro chama o
; meio de outro time (FromTeam), da Pokestop + Medicine, usa a skill (Key) e so entao chama o
; proprio meio. Serve para skill de CD curto que o meio dono ja usa (F6 do 330: 20 s, 30k).
; Map() vazio desliga.
global Hoenn15_GuestSkill := Map(2, {FromTeam: 1, Key: "f6", CdMs: 20000})
global Hoenn15_GuestSleepAfterMs := 1000                 ; skill emprestada -> chamada do meio
global Hoenn15_SkillGapMs := 300                       ; entre uma skill e a proxima do meio (50 e 100 nao bastaram no jogo)
global Hoenn15_SleepAfterPart1Ms := Map(1, 2700, 2, 2700) ; ultima skill da parte 1 -> pocao (depois vem a lure 2)
global Hoenn15_SleepAfterPart2Ms := Map(1, 2700, 2, 2700) ; ultima skill da parte 2 -> chamada do finalizador
; Tempo de lure, como o Hoenn222_MinLureMs. 0 = so o CD manda.
; Lure 1 (quem abre): da troca de time ate o combo.
global Hoenn15_MinLureMs := Map(1, 10000, 2, 10000)
; Lure 2 (o meio): da pocao ate a parte 2. Inclui ir ate o ponto de divisa (medido: 13-15,5 s).
global Hoenn15_MinLure2Ms := Map(1, 14000, 2, 14000)
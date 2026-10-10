#Requires AutoHotkey v2.0
; Configuracao do macro. Tempos em ms. Explicacao de cada bloco: docs/estrutura.md.

; --- Jogo e entrada ---
global GameWindow := "ahk_exe PokeAlliance_dx.exe"
global DeadzoneMove := 20000

; --- Esperas internas do combo (animacao do jogo; nao alterar sem medir) ---
global SleepAfterTankCombo := 2700    ; cast do tank -> chamada do secundario
global SleepAfterSwitch := 800        ; chamada do secundario -> cast dele
global SleepAfterCombo := 3000        ; depois do combo
global SleepAfterSecondCombo := 3000  ; modo 3-3

; --- Teclas ---
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

; --- Tela ---
global TileSize := 70
global PlayerOriginX := 936
global PlayerOriginY := 402
global Hoenn222CenterOffsetX := 0     ; quadrado central do indicador
global Hoenn222CenterOffsetY := -60

; --- Hoenn 2-2-2: duplas (editar ao trocar de respawn ou de time) ---
; Tier do tank e do secundario de cada dupla (1, 2 e 3). O rotulo define o CD pela
; tabela Hoenn222_CdByTier abaixo e e exibido como esta no indicador.
global Hoenn222_TankTier := Map(1, "SR", 2, "SR", 3, "SR")
global Hoenn222_SecondTier := Map(1, "Lendário", 2, "UR", 3, "UR")

; --- Hoenn 2-2-2: otimizador de cooldown ---
global Hoenn222_CdOptimizerEnabled := true
global Hoenn222_CdByTier := Map("Lendário", 40000, "UR", 43000, "SR", 45000, "T1", 50000)
global Hoenn222_CdDefaultMs := 50000  ; rotulo desconhecido
global Hoenn222_RateOutOfBall := 1.0  ; recuperacao de CD por segundo, fora da Ball
global Hoenn222_RateInBall := 0.5     ; e dentro da Ball
global Hoenn222_LatencyMs := 250      ; congelamento do CD ao castar e ao sair da Ball na troca de time (tank)
; Congelamento do CD do SECUNDARIO ao ser chamado. E um atraso fisico proprio (chamada,
; recolhida do tank, bola), medido na gravacao de 09/10: o modelo com 250 ms estava ~0,9 s
; otimista e a F7 do Rampardos foi comida 2 de 5. Nao e margem: a margem fica so para ruido.
global Hoenn222_ExitLatencySecondaryMs := 1100
global Hoenn222_MarginMs := 450       ; folga depois do CD estimado zerar (cada +50 ms ~ +0,1 s de volta)

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
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
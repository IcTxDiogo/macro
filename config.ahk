#Requires AutoHotkey v2.0

; --- CONFIGURAÇÕES GLOBAIS ---

; Nome da janela do jogo
global GameWindow := "PokeAlliance"

; Deadzone para movimento analógico
global DeadzoneMove := 20000

; Tempos de espera (em ms)
global SleepAfterCombo := 3000
global SleepAfterSwitch := 800
global SleepAfterSecondCombo := 3000
global SleepAfterThirdCombo := 4000
global SleepAfterHeal := 700

; Teclas para ações
global KeyPokestop := "c"
global KeyMedicine := "f"
global KeyCombo := "i"
global KeyMovePokemon := "q"
global KeyBall := "v"
global KeyBallSpecial := "p"
global KeyRevive := "Space"
global KeyBuffMove := "f1"
global KeyBuffDrop := "j"
global KeyPotion := "e"
global KeyChangeTarget := "Tab"
global KeyFullDef := "t"
global KeyFullAtk := "y"
global KeyPokeMoveF3 := "f3"

; Tamanho do tile (em px)
global TileSize := 70

; Coordenadas do personagem
global PlayerOriginX := 970
global PlayerOriginY := 410
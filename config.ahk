#Requires AutoHotkey v2.0

; --- CONFIGURAÇÕES GLOBAIS ---

; Nome da janela do jogo
global GameWindow := "PokeAlliance"

; Deadzone para movimento analógico
global DeadzoneMove := 20000

; Tempos de espera (em ms)
global SleepAfterCombo := 3000
global SleepAfterSwitch := 1000
global SleepAfterSecondCombo := 3000
global SleepAfterThirdCombo := 5000
global SleepAfterHeal := 700

; Teclas para ações
global KeyPokestop := "c"
global KeyMedicine := "f"
global KeyCombo := "i"
global KeyMovePokemon := "q"
global KeyBall := "k"
global KeyRevive := "Space"
global KeyBuffMove := "f1"
global KeyBuffDrop := "j"
#Requires AutoHotkey v2.0
; Indice dos modulos. Camadas (cada uma so conhece as de cima nesta lista):
;   nucleo    estado global e log; sem regra de jogo
;   tempo     CONTROLE DE TEMPO: cooldown por Pokemon, plano da volta, cronometro e verde.
;             Nunca envia tecla nem toca na janela ou na interface.
;   macro     o que o macro FAZ no jogo: teclas, rodizios, troca de time, antecipacao, modos
;   interface gamepad (laco de 30 ms) e indicador visual
; A ORDEM importa: estado e cooldown leem o config.ahk ao carregar (main.ahk o inclui antes).
#Include nucleo\logger.ahk
#Include nucleo\estado.ahk

#Include tempo\cooldown.ahk
#Include tempo\planejador.ahk
#Include tempo\cronometro.ahk

#Include macro\teclas.ahk
#Include macro\teclas_inativas.ahk
#Include macro\troca_time.ahk
#Include macro\rodizio_222.ahk
#Include macro\antecipacao.ahk
#Include macro\antecipacao_combo.ahk
#Include macro\antecipacao_troca.ahk
#Include macro\modos.ahk
#Include macro\acoes.ahk

#Include interface\quadrado_central.ahk
#Include interface\painel.ahk
#Include interface\controle.ahk

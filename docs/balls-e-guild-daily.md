# Balls especiais e guild daily

## Captura (B / direcional esquerdo)

Cada pressao envia uma ball: 1, 2, 3, 1... Configure `KeyBallSpecial` (a primeira,
padrao `p`), `KeyBallSpecial2` e `KeyBallSpecial3` em `config.ahk`.
As teclas 2 e 3 vazias sao puladas; com apenas a primeira, o comportamento e o anterior.
O macro acompanha apenas os envios, sem detectar estoque ou sucesso da captura no jogo.
O indice fica so na memoria: reabrir ou reiniciar (Start / Ctrl+Esc) comeca pela primeira.
F8 e troca de modo nao zeram a sequencia de balls.

## Renovacao da guild daily (X / direcional direito)

Configure `GuildDailyRenewPos` e `GuildDailyConfirmPos` com X e Y de cada botao,
usando as coordenadas **Client** do Window Spy do AutoHotkey. Sao relativas a area
interna da janela do jogo, sem borda/barra de titulo. Nao copie coordenadas de tela
das imagens sem converter para a sua janela/resolucao.

Os dois pontos comecam em zero (desativados ate configurar). Abra a janela da guild
daily no jogo antes de acionar. O macro clica em renovar, espera
`GuildDailyConfirmDelayMs` (padrao 300 ms) e clica em confirmar. Ajuste a espera se
o dialogo demorar mais para abrir. A confirmacao consome o ticket conforme o jogo.
Nao ha reconhecimento de imagem nem abertura automatica da janela de daily.
Funciona nos dois modos. Segurar o botao dispara apenas uma vez; solte para renovar novamente.

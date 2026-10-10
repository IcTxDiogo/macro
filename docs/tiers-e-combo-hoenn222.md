# Tiers por dupla e combo antecipado/emergência — Hoenn 2-2-2

Comportamento e decisões do 2-2-2: tiers, botão de combo e gatilho de troca (normal,
armado, emergência), ritmo da 1ª volta, latências e correções. Os módulos estão em
`docs/estrutura.md`. As seções datadas contam como o modelo chegou ao estado atual; os
parâmetros vigentes estão no `config.ahk`.

## 1. Configuração de tier e de tempo

Tudo que é do respawn está num único bloco do `config.ahk`:

| Chave | Papel |
| --- | --- |
| `Hoenn222_TankTier` | rótulo do tier do tank de cada dupla (`Lendário`, `UR`, `SR`, `T1`) |
| `Hoenn222_SecondTier` | rótulo do tier do secundário de cada dupla |
| `Hoenn222_CdByTier` | CD principal de cada rótulo (40 / 43 / 45 / 50 s) |
| `Hoenn222_CdDefaultMs` | CD usado se o rótulo não estiver na tabela (50000) |
| `Hoenn222_ComboTargetMs` / `Hoenn222_SwitchTargetMs` | alvos FIXOS de COMBAR e TROCAR TIME: só valem com o otimizador desligado ou se ele falhar |
| `Hoenn222_EmergencyWindowMs` | janela do duplo acionamento (0 desliga) |

Com o otimizador ligado (padrão), o verde de cada fase vem do estado real dos seis Pokémon
(ver `docs/arquitetura-otimizador-cooldown.md`), não dos alvos fixos. O rótulo escolhe o CD
pela tabela `Hoenn222_CdByTier` e aparece como está no indicador. Rótulo fora da tabela usa
`Hoenn222_CdDefaultMs` e registra `CD_TIER_UNKNOWN` uma vez; um time ausente do mapa mostra
`?` no indicador e registra `phase=tier_config`. Nada disso derruba o cronômetro.

### Por que ainda existem alvos fixos

Foram a primeira versão: medidas do respawn (COMBAR `15000/16000/15500` ms e TROCAR TIME
`9500/11500/11500` ms por dupla), que não são função só da raridade (duplas com os mesmos
tiers trocados davam resultados diferentes). Hoje são a rede de segurança: se o cálculo do
otimizador lançar exceção, o macro volta a eles em vez de travar.

## 2. Botão de combo: normal, antecipado e emergência

`PedirCombo()` (chamado por `PedirProximaAcao()` na fase COMBAR) classifica
a pressão e age em uma das três saídas:

| Caso | Entrada | Resultado |
| --- | --- | --- |
| A — antecipado | 1ª pressão com o contador ainda amarelo | o pedido fica armado, nada é enviado; o macro executa sozinho ao ficar verde |
| B — normal | 1ª pressão com o contador verde | executa na hora, como antes |
| C — emergência | 2ª pressão dentro de `Hoenn222_EmergencyWindowMs` | ignora o contador e executa na hora |

O pedido armado aparece como `COMBO ARMADO` no tooltip, para nunca ficar
invisível.

### Duplo acionamento

A detecção é por tempo entre duas pressões do mesmo botão, medida em
`A_TickCount` na entrada de `PedirCombo()`. Ela não depende de
thread, timer ou estado anterior, então funciona igual para `XButton1` e para
os bumpers do controle (ambos já geram um evento por transição de solto para
pressionado).

A janela padrão é 400 ms. Dentro dela, a segunda pressão **não** re-arma o
pedido: ela consome e executa. Fora dela, o comportamento é o da primeira
pressão. `Hoenn222_EmergencyWindowMs := 0` desliga a emergência e mantém só o
pedido antecipado.

### Troca de time: o mesmo pedido, na fase TROCAR TIME

A troca para o próximo time segue a mesma regra do combo. `PedirTrocaDeTime()` usa o verde da
fase `TROCAR TIME`, lido do mesmo `FaltaParaVerdeMs()`.

| Fase | Pressão | Resultado |
| --- | --- | --- |
| `TROCAR TIME` verde | 1ª | troca na hora |
| `TROCAR TIME` amarelo | 1ª | `TROCA ARMADA`; troca sozinha no instante do verde |
| `TROCAR TIME` | 2ª dentro de `Hoenn222_EmergencyWindowMs` | emergência: troca na hora e consome o pedido |

O pedido de troca fica preso ao time em que foi feito e é cancelado por F8, troca de modo e
mudança de time. Diagnóstico: `SWITCH_REQUEST`, `SWITCH_ARMED`, `SWITCH_FIRED`,
`SWITCH_DISARMED`, `SWITCH_RESULT`. O cálculo do verde nunca prende a troca: se ele lançar
exceção, vale o comportamento antigo (troca na hora) e o erro vai para `phase=switch_readiness`.

O alvo de `TROCAR TIME` é `janela − lure` do plano, medido a partir do cast. A janela do plano
começa na troca de time e o lure acontece antes do cast; usar a janela inteira contava o lure
duas vezes.

### Botão único: a próxima ação do ciclo

No modo 2-2-2 existe **uma ação só**: `PedirProximaAcao()` olha a fase e pede o próximo
movimento. LB/RB, LT/RT e os dois botões laterais do mouse fazem o mesmo.

| Fase | O botão pede | Em espera (amarelo/azul) | Verde | 2 cliques seguidos |
| --- | --- | --- | --- | --- |
| antes do 1º combo, `COMBAR` | o combo | arma e executa sozinho no verde | executa na hora | executa na hora |
| `TROCAR TIME` | a troca de time | arma e troca sozinho no verde | troca na hora | troca na hora |

Durante o rodizio a fase já é `TROCAR TIME`: apertar de novo nessa hora arma a troca, que sai
sozinha no verde. Combo e troca nunca ficam armados ao mesmo tempo. Diagnóstico: o evento
`NEXT_ACTION` registra origem, fase e a ação escolhida. No modo Normal nada muda (bumpers =
combo simples, gatilhos = reviver).

### Primeira volta: o ritmo do plano vale desde o primeiro ciclo

Ao ligar o macro ou depois do F8, os seis Pokémon estão com o CD pronto. Só pelo
cooldown nada obrigaria a esperar: a troca para o time 2 liberava o combo na hora
(CD zero) e a espera inteira caía de uma vez na volta do time 1. Por isso, enquanto
um time ainda não fez o primeiro cast do tank depois do F8
(`TankJaCastou`), o verde do `COMBAR` só acende depois do `lure` planejado,
contado da troca de time. Depois do primeiro cast quem manda é só o cooldown real.

Simulação com as funções de produção (SR/Lendário, SR/UR, SR/UR): combos em
0,0 s, 21,2 s e 48,3 s; trocas em 8,3 s, 35,4 s e 62,6 s; o time 1 volta a
combar em 75,5 s, que é o `L` do plano (margem de 400 ms da época; hoje ~76,9 s), e todas as
voltas seguintes duram o mesmo.
### Margem do secundário e latência da chamada

O jogo só conta o CD `LatencyMs` depois de o Pokémon sair da Ball, e o acumulador
aplica esse congelamento na chamada do p2. A tolerância do secundário e o plano
não o contavam, então num ciclo perfeito o secundário era usado ~10 ms depois do
CD zerar, não 250 ms. Agora a tolerância é
`0,5 × SleepAfterTankCombo + (SleepAfterSwitch − Latency) − Margin` e o secundário
entra no plano com `2·Latency + Margin` (o tank continua com `Latency + Margin`).
Teste Z: num ciclo perfeito, todo cast de tank e de secundário ocorre depois de
CD zerado + margem. Custo: a volta do plano sobe cerca de 0,2 s.

> **Superado em parte:** o secundário passou a ter atraso de saída próprio (seção \
### Tempo fora mínimo (conforto): `Hoenn222_MinLureMs` e `Hoenn222_MinSecondaryOutMs`

A volta mínima usa só o cooldown, sem folga para o jogador. Dois pisos por dupla no
`config.ahk` dão esse tempo: o tank fica fora ao menos `MinLureMs` antes do combo
(da troca ao cast) e o secundário ao menos `MinSecondaryOutMs` (da chamada à troca).
O macro nunca libera o combo antes do piso e o planejador acha a menor volta que
cabe, já tirando do secundário o que o cooldown dele permite. Regra de bolso:
cada +1 s de volta libera ~7 s de tempo fora para dividir entre os seis Pokémon.

Valores de 09/10, com margem de 400 ms e esses pisos como padrão. Hoje os pisos padrão são 0
(`MinLureMs`/`MinSecondaryOutMs` no `config.ahk`) e a volta do plano é ~76,9 s; a regra
de bolso acima continua valendo.

SR/Lendário, SR/UR, SR/UR, simulação de jogador perfeito:

| Pisos | Volta | Lure tank | Secundário fora |
| --- | --- | --- | --- |
| nenhum | 75,9 s | 12,7 s | 5,9 / 11,9 / 11,9 s |
| lure 15 s | 77,6 s | 15,0 s | 4,2 / 10,2 / 10,2 s |
| lure 15 s + secundário do time 1 em 8 s (padrão na época) | 78,9 s | 15,0 s | 8,0 / 8,9 / 8,9 s |
| lure 15 s + secundário do time 1 em 8 s + secundários 2 e 3 em 12 s | 85,1 s | 15,0 s | 8,0 / 12,0 / 12,0 s |

### Congelamento do movimento durante a ação armada (corrigido)

O laço de 30 ms (`GameLoop`) também envia o movimento. Quando a ação armada
disparava a partir dele, o combo (~6,5 s) ou a troca (~1 s) subia **por cima** da
thread do laço; o AutoHotkey não reinicia um timer enquanto a instância antiga
existe, então movimento, botões e quadrado paravam até a ação terminar.
Agendar com `SetTimer(..., -1)` não bastava: com chamadas lentas no laço
(`ControlSend`, `WinExist`, `ToolTip`) o timer ainda interrompia o laço.

Correção: `Thread("NoTimers")` no início do `GameLoop` (nenhum timer sobe por
cima dele; as ações começam quando a volta termina), disparo automático em thread
descartável (`DispararComboArmado`, `DispararTrocaArmada`) e
atalhos do mouse agendados como o controle. Regra: **nunca** usar `Critical`,
`Sleep` ou ação longa direto no `GameLoop`.

Teste permanente: `tests/run-live-stall-test.ps1` (timers e `Sleep` reais).
Antes da correção: laço parado 6828 ms no combo e 953 ms na troca; depois: 62 ms e
94 ms. O log registra `LOOP_STALL` se o laço ficar parado mais de 400 ms.
### Latência de saída da Ball também para o tank (troca de time)

O acumulador aplicava a latência de saída da Ball ao secundário (chamada do p2), mas
creditava o tank novo com recuperação 1,0 desde a tecla da troca. Os casts de tank
saíam ~250 ms otimistas (teste em jogo de 09/10: tanks usados 412–420 ms depois do CD
estimado zerar, contra 640–4300 ms antes, quando a demora do jogador e o travamento
escondiam a folga). Agora os seis perdem a latência duas vezes por intervalo entre
casts (saída da Ball e início do CD novo): `RegistrarTrocaDeTime` congela o tank novo
por `LatencyMs`, o planejador usa `2·Latency + Margin` para todos e
`MsAteCastSeguro` soma o congelamento ainda por vir. Num ciclo perfeito todo cast
cai a `Margin` + 0–5 ms depois do CD zerado. Custo: a volta do plano sobe 0,2 s.

### Atraso de saída próprio do secundário (gravação de 09/10 19:39–19:46)

A F7 do Rampardos (secundário do time 2) foi comida 2 vezes em 5 e o teste seguinte
mostrou o mesmo em outro secundário (time 3): sempre secundários, sempre com a skill
"pronta" no cliente e rejeitada pelo servidor. O cruzamento barra F1–F8 × log mostrou
que o modelo estava ~0,9 s otimista só para o secundário, enquanto o tank ficava
dentro do erro de medida. A causa estava na estrutura: uma única constante
(`LatencyMs = 250`) cobria três atrasos físicos diferentes — início do CD depois do
cast, saída do tank (troca de time) e saída do secundário (chamada). O da chamada é
maior: o tank é recolhido, a Ball abre e a barra do secundário só aparece ~0,6 s depois
da tecla.

Agora `Hoenn222_ExitLatencySecondaryMs` (1100 ms) congela o CD do secundário depois da
chamada (`RegistrarChamadaDoSecundario`), entra no planejador
(`margemSec = Latency + ExitLatencySecondary + Margin`), na tolerância do combo
(`Max(0, SleepAfterSwitch − ExitLatencySecondary) − Margin`) e no pendente do
secundário. `MarginMs` volta a ser só folga de ruído. Custo medido nos testes: volta do
plano 76,2 → 76,9 s. O valor 1100 ms vem de 2 falhas em ~14 casts de secundário; ajuste
com `CD_CAST`/`CD_ENTRADA` + barra se aparecerem mais falhas.
## 3. Garantias

- **Um pedido por vez.** `IniciarRodizio222()` consome o pedido armado
  junto com a trava `RodizioAtivo`, dentro de `Critical`. Botão e varredura
  nunca passam juntos pelo bloqueio, e a trava só é armada com time válido
  (1–3) — antes, um time inválido deixava `RodizioAtivo` travado para sempre.
- **Nunca no time errado.** O pedido guarda o time em que foi feito
  (`TimeDoComboArmado`). A varredura descarta o pedido se o modo ou o
  time mudarem, e a troca de time, o F8 e a troca de modo cancelam o pedido
  explicitamente (`reason=team_switch`, `resync`, `mode_change`).
- **Sem execução concorrente.** O disparo automático agenda o mesmo
  `SetTimer(..., -1)` do combo manual; a validação de time/modo
  `execIdOriginal` já existente continua valendo.
- **Sem atraso novo.** A varredura roda no laço de 30 ms que já existe e usa
  o mesmo cálculo do indicador, `FaltaParaVerdeMs()`. Não há sleep, nem
  timer novo, nem polling adicional.
- **Interface não participa da decisão.** O disparo fica antes do bloco de
  renderização e em `try/catch` próprio, então uma falha de tooltip não come
  o pedido, e uma falha do pedido não come o tooltip.
- **Falha de cálculo.** Na pressão, vale o comportamento antigo (executa). Na
  varredura, vale a espera (não dispara). Em ambos os casos a exceção vai para
  `phase=combo_readiness`.

### Estados alcançados pelo pedido

`FaltaParaVerdeMs()` devolve `0` em `WAITING_FIRST_COMBO`, então o
primeiro combo continua imediato, como o F8 espera. Nos demais estados o
verde significa "agora": um pedido armado durante `TROCAR TIME` também espera
o verde daquele estado. É a leitura mais previsível do indicador e evita
casos especiais por fase.

## 4. Diagnóstico

Tudo em `A_Temp\macro_switch_debug.log`:

| Evento | Significado |
| --- | --- |
| `COMBO_REQUEST gap_ms= missing_ms= emergency= armed=` | pressão recebida; `gap_ms` negativo na primeira pressão, `emergency=true` na segunda dentro da janela |
| `COMBO_RESULT result=immediate \| emergency \| ignored` | desfecho da pressão (`ignored` = combo em andamento) |
| `COMBO_ARMED team= missing_ms=` | pedido antecipado registrado |
| `COMBO_FIRED team= reason=armed` | disparo automático, sem nova pressão |
| `COMBO_DISARMED reason=team_switch \| resync \| mode_change \| context_changed \| combo_running` | pedido descartado |

O logger de sessão passou a registrar a origem do combo:
`COMBO START | Modo: 2-2-2 | Time: 1 | Origem: manual | antecipado | emergencia`.

Indicador visual — o quadrado e o botão leem o mesmo pendente, então a cor diz
exatamente o que o botão vai fazer:

| Cor | Significado |
| --- | --- |
| Verde | apertar executa na hora (inclui `Aguardando sincronização`) |
| Azul | `COMBAR` com até 10 s para o verde |
| Violeta | há pedido armado; executa sozinho ao ficar verde |
| Amarelo | demais casos de espera |

O alvo de `COMBAR` do otimizador é *quanto falta a partir de agora*; ele chega ao
contador somado ao decorrido, de modo que o pendente é exatamente o que falta
(antes o decorrido era descontado duas vezes e o verde acendia na metade do tempo).
A margem de segurança conta a partir do instante em que o CD zerou.

O tooltip mostra `Tank:` e `Sec:` lidos do `config.ahk` (não há mais `Ref: <tier>` fixo).

Rotação 2+2+2, teclas `{1}/{3}/{5}` e `{2}/{4}/{6}`, `SleepAfterTankCombo`,
`SleepAfterCombo`, `SleepAfterSwitch`, sequência de habilidades, debounce de 1000 ms
da troca, modo `Normal`, logger, tooltips (IDs, posições, quadrado central) e
F8/F12/XButton1/XButton2. (A dívida global `Hoenn222_DebtMs` deixou de existir: cada
Pokémon tem o próprio acumulador de CD.)

`Sleep`, `SetTimer` e o agendamento do combo são idênticos: a única diferença
em `IniciarRodizio222()` é a trava ser decidida sob `Critical` e haver
validação de time.

## 6. Testes

```powershell
.\tests\run-hoenn-switch-tests.ps1
.\tests\run-hoenn-switch-tests.ps1 -LoggerInitFailure
```

**44 grupos PASS** (**45** com `DirCreate` falhando) mais o teste de congelamento
demais (H–AD: CD individual, plano, 1ª volta, pisos, atraso de saída) estão em
`tests/hoenn-switch-tests.ahk`.

| Grupo | Cenário | Resultado |
| --- | --- | --- |
| A | pressão antes do verde, sem pressionar de novo | arma, não envia nada, dispara sozinho ao virar verde, consome o pedido |
| B | verde sem pressão, depois com pressão | nunca automático; executa na pressão |
| C | duas pressões dentro e fora da janela | emergência executa e descarta o pedido; fora da janela só re-arma; janela `0` desliga |
| D | troca de time aceita com pedido armado | cancela (`team_switch`), não vaza combo para o time novo |
| E | F8 e troca de modo com pedido armado | cancelam; nada executa depois |
| F | tiers e alvos lidos do `config.ahk` | alterar os mapas muda alvo e rótulo sem tocar no código; time inexistente devolve `?` |
| G | sync imediato, pedido armado e trava | primeiro combo imediato; combo direto consome o pedido; trava impede duplicata |

Correção no runner: `$process.Handle` passou a ser lido logo após
`Start-Process`. Sem isso o `ExitCode` fica vazio no PowerShell 5.1 e uma
execução inteiramente verde era reportada como falha.

Validação de carga: `tests\run-hoenn-switch-tests.ps1` roda `AutoHotkey /validate main.ahk`, que
carrega todos os includes e confere a sintaxe sem executar nada (nao le o gamepad nem envia
tecla). Nunca suba o `main.ahk` de verdade com o jogo aberto.

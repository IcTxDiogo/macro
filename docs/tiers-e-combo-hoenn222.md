# Tiers por dupla e combo antecipado/emergência — Hoenn 2-2-2

Alterações em `config.ahk`, `main.ahk`, `src/hoenn_engine.ahk`,
`src/mapeamento-controle.ahk`, `src/logger.ahk` e nos testes isolados.
Nenhuma execução dentro do jogo foi feita nesta intervenção; a verificação
foi feita sobre as funções de produção com as fronteiras de I/O substituídas
por mocks, mais um boot real do script principal sem janela de jogo.

## 1. Configuração de tier e de tempo

Antes, o alvo do cronômetro e o rótulo do tier eram Conditional dentro do
código:

```ahk
GetHoenn222BaseTargetMs(state, timeIndex) {
    if (state == "WAITING_COMBO")
        return (timeIndex == 1) ? 15000 : ((timeIndex == 2) ? 16000 : 15500)
    ...
```

```ahk
refText := (TimeAtual == 1) ? "Lendário" : "UR"
```

Ou seja, trocar de respawn exigia editar duas funções e o valor fixo ficava
espalhado. Agora tudo que é do respawn está em um único bloco do `config.ahk`:

| Chave | Papel |
| --- | --- |
| `Hoenn222_TankTier` | rótulo do tier do Tank/Lurer de cada dupla |
| `Hoenn222_SecondTier` | rótulo do tier do secundário chamado no combo |
| `Hoenn222_ComboTargetMs` | ms dentro do time até o verde (fase COMBAR) |
| `Hoenn222_SwitchTargetMs` | ms após o combo até o verde (fase TROCAR TIME) |
| `Hoenn222_EmergencyWindowMs` | janela do duplo acionamento (0 desliga) |

Os rótulos de tier são **texto livre**: o que estiver no arquivo aparece no
indicador, sem tabela de conversão no código. Um time ausente ou um mapa
inválido devolve `?` e um alvo `0`, e registra `phase=tier_config` ou
`phase=target_config` — nunca derruba o cronômetro.

### Por que tempo e tier são configurados separados

Os alvos atuais **não** são deriváveis do tier. Se `COMBAR` fosse
`tank + secundário`, os valores medidos seriam inconsistentes:

| Dupla | Tank | Secundário | COMBAR medido |
| --- | --- | --- | --- |
| 1 | Lendário | UR | 15000 |
| 2 | UR | SR | 16000 |
| 3 | SR | UR | 15500 |

As duplas 2 e 3 trocam os papéis e mesmo assim diferem em 500 ms, e `UR + SR`
aparece duas vezes com resultados diferentes. Os alvos são medições do
respawn (move, cleanse, cadência do alvo), não uma função da raridade. Forçar
uma fórmula mudaria o comportamento atual de todo respawn; por isso os dois
ficam lado a lado no `config.ahk`, e o tier sozinho apenas troca o rótulo.

Os valores padrão reproduzem exatamente o comportamento anterior
(`15000/16000/15500` e `9500/11500/11500`).

## 2. Botão de combo: normal, antecipado e emergência

`Acao_Bumpers()` chama `SolicitarComboHoenn222()` no modo 2-2-2. Ela classifica
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
`A_TickCount` na entrada de `SolicitarComboHoenn222()`. Ela não depende de
thread, timer ou estado anterior, então funciona igual para `XButton1` e para
os bumpers do controle (ambos já geram um evento por transição de solto para
pressionado).

A janela padrão é 400 ms. Dentro dela, a segunda pressão **não** re-arma o
pedido: ela consome e executa. Fora dela, o comportamento é o da primeira
pressão. `Hoenn222_EmergencyWindowMs := 0` desliga a emergência e mantém só o
pedido antecipado.

### Gatilho de troca de time (LT/RT e XButton2)

A mesma regra vale para o outro movimento do ciclo, a troca para o próximo time.
`Acao_Gatilhos()` chama `SolicitarTrocaHoenn222()`; o verde é o do estado
`TROCAR TIME`, lido do mesmo `GetHoenn222PendingMs()`.

| Fase | Pressão | Resultado |
| --- | --- | --- |
| `TROCAR TIME` verde | 1ª | troca na hora |
| `TROCAR TIME` amarelo | 1ª | `TROCA ARMADA`; troca sozinha no instante do verde |
| `COMBAR` (combo ainda não feito) | 1ª | armada; só sai depois do combo desta dupla e do verde da troca |
| qualquer fase | 2ª dentro de `Hoenn222_EmergencyWindowMs` | emergência: troca na hora e consome o pedido |
| `Aguardando sincronização` | 1ª | troca na hora |

O pedido de troca é independente do pedido de combo (os dois podem estar
armados), fica preso ao time em que foi feito e é cancelado por F8, troca de modo
e mudança de time. Diagnóstico: `SWITCH_REQUEST`, `SWITCH_ARMED`, `SWITCH_FIRED`,
`SWITCH_DISARMED`, `SWITCH_RESULT`.

O cálculo do verde nunca prende a troca: se ele lançar exceção, vale o
comportamento antigo (troca na hora) e o erro vai para `phase=switch_readiness`.

O alvo de `TROCAR TIME` é `janela − lure` do plano, medido a partir do cast. A
janela do plano começa na troca de time e o lure acontece antes do cast; usar a
janela inteira contava o lure duas vezes.
### Primeira volta: o ritmo do plano vale desde o primeiro ciclo

Ao ligar o macro ou depois do F8, os seis Pokémon estão com o CD pronto. Só pelo
cooldown nada obrigaria a esperar: a troca para o time 2 liberava o combo na hora
(CD zero) e a espera inteira caía de uma vez na volta do time 1. Por isso, enquanto
um time ainda não fez o primeiro cast do tank depois do F8
(`Hoenn222_TeamCasted`), o verde do `COMBAR` só acende depois do `lure` planejado,
contado da troca de time. Depois do primeiro cast quem manda é só o cooldown real.

Simulação com as funções de produção (SR/Lendário, SR/UR, SR/UR): combos em
0,0 s, 21,2 s e 48,3 s; trocas em 8,3 s, 35,4 s e 62,6 s; o time 1 volta a
combar em 75,5 s, que é o `L` do plano, e todas as voltas seguintes duram o mesmo.
### Margem do secundário e latência da chamada

O jogo só conta o CD `LatencyMs` depois de o Pokémon sair da Ball, e o acumulador
aplica esse congelamento na chamada do p2. A tolerância do secundário e o plano
não o contavam, então num ciclo perfeito o secundário era usado ~10 ms depois do
CD zerar, não 250 ms. Agora a tolerância é
`0,5 × SleepAfterTankCombo + (SleepAfterSwitch − Latency) − Margin` e o secundário
entra no plano com `2·Latency + Margin` (o tank continua com `Latency + Margin`).
Teste Z: num ciclo perfeito, todo cast de tank e de secundário ocorre depois de
CD zerado + margem. Custo: a volta do plano sobe cerca de 0,2 s.
### Tempo fora mínimo (conforto): `Hoenn222_MinLureMs` e `Hoenn222_MinSecondaryOutMs`

A volta mínima usa só o cooldown, sem folga para o jogador. Dois pisos por dupla no
`config.ahk` dão esse tempo: o tank fica fora ao menos `MinLureMs` antes do combo
(da troca ao cast) e o secundário ao menos `MinSecondaryOutMs` (da chamada à troca).
O macro nunca libera o combo antes do piso e o planejador acha a menor volta que
cabe, já tirando do secundário o que o cooldown dele permite. Regra de bolso:
cada +1 s de volta libera ~7 s de tempo fora para dividir entre os seis Pokémon.

Com SR/Lendário, SR/UR, SR/UR e margem 400 ms (simulação de jogador perfeito):

| Pisos | Volta | Lure tank | Secundário fora |
| --- | --- | --- | --- |
| nenhum | 75,9 s | 12,7 s | 5,9 / 11,9 / 11,9 s |
| lure 15 s | 77,6 s | 15,0 s | 4,2 / 10,2 / 10,2 s |
| lure 15 s + Hyperior 8 s (padrão) | 78,9 s | 15,0 s | 8,0 / 8,9 / 8,9 s |
| lure 15 s + Hyperior 8 s + sec 2/3 em 12 s | 85,1 s | 15,0 s | 8,0 / 12,0 / 12,0 s |
### Congelamento do movimento durante a ação armada (corrigido)

O laço de 30 ms (`GameLoop`) também envia o movimento. Quando a ação armada
disparava a partir dele, o combo (~6,5 s) ou a troca (~1 s) subia **por cima** da
thread do laço; o AutoHotkey não reinicia um timer enquanto a instância antiga
existe, então movimento, botões e quadrado paravam até a ação terminar.
Agendar com `SetTimer(..., -1)` não bastava: com chamadas lentas no laço
(`ControlSend`, `WinExist`, `ToolTip`) o timer ainda interrompia o laço.

Correção: `Thread("NoTimers")` no início do `GameLoop` (nenhum timer sobe por
cima dele; as ações começam quando a volta termina), disparo automático em thread
descartável (`DispararComboArmadoHoenn222`, `DispararTrocaArmadaHoenn222`) e
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
casts (saída da Ball e início do CD novo): `Hoenn222CdTrocaTime` congela o tank novo
por `LatencyMs`, o planejador usa `2·Latency + Margin` para todos e
`Hoenn222CdReadyInMs` soma o congelamento ainda por vir. Num ciclo perfeito todo cast
cai a `Margin` + 0–5 ms depois do CD zerado. Custo: a volta do plano sobe 0,2 s.
## 3. Garantias

- **Um pedido por vez.** `ComboComplexoHoenn222()` consome o pedido armado
  junto com a trava `isRodizioAtivo`, dentro de `Critical`. Botão e varredura
  nunca passam juntos pelo bloqueio, e a trava só é armada com time válido
  (1–3) — antes, um time inválido deixava `isRodizioAtivo` travado para sempre.
- **Nunca no time errado.** O pedido guarda o time em que foi feito
  (`Hoenn222_ComboArmedTeam`). A varredura descarta o pedido se o modo ou o
  time mudarem, e a troca de time, o F8 e a troca de modo cancelam o pedido
  explicitamente (`reason=team_switch`, `resync`, `mode_change`).
- **Sem execução concorrente.** O disparo automático agenda o mesmo
  `SetTimer(..., -1)` do combo manual; a validação de time/modo
  `execIdOriginal` já existente continua valendo.
- **Sem atraso novo.** A varredura roda no laço de 30 ms que já existe e usa
  o mesmo cálculo do indicador, `GetHoenn222PendingMs()`. Não há sleep, nem
  timer novo, nem polling adicional.
- **Interface não participa da decisão.** O disparo fica antes do bloco de
  renderização e em `try/catch` próprio, então uma falha de tooltip não come
  o pedido, e uma falha do pedido não come o tooltip.
- **Falha de cálculo.** Na pressão, vale o comportamento antigo (executa). Na
  varredura, vale a espera (não dispara). Em ambos os casos a exceção vai para
  `phase=combo_readiness`.

### Estados alcançados pelo pedido

`GetHoenn222PendingMs()` devolve `0` em `WAITING_FIRST_COMBO`, então o
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

Indicador visual — o quadrado e o botão leem o mesmo pendente, então a cor diz\nexatamente o que o botão vai fazer:

| Cor | Significado |
| --- | --- |
| Verde | apertar executa na hora (inclui `Aguardando sincronização`) |
| Azul | `COMBAR` com até 10 s para o verde |
| Violeta | há pedido armado; executa sozinho ao ficar verde |
| Amarelo | demais casos de espera |

O alvo de `COMBAR` do otimizador é *quanto falta a partir de agora*; ele chega ao
contador somado ao decorrido, de modo que o pendente é exatamente o que falta
(antes o decorrido era descontado duas vezes e o verde acendia na metade do tempo).
A margem de segurança conta a partir do instante em que o CD zerou. O tooltip deixou de mostrar `Ref: <tier>` fixo e
passa a mostrar `Tank:` e `Sec:` lidos do `config.ahk`.

## 5. O que não mudou

Rotação 2+2+2, teclas `{1}/{3}/{5}` e `{2}/{4}/{6}`, `SleepAfterTankCombo`,
`SleepAfterCombo`, `SleepAfterSwitch`, sequência de habilidades, dívida
`Max(0, alvo + dívida - decorrido)` calculada com o time **anterior**,
debounce de 1000 ms da troca, modo 3-3, `Normal`, logger, tooltips (IDs,
posições, quadrado central) e F8/F12/XButton1/XButton2.

`Sleep`, `SetTimer` e o agendamento do combo são idênticos: a única diferença
em `ComboComplexoHoenn222()` é a trava ser decidida sob `Critical` e haver
validação de time.

## 6. Testes

```powershell
.\tests\run-hoenn-switch-tests.ps1
.\tests\run-hoenn-switch-tests.ps1 -LoggerInitFailure
```

**24 grupos PASS, exit code 0**; **25 grupos PASS** com `DirCreate` falhando,
exit code 0. Os 17 grupos anteriores continuam sem alteração.

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

Boot real: cópia temporária de `main.ahk` com `ExitApp` agendado para 2 s,
sem janela de jogo — exit code 0, sem saída de erro. Nenhum comando foi
enviado ao jogo.

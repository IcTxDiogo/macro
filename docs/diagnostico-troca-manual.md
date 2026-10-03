# Troca manual de Pokémon — diagnóstico e correção

Análise das versões em disco de `main.ahk`, `src/hoenn_engine.ahk`,
`src/mapeamento-controle.ahk`, `src/logger.ahk` e `config.ahk`, em 2026-10-03.
As alterações anteriores já presentes no workspace foram preservadas.
O patch `troca-manual.patch` compara o resultado com esses arquivos em disco
antes desta intervenção, não com o HEAD antigo do Git.

## Evidência e limite da conclusão

Na versão anterior, as funções de produção executadas no AutoHotkey v2 instalado
reproduziram estes defeitos, com o envio ao jogo substituído por um mock:

| Falha introduzida no teste | Resultado anterior comprovado |
| --- | --- |
| `LogTeamSwitch()` lança exceção | `TimeAtual=2`, zero chamadas a `ControlSend` |
| `FileAppend` real recebe um caminho sem diretório | Exceção do logger propaga até `Acao_Gatilhos()`, `TimeAtual=2`, zero envios |
| `GetHoenn222BaseTargetMs()` lança exceção | `TimeAtual=2`, zero envios, debounce já armado |
| Cálculo do tooltip lança exceção em `GameLoop()` | Zero callbacks de gatilho agendados |

O ponto exato do primeiro defeito é a ordem em `TrocarTimeHoenn()`:
`TimeAtual += 1` → `LogTeamSwitch()` → estatísticas/dívida → `ControlSend()`.
O segundo ponto está em `GameLoop()`: `GetHoenn222Tooltip()` e
`GetHoenn222CentralTooltip()` eram chamados antes do bloco dos gatilhos.
Não são hipóteses sobre a execução do código: os resultados acima foram
reproduzidos e estão em `testes-troca-anterior.txt`.

Isso comprova os defeitos arquiteturais, mas não identifica qual exceção ou filtro
ocorreu na tentativa específica dentro do jogo. O log existente
`logs/farm_log_2026-10-03_01-01-59.txt` registra um `TEAM SWITCH` para Time 2 às
01:04:07 e combos do Time 2 às 01:04:14 e 01:04:23. Ele não registrava o envio,
rejeições, origem dos gatilhos ou exceções. A mensagem antiga “Entrando Time”
era escrita antes de `ControlSend`, portanto não comprovava nem o envio nem a
entrada visual. Nenhuma reprodução visual no jogo foi executada nesta intervenção.

## Fluxo e escopo

- Mouse: `XButton2`, condicionado a `WinActive(GameWindow)`, chama
  `Acao_Gatilhos("mouse")` diretamente.
- Controle: `GameLoop()` consulta XInput a cada 30 ms; gatilho maior que 200,
  janela existente e transição de solto para pressionado agendam
  `Acao_Gatilhos("controller")` por timer de uma execução. Segurar o botão não
  agenda trocas repetidas.
- `Acao_Gatilhos()` chama `TrocarTimeHoenn(3)` em Hoenn 2-2-2.
  A rotina aceita ambos `WAITING_TEAM_SWITCH` e `WAITING_COMBO`; os estados
  participam apenas do cálculo da dívida. `isRodizioAtivo` limita combos, não
  a troca manual.
- Debounce: menos de 1000 ms desde o último envio aceito, somente no modo
  2-2-2. Exatamente 1000 ms permite a troca. Um tick inicial igual a zero não
  representa envio anterior. Falha de envio não arma debounce.
- Teclas solicitadas em 2-2-2: Time 1 → `{1}`, Time 2 → `{3}`, Time 3 → `{5}`.
  O 3-3 conserva `{1}` e o tank alternado `{4}`/`{5}`, sem novo debounce.
- As configurações declaradas `global` no nível superior continuam globais.
  `TimeAtual`, estado, ticks, mapas e dívida que recebem escrita nas funções
  estão declarados explicitamente. A versão analisada já possuía
  `global Hoenn222_DebtMs` em `TrocarTimeHoenn()`: não faltava essa declaração,
  e ela não elimina as exceções anteriores ao envio.
- F8 reseta cronômetro/dívida e invalida callbacks da interface, conserva o
  time solicitado e conserva o debounce. F8 não detecta o Pokémon na tela.

## Alteração implementada

1. Validar time, debounce e existência da janela, sem avançar `TimeAtual`.
2. Determinar próximo time e tecla.
3. Enviar a tecla principal dentro de `try/catch`.
4. Após retorno sem exceção, atualizar o time solicitado e os ticks/estado
   essenciais. Essa sequência curta é protegida por `Critical`, restaurado
   em `finally` inclusive nas rejeições; cálculos e logger ficam fora dela.
5. Enviar `KeyPokestop` e `KeyFullDef` na ordem anterior.
6. Calcular dívida e estatísticas em blocos independentes de `try/catch`.
   Se o cálculo da dívida falhar, conservar seu valor anterior e registrar
   a exceção. O novo estado `WAITING_COMBO` e seu tick já estão consistentes.
7. Atualizar texto e logger com tratamento de exceção. Retornar `true`
   para o envio principal aceito, inclusive se as operações auxiliares falharem.
8. `Acao_Gatilhos()` conserva `Sleep(800)` → `KeyPokestop` → `Potion()` nas
   trocas aceitas. A sequência testada no Time 1 → Time 2 é
   `{3}` → `{c}` → `{t}` → espera → `{c}` → `{e}`.

A dívida conserva a fórmula `Max(0, alvoDoEstadoAnterior + dívidaAnterior -
tempoDecorrido)`, com o alvo do time anterior, e não o alvo do time novo.
O logger de sessão também trata falhas reais de criação da pasta e escrita.
A mensagem de troca agora diz “Solicitado Time” e “Entrada visual: nao confirmada”.

Os botões são agendados antes da renderização. Posição da janela, formatação
e exibição dos tooltips ficam numa função protegida. Uma falha persistente de
interface gera somente um diagnóstico por mensagem/função/linha até a recuperação.
Nenhum evento é registrado nas atualizações normais de tela.

`config.ahk` e `src/core_actions.ahk` não foram alterados nesta intervenção.
Foram conservados `SleepAfterTankCombo=2700`, `SleepAfterCombo=3000`,
`SleepAfterSwitch=800`, as habilidades, o 3-3, os controles e os dois tooltips,
incluindo IDs, posições e três casas decimais. Não foram adicionadas trocas automáticas.

## Diagnóstico na próxima tentativa

Após recarregar a macro, o arquivo é **`A_Temp\macro_switch_debug.log`**,
normalmente **`%TEMP%\macro_switch_debug.log`**. Cada linha contém data/hora,
tick e PID; o arquivo acumula tentativas. Os testes usam outros arquivos dentro
de diretórios temporários isolados, sem misturar o diagnóstico da sessão real.
Para desligar a instrumentação depois do diagnóstico, definir
`SwitchDebugEnabled := false` em `src/logger.ahk`.

Sequência esperada:

```text
TRIGGER_RECEIVED | source=mouse ou controller
SWITCH_REQUESTED | from=1 total=3 state=...
SWITCH_COMMAND_BEGIN | from=1 to=2 key=3 window=...
SWITCH_COMMAND_END | result=requested_only to=2 key=3
SWITCH_STATE_UPDATED | requested_team=2 visual_confirmation=unknown
```

| Eventos observados | O que permitem concluir |
| --- | --- |
| Nenhum `TRIGGER_RECEIVED` | `Acao_Gatilhos()` não foi chamada; verificar filtro do mouse/janela, XInput, gatilho e agendamento |
| `SWITCH_REJECTED reason=debounce` | Bloqueio deliberado inferior a 1000 ms, com o tempo registrado |
| `SWITCH_REJECTED reason=invalid_team` | Time ou quantidade de times inválidos, registrados no evento |
| `SWITCH_REJECTED reason=no_window` | Janela ausente na validação, nenhum envio solicitado |
| `BEGIN` → `END result=failed` → `ERROR phase=primary_command` | `ControlSend` lançou exceção; mensagem/função/linha/arquivo identificam o ponto; time/debounce conservados |
| `END result=requested_only` → `STATE_UPDATED` | A chamada retornou sem exceção e o estado solicitado foi atualizado; entrada visual continua desconhecida |
| `ERROR phase=debt`, `timer_statistics` ou `team_logger` após `STATE_UPDATED` | Falha auxiliar posterior ao envio, sem cancelar os comandos posteriores |
| `ERROR phase=session_logger` ou `logger_init` | Falha real de I/O do logger de sessão, isolada do fluxo de troca |
| `ERROR phase=tooltip` | Falha de renderização isolada; os botões continuam sendo processados |
| `ERROR phase=post_command` ou `trigger_action` | Falha em comando posterior à tecla principal; não implica que o envio principal falhou |
| `BEGIN` sem `END`, mantendo o mesmo processo | Interrupção/ausência de retorno durante a chamada principal; não há evidência de conclusão |

Uma falha no próprio diagnóstico é absorvida sem diálogo e sem cancelar a troca.
Se o arquivo de diagnóstico também estiver indisponível, não será possível obter
evidência por esse arquivo; esse caso foi testado com falhas simultâneas na dívida
e no logger e a sequência de troca permaneceu completa.

## Testes executados

AutoHotkey v2 nativo: `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`.
O runner concatena funções atuais e substitui envio, relógio, janela, XInput,
timers e tooltips por mocks; não executa `main.ahk`, hotkeys ou polling real.
O teste J chama o `ControlSend` real somente para um executável sintético
inexistente, produzindo `TargetError` antes de qualquer envio. Nenhum comando foi
enviado ao jogo. Os erros de `FileAppend` e `DirCreate` também são reais.

| Cenário obrigatório | Resultado |
| --- | --- |
| A — 1 → 2 → 3 → 1 | PASS: teclas `{3}`, `{5}`, `{1}` e estado coerente |
| B — dívida acumulada | PASS: `9500 + 2000 - 3000 = 8500 ms`; duração e intervalo preservados |
| C — dívida zero | PASS: dívida permanece zero após tempo suficiente |
| D — `WAITING_TEAM_SWITCH` | PASS: aceita e conserva a antecipação |
| E — `WAITING_COMBO` | PASS: aceita aos 1000 ms, usando alvo do time anterior |
| F — duplo acionamento | PASS: rejeita aos 999 ms, sem novos comandos/avanço |
| G — erro no alvo da dívida | PASS: todos os comandos de troca/continuação; dívida anterior conservada; exceção registrada |
| H — erro no logger | PASS: exceção injetada e erro real de escrita, sem cancelar comandos |
| I — F8 e troca | PASS: reseta dívida, invalida interface, permite troca e conserva debounce |
| J — janela ausente / desaparecida | PASS: validação rejeita; `ControlSend` real falha no alvo sintético; nenhum falso sucesso |

Além de A–J, foram verificados: debug indisponível, tooltip com cálculo e I/O
falhando, pressionar/segurar/soltar/repressionar gatilho, ausência de logs por frame,
IDs/posições/precisão dos tooltips, ciclo/tank do 3-3, sequência de habilidades e
esperas do 2-2-2, independência do bloqueio de combo e ordem dos eventos de debug.

- `testes-troca-anterior.txt`: **4 reproduções do defeito anterior**, exit code 0.
- `testes-troca-atual.txt`: **17 grupos PASS**, exit code 0.
- `testes-troca-logger-init.txt`: **18 grupos PASS** com `DirCreate` falhando,
  exit code 0; inclui todos os 17 grupos normais.
- `git diff --check`: passou.

Reexecutar:

```powershell
.\tests\run-hoenn-switch-tests.ps1
.\tests\run-hoenn-switch-tests.ps1 -LoggerInitFailure
```

O runner também aceita uma cópia dos arquivos anteriores:

```powershell
.\tests\run-hoenn-switch-tests.ps1 -Baseline -SourceRoot '<cópia anterior>'
```

A cópia usada nesta sessão foi preservada temporariamente em
`C:\Users\santos\AppData\Local\Temp\macro-switch-baseline-2e6af4b92d644768b69f21639b2161b8`.
Os caminhos dos scripts gerados e saídas completas de cada execução aparecem
nos respectivos arquivos de resultados.

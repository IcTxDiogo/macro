# Estrutura do macro

Ponto de entrada: `main.ahk` (modo, atalhos e ações). Tudo é configurado em `config.ahk`.

## Módulos (`src/`)

`hoenn_engine.ahk` e `mapeamento-controle.ahk` são só índices de `#Include`. A ordem
importa: `estado.ahk` e `cooldown.ahk` leem o `config.ahk` ao carregar.

| Módulo | Responsabilidade |
| --- | --- |
| `core_actions.ahk` | teclas básicas (`ComboSimples`, poção, bola, alvo) |
| `logger.ahk` | log de sessão (`logs/`) e diagnóstico (`SwitchDebug`, `%TEMP%\macro_switch_debug.log`) |
| `estado.ahk` | variáveis globais de estado: time atual, fase, travas, pedidos armados |
| `cooldown.ahk` | CD individual dos 6 Pokémon (acumulador preguiçoso, taxas, latência, margem) |
| `planejador.ahk` | menor volta sustentável e janelas por dupla (`PlanHoenn222`) |
| `cronometro.ahk` | alvo de cada fase, pendente até o verde, quem segura o verde |
| `troca_time.ahk` | `TrocarTimeHoenn`: validação, envio, estado |
| `combos.ahk` | rodízio dos modos 3-3 e 2-2-2 |
| `antecipacao.ahk` | cancelamento comum dos pedidos armados |
| `antecipacao_combo.ahk` | botão de combo: normal, armado, emergência |
| `antecipacao_troca.ahk` | gatilho de troca: normal, armado, emergência |
| `indicador.ahk` | tooltip e quadrado central colorido |
| `controle.ahk` | laço de 30 ms: XInput, movimento, botões |

## Regras que não se quebram

- O laço de `controle.ahk` nunca usa `Critical`, `Sleep` nem executa ação longa:
  agenda com `SetTimer(fn, -1)`. Ver `docs/tiers-e-combo-hoenn222.md`.
- A troca de time nunca fica presa por falha de cálculo: na dúvida, troca.
- Os intervalos internos do combo (2700 / 800 / 3000 ms) não são alterados pelo otimizador.

## Testes

```powershell
powershell -File tests\run-hoenn-switch-tests.ps1                 # lógica isolada, relógio e timers simulados
powershell -File tests\run-hoenn-switch-tests.ps1 -LoggerInitFailure
powershell -File tests\run-live-stall-test.ps1                    # timers reais: laço não congela
```

`tests/fontes.ps1` lista os módulos usados pelos runners e falha se os índices de
include saírem de sincronia.

## Diagnóstico do cooldown (comparar com a barra de golpes do jogo)

| Evento | Quando | Campos |
| --- | --- | --- |
| `CD_CAST` | cada cast | `slot`, `cd_main`, `cd_comeca`, `pronto`, `seguro` |
| `CD_ENTRADA` | Pokémon entra em campo (troca ou chamada) | `cd_modelo_ms`, `taxa`, `pronto_em_ms` |
| `LOOP_STALL` | laço de 30 ms parado > 400 ms | `gap_ms`, `state` |

`CD_ENTRADA` é o CD que o modelo espera; a barra F1–F8 do jogo mostra o real dos golpes
do Pokémon que está fora. A diferença é o erro do modelo para aquele Pokémon.
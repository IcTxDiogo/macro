# Estrutura do macro

```
main.ahk          entrada: includes, XInput, atalhos de teclado e mouse
config.ahk        tudo que se ajusta (teclas, tiers, tempos, margem)
lib/XInput.ahk    leitura do controle
src/
  indice.ahk      lista (e ordem) dos modulos
  nucleo/         estado global e log; sem regra de jogo
  tempo/          CONTROLE DE TEMPO: quando cada coisa pode acontecer
  macro/          o que o macro FAZ no jogo
  interface/      gamepad e indicador visual
tests/            runners e testes (ver abaixo)
docs/             documentacao atual; docs/historico guarda analises antigas
```

## Camadas

Cada camada so conhece as de baixo: `interface` -> `macro` -> `tempo` -> `nucleo`.

| Camada | Pergunta que responde | Pode enviar tecla? |
| --- | --- | --- |
| `nucleo` | em que estado estamos? | nao |
| `tempo` | quando posso agir sem a skill ser comida? | **nunca** (o teste falha) |
| `macro` | o que enviar ao jogo, e quando o pedido do jogador vira acao | sim |
| `interface` | o que o jogador esta apertando e o que mostrar | so movimento (WASD) |

## Modulos

| Modulo | Responsabilidade |
| --- | --- |
| `nucleo/estado.ahk` | variaveis globais: modo, time atual, fase, travas, pedidos armados |
| `nucleo/validacao_config.ahk` | confere o `config.ahk` ao carregar; problemas aparecem no painel (`!! CONFIG !!`) e no log |
| `nucleo/logger.ahk` | log de sessao (`logs/`) e diagnostico (`LogDiagnostico`, `%TEMP%\macro_switch_debug.log`) |
| `tempo/cooldown.ahk` | CD individual dos 6 Pokemon (acumulador, taxa fora/dentro da Ball, atrasos, margem) |
| `tempo/planejador.ahk` | menor volta sustentavel e janelas por dupla (`PlanejarVolta`) |
| `tempo/cronometro.ahk` | alvo de cada fase, pendente ate o verde, quem segura o verde |
| `macro/teclas.ahk` | teclas basicas (`ComboSimples`, pocao, alvo, reiniciar) |
| `macro/troca_time.ahk` | `TrocarDeTime`: validacao, envio, estado |
| `macro/rodizio_222.ahk` | rodizio do modo 2-2-2 (registra cast e chamada no `tempo`) |
| `macro/antecipacao*.ahk` | combo e troca armados (verde automatico) e emergencia (duplo clique) |
| `macro/persistencia.ahk` | salva o modelo a cada evento e o restaura no reload (menos de 3 min) |
| `macro/modos.ahk` | `TrocarModo` e `Resincronizar` (F8) |
| `macro/acoes.ahk` | acao de cada botao conforme o modo; `PedirProximaAcao` e o botao unico do 2-2-2 |
| `interface/controle.ahk` | laco de 30 ms: XInput, movimento, botoes -> acoes |
| `interface/painel.ahk` | tooltip de texto e orquestracao da interface |
| `interface/quadrado_central.ahk` | quadrado colorido (verde / azul / amarelo / violeta) |

A ordem de `indice.ahk` importa: `estado` e `cooldown` leem o `config.ahk` ao carregar.

## Documentação

| Documento | Para quê |
| --- | --- |
| `CLAUDE.md` (raiz) | guia rápido: onde ajustar, regras, como diagnosticar |
| `docs/estrutura.md` | este arquivo: camadas, módulos, testes, diagnóstico |
| `docs/tiers-e-combo-hoenn222.md` | comportamento do 2-2-2: tiers, combo/troca armados, 1ª volta, correções datadas |
| `docs/arquitetura-otimizador-cooldown.md` | o modelo de cooldown e o planejador (fórmulas) |
| `docs/historico/` | registros de fases anteriores; não refletem o estado atual |
## Regras que nao se quebram

- O laco de `interface/controle.ahk` nunca usa `Critical`, `Sleep` nem executa acao longa:
  agenda com `SetTimer(fn, -1)`. Ver `docs/tiers-e-combo-hoenn222.md`.
- A troca de time nunca fica presa por falha de calculo: na duvida, troca.
- Os intervalos internos do combo (2700 / 800 / 3000 ms) nao sao alterados pelo otimizador.
- `tempo/` so calcula: nao envia tecla, nao toca em janela, tooltip nem timer.

## Testes

```powershell
powershell -File tests\run-hoenn-switch-tests.ps1                 # logica isolada, relogio e timers simulados
powershell -File tests\run-hoenn-switch-tests.ps1 -LoggerInitFailure
powershell -File tests\run-live-stall-test.ps1                    # timers reais: laco nao congela
```

Antes de rodar os testes, os runners conferem: (1) `src/indice.ahk` e `tests/fontes.ps1`
listam os mesmos modulos, na mesma ordem, e nenhum `.ahk` de `src/` ficou fora; (2) `src/tempo`
nao usa funcoes de macro/interface; (3) o `main.ahk` carrega de verdade (`/validate`, sem
executar nem ler o gamepad). `tests/simulacoes/` guarda os simuladores antigos do modelo.

Os testes estao divididos por tema: `tests/base.ahk` (mocks, `ResetCase`, auxiliares e o
`RunTests` que chama cada tema) e `tests/grupos/NN-tema.ahk` (uma funcao `Testes*` por arquivo,
em ordem; todas usam `global`, entao um grupo le o que o anterior criou).

## Reiniciar e instancia unica

- **Reload (Ctrl+Esc / Start):** funciona com o jogo fechado. O estado do modelo e salvo a
  cada evento em `logs\estado_do_macro.txt` e restaurado no boot se tiver menos de 3 min e for
  da mesma sessao do Windows (`Hoenn222_RestoreStateOnReload`). F8 continua zerando de proposito.
- **Instancia unica:** um mutex da maquina impede duas copias do macro (que leriam o mesmo
  controle e mandariam teclas em dobro). No reload a nova espera ate 3 s pela antiga sair.
- **Log de diagnostico:** acima de 5 MB vira `.old` no boot.

## Diagnostico do cooldown (comparar com a barra de golpes do jogo)

| Evento | Quando | Campos |
| --- | --- | --- |
| `CD_PLAN` | plano calculado | `L`, `janelas`, `lure`, `tank_fora`, `sec_fora`, `latencia`, `saida_sec`, `margem` |
| `CD_CAST` | cada cast | `slot`, `cd_main`, `cd_comeca`, `pronto`, `seguro` |
| `CD_ENTRADA` | Pokemon entra em campo (troca ou chamada) | `cd_modelo_ms`, `taxa`, `pronto_em_ms` |
| `NEXT_ACTION` | botao apertado no 2-2-2 | `source`, `phase`, `action` (combo ou troca), `team` |
| `CONFIG_PROBLEMA` | config invalido ao carregar | `detalhe` |
| `STATE_RESTORED` / `STATE_RESTORE_SKIPPED` | boot depois de reload | `age_s`, `mode`, `team`, `state` / `reason` |
| `INSTANCIA_DUPLICADA` | outra copia ja roda | `path` |
| `LOOP_STALL` | laco de 30 ms parado > 400 ms | `gap_ms`, `state` |

`CD_ENTRADA` e o CD que o modelo espera; a barra F1-F8 do jogo mostra o real dos golpes
do Pokemon que esta fora. A diferenca e o erro do modelo para aquele Pokemon.

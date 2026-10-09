# Arquitetura consolidada — Otimizador dinâmico Hoenn 2+2+2

Validação executada em `tests/validar-otimizador.ps1`; saída completa em
`docs/validacao-otimizador.txt`. **Nenhuma implementação nova foi feita nesta
rodada** — o estado da árvore está descrito na seção 8.

---

## 1. O que é fixo e o que é variável

### Fixo (vem do código, nunca alterado pelo otimizador)

`ExecutarRodizio222()` em `src/hoenn_engine.ahk`:

```
AutoCombo tank      -> Sleep(SleepAfterTankCombo = 2700)
                    -> ControlSend("{p2}")        chamada: secundario sai da Ball
                    -> Sleep(SleepAfterSwitch  = 800)
AutoCombo secundario                             cast: T2 = T0 + 2700 + 800
                    -> Sleep(SleepAfterCombo  = 3000)
```

O otimizador **nunca** altera 2700 nem 800. Não há espera estendida "porque o
secundário ainda não está pronto". Se o secundário não estiver pronto no
instante fixo do seu cast, o macro **avisa** — não espera.

### Variável (as duas únicas decisões do otimizador)

1. `T0` — instante de início do próximo combo.
2. `s` — instante da troca para o próximo time.

Tudo o mais é consequência. É por isso que a rotação converge sem deriva: só
duas grandezas são escolhidas por volta, e a terceira dupla fecha o ciclo.

---

## 2. Instantes de entrada e saída da Ball (lidos do código)

| Evento | Instante | Taxa a partir daí |
| --- | --- | --- |
| Troca de time para a dupla `k` | `s_k` | Tank sai da Ball → **1,0** |
| Cast do tank | `T0_k` | CD passa a contar em `T0_k + 250` |
| Chamada do secundário | `T1_k = T0_k + 2700` | Secundário sai da Ball → **1,0** |
| Cast do secundário | `T2_k = T0_k + 3500` | CD passa a contar em `T2_k + 250` |
| Troca para a dupla seguinte | `s_{k+1}` | Ambos voltam para dentro → **0,5** |

O Tank recupera durante **todo** o tempo em que o time está em campo: a
espera até o combo, os 2700 ms, os 800 ms e a espera pós-combo. O secundário
recupera a 0,5 desde a troca anterior até a chamada, e a 1,0 entre `T1` e `T2`.

Não existe `PrepareMs`. A única restrição física implícita é que o combo não
pode começar antes de `s_k` — o macro não impõe nada além disso.

---

## 3. Verde = viabilidade do combo inteiro

Verde **não** significa "o tank está pronto". Significa que o combo inteiro é
viável com os tempos internos preservados:

```
Tank       : CD zerado + Margem  <=  T0
Secundário : CD que ele terá em T1 + Margem  <=  Gap
```

O secundário ainda está na Ball entre `T0` e `T1`, recuperando a 0,5. Então o
teto de CD admissível **no instante T0** é:

```
SEC_TOL = 0,5 × Summon + Gap − Margin = 1350 + 800 − 250 = 1900 ms
```

Se `CD_sec(T0) > 1900`, o verde não acende: o macro sabe que o secundário
estaria em cooldown no seu próprio cast, mesmo que o jogador aguardasse.

Consequência validada (seção 6 da saída): com o Tank pronto e o secundário com
3000 ms, o verde só acende 2200 ms depois; se o jogador forçar o combo nesse
instante, o secundário chega ao cast com 1650 ms de CD. **O macro tem de
sinalizar, não inventar.**

---

## 4. Planejamento global das três duplas

Com `X = (L + w)/2`, `L` = volta, `w` = janela da dupla:

```
Tank       : X ≥ cdTank + Λ + Δ                    (independe de p)
Secundário : X ≥ cdSec  + 0,5·p + 0,5·Summon + Λ + Δ
p = offset de T0 dentro da janela

L = ΣX / 2        janela_k = 2·X_k − L
```

`Λ = Latency = 250`, `Δ = Margin = 250`.

O termo do Tank **não depende de `p`**: o tempo antes do cast recupera o timer
da volta anterior e é apagado pelo reset. Já o secundário paga `0,5·p` — quanto
mais o jogador espera dentro da janela, mais tempo o secundário passa na Ball.

Para as duplas do exemplo (Lendário/UR, UR/SR, SR/UR):

| Dupla | Tank exige | Secundário exige | Limita |
| --- | --- | --- | --- |
| Time 1 | 40,5 s | 45,0 s | secundário |
| Time 2 | 43,5 s | 47,0 s | secundário |
| Time 3 | 45,5 s | 45,0 s | **tank** |

`L = 68,725 s`, janelas `21,23 / 25,23 / 22,28 s`.

Isto responde ao ponto "um Pokémon ficar pronto antes do planejado é normal":
no Time 3 é o **Tank** que limita, e o secundário fica pronto antes — a janela
absorve essa folga em vez de desperdiçá-la.

---

## 5. Por que "executar o mais cedo possível" é pior

| Política | Volta | vs. macro atual (86,5 s) |
| --- | --- | --- |
| **plan** (janelas do planejador) | **68,725 s** | **−20,5 %** |
| greedy (troca assim que o próximo tank fica pronto) | 89,950 s | **+4,0 % — pior que hoje** |

A política gulosa troca cedo demais, os Pokémon da dupla que sai perdem
recuperação a 1,0 e a volta só fecha muito depois. Confirmado numericamente em
20 voltas.

---

## 6. Validações executadas

| Verificação | Resultado |
| --- | --- |
| Fórmula analítica × simulação | previsto 68,725 s, medido 68,725 s |
| Convergência (20 voltas) | desvio **0,0000 s**, sem deriva |
| Casts com CD pendente | **0 de 120** |
| Intervalos internos | `Summon=2700` e `Gap=800` idênticos em todos os cenários |
| Latência de saída da Ball (0/250/500 ms) | 0 casts pendentes; a volta apenas alonga (68,7 → 69,9 s) |
| Antecipação forçada com secundário ≥ 3000 ms | inviável; macro deve sinalizar |
| Comparação com o macro atual | 68,725 s contra 86,500 s medidos no log |

---

## 7. Onde o estado é recalculado

O acumulador por Pokémon é preguiçoso (atualiza na leitura), então recalcular é
barato. Recalcula-se em:

| Evento | Transição no acumulador |
| --- | --- |
| Troca de time aceita | tank novo → 1,0; tank e secundário antigos → 0,5 |
| `AutoCombo` do tank | `cd = cdTank`, contagem em `tick + Λ`, taxa 1,0 |
| `ControlSend("{p2}")` | secundário → 1,0 |
| `AutoCombo` do secundário | `cd = cdSec`, contagem em `tick + Λ` |
| Interrupção no meio do combo | o que já foi enviado fica registrado; o resto não |
| Antecipação manual | recalcula o verde com o instante forçado |
| F8 | seis cooldowns a zero, todos dentro da Ball |

O estado já decorrido nunca é reconstruído: é acumulado.

---

## 8. Estado da árvore de trabalho

Implementado e com a suíte de testes passando.

- **Git restaurado.** O repositório estava intacto — só o binário faltava após a
  formatação. Instalado o Git 2.55.0, identidade `santos <ictxdiogo@gmail.com>`,
  remote `https://github.com/IcTxDiogo/macro.git` intacto. `origin/main` é
  ancestral direto: **sem divergência de histórico**, 4 commits locais à frente.
- **Reaproveitado** da tentativa anterior: o acumulador preguiçoso por slot
  (`Hoenn222Cd*`), o mapeamento tier → CD, o `PlanHoenn222()` com cache, o
  cancelamento de pedido armado e o fallback para os alvos fixos.
- **Descartado:** `PrepareMs` artificial e a extensão dinâmica da espera interna
  do secundário. `GetHoenn222SecondaryWaitMs` não existe mais; os intervalos
  são `SleepAfterTankCombo` e `SleepAfterSwitch`, os valores originais.
- **Sem espera artificial:** com todos os CD zerados o alvo de COMBAR é só a
  margem (250 ms). Se o secundário não couber, o verde não acende — o macro
  avisa quem falta em vez de estender o intervalo.

Correções de runtime encontradas durante a implementação:

- Neste AutoHotkey um índice **Float** de array é tratado como nome de
  propriedade. `for x in 1..N` gera Float e quebra o acesso. Todo índice passa
  por `Integer()`.
- Os alvos de `Hoenn222_BaseTargetMs` são **durações** contadas do início do
  estado, nunca instantes absolutos — é assim que `Hoenn222_ComboTargetMs` e
  `Hoenn222_SwitchTargetMs` são definidos, e é assim que
  `GetHoenn222PendingMs()` desconta o decorrido.
- O runner dos testes lia as fontes na codificação ANSI do console (aqui
  ibm850), o que corrompia os acentos e produzia erro de sintaxe no script
  gerado; e montava o arquivo com LF sobre fontes CRLF. Ambos corrigidos.

---

## 9. O que ainda precisa de calibração no jogo

1. A tabela 40/43/45/50 s e as taxas 1,0 / 0,5 — a fórmula é exata, os
   parâmetros precisam ser medidos.
2. Se a saída da Ball tem latência observável (a simulação mostra que 500 ms
   não causam cast perdido, apenas alongam a volta).
3. Os logs `CD_CAST`, `CD_PLAN` e `CD_SEC_ESPERA` já previstos dão a medição
   direta: tempo entre o comando e a primeira skill, e quantas vezes a
   viabilidade do secundário quase estourou.

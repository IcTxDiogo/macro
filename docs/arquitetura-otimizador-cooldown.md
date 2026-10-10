# Arquitetura consolidada — Otimizador dinâmico Hoenn 2+2+2

Já implementado em `src/tempo`. Os simuladores que originaram a análise estão em
`tests/simulacoes/validar-otimizador.ps1` (saída em `docs/historico/validacao-otimizador.txt`).
Números desta página com margem 250 ms são da época da validação; o plano atual está em `CD_PLAN`.

---

## 1. O que é fixo e o que é variável

### Fixo (vem do código, nunca alterado pelo otimizador)

`ExecutarRodizio222()` em `src/macro/rodizio_222.ahk`:

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
| Chamada do secundário | `T1_k = T0_k + 2700` | **Tank volta para a Ball (0,5)**; secundário sai → **1,0** |
| Cast do secundário | `T2_k = T0_k + 3500` | CD passa a contar em `T2_k + 250` |
| Troca para a dupla seguinte | `s_{k+1}` | Ambos voltam para dentro → **0,5** |

**Só um Pokémon fica fora da Ball por vez.** Na chamada do p2 o tank sai de
campo. Sem isso os dois recuperariam a 1,0 ao mesmo tempo e a capacidade da
volta passaria de 3,5× para 4,0× — foi exatamente esse o erro que inflou o
planejador para 67 s.

O Tank recupera a 1,0 durante **todo** o tempo em que está em campo: a
espera de lure e os 2700 ms pós-cast. O lure **conta** para o CD dele — mas é
o CD que nasceu no cast da volta **anterior**, não o que vai começar no cast
que vem a seguir. Ver a seção 4.

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
SEC_TOL = 0,5 × Summon + max(0, Gap − Λ_saída_sec) − Margin
        = 1350 + max(0, 800 − 1100) − 450 = 900 ms      (valores atuais)
```

Se `CD_sec(T0) > SEC_TOL`, o verde não acende: o macro sabe que o secundário estaria em
cooldown no seu próprio cast, mesmo que o jogador aguardasse. Com o atraso de saída maior que
o `Gap`, o secundário precisa chegar à chamada com o CD já zerado (mais a margem).

Consequência validada (seção 6 da saída): com o Tank pronto e o secundário com
3000 ms, o verde só acende 2200 ms depois; se o jogador forçar o combo nesse
instante, o secundário chega ao cast com 1650 ms de CD. **O macro tem de
sinalizar, não inventar.**

---

## 4. Planejamento global das três duplas

A recuperação é contada **entre dois casts consecutivos** do mesmo Pokémon. Com
`F` = tempo total fora da Ball nesse intervalo:

```
(F − Λ_saída − Λ_cast)·1,0 + (L − F)·0,5   ≥   CD + Δ
F  ≥  2·(CD + Λ_cast + Λ_saída + Δ) − L
```

O congelamento de saída da Ball (Λ_saída) e o do início do CD depois do cast (Λ_cast)
ficam dentro do primeiro trecho fora da Ball. Λ_cast e Λ_saída do tank valem
`Hoenn222_LatencyMs` (250); Λ_saída do secundário é `Hoenn222_ExitLatencySecondaryMs`
(1100). Δ é `MarginMs`, a folga exigida no próximo cast.

Quem pode ficar fora, e quanto:

| | tempo fora disponível | mínimo técnico |
| --- | --- | --- |
| Tank `k` | `lure_k + P` (da troca até a chamada do p2) | `P` |
| Secundário `k` | `janela_k − lure_k − P` | `Gap + Post` |

E as janelas fecham: `L = janela₁ + janela₂ + janela₃`, com
`janela_k = lure_k + P + F_sec_k`.

**O lure conta.** Ele acontece no meio do intervalo entre dois casts e
recupera o cooldown que nasceu no cast anterior. Um erro anterior da auditoria
afirmava o contrário e inflava a volta em 13 s.

Não existe tempo fora "de graça": só um Pokémon está fora por vez, então dar
mais lure ao tank é tirar tempo do secundário. No mínimo, cada janela é
exatamente o que o par exige — e as três somam exatamente `L`.

Para a composição principal auditada (SR/Lendário, SR/UR, SR/UR):

| Dupla | Tank exige | Secundário exige | Janela | Lure |
| --- | --- | --- | --- | --- |
| Time 1 | 15,571 s | 5,571 s | 21,143 s | 12,871 s |
| Time 2 | 15,571 s | 11,571 s | 27,143 s | 12,871 s |
| Time 3 | 15,571 s | 11,571 s | 27,143 s | 12,871 s |

`L = 75,429 s` — exatamente o piso idealizado `(ΣCD + 6·0,5) / 3,5`.

Isto responde ao ponto "um Pokémon ficar pronto antes do planejado é normal": a
janela de cada dupla absorve essa folga em vez de desperdiçá-la.

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

## 8. O que foi implementado (e descartado)

Implementado em `src/tempo` e coberto pela suíte de testes (`tests/`).

- **Reaproveitado:** o acumulador preguiçoso por slot (`CooldownRestanteMs`, `AtualizarCooldown`), o mapeamento tier → CD,
  o `PlanejarVolta()` com cache, o cancelamento de pedido armado e o fallback para os alvos fixos.
- **Descartado:** `PrepareMs` artificial e a extensão dinâmica da espera interna do
  secundário. Os intervalos são `SleepAfterTankCombo` e `SleepAfterSwitch`, os valores originais.
- **Sem espera artificial:** com todos os CD zerados o alvo de COMBAR é só a margem
  (`MarginMs`, 450 ms hoje). Se o secundário não couber, o verde não acende: o macro avisa
  quem falta em vez de estender o intervalo.

Correções de runtime encontradas durante a implementação:

- Neste AutoHotkey um índice **Float** de array é tratado como nome de
  propriedade. `for x in 1..N` gera Float e quebra o acesso. Todo índice passa
  por `Integer()`.
- Os alvos de `Hoenn222_BaseTargetMs` são **durações** contadas do início do
  estado, nunca instantes absolutos — é assim que `Hoenn222_ComboTargetMs` e
  `Hoenn222_SwitchTargetMs` são definidos, e é assim que
  `FaltaParaVerdeMs()` desconta o decorrido.
- O runner dos testes lia as fontes na codificação ANSI do console (aqui
  ibm850), o que corrompia os acentos e produzia erro de sintaxe no script
  gerado; e montava o arquivo com LF sobre fontes CRLF. Ambos corrigidos.

---

## 9. O que foi calibrado em jogo e o que falta

1. A tabela 40/43/45/50 s e as taxas 1,0 / 0,5: a fórmula é exata, os parâmetros vêm de
   medição. Na gravação de 09/10 o CD fora da Ball bateu em 1,00/s; dentro da Ball ficou em
   0,487–0,495/s (consistente com 0,5 mais um atraso de saída).
2. Latência de saída da Ball: medida em 09/10. Tank ~250 ms (dentro do erro de medida);
   secundário ~1100 ms (`Hoenn222_ExitLatencySecondaryMs`). A amostra do secundário é pequena
   (2 falhas em ~14 casts): confirmar com 10+ voltas.
3. Diagnóstico: `CD_CAST`, `CD_PLAN` e `CD_ENTRADA` (CD que o modelo espera na entrada de
   cada Pokémon) permitem comparar com os contadores da barra F1–F8. Ver `docs/estrutura.md`.

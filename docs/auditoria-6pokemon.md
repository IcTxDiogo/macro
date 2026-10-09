# Auditoria matemática e de confiabilidade — Hoenn 2-2-2

Datas: 2026-10-09 (primeira auditoria e correção de dois erros graves) e
2026-10-09 (segunda rodada: correção da premissa de recuperação).

## A — Diagnóstico

### A.1 Erro 1 (primeira rodada, preservado): dois Pokémon fora da Ball

`Hoenn222CdRegistrarChamada()` colocava **só** o secundário a 1,0× na chamada
do p2. O tank permanecia a 1,0× até a próxima troca.

Isso viola "apenas um Pokémon fora da Ball por vez" e inflava a capacidade da
volta de 3,5× para 4,0×.

**Correção:** a chamada do p2 também leva o tank de volta para a Ball.

### A.2 Erro 2 (primeira rodada, preservado): dupla tratada como um Pokémon só

`L = ΣX/2` não tem base física, a janela inteira era dada ao tank e
`0,5·Summon` era somado como ganho quando o secundário está na Ball nesse
trecho (é perda). O plano de 67,462 s produzia casts com 8,2 s de CD pendente.

### A.3 Erro 3 (segunda rodada): o lure antes do cast não contava

A primeira auditoria afirmou:

> O tempo de lure antes do cast não recupera o cooldown do Tank, porque o
> cooldown só começa depois da skill.

**Isso está errado.** O cooldown nasce no cast da volta **anterior** e
precisa zerar antes do próximo. O lure acontece no meio desse intervalo e
recupera esse mesmo cooldown. Cada segundo conta onde acontecer.

O efeito era grande: o planejador da primeira rodada dava **88,8 s** para a
composição principal, quando o mínimo real é **75,4 s** — 13,4 s de volta
desperdiçada por conta de uma premissa errada.

### A.4 Por que o tempo de lure não é "de graça"

Não existe tempo fora "de graça": só um Pokémon está fora da Ball por vez. A
janela de uma dupla é

```
janela_k = lure_k + P + F_sec_k
```

O lure dá tempo fora ao **tank**; o trecho depois do p2 dá tempo fora ao
**secundário**. Dar mais lure ajuda o tank e *tira* tempo do secundário. É por
isso que a distribuição não é livre: no mínimo, cada janela é exatamente o
que o tank e o secundário daquele par exigem, e as três somam exatamente L.

---

## B — Fórmula final

Recuperação contada **entre dois casts consecutivos** do mesmo Pokémon. Com
F = tempo total fora da Ball nesse intervalo, Λ = latência, Δ = margem:

```
(F − Λ)·1,0 + (L − F)·0,5   >=   CD + Δ
F  >=  2·(CD + Λ + Δ) − L
```

O `(F − Λ)` existe porque o congelamento de latência fica **dentro** do
primeiro trecho fora da Ball. Λ e Δ entram uma vez cada.

Quem pode ficar fora, e quanto:

| | tempo fora disponível | mínimo técnico |
|---|---|---|
| Tank `k` | `lure_k + P` (da troca até a chamada do p2) | `P` |
| Secundário `k` | `janela_k − lure_k − P` | `Gap + Post` |

E as três janelas fecham em `L = janela₁ + janela₂ + janela₃`.

O menor `L` que fecha essa soma é a volta mínima sustentável. A soma das
janelas é decrescente em `L` (CD maior exige menos tempo fora), então a busca
é por bisseção na condição `soma(janelas) ≤ L`.

**Verificado:** `tests/simular-6pokemon.ps1` seção 7 cruza a fórmula fechada
com o simulador de eventos por busca binária. As duas concordam com diferença
0 ms nas seis composições.

---

## C — Comparação: composição principal (SR/Lendário, SR/UR, SR/UR)

| Métrica | Valor |
|---|---|
| Soma dos seis CDs | 261,0 s |
| Piso teórico 3,5× sem margem | 74,571 s |
| Piso teórico 3,5× + 500 ms por Pokémon | 75,429 s |
| Plano da 1ª auditoria (premissa errada) | 88,800 s |
| **Plano corrigido** | **75,429 s** |
| Mínimo absoluto do simulador | 75,428 s |

O plano corrigido **atinge** o limite idealizado. Ganho contra a primeira
auditoria: **−15,1 %**. Contra o macro anterior medido (86,500 s, composição
diferente): **−12,8 %**.

### Outras composições

| Composição | Soma CD | Piso 3,5× | Plano |
|---|---|---|---|
| Lendário/UR, UR/UR, UR/UR (anterior config) | 255,0 | 72,857 | 73,714 |
| Todos 45 s | 270,0 | 77,143 | 78,000 |
| Tanks 50 s / secs 40,43,43 | 276,0 | 78,857 | 80,133 |
| Lendários 40/40, 40/43, 40/45 | 248,0 | 70,857 | 71,714 |
| Misto 45/40, 43/45, 43/50 | 266,0 | 76,000 | 76,857 |

Em todas, o plano fica entre o piso sem margem e o piso com 500 ms de margem.

---

## D — Distribuição dos seis Pokémon

Composição principal, L = 75,429 s:

| Dupla | Tank | Secundário | Janela | Lure | Tank fora | Sec fora |
|---|---|---|---:|---:|---:|---:|
| 1 | SR 45 s | Lendário 40 s | 21,143 | 12,871 | 15,571 | 5,571 |
| 2 | SR 45 s | UR 43 s | 27,143 | 12,871 | 15,571 | 11,571 |
| 3 | SR 45 s | UR 43 s | 27,143 | 12,871 | 15,571 | 11,571 |

Soma das janelas = 75,429 ms = L. Soma dos seis tempos fora = 75,429 ms.
**Nenhum segundo é contado para dois Pokémon, e nenhum tempo fora ultrapassa a
volta.**

Linha do tempo de uma dupla `k` (instantes relativos):

```
s_k        tank k SAI da Ball, secundário continua dentro (0,5)
  ...      tank recupera a 1,0 — este é o CD que nasceu em T0 da volta anterior
T0_k       cast do tank; CD novo passa a contar em T0_k + Λ
T0_k+P     chamada do p2: tank VOLTA para a Ball, secundário SAI (1,0)
T0_k+P+G   cast do secundário; CD conta a partir de +Λ
  ...      secundário recupera a 1,0
s_(k+1)    troca: secundário volta para dentro
```

---

## E — Tempos obrigatórios e otimizáveis

| Sleep | Valor | Obrigatório | Efeito |
|---|---:|---|---|
| `SleepAfterTankCombo` | 2700 ms | Sim (animação) | Entra em `F_tank`. Cada +1 s encurta a volta em até 1 s |
| `SleepAfterSwitch` | 800 ms | Sim | Entra no mínimo do secundário |
| `SleepAfterCombo` | 3000 ms | Sim | Entra no mínimo do secundário |

Os três já estão dentro da linha do tempo: não são somados ao piso, ele é
calculado com eles. Não há espera artificial: o alvo de COMBAR sem CD é só a
margem.

---

## F — Compensação dinâmica

O acumulador é preguiçoso: cada leitura aplica a recuperação decorrida com a
taxa vigente do slot. O atraso do jogador **não é descontado** da próxima
espera; o alvo é recalculado dos seis CDs reais.

Verificado no simulador (composição CONFIG, L = 73,714 s):

| Atraso | Volta | Casts com CD pendente |
|---|---:|---:|
| nenhum | 73,715 s | 0 |
| combo +5 s | 88,715 s | 0 |
| combo +30 s | 163,715 s | 0 |
| troca +30 s | 163,715 s | 0 |
| ambos +30 s | 253,715 s | 0 |

Atraso alonga a volta; nunca força cast com CD pendente.

---

## G — Testes

| Verificação | Resultado |
|---|---|
| Suíte isolada | 28 grupos |
| Suíte com falha de logger | 29 grupos |
| Boot real do `main.ahk` | exit 0, stderr vazio |
| Simulador: 6 composições × 20 e 200 voltas | 0 violações |
| Propriedade: 40 composições aleatórias | 0 violações no L mínimo |
| Cruzamento fórmula × simulador | 6/6 com diferença 0 ms |
| Teste da premissa (grupo L) | passa; falha se o lure for ignorado |

Sensibilidade:

| Margem | L | Latência | L |
|---:|---:|---:|---:|
| 0 ms | 73,286 s | 0 ms | 73,286 s |
| 250 ms | 73,714 s | 250 ms | 73,714 s |
| 500 ms | 74,143 s | 500 ms | 74,143 s |
| 1000 ms | 75,000 s | 1000 ms | 75,000 s |

Latência e margem pesam o mesmo, como esperado: entram somadas em `2·(CD+Λ+Δ)`.

**Correção de runtime:** este build do AutoHotkey não aceita literal de objeto
multi-linha. O plano usa literal de uma linha.

---

## H — Pendências para o primeiro teste prático

Nada foi medido dentro do jogo. É simulação.

1. **A tabela 40/43/45/50 s.** Vem da especificação, não de medição. Um erro
   de 2 s no CD de um tank move a volta em cerca de 4 s.
2. **As taxas 1,0 / 0,5.** Assumidas exatas.
3. **A latência de 250 ms.** Se for maior, a volta alonga na mesma medida.
4. **Se a animação de 2700 ms é redutível.** Entra direto em `F_tank`.
5. **O lure real do respawn.** O plano assume `lure = F_tank − P`. Se o
   respawn não der esse tempo, a volta precisa crescer.
6. **Comportamento em F8, interrupção e falha de envio.**

Nenhum número deste documento representa resultado medido no jogo.
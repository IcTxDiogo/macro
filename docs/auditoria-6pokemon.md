# Auditoria matemática e de confiabilidade — Hoenn 2-2-2

Data: 2026-10-09. Auditoria do otimizador de cooldown dos seis Pokémon.

## A. Diagnóstico

### A.1 Erro grave: dois Pokémon fora da Ball ao mesmo tempo

`Hoenn222CdRegistrarChamada()` colocava **só** o secundário a 1,0× na chamada
do p2. O tank permanecia a 1,0× até a próxima troca de time.

Isso viola a regra de "apenas um Pokémon fora da Ball por vez" e **infla a
capacidade da volta de 3,5× para 4,0×**. Todo o plano era calculado sobre essa
capacidade errada.

**Correção:** a chamada do p2 agora também leva o tank de volta para a Ball.

### A.2 Erro grave: o planejador tratava a dupla como um único Pokémon

A fórmula anterior era:

```
X_k = max(cdTank + Λ + Δ, cdSec + 0,5·p + 0,5·Summon + Λ + Δ)
L   = ΣX / 2
janela_k = 2·X_k − L
```

Três defeitos, todos confirmados pelo simulador independente:

1. **`L = ΣX/2` não tem base física.** Não existe identidade que faça a volta
   ser metade da soma dos "X". A volta é a soma das janelas, e as janelas têm
   de comportar o combo inteiro mais a recuperação.
2. **Dava a janela inteira ao tank.** O tank só recupera a 1,0× no trecho
   pós-cast; o tempo de lure antes do cast não conta, porque o cooldown só
   começa a correr **depois** da skill.
3. **Somava `0,5·Summon` como se fosse ganho.** O secundário está na Ball
   durante o Summon — esse tempo é perda de 0,5×, não acréscimo.

**Consequência medida:** o plano antigo de 67,462 s produzia casts com até
**8,2 s de CD ainda pendente**, em 6 de 18 casts da primeira volta.

### A.3 Margem contada duas vezes

`Hoenn222_CdByTier` e a margem de 250 ms apareciam tanto na restrição do tank
quanto na do secundário, dentro da mesma fórmula. Com a estrutura corrigida
cada restrição usa a margem uma vez.

### A.4 Ineficiência real, não corrigida (e não deve ser)

O **lure** — tempo do tank em campo antes do cast — não recupera o CD do
próprio tank. Só serve ao CD do Pokémon da dupla *anterior*, que já está em
cooldown. Consequência: **o lure é tempo morto do ponto de vista do tank que
vai usar a skill.** É por isso que o piso real fica acima do piso teórico de
3,5×.

---

## B. Fórmula final

Só um Pokémon fora da Ball por vez. Dentro da janela da dupla `k`:

| Trecho | Duração | Quem está fora | Taxa |
| --- | --- | --- | --- |
| troca → lure | `lure` | tank `k` | 1,0 |
| lure → cast do tank | `lure` | tank `k` | 1,0 (CD ainda não começou) |
| `T0+Λ` → `T0+P` | `P − Λ` | tank `k` | 1,0 |
| `T0+P` → troca | resto | secundário `k` | 1,0 |

### Restrição do tank — é a que limita

```
(P − Λ)·1,0 + (L − P)·0,5  >=  CD + Λ + Δ
L  >=  2·CD + 4·Λ + 2·Δ − P
```

Com CD 45 s, Λ = Δ = 250 ms e P = 2700 ms: **L ≥ 88,8 s**.

### Restrição do secundário

Ele fica fora da Ball de `T0+P` até a próxima troca, ou seja `(w − P)` da
janela `w`:

```
(w − P)·1,0 + (L − w + P)·0,5  >=  CD + Δ
w  >=  2·(CD + Δ) − L + P
```

E a janela ainda precisa comportar o combo: `w ≥ P + Gap + Post = 6500 ms`.

### Janelas

O menor `L` que satisfaz as duas restrições. A sobra sobre o mínimo é lure,
que fica disponível para o jogador. Quando a soma dos mínimos dos
secundários exige mais que o piso do tank, é ela que define `L`.

**Verificado:** `tests/simular-6pokemon.ps1` seção 7 cruza a fórmula fechada
com uma busca binária sobre o simulador de eventos. As duas concordam, com o
plano 1,5 ms mais folgado que o mínimo absoluto.

---

## C. Comparação

Composição CONFIG (a que o `config.ahk` usava antes da auditoria):

| Métrica | Valor |
| --- | --- |
| Soma dos seis CDs | 255,0 s |
| Piso teórico 3,5× | 72,857 s |
| Piso teórico 3,5× + 500 ms | 73,714 s |
| Plano antigo (errado) | 67,462 s — **inviável** |
| Macro anterior medido | 86,500 s |
| **Plano corrigido** | **84,800 s** |
| Mínimo absoluto (simulador) | 83,299 s |

Composição principal da auditoria (SR/Lendário, SR/UR, SR/UR):

| Métrica | Valor |
| --- | --- |
| Soma dos seis CDs | 261,0 s |
| Piso teórico 3,5× | 74,571 s |
| Piso teórico 3,5× + 500 ms | 75,429 s |
| **Plano corrigido** | **88,800 s** |
| Mínimo absoluto (simulador) | 87,299 s |

**A composição principal é mais lenta que o macro anterior de 86,5 s.** Não é
regressão: os tanks são SR (45 s) em vez de Lendário/UR. O tier do tank é o
que manda, e ele está no `config.ahk`.

Ganho real sobre o macro anterior, na **mesma** composição: 86,500 → 84,800 s
(**−2,1 %**). Os 20 % de antes eram artefato da capacidade errada.

---

## D. Distribuição dos seis Pokémon

Composição CONFIG, L = 84,8 s, janela = 28,27 s por dupla:

| Dupla | Tank (CD) | Secundário (CD) | Tank fora | Sec fora | Lure |
| --- | --- | --- | --- | --- | --- |
| 1 | Lendário 40 s | UR 43 s | 25,57 s | 25,07 s | 0 |
| 2 | UR 43 s | UR 43 s | 25,57 s | 25,07 s | 0 |
| 3 | UR 43 s | UR 43 s | 25,57 s | 25,07 s | 0 |

O tank não está fora da Ball o tempo todo: são 2700 ms de recuperação real
(2450 ms úteis, descontada a latência) mais o lure. **A soma das janelas é
exatamente L.** Nenhum segundo é contado para dois Pokémon.

---

## E. Tempos obrigatórios e otimizáveis

| Sleep | Valor | Obrigatório? | Efeito na volta |
| --- | --- | --- | --- |
| `SleepAfterTankCombo` | 2700 ms | Sim (animação do jogo) | **Alavanca maior.** Cada +1000 ms aqui encurta a volta em 1000 ms |
| `SleepAfterSwitch` | 800 ms | Sim (chamada → cast) | Incluído em `P + Gap` |
| `SleepAfterCombo` | 3000 ms | Sim (pós-combo) | Incluído em `P + Gap + Post` |
| Pausas de 50 ms em `ComboSimples()` | 4×50 ms | Provavelmente sim | Marginal |

**Oportunidade real:** aumentar o tempo do tank fora da Ball depois do cast
encurta a volta na mesma medida. Em 12 s de pós-cast a volta cai para 76,4 s.
Isso é uma decisão de jogo (o tank precisa continuar em campo), não uma
otimização de software — por isso o valor continua 2700 ms.

Não há espera artificial. O alvo de COMBAR sem CD é a margem (250 ms).

---

## F. Compensação dinâmica

O acumulador é preguiçoso: cada leitura aplica a recuperação decorrida com a
taxa vigente do slot. Eventos que mudam a taxa:

| Evento | Efeito |
| --- | --- |
| Cast do tank | CD = CD principal, contagem em `T+Λ`, taxa 1,0 |
| Chamada do p2 | tank → 0,5, secundário → 1,0 |
| Cast do secundário | CD = CD principal, contagem em `T+Λ` |
| Troca de time | dupla anterior → 0,5, tank novo → 1,0 |
| F8 | seis CDs a zero, todos na Ball |

Atraso não é descontado da próxima espera. O macro recalcula o alvo a partir
dos seis CDs reais a cada leitura. Verificado no simulador:

| Atraso | Volta resultante | Casts com CD pendente |
| --- | --- | --- |
| nenhum | 83,3 s | 0 |
| combo +5 s | 83,3 s | 0 |
| combo +15 s | 83,3 s | 0 |
| combo +30 s | 98,1 s | 0 |
| troca +5 s | 98,3 s | 0 |
| ambos +30 s | 173,3 s | 0 |

Atraso pequeno é absorvido pela folga; atraso maior alonga a volta. **Nunca
força cast com CD pendente.**

---

## G. Testes

| Verificação | Resultado |
| --- | --- |
| Suíte isolada (`hoenn-switch-tests.ahk`) | 27 grupos, todas as asserções |
| Suíte com falha de logger | 28 grupos |
| Boot real do `main.ahk` | exit 0, stderr vazio |
| Simulador: 6 composições × 20 voltas | 0 violações, maior CD no cast 250 ms |
| Simulador: 200 voltas (estabilidade) | 5 primeiras = 5 últimas |
| Propriedade: 40 composições aleatórias | 0 violações no L mínimo |
| Cruzamento fórmula × simulador | 6/6 concordam, folga 1,5 ms |

**Expectativas de teste corrigidas** (nunca afrouxadas, sempre com o motivo):

1. *Tier→CD* fixava `40000`/`43000`/`45000` em números literais. Passou a
   derivar do `Hoenn222_CdByTier`, para não quebrar quando o tier muda.
2. *Cumulador* assumia que `Acao_Gatilhos` (troca de time) disparava combo. É
   uma troca: a dupla vai para a Ball, e a conta é 1,0 até a troca e 0,5
   depois.
3. *Grupo A* assumia verde em `cdSec − 1900`. O alvo encolhe conforme o CD
   recupera, então o verde chega antes: `2·decorrido ≥ cdSec + Λ − tolerância`.
4. *Grupo F* validava `Σ(janelas) = L`, que só valia para a fórmula antiga.
   Passou a validar o piso do tank e que `L` vem do tank mais lento.
5. *Grupo K* fixava `40000`; agora deriva do config.

**Testes novos:** tier desconhecido cai no padrão; tank volta para a Ball na
chamada do p2; nunca mais de um Pokémon fora da Ball; piso do tank; o plano
aumenta quando o tank fica mais lento.

---

## H. Pendências para o primeiro teste prático

Nada abaixo foi validado dentro do jogo. É simulação.

1. **A tabela 40/43/45/50 s.** Os números vêm da auditoria, não de medição.
   Um erro de 2 s no CD do tank move a volta em 4 s.
2. **As taxas 1,0 / 0,5.** Assumidas exatas. Se a de dentro da Ball for 0,6, a
   volta encurta.
3. **A latência de 250 ms.** Medir entre o `ControlSend` e o início real do
   cooldown. Valores medidos antes: 750 ms real → cast 250 ms adiantado.
4. **Se a animação de 2700 ms é redutível.** É a alavanca maior que existe.
5. **Aurrela e quantos segundos de "lure" o respawn permite.** O lure não
   ajuda o tank que vai usar a skill, então só interessa como folga.
6. **Comportamento na troca de time com F8 ou interrupção.**

Nenhum número deste documento representa resultado medido no jogo.
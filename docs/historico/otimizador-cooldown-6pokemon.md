# Otimizador dinâmico Hoenn 2-2-2 — cooldown individual dos 6 Pokémon

**Documento histórico (fase de modelagem). Já implementado: a arquitetura vigente está em
`docs/arquitetura-otimizador-cooldown.md`.** Valores desta página (margem 250 ms, `PrepareMs`,
`SummonMs` configurável) foram superados: `PrepareMs` e a espera estendida foram descartados,
a margem hoje é 450 ms e o atraso de saída do secundário é 1100 ms (`config.ahk`).
Simulador: `tests/simulacoes/sim-cooldown-6pokemon.ps1`. Saída bruta: `simulacao-cooldown-6pokemon.txt`
(nesta pasta).

---

## 1. Reavaliação das quatro perguntas

| Pergunta | Decisão | Efeito |
| --- | --- | --- |
| Margem de segurança | `MarginMs = 250` (só depois do CD estimado zerar) + `LatencyMs = 250` (CD começa a contar 250 ms após o comando) | −17,4 % de volta a −86,5 s |
| PrepareMs | Tempo físico, calibrável, **sem valor inflado por segurança** | ↓0,75 s de volta por segundo de Prepare |
| `SleepAfterTankCombo` | Animação, não margem. Investigado abaixo | ~1,0 s de volta por 1,35 s de invocação |
| Tier → CD | Rótulo do tier é a chave; cada Pokémon tem estado próprio | Sem configuração duplicada |

---

## 2. As cinco grandezas, separadas

O erro da proposta anterior foi tratar "margem" como um colchão único de 2–2,5 s.
São cinco quantidades distintas, com origens diferentes:

| Grandeza | O que é | Padrão | Config |
| --- | --- | --- | --- |
| **CD principal** | Propriedade do Pokémon, pelo tier | 40/43/45/50 s | `CdByTier` |
| **Taxa de recuperação** | Recuperação por segundo real | 1,0 fora / 0,5 dentro | `RateOut`, `RateIn` |
| **Latência** | O jogo começa a contar o CD **depois** do comando | 250 ms | `LatencyMs` |
| **Margem** | Só usar a skill **depois** do CD estimado zerar | 250 ms | `MarginMs` |
| **Animação** | Mechanic do jogo entre dois comandos | 2700 + 800 ms | `SummonMs`, `GapMs` |
| **PrepareMs** | Deslocamento + início do lure, só seu | a calibrar | `PrepareMs` |

Aplicação literal do seu exemplo (CD de 90 s, Pokémon sempre fora da Ball):

```
T            comando enviado
T + 250      início estimado do CD            <- LatencyMs
T + 90 250   CD estimado em zero
T + 90 500   primeiro instante seguro          <- MarginMs
```

Consequência importante e não óbvia: **a latência e a margem se cancelam para o
tank**. O tank sai da Ball com `+250` de atraso (perde 250 de recuperação) e
ganha 250 de prazo (o CD precisa estar zerado 250 ms antes do comando). O que
sobra no plano é `1,5·Latency + Margin` = **625 ms** para o tank e
`0,5·Prepare + 0,5·Summon + 1,5·Latency + Margin` para o secundário.

Regra conservadora usada para transições de Ball, uniforme com a latência do
cast: **sair da Ball leva `LatencyMs`; voltar é imediato.** As duas direções
reduzem a recuperação creditada.

---

## 3. A modelagem já atendia? Três ajustes

O acumulador individual por Pokémon já era a arquitetura correta — não mudou.
O que mudou:

1. **Duas margens separadas** no lugar de uma só. `LatencyMs` entra no instante
   do cast (`since = tick + LatencyMs`) e em cada transição para fora da Ball;
   `MarginMs` é só o prazo de "utilizável".
2. **O secundário também tem instante seguro próprio.** O comando do
   secundário vai para `max(tankCast + Summon + Gap, primeiroInstanteSeguro)`.
   Nunca uma espera fixa de vários segundos "porque ainda não está pronto".
3. **PrepareMs deixou de ser folga.** É o menor deslocamento fisicamente
   viável, e o plano cai `0,75 s` na volta a cada segundo que você conseguir
   remover dele.

### Simplicação proposta: acumulador preguiçoso

Em vez de propagar recovers para todos os slots a cada evento, um acumulador que
se atualiza **na leitura**. Qualquer leitura ou escrita chama `CdTouch` antes:

```
Hoenn222_Cd[i]      ms de CD restantes
Hoenn222_CdRate[i]  1.0 fora / 0.5 dentro
Hoenn222_CdSince[i] tick da ultima mudanca

CdTouch(i, now):  se now > since -> cd -= (now - since) * rate ; since = now
CdSetRate(i, r):  CdTouch ; rate = r
CdCast(i, now):   CdTouch ; cd = CdMain(i) ; since = now + LatencyMs
CdFaltaMs(i, now): CdTouch ; return cd / rate + MarginMs - now
```

Quatro funções curtas, três arrays de 6 posições, indexados por
`slot = (time-1)*2 + (1 tank, 2 secundario)`. É o mesmo modelo da simulação,
sem passo de recuperação espalhado pelo código, e sem risco de esquecer de
atualizar um slot. Elimina de vez a dívida global `Hoenn222_DebtMs`, que faria
contagem dupla.

---

## 4. Investigação dos 2700 ms (`SleepAfterTankCombo`)

O que o código mostra:

```
ComboSimples()               cast do tank em T
Sleep(SleepAfterTankCombo)   2700
ControlSend("{p2}")          chamada do secundario
Sleep(SleepAfterSwitch)      800
ComboSimples()               cast do secundario em T + 3500
```

Não existe nenhum comando enviado dentro dos 2700 ms. O número 2700 não é
redondo, o que sugere ajuste empírico por tentativa contra a animação do jogo —
mas **isso não é verificável pelo código nem pelos logs**: não existe evento de
diagnóstico entre o cast do tank e a chamada, e `Hoenn222_P2CallTick` é escrito
mas nunca registrado.

O que dá para afirmar:

- **Custo real da invocação.** O secundário fica na Ball durante a animação. Na
  fórmula isso vale `0,5 · SummonMs` por volta, então `ΔL = 0,75 · ΔSummonMs`:

  | Invocação | Volta |
  | --- | --- |
  | 4000 ms | 72,44 s |
  | 2700 ms (atual) | 71,46 s |
  | 1350 ms | 70,45 s |
  | 0 ms | 69,44 s |

  Reduzir 1350 ms de invocação vale ~1,0 s de volta. É a segunda maior
  alavanca depois do PrepareMs, e por isso vale um teste em jogo.

- **Não dá para reduzir às cegas.** Se os 2700 ms forem animação de verdade,
  cortá-los faz o `ControlSend("{p2}")` chegar antes do Pokémon estar invocado.
  Recomendação: manter **2700 ms como padrão**, marcar como `SummonMs`
  configurável com o rótulo explícito de animação, e fazer o teste em jogo com
  log de confirmação antes de mexer. O otimizador não depende disso: a regra é
  `espera = max(SummonMs, primeiroInstanteSeguroDoSecundario)`.

---

## 5. Simulação com os parâmetros corrigidos

`MarginMs = 250`, `LatencyMs = 250`, `SummonMs = 2700`, `GapMs = 800`,
`PrepareMs = 4000`. Duplas: Legendary/UR, UR/SR, SR/UR.

```
Volta L = 71,463 s          (limite agregado 68,200 s)

 Time 1: tank Lendário CD 40s | sec UR CD 43s | janela 22,49s | X = 46,98s
 Time 2: tank UR       CD 43s | sec SR CD 45s | janela 26,49s | X = 48,98s
 Time 3: tank SR       CD 45s | sec UR CD 43s | janela 22,49s | X = 46,98s

 comando tank @+4,00s | comando sec @+7,50s | ocioso pós-combo 14,99 18,99 14,99s
```

### Cenário A — execução conforme o plano (4 voltas)

**Skills não prontas no instante do comando: 0 de 12.**

| Volta | Time | Cmd tank | CD | Cmd sec | CD |
|---|---|---|---|---|---|
| v1 | 1 | 75,463 s | −6 350 ms | 78,963 s | **0 ms** |
| v1 | 2 | 97,950 s | −5 350 ms | 101,450 s | **0 ms** |
| v1 | 3 | 124,438 s | −1 350 ms | 127,938 s | **0 ms** |

Os três **secundários batem em 0 ms exatos**: eles limitam a volta e estão
programados no primeiro instante utilizável. Os tanks têm 1,35 a 6,35 s de
folga — e mesmo assim a volta não encurta por causa deles.

Recuperação em 4 voltas:

| Pokémon | fora da Ball | dentro da Ball | creditado | casts |
|---|---|---|---|---|
| L1 tank | 88,0 s | 147,9 s | 161,9 s | 4 |
| U1 sec | 61,2 s | 174,7 s | 148,5 s | 4 |
| U2 tank | 104,0 s | 158,4 s | 183,2 s | 4 |
| R2 sec | 77,2 s | 185,2 s | 169,8 s | 4 |
| R3 tank | 88,0 s | 196,9 s | 186,4 s | 4 |
| U3 sec | 61,2 s | 223,7 s | 173,0 s | 4 |

### Cenário A2 — macro sempre no primeiro instante seguro

Todos os secundários em **−250 ms**: a margem de 250 ms é respeitada com folga,
porque o comando é empurrado até `pronto + 250` em vez de `pronto`.

### Cenário B — cast do tank do Time 1 atrasado 3 s, janela mantida

| Volta | Time | Cmd tank | CD | Cmd sec | CD |
|---|---|---|---|---|---|
| v1 | 1 | 78,463 s | −6 350 ms | 81,963 s | **+1 500 ms ATRASADO** |

O tank continua pronto — esperar mais só ajuda. O secundário perde, porque
entrou 3 s depois na Ball.

### Cenário B2 — mesmo atraso, com a janela replanejada

**Skills não prontas: 0 de 9.** Volta 73,71 s (+2,25 s).

| atraso no cast | janela da dupla 1 | volta | absorvido |
|---|---|---|---|
| 1,0 s | +0,25 s | +0,75 s | 75 % |
| 3,0 s | +0,75 s | +2,25 s | 75 % |
| 5,0 s | +1,25 s | +3,75 s | 75 % |

Não é "descontar X da etapa anterior": o tank fica mais tempo fora (1,0 em vez
de 0,5), o secundário fica menos tempo na Ball e a janela cresce 0,25 s por
segundo de atraso.

### Cenário C — troca antecipada 5 s no Time 2

**Skills não prontas: 0 de 15**, mas o comando do secundário vai deslizando
(73,9 s → 76,7 s → 83,4 s → 101,7 s → 124,9 s) e o macro espera o verde. O
déficit é preservado e absorvido ao longo das voltas, em vez de gastar uma
skill em cooldown.

### Antecipação — sobra de CD abre a janela

| sobra | janela da dupla 1 | volta |
|---|---|---|
| 2,0 s | 21,80 s | 69,40 s |
| 4,0 s | 21,30 s | 67,90 s |
| 8,0 s | 21,30 s | 67,90 s |

Satura em 4 s porque o offset do tank já chegou a zero.

### PrepareMs — a única alavanca realmente grande

| PrepareMs | Volta | vs. 86,5 s |
| --- | --- | --- |
| 2 s | 69,96 s | **−19,1 %** |
| 3 s | 70,71 s | −18,3 % |
| 4 s | 71,46 s | −17,4 % |
| 6 s | 72,96 s | −15,7 % |
| 8 s | 74,46 s | −13,9 % |
| 12 s | 77,46 s | −10,4 % |

Cada segundo de Prepare removido vale 0,75 s de volta. É medido no jogo, não
arbitrado.

### As duas margens de 250 ms custam 0,94 s de volta

| Margin | Latency | Volta |
|---|---|---|
| 0 | 0 | 70,53 s |
| 250 | 250 | **71,46 s** |
| 2 000 | 250 | 74,09 s |

A versao de 2 000 ms custava 2,6 s por volta. Com 250 ms, o preço é 1,3 %.

### Sem tempo suficiente

| Caso | Volta | Janela | casts cabem |
|---|---|---|---|
| 3 duplas todas SR (45 s) | 73,46 s | 24,49 s | sim |
| 3 duplas todas T1 (50 s) | 80,96 s | 26,99 s | sim |
| PrepareMs = 20 s | 83,46 s | 26,49 s | sim |
| PrepareMs = 30 s | 90,96 s | 28,99 s | **não** (precisa de 33,5 s) |

Deteccao de infecibilidade: `w_k < PrepareMs + SummonMs + GapMs`. O macro registra e
**preserva o atraso**; não comprime abaixo do mínimo físico.

---

## 6. Riscos reais

### Cast antecipado

Teste com um CD "real" rodando em paralelo, medindo quanto de CD real restaria
no instante do comando:

| Cenário real | CD real restante no comando |
|---|---|
| tudo exato como o modelo | 0 ms — OK |
| latência real maior que 250 ms | 0 ms — OK (atrasar não quebra) |
| recuperação 1 % mais lenta | **326 ms** |
| recuperação 2 % mais lenta | **778 ms** |
| recuperação 5 % mais lenta | **2 131 ms** |

**Conclusão honesta:** latência a mais é inofensiva — só atrasa. O perigo é
erro de modelo. **250 ms de margem absorve no máximo ~0,8 % de erro na taxa de
recuperação.** Para um CD de 40 s, 250 ms são 0,6 % do CD. Ou seja: a margem é
um buffer de latência, como você definiu; ela **não** protege contra a tabela
de CD ou as taxas 1,0/0,5 erradas. Essas precisam ser medidas no jogo. Os logs
do item 8 existem exatamente para isso.

### Contagem dupla de CD

Não há. O cast faz `cd = CdMain` e `since = tick + Latency`, apagando a
recuperação anterior. E o registro acontece **no mesmo ponto do código** que
envia o comando — `CdCast` para o tank imediatamente antes do primeiro
`ComboSimples()`, e para o secundário imediatamente antes do segundo. Se
`ExecutarRodizio222()` retornar no meio (time mudou), só o tank foi registrado,
exatamente como só o tank foi enviado.

### Espera desnecessária

Três garantias:

- O alvo de COMBAR é `t_estado + max(PrepareMs, faltaDoTank)`. Verde não espera
  nada além do instante utilizável.
- O alvo de TROCAR TIME é `t_estado + w_k` do plano; se já passou, o macro não
  espera (o `pending` fica negativo e o verde acende).
- O alvo de COMBAR em `WAITING_FIRST_COMBO` é imediato, como hoje.

### Duplo acionamento

Não muda. `SolicitarComboHoenn222()` continua decidindo antes de tocar no
acumulador; o pedido armado é cancelado em troca de time, F8 e troca de modo.

---

## 7. Plano de implementação

**`config.ahk`** — bloco só de CD:

```ahk
global Hoenn222_CdByTier := Map("Lendário", 40000, "UR", 43000, "SR", 45000, "T1", 50000)
global Hoenn222_CdDefaultMs := 50000
global Hoenn222_RateOutOfBall := 1.0
global Hoenn222_RateInBall := 0.5
global Hoenn222_LatencyMs := 250
global Hoenn222_MarginMs := 250
global Hoenn222_PrepareMs := 4000
global Hoenn222_SummonMs := 2700      ; animação, não margem
global Hoenn222_SecondaryGapMs := 800 ; chamada -> cast
```

**`src/tempo/cooldown.ahk`** — três arrays de 6 + quatro funções
(`CdTouch`, `CdSetRate`, `CdCast`, `CdFaltaMs`) e `PlanHoenn222()` que devolve
`{ L, w1, w2, w3 }`.

**Alvos** — `GetHoenn222BaseTargetMs()` continua com a mesma assinatura e passa
a devolver o alvo **dinâmico**, para o tooltip não mudar de forma:

```ahk
WAITING_COMBO       -> t_estado + max(PrepareMs, CdFaltaMs(tank))
WAITING_TEAM_SWITCH -> t_estado + w_k do plano recalculado
```

`Hoenn222_DebtMs` sai do cálculo.

**Eventos que tocam o acumulador:**

| Onde | Transição |
| --- | --- |
| `TrocarTimeHoenn` aceita | tank da dupla nova → fora; tank e secundário da dupla anterior → dentro |
| `ExecutarRodizio222`, antes do 1º `ComboSimples()` | `CdCast(tank)` |
| `ExecutarRodizio222`, no `ControlSend("{p2}")` | secundário → fora |
| `ExecutarRodizio222`, antes do 2º `ComboSimples()` | `CdCast(secundario)` |
| `ResincronizarHoenn222` / F8 | todos os CD a 0, todos dentro da Ball |

`GetHoenn222PendingMs()` continua sendo a fonte única da cor e da decisão do
combo — só passa a ler o acumulador.

**Preservado:** teclas, `ComboSimples()`, debounce, `Critical`, `ExecutionId`,
cores, bloqueio por fase, combo antecipado/emergência, logger, tooltips.

---

## 8. Logs para calibração

Diagnóstico (`A_Temp\macro_switch_debug.log`):

| Evento | Conteúdo |
| --- | --- |
| `CAST_SEND` | `slot= role= tier= cd_main= send_tick= cd_start_tick= ready_tick=` |
| `CD_PENDING` | `slot= falta_ms= rate=` no instante do comando |
| `PLAN` | `L= janelas= X= prepare= margin= latency= summon=` a cada troca |
| `INFEASIBLE` | `w= precisa_de=` quando os casts não cabem |
| `SUMMON_ADJUST` | quando a espera estendeu por causa do CD do secundário |

Sessão (`logs\farm_log_*`):

```
CD | Time 1 | tank Lendário 40000 | secundário UR 43000 | janela 22490 | alvo 4000 | ocioso 14990
```

Juntando `CAST_SEND` com o tick real de envio, dá para medir:
1. quanto tempo o `{y}` leva entre `ControlSend` início e fim (validar
   `LatencyMs`);
2. o quanto o macro chegou cedo ou tarde em relação ao alvo (calibrar
   `PrepareMs`);
3. quantas vezes o secundário precisou estender a espera (calibrar
   `SummonMs`).

---

## 9. O que ainda precisa de você

1. **PrepareMs real** no respawn atual. Começaria em 4 s, mas é medida sua.
2. **Os 2700 ms são animação?** Teste em jogo antes de mexer; o ganho é ~1 s de
   volta por 1,35 s removidos.
3. **A tabela 40/43/45/50 e as taxas 1,0/0,5 foram medidas?** A margem de 250 ms
   só absorve ~0,8 % de erro de taxa.
4. `SleepAfterCombo = 3000` continua intocado por ser guarda, não espera real —
   confirmar que concorda.

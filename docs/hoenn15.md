# Modo Hoenn 1,5

Modo alternativo ao 2-2-2 para respawns em que 1,5 combo mata uma lure. Usa os mesmos
6 Pokemon em **2 times de 3** e faz **4 lures por volta** (o 2-2-2 faz 3). O 2-2-2 nao muda.

## Ciclo (um botao so, 3 cliques por time)

| Clique | Fase no painel | O macro faz |
| --- | --- | --- |
| 1 | PARTE 1 (lure 1) | quem abre: combo (`KeyCombo`) -> chama o meio -> Pokestop -> Medicine -> skills da parte 1 -> espera -> pocao |
| (voce lura com o meio) | | |
| 2 | PARTE 2 (lure 2) | meio: skills da parte 2 (stun por ultimo) -> chama o finalizador -> combo (com Pokestop) |
| 3 | TROCAR TIME | chama quem abre o outro time (Pokestop, Full Def, pocao, como no 2-2-2) |

Teclas do jogo: time 1 = `{1}` abre, `{2}` meio, `{3}` finaliza; time 2 = `{4}`, `{5}`, `{6}`.
Todo Pokemon que entra recebe Pokestop e Medicine antes de agir (o meio, 50 ms entre os dois,
como no combo). As esperas sao as do 2-2-2 (2700 ms do combo ate a chamada, 800 ms da chamada
ate agir, 3000 ms depois do combo), mais:
`Hoenn15_SkillGapMs` entre a Medicine e as skills do meio (300 ms: 50 e 100 comiam skill),
`Hoenn15_SleepAfterPart1Ms` entre a ultima skill da parte 1 e a pocao, e
`Hoenn15_SleepAfterPart2Ms` entre a ultima skill da parte 2 e a chamada do finalizador.
Essas esperas entram no plano: a lure 2 conta a partir da pocao.

Cores, pedido armado (violeta), emergencia (dois cliques em 400 ms) e F8 funcionam como no 2-2-2.

## Atalhos

- **F12** (ou Back no controle): gira **Normal -> Hoenn 2-2-2 -> Hoenn 1,5 -> Normal**.
  Entrar no 1,5 recomeca do zero no time 1 (os times sao outros).
- `StartMode` no `config.ahk` escolhe com qual modo Hoenn o macro abre.

## Config

```ahk
global Hoenn15_OpenerTier := Map(1, "Lendário", 2, "UR")    ; quem abre (CD pelo tier)
global Hoenn15_FinisherTier := Map(1, "SR", 2, "SR")         ; quem finaliza
global Hoenn15_MiddlePart1Skills := Map(1, [{Key: "f9", CdMs: 45000}, ...], 2, [...])
global Hoenn15_MiddlePart2Skills := Map(1, [{Key: "f8", CdMs: 40000}, ...], 2, [...])
global Hoenn15_MinLureMs := Map(1, 10000, 2, 10000)          ; lure 1: da troca ate o combo
global Hoenn15_MinLure2Ms := Map(1, 14000, 2, 14000)         ; lure 2 (meio): da pocao ate a parte 2
global Hoenn15_GuestSkill := Map(2, {FromTeam: 1, Key: "f6", CdMs: 20000})  ; skill emprestada
global Hoenn15_GuestSleepAfterMs := 1000                     ; skill emprestada -> chamada do meio
```

- **Skill emprestada:** na parte 1 do time 2, depois do combo de quem abre, o macro chama o meio
  do time 1 (330), da Pokestop + Medicine, usa a F6 dele (30k, 20 s de CD) e so entao chama o
  proprio meio. Fechou a combo 4 que faltava ~7k: o 360 passou a F8 (106) para a parte 2 e a
  combo 3 compensou com a F6. O relogio da F6 anda com o 330 e reinicia nos dois usos (combo 1
  e combo 3); o verde das duas partes 1 confere esse relogio. Custa ~2,15 s por volta.
  `Map()` vazio desliga.

- A lure 2 e mais longa porque inclui ir ate o ponto de divisa: medida em 13 a 15,5 s no log de
  02/11/2026. Se o plano reserva menos que o real, a parte 2 fica verde cedo e o TROCAR TIME
  segura o finalizador alem do necessario. Ajuste pelo log (`COMBO15_PARTE` parte=1 + 2700 ms
  ate o `NEXT_ACTION` da parte 2).

- Cada skill do meio tem a tecla e o CD dela. O CD de cada parte e o da skill que termina por
  ultimo (CD + atraso de envio). Assim, deixar de fora a skill de 45 s ja baixa o CD.
- A parte 1 **nunca** leva o stun; a parte 2 leva o stun por ultimo.
- Lista em UMA linha (este AutoHotkey nao aceita literal de objeto em varias linhas).

## Como o tempo e calculado

Mesmo modelo do 2-2-2 (`docs/arquitetura-otimizador-cooldown.md`): so um Pokemon fora por vez,
1,0 s/s fora e blocos de 2 s na Ball. O meio tem dois relogios (um por parte) que entram e saem
da Ball juntos. O planejador acha a menor volta em que os seis recuperam o CD e reparte o
tempo fora:

- **abre**: da troca de time ate a chamada do meio (lure 1 + combo);
- **meio**: da chamada ate a do finalizador (parte 1 + lure 2 + parte 2);
- **finaliza**: da chamada ate a troca. Se o CD dele pedir mais tempo fora, o TROCAR TIME
  fica amarelo depois do combo: da para andar ate o proximo grupo nesse tempo.

Com o time de exemplo (410 Lendario / 330 SR / 326 SR e 360 UR / 358 UR / 348 SR, lure 1 de
10 s, lure 2 de 14 s, 300 ms entre skills, 2700 ms ate a pocao), a volta fica em
**84,05 s = ~21 s por lure**; o finalizador fica 7,55 s fora (o amarelo do TROCAR TIME).
O 2-2-2 com Lendario UR UR | Lendario x3
fica em 73,05 s = ~24,4 s por lure.

## Diagnostico

Os eventos de log sao os mesmos, com `modo=1,5`: `CD_PLAN`, `CD_CAST` (`papel=abre|meio1|meio2|fim`),
`CD_CHAMADA`, `CD_ENTRADA`, `CD_ANTECIPACAO`. `COMBO15_PARTE` registra as teclas enviadas em cada
parte. A espera depois do stun (`Hoenn15_SleepAfterPart2Ms`, 2700 ms) ainda precisa ser medida na
gravacao para cada Pokemon.

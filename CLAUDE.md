# CLAUDE.md — macro PokeAlliance (AutoHotkey v2)

Macro de farm Hoenn **2-2-2**: 3 duplas (time 1, 2, 3), cada uma com um tank e um secundario.
Fase COMBAR (combo) e fase TROCAR TIME (proxima dupla). O jogador aperta; o macro decide
se executa agora, arma e espera o verde, ou trata como emergencia. Idioma do projeto: portugues.

Estrutura, camadas e diagnostico: `docs/estrutura.md`. Historico e decisoes: `docs/tiers-e-combo-hoenn222.md`.

## Onde mexer para cada ajuste

| Quero... | Onde |
| --- | --- |
| trocar Pokemon/tier de uma dupla | `config.ahk`: `Hoenn222_TankTier`, `Hoenn222_SecondTier` (`Lendário`, `UR`, `SR`, `T1`) |
| CD por tier | `config.ahk`: `Hoenn222_CdByTier` |
| skill comida / folga | `config.ahk`: `Hoenn222_ExitLatencySecondaryMs`, `Hoenn222_LatencyMs`, `Hoenn222_MarginMs` |
| tempo minimo fora (conforto) | `config.ahk`: `Hoenn222_MinLureMs`, `Hoenn222_MinSecondaryOutMs` |
| teclas, janela, tela | `config.ahk` |
| o que um botao faz | `src/macro/acoes.ahk` |
| mapeamento botao do controle | `src/interface/controle.ahk` (`DespacharBotoes`) |
| atalhos de teclado/mouse | `main.ahk` |
| conta do cooldown, plano, verde | `src/tempo/` |

Depois de editar o config: recarregar o macro (Ctrl+Esc ou Start) e F8 para resincronizar.

## Regras que nao se quebram

1. **`GameLoop` (30 ms) nunca usa `Critical`, `Sleep` nem executa acao longa.** Acao longa
   vai em thread descartavel: `SetTimer(fn, -1)`. O laco comeca com `Thread("NoTimers")`.
   Quebrar isso congela o movimento. Toda mudanca nesse caminho roda `run-live-stall-test.ps1`.
2. **`src/tempo/` so calcula.** Nao envia tecla, nao toca em janela, tooltip nem timer
   (um teste falha se acontecer). Camadas: `interface` -> `macro` -> `tempo` -> `nucleo`.
3. **Os intervalos do combo (2700 / 800 / 3000 ms) nao sao do otimizador.** Se o CD nao
   couber, o macro avisa antes (verde), nunca estende a espera.
4. **Troca de time nunca fica presa por erro de calculo:** na duvida, troca.
5. **Nunca subir o `main.ahk` de verdade com o jogo aberto.** Ele le o mesmo gamepad e manda
   teclas ao jogo (ja contaminou uma gravacao). Validar com os testes e `/validate`.
6. **Consertar a causa, nao por margem.** Skill comida = termo errado do modelo. Separar o
   atraso fisico do evento; `MarginMs` e so folga de ruido.

## Como o modelo de cooldown funciona (resumo)

- So um Pokemon fica fora da Ball por vez. CD recupera 1,0 s/s fora e 0,5 s/s dentro.
- Atrasos fisicos separados: inicio do CD apos o cast (250), saida do tank na troca de time
  (250) e saida do secundario na chamada (1100, medido em jogo).
- `slot = (time-1)*2 + (1 tank | 2 secundario)`. Slots pares sao secundarios.
- O planejador acha a menor volta L em que os seis recuperam CD + atrasos + margem.
  A 1a volta ja segue o ritmo do plano (os seis comecam prontos, mas nao liberam de uma vez).
- Cores: verde = executa; azul = faltam <= 10 s (COMBAR); amarelo = espera; violeta = armado.
  Dois cliques em ate 400 ms = emergencia (executa na hora).

## Diagnosticar skill comida

1. Log: `%TEMP%\macro_switch_debug.log` (`CD_CAST`, `CD_ENTRADA`, `CD_ANTECIPACAO`, `LOOP_STALL`).
2. Gravacao: barra F1-F8 mostra os golpes do Pokemon ativo com contador; sincronizar pelas
   transicoes do quadrado central. `*.mp4` e `logs/` ficam fora do git.
3. Skill comida = cast com o contador ainda > 0 **ou** skill "pronta" no cliente e rejeitada
   pelo servidor. Comparar `zerado ha` no `CD_CAST` com a folga real; o limiar do
   secundario ficou perto de 0,9 s depois do zero do modelo.
4. Ajustar o parametro fisico do evento que errou e conferir com 10+ voltas.

## Testes (rodar antes de qualquer commit)

```powershell
powershell -File tests\run-hoenn-switch-tests.ps1                  # logica isolada
powershell -File tests\run-hoenn-switch-tests.ps1 -LoggerInitFailure
powershell -File tests\run-live-stall-test.ps1                     # timers reais
```

- Os runners concatenam `src/indice.ahk` na ordem de `tests/fontes.ps1` e trocam por mocks
  `ControlSend`, `Sleep`, `SetTimer`, `WinExist`, `WinActive`, `WinGetPos`, `ToolTip`,
  `XInput_GetState` e `A_TickCount`. **Novo modulo: listar em `src/indice.ahk` E em
  `tests/fontes.ps1`.** Nova chamada de I/O: criar o mock nos runners.
- Teste novo de comportamento do tempo: `ResetCase()` zera extras e pisos; ligue-os no grupo.

## Convencoes e armadilhas do AutoHotkey v2 deste repo

- Fim de linha CRLF; sem Python na maquina (usar PowerShell/Bash).
- Literal de objeto em UMA linha (`{L: L, Janelas: janelas}`): este build nao aceita multilinha.
- Ler variavel `unset` e erro: inicializar com `false`/`0`.
- Funcao so le global sem declarar; para atribuir precisa de `global`.
- Refatoracao grande: fazer numa copia (`git clone` no scratchpad), testar e so entao
  `git pull --ff-only` no projeto, para nao quebrar o macro que o jogador esta usando.
- `git status` deve estar limpo antes de mexer; commits em portugues, `tipo: resumo`.

## Convencoes de nomes (codigo em portugues, sem acento)

- **Funcoes:** verbo no infinitivo + objeto (`PedirCombo`, `RegistrarCast`, `PlanejarVolta`).
  Consultas dizem o que devolvem e a unidade (`FaltaParaVerdeMs`, `MsAteCastSeguro`).
- **Estado global:** substantivo do dominio (`FaseAtual`, `ComboArmado`, `CooldownRestanteMs`);
  instantes terminam em `Tick`, duracoes em `Ms`.
- **Config:** chaves `Hoenn222_*` e `Key*` em `config.ahk` (nome em ingles, mexe so quem ajusta).
- **Vocabulario:** `time` = dupla/time 1 a 3; `tank`/`secundario`; `slot` = Pokemon (1 a 6);
  "verde" = `FaltaParaVerdeMs() <= 0`; "armado" = pedido esperando o verde.
- **Eventos de log** (`COMBO_FIRED`, `CD_CAST`...) sao contrato com a analise: nao renomear.

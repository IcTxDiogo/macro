# Planejador por blocos validado — 10/10/2026

Ativado por `Hoenn222_UseDiscretePlanner := true`. Com `false`, voltam o planejador continuo, a previsao antiga da chamada, o lure apenas da primeira volta e o prazo antigo de troca. O acumulador de blocos continua ativo nos dois casos. Recarregar para aplicar o config; nao restaurar estado salvo.

Nao foram reduzidos os sleeps 2700/800/3000 nem os tres sleeps de 50 ms de `ComboSimples`. Botoes, Pokestop, pocao, skills, fases, cores, pedidos armados, emergencia e F8 mantem as rotinas existentes. Emergencia continua ignorando deliberadamente o verde.

## Calculo

Para cada slot, seja F o intervalo total fora, L a volta e n um numero de blocos garantidos. O planejador resolve simultaneamente:

`F * RateOut + n * Credito >= CD + atrasos * RateOut + MarginMs + PlannerOutReserveMs`

`F + n * InBallBlockMs + PlannerBallReserveMs <= L`

`sum(F dos seis slots) = L`

O restante incompleto da Ball nao recebe credito. As opcoes inteiras sao verificadas por busca com poda e bisseccao do periodo viavel. As sobras sao distribuidas dentro das capacidades das seis janelas, sem impor lures iguais. Pisos de lure/secundario e os sleeps fisicos sao respeitados. O plano fica em cache e o main o calcula antes de iniciar o timer de 30 ms. Alterar config requer recarregar, nao uma busca a cada frame.

`PlannerOutReserveMs=300` e `PlannerBallReserveMs=500` sao as restricoes explicitas escolhidas para esta distribuicao de 76,3 s. A primeira representa CD excedente; a segunda representa distancia em tempo de Ball dos blocos necessarios. Nao sao latencias do jogo, nao modificam o acumulador e nao adicionam um sleep ao final. O diagnostico continua usando o CD calculado sem essas reservas. Nao confundir essas restricoes conservadoras com uma causa comprovada do servidor.

Sem essas duas reservas, o mesmo algoritmo encontra 75,5 s, candidato fragil. Com elas, encontra 76,3 s para os CDs atuais. Outros tiers produzem outros periodos; nao existe timer fixo de 76300 ms nem uma distribuicao fixa dos Pokemon.

## Preparo e timestamps

`ComboPreparationMs=235` estima o tempo entre o registro logico do cast e a chamada, alem do sleep de 2700 ms. Os logs anteriores inferiam esse valor por essa diferenca, portanto ele inclui os envios associados, inclusive a tecla de chamada. Nao representa um novo Sleep.

O plano usa `F_tank = lure + preparo_estimado + 2700` e inclui o preparo no piso fisico do secundario. Depois da chamada, o prazo de troca passa a ser `chamada_real + F_sec_planejado`. Um preparo mais lento estende a janela da dupla, em vez de reduzir a permanencia do secundario.

O verde projeta apenas os 150 ms de preparo garantidos pelos tres sleeps existentes, somados aos 2700 ms. Ele nao depende de os envios futuros consumirem os 235 ms estimados para completar um bloco. Uma variacao negativa no preparo nao cria um cast com CD estimado pendente. O acumulador continua recebendo os timestamps reais da chamada, troca e registros de cast; nao recebe timestamps sinteticos do plano.

No modo novo, o lure planejado e um piso contado da entrada real em todas as voltas. Esperas maiores por cooldown ou atrasos manuais sao absorvidos; nao se tenta recuperar uma agenda global atrasada.

## Distribuicao derivada atual

| Dupla | Tank fora | Secundario fora | Lure nominal | Janela |
|---|---:|---:|---:|---:|
| Metang / Rhyperior | 15,800 s | 5,633333 s | 12,865 s | 21,433333 s |
| Arcanine / Rampardos | 15,800 s | 11,633333 s | 12,865 s | 27,433333 s |
| Machamp / Metagross | 15,800 s | 11,633333 s | 12,865 s | 27,433333 s |
| Total | | | | **76,300 s** |

Difere ligeiramente da referencia da revisao: os tanks ficam 70 ms menos fora; Rhyperior 43,333 ms mais; os URs 83,333 ms mais. A permanencia Ball dos tanks passa a 60,5 s e as dos secundarios a 70,666667 / 64,666667 / 64,666667 s. Blocos necessarios: 30 / 35 / 30 / 32 / 30 / 32. Folgas nominais de CD: 300 ms nos tanks e 383,333 ms nos secundarios.

## Validacao e limites

Os testes existentes continuam rodando na politica anterior. O novo grupo verifica cache, soma das seis janelas, outros tiers, lures distintos, timestamps, F8, armado, emergencia, modos, preparo rapido e 200 voltas da sequencia de producao com relogio/teclas simulados. Apenas um Pokemon fora e nenhum CD pendente sao verificados antes dos 1200 registros de cast.

O calendario fixo e testado separadamente com +/-100 ms e +/-200 ms nos comandos, mais +/-50 ms de preparo. Nao usar o verde nesse teste e proposital: permitir que ele espere esconderia a inviabilidade do periodo fixo no caso maior. O modelo independente tambem verifica as fronteiras do floor, incluindo os piores extremos.

No caso de +/-100 ms e preparo +/-50 ms, a folga minima calculada e 50 ms nos tanks e 133,333 ms nos secundarios. Com +/-200 ms, podem faltar 150 ms nos tanks e 66,667 ms nos secundarios. O macro deve esperar o verde nesses casos, aumentando a volta. Nao elevar as reservas silenciosamente para fazer o calendario fixo passar.

Sem confirmacao do servidor, um `CD_CAST` e apenas uma estimativa. Nenhum teste automatizado confirma skills aceitas no jogo. A gameplay de 10/10/2026 confirmou 18/18 principais em tres rotacoes, com volta de aproximadamente 76,47 s (ganho de 0,87 s). A versao foi aprovada pelo jogador; isso nao prova a regra interna do servidor.

## Gravar e comparar

1. Com os seis efetivamente prontos e o tank do time 1 fora, recarregar o macro pelo Start/Ctrl+Esc. Abertura/reload comeca no time 1. F8 apenas ressincroniza o time atual e pressupoe os seis prontos.
2. Gravar desde o primeiro combo e executar pelo menos tres voltas completas. Usar os pedidos armados normalmente; evitar duplo acionamento de emergencia para medir a politica do verde.
3. Guardar o video e uma copia de `%TEMP%\macro_switch_debug.log` antes de novos testes. `CD_PLAN` identifica `plano_piso_continuo=0`, preparo e reservas; `CD_CHAMADA` fornece a ancora real; `COMBO_PREPARO` fornece inicio/fim/duracao do preparo de cada papel. `CD_CAST` nao confirma execucao.
4. Conferir visualmente as seis principais, Pokestop e trocas. Medir periodos entre casts equivalentes depois da volta inicial e os intervalos reais fora/Ball.
5. Se falhar, preservar o caso e voltar `UseDiscretePlanner := false`, recarregar e repetir a referencia estavel com os seis efetivamente prontos. Nao zerar os CDs estimados enquanto os reais ainda estao carregando.

Nao iniciar outra copia do main com o jogo aberto. A validacao automatizada usa `/validate` e fronteiras simuladas. A finalizacao inclui cache visual no painel; o contador e arredondado apenas na apresentacao, sem alterar o cronometro ou o planejador.

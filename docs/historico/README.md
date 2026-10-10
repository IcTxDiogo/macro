# Histórico

Análises, saídas de teste e propostas de fases anteriores do projeto. São registros: **não
refletem o estado atual** e não devem ser editados para "acompanhar" o código. Os documentos
vigentes estão em `docs/` (`estrutura.md`, `tiers-e-combo-hoenn222.md`,
`arquitetura-otimizador-cooldown.md`).

| Arquivo | O que registra |
| --- | --- |
| `otimizador-cooldown-6pokemon.md` | proposta do otimizador por Pokémon (margem 250 ms, `PrepareMs`) |
| `auditoria-6pokemon.md` | auditoria do modelo de 6 Pokémon e dos erros que inflavam a volta |
| `diagnostico-troca-manual.md` | diagnóstico da troca manual que falhava (03/10) |
| `troca-manual.patch`, `testes-troca-*.txt` | patch e saídas de teste daquela correção |
| `simulacao-*.txt`, `validacao-otimizador.txt` | saídas brutas dos simuladores em `tests/simulacoes/` |
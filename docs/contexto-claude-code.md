# Contexto para o Claude Code

Este arquivo resume decisões e conversas que não estão (ou não estão completas) em `docs/plano.md`. Leia os dois antes de propor qualquer mudança.

## Como trabalhar

- Primeiro analisar o código e discutir; só implementar depois de o plano ser aprovado.
- Uma etapa do `docs/plano.md` por PR, com testes, seguindo o `AGENTS.md`.
- Toda decisão nova discutida em sessão deve ser registrada no `docs/plano.md`.

## Ordem de lançamento (prioridade)

O produto principal é a nuvem. Lançar primeiro o plano hospedado; servidor local, ISO, launcher e compartilhamento entre empresas ficam para depois.

Regra de prioridade: fazer agora tudo que é caro mudar depois que houver dados de clientes reais; adiar o que pode ser acrescentado sem migração.

1. **Fundações:** repositório privado; autenticação com pessoa, vínculo e perfis; UUID em todas as entidades; exclusão lógica; processamento de arquivos em fila.
2. **Modelo de domínio:** renomear `Modelo` para `Referencia`; criar Produto e o novo Modelo (categoria); tamanhos individuais com cortes que declaram os tamanhos atendidos; colunas de versão e base (`version`, `base_id`, `published_at`) já presentes, sem implementar herança e alertas ainda.
3. **Operação na nuvem:** uma instância por cliente criada por script com Kamal; backup diário de cada instância com restauração testada; cobrança manual no início.
4. **Lançamento beta** com 2 ou 3 clientes, começando pela sublimação cujos dados já estão no sistema.
5. **Depois:** estampas; herança e alertas de versão; cobrança automática; servidor local com ISO; compartilhamento entre empresas.

## Exemplo real do catálogo (planilha de referência)

| Produto | Modelo (categoria) | Molde | Referência | Partes | Tamanhos |
| --- | --- | --- | --- | --- | --- |
| Chinelo | Flip Flop | Slin | — | Correia, Tira | 33-34 ao 39-40 |
| | | | | Detalhe | P e G |
| Chinelo | Flip Flop | Unisex | — | Correia, Tira | 33-34 ao 39-40 |
| | | | | Detalhe | P e G |
| Chinelo | Slide | mind 1 | — | Cabedal, Palmilha, Soleta | 33-34 ao 43-44 |
| | | | | Knit | P, M, G |
| Tênis | Jogging | NB | Fuel, Elite | Cabedal, Forro, Palmilha, Língua | 33-34 ao 43-44 |
| Tênis | Cano Baixo | 21-24 | 21, 24 | Lateral, Língua, Palmilha | 33-34 ao 43-44 |
| Tênis | Cano Baixo | 19-20 | 19, 20 | Lateral, Língua, Palmilha | 33-34 ao 43-44 |
| Tênis | Cano Baixo | 28-29 | 28, 29 | Lateral, Língua, Palmilha | 33-34 ao 43-44 |
| Tênis | Cano Alto | 40-41 | 40, 41 | Lateral, Língua, Palmilha | 33-34 ao 43-44 |

Leitura: "—" significa molde usado diretamente, sem referência. Faixas como 33-34 e rótulos como P/M/G são agrupamentos de cortes; no sistema, os tamanhos são guardados um a um e cada corte declara quais atende. A tabela de correspondência (ex: quais números o Knit P atende) é definida no molde e pode ser substituída na referência.

## Casos de uso levantados

**Dono ou admin:** assinar o plano hospedado; instalar a ISO e parear; convidar funcionários (ou criar acesso temporário offline); bloquear ex-funcionário; aprovar ou adiar atualização com rollback; trocar disco de backup; adicionar disco; restaurar numa máquina nova; migrar entre nuvem e local; acessar remotamente com 2FA.

**Catálogo:** cadastrar produto, modelo, molde, partes e grade; subir cortes marcando tamanhos; criar variação de molde; criar referência herdando partes; substituir, acrescentar ou remover parte; reagrupar cortes na referência; publicar nova versão e alertar dependentes; adotar ou não uma nova versão; usar molde público de outra empresa.

**Estampas, artes e produção:** criar estampa com material do cliente; criar artes (uma por corte); refazer artes após correção da estampa; lançar pedido por tamanho individual e resolver corte e arte; baixar saídas de produção; excluir e restaurar arte.

**Compartilhamento:** compartilhar molde desmarcando itens; compartilhar só um corte com sua arte; receber e produzir offline; revogar; empresa de outro processo pendurar componente próprio numa parte recebida.

**Usuários:** pessoa com vínculos em várias empresas; cliente final aprovando artes e acompanhando pedidos; cliente final criando a própria empresa; suporte do Neajud listando usuários e entrando como eles.

## Casos que ainda faltam discutir

- Ciclo do pedido: rascunho, confirmado, produção, entregue (já existe bloqueio de confirmação no código: peça sem arte, item com quantidade 0, peça sem corte, tamanho que o corte não tem — `PedidoBloqueiosService`).
- Registro de tempo de produção e relatórios.
- Estoque, materiais e cores (existem no código como movimentos, materiais e cores).
- Montagem da impressão: organizar vários cortes numa folha ou rolo.
- Cobrança do ponto de vista do cliente: troca de plano, fim do teste, inadimplência.
- Perfil Financeiro.
- Relação final entre Estampa e Arte (ligação opcional nos dois sentidos, em definição).
- **Pendências viram tarefas** (discutido em 26/09/2026, adiado). A ideia original do produto era um sistema de tarefas (o antigo `docs/product-requirements.md`, removido em 26/09/2026, era "rastrear o tempo gasto em estampas"; a home ainda se chama "Tracker"). Descrever tarefas é chato e ambíguo; o estado dos arquivos já descreve o trabalho. O sistema já calcula pendências com contexto e ação que resolve: `PedidoBloqueiosService` (peça sem arte, item zerado, peça sem corte, tamanho sem corte) e os ícones do card da galeria (sem cliente, não organizado, cortes sobrepostos, sem preview do tamanho, falha de processamento). Direção: essas pendências viram uma caixa de tarefas por perfil, **calculadas** e que **fecham sozinhas** quando o arquivo resolve; gravar responsável e tempo só depois da Etapa 0.5. Próximo passo: cada nova feature que gerar pendências será analisada como fonte de tarefa antes de construir a caixa. Tarefas de produção (cortar/imprimir) e o ciclo do pedido ficam para outra conversa.

## Sugestão de primeira mensagem na sessão

> Leia `AGENTS.md`, `docs/plano.md` e `docs/contexto-claude-code.md`. Quero discutir um conceito novo que ainda não está no plano, antes de escrever qualquer código: [descreva o conceito]. Analise o código atual, me diga onde ele se encaixa e quais partes existentes ele afeta. Não altere nada ainda.

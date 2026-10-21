# Contexto para o Claude Code

Este arquivo resume decisões e conversas que não estão (ou não estão completas) em `docs/plano.md`. Leia os dois antes de propor qualquer mudança.

## Como trabalhar

- Primeiro analisar o código e discutir; só implementar depois de o plano ser aprovado.
- Uma etapa do `docs/plano.md` por PR, com testes, seguindo o `AGENTS.md`.
- **AGENTS.md por domínio (19/10/2026):** o AGENTS.md fica só com as regras de toda mudança; o domínio de cada área vai em `docs/dominio/<área>.md`, lido quando se mexe nela. Cada etapa nova documenta o seu domínio lá, não no AGENTS.md (era 1.772 linhas, ~26 mil tokens em toda sessão). Revisto no mesmo dia: E2E **1× local** (o 3× vinha da época de dev e teste na mesma porta e esperas fixas; o CI roda tudo em todo PR), sem a seção "Known gaps" (vazia), logging em JSON adiado para a Fase 3, o dev :3000 só leitura escrito no fluxo. Feito no mesmo dia: `bin/e2e --alterados` / `--area` com `e2e/areas.yml` (só local; global ou sem área = suíte inteira). **Para depois:** usar os generators do Rails (migração por `bin/rails g migration`, `config.generators` com RSpec/factory_bot, sem helper/assets/jbuilder) — hoje tudo é escrito à mão.
- Toda decisão nova discutida em sessão deve ser registrada no `docs/plano.md`.

## Ordem de lançamento (prioridade)

Detalhada, fase a fase, em `docs/plano.md` › **Ordem de execução** (reordenado em 26/09/2026: nuvem primeiro; servidor local depois, junto com o launcher Tauri; em 30/09/2026 o "Pronto para o beta" passou a vir antes da operação na nuvem).

O produto principal é a nuvem. Lançar primeiro o plano hospedado; servidor local, ISO, launcher e compartilhamento entre empresas ficam para depois.

Regra de prioridade: fazer agora tudo que é caro mudar depois que houver dados de clientes reais; adiar o que pode ser acrescentado sem migração.

1. **Fundações:** repositório privado; autenticação com pessoa, vínculo e perfis; UUID em todas as entidades; exclusão lógica; processamento de arquivos em fila.
2. **Modelo de domínio:** trocar os nomes `Molde` ⇄ `Modelo`; Produto e Modelo (categoria) do catálogo oficial do Neajud; Referência e Nome nas artes; tamanhos individuais com tipo de grade no corte; arte com um arquivo por tamanho; pedido com um tipo; colunas de versão e base (`version`, `base_id`, `published_at`) já presentes, sem implementar herança e alertas ainda. Sem migração dos dados atuais.
3. **Pronto para o beta:** download da arte, ciclo do pedido e etapas de produção, estoque, parâmetros e preços do dono, numeração automática, DTF, estampa corrida e cor lisa, cliente final.
4. **Operação na nuvem:** uma instância por cliente criada por script com Kamal; backup diário de cada instância com restauração testada; cobrança manual no início.
5. **Lançamento beta** com 2 ou 3 clientes, começando pela sublimação; cada instância começa vazia e o cliente sobe tudo de novo.
6. **Depois:** estampas; herança e alertas de versão; cobrança automática; servidor local com ISO; a rede de produção (compartilhamento entre empresas).

## Exemplo real do catálogo

Revisado em 29/09/2026, com os clientes reais (a planilha original misturava molde e referência; a definição vale o que está no glossário do `plano.md`):

| Produto | Modelo (categoria) | Cliente | Molde | Referências (agrupam artes) | Partes |
| --- | --- | --- | --- | --- | --- |
| Tênis | Tenis [TNS] | MKS | 001-TNS | 19, 20 (a 19 tem um detalhe na arte) | Lateral, Língua |
| Tênis | Tenis [TNS] | MKS | 002-TNS Furado (variação do 001) | — | Lateral própria; Língua herdada |
| Tênis | Tenis [TNS] | MKS | 003-TNS Velcro (variação do 001) | — | Lateral própria; Língua herdada |
| Tênis | Jogging [JGG] | NESK | 001-JGG DUNN · 002-JGG NB · 003-JGG Olympus | Fuel, Elite (no 002) | Cabedal, Reforço |
| Tênis | Jogging [JGG] | GMS | 001-JGG NB | Fuel, Elite | Cabedal, Reforço |

Leitura: o molde pertence ao cliente e tem código fixo `NNN-ABR` (número sequencial por cliente) mais um sufixo livre. Mudar o corte de uma parte gera um molde variação; mudar só a arte é outra referência ou outro nome. O nome completo de uma arte é calculado: `002-TNS_20_Bluey Azul_Lingua_29-30`. Faixas como 29-30 são agrupamentos de cortes; no sistema, os tamanhos são guardados um a um e cada corte declara quais atende.

## Casos de uso levantados

**Dono ou admin:** assinar o plano hospedado; instalar a ISO e parear; convidar funcionários (ou criar acesso temporário offline); bloquear ex-funcionário; aprovar ou adiar atualização com rollback; trocar disco de backup; adicionar disco; restaurar numa máquina nova; migrar entre nuvem e local; acessar remotamente com 2FA.

**Catálogo:** escolher produto e modelo (categoria com abreviação) da lista oficial do Neajud; cadastrar molde do cliente (código automático + sufixo), com o intervalo da grade e as partes; subir cortes marcando tamanhos; criar variação de molde que substitui, acrescenta ou remove parte, ou reagrupa cortes; marcar referência e nome nas artes para agrupá-las; publicar nova versão e alertar dependentes; adotar ou não uma nova versão; usar molde público de outra empresa.

**Estampas, artes e produção:** criar estampa com material do cliente; criar artes (uma por corte + referência + nome, com um arquivo por tamanho, agrupados no upload); subir etiquetas DTF, estampas corridas e cores lisas; refazer artes após correção da estampa; lançar pedido (um tipo por pedido: calçado, DTF ou tecido) e, no calçado, por tamanho individual resolvendo corte e arte; baixar saídas de produção; excluir e restaurar arte.

**Compartilhamento e rede de produção:** compartilhar molde desmarcando itens; compartilhar só um corte com sua arte; receber e produzir offline; revogar; empresa de outro processo pendurar componente próprio numa parte recebida; marca subir o DXF cru e os anexos do modelo; fornecedor que assina organizar o molde da marca; subir versão nova e quem compartilhou adotar ou responder "não me afeta"; definir o roteiro (quem faz cada etapa, em que ordem) herdando da marca; marca mandar pedido que se divide entre os fornecedores; fornecedor lançar em nome da marca o pedido que chegou por fora; registrar a passagem da peça de um fornecedor para o outro; marca confirmar o recebimento final.

**Usuários:** pessoa com vínculos em várias empresas; cliente final aprovando artes e acompanhando pedidos; cliente final criando a própria empresa; suporte do Neajud listando usuários e entrando como eles.

## Rede de produção (discutida em 20/10/2026)

Visão do dono do produto: espalhar o Neajud pela cadeia de produção, para que cada pessoa se sinta em casa resolvendo o que é interno, o terceirizado e as várias partes de um mesmo produto feitas em empresas diferentes. Discutida pergunta a pergunta sobre um caso real (INPU, Novac, Harley, MKS, Bordec) e levada ao `docs/plano.md` como a **Fase 9 revista**. Pontos da conversa que não ficam óbvios lendo só o plano:

- O ponto de partida foi "ver dados de várias empresas juntos". Banco único foi descartado pela federação; painel consolidado na nuvem, consulta direta nos arquivos (DuckDB) e consulta ao vivo ficaram como formas de leitura, sem decisão.
- A conta de parceiro gratuita começou maior (o fornecedor subia versões e cadastrava moldes) e foi enxugada pelo dono: **o gratuito recebe e acompanha; trabalhar é assinar**. As exceções são da marca, porque o molde é dela: subir o DXF cru e os anexos, definir o roteiro, mandar pedidos e confirmar o recebimento final.
- O aviso de divergência (dois fornecedores em versões diferentes da mesma parte) foi proposto e recusado como ruído.
- A sobreposição da frequência ao desenho foi decidida e, em seguida, simplificada para anexo; fica como evolução.
- Ainda sem decisão: uma instância por empresa ou um processo com um SQLite por empresa na nuvem (Decisões em aberto do plano).

## Casos que ainda faltam discutir

Discutidos em 29 e 30/09/2026 e levados ao `docs/plano.md`: ciclo do pedido e etapas de produção (Etapa 2.2), estoque e materiais (2.3), montagem da impressão (o RIP monta; o Neajud só estima o encaixe do DTF, 2.6), perfil Financeiro (virou uma função que o dono cria).

- Registro de tempo de produção e relatórios.
- **Celular** (discutido em 19 e 20/10/2026, sem decisão): APK dá para gerar nesta máquina, iOS só com build em nuvem (macOS) e conta Apple. Caminho preferido, se vier: Hotwire Native (reaproveita as telas, API mínima, no namespace próprio, porque `/api/v1` é da nuvem). Alternativas levantadas: PWA com **Web Share Target** (o Neajud no "Compartilhar" da galeria, só no Android, exige HTTPS; o POST do compartilhar vem sem CSRF, então o service worker guarda os arquivos e a página envia pelo upload que já existe) e **bot de WhatsApp** pela Cloud API oficial (avisar e aprovar arte com botões; receber respostas exige URL pública, ou seja, a nuvem). O PWA do Rails já está gerado em `app/views/pwa/`, desligado.
- Cobrança do ponto de vista do cliente: troca de plano, fim do teste, inadimplência.
- Relação final entre Estampa e Arte (ligação opcional nos dois sentidos, em definição).
- **Pendências viram tarefas** (discutido em 26/09/2026, adiado). A ideia original do produto era um sistema de tarefas (o antigo `docs/product-requirements.md`, removido em 26/09/2026, era "rastrear o tempo gasto em estampas"; a home ainda se chama "Tracker"). Descrever tarefas é chato e ambíguo; o estado dos arquivos já descreve o trabalho. O sistema já calcula pendências com contexto e ação que resolve: `PedidoBloqueiosService` (peça sem arte, item zerado, peça sem corte, tamanho sem corte) e os ícones do card da galeria (sem cliente, não organizado, cortes sobrepostos, sem preview do tamanho, falha de processamento). Direção: essas pendências viram uma caixa de tarefas por perfil, **calculadas** e que **fecham sozinhas** quando o arquivo resolve; gravar responsável e tempo só depois da Etapa 0.5. Próximo passo: cada nova feature que gerar pendências será analisada como fonte de tarefa antes de construir a caixa. Primeira caixa por cliente (01/10/2026): a página do cliente lista os "Cortes não organizados" (não organizados, ou organizados sem molde ligado) e mostra em cada molde os seus cortes. As etapas de produção (imprimir, cortar, transferir) e o ciclo do pedido foram decididos na Etapa 2.2 do plano; ligar as pendências a elas continua aberto.

## Sugestão de primeira mensagem na sessão

> Leia `AGENTS.md`, `docs/plano.md` e `docs/contexto-claude-code.md`. Quero discutir um conceito novo que ainda não está no plano, antes de escrever qualquer código: [descreva o conceito]. Analise o código atual, me diga onde ele se encaixa e quais partes existentes ele afeta. Não altere nada ainda.

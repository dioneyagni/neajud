# Primeiros passos: o mapa, as telas vazias e o exemplo

Série decidida em 26/11/2026, depois da pesquisa de estados vazios (o
"Mapa do Neajud": Basecamp, o código aberto do Campfire e guias de design).
Objetivo: o sistema não começar vazio e ensinar o próximo passo.

| Etapa | O que entra |
|---|---|
| **1/6** | `config/mapa.yml` e as telas vazias (esta página) |
| **2/6a** | O assistente inicial: os passos, o que cada um grava, o aviso no Painel (abaixo) |
| 2/6b | Esconder o que a fábrica não produz; "O que produzimos" em Parâmetros › Empresa |
| 3/6 | A marca de exemplo: `Visibilidade`, mostrar/ocultar por pessoa, banner, "Apagar o exemplo" |
| 4/6 | O exemplo por tipo marcado: clientes, artes com arquivos de amostra, pedidos em vários estados |
| 5/6 | A tela de boas-vindas com o play: balões que digitam e salvam o exemplo, e os atalhos |
| 6/6 | Os tours curtos por página na primeira visita, e o "?" para refazer |

Decisões (26/11/2026): Q1 dados de exemplo com exibir/ocultar; Q2a no mesmo
banco, cada registro marcado, ocultar pela `Visibilidade`, a fila real nunca
conta o exemplo; Q3a mostrar/ocultar por pessoa, "Apagar" só o dono, o
cliente final nunca vê o exemplo, com balões guiados; Q4a tour por página na
primeira visita; Q5a o exemplo segue os tipos marcados no assistente; Q6 uma
tela de boas-vindas com play, ou atalhos para quem não quiser; Q7a no play o
sistema digita e salva, a pessoa clica Próximo; Q8a `config/mapa.yml` é a
fonte única; Q9a ícones no estilo dos da Lixeira, na cor do bloco.

## O mapa (`config/mapa.yml`, 1/6)

Cada parte do sistema (29, em 7 blocos: Empresa e acesso, Catálogo, Artes,
Comercial, Materiais e estoque, Produção, Programação) diz:

- `bloco`, `pagina` (o nome da rota), `icone` (em `app/assets/images/icons/partes/`);
- `precisa` (o que precisa existir antes) e `alimenta` (para onde os dados vão);
- `preenche`: `vem` (já vem pronto), `assistente`, `pessoa` ou `sistema`;
- `vazio`: `titulo`, `texto`, `acao` (`link`, `post`, `dialogo` ou `ancora`,
  com a `permissao` — `"area:nivel"`, `"acao:<ação>"` ou `"dono"`), `falta`
  (as contagens do "o que vem antes") e `depois` (mostra para onde leva).

`MapaDoSistema` lê o arquivo uma vez (`LeitorDoMapa` valida): uma ligação para
uma parte que não existe, uma página ou ação sem rota, um tipo de ação
desconhecido ou uma contagem sem contador dá erro, com todos os problemas de
uma vez. As contagens (`MapaDoSistema::CONTADORES`) contam pelo `visiveis`
de quem olha; a dos ritmos só fica "ok" com todas as etapas.

## As telas vazias (1/6)

Canvas "Primeiros passos", pranchetas 1–6. A regra do Basecamp: um título
com "ainda", até três linhas, uma ação. `estado_vazio(:parte, tamanho:)`
(`EstadoVazioHelper`, `shared/_estado_vazio`) desenha:

- `:pagina` — a lista inteira vazia: ícone grande, botão principal;
- `:secao` — uma parte da página vazia: ícone ao lado, borda tracejada,
  botão secundário;
- `:linha` — numa tabela, quando o vazio é normal ("Nenhuma parada").

"O que vem antes" (`falta`): para a equipe, cada item com ✓ ou ○ e a
contagem ("3 cadastrados", "nenhuma ainda"), e o **primeiro que falta vira a
ação principal** (Pedidos sem arte → "Enviar arquivos", na galeria). O
cliente final não vê essa lista, nem o Painel vazio. A ação só aparece para
quem pode fazê-la.

O outro tipo de vazio, um filtro que não deixou nada, é só texto:
`estado_sem_resultado("Nenhum pedido com esse filtro", limpar: pedidos_path)`.

Páginas com tela vazia na 1/6: Clientes, Peças, Moldes, Artes (a galeria,
`#upload`), Pedidos, Materiais, Construções, Turnos, Máquinas, Paradas (a
linha) e o Painel (quando não há pedido nenhum). As outras partes já estão
no mapa para as etapas seguintes.

## O assistente inicial (2/6a)

Decidido em 20/11 (Q1a–Q7a) e desenhado em 26/11 (canvas "Primeiros passos",
pranchetas 7–13). Aparece logo depois do primeiro acesso (`ConfiguracaoController`
→ `/assistente`), só para o dono, com cabeçalho próprio (layout `assistente`).

- **Os passos são uma lista** (`PassosDoAssistente::TODOS`): quantos são não
  está fechado (26/11: "não sei quantos passos vão dar"). Acrescentar, tirar
  ou reordenar é uma linha ali, uma view `assistente/_passo_<chave>` e um
  método `aplicar_<chave>` em `AplicarPassoDoAssistente`; a barra e o
  "faltam N de M" acompanham. Hoje: o que produzem · quem trabalha ·
  horário · máquinas · materiais.
- **O conteúdo é `config/assistente.yml`** (`ConteudoDoAssistente`): os tipos
  (Calçado/Vestuário, DTF, Tecido em corrida, Tecido em cor lisa, Dublagem)
  com os trabalhos de máquina e os materiais típicos de cada um, a frase de
  cada função, os turnos propostos (Manhã 08–12, Tarde 13–18, seg–sex), os
  materiais e as regras dos grupos (as mesmas que a rede de dublagens e as
  sementes do dev usam).
- **Cada passo grava ao avançar** e só acrescenta: tipos e de quem é o
  tecido na empresa (`tipos_produzidos`, `tecido_de`); a função desmarcada
  vai para a Lixeira (com pessoas, continua e avisa); turnos novos (um nome
  que existe fica como está) e os feriados nacionais do ano; uma máquina por
  linha (`SalvarMaquina`); os materiais marcados com seus grupos
  (`CadastroDeMateriais`, compartilhado com `dev:semear`) e, se a empresa não
  tem, o papel padrão e o filme do DTF (grupo próprio, "Filme DTF"). Um
  material que um grupo já existente recusa fica de fora com aviso, sem
  travar o passo.
- **Abrir um passo não grava nada.** Onde parou (`assistente_passo`) muda ao
  avançar, em "Fazer depois" e no primeiro acesso. "Fazer depois" deixa
  tudo ligado e o Painel mostra ao dono "Termine o assistente · faltam N de
  M", com "Continuar de onde parei", até concluir (`assistente_concluido_em`).
- **Refazer** em Parâmetros › Empresa: o que já existe aparece como feito
  (turnos, máquinas, materiais) e só o que for marcado a mais entra.

# Usuários e o acesso do cliente final

Users, sign-in details, and what a cliente final may see and do (Etapa 0.5, 2.8 2/5–5/5). Moved out of `AGENTS.md` on 19/10/2026; read it when working on this area.

## Users (Etapa 0.5)

- **Model:** `User` (the plan's "pessoa"; name chosen in session) +
  `Empresa` (**one per instance** — docs/plano.md Etapa 3.1; `Empresa.atual`)
  + `Vinculo` (user × empresa × **one `Funcao`** + `acessos_extras`). New
  tables get a `uuid` via the `GeraUuid` concern; `users.cloud_user_uuid`
  links to the future Neajud Cloud account (Etapa 7.1).
- **First access:** while there is no user, every page redirects to
  `/configuracao` (`ConfiguracaoInicialService`: empresa + first user as
  `dono`). Once a user exists the screen redirects to sign in — it must never
  reopen (it would let anyone create a second owner).
- **No password reset by email.** On the Usuários page a manager sets a
  **provisional password** (`User#definir_senha_provisoria!`, sets
  `trocar_senha`): until the person picks their own at `/senha/edit`,
  `Authentication#exigir_troca_de_senha` redirects every page there. Anyone
  changes their own password from their name in the header. Email recovery
  comes with the cloud account (Etapa 7.1).
- **Users are deactivated, never deleted** (`User#desativar!`): sign-in is
  refused, sessions end, and `find_session_by_cookie` / the cable connection
  only accept `User.ativos`.
- **Usuários page** (`/usuarios`, action `gerenciar_usuarios`):
  `CadastroDeUsuarioService` saves name, email, função and acessos extras;
  `GestaoDeUsuarios` holds the rules — only a dono manages donos or gives the
  Dono função, nobody gives more than they have, the empresa always keeps an
  active dono, nobody deactivates themselves.

## The cliente final (Etapa 2.8, 2/5–5/5)

- **Client access (2/5, decided 10/10/2026):** a função is the team's or
  **para clientes** (`funcoes.para_cliente`, fixed at creation; default
  "Cliente final": every área "ver", no lixeira). A vínculo with `client_id`
  takes only a função para clientes and the team's never one
  (`Vinculo#tipo_da_funcao`); neither a função para clientes nor a client's
  extras may have `Autorizacao::AREAS_DA_EQUIPE` / `ACOES_DA_EQUIPE`
  (lixeira, baixar/atualizar produção, gerenciar usuários, ver valores) —
  `Autorizacao.erros_para_cliente`. Created and listed on the client's page
  ("Acesso ao sistema", `clients/_acesso_ao_sistema`, needs
  `gerenciar_usuarios`) through `UsuariosController` with
  `usuario[client_uuid]`; its actions come back to that page. `/usuarios`
  lists only the team (`User.da_equipe`). A client in the trash closes its
  people's access (`User.com_acesso`, used by the session cookie and the
  cable). A cliente final lands on Pedidos (sign-in and password change);
  the header shows the client's name.
- **Open/closed by kind (3a, decided 10/10/2026):** `TiposParaCliente` lists
  six kinds — pedidos, moldes, estoque (open by default); original, cortes,
  valores (closed). The dono's default grid is `Empresa#visibilidade_cliente`
  (`/visibilidade`, `VisibilidadePadraoController`); a client's exceptions are
  `Client#visibilidade` (its page, `clients/_visibilidade`, "gerenciar
  usuários"). Record kinds are applied **inside `Visibilidade`**
  (`TIPO_DO_MODELO`; cortes closed leaves only artes), so every `visiveis`
  query follows them; capabilities go through helpers that are the team's
  rule for the team: `aberto_ao_cliente?(:x)` (always true for the team),
  `pode_baixar_original?` (`exige_baixar_original`), `pode_ver_precos?`
  (price only — cost and margin stay `pode_acao?(:ver_valores)`), and
  `exige_aberto :cortes` for a page of a kind (404). The artes' previews and
  versions are never a kind (the client approves them). The sweep also signs
  in a client with every kind closed and looks for his own records' uuids.
- **Live updates per client (3b, decided 11/10/2026):** every page
  subscribes through `AoVivoChannel` with the helpers `canal_dos_cartoes` /
  `canal_do_registro(record)` — never `turbo_stream_from`, whose names Turbo
  signs for its own channel, which checks only the signature (a signed name is
  valid forever, for anyone holding it). `CanaisAoVivo` names the streams by
  uuid (`cartoes:equipe`, `cartoes:<client uuid>`, `arquivo:<uuid>`,
  `pedido:<uuid>` — Turbo's default was `gid://…/Arquivo/232`, the integer id
  in the page), signs them with its own verifier and answers `permitido?` on
  every subscription: the team's cards for the team, a client's for its people,
  a page's while `Visibilidade` shows its record. A card goes to the team and
  to each client whose `Visibilidade` shows the file (`dos_cartoes_de`; a
  corte reaches the clients of its moldes while their cortes are open);
  refreshes go through `CanaisAoVivo.recarregar(record)`. Card DOM ids are
  `arquivo_<uuid>` (`id_do_cartao`). The sweep checks every stream a page
  subscribes; E2E: `e2e/canais-ao-vivo.spec.js` listens to the client's
  WebSocket frames.
- **The client answers in the system (4a, decided 12/10/2026):** for a
  função para clientes, `aprovar_arte` means answering a request (the default
  "Cliente final" has it): on the arte's page, while it is `:aguardando`,
  `RespostaDoClienteController` (`exige_cliente_final`) — **Approve** the
  version he picks of each file (`AprovarNoSistemaService`, canal `sistema`,
  "No sistema"; the photo is his choice) or **Ask for changes** with a note
  (`PedirAlteracaoService` → `AlteracaoArte`). Sending and registering stay
  the team's (`exige_equipe`), whatever his grid says.
- **The client uploads his artes (4b, decided 12/10/2026):** a client's
  função or extras stop at `Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE` — artes
  up to editar, the rest only ver (`erros_para_cliente`; the grid offers no
  more; the default "Cliente final" has artes: editar) — so no client
  registers clients, moldes, the common peças or stock. **Every uuid
  assignment goes through `Visibilidade`** (`AtribuiPorUuid` reads
  `Current.user`; nobody signed in = the team's view): another client's
  molde, client or tamanho is a 404. His uploads are his client's
  (`arquivo_do_upload`; an empty arte from the grouping can take a file —
  `artes_que_recebem`), never a DXF. Versions, the version in use, the client
  and the cortes stay the team's (`exige_equipe`; views use
  `equipe_edita_arquivo?`). The write sweep
  (`spec/requests/visibilidade_escrita_spec.rb`) sends every
  POST/PATCH/PUT/DELETE route as client A with B's uuids and checks nothing
  of B changed and nothing of A points at B; new routes are swept
  automatically. E2E: `e2e/cliente-envia.spec.js`.
- **The client's drafts (5/5, decided 12/10/2026):** a client's grid goes up
  to pedidos: editar (the default "Cliente final" has it). He builds a draft
  of his artes and **sends it to the factory** — `Pedido` status `enviado`
  ("aguardando a fábrica", between rascunho and confirmado;
  `Pedido::ANTES_DA_CONFIRMACAO`, `confirmavel?`, scope `nao_confirmados`,
  which `RecomporRascunhos` follows). Pendências never stop sending; on the
  panel his own (quantity 0, a file or side missing) keep their actions and
  the factory's (`PedidoBloqueiosService::DA_FABRICA`) show as "em análise".
  Sent, only the team changes it (`Pedido#editavel?(cliente_final:)`, the
  `recusar_pedido_travado` guard — which also stopped a confirmed pedido's
  grade from changing); he may take it back ("Retirar o envio") until it is
  confirmed. `EnviosPedidoController` (`enviar` / `retirar` for the client,
  `devolver` with a required note for the team) moves the status through
  `EnvioDoPedido` and writes an `EventoPedido` (the pedido's "Histórico").
  Confirming is the team's (`exige_equipe`), from rascunho or enviado. Notices
  stay in the system: the team's header counts the pedidos `enviado`
  (`aguardando_fabrica_count`, links to the filter), the client's Pedidos
  lists the drafts returned with their note on top
  (`Pedido#devolucao_pendente`). E2E: `e2e/cliente-rascunho.spec.js`.

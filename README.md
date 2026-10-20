# Neajud

Sistema para pequenas produções (sublimação, gráficas, ateliês, private label) organizarem o
catálogo de moldes e as peças que os compõem, as artes e cortes de cada peça, e os pedidos que
vão para o chão de fábrica — com os arquivos de produção (DXF de corte por tamanho) prontos
para baixar.

Rails 8.1 monolítico: SQLite, Hotwire (Turbo + Stimulus), Importmap, Solid Queue/Cache/Cable,
ImageMagick, exiftool e scripts Node (UTIF.js, dxf) para prévias e extração de DXF.

## Documentação

| Documento | Conteúdo |
|---|---|
| [AGENTS.md](AGENTS.md) | Como trabalhar no código hoje: estilo, testes, comandos, fluxo de PR, armadilhas conhecidas |
| [docs/dominio/](docs/dominio/) | O domínio por área (pedido do calçado, produção, estoque, artes, DTF, tecido…), lido conforme o que se mexe |
| [docs/plano.md](docs/plano.md) | Para onde o produto vai: visão, domínio, fases e regras para o agente |
| [docs/contexto-claude-code.md](docs/contexto-claude-code.md) | Ordem de lançamento, decisões das sessões e temas em aberto |

## Rodando localmente

Dependências do sistema: `imagemagick`, `exiftool` (`libimage-exiftool-perl`) e Node.js.

```bash
bin/setup                # instala as gems e prepara o banco
npm install              # pacotes Node dos scripts de prévia/DXF e do Playwright
bin/dev                  # servidor de desenvolvimento em http://localhost:3000
bin/dev-backup           # snapshot dos dados de desenvolvimento (antes de algo arriscado)
```

## Testes

```bash
bin/rspec                # unitários e de requisição
bash bin/e2e             # Playwright E2E, num servidor de teste próprio na porta 3001
```

Pre-commit, fluxo de branch/PR e o que cada teste precisa conferir estão no [AGENTS.md](AGENTS.md).

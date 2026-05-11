# Testes

## Stack de Testes

- **Unit/Request**: RSpec + FactoryBot + Shoulda Matchers
- **E2E**: Playwright (Chromium headless)
- **Pipeline E2E**: Script `bin/e2e` que mata servidor → prepara DB → sobe server → roda testes → derruba server

## Rodar Testes

```bash
# RSpec (modelos + requests)
bundle exec rspec

# E2E headless (completo)
bash bin/e2e

# E2E com navegador visível
bash bin/e2e --headed

# Ciclo completo: testes + verificação
bundle exec rspec && bash bin/e2e
```

## Após Qualquer Alteração

Sempre rodar na sequência:

```bash
# 1. Testes unitários
bundle exec rspec

# 2. E2E completo (mata servidor, sobe, testa, derruba)
bash bin/e2e

# 3. Verificar se o servidor sobe sem erros
bin/rails server -p 3000 -e test
# Acessar http://localhost:3000 e confirmar 200 OK
```

## Verificação de Erros

```bash
# Subir servidor em background e checar logs
bin/rails server -p 3000 -b 0.0.0.0 -e test &>/tmp/neajud_server.log &
sleep 3

# Testar página inicial
curl -sI http://localhost:3000  # deve retornar 200

# Verificar log por erros
grep -i "error\|exception\|NoMethod\|undefined\|fail" /tmp/neajud_server.log

# Testar rota principal
curl -s http://localhost:3000/stamps

# Derrubar servidor
kill $(lsof -t -i:3000) 2>/dev/null; fuser -k 3000/tcp 2>/dev/null
```

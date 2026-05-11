# Segurança

## Banco de Dados Criptografado

O banco SQLite deve utilizar criptografia.

Sugestão:
- SQLite + SQLCipher

---

# IDs Aleatórios

Todos os registros expostos externamente devem usar:
- UUID
- SecureRandom.uuid

---

# Upload Security

## Tamanho máximo

Limite por arquivo:
- 1GB

---

## Proteção contra abuso

Bloquear automaticamente usuários/IPs que:
- tentarem subir mais de:
  - 3 arquivos de 1GB
  - em sequência

A ação deve:
- gerar registro na tabela `Ban`
- executar via background job

---

# Validação real de tamanho

Nunca confiar:
- no Content-Length
- nem apenas nos metadados enviados pelo navegador

Conferir:
- tamanho real do arquivo em disco após upload

---

# Rate Limiting

Todos endpoints públicos devem usar:
- Rack::Attack

---

# IP Banning Automático

Implementar:
- modelo `Ban`
- middleware de bloqueio
- job assíncrono

---

# Segurança do ImageMagick

Configurar `policy.xml`.

Exemplo:

```xml
<policy domain="coder" rights="none" pattern="PDF" />
```

---

# Nunca fazer

- processar PSD/TIFF diretamente no request web
- confiar em MIME type do navegador
- confiar apenas na extensão do arquivo

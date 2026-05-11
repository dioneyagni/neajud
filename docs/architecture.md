# Arquitetura

## Stack

- Ruby 3.3.x
- Rails 8.1.x
- SQLite3
- Propshaft
- Importmap
- Hotwire
- SolidQueue
- SolidCable
- SolidCache

---

# Estratégia

Sistema monolítico Rails.

---

# Processamento Assíncrono

Uploads nunca devem processar inline.

Fluxo:

1. Upload
2. Persistência
3. Enfileiramento
4. Processamento
5. Broadcast Turbo Streams

---

# Estrutura de Storage

```txt
storage/stamps/:uuid/original/
storage/stamps/:uuid/preview/
storage/stamps/:uuid/overlay/
```

---

# Estratégia de Banco

SQLite será mantido.

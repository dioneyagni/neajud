# Modelagem de Domínio

## Stamp

Representa uma estampa individual.

### Campos

- id
- uuid
- original_file
- preview_file
- overlay_file
- filename
- extension
- mime_type
- colorspace
- has_spots
- estimated_seconds
- annotated_seconds
- status
- batch_id
- created_at
- updated_at

### Status

- pending
- processing
- processed
- failed
- invalid_colorspace
- unsupported_format

---

## StampTimeLog

Histórico de alterações manuais de tempo.

### Campos

- id
- uuid
- stamp_id
- previous_seconds
- new_seconds
- changed_by
- created_at

---

## BatchUpload

Representa um lote de upload.

### Campos

- id
- uuid
- total_files
- processed_files
- failed_files
- uploaded_by
- created_at

---

## Ban

Bloqueio automático de IPs abusivos.

### Campos

- id
- ip_address
- reason
- expires_at
- created_at

---

# IDs

Todos os modelos devem usar:
- UUID aleatório
- Nunca expor IDs sequenciais publicamente

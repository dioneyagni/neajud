# Processamento de Imagem

## Objetivos

- preservar ICC profile
- detectar spot channels
- gerar previews corretos
- suportar RGB e CMYK

---

# Formatos suportados

- tif
- tiff
- psd
- jpg
- eps
- ai
- cdr

---

# Limites

Tamanho máximo:
- 1GB por arquivo

---

# Pipeline CMYK com spots

```bash
convert arquivo.tif[0]   -channel cmyk   -separate   -background white   -profile XCMYK\ 2017.icc   -profile sRGB.icc   -colorspace sRGB   -combine   -type TrueColorAlpha   preview.png
```

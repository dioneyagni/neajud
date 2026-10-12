# Calibrador de cor por foto — especificação

## Contexto

Somos uma estamparia. Uma demanda frequente é reproduzir uma **cor chapada no tom exato de um material do cliente**. Hoje isso exige vários testes manuais. O objetivo é automatizar: medir a cor do material com a câmera do celular, gerar arquivos de teste com variações próximas e convergir para o tom certo em poucas rodadas, com histórico de tudo.

O sistema será integrado ao **app Rails que já existe**. A ideia não é criar um perfil ICC completo, e sim acertar **uma cor por vez**, usando um modelo local da impressora.

## Princípio de medição

O celular vira um "colorímetro aproximado" fotografando cartões impressos com **cores conhecidas** e **marcadores de alinhamento**. O software:

1. detecta os marcadores (ArUco) e corrige a perspectiva;
2. compara os patches de referência fotografados com seus valores conhecidos e calcula uma **matriz de correção de cor** (3×3 ou polinomial), corrigindo luz e câmera;
3. aplica a correção e converte para **CIE Lab**;
4. compara cores com **ΔE2000**.

Precisão esperada: ΔE ~2–5, suficiente para combinar com a escolha visual. Requisitos da captura: exposição, ISO e balanço de branco travados, de preferência RAW (DNG), luz uniforme de alto CRI e sem reflexo.

## Fase 1 — Calibração de cada impressora (uma vez por impressora)

Objetivo: saber como cada impressora desvia em relação a cores conhecidas.

1. Imprimir o **cartão de calibração** em papel (o original, com cores conhecidas, tipo Pantone).
2. Estampar o **mesmo arquivo, sem correção**, no tecido mais usado.
3. Cortar a laser um **furo de 3,5 mm no centro de cada patch** da cópia estampada.
4. Sobrepor a estampa furada ao original: em cada patch, o furo mostra a cor verdadeira e a borda mostra a cor estampada.
5. Fotografar. O sistema mede furo × borda em cada patch e calcula a correção.
6. Estampar de novo com a correção e repetir até alinhar.
7. Salvar o **perfil da impressora** (uma correção por impressora, não por tecido).

Os valores de referência dos cartões são estabelecidos uma vez, fotografando cada cartão novo ao lado de uma referência comercial (ex.: ColorChecker). Se um cartão for reimpresso, ele precisa ser recalibrado.

## Fase 2 — Pedido de cor (dia a dia do vendedor)

1. O vendedor coloca o **cartão de bolso** sobre o material do cliente, com a cor aparecendo pelo furo central, e fotografa pelo app.
2. O sistema corrige a foto com os patches ao redor do furo e obtém o **Lab alvo**.
3. Usando o perfil da impressora, gera uma **impressão de teste** com uma grade numerada de variações em volta do alvo previsto.
4. A impressão é estampada e fotografada sob o **cartão A4 de visualização** (janela central). O sistema mede cada variação e calcula o ΔE até o alvo.
5. O vendedor escolhe a variação mais parecida e dá feedback (mais claro/escuro, mais/menos vermelho, azul, amarelo). O feedback vira um deslocamento em Lab.
6. Próxima rodada com passos menores, centrada na nova previsão (modelo local: valor enviado → Lab medido). Normalmente 2–3 rodadas.
7. Ao aprovar, salvar a **receita final** no pedido.

Se o alvo estiver **fora do gamut** da impressora, avisar e entregar a cor mais próxima possível, informando o ΔE mínimo.

## Peças físicas (layouts já desenhados)

Todos os arquivos são gerados pelo sistema em **TIFF CMYK, perfil US Web Coated (SWOP)**, com o arquivo de corte separado (SVG/DXF) para laser ou plotter.

| Peça | Tamanho | Conteúdo |
|---|---|---|
| Cartão de bolso (original) | 85,6 × 54 mm | 4 marcadores ArUco nos cantos; 32 patches de referência (neutros, primárias CMYRGB, tons de pele e terrosos, cores saturadas) em volta; anel cinza 50% e furo central para o material. ID impresso: `CB · v1 · lote` |
| Cartão de bolso (cópia estampada, fase 1) | 85,6 × 54 mm | Mesmo arquivo estampado, com furo de 3,5 mm em cada patch |
| Cartão A4 de calibração (fase 1) | A4 | 4 marcadores; grade de 14 × 15 = **210 patches de 11 mm**: escala de cinzas no topo e na base, coluna de cinzas em cada lateral (em sentidos opostos, para detectar luz irregular), tons de pele e terrosos, e 12 matizes (a cada 30°) em várias combinações de claridade e saturação. Furo de 3,5 mm por patch só na cópia estampada |
| Cartão A4 de visualização (fase 2) | A4 | 4 marcadores; as mesmas 32 cores de referência distribuídas na borda; moldura cinza neutra; **janela grande central** onde aparece a impressão de teste. Sem campos para preencher: todos os dados ficam no app |
| Impressão de teste (fase 2) | 150 × 240 mm, no tecido | Número único do teste (ex.: `T-000123`) em destaque + **QR code** com esse número; pedido, rodada e impressora; grade de **5 × 7 = 35 variações numeradas**, com o alvo previsto marcado; número repetido na margem, que fica sob a moldura do A4 |

O QR/número do teste abre no sistema o material, a **ficha técnica de produção** e o histórico de rodadas.

## Arquitetura proposta

- **App Android nativo (captura)**: Kotlin + Camera2 (não CameraX), com controle manual e RAW quando o aparelho suportar. Faz a pré-checagem na tela (cartão detectado, luz uniforme, sem reflexo), lê o QR e envia a foto para a API do Rails. Sem processamento pesado no aparelho.
- **Rails (orquestração)**: API e telas web, Active Storage para as fotos, jobs (Sidekiq ou Solid Queue), cadastro de impressoras e perfis, pedidos de cor, rodadas e histórico. Gera ou solicita os arquivos de teste.
- **Serviço Python (cor)**: FastAPI chamado pelo Rails por HTTP (ou script chamado pelo job). Bibliotecas: OpenCV (ArUco, perspectiva, extração de patches), `colour-science` (Lab, ΔE2000, matriz de correção), NumPy. Gera também os TIFF CMYK e os arquivos de corte.

## Modelo de dados (sugestão)

- `Printer`: nome, perfil de calibração atual.
- `PrinterCalibration`: impressora, iterações, medições por patch, correção resultante, status.
- `ReferenceCard`: tipo (bolso, A4 calibração, A4 visualização), versão, lote, valores Lab de referência de cada patch.
- `ColorRequest`: pedido, cliente, material, impressora, foto da amostra, Lab alvo, status (em teste, aprovada, fora do gamut), link para a ficha técnica.
- `TestPrint`: número único (`T-000123`), request, rodada, arquivo gerado, foto medida.
- `TestPatch`: test_print, posição (1–35), valor CMYK enviado, Lab medido, ΔE até o alvo.
- `Feedback`: test_print, patch escolhido, ajustes (mais claro, menos azul…).
- `Recipe`: valor final aprovado, ligado ao request e à impressora.

## Telas (layouts já desenhados)

1. **App: captura da cor**: câmera com guia do cartão, checagens (enquadramento, luz, reflexo), cor lida no furo, impressora selecionada e botão de captura.
2. **App: escolha da rodada**: tecido do cliente ao lado da variação escolhida (com ΔE), grade numerada 5 × 7 com a sugestão do sistema marcada, botões de ajuste e ações "Aprovar" e "Gerar próxima rodada".
3. **App: versões e rodadas**: ficha do pedido (cliente, material, impressora, alvo) e linha do tempo das rodadas (número do teste, faixa de cores, escolhido, ΔE, ajuste pedido), com atalhos para o gamut e a ficha técnica.
4. **Web: todas as cores**: banner em toda a largura com uma **cartela 2D de ladrilhos** que se preenche conforme as cores entram (coluna = matiz, linha = claridade, primeira coluna = neutros, células vazias em cinza escuro, tooltip com o número do teste e a contagem); abaixo, busca, filtros (status, impressora) e tabela (cor, teste, pedido, cliente, material, impressora, rodadas, ΔE, status).
5. **Web: visualizador de gamut** (página "artística", fundo escuro): **corte 2D** no plano a\*b\* com controle de claridade L, mostrando as cores que a impressora alcança, as que só a tela mostra, o limite sRGB, o alvo e o caminho das rodadas; **sólido 3D** do gamut girando em volta do eixo L, com o corte atual destacado; modo "alvo fora do gamut" com linha até a cor mais próxima e o ΔE. O gamut real vem das medições da fase 1. Na versão final, o 3D pode ser feito com Three.js (casca do sólido).

## Ordem de implementação sugerida

1. Protótipo Python: gerar os cartões (TIFF CMYK + corte), detectar marcadores, corrigir a cor e medir Lab a partir de fotos tiradas com app de câmera manual (ex.: Open Camera). Validar a precisão.
2. Fase 1 ponta a ponta: perfil de impressora.
3. Modelos e API no Rails, integração com o serviço Python e jobs.
4. Fase 2: geração da impressão de teste numerada, medição, feedback e rodadas.
5. Telas web (histórico com banner, gamut).
6. App Android de captura.

## Pontos em aberto

- Valores CMYK exatos dos patches de cada cartão.
- RIP e gerenciamento de cor atuais da impressão (como o TIFF é enviado à impressora).
- Luz padrão para fotos e aprovação (metamerismo).
- Materiais difíceis (metalizado, fluorescente, muito texturizado).
- Onde hospedar o serviço Python (mesmo servidor ou separado).

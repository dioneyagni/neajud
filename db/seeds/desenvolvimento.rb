# The development database's starting groups and materials (decided
# 28/10/2026, before Dublagem 2/5: the network names groups the dev database
# didn't have). Read by SemeadorDeDesenvolvimento, run by
# `bin/rails dev:semear`; never by db:seed, so no instance starts with them.
#
# Groups follow the roles of Dublagem 1/5: a superfície goes on the face, a
# base dubs another; the ligantes (filme, in micras) and the insumos
# (papel, kraft, plástico de sucção; 28/10/2026) are neither. Materials are created with no stock and no price: entries and
# prices stay the people's.
module DadosDeDesenvolvimento
  GRUPOS = [
    { nome: "Oxford", superficie: true, base: true, estampavel: "sim", pede: %w[densidade], obrigatorios: %w[gramatura] },
    { nome: "Microfibra", superficie: true, base: true, estampavel: "sim", obrigatorios: %w[gramatura] },
    { nome: "Cetim", superficie: true, base: true, estampavel: "sim", obrigatorios: %w[gramatura] },
    { nome: "Telinha", superficie: true, base: false, estampavel: "sim", obrigatorios: %w[gramatura] },
    { nome: "TNT", superficie: true, base: true, estampavel: "ressalvas", ressalva: "a estampa pode ficar menos nítida", obrigatorios: %w[gramatura] },
    { nome: "Helanca", superficie: false, base: true, estampavel: "nao", obrigatorios: %w[gramatura] },
    { nome: "Lona", superficie: false, base: true, estampavel: "nao", obrigatorios: %w[gramatura] },
    { nome: "EVA", superficie: false, base: true, estampavel: "nao", obrigatorios: %w[espessura_mm] },
    { nome: "Espuma", superficie: false, base: true, estampavel: "nao", obrigatorios: %w[densidade espessura_mm] },
    { nome: "Filme", superficie: false, base: false, estampavel: "nao", obrigatorios: %w[micras] },
    { nome: "Filme PU", superficie: false, base: false, estampavel: "nao", obrigatorios: %w[micras] },
    { nome: "Filme TPU", superficie: false, base: false, estampavel: "nao", obrigatorios: %w[micras] },
    { nome: "Papel", superficie: false, base: false, estampavel: "nao", obrigatorios: %w[gramatura] },
    { nome: "Kraft", superficie: false, base: false, estampavel: "nao", obrigatorios: %w[gramatura] },
    { nome: "Plástico de sucção", superficie: false, base: false, estampavel: "nao", obrigatorios: %w[micras] }
  ].freeze

  MATERIAIS = [
    { grupo: "Oxford", cor: "Branco", largura: "1.40 m", gramatura: "120g" },
    { grupo: "Oxford", cor: "Preto", largura: "1.40 m", gramatura: "120g" },
    { grupo: "Microfibra", cor: "Branco", largura: "1.40 m", gramatura: "180g" },
    { grupo: "Cetim", cor: "Branco", largura: "1.50 m", gramatura: "90g" },
    { grupo: "Telinha", cor: "Branco", largura: "1.60 m", gramatura: "90g" },
    { grupo: "TNT", cor: "Branco", largura: "1.40 m", gramatura: "80g" },
    { grupo: "Helanca", cor: "Branco", largura: "1.60 m", gramatura: "150g" },
    { grupo: "Lona", cor: "Bege", largura: "1.40 m", gramatura: "300g" },
    { grupo: "EVA", cor: "Preto", largura: "1.40 m", espessura_mm: 2 },
    { grupo: "Espuma", cor: "Branco", largura: "1.40 m", densidade: "TC4", espessura_mm: 3 },
    { grupo: "Espuma", cor: "Branco", largura: "1.40 m", densidade: "TC4", espessura_mm: 5 },
    { grupo: "Filme", cor: "Branco", largura: "1.40 m", micras: 25, tipo: "filme" },
    { grupo: "Filme", cor: "Branco", largura: "1.40 m", micras: 35, tipo: "filme" },
    { grupo: "Filme PU", cor: "Branco", largura: "1.40 m", micras: 100, tipo: "filme" },
    { grupo: "Filme TPU", cor: "Branco", largura: "1.40 m", micras: 100, tipo: "filme" },
    { grupo: "Papel", cor: "Branco", largura: "1.60 m", gramatura: "90g", tipo: "papel" },
    { grupo: "Kraft", cor: "Bege", largura: "1.60 m", gramatura: "80g", tipo: "kraft" },
    { grupo: "Plástico de sucção", cor: "Branco", largura: "1.80 m", micras: 50, tipo: "plastico_succao" }
  ].freeze
end

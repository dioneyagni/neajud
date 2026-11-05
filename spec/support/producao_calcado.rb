# A confirmed calçado pedido for the Painel specs (Painel 1/4), as in
# RegistrarBaixaService's spec: each item an arte with Lateral + Língua
# files of 29-30, 5 pairs of 30, cut on a Tactel 1,40 m.
# Usage: pedido = pedido_calcado_confirmado(itens: 2)
#        RegistrarBaixaService.call(pedido, etapa: "corte", nivel: "pedido", medida: "0,6")
module ProducaoCalcado
  def pedido_calcado_confirmado(itens: 1, client: create(:client))
    partes = %w[Lateral Língua].map { |nome| Peca.find_by(nome: nome) || create(:peca, nome: nome) }
    molde = create(:molde, client: client, partes: partes)
    material = @tactel_do_painel ||= MateriaPrima.create!(grupo_material: GrupoMaterial.create!(nome: "Tactel"), cor_material: CorMaterial.find_or_create_by!(nome: "Azul"),
                                                         largura: "1.40 m", gramatura: "80g")
    pedido = create(:pedido, client: client)
    cortes = partes.to_h { |peca| [ peca, corte_do_molde(molde, peca) ] }
    itens.times { item_calcado(pedido, molde, cortes, material) }
    pedido.update!(status: "confirmado")
    pedido.reload
  end

  # The pedido produced up to the Conferência, which counts `faltam` Laterais
  # fewer (of 10): the whole pedido at once releases the reposição; one line
  # (juntando: true) leaves it gathering, a rascunho. refazer: the stages
  # to redo ("impressao" alone: the cut piece was fine), else both.
  # Usage: reposicao = reposicao_com_falta(pedido, faltam: 2) # => #<Pedido status="confirmado" reposicao_de=pedido>
  def reposicao_com_falta(pedido, faltam: 2, juntando: false, refazer: nil)
    %w[impressao corte estamparia].each { |etapa| RegistrarBaixaService.call(pedido, etapa: etapa, nivel: "pedido", medida: "20", confirmar: true) }
    lateral, lingua = LinhasDeProducao.call(pedido, EtapasProducao.etapa("calcado", "conferencia")).map(&:chave)
    contadas = (10 - faltam).to_s
    baixa = if juntando
      RegistrarBaixaService.call(pedido, etapa: "conferencia", nivel: "linha", alvo: lateral, medida: contadas, contagens: { lateral => contadas })
    else
      RegistrarBaixaService.call(pedido, etapa: "conferencia", nivel: "pedido", medida: (20 - faltam).to_s, contagens: { lateral => contadas, lingua => "10" },
                                         refazer: (refazer && { lateral => refazer }))
    end
    baixa.baixa.reposicao.reload
  end

  def corte_do_molde(molde, peca)
    create(:arquivo, :corte, organized: true, peca: peca, client: molde.client, modelo: molde.modelo, giro: "180").tap do |c|
      c.moldes << molde
      create(:tamanho, arquivo: c, nome: "29-30", numeros: %w[29 30], position: 1, metros_por_peca: { "1400" => 0.02 })
    end
  end

  def item_calcado(pedido, molde, cortes, material)
    lateral, lingua = cortes.keys
    arte = create(:arquivo, molde: molde, client: molde.client, peca: lateral, tamanho: cortes[lateral].tamanhos.first)
    create(:arquivo, arte: arte.arte, molde: molde, client: molde.client, peca: lingua, tamanho: cortes[lingua].tamanhos.first)
    create(:item_pedido, pedido: pedido, arquivo: arte, materia_prima: material).tap do |item|
      item.compor_pecas!(MoldeComposicaoService.call(arte))
      item.grades.create!(tamanho_nome: "30", quantidade: 5)
    end
  end
end

RSpec.configure { |config| config.include ProducaoCalcado }

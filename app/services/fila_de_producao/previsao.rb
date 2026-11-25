class FilaDeProducao
  # The pedido's open stages. motivo: why none can be computed (a draft
  # with pendências).
  Previsao = Struct.new(:pedido, :vezes, :motivo, :se_confirmar, keyword_init: true) do
    # When its last stage ends; nil when some stage has no previsão.
    # A letra held by a missing material leaves it without one too (5b1c3).
    def fim
      return if vezes.empty? || vezes.any? { |vez| vez.fim.nil? || vez.retidas.present? }

      vezes.map(&:fim).max
    end

    def sem_previsao
      self[:motivo] || vezes.find { |vez| vez.fim.nil? }&.motivo || vezes.filter_map(&:motivo_das_retidas).first
    end

    # Every stage done: only the delivery is left.
    def pronta?
      vezes.empty? && self[:motivo].nil?
    end

    # Its next piece of work from the moment on (the block it is in, Q3a).
    def proxima(agora)
      vezes.flat_map(&:trechos).select { |trecho| trecho.fim >= agora }.min_by(&:inicio)
    end

    # Days left between the previsão and the deadline; negative: late.
    def folga(prazo)
      prazo && fim && (prazo - fim.to_date).to_i
    end
  end
end

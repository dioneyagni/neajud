require "rails_helper"

RSpec.describe ArquivosHelper, type: :helper do
  describe "#processamento_label" do
    it "names the queued states and humanizes the rest" do
      expect(%w[pending processing failed].map { |s| helper.processamento_label(s) }).to eq([ "Na fila", "Processando", "Failed" ])
    end
  end
end

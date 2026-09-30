require "rails_helper"

RSpec.describe Produto, type: :model do
  let(:calcado) { build(:produto, grade: (18..46).map(&:to_s)) }

  describe "#trecho_da_grade" do
    it "returns the stretch between two sizes, inclusive" do
      expect(calcado.trecho_da_grade("33", "36")).to eq(%w[33 34 35 36])
      expect(calcado.trecho_da_grade("18", "18")).to eq(%w[18])
    end

    it "is nil for sizes outside the grade or a reversed stretch" do
      expect(calcado.trecho_da_grade("17", "20")).to be_nil
      expect(calcado.trecho_da_grade("36", "33")).to be_nil
    end
  end

  it "needs the grade to be a list of size labels" do
    expect(build(:produto, grade: [])).to be_valid
    produto = build(:produto, grade: [ 18, "" ])
    expect(produto).not_to be_valid
    expect(produto.errors[:grade].first).to include("ordered list of size labels", "[18, \"\"]")
  end
end

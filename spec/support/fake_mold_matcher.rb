# Stands in for MoldMatchService (which shells out to ImageMagick) in specs of
# code that takes a `matcher:` dependency. Returns a fixed tamanho (or nil).
#
# Usage: TamanhoAutoAssignService.call(arte, matcher: FakeMoldMatcher.new(tamanho))
class FakeMoldMatcher
  # How many times it was asked (proves a step ran before the matcher).
  attr_reader :calls

  def initialize(result)
    @result = result
    @calls = 0
  end

  def call(_arte)
    @calls += 1
    @result
  end
end

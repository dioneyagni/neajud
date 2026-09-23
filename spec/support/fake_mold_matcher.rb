# Stands in for MoldMatchService (which shells out to ImageMagick) in specs of
# code that takes a `matcher:` dependency. Returns a fixed tamanho (or nil).
#
# Usage: TamanhoAutoAssignService.call(arte, matcher: FakeMoldMatcher.new(tamanho))
class FakeMoldMatcher
  def initialize(result)
    @result = result
  end

  def call(_arte)
    @result
  end
end

class NullView < FatTerm::View
  attr_reader :renders

  def initialize(id: nil, z: 0)
    super
    @renders = []
  end

  def render(**args)
    @renders << args
  end
end

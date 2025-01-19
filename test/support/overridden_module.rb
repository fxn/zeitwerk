module OverriddenModule
  def new_overridden_module
    new_overriden_of_type(Module)
  end

  def new_overridden_class
    new_overriden_of_type(Class)
  end

  private

  def new_overriden_of_type(type)
    mod = type.new { @real_hash = hash }

    def mod.real_hash = @real_hash
    def mod.name(_) = "overridden name"
    def mod.hash(_) = 42

    mod
  end
end

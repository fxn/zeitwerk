# frozen_string_literal: true

module Zeitwerk::ConstAdded
  def const_added(cname)
    if loader = Zeitwerk::ExplicitNamespace.__loader_for(self, cname)
      loader.on_namespace_loaded(const_get(cname, false))
    end
    super
  end

  Module.prepend(self)
end

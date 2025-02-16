# frozen_string_literal: true

module Zeitwerk::ConstAdded # :nodoc:
  # @sig (Symbol) -> void
  def const_added(cname)
    if loader = Zeitwerk::Registry::ExplicitNamespaces.__loader_for(self, cname)
      namespace = const_get(cname, false)

      unless namespace.is_a?(Module)
        cref = Zeitwerk::Cref.new(self, cname)
        raise Zeitwerk::Error, "#{cref} is expected to be a namespace, should be a class or module (got #{namespace.class})"
      end

      loader.__on_namespace_loaded(Zeitwerk::Cref.new(self, cname), namespace)
    end
    super
  end

  Module.prepend(self)
end

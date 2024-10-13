# frozen_string_literal: true

module Zeitwerk::ConstAdded
  def const_added(cname)
    if loader = Zeitwerk::ExplicitNamespace.__loader_for(self, cname)
      namespace = const_get(cname, false)

      unless namespace.is_a?(Module)
        cref = Zeitwerk::Cref.new(self, cname)
        raise Zeitwerk::Error, "#{cref.path} is expected to be a namespace, should be a class or module (got #{namespace.class})"
      end

      loader.on_namespace_loaded(namespace)
    end
    super
  end

  Module.prepend(self)
end

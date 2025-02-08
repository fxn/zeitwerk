# frozen_string_literal: true

module Zeitwerk
  module Registry # :nodoc: all
    require_relative "registry/explicit_namespaces"
    require_relative "registry/inceptions"

    class << self
      # Keeps track of all loaders. Useful to broadcast messages and to prevent
      # them from being garbage collected.
      #
      # @private
      # @sig Array[Zeitwerk::Loader]
      attr_reader :loaders

      # Registers gem loaders to let `for_gem` be idempotent in case of reload.
      #
      # @private
      # @sig Hash[String, Zeitwerk::Loader]
      attr_reader :gem_loaders_by_root_file

      # Maps absolute paths to the loaders responsible for them.
      #
      # This information is used by our decorated `Kernel#require` to be able to
      # invoke callbacks and autovivify modules.
      #
      # @private
      # @sig Hash[String, Zeitwerk::Loader]
      attr_reader :autoloads

      # Registers a loader.
      #
      # @private
      # @sig (Zeitwerk::Loader) -> void
      def register_loader(loader)
        loaders << loader
      end

      # @private
      # @sig (Zeitwerk::Loader) -> void
      def unregister_loader(loader)
        loaders.delete(loader)
        gem_loaders_by_root_file.delete_if { |_, l| l == loader }
        autoloads.delete_if { |_, l| l == loader }
      end

      # This method returns always a loader, the same instance for the same root
      # file. That is how Zeitwerk::Loader.for_gem is idempotent.
      #
      # @private
      # @sig (String) -> Zeitwerk::Loader
      def loader_for_gem(root_file, namespace:, warn_on_extra_files:)
        gem_loaders_by_root_file[root_file] ||= GemLoader.__new(root_file, namespace: namespace, warn_on_extra_files: warn_on_extra_files)
      end

      # @private
      # @sig (Zeitwerk::Loader, String) -> String
      def register_autoload(loader, abspath)
        autoloads[abspath] = loader
      end

      # @private
      # @sig (String) -> void
      def unregister_autoload(abspath)
        autoloads.delete(abspath)
      end

      # @private
      # @sig (String) -> Zeitwerk::Loader?
      def loader_for(path)
        autoloads[path]
      end

      # @private
      # @sig (Zeitwerk::Loader) -> void
      def on_unload(loader)
        autoloads.delete_if { |_path, object| object == loader }
      end
    end

    @loaders                  = []
    @gem_loaders_by_root_file = {}
    @autoloads                = {}
  end
end

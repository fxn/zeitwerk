# frozen_string_literal: true

module Zeitwerk
  require "zeitwerk/real_mod_name"
  require "zeitwerk/internal"
  require "zeitwerk/cref"
  require "zeitwerk/loader"
  require "zeitwerk/gem_loader"
  require "zeitwerk/registry"
  require "zeitwerk/explicit_namespace"
  require "zeitwerk/inflector"
  require "zeitwerk/gem_inflector"
  require "zeitwerk/null_inflector"
  require "zeitwerk/kernel"
  require "zeitwerk/error"
  require "zeitwerk/version"

  # This is a dangerous method.
  #
  # @experimental
  # @sig () -> void
  def self.with_loader
    loader = Zeitwerk::Loader.new
    yield loader
  ensure
    loader.unregister
  end
end

# frozen_string_literal: true

module Zeitwerk
  class Error < StandardError
  end

  class ReloadingDisabledError < Error
  end

  class UnsynchronizedReloadError < Error
    MESSAGE = <<~EOS
      Unsynchronized reload detected.

        * If you are using a framework that provides reloading, please report this
          error to said framework. Running in single-threaded mode would allow you
          to avoid this problem while it is addressed upstream.

        * If you are invoking Zeitwerk::Loader#reload yourself, maybe as a framework
          developer, please check https://github.com/fxn/zeitwerk#reloading.

      This exception is FATAL. You cannot rescue it and expect things to work.
    EOS

    def initialize(message=MESSAGE)
      super
    end
  end

  class NameError < ::NameError
  end
end

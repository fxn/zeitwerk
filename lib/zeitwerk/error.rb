# frozen_string_literal: true

module Zeitwerk
  class Error < StandardError
  end

  class ReloadingDisabledError < Error
    #: () -> void
    def initialize
      super("can't reload, please call loader.enable_reloading before setup")
    end
  end

  class NameError < ::NameError
  end

  class SetupRequired < Error
    #: () -> void
    def initialize
      super("please, finish your configuration and call Zeitwerk::Loader#setup once all is ready")
    end
  end

  class ConstantPathConflict < Error
    #: (Zeitwerk::Cref, location: String?, conflicting_file: String) -> void
    def initialize(cref, location:, conflicting_file:)
      if location
        super("#{cref} is already defined at #{location}, so #{conflicting_file} is invalid")
      else
        super("#{cref} is already defined, possibly by C code, so #{conflicting_file} is invalid")
      end
    end
  end
end

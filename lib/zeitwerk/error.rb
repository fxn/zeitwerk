module Zeitwerk
  class Error < StandardError
  end

  class ReloadingDisabledError < Error
  end
end

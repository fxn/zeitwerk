require 'fileutils'

module DeleteLoadedFeature
  def delete_loaded_feature(*paths)
    Array(paths).each do |path|
      $LOADED_FEATURES.delete_if do |realpath|
        realpath.end_with?(path)
      end
    end
  end
end

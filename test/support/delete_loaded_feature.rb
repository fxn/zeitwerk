module DeleteLoadedFeature
  def delete_loaded_feature(path)
    $LOADED_FEATURES.delete_if do |realpath|
      realpath.end_with?(path)
    end
  end
end

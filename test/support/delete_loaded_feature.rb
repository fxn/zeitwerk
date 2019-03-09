module DeleteLoadedFeature
  def delete_loaded_feature(path)
    $LOADED_FEATURES.delete(File.realpath(path))
  end
end

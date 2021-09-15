# frozen_string_literal: true

module DeleteLoadedFeature
  def delete_loaded_feature(path)
    $LOADED_FEATURES.delete_if do |abspath|
      abspath.end_with?(path)
    end
  end
end

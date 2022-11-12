# frozen_string_literal: true

require "test_helper"

class TestNestedRootDirectories < LoaderTest
  test "nested root directories do not autovivify modules" do
    files = [["concerns/pricing.rb", "module Pricing; end"]]
    with_setup(files, dirs: %w(. concerns)) do
      assert_raises(NameError) { Concerns }
    end
  end

  test "nested root directories are ignored even if there is a matching file" do
    files = [
      ["hotel.rb", "class Hotel; include GeoLoc; end"],
      ["concerns/geo_loc.rb", "module GeoLoc; end"],
      ["concerns.rb", "module Concerns; end"]
    ]
    with_setup(files, dirs: %w(. concerns)) do
      assert Concerns
      assert Hotel
    end
  end

  test "eager loading handles nested root directories correctly" do
    $airplane_eager_loaded = $locatable_eager_loaded = false
    files = [
      ["airplane.rb", "class Airplane; $airplane_eager_loaded = true; end"],
      ["concerns/locatable.rb", "module Locatable; $locatable_eager_loaded = true; end"]
    ]
    with_setup(files, dirs: %w(. concerns)) do
      loader.eager_load
      assert $airplane_eager_loaded
      assert $locatable_eager_loaded
    end
  end
end

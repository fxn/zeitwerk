require "test_helper"

class TestNestedRootDirectories < LoaderTest
  test "nested root directories do not autovivify modules" do
    files = [["app/models/concerns/pricing.rb", "module Pricing; end"]]
    with_setup(files, dirs: %w(app/models app/models/concerns)) do
      assert_raises(NameError) { Concerns }
    end
  end

  test "nested root directories are ignored even if there is a matching file" do
    files = [
      ["app/models/hotel.rb", "class Hotel; include GeoLoc; end"],
      ["app/models/concerns/geo_loc.rb", "module GeoLoc; end"],
      ["app/models/concerns.rb", "module Concerns; end"]
    ]
    with_setup(files, dirs: %w(app/models app/models/concerns)) do
      assert Concerns
      assert Hotel
    end
  end
end

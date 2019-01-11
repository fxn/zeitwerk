require "test_helper"

class TestExceptions < LoaderTest
  test "raises NameError if the expected constant is not defined" do
    files = [["typo.rb", "TyPo = 1"]]
    with_setup(files) do
      assert_raises(NameError) { Typo }
    end
  end

  test "raises if the file does" do
    files = [["raises.rb", "Raises = 1; raise 'foo'"]]
    with_setup(files, rm: false) do
      assert_raises(RuntimeError, "foo") { Raises }
    end
  end
end

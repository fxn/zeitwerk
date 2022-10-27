# frozen_string_literal: true

require "pathname"
require "test_helper"

class TestEagerLoadDir < LoaderTest
  test "eager loads all files" do
    files = [
      ["x.rb", "X = 1"],
      ["y.rb", "Y = 1"],
      ["m/n/p.rb", "module M::N::P; end"],
      ["m/n/a.rb", "M::N::A = 1"],
      ["m/n/p/q/z.rb", "M::N::P::Q::Z = 1"]
    ]
    with_setup(files) do
      loader.eager_load_dir(".")

      files.each do |file|
        assert required?(file)
      end
    end
  end

  test "shortcircuits if eager loaded" do
    with_setup([]) do
      loader.eager_load

      # Dirty way to prove we shortcircuit.
      def loader.actual_eager_load_dir(*)
        raise
      end

      begin
        loader.eager_load_dir(".")
      rescue
        flunk
      else
        pass
      end
    end
  end

  test "eager loads all files (Pathname)" do
    files = [
      ["x.rb", "X = 1"],
      ["y.rb", "Y = 1"],
      ["m/n/p.rb", "module M::N::P; end"],
      ["m/n/a.rb", "M::N::A = 1"],
      ["m/n/p/q/z.rb", "M::N::P::Q::Z = 1"]
    ]
    with_setup(files) do
      loader.eager_load_dir(Pathname.new("."))
      assert required?(files)
    end
  end

  test "does not eager load excluded directories (same)" do
    files = [["m/x.rb", "M::X = 1"]]
    with_setup(files) do
      loader.do_not_eager_load("m")
      loader.eager_load_dir("m")

      assert !required?(files)
    end
  end

  test "does not eager load excluded files or directories" do
    files = [
      ["x.rb", "X = 1"],
      ["y.rb", "Y = 1"],
      ["m/n.rb", "module M::N; end"],
      ["m/n/a.rb", "M::N::A = 1"]
    ]
    with_setup(files) do
      loader.do_not_eager_load("y.rb")
      loader.do_not_eager_load("m/n")
      loader.eager_load_dir(".")

      assert required?(files[0])
      assert !required?(files[1])
      assert required?(files[2])
      assert !required?(files[3])
    end
  end

  test "does not eager load excluded files or directories (descendants)" do
    files = [
      ["excluded/m/n.rb", "module M::N; end"],
      ["excluded/m/n/a.rb", "M::N::A = 1"]
    ]
    with_setup(files) do
      loader.do_not_eager_load("excluded")
      loader.eager_load_dir(".")

      assert files.none? { |file| required?(file) }
    end
  end

  # This is a file system-based interface.
  test "eager loads explicit namespaces if some subtree is not excluded" do
    files = [
      ["x.rb", "X = 1"],
      ["m/n.rb", "module M::N; end"],
      ["m/n/a.rb", "M::N::A = 1"]
    ]
    with_setup(files) do
      loader.do_not_eager_load("m/n.rb")
      loader.eager_load_dir(".")

      assert required?(files)
    end
  end

  test "does not eager load ignored directories (same)" do
    files = [["m/x.rb", "M::X = 1"]]
    with_files(files) do
      loader.ignore("m")
      loader.setup
      loader.eager_load_dir("m")

      assert !required?(files[0])
    end
  end

  test "does not eager load ignored files or directories" do
    files = [
      ["x.rb", "X = 1"],
      ["y.rb", "Y = 1"],
      ["m/n.rb", "module M::N; end"],
      ["m/n/a.rb", "M::N::A = 1"]
    ]
    with_files(files) do
      loader.push_dir(".")
      loader.ignore("y.rb")
      loader.ignore("m/n")
      loader.setup
      loader.eager_load_dir(".")

      assert required?(files[0])
      assert !required?(files[1])
      assert required?(files[2])
      assert !required?(files[3])
    end
  end

  test "does not eager load ignored files or directories (descendants)" do
    files = [
      ["ignored/m/n.rb", "module M::N; end"],
      ["ignored/m/n/a.rb", "M::N::A = 1"]
    ]
    with_files(files) do
      loader.push_dir(".")
      loader.ignore("ignored")
      loader.setup
      loader.eager_load_dir("ignored/m")

      assert files.none? { |file| required?(file) }
    end
  end

  test "does not eager load shadowed files" do
    files = [
      ["a/x.rb", "X = 1"],
      ["b/x.rb", "SHADOWED"]
    ]
    with_setup(files, dirs: %w(a b)) do
      loader.eager_load_dir("b")

      assert !required?(files[0])
      assert !required?(files[1])
    end
  end

  test "eager loads all files in a subdirectory, ignoring what is above" do
    files = [
      ["x.rb", "X = 1"],
      ["m/k/x.rb"],
      ["m/n/p.rb", "module M::N::P; end"],
      ["m/n/a.rb", "M::N::A = 1"],
      ["m/n/p/q/z.rb", "M::N::P::Q::Z = 1"]
    ]
    with_setup(files) do
      loader.eager_load_dir("m/n")

      assert !required?(files[0])
      assert !required?(files[1])
      assert required?(files[2])
      assert required?(files[3])
      assert required?(files[4])
    end
  end

  test "eager loads all files, ignoring other directories (different namespace)" do
    files = [
      ["a/x.rb", "A::X = 1"],
      ["b/y.rb", "B::Y = 1"],
      ["c/z.rb", "C::Z = 1"]
    ]
    with_setup(files) do
      loader.eager_load_dir("a")

      assert required?(files[0])
      assert !required?(files[1])
      assert !required?(files[2])
    end
  end

  test "eager loads all files, ignoring other directories (same namespace)" do
    files = [
      ["a/m/x.rb", "M::X = 1"],
      ["b/m/y.rb", "M::Y = 1"],
    ]
    with_setup(files, dirs: %w(a b)) do
      loader.eager_load_dir("a/m")

      assert required?(files[0])
      assert !required?(files[1])
    end
  end

  # This is a file system-based interface.
  test "eager loads collapsed directories, ignoring the rest of the namespace" do
    files = [["x.rb", "X = 1"], ["collapsed/y.rb", "Y = 1"]]
    with_files(files) do
      loader.push_dir(".")
      loader.collapse("collapsed")
      loader.setup
      loader.eager_load_dir("collapsed")

      assert !required?(files[0])
      assert required?(files[1])
    end
  end

  test "files under nested root directories are ignored" do
    files = [
      ["x.rb", "X = 1"],
      ["nested_root/y.rb", "Y = 1"]
    ]
    with_setup(files, dirs: %w(. nested_root)) do
      loader.eager_load_dir(".")

      assert required?(files[0])
      assert !required?(files[1])
    end
  end

  test "can be called recursively" do
    $test_loader = loader
    files = [
      ["a/x.rb", "A::X = 1; $test_loader.eager_load_dir('b')"],
      ["b/x.rb", "B::X = 1"]
    ]
    with_setup(files) do
      loader.eager_load_dir("a")

      assert files.all? { |file| required?(file) }
    end
  end

  test "does not prevent reload" do
    $test_loaded_count = 0
    files = [["m/x.rb", "$test_loaded_count += 1; M::X = 1"]]
    with_setup(files) do
      loader.eager_load_dir("m")
      assert_equal 1, $test_loaded_count

      loader.reload

      loader.eager_load_dir("m")
      assert_equal 2, $test_loaded_count
    end
  end

  test "non-Ruby files are ignored" do
    files = [
      ["x.rb", "X = 1"],
      ["README.md", ""],
      ["TODO.txt", ""],
      [".config", ""],
    ]
    with_setup(files) do
      loader.eager_load_dir(".")

      assert required?(files[0])
      assert files[1..-1].none? { | file| required?(file) }
    end
  end

  test "raises Zeitwerk::Error if the argument is not a directory" do
    e = assert_raises(Zeitwerk::Error) { loader.eager_load_dir(__FILE__) }
    assert_equal "#{__FILE__} is not a directory", e.message
  end

  test "raises Zeitwerk::Error if the argument is not a directory, even if eager loaded" do
    loader.eager_load
    e = assert_raises(Zeitwerk::Error) { loader.eager_load_dir(__FILE__) }
    assert_equal "#{__FILE__} is not a directory", e.message
  end
end

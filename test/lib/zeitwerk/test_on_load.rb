# frozen_string_literal: true

require "test_helper"

class TestOnLoad < LoaderTest
  test "on_load checks its argument type" do
    assert_raises(TypeError, "on_load only accepts strings") do
       loader.on_load(:X) {}
    end

    assert_raises(TypeError, "on_load only accepts strings") do
      loader.on_load(Object) {}
    end
  end

  test "on_load is called in the expected order, no namespace" do
    files = [
      ["a.rb", "class A; end"],
      ["b.rb", "class B; end"]
    ]
    with_setup(files) do
      x = []
      loader.on_load("A") { x << 1 }
      loader.on_load("B") { x << 2 }
      loader.on_load("A") { x << 3 }
      loader.on_load("B") { x << 4 }

      assert A
      assert B
      assert_equal [1, 3, 2, 4], x
    end
  end

  test "on_load is called in the expected order, implicit namespace" do
    files = [["x/a.rb", "class X::A; end"]]
    with_setup(files) do
      x = []
      loader.on_load("X") { x << 1 }
      loader.on_load("X::A") { x << 2 }

      assert X::A
      assert_equal [1, 2], x
    end
  end

  test "on_load is called in the expected order, explicit namespace" do
    files = [["x.rb", "module X; end"], ["x/a.rb", "class X::A; end"]]
    with_setup(files) do
      x = []
      loader.on_load("X") { x << 1 }
      loader.on_load("X::A") { x << 2 }

      assert X::A
      assert_equal [1, 2], x
    end
  end

  test "on_load gets the expected arguments passed" do
    with_setup([["x.rb", "X = 1"]]) do
      args = []; loader.on_load("X") { |*a| args = a }

      assert X
      assert_equal 1, args[0]
      assert_abspath "x.rb", args[1]
    end
  end

  test "on_load for :ANY is called for files with the expected arguments" do
    with_setup([["x.rb", "X = 1"]]) do
      args = []; loader.on_load { |*a| args = a }

      assert X
      assert_equal "X", args[0]
      assert_equal 1, args[1]
      assert_abspath "x.rb", args[2]
    end
  end

  test "on_load for :ANY is called for autovivified modules with the expected arguments" do
    with_setup([["x/a.rb", "X::A = 1"]]) do
      args = []; loader.on_load { |*a| args = a }

      assert X
      assert_equal "X", args[0]
      assert_equal X, args[1]
      assert_abspath "x", args[2]
    end
  end

  test "on_load for :ANY is called for namespaced constants with the expected arguments" do
    with_setup([["x/a.rb", "X::A = 1"]]) do
      args = []; loader.on_load { |*a| args = a }

      assert X::A
      assert_equal "X::A", args[0]
      assert_equal X::A, args[1]
      assert_abspath "x/a.rb", args[2]
    end
  end

  test "multiple on_load for :ANY are called in order" do
    with_setup([["x.rb", "X = 1"]]) do
      x = []
      loader.on_load { x << 1 }
      loader.on_load { x << 2 }

      assert X
      assert_equal [1, 2], x
    end
  end

  test "if there are specific and :ANY on_loads, the specific one runs first" do
    with_setup([["x.rb", "X = 1"]]) do
      x = []
      loader.on_load { x << 2 }
      loader.on_load("X") { x << 1 }

      assert X
      assert_equal [1, 2], x
    end
  end

  test "on_load survives reloads" do
    with_setup([["a.rb", "class A; end"]]) do
      x = 0; loader.on_load("A") { x += 1 }

      assert A
      assert_equal 1, x

      loader.reload

      assert A
      assert_equal 2, x
    end
  end

  test "on_load for namespaces gets called with child constants available (implicit)" do
    with_setup([["x/a.rb", "X::A = 1"]]) do
      ok = false
      loader.on_load("X") { ok = X.const_defined?(:A) }

      assert X
      assert ok
    end
  end

  test "on_load for namespaces gets called with child constants available (explicit)" do
    with_setup([["x.rb", "module X; end"], ["x/a.rb", "X::A = 1"]]) do
      ok = false
      loader.on_load("X") { ok = X.const_defined?(:A) }

      assert X
      assert ok
    end
  end

  test "on_load :ANY for namespaces gets called with child constants available (implicit)" do
    with_setup([["x/a.rb", "X::A = 1"]]) do
      ok = false
      loader.on_load { |cpath| ok = X.const_defined?(:A) if cpath == "X" }

      assert X
      assert ok
    end
  end

  test "on_load :ANY for namespaces gets called with child constants available (explicit)" do
    with_setup([["x.rb", "module X; end"], ["x/a.rb", "X::A = 1"]]) do
      ok = false
      loader.on_load { |cpath| ok = X.const_defined?(:A) if cpath == "X" }

      assert X
      assert ok
    end
  end

  test "if reloading is disabled, we deplete the hash (performance test)" do
    on_teardown do
      remove_const :A
      delete_loaded_feature "a.rb"
    end

    with_files([["a.rb", "class A; end"]]) do
      loader = new_loader(dirs: ".", enable_reloading: false, setup: false)
      x = 0; loader.on_load("A") { x = 1 }
      loader.setup

      assert !loader.on_load_callbacks.empty?
      assert A
      assert_equal 1, x
      assert loader.on_load_callbacks.empty?
    end
  end
end

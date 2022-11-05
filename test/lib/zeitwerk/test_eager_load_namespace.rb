require "test_helper"

class TestEagerLoadNamespaceWithObjectRootNamespace < LoaderTest
  test "eader loads everything" do
    files = [["x.rb", "X = 1"], ["m/x.rb", "M::X = 1"]]
    with_setup(files) do
      loader.eager_load_namespace(Object)

      assert required?(files)
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
        loader.eager_load_namespace(Object)
      rescue
        flunk
      else
        pass
      end
    end
  end

  test "does not assume the namespace has a name" do
    files = [["x.rb", "X = 1"]]
    with_setup(files) do
      loader.eager_load_namespace(Module.new)

      assert !required?(files[0])
    end
  end

  test "eader loads everything (multiple root directories)" do
    files = [
      ["a/x.rb", "X = 1"],
      ["a/m/x.rb", "M::X = 1"],
      ["b/y.rb", "Y = 1"],
      ["b/m/y.rb", "M::Y = 1"]
    ]
    with_setup(files, dirs: %w(a b)) do
      loader.eager_load_namespace(Object)

      assert required?(files)
    end
  end

  test "eader loads everything (nested root directories)" do
    files = [
      ["x.rb", "X = 1"],
      ["m/x.rb", "M::X = 1"],
      ["nested/y.rb", "Y = 1"],
      ["nested/m/y.rb", "M::Y = 1"]
    ]
    with_setup(files, dirs: %w(. nested)) do
      loader.eager_load_namespace(Object)

      assert required?(files)
    end
  end

  test "eager loads a managed namespace" do
    files = [["x.rb", "X = 1"], ["m/x.rb", "M::X = 1"]]
    with_setup(files) do
      loader.eager_load_namespace(M)

      assert !required?(files[0])
      assert required?(files[1])
    end
  end

  test "eager loading a non-managed namespace does not raise" do
    files = [["x.rb", "X = 1"]]
    with_setup(files) do
      loader.eager_load_namespace(self.class)

      assert !required?(files[0])
    end
  end

  test "does not eager load ignored files" do
    files = [["x.rb", "X = 1"], ["y.rb", "Y = 1"]]
    with_files(files) do
      loader.push_dir(".")
      loader.ignore("y.rb")
      loader.setup
      loader.eager_load_namespace(Object)

      assert required?(files[0])
      assert !required?(files[1])
    end
  end

  test "does not eager load shadowed files" do
    files = [["a/x.rb", "X = 1"], ["b/x.rb", "X = 1"]]
    with_setup(files, dirs: %w(a b)) do
      loader.eager_load_namespace(Object)

      assert required?(files[0])
      assert !required?(files[1])
    end
  end

  test "skips root directories which are excluded from eager loading (Object)" do
    files = [["rd1/a.rb", "A = 1"], ["rd2/b.rb", "B = 1"]]
    with_setup(files, dirs: %w(rd1 rd2)) do
      loader.do_not_eager_load("rd1")
      loader.eager_load_namespace(Object)

      assert !required?(files[0])
      assert required?(files[1])
    end
  end

  test "skips directories which are excluded from eager loading (namespace, ancestor)" do
    files = [["rd1/m/a.rb", "M::A = 1"], ["rd2/m/b.rb", "M::B = 1"]]
    with_setup(files, dirs: %w(rd1 rd2)) do
      loader.do_not_eager_load("rd1/m")
      loader.eager_load_namespace(Object)

      assert !required?(files[0])
      assert required?(files[1])
    end
  end

  test "skips directories which are excluded from eager loading (namespace, self)" do
    files = [["rd1/m/a.rb", "M::A = 1"], ["rd2/m/b.rb", "M::B = 1"]]
    with_setup(files, dirs: %w(rd1 rd2)) do
      loader.do_not_eager_load("rd1/m")
      loader.eager_load_namespace(M)

      assert !required?(files[0])
      assert required?(files[1])
    end
  end

  test "skips directories which are excluded from eager loading (namespace, descendant)" do
    files = [["rd1/m/n/a.rb", "M::N::A = 1"], ["rd2/m/n/b.rb", "M::N::B = 1"]]
    with_setup(files, dirs: %w(rd1 rd2)) do
      loader.do_not_eager_load("rd1/m")
      loader.eager_load_namespace(M::N)

      assert !required?(files[0])
      assert required?(files[1])
    end
  end

  test "does not eager load namespaces from other loaders" do
    files = [["a/m/x.rb", "M::X = 1"], ["b/m/y.rb", "M::Y = 1"]]
    with_files(files) do
      loader.push_dir("a")
      loader.setup

      new_loader(dirs: "b").eager_load_namespace(M)

      assert !required?(files[0])
      assert required?(files[1])
    end
  end

  test "raises if the argument is not a class or module object" do
    with_setup([]) do
      e = assert_raises(Zeitwerk::Error) do
        loader.eager_load_namespace(self.class.name)
      end
      assert_equal %Q("#{self.class.name}" is not a class or module object), e.message
    end
  end

  test "raises if the argument is not a class or module object, even if eager loaded" do
    with_setup([]) do
      loader.eager_load
      e = assert_raises(Zeitwerk::Error) do
        loader.eager_load_namespace(self.class.name)
      end
      assert_equal %Q("#{self.class.name}" is not a class or module object), e.message
    end
  end
end

class TestEagerLoadNamespaceWithCustomRootNamespace < LoaderTest
  module CN; end
  ancestors = [Object, self, CN]

  ancestors.each do |ancestor|
    test "eader loads everything #{ancestor}" do
      files = [["x.rb", "#{CN}::X = 1"], ["m/x.rb", "#{CN}::M::X = 1"]]
      with_setup(files, namespace: CN) do
        loader.eager_load_namespace(ancestor)

        assert required?(files)
      end
    end

    test "eader loads everything (multiple root directories) #{ancestor}" do
      files = [
        ["a/x.rb", "#{CN}::X = 1"],
        ["a/m/x.rb", "#{CN}::M::X = 1"],
        ["b/y.rb", "#{CN}::Y = 1"],
        ["b/m/y.rb", "#{CN}::M::Y = 1"]
      ]
      with_setup(files, dirs: %w(a b), namespace: CN) do
        loader.eager_load_namespace(ancestor)

        assert required?(files)
      end
    end

    test "eader loads everything (nested root directories) #{ancestor}" do
      files = [
        ["x.rb", "#{CN}::X = 1"],
        ["m/x.rb", "#{CN}::M::X = 1"],
        ["nested/y.rb", "#{CN}::Y = 1"],
        ["nested/m/y.rb", "#{CN}::M::Y = 1"]
      ]
      with_setup(files, dirs: %w(. nested), namespace: CN) do
        loader.eager_load_namespace(ancestor)

        assert required?(files)
      end
    end

    test "eader loads everything (nested root directories, different namespaces 1) #{ancestor}" do
      files = [
        ["x.rb", "#{CN}::X = 1"],
        ["m/x.rb", "#{CN}::M::X = 1"],
        ["nested/y.rb", "Y = 1"],
        ["nested/m/y.rb", "M::Y = 1"]
      ]
      with_files(files) do
        loader.push_dir(".", namespace: CN)
        loader.push_dir("nested")
        loader.setup
        loader.eager_load_namespace(ancestor)

        if ancestor.equal?(Object)
          assert required?(files)
        else
          assert required?(files[0..1])
          assert !required?(files[2])
          assert !required?(files[3])
        end
      end
    end

    test "eader loads everything (nested root directories, different namespaces 2) #{ancestor}" do
      files = [
        ["x.rb", "X = 1"],
        ["m/x.rb", "M::X = 1"],
        ["nested/y.rb", "#{CN}::Y = 1"],
        ["nested/m/y.rb", "#{CN}::M::Y = 1"]
      ]
      with_files(files) do
        loader.push_dir(".")
        loader.push_dir("nested", namespace: CN)
        loader.setup
        loader.eager_load_namespace(ancestor)

        if ancestor.equal?(Object)
          assert required?(files)
        else
          assert !required?(files[0])
          assert !required?(files[1])
          assert required?(files[2..3])
        end
      end
    end
  end

  test "does not assume the namespace has a name" do
    files = [["x.rb", "X = 1"]]
    with_setup(files, namespace: CN) do
      loader.eager_load_namespace(Module.new)

      assert !required?(files[0])
    end
  end

  test "eager loads a managed namespace" do
    files = [["x.rb", "#{CN}::X = 1"], ["m/x.rb", "#{CN}::M::X = 1"]]
    with_setup(files, namespace: CN) do
      loader.eager_load_namespace(CN::M)

      assert !required?(files[0])
      assert required?(files[1])
    end
  end

  test "eager loading a non-managed namespace does not raise" do
    files = [["x.rb", "#{CN}::X = 1"]]
    with_setup(files, namespace: CN) do
      loader.eager_load_namespace(String)

      assert !required?(files[0])
    end
  end

  test "does not eager load ignored files" do
    files = [["x.rb", "#{CN}::X = 1"], ["y.rb", "#{CN}::Y = 1"]]
    with_files(files) do
      loader.push_dir(".", namespace: CN)
      loader.ignore("y.rb")
      loader.setup
      loader.eager_load_namespace(CN)

      assert required?(files[0])
      assert !required?(files[1])
    end
  end

  test "does not eager load shadowed files" do
    files = [["a/x.rb", "#{CN}::X = 1"], ["b/x.rb", "#{CN}::X = 1"]]
    with_setup(files, dirs: %w(a b), namespace: CN) do
      loader.eager_load_namespace(CN)

      assert required?(files[0])
      assert !required?(files[1])
    end
  end

  test "skips root directories which are excluded from eager loading (Object)" do
    files = [["rd1/a.rb", "#{CN}::A = 1"], ["rd2/b.rb", "#{CN}::B = 1"]]
    with_setup(files, dirs: %w(rd1 rd2), namespace: CN) do
      loader.do_not_eager_load("rd1")
      loader.eager_load_namespace(Object)

      assert !required?(files[0])
      assert required?(files[1])
    end
  end

  test "skips root directories which are excluded from eager loading (self)" do
    files = [["rd1/a.rb", "#{CN}::A = 1"], ["rd2/b.rb", "#{CN}::B = 1"]]
    with_setup(files, dirs: %w(rd1 rd2), namespace: CN) do
      loader.do_not_eager_load("rd1")
      loader.eager_load_namespace(CN)

      assert !required?(files[0])
      assert required?(files[1])
    end
  end

  test "skips directories which are excluded from eager loading (namespace, ancestor)" do
    files = [["rd1/m/a.rb", "#{CN}::M::A = 1"], ["rd2/m/b.rb", "#{CN}::M::B = 1"]]
    with_setup(files, dirs: %w(rd1 rd2), namespace: CN) do
      loader.do_not_eager_load("rd1/m")
      loader.eager_load_namespace(Object)

      assert !required?(files[0])
      assert required?(files[1])
    end
  end

  test "skips directories which are excluded from eager loading (namespace, self)" do
    files = [["rd1/m/a.rb", "#{CN}::M::A = 1"], ["rd2/m/b.rb", "#{CN}::M::B = 1"]]
    with_setup(files, dirs: %w(rd1 rd2), namespace: CN) do
      loader.do_not_eager_load("rd1/m")
      loader.eager_load_namespace(CN::M)

      assert !required?(files[0])
      assert required?(files[1])
    end
  end

  test "skips directories which are excluded from eager loading (namespace, descendant)" do
    files = [["rd1/m/n/a.rb", "#{CN}::M::N::A = 1"], ["rd2/m/n/b.rb", "#{CN}::M::N::B = 1"]]
    with_setup(files, dirs: %w(rd1 rd2), namespace: CN) do
      loader.do_not_eager_load("rd1/m")
      loader.eager_load_namespace(CN::M::N)

      assert !required?(files[0])
      assert required?(files[1])
    end
  end

  test "does not eager load namespaces from other loaders" do
    files = [["a/m/x.rb", "#{CN}::M::X = 1"], ["b/m/y.rb", "#{CN}::M::Y = 1"]]
    with_files(files) do
      loader.push_dir("a", namespace: CN)
      loader.setup

      new_loader(dirs: "b", namespace: CN).eager_load_namespace(CN::M)

      assert !required?(files[0])
      assert required?(files[1])
    end
  end

  test "raises if called before setup" do
    assert_raises(Zeitwerk::SetupRequired) do
      loader.eager_load_namespace(self.class)
    end
  end

  test "the class method broadcasts the call to all registered loaders" do
    files = [
      ["a/m/x.rb", "M::X = 1"],
      ["a/x.rb", "X = 1"],
      ["b/m/y.rb", "M::Y = 1"],
      ["b/y.rb", "Y = 1"],
      ["c/z.rb", "Z = 1"],
    ]
    with_files(files) do
      new_loader(dirs: "a")
      new_loader(dirs: "b")
      new_loader(dirs: "c")

      Zeitwerk::Loader.eager_load_namespace(M)

      assert required?(files[0])
      assert !required?(files[1])

      assert required?(files[2])
      assert !required?(files[3])

      assert !required?(files[4])
    end
  end

  test "the class method skips loaders that are not ready" do
    files = [["m/x.rb", "M::X = 1"]]
    with_setup(files) do
      new_loader(setup: false) # should be skipped
      Zeitwerk::Loader.eager_load_namespace(M)
      assert required?(files)
    end
  end
end

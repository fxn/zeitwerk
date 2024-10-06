# frozen_string_literal: true

require "test_helper"

class TestExplicitNamespace < LoaderTest
  module Namespace; end

  test "explicit namespaces are loaded correctly (directory first, Object)" do
    files = [
      ["hotel.rb", "class Hotel; X = 1; end"],
      ["hotel/pricing.rb", "class Hotel::Pricing; end"]
    ]
    with_setup(files) do
      assert_kind_of Class, Hotel
      assert Hotel::X
      assert Hotel::Pricing
    end
  end

  test "explicit namespaces are loaded correctly (directory first, Namespace)" do
    files = [
      ["hotel.rb", "class #{Namespace}::Hotel; X = 1; end"],
      ["hotel/pricing.rb", "class #{Namespace}::Hotel::Pricing; end"]
    ]
    with_setup(files, namespace: Namespace) do
      assert_kind_of Class, Namespace::Hotel
      assert Namespace::Hotel::X
      assert Namespace::Hotel::Pricing
    end
  end

  test "explicit namespaces are loaded correctly (file first, Object)" do
    files = [
      ["rd1/hotel.rb", "class Hotel; X = 1; end"],
      ["rd2/hotel/pricing.rb", "class Hotel::Pricing; end"]
    ]
    with_setup(files) do
      assert_kind_of Class, Hotel
      assert Hotel::X
      assert Hotel::Pricing
    end
  end

  test "explicit namespaces are loaded correctly (file first, Namespace)" do
    files = [
      ["rd1/hotel.rb", "class #{Namespace}::Hotel; X = 1; end"],
      ["rd2/hotel/pricing.rb", "class #{Namespace}::Hotel::Pricing; end"]
    ]
    with_setup(files, namespace: Namespace) do
      assert_kind_of Class, Namespace::Hotel
      assert Namespace::Hotel::X
      assert Namespace::Hotel::Pricing
    end
  end

  test "explicit namespaces defined with an explicit constant assignment are loaded correctly" do
    files = [
      ["hotel.rb", "Hotel = Class.new; Hotel::X = 1"],
      ["hotel/pricing.rb", "class Hotel::Pricing; end"]
    ]
    with_setup(files) do
      assert_kind_of Class, Hotel
      assert Hotel::X
      assert Hotel::Pricing
    end
  end

  test "explicit namespaces are loaded correctly even if #name is overridden" do
    files = [
      ["hotel.rb", <<~RUBY],
        class Hotel
          def self.name
            "X"
          end
        end
      RUBY
      ["hotel/pricing.rb", "class Hotel::Pricing; end"]
    ]
    with_setup(files) do
      assert Hotel::Pricing
    end
  end

  test "explicit namespaces managed by different instances" do
    files = [
      ["a/m.rb", "module M; end"], ["a/m/n.rb", "M::N = true"],
      ["b/x.rb", "module X; end"], ["b/x/y.rb", "X::Y = true"],
    ]
    with_files(files) do
      new_loader(dirs: "a")
      new_loader(dirs: "b")

      assert M::N
      assert X::Y
    end
  end

  test "autoloads are set correctly, even if there are autoloads for the same cname in the superclass" do
    files = [
      ["a.rb", "class A; end"],
      ["a/x.rb", "A::X = :A"],
      ["b.rb", "class B < A; end"],
      ["b/x.rb", "B::X = :B"]
    ]
    with_setup(files) do
      assert_kind_of Class, A
      assert_kind_of Class, B
      assert_equal :B, B::X
    end
  end

  test "autoloads are set correctly, even if there are autoloads for the same cname in a module prepended to the superclass" do
    files = [
      ["m/x.rb", "M::X = :M"],
      ["a.rb", "class A; prepend M; end"],
      ["b.rb", "class B < A; end"],
      ["b/x.rb", "B::X = :B"]
    ]
    with_setup(files) do
      assert_kind_of Class, A
      assert_kind_of Class, B
      assert_equal :B, B::X
    end
  end

  test "autoloads are set correctly, even if there are autoloads for the same cname in other ancestors" do
    files = [
      ["m/x.rb", "M::X = :M"],
      ["a.rb", "class A; include M; end"],
      ["b.rb", "class B < A; end"],
      ["b/x.rb", "B::X = :B"]
    ]
    with_setup(files) do
      assert_kind_of Class, A
      assert_kind_of Class, B
      assert_equal :B, B::X
    end
  end

  test "namespace promotion updates the registry" do
    # We use two root directories to make sure the loader visits the implicit
    # rd1/m first, and the explicit rd2/m.rb after it.
    files = [
      ["rd1/m/x.rb", "M::X = true"],
      ["rd2/m.rb", "module M; end"]
    ]
    with_setup(files) do
      assert_nil Zeitwerk::Registry.loader_for(File.expand_path("rd1/m"))
      assert_same loader, Zeitwerk::Registry.loader_for(File.expand_path("rd2/m.rb"))
    end
  end

  test "non-hashable explicit namespaces are supported" do
    files = [
      ["m.rb", <<~EOS],
        module M
          # This method is overridden with a different arity. Therefore, M is
          # not hashable. See https://github.com/fxn/zeitwerk/issues/188.
          def self.hash(_)
          end
        end
      EOS
      ["m/x.rb", "M::X = true"]
    ]
    with_setup(files) do
      assert M::X
    end
  end
end

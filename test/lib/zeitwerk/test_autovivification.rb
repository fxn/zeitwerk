# frozen_string_literal: true

require "test_helper"

class TestAutovivification < LoaderTest
  module Namespace; end

  test "autoloads a simple constant in an autovivified module (Object)" do
    files = [["admin/x.rb", "Admin::X = true"]]
    with_setup(files) do
      assert_kind_of Module, Admin
      assert Admin::X
    end
  end

  test "autoloads a simple constant in an autovivified module (Namespace)" do
    files = [["admin/x.rb", "#{Namespace}::Admin::X = true"]]
    with_setup(files, namespace: Namespace) do
      assert_kind_of Module, Namespace::Admin
      assert Namespace::Admin::X
    end
  end

  test "autovivifies several levels in a row (Object)" do
    files = [["foo/bar/baz/woo.rb", "Foo::Bar::Baz::Woo = true"]]
    with_setup(files) do
      assert Foo::Bar::Baz::Woo
    end
  end

  test "autovivifies several levels in a row (Namespace)" do
    files = [["foo/bar/baz/woo.rb", "#{Namespace}::Foo::Bar::Baz::Woo = true"]]
    with_setup(files, namespace: Namespace) do
      assert Namespace::Foo::Bar::Baz::Woo
    end
  end

  test "autoloads several constants from the same namespace (Object)" do
    files = [
      ["rd1/admin/hotel.rb", "class Admin::Hotel; end"],
      ["rd2/admin/hotels_controller.rb", "class Admin::HotelsController; end"]
    ]
    with_setup(files) do
      assert Admin::Hotel
      assert Admin::HotelsController
    end
  end

  test "autoloads several constants from the same namespace (Namespace)" do
    files = [
      ["rd1/admin/hotel.rb", "class #{Namespace}::Admin::Hotel; end"],
      ["rd2/admin/hotels_controller.rb", "class #{Namespace}::Admin::HotelsController; end"]
    ]
    with_setup(files, namespace: Namespace) do
      assert Namespace::Admin::Hotel
      assert Namespace::Admin::HotelsController
    end
  end

  test "autovivification is synchronized" do
    $test_admin_const_set_queue = Queue.new

    files = [["admin/v2/user.rb", "class Admin::V2::User; end"]]
    with_setup(files) do
      assert Admin

      def Admin.const_set(cname, mod)
        $test_admin_const_set_queue << true
        sleep 0.5
        super
      end

      concurrent_autovivifications = [
        Thread.new {
          Admin::V2
        },
        Thread.new {
          $test_admin_const_set_queue.pop()
          Admin::V2
        }
      ]

      concurrent_autovivifications.each(&:join)

      assert $test_admin_const_set_queue.empty?
    end
  end

  test "defines no namespace for empty directories" do
    with_files([]) do
      FileUtils.mkdir("foo")
      loader.push_dir(".")
      loader.setup
      assert !Object.autoload?(:Foo)
    end
  end

  test "defines no namespace for empty directories (recursively)" do
    with_files([]) do
      FileUtils.mkdir_p("foo/bar/baz")
      loader.push_dir(".")
      loader.setup
      assert !Object.autoload?(:Foo)
    end
  end

  test "defines no namespace for directories whose files are all non-Ruby" do
    with_setup([["tasks/newsletter.rake", ""], ["assets/.keep", ""]]) do
      assert !Object.autoload?(:Tasks)
      assert !Object.autoload?(:Assets)
    end
  end

  test "defines no namespace for directories whose files are all non-Ruby (recursively)" do
    with_setup([["tasks/product/newsletter.rake", ""], ["assets/css/.keep", ""]]) do
      assert !Object.autoload?(:Tasks)
      assert !Object.autoload?(:Assets)
    end
  end

  test "defines no namespace for directories whose Ruby files are all ignored" do
    with_setup([["foo/bar/ignored.rb", "IGNORED"]]) do
      assert !Object.autoload?(:Foo)
    end
  end

  test "defines no namespace for directories that have Ruby files below ignored directories" do
    with_setup([["foo/ignored/baz.rb", "IGNORED"]]) do
      assert !Object.autoload?(:Foo)
    end
  end
end

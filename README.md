# Zeitwerk



[![Gem Version](https://img.shields.io/gem/v/zeitwerk.svg?style=for-the-badge)](https://rubygems.org/gems/zeitwerk)
[![Build Status](https://img.shields.io/travis/com/fxn/zeitwerk.svg?style=for-the-badge)](https://travis-ci.com/fxn/zeitwerk)

<!-- TOC -->

- [Zeitwerk](#zeitwerk)
    - [Introduction](#introduction)
    - [Synopsis](#synopsis)
    - [File structure](#file-structure)
        - [Implicit namespaces](#implicit-namespaces)
        - [Explicit namespaces](#explicit-namespaces)
        - [Nested root directories](#nested-root-directories)
    - [Usage](#usage)
        - [Setup](#setup)
        - [Reloading](#reloading)
        - [Eager loading](#eager-loading)
        - [Preloading](#preloading)
        - [Inflection](#inflection)
            - [Zeitwerk::Inflector](#zeitwerkinflector)
            - [Zeitwerk::GemInflector](#zeitwerkgeminflector)
            - [Custom inflector](#custom-inflector)
        - [Logging](#logging)
            - [Loader tag](#loader-tag)
        - [Ignoring parts of the project](#ignoring-parts-of-the-project)
            - [Use case: Files that do not follow the conventions](#use-case-files-that-do-not-follow-the-conventions)
            - [Use case: The adapter pattern](#use-case-the-adapter-pattern)
            - [Use case: Test files mixed with implementation files](#use-case-test-files-mixed-with-implementation-files)
        - [Edge cases](#edge-cases)
    - [Pronunciation](#pronunciation)
    - [Supported Ruby versions](#supported-ruby-versions)
    - [Motivation](#motivation)
    - [Thanks](#thanks)
    - [License](#license)

<!-- /TOC -->

## Introduction

Zeitwerk is an efficient and thread-safe code loader for Ruby.

Given a conventional file structure, Zeitwerk loads your project's classes and modules on demand. You don't need to write `require` calls for your own files, rather, you can streamline your programming knowing that your classes and modules are available everywhere. This feature is efficient, thread-safe, and matches Ruby's semantics for constants.

Zeitwerk issues `require` calls exclusively using absolute file names, so there are no costly file system lookups in `$LOAD_PATH`. Technically, the directories managed by Zeitwerk do not even need to be in `$LOAD_PATH`. Furthermore, by design, Zeitwerk does only one single scan of the project tree, and it descends into subdirectories lazily, only if their namespaces are used.

The library is designed so that each gem and application can have their own loader, independent of each other. Each loader has its own configuration, inflector, and optional logger.

Zeitwerk is also able to reload code, which may be handy for web applications. Coordination is needed to reload in a thread-safe manner. The documentation below explains how to do this.

Finally, in some production setups it may be optimal to eager load all code upfront. Zeitwerk is able to do that too.

## Synopsis

Main interface for gems:

```ruby
# lib/my_gem.rb (main file)

require "zeitwerk"
loader = Zeitwerk::Loader.for_gem
loader.setup # ready!
# loader.eager_load, optionally

module MyGem
  # ...
end
```

Main generic interface:

```ruby
loader = Zeitwerk::Loader.new
loader.push_dir(...)
loader.setup # ready!
```

The `loader` variable can go out of scope. Zeitwerk keeps a registry with all of them, and so the object won't be garbage collected.

Later, you can reload if you want to:

```ruby
loader.reload
```

and you can also eager load all the code:

```ruby
loader.eager_load
```

It is also possible to broadcast `eager_load` to all instances:

```ruby
Zeitwerk::Loader.eager_load_all
```

## File structure

To have a file structure Zeitwerk can work with, just name files and directories after the name of the classes and modules they define:

```
lib/my_gem.rb         -> MyGem
lib/my_gem/foo.rb     -> MyGem::Foo
lib/my_gem/bar_baz.rb -> MyGem::BarBaz
lib/my_gem/woo/zoo.rb -> MyGem::Woo::Zoo
```

Every directory configured with `push_dir` acts as root namespace. There can be several of them. For example, given

```ruby
loader.push_dir(Rails.root.join("app/models"))
loader.push_dir(Rails.root.join("app/controllers"))
```

Zeitwerk understands that their respective files and subdirectories belong to the root namespace:

```
app/models/user.rb                        -> User
app/controllers/admin/users_controller.rb -> Admin::UsersController
```

### Implicit namespaces

Directories without a matching Ruby file get modules autovivified automatically by Zeitwerk. For example, in

```
app/controllers/admin/users_controller.rb -> Admin::UsersController
```

`Admin` is autovivified as a module on demand, you do not need to define an `Admin` class or module in an `admin.rb` file explicitly.

### Explicit namespaces

Classes and modules that act as namespaces can also be explicitly defined, though. For instance, consider

```
app/models/hotel.rb         -> Hotel
app/models/hotel/pricing.rb -> Hotel::Pricing
```

There, `app/models/hotel.rb` defines `Hotel`, and thus Zeitwerk does not autovivify a module.

The classes and modules from the namespace are already available in the body of the class or module defining it:

```ruby
class Hotel < ApplicationRecord
  include Pricing # works
  ...
end
```

An explicit namespace must be managed by one single loader. Loaders that reopen namespaces owned by other projects are responsible for loading their constants before setup.

### Nested root directories

Root directories should not be ideally nested, but Zeitwerk supports them because in Rails, for example, both `app/models` and `app/models/concerns` belong to the autoload paths.

Zeitwerk detects nested root directories, and treats them as roots only. In the example above, `concerns` is not considered to be a namespace below `app/models`. For example, the file:

```
app/models/concerns/geolocatable.rb
```

should define `Geolocatable`, not `Concerns::Geolocatable`.

## Usage

### Setup

Loaders are ready to load code right after calling `setup` on them:

```ruby
loader.setup
```

This method is synchronized and idempotent.

Customization should generally be done before that call. In particular, in the generic interface you may set the root directories from which you want to load files:

```ruby
loader.push_dir(...)
loader.push_dir(...)
loader.setup
```

The loader returned by `Zeitwerk::Loader.for_gem` has the directory of the caller pushed, normally that is the absolute path of `lib`. In that sense, `for_gem` can be used also by projects with a gem structure, even if they are not technically gems. That is, you don't need a gemspec or anything.

Zeitwerk works internally only with absolute paths to avoid costly file searches in `$LOAD_PATH`. Indeed, the root directories do not even need to belong to `$LOAD_PATH`, everything just works by design if they don't.

### Reloading

In order to reload code:

```ruby
loader.reload
```

Generally speaking, reloading is useful while developing running services like web applications. Gems that implement regular libraries, so to speak, won't normally have a use case for reloading.

Reloading removes the currently loaded classes and modules, resets the loader so that it will pick whatever is in the file system now, and runs preloads if there are any.

It is important to highlight that this is an instance method. Don't worry about the project dependencies, their loaders are independent.

In order for reloading to be thread-safe, you need to implement some coordination. For example, a web framework that serves each request with its own thread may have a globally accessible RW lock. When a request comes in, the framework acquires the lock for reading at the beginning, and the code in the framework that calls `loader.reload` needs to acquire the lock for writing.

On reloading, client code has to update anything that would otherwise be storing a stale object. For example, if the routing layer of a web framework stores controller class objects or instances in internal structures, on reload it has to refresh them somehow, possibly reevaluating routes.

### Eager loading

Zeitwerk instances are able to eager load their managed files:

```ruby
loader.eager_load
```

That skips [ignored files and directories](#ignoring-parts-of-the-project), and you can also tell Zeitwerk that certain files or directories are autoloadable, but should not be eager loaded:

```ruby
db_adapters = "#{__dir__}/my_gem/db_adapters"
loader.do_not_eager_load(db_adapters)
loader.setup
loader.eager_load # won't eager load the database adapters
```

Eager loading is synchronized and idempotent.

If you want to eager load yourself and all dependencies using Zeitwerk, you can broadcast the `eager_load` call to all instances:

```ruby
Zeitwerk::Loader.eager_load_all
```

This may be handy in top-level services, like web applications.

Note that thanks to idempotence `Zeitwerk::Loader.eager_load_all` won't eager load twice if any of the instances already eager loaded.

### Preloading

Zeitwerk instances are able to preload files and directories.

```ruby
loader.preload("app/models/videogame.rb")
loader.preload("app/models/book.rb")
```

The call can happen before `setup` (preloads during setup), or after `setup` (preloads on the spot). Each reload preloads too.

This is a feature specifically thought for STIs in Rails, preloading the leafs of a STI tree ensures all classes are known when doing a query.

The example above depicts several calls are supported, but `preload` accepts multiple arguments and arrays of strings as well.

### Inflection

Each individual loader needs an inflector to figure out which constant path would a given file or directory map to. Zeitwerk ships with two basic inflectors.

#### Zeitwerk::Inflector

This is a very basic inflector that converts snake case to camel case:

```
user             -> User
users_controller -> UsersController
html_parser      -> HtmlParser
```

There are no inflection rules or global configuration that can affect this inflector. It is deterministic.

This is the default inflector.

#### Zeitwerk::GemInflector

The loader instantiated behind the scenes by `Zeitwerk::Loader.for_gem` gets assigned by default an inflector that is like the basic one, except it expects `lib/my_gem/version.rb` to define `MyGem::VERSION`.

#### Custom inflector

The inflectors that ship with Zeitwerk are deterministic and simple. But you can configure your own:

```ruby
# frozen_string_literal: true

class MyInflector < Zeitwerk::Inflector
  def camelize(basename, _cpath, _abspath)
    case basename
    when "api"
      "API"
    when "mysql_adapter"
      "MySQLAdapter"
    else
      super
    end
  end
end
```

The first argument, `basename`, is a string with the basename of the file or directory to be inflected. In the case of a file, without extension. The inflector needs to return this basename inflected. Therefore, a simple constant name without colons.

The second argument, `cpath`, is a string with the fully qualified name of the parent constant, e.g. `"SomeNanespace::SubNamespace"`.

The third argument, `abspath`, is a string with the absolute path to the file or directory in case you need it to decide how to inflect the basename.

Then, assign the inflector:

```ruby
loader.inflector = MyInflector.new
```

This needs to be done before calling `setup`.

### Logging

Zeitwerk is silent by default, but you can configure a callable as logger:

```ruby
loader.logger = method(:puts)
loader.logger = ->(msg) { ... }
```

as well as anything that responds to `debug`:

```ruby
loader.logger = Logger.new($stderr)
loader.logger = Rails.logger
```

In both cases, the corresponding methods are going to be passed exactly one argument with the message to be logged.

It is also possible to set a global default this way:

```ruby
Zeitwerk::Loader.default_logger = method(:puts)
```

If there is a logger configured, you'll see traces when autoloads are set, files loaded, and modules autovivified. While reloading, removed autoloads and unloaded objects are also traced.

As a curiosity, if your project has namespaces you'll notice in the traces Zeitwerk sets autoloads for _directories_. That's a technique used to be able to descend into subdirectories on demand, avoiding that way unnecessary tree walks.

#### Loader tag

Loaders have a tag that is printed in traces in order to be able to distinguish them in globally logged activity:

```
Zeitwerk@9fa54b: autoload set for User, to be loaded from ...
```

By default, a random tag like the one above is assigned, but you can change it:

```
loader.tag = "grep_me"
```

The tag of a loader returned by `for_gem` is the basename of the root file without extension:

```
Zeitwerk@my_gem: constant MyGem::Foo loaded from ...
```

### Ignoring parts of the project

Zeitwerk ignores automatically any file or directory whose name starts with a dot, and any files that do not have extension ".rb".

However, sometimes it might still be convenient to tell Zeitwerk to completely ignore some particular Ruby file or directory. That is possible with `ignore`, which accepts an arbitrary number of strings or `Pathname` objects, and also an array of them.

You can ignore file names, directory names, and glob patterns. Glob patterns are expanded on setup and on reload.

Let's see some use cases.

#### Use case: Files that do not follow the conventions

Let's suppose that your gem decorates something in `Kernel`:

```ruby
# lib/my_gem/core_ext/kernel.rb

Kernel.module_eval do
  # ...
end
```

That file does not define a constant path after the path name and you need to tell Zeitwerk:

```ruby
kernel_ext = "#{__dir__}/my_gem/core_ext/kernel.rb"
loader.ignore(kernel_ext)
loader.setup
```

You can also ignore the whole directory:

```ruby
core_ext = "#{__dir__}/my_gem/core_ext"
loader.ignore(core_ext)
loader.setup
```

#### Use case: The adapter pattern

Another use case for ignoring files is the adapter pattern.

Let's imagine your project talks to databases, supports several, and has adapters for each one of them. Those adapters may have top-level `require` calls that load their respective drivers:

```ruby
# my_gem/db_adapters/postgresql.rb
require "pg"
```

but you don't want your users to install them all, only the one they are going to use.

On the other hand, if your code is eager loaded by you or a parent project (with `Zeitwerk::Loader.eager_load_all`), those `require` calls are going to be executed. Ignoring the adapters prevents that:

```ruby
db_adapters = "#{__dir__}/my_gem/db_adapters"
loader.ignore(db_adapters)
loader.setup
```

The chosen adapter, then, has to be loaded by hand somehow:

```ruby
require "my_gem/db_adapters/#{config[:db_adapter]}"
```

#### Use case: Test files mixed with implementation files

There are project layouts that put implementation files and test files together. To ignore the test files, you can use a glob pattern like this:

```ruby
tests = "#{__dir__}/**/*_test.rb"
loader.ignore(tests)
loader.setup
```

### Edge cases

A class or module that acts as a namespace:

```ruby
# trip.rb
class Trip
  include Geolocation
end

# trip/geolocation.rb
module Trip::Geolocation
  ...
end
```

has to be defined with the `class` or `module` keywords, as in the example above.

For technical reasons, raw constant assignment is not supported:

```ruby
# trip.rb
Trip = Class.new { ... }  # NOT SUPPORTED
Trip = Struct.new { ... } # NOT SUPPORTED
```

This only affects explicit namespaces, those idioms work well for any other ordinary class or module.

## Pronunciation

"Zeitwerk" is pronounced [this way](http://share.hashref.com/zeitwerk/zeitwerk_pronunciation.mp3).

## Supported Ruby versions

Zeitwerk works with MRI 2.4.4 and above.

## Motivation

Since `require` has global side-effects, and there is no static way to verify that you have issued the `require` calls for code that your file depends on, in practice it is very easy to forget some. That introduces bugs that depend on the load order. Zeitwerk provides a way to forget about `require` in your own code, just name things following conventions and done.

On the other hand, autoloading in Rails is based on `const_missing`, which lacks fundamental information like the nesting and the resolution algorithm that was being used. Because of that, Rails autoloading is not able to match Ruby's semantics and that introduces a series of gotchas. The original goal of this project was to bring a better autoloading mechanism for Rails 6.

## Thanks

I'd like to thank [@matthewd](https://github.com/matthewd) for the discussions we've had about this topic in the past years, I learned a couple of tricks used in Zeitwerk from him.

Also, would like to thank [@Shopify](https://github.com/Shopify), [@rafaelfranca](https://github.com/rafaelfranca), and [@dylanahsmith](https://github.com/dylanahsmith), for sharing [this PoC](https://github.com/Shopify/autoload_reloader). The technique Zeitwerk uses to support explicit namespaces was copied from that project.

Finally, many thanks to [@schurig](https://github.com/schurig) for recording an [audio file](http://share.hashref.com/zeitwerk/zeitwerk_pronunciation.mp3) with the pronunciation of "Zeitwerk" in perfect German. :100:

## License

Released under the MIT License, Copyright (c) 2019–<i>ω</i> Xavier Noria.

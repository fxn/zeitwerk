# Zeitwerk

[![Gem Version](https://badge.fury.io/rb/zeitwerk.svg)](https://badge.fury.io/rb/zeitwerk)
[![Build Status](https://travis-ci.com/fxn/zeitwerk.svg?branch=master)](https://travis-ci.com/fxn/zeitwerk)

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
        - [Ignoring parts of the project](#ignoring-parts-of-the-project)
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

The library is designed so that each gem and application can have their own loader, independent of each other. Each loader has its own configuration, inflector, and optional logger.

Zeitwerk is also able to reload code, which may be handy for web applications. Coordination is needed to reload in a thread-safe manner. The documentation below explains how to do this.

Finally, in some production setups it may be optimal to eager load all code upfront. Zeitwerk is able to do that too.

## Synopsis

Main interface for gems:

```ruby
# lib/my_gem.rb (main file)

require "zeitwerk"
Zeitwerk::Loader.for_gem.setup # ready!

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

You can tell Zeitwerk not to eager load certain files or directories. For example, let's imagine your project talks to databases and implements an adapter pattern. Maybe adapters have top-level `require` calls that load their respective drivers, but you don't want your users to install them all, only the one they are going to use. Solution: do not eager load those files:

```ruby
db_adapters = File.expand_path("my_gem/db_adapters", __dir__)
loader.do_not_eager_load(db_adapters)
loader.setup
loader.eager_load # won't eager load the database adapters
```

Files and directories excluded from eager loading can still be loaded on demand, so an idiom like this is still possible:

```ruby
db_adapter = Object.const_get("MyGem::DbAdapters::#{config[:db_adapter]}")
```

Please check `Zeitwerk::Loader#ignore` if you want those files or directories to not be even autoloadable.

If you want to eager load yourself and all dependencies using Zeitwerk, you can broadcast the `eager_load` call to all instances:

```ruby
Zeitwerk::Loader.eager_load_all
```

In that case, exclusions are per autoloader, and so will apply to each of them accordingly.

This may be handy in top-level services, like web applications.

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
  def camelize(basename, _abspath)
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

The second argument, `abspath`, is a string with the absolute path to the file or directory in case you need it to decide how to inflect the basename.

Then, assign the inflector:

```ruby
loader.inflector = MyInflector.new
```

This needs to be done before calling `setup`.

### Logging

Zeitwerk is silent by default, but you can configure a callable as logger:

```ruby
loader.logger = method(:puts)
```

If there is a logger configured, the loader is going to print traces when autoloads are set, files loaded, and modules autovivified. While reloading, removed autoloads and unloaded objects are also traced.

If your project has namespaces, you'll notice in the traces Zeitwerk sets autoloads for _directories_. That's a technique used to be able to descend into subdirectories on demand, avoiding that way unnecessary tree walks.

### Ignoring parts of the project

Sometimes it might be convenient to tell Zeitwerk to completely ignore some particular file or directory. For example, let's suppose that your gem decorates something in `Kernel`:

```ruby
# lib/my_gem/core_ext/kernel.rb

Kernel.module_eval do
  # ...
end
```

That file does not follow the conventions and you need to tell Zeitwerk:

```ruby
kernel_ext = File.expand_path("my_gem/core_ext/kernel.rb", __dir__)
loader.ignore(kernel_ext)
loader.setup
```

You can pass several arguments to this method, also an array of strings. And you can call `ignore` multiple times too.

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

"Zeitwerk" is pronounced [this way](https://raw.githubusercontent.com/fxn/zeitwerk/master/extras/zeitwerk_pronunciation.mp3).

## Supported Ruby versions

Zeitwerk works with MRI 2.4.4 and above.

## Motivation

Since `require` has global side-effects, and there is no static way to verify that you have issued the `require` calls for code that your file depends on, in practice it is very easy to forget some. That introduces bugs that depend on the load order. Zeitwerk provides a way to forget about `require` in your own code, just name things following conventions and done.

On the other hand, autoloading in Rails is based on `const_missing`, which lacks fundamental information like the nesting and the resolution algorithm that was being used. Because of that, Rails autoloading is not able to match Ruby's semantics and that introduces a series of gotchas. The original goal of this project was to bring a better autoloading mechanism for Rails 6.

## Thanks

I'd like to thank [@matthewd](https://github.com/matthewd) for the discussions we've had about this topic in the past years, I learned a couple of tricks used in Zeitwerk from him.

Also would like to thank [@Shopify](https://github.com/Shopify), [@rafaelfranca](https://github.com/rafaelfranca), and [@dylanahsmith](https://github.com/dylanahsmith), for sharing [this PoC](https://github.com/Shopify/autoload_reloader). The technique Zeitwerk uses to support explicit namespaces was copied from that project.

## License

Released under the MIT License, Copyright (c) 2019–<i>ω</i> Xavier Noria.

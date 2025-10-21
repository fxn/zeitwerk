# CHANGELOG

## 2.7.3 (20 May 2025)

* The helper `Zeitwerk::Loader#cpath_expected_at` did not work correctly if the
  inflector had logic that relied on the absolute path of the given file or
  directory. This has been fixed.

  This bug was found by [Codex](https://openai.com/codex/).

* Perpetual internal work.

## 2.7.2 (18 February 2025)

* Internal improvements and micro-optimizations.

* Add stable TruffleRuby to CI.

## 2.7.1 (19 October 2024)

* Micro-optimization in a hot path.

* Raises `Zeitwerk::Error` if an autoloaded constant expected to represent a
  namespace does not store a class or module object.

* Adds `truffleruby-head` to CI, except for autoloading thread-safety
  (see why in https://github.com/oracle/truffleruby/issues/2431).

## 2.7.0 (11 October 2024)

* [Explicit namespaces](https://github.com/fxn/zeitwerk#explicit-namespaces) can
  now also be defined using constant assignments.

  While constant assignments like

  ```ruby
  # coordinates.rb

  Coordinates = Data.define(:x, :y)
  ```

  worked for most objects, they did not for classes and modules that were also
  namespaces (i.e., those defined by a file and matching subdirectories). In
  such cases, their child constants could not be autoloaded.

  This limitation has been removed.

* `TracePoint` is no longer used.

* Requires Ruby 3.2 or later.

  Gems that work with previous versions of Zeitwerk also work with this one. If
  they support Ruby versions older than 3.2 they can specify a relaxed version
  constraint for Zeitwerk like "~> 2.6", for example.

  In client projects, Bundler takes the Ruby requirement into account when
  resolving dependencies, so `Gemfile.lock` will get one compatible with the
  Ruby version being used.

## 2.6.18 (2 September 2024)

* Fixes a bug in which projects reopening the main namespace of a gem dependency
  managed by its own Zeitwerk loader could not reload the constants they added
  to that external namespace.

## 2.6.17 (29 July 2024)

* Fix log message when eager loading a directory ends.

## 2.6.16 (15 June 2024)

* Logging prints a message when a directory that was not ignored is skipped
  anyway because it contains no Ruby files.

* Internal refactors.

## 2.6.15 (26 May 2024)

* Internal improvements.

## 2.6.14 (14 May 2024)

* Implements `Zeitwerk::Loader#all_expected_cpaths`, which returns a hash that
  maps the absolute paths of the files and directories managed by the receiver
  to their expected constant paths.

  Please, check its [documentation](https://github.com/fxn/zeitwerk?tab=readme-ov-file#zeitwerkloaderall_expected_cpaths) for further details.

## 2.6.13 (6 February 2024)

* There is a new experimental null inflector that simply returns its input
  unchanged:

  ```ruby
  loader.inflector = Zeitwerk::NullInflector.new
  ```

  Projects using this inflector are expected to define their constants in files
  and directories with names exactly matching them:

  ```
  User.rb       -> User
  HTMLParser.rb -> HTMLParser
  Admin/Role.rb -> Admin::Role
  ```

  Please see its
  [documentation](https://github.com/fxn/zeitwerk#zeitwerknullinflector) for
  further details.

* Documentation improvements.

## 2.6.12 (25 September 2023)

* Maintenance release with some internal polishing.

## 2.6.11 (2 August 2023)

* Let `on_load` callbacks for implicit namespaces autoload other implicit
  namespaces.

## 2.6.10 (30 July 2023)

* Improve validation of the values returned by the inflector's `camelize`.

## 2.6.9 (25 July 2023)

* Given a path as a string or `Pathname` object, `Zeitwerk::Loader#cpath_expected_at`
  returns a string with the corresponding expected constant path.

  Some examples, assuming that `app/models` is a root directory:

  ```ruby
  loader.cpath_expected_at("app/models")                  # => "Object"
  loader.cpath_expected_at("app/models/user.rb")          # => "User"
  loader.cpath_expected_at("app/models/hotel")            # => "Hotel"
  loader.cpath_expected_at("app/models/hotel/billing.rb") # => "Hotel::Billing"
  ```

  This method returns `nil` for some input like ignored files, and may raise
  errors too. Please check its
  [documentation](https://github.com/fxn/zeitwerk#zeitwerkloadercpath_expected_at)
  for further details.

* `Zeitwerk::Loader#load_file` raises with a more informative error if given a
  hidden file or directory.

* `Zeitwerk::Loader#eager_load_dir` does nothing if the argument is a hidden
  file or directory. This is coherent with its existing behavior for eager load
  exclusions and ignored paths. Before, that kind of argument would result in a
  non-deliberate `NameError`.

* Documentation improvements.

## 2.6.8 (28 April 2023)

* The new `Zeitwerk::Loader.for_gem_extension` gives you a loader configured
  according to the conventions of a [gem
  extension](https://guides.rubygems.org/name-your-gem/).

  Please check its
  [documentation](https://github.com/fxn/zeitwerk#for_gem_extension) for further
  details.

## 2.6.7 (10 February 2023)

* Reset module state on `Zeitwerk::NameError`.

  If an autoload is triggered, the file is loaded successfully, but the expected
  constant does not get defined, Ruby resets the state of the module. In
  particular, `autoload?` returns `nil` for that constant name, and `constants`
  does not include the constant name (starting with Ruby 3.1).

  Zeitwerk is more strict, not defining the expected constant is an error
  condition and the loader raises `Zeitwerk::NameError`. But this happens during
  the `require` call and the exception prevents Ruby from doing that cleanup.

  With this change, the parent module is left in a state that makes more sense
  and is consistent with what Ruby does.

* A message is logged if an autoload did not define the expected constant.

  When that happens, `Zeitwerk::NameError` is raised and you normally see the
  exception. But if the error is shallowed, and you are inspecting the logs to
  investigate something, this new message may be helpful.

* By default, `Zeitwerk::Loader#dirs` filters ignored root directories out.
  Please, pass `ignored: true` if you want them included.

  It is very strange to configure a root directory and also ignore it, the edge
  case is supported only for completeness. However, in that case, client code
  listing root directories rarely needs the ignored ones.

* Documentation improvements.

* Enforcement of private interfaces continues with another gradual patch.

## 2.6.6 (8 November 2022)

* The new `eager_load_namespace` had a bug when eager loading certain namespaces
  with collapsed directories. This has been fixed.

## 2.6.5 (6 November 2022)

* Controlled errors in a couple of situations:

  - Attempting to eager load or reload without previously invoking `setup` now
    raises `Zeitwerk::SetupRequired`.

  - The method `Zeitwerk::Loader#push_dir` raises `Zeitwerk::Error` if it gets
    an anonymous custom namespace.

  These should be backwards compatible, because they raise in circumstances that
  didn't work anyway. The goal here is to provide a meaningful error upfront.

* Enforcement of private interfaces continues with another gradual patch.

## 2.6.4 (1 November 2022)

Ruby does not have gem-level visibility, so sometimes you need things to be
`public` for them to be accessible internally. But they do not belong to the
public interface of the gem.

A method that is undocumented and marked as `@private` in the source code is
clearly private API, regardless of its formal Ruby visibility.

This release starts a series of gradual patches in which private interface is
enforced with stricter formal visibility.

## 2.6.3 (31 October 2022)

* `v2.6.2` introduced a regression in the logic that checks whether two loaders
  want to manage the same root directories. It has been fixed.

## 2.6.2 (31 October 2022)

* `Zeitwerk::Loader#load_file` allows you to load an individual Ruby file. Check
  its [documentation](https://github.com/fxn/zeitwerk#loading-individual-files)
  for details.

* `Zeitwerk::Loader#eager_load_dir` allows you to eager load a directory,
  recursively. Check its
  [documentation](https://github.com/fxn/zeitwerk#eager-load-directories) for
  details.

* `Zeitwerk::Loader#eager_load_namespace` allows you to eager a namespace,
  recursively. Namespaces are global, this method loads only what the receiver
  manages from that namespace, if anything. Check its
  [documentation](https://github.com/fxn/zeitwerk#eager-load-namespaces) for
  details.

* `Zeitwerk::Loader.eager_load_namespace` broadcasts `eager_load_namespace` to
  all registered loaders. Check its
  [documentation](https://github.com/fxn/zeitwerk#eager-load-namespaces-shared-by-several-loaders)
  for details.

* Documents [shadowed files](https://github.com/fxn/zeitwerk#shadowed-files).
  They always existed, but were not covered by the documentation.

* Other assorted documentation improvements.

## 2.6.1 (1 October 2022)

* `Zeitwerk::Loader#dirs` allows you to introspect the root directories
  configured in the receiver. Please check its
  [documentation](https://github.com/fxn/zeitwerk#introspection) for details.

## 2.6.0 (13 June 2022)

* Directories are processed in lexicographic order.

  Different file systems may list directories in different order, and with this
  change we ensure that client code eager loads consistently across platforms,
  for example.

* Before this release, subdirectories of root directories always represented
  namespaces (unless ignored or collapsed). From now on, to be considered
  namespaces they also have to contain at least one non-ignored Ruby file with
  extension `.rb`, directly or recursively.

  If you know beforehand a certain directory or directory pattern does not
  represent a namespace, it is intentional and more efficient to tell Zeitwerk
  to [ignore](https://github.com/fxn/zeitwerk#ignoring-parts-of-the-project) it.

  However, if you don't do so and have a directory `tasks` that only contains
  Rake files, arguably that directory is not meant to represent a Ruby module.
  Before, Zeitwerk would define a top-level `Tasks` module after it; now, it
  does not.

  This feature is also handy for projects that have directories with auxiliary
  resources mixed in the project tree in a way that is too dynamic for an ignore
  pattern to be practical. See https://github.com/fxn/zeitwerk/issues/216.

  In the unlikely case that an existing project has an empty directory for the
  sole purpose of defining a totally empty module (no code, and no nested
  classes or modules), such module has now to be defined in a file.

  Directories are scanned again on reloads.

* On setup, loaders created with `Zeitwerk::Loader.for_gem` issue warnings if
  `lib` has extra, non-ignored Ruby files or directories.

  This is motivated by existing gems with directories under `lib` that are not
  meant to define Ruby modules, like directories for Rails generators, for
  instance.

  This warning can be silenced in the unlikely case that the extra stuff is
  actually autoloadable and has to be managed by Zeitwerk.

  Please, check the [documentation](https://github.com/fxn/zeitwerk#for_gem) for
  further details.

  This method returns an instance of a private subclass of `Zeitwerk::Loader`
  now, but you cannot rely on the type, just on the interface.

## 2.5.4 (28 January 2022)

* If a file did not define the expected constant, there was a reload, and there were `on_unload` callbacks, Zeitwerk still tried to access the constant during reload, which raised. This has been corrected.

## 2.5.3 (30 December 2021)

* The change introduced in 2.5.2 implied a performance regression that was particularly dramatic in Ruby 3.1. We'll address [#198](https://github.com/fxn/zeitwerk/issues/198) in a different way.

## 2.5.2 (27 December 2021)

* When `Module#autoload` triggers the autovivification of an implicit namespace, `$LOADED_FEATURES` now gets the corresponding directory pushed. This is just a tweak to Zeitwerk's `Kernel#require` decoration. That way it acts more like the original, and cooperates better with other potential `Kernel#require` wrappers, like Bootsnap's.

## 2.5.1 (20 October 2021)

* Restores support for namespaces that are not hashable. For example namespaces that override the `hash` method with a different arity as shown in [#188](https://github.com/fxn/zeitwerk/issues/188).

## 2.5.0 (20 October 2021)

### Breaking changes

* Requires Ruby 2.5.

* Deletes the long time deprecated preload API. Instead of:

  ```ruby
  loader.preload("app/models/user.rb")
  ```

  just reference the constant on setup:

  ```ruby
  loader.on_setup { User }
  ```

  If you want to eager load a namespace, use the constants API:

  ```ruby
  loader.on_setup do
    Admin.constants(false).each { |cname| Admin.const_get(cname) }
  end
  ```

### Bug fixes

* Fixes a bug in which a certain valid combination of overlapping trees managed by different loaders and ignored directories was mistakenly reported as having conflicting directories.

* Detects external namespaces defined with `Module#autoload`. If your project reopens a 3rd party namespace, Zeitwerk already detected it and did not consider the namespace to be managed by the loader (automatically descends, ignored for reloads, etc.). However, the loader did not do that if the namespace had only an autoload in the 3rd party code yet to be executed. Now it does.

### Callbacks

* Implements `Zeitwerk::Loader#on_setup`, which allows you to configure blocks of code to be executed on setup and on each reload. When the callback is fired, the loader is ready, you can refer to project constants in the block.

  See the [documentation](https://github.com/fxn/zeitwerk#the-on_setup-callback) for further details.

* There is a new catch-all `Zeitwerk::Loader#on_load` that takes no argument and is triggered for all loaded objects:

  ```ruby
  loader.on_load do |cpath, value, abspath|
    # ...
  end
  ```

  Please, remember that if you want to trace the activity of a loader, `Zeitwerk::Loader#log!` logs plenty of information.

  See the [documentation](https://github.com/fxn/zeitwerk#the-on_load-callback) for further details.

* The block of the existing `Zeitwerk::Loader#on_load` receives also the value stored in the constant, and the absolute path to its corresponding file or directory:

  ```ruby
  loader.on_load("Service::NotificationsGateway") do |klass, abspath|
    # ...
  end
  ```

  Remember that blocks can be defined to take less arguments than passed. So this change is backwards compatible. If you had

  ```ruby
  loader.on_load("Service::NotificationsGateway") do
    Service::NotificationsGateway.endpoint = ...
  end
  ```

  That works.

* Implements `Zeitwerk::Loader#on_unload`, which allows you to configure blocks of code to be executed before a certain class or module gets unloaded:

  ```ruby
  loader.on_unload("Country") do |klass, _abspath|
    klass.clear_cache
  end
  ```

  These callbacks are invoked during unloading, which happens in an unspecified order. Therefore, they should not refer to reloadable constants.

  You can also be called for all unloaded objects:

  ```ruby
  loader.on_unload do |cpath, value, abspath|
    # ...
  end
  ```

  Please, remember that if you want to trace the activity of a loader, `Zeitwerk::Loader#log!` logs plenty of information.

  See the [documentation](https://github.com/fxn/zeitwerk/blob/main/README.md#the-on_unload-callback) for further details.

### Assorted

* Performance improvements.

* Documentation improvements.

* The method `Zeitwerk::Loader#eager_load` accepts a `force` flag:

  ```ruby
  loader.eager_load(force: true)
  ```

  If passed, eager load exclusions configured with `do_not_eager_load` are not honoured (but ignored files and directories are).

  This may be handy for test suites that eager load in order to ensure all files define the expected constant.

* Eliminates internal use of `File.realpath`. One visible consequence is that  in logs root dirs are shown as configured if they contain symlinks.

* When an autoloaded file does not define the expected constant, Ruby clears state differently starting with Ruby 3.1. Unloading has been revised to be compatible with both behaviours.

* Logging prints a few new traces.

## 2.4.2 (27 November 2020)

* Implements `Zeitwerk::Loader#on_load`, which allows you to configure blocks of code to be executed after a certain class or module have been loaded:

  ```ruby
  # config/environments/development.rb
  loader.on_load("SomeApiClient") do
    SomeApiClient.endpoint = "https://api.dev"

  # config/environments/production.rb
  loader.on_load("SomeApiClient") do
    SomeApiClient.endpoint = "https://api.prod"
  end
  ```

  See the [documentation](https://github.com/fxn/zeitwerk/blob/main/README.md#the-on_load-callback) for further details.

## 2.4.1 (29 October 2020)

* Use `__send__` instead of `send` internally.

## 2.4.0 (15 July 2020)

* `Zeitwerk::Loader#push_dir` supports an optional `namespace` keyword argument. Pass a class or module object if you want the given root directory to be associated with it instead of `Object`. Said class or module object cannot be reloadable.

* The default inflector is even more performant.

## 2.3.1 (29 June 2020)

* Saves some unnecessary allocations made internally by MRI. See [#125](https://github.com/fxn/zeitwerk/pull/125), by [@casperisfine](https://github.com/casperisfine).

* Documentation improvements.

* Internal code base maintenance.

## 2.3.0 (3 March 2020)

* Adds support for collapsing directories.

    For example, if `booking/actions/create.rb` is meant to define `Booking::Create` because the subdirectory `actions` is there only for organizational purposes, you can tell Zeitwerk with `collapse`:

    ```ruby
    loader.collapse("booking/actions")
    ```

    The method also accepts glob patterns to support standardized project structures:

    ```ruby
    loader.collapse("*/actions")
    ```

    Please check the documentation for more details.

* Eager loading is idempotent, but now you can eager load again after reloading.

## 2.2.2 (29 November 2019)

* `Zeitwerk::NameError#name` has the name of the missing constant now.

## 2.2.1 (1 November 2019)

* Zeitwerk raised `NameError` when a managed file did not define its expected constant. Now, it raises `Zeitwerk::NameError` instead, so it is possible for client code to distinguish that mismatch from a regular `NameError`.

    Regarding backwards compatibility, `Zeitwerk::NameError` is a subclass of `NameError`.

## 2.2.0 (9 October 2019)

* The default inflectors have API to override how to camelize selected basenames:

    ```ruby
    loader.inflector.inflect "mysql_adapter" => "MySQLAdapter"
    ```

    This addresses a common pattern, which is to use the basic inflectors with a few straightforward exceptions typically configured in a hash table or `case` expression. You no longer have to define a custom inflector if that is all you need.

* Documentation improvements.

## 2.1.10 (6 September 2019)

* Raises `Zeitwerk::NameError` with a better error message when a managed file or directory has a name that yields an invalid constant name when inflected. `Zeitwerk::NameError` is a subclass of `NameError`.

## 2.1.9 (16 July 2019)

* Preloading is soft-deprecated. The use case it was thought for is no longer. Please, if you have a legit use case for it, drop me a line.

* Root directory conflict detection among loaders takes ignored directories into account.

* Supports classes and modules with overridden `name` methods.

* Documentation improvements.

## 2.1.8 (29 June 2019)

* Fixes eager loading nested root directories. The new approach in 2.1.7 introduced a regression.

## 2.1.7 (29 June 2019)

* Prevent the inflector from deleting parts un multiword constants whose capitalization is the same. For example, `point_2d` should be inflected as `Point2d`, rather than `Point`. While the inflector is frozen, this seems to be just wrong, and the refinement should be backwards compatible, since those constants were not usable.

* Make eager loading consistent with auto loading with regard to detecting namespaces that do not define the matching constant.

* Documentation improvements.

## 2.1.6 (30 April 2019)

* Fixed: If an eager load exclusion contained an autoload for a namespace also
  present in other branches that had to be eager loaded, they could be skipped.

* `loader.log!` is a convenient shortcut to get traces to `$stdout`.

* Allocates less strings.

## 2.1.5 (24 April 2019)

* Failed autoloads raise `NameError` as always, but with a more user-friendly
  message instead of the original generic one from Ruby.

* Eager loading uses `const_get` now rather than `require`. A file that does not
  define the expected constant could be eager loaded, but not autoloaded, which would be inconsistent. Thanks to @casperisfine for reporting this one and help testing the alternative.

## 2.1.4 (23 April 2019)

* Supports deletion of root directories in disk after they've been configured.

  `push_dir` requires root directories to exist to prevent misconfigurations,
  but after that Zeitwerk no longer assumes they exist. This might be convenient
  if you removed one in a web application while a server was running.

## 2.1.3 (22 April 2019)

* Documentation improvements.
* Internal work.

## 2.1.2 (11 April 2019)

* Calling `reload` with reloading disabled raises `Zeitwerk::ReloadingDisabledError`.

## 2.1.1 (10 April 2019)

* Internal performance work.

## 2.1.0 (9 April 2019)

* `loaded_cpaths` is gone, you can ask if a constant path is going to be unloaded instead with `loader.to_unload?(cpath)`. Thanks to this refinement, Zeitwerk is able to consume even less memory. (Change included in a minor upgrade because the introspection API is not documented, and it still isn't, needs some time to settle down).

## 2.0.0 (7 April 2019)

* Reloading is disabled by default. In order to be able to reload you need to opt-in by calling `loader.enable_reloading` before setup. The motivation for this breaking change is twofold. On one hand, this is a design decision at the interface/usage level that reflects that the majority of use cases for Zeitwerk do not need reloading. On the other hand, if reloading is not enabled, Zeitwerk is able to use less memory. Notably, this is more optimal for large web applications in production.

## 1.4.3 (26 March 2019)

* Faster reload. If you're using `bootsnap`, requires at least version 1.4.2.

## 1.4.2 (23 March 2019)

* Includes an optimization.

## 1.4.1 (23 March 2019)

* Fixes concurrent autovivifications.

## 1.4.0 (19 March 2019)

* Trace point optimization for singleton classes by @casperisfine. See the use case, explanation, and patch in [#24](https://github.com/fxn/zeitwerk/pull/24).

* `Zeitwerk::Loader#do_not_eager_load` provides a way to have autoloadable files and directories that should be skipped when eager loading.

## 1.3.4 (14 March 2019)

* Files shadowed by previous occurrences defining the same constant path were being correctly skipped when autoloading, but not when eager loading. This has been fixed. This mimics what happens when there are two files in `$LOAD_PATH` with the same relative name, only the first one is loaded by `require`.

## 1.3.3 (12 March 2019)

* Bug fix by @casperisfine: If the superclass or one of the ancestors of an explicit namespace `N` has an autoload set for constant `C`, and `n/c.rb` exists, the autoload for `N::C` proper could be missed.

## 1.3.2 (6 March 2019)

* Improved documentation.

* Zeitwerk creates at most one trace point per process, instead of one per loader. This is more performant when there are multiple gems managed by Zeitwerk.

## 1.3.1 (23 February 2019)

* After module vivification, the tracer could trigger one unnecessary autoload walk.

## 1.3.0 (21 February 2019)

* In addition to callables, loggers can now also be any object that responds to `debug`, which accepts one string argument.

## 1.2.0 (14 February 2019)

* Use `pretty_print` in the exception message for conflicting directories.

## 1.2.0.beta (14 February 2019)

* Two different loaders cannot be managing the same files. Now, `Zeitwerk::Loader#push_dir` raises `Zeitwerk::ConflictingDirectory` if it detects a conflict.

## 1.1.0 (14 February 2019)

* New class attribute `Zeitwerk::Loader.default_logger`, inherited by newly instantiated loaders. Default is `nil`.
* Traces include the loader tag in the prefix to easily distinguish them.
* Loaders now have a tag.

## 1.0.0 (12 February 2019)

* Documentation improvements.

## 1.0.0.beta3 (4 February 2019)

* Documentation improvements.
* `Zeitwerk::Loader#ignore` accepts glob patterns.
* New read-only introspection method `Zeitwerk::Loader.all_dirs`.
* New read-only introspection method `Zeitwerk::Loader#dirs`.
* New introspection predicate `Zeitwerk::Loader#loaded?(cpath)`.

## 1.0.0.beta2 (22 January 2019)

* `do_not_eager_load` has been removed, please use `ignore` to opt-out.
* Documentation improvements.
* Pronunciation section in the README, linking to sample audio file.
* All logged messages have a "Zeitwerk:" prefix for easy grepping.
* On reload, the logger also traces constants and autoloads removed.

## 1.0.0.beta (18 January 2019)

* Initial beta release.

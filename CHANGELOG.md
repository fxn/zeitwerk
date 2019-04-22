# CHANGELOG

## 2.1.4 (Unreleased)

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

* Files shadowed by previous occurrences defining the same constant path were being correctly skipped when autoloading, but not when eager loading. This has been fixed. This mimicks what happens when there are two files in `$LOAD_PATH` with the same relative name, only the first one is loaded by `require`.

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

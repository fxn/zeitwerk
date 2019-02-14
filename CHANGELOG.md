# CHANGELOG

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

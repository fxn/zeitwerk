# Project rules

## Notation

It is very important that all the source code uses systematically the following naming conventions.

### Variables for constants

* `cname`: A constant name, for example `:User`. Must be a symbol.
* `cpath`: A constant path, for example `"User"` or `"Hotel::Pricing"`. Must be a string.
* `cref`: A constant reference represented as an array of two elements. The first one a class or module object, and the second one a constant name as a symbol. For example `[Admin, :UsersController]`.

### Variables for paths

You should pick always the most specific option:

* `file`: Absolute path of a file.
* `dir`: Absolute path of a directory.
* `abspath`: Absolute path of a file or directory.
* `realpath`: Absolute real path of a file or directory.

Note that Zeitwerk does not deal with file or directory objects, only with paths. For brevity, we exploit this fact to adopt the convention `file`/`dir` instead of `filename`/`dirname` or somesuch.

## Paths

* The only relative file names allowed in the project come from users. For example, public methods like `push_dir` should understand relative paths.
* As soon as a relative file name comes from outside, it has to be converted to an absolute file name right away.
* Internally, you have to use exclusively absolute file names. In particular, any `autoload` or `require` calls have to be issued using absolute paths to avoid `$LOAD_PATH` walks.
* It is forbidden to do any sort of directory lookups resolving relative file names.
* The only directory walks allowed are the one needed to set autoloads. One pass, and as lazy as possible (do not descend into subdirectories until necessary).
* File and directory names should be kept as entered as much as possible so that logging prints what the user expects. Convert to real paths only in code that needs coordination with `Kernel#require`.

## Types

* All methods should have a documented signature.
* Use the most concise type always. Use a set when a set is the best choice, use `Module` when a class or module object is the natural data type (rather than its name).
* Use always symbols for constant names.
* Use always strings for constant paths.
* Use always strings for paths, not pathnames. Pathnames are only accepted coming from the user, but internally everything is strings.

## Public interface definition

Documented public methods conform the public interface. In particular:

* Public methods tagged as `@private` do not belong to the public interface.
* Undocumented public methods do not belong to the public interface. They are probably exploratory and may change or be deleted without warning. These are private interface in practice.
* Undocumented public methods can be used in the Rails integration. We control both repositories, and Rails usage may help refine the actual public interface.

Any release can change the private interface, including patch releases.

## Documentation

Try to word the documentation in terms of classes, modules, and namespaces. Do that with extra care to avoid introducing leaking metaphors.

We sacrifice there a bit of precision in order to communicate better. Some Ruby programmers do not have a deep understanding of constants, so better avoid being pedantic for didactic purposes. Those in the know understand what the documentation really says.

## Performance

Zeitwerk is infraestructure, should have minimal cost both in speed and memory usage.

Be extra careful, allocate as less as possible, store as less as possible. Use always absolute file names for `autoload` and `require`.

Log always using this pattern:

```ruby
log(message) if logger
```

to avoid unncessary calls, and unnecessary computed values in the message.

Some projects may have hundreds of root directories and hundreds of thousands of files, please remember that.

However, do not write ugly code. Ugly code should be extremely justified in terms of performance. Instead, keep it simple, write simple performant code that reads well and is idiomatic.

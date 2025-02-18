# frozen_string_literal: true

# This class emulates a hash table whose keys are of type Zeitwerk::Cref.
#
# It is a synchronized 2-level hash. The keys of the top one, stored in `@map`,
# are class and module objects, but their hash code is forced to be their object
# IDs (see why below). Then, each one of them stores a hash table keyed on
# constant names as symbols. We finally store the values in those.
#
# For example, if we store values 0, 1, and 2 for the crefs that would
# correspond to `M::X`, `M::Y`, and `N::Z`, the map will look like this:
#
#   { M => { X: 0, :Y => 1 }, N => { Z: 2 } }
#
# This structure is internal, so only the needed interface is implemented.
#
# Why not use tables that map pairs [Module, Symbol] to their values? Because
# class and module objects are not guaranteed to be hashable, the `hash` method
# may have been overridden:
#
#   https://github.com/fxn/zeitwerk/issues/188
#
# We can also use a 1-level hash whose keys are the corresponding class and
# module names. In the example above it would be:
#
#   { "M::X" => 0, "M::Y" => 1, "N::Z" => 2 }
#
# The gem used this approach for several years.
#
# Another option would be to make crefs hashable. I tried with hash code
#
#   real_mod_hash(mod) ^ cname.hash
#
# and the matching eql?, but that was about 1.8x slower.
#
# Finally, I came with this solution which is 1.6x faster than the previous one
# based on class and module names, even being synchronized. Also, client code
# feels natural, since crefs are central objects in Zeitwerk's implementation.
class Zeitwerk::Cref::Map # :nodoc: all
  def initialize
    @map = {}
    @map.compare_by_identity
    @mutex = Mutex.new
  end

  # @sig (Zeitwerk::Cref, V) -> V
  def []=(cref, value)
    @mutex.synchronize do
      cnames = (@map[cref.mod] ||= {})
      cnames[cref.cname] = value
    end
  end

  # @sig (Zeitwerk::Cref) -> top?
  def [](cref)
    @mutex.synchronize do
      @map[cref.mod]&.[](cref.cname)
    end
  end

  # @sig (Zeitwerk::Cref, { () -> V }) -> V
  def get_or_set(cref, &block)
    @mutex.synchronize do
      cnames = (@map[cref.mod] ||= {})
      cnames.fetch(cref.cname) { cnames[cref.cname] = block.call }
    end
  end

  # @sig (Zeitwerk::Cref) -> top?
  def delete(cref)
    delete_mod_cname(cref.mod, cref.cname)
  end

  # Ad-hoc for loader_for, called from const_added. That is a hot path, I prefer
  # to not create a cref in every call, since that is global.
  #
  # @sig (Module, Symbol) -> top?
  def delete_mod_cname(mod, cname)
    @mutex.synchronize do
      if cnames = @map[mod]
        value = cnames.delete(cname)
        @map.delete(mod) if cnames.empty?
        value
      end
    end
  end

  # @sig (top) -> void
  def delete_by_value(value)
    @mutex.synchronize do
      @map.delete_if do |mod, cnames|
        cnames.delete_if { _2 == value }
        cnames.empty?
      end
    end
  end

  # Order of yielded crefs is undefined.
  #
  # @sig () { (Zeitwerk::Cref) -> void } -> void
  def each_key
    @mutex.synchronize do
      @map.each do |mod, cnames|
        cnames.each_key do |cname|
          yield Zeitwerk::Cref.new(mod, cname)
        end
      end
    end
  end

  # @sig () -> void
  def clear
    @mutex.synchronize do
      @map.clear
    end
  end

  # @sig () -> bool
  def empty? # for tests
    @mutex.synchronize do
      @map.empty?
    end
  end
end

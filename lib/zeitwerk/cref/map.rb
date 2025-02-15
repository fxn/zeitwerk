# frozen_string_literal: true

# This class emulates a hash table whose keys are of type Zeitwerk::Cref.
#
# It is a synchronized hash of hashes. The first one, stored in `@map`, is keyed
# on class and module object IDs. Then, each one of them stores a hash table
# keyed on constant names, where we finally store the values.
#
# For example, if we store values 0, 1, and 2 for the crefs that would
# correspond to `M::X`, `M::Y`, and `N::Z`, the map will look like this:
#
#   { M => { X: 0, :Y => 1 }, N => { Z: 2 } }
#
# Why not use simple hash tables of type Hash[Module, Symbol]? Because class and
# module objects are not guaranteed to be hashable, the `hash` method may have
# been overridden:
#
#   https://github.com/fxn/zeitwerk/issues/188
#
# Another option would be to make crefs hashable. I tried with hash code
#
#  real_mod_hash(mod) ^ cname.hash
#
# and the matching eql?, but that was about 1.8x slower than a hash keyed by
# class and module names.
#
# The gem used hashes keyed by class and module names, but that felt like an
# unnecessary dependency on said names, our natural objects are the crefs.
#
# On the other hand, an unsynchronized hash based on constant paths is 1.6x
# slower than this map.
class Zeitwerk::Cref::Map # :nodoc: all
  def initialize
    @map = {}
    @map.compare_by_identity
    @mutex = Mutex.new
  end

  def []=(cref, value)
    @mutex.synchronize do
      cnames = (@map[cref.mod] ||= {})
      cnames[cref.cname] = value
    end
  end

  def [](cref)
    @mutex.synchronize do
      @map[cref.mod]&.[](cref.cname)
    end
  end

  def delete(cref)
    delete_mod_cname(cref.mod, cref.cname)
  end

  # Ad-hoc for loader_for, called from const_added. That is a hot path, I prefer
  # to not create a cref in every call, since that is global.
  def delete_mod_cname(mod, cname)
    @mutex.synchronize do
      if cnames = @map[mod]
        value = cnames.delete(cname)
        @map.delete(mod) if cnames.empty?
        value
      end
    end
  end

  def delete_by_value(value)
    @mutex.synchronize do
      @map.delete_if do |mod, cnames|
        cnames.delete_if { _2 == value }
        cnames.empty?
      end
    end
  end

  # Order is undefined.
  def each_key
    @mutex.synchronize do
      @map.each do |mod, cnames|
        cnames.each_key do |cname|
          yield Zeitwerk::Cref.new(mod, cname)
        end
      end
    end
  end

  def clear
    @mutex.synchronize do
      @map.clear
    end
  end

  def empty?
    @mutex.synchronize do
      @map.empty?
    end
  end
end

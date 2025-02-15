# frozen_string_literal: true

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

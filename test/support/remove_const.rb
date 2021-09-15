# frozen_string_literal: true

module RemoveConst
  def remove_const(cname, from: Object)
    from.send(:remove_const, cname)
  end
end

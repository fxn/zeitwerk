# frozen_string_literal: true

module RemoveConst
  def remove_const(cname, from: Object)
    from.__send__(:remove_const, cname)
  end
end

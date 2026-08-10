module ApplicationHelper
  def suffrages(count)
    count > 1 ? "#{count} suffrages exprimés" : "#{count} suffrage exprimé"
  end
end

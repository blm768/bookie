module ApplicationHelper
  #To do: relocate?
  def options(values, selected = nil)
    text = ""
    values.each_pair do |value, label|
      text << %{<option value="#{value}" }
      text << 'selected="selected"' if selected == value
      text << " />#{label}</option>"
    end
    return text
  end
end

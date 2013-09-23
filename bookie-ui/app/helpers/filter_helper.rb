module FilterHelper
  def filter_for(name, filter_type, values = nil)
    id = nil
    unless values
      id = "filter_prototype_#{name}"
    end

    values ||= []

    render :partial => "shared/filters/#{filter_type}", :locals => {
      :name => name,
      :id => id,
      :values => values
    }
  end
end


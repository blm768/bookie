module FilterHelper
  def filter_for(name, filter_type, values)
    render :partial => 'shared/filter', :locals => {
      :name => name,
      :filter_type => filter_type,
      :values => values
    }
  end

  def filter_prototype_for(name, filter_type)
    render :partial => 'shared/filter_prototype', :locals => {
      :name => name,
      :filter_type => filter_type
    }
  end
end


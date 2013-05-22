function initFilters() {
  var addFilterSelect = $('#add_filter')
  addFilterSelect.change(addFilter)
  
  //If filters have already been created by the server, tie events to them.
  $('.filter_remover').click(function() { $(this).parent().remove() })
  $('.filter').children('input[type=text]').change(function() {
  	//Used when the filter form's submit event is cancelled
    this.blur()
  })

  //If there's a page selector, set it up.
  var pageSelect = $('#select_page')
  if(pageSelect) {
    pageSelect.change(function() {
      $('#filter_form').submit()
    })
  }
}

function addFilter() {
  var select = $('#add_filter')
  if(select.val() == 0) {
    return
  }
  var opt = select.children(':selected')
  select.val(0)
  
  var filters = $('#filters')
  var filter = $('<div/>')
  filter.addClass('filter')
  filter.append(opt.text())
  var remover = $('<div/>')
  remover.addClass('filter_remover')
  remover.click(function() { filter.remove() })
  remover.append('X')
  filter.append(remover)
  //The value attribute is hijacked to store the type of filter parameters.
  var types = opt.val().split(' ')
  for(var i = 0; i < parseInt(opt.val()); ++i) {
    var text = $('<input/>')
    text.attr('type', 'text')
    text.change(function() {
      this.blur()
    })
    filter.append(text)
  }
  filters.append(filter)
}

function removeFilter(filter) {
  filter.remove()
}

function getFilterData() {
  var filters = $('#filters')
  var filterTypes = []
  var filterValues = []
  filters.children('.filter').each(function() {
    var $this = $(this)
    //To do (future): replace $.trim with String.trim() when browser support is sufficient.
    var text = $.trim($($this.contents()[0]).text())
    filterTypes.push(text)
    $this.children('input').each(function() {
      filterValues.push(this.value)
    })
  })
  return [filterTypes, filterValues]
}

function submitFilters() {
  var filterForm = $('#filter_form')
  var filterData = getFilterData()
  var filterTypesInput = $('<input/>')
  filterTypesInput.attr('type', 'hidden')
  filterTypesInput.attr('name', 'filter_types')
  filterTypesInput.val(filterData[0].join(','))
  filterForm.append(filterTypesInput)
  var filterValuesInput = $('<input/>')
  filterValuesInput.attr('type', 'hidden')
  filterValuesInput.attr('name', 'filter_values')
  //To do: prevent commas in the values from causing problems.
  filterValuesInput.val(filterData[1].join(','))
  filterForm.append(filterValuesInput)
  var includeDetails = $('#show_details')
  if(includeDetails.prop('checked')) {
    var pageSelect = $('#select_page')
    if(pageSelect.length > 0) {
      var page = $('<input/>')
      page.attr('type', 'hidden')
      page.attr('name', 'page')
      page.val(Math.max(pageSelect.prop('selectedIndex') + 1, 1))
      filterForm.append(page)
    }
  }
}

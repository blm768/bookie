// vim: ts=2:sw=2:et

function initFilters() {
  var addFilterSelect = $('#add_filter')
  addFilterSelect.change(addFilter)
  
  //If filters have already been created by the server, tie events to them.
  $('.filter_remover').click(function() { removeFilter($(this).parent()) })
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
  if(select.val() == '') {
    return
  }
  var opt = select.children(':selected')
  opt.prop('disabled', true)
  select.val('')
  
  var filters = $('#filters')
  var filter = $('<div/>')
  filter.addClass('filter')
  var type_span = $('<span/>')
  type_span.addClass('filter_type')
  type_span.append(opt.text())
  filter.append(type_span)
  var remover = $('<div/>')
  remover.addClass('filter_remover')
  remover.click(function() { removeFilter(filter) })
  remover.append('X')
  filter.append(remover)
  //The value attribute is hijacked to store the type of filter parameters.
  var types = opt.val().split(' ')
  for(var i = 0; i < types.length; ++i) {
    var type = types[i]
    var input
    switch(type) {
      case 'text':
        input = $('<input/>')
        input.attr('type', 'text')
        break
      default:
        input = $('#select_prototype_' + type).clone()
        input.removeAttr('id')
        break
    }
    input.change(function() {
      this.blur()
    })
    filter.append(input)
  }
  filters.append(filter)
}

function removeFilter(filter) {
  var type = filter.children('.filter_type').text()
  $('#add_filter').children().each(function() {
    var $this = $(this)
    if($this.text() == type) {
      $this.prop('disabled', false)
      return false
    }
  })
  filter.remove()
}

function getFilterData() {
  var filters = $('#filters')
  var filterTypes = []
  var filterValues = []
  filters.children('.filter').each(function() {
    var $this = $(this)
    //To consider: replace $.trim with String.trim() when browser support is sufficient?
    var text = $.trim($($this.contents()[0]).text())
    filterTypes.push(text)
    $this.children(':input').each(function() {
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
  //Prevent commas in the filter values from causing problems
  //by adding a second layer of URI encoding to the values:
  for(var i = 0; i < filterData[1].length; ++i) {
    filterData[1][i] = encodeURIComponent(filterData[1][i])
  }
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


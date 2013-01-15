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
  //The value attribute is hijacked to store the number of filter parameters.
  for(var i = 0; i < parseInt(opt.val()); ++i) {
    var text = $('<input/>')
    text.attr('type', 'text')
    filter.append(text)
  }
  filters.append(filter)
}

function submitFilters() {
  var filters = $('#filters')
  var filterForm = filters.parent()
  var filterTypes = []
  var filterValues = []
  filters.children('.filter').each(function() {
    var $this = $(this)
    //To do (future): replace $.trim with the trim() method when browser support is sufficient.
    var text = $.trim($($this.contents()[0]).text())
    filterTypes.push(text)
    $this.children('input').each(function() {
      filterValues.push(this.value)
    })
  })
  var filterTypesInput = $('<input/>')
  filterTypesInput.attr('type', 'hidden')
  filterTypesInput.attr('name', 'filter_types')
  filterTypesInput.val(filterTypes.join(','))
  filterForm.append(filterTypesInput)
  var filterValuesInput = $('<input/>')
  filterValuesInput.attr('type', 'hidden')
  filterValuesInput.attr('name', 'filter_values')
  //To do: prevent commas in the values from causing problems.
  filterValuesInput.val(filterValues.join(','))
  filterForm.append(filterValuesInput)
  var pageSelect = $('#select_page')
  if(pageSelect.length > 0) {
    var page = $('<input/>')
    page.attr('type', 'hidden')
    page.attr('name', 'page')
    page.val(Math.max(pageSelect.prop('selectedIndex') + 1, 1))
    filterForm.append(page)
  }
}

$(document).ready(function() {
  var addFilterSelect = $('#add_filter')
  //This should be addEventListener(), but Safari doesn't like that. I have no idea why.
  addFilterSelect.change(addFilter)
  var filterForm = addFilterSelect.parent()
  filterForm.submit(submitFilters)
  //If filters have already been created by the server, tie events to their removers.
  $('.filter_remover').click(function() { $(this).parent().remove() })
  var pageSelect = $('#select_page')
  if(pageSelect) {
    pageSelect.change(function() { filterForm.submit() })
  }
})

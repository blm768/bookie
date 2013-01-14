function nextElement(node) {
  var next = node.nextSibling
  while(next && next.nodeType != 1) {
    next = next.nextSibling
  }
  return next
}

var filterMax = 0

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
  //The value attribute is hijacked to store the number of filter parameters.
  for(var i = 0; i < parseInt(opt.val()); ++i) {
    var text = $('<input/>')
    text.attr('type', 'text')
    filter.append(text)
  }
  var remover = $('<div/>')
  remover.addClass('filter_remover')
  remover.click(function() { filter.remove() })
  remover.append('X')
  filter.append(remover)
  filters.append(filter)
  ++filterMax
}

function submitFilters() {
  var filters = $('#filters')
  var filterForm = filters.parent()
  var filterTypes = []
  var filterValues = []
  filters.children('.filter').each(function() {
    var $this = $(this)
    var text = $($this.contents()[0]).text()
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
}

$(document).ready(function() {
  var addFilterSelect = $('#add_filter')
  //This should be addEventListener(), but Safari doesn't like that. I have no idea why.
  addFilterSelect.change(addFilter)
  var filterForm = addFilterSelect.parent()
  filterForm.submit(submitFilters)
})

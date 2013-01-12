function nextElement(node) {
  var next = node.nextSibling
  while(next && next.nodeType != 1) {
    next = next.nextSibling
  }
  return next
}

var filterMax = 0

function forEachFilter(action) {
  var filters = document.getElementById('filters')
  var filter = filters.firstChild
  while(filter && filter.nodeType != 1) {
    filter = filter.nextSibling
  }
  while(filter) {
    action(filter)
    filter = nextElement(filter)
  }
}

function addFilter() {
  var select = document.getElementById('add_filter')
  if(select.selectedIndex == 0) {
    return
  }
  var opt = select.options[select.selectedIndex]
  select.selectedIndex = 0
  
  var filters = document.getElementById('filters')
  var filter = document.createElement('div')
  filter.class = 'filter'
  filter.id = 'filter' + filterMax
  filter.appendChild(document.createTextNode(opt.firstChild.nodeValue))
  var text = document.createElement('input')
  text.type = 'text'
  filter.appendChild(text)
  var remover = document.createElement('div')
  remover.class = 'filter_remover'
  remover.onclick = function() { filters.removeChild(filter) }
  remover.appendChild(document.createTextNode("X"))
  filter.appendChild(remover)
  filters.appendChild(filter)
  ++filterMax
}

function submitFilters() {
  var filters = document.getElementById('filters')
  var filterForm = filters.parentNode
  var filterTypes = []
  var filterValues = []
  forEachFilter(function(filter) {
    var textNode = filter.firstChild
    filterTypes.push(textNode.nodeValue)
    var valueNode = nextElement(textNode)
    while(valueNode && valueNode.tagName == 'input') {
      alert(valueNode.value)
      filterValues.push(valueNode.value)
      valueNode = nextElement(valueNode)
    }
  })
  var filterTypesInput = document.createElement('input')
  filterTypesInput.type = 'hidden'
  filterTypesInput.name = 'filter_types'
  filterTypesInput.value = filterTypes.join(',')
  filterForm.appendChild(filterTypesInput)
  var filterValuesInput = document.createElement('input')
  filterValuesInput.type = 'hidden'
  filterValuesInput.name = 'filter_values'
  //To do: prevent commas in the values from causing problems.
  filterValuesInput.value = filterValues.join(',')
  filterForm.appendChild(filterValuesInput)
}

document.addEventListener('DOMContentLoaded', function() {
  var addFilterSelect = document.getElementById('add_filter')
  //This should be addEventListener(), but Safari doesn't like that. I have no idea why.
  addFilterSelect.onchange = addFilter
  var filterForm = addFilterSelect.parentNode
  filterForm.onsubmit = submitFilters
}, false);

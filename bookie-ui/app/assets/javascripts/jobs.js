function nextElement(node) {
  var next = node.nextSibling
  while(next.nodeType != 1) {
    next = next.nextSibling
  }
  return next
}

//Sets the visibility of a filter's "extra" fields
function setFormExtrasVisibility(filter) {
  var opt = filter.options[filter.selectedIndex]
  var filter_extras = nextElement(filter)
  if(opt.value == 'none') {
    filter_extras.style.display = 'none'
    document.getElementById(filter.id + '_value').value = ''
  } else {
    filter_extras.style.display = 'inline'
  }
}

document.addEventListener('DOMContentLoaded', function() {
  var filter0 = document.getElementById('filter0')
  //This should be addEventListener(), but Safari doesn't like that. I have no idea why.
  filter0.onchange = function() { setFormExtrasVisibility(filter0) }
}, false);
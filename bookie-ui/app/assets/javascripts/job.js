
document.addEventListener('DOMContentLoaded', function() {
  var filter_type = document.getElementById('filter_type')
  function setVisibility() {
    var opt = filter_type.options[filter_type.selectedIndex]
    var filter_extras = document.getElementById('filter_extras')
    if(opt.value == 'none') {
      filter_extras.style.display = 'none'
      document.getElementById('filter_value').value = ''
    } else {
      filter_extras.style.display = 'inline'
    }
  }
  //This should be addEventListener(), but Safari doesn't like that. I have no idea why.
  filter_type.onchange = setVisibility
  setVisibility()
}, false);
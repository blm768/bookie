function addFilter() {
  var select = $('#add_filter')
  if(select.val() == '') {
    return
  }
  var opt = select.children(':selected')
  opt.prop('disabled', true)
  //Reset the displayed option to the default.
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
  filter.append(remover)

  //The value attribute is hijacked to store the type of filter.
  var filter_type = opt.val()
  //Copy the prototype inputs from the hidden div.
  var inputs = $('#filter_prototype_' + filter_type).clone().children()
  inputs.change(function() {
      this.blur()
  })
  filter.append(inputs)

  filters.append(filter)
}

function removeFilter(filter) {
  //Re-enable the correct entry in the "Add filter" select box:
  //TODO: find a cleaner method of doing this?
  var type = $.trim(filter.children('.filter_type').text())
  $('#add_filter').children().each(function() {
    var $this = $(this)
    if($.trim($this.text()) == type) {
      $this.prop('disabled', false)
      return false
    }
  })
  filter.remove()
}

function submitFilters() {
  var filterForm = $('#filter_form')

  var includeDetails = $('#show_details')
  if(includeDetails.prop('checked')) {
    //Process the page selector if it exists.
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

$(document).one("ready", function() {
	var filterForm = $('#filter_form')
	filterForm.submit(submitFilters)

  $('#add_filter').change(addFilter)

  //If filters already exist, tie events to them.
  //TODO: factor this out into a common function.
  $('.filter_remover').click(function() { removeFilter($(this).parent()) })
  $('.filter').children('input[type=text]').change(function() {
    //Used when the filter form's submit event is cancelled (such as on the Graphs page)
    this.blur()
  })

  //If there's a page selector, set it up.
  var pageSelect = $('#select_page')
  if(pageSelect) {
    pageSelect.change(function() {
      $('#filter_form').submit()
    })
  }
})

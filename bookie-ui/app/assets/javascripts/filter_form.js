// vim: sw=2:ts=2:et

//Prepares the filter form to be used as a standard form

$(document).ready(function() {
	initFilters()
	var filterForm = $('#filters').parent()
	filterForm.submit(submitFilters)
})


// vim: sw=2:ts=2:et

//Prepares the filter form to be used as a standard form
//TODO: move to filter.js?

$(document).ready(function() {
	//TODO: use UJS?
	initFilters()
	var filterForm = $('#filter_form')
	filterForm.submit(submitFilters)
})

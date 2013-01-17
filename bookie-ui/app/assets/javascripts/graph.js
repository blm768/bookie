//To do: fix?
function pad(str, len) {
  while(str.length < len) {
    str = '0' + str
  }
  return str
}

function dateToString(date) {
  return pad(date.getFullYear(), 4) + '-' + pad(date.getMonth() + 1, 2) + '-' + pad(date.getDate(), 2)
}

date_start = undefined
date_end = undefined

function initRange() {
  var inputs = $('#date_range .date_box').children()
  
  inputs.change(function() {
    var complete = true
    inputs.filter('input').each(function() {
      if(this.value.length == 0) {
        complete = false
        return false
      }
    })
    if(complete) {
      date_start = new Date(
        parseInt($('#year_start').val()), 
        parseInt($('#month_start').val() - 1),
        parseInt($('#day_start').val())
      )
      date_end = new Date(
        parseInt($('#year_end').val()), 
        parseInt($('#month_end').val() - 1),
        parseInt($('#day_end').val())
      )
      onFilterChange()
    }
  })  
}

function getSummary(day, params) {
  var start = dateToString(day)
  var next_day = new Date(day.valueOf())
  next_day.setDate(next_day.getDate() + 1)
  var end = dateToString(next_day)
  
  var queryParams = ['filter_types=' + params[0].join(','), 'filter_values=' + params[1].join(',')]
  if(params[0].length > 0) {
    queryParams[0] += ','
  }
  if(params[1].length > 0) {
    queryParams[1] += ','
  }
  queryParams[0] += 'Time'
  queryParams[1] += start + ',' + end
  $.getJSON('jobs.json?' + queryParams.join('&'), function(data) {
    addPoint(day, data)
  })
}

dates = []
counts = []

function addPoint(date, summary) {
  counts.push(summary['Count'])
  //If we have all the points, draw them.
  if(counts.length == dates.length) {
    drawPoints()
  }
}

function resetPoints() {
  dates = []
  counts = []
}

function drawPoints() {
  $('#content').append(counts.toString())
}

function onFilterChange() {
  resetPoints()
  if(!date_start || !date_end) {
    return
  }
  
  var params = getFilterData()
  
  var day = new Date(date_start.valueOf())
  while(day < date_end) {
    getSummary(day, params)
    dates.push(day)
    day.setDate(day.getDate() + 1)
  }
}

$(document).ready(function() {
  initFilters();
  initRange();
  var filterForm = $('#filters').parent()
  onFilterChange()
})

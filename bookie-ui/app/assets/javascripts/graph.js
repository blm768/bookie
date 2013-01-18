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

var MSECS_PER_DAY = 24 * 3600 * 1000

var date_start, date_end

function initRange() {
  var dateBoxes = $('#date_range .date_box')
  
  var date = new Date(Date.now())
  date.setDate(1)
  
  dateBoxes.children().filter('.day').val(1)
  
  dateBoxes.each(function() {
    var $this = $(this)
    var inputs = $this.children()
    inputs.filter('.month').val(date.getMonth())
    inputs.filter('.year').val(date.getFullYear())
    date.setMonth(date.getMonth() + 1)
  })
  
  $('#set_date_range').click(function() {
    var inputs = dateBoxes.children()
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
        parseInt($('#month_start').val()),
        parseInt($('#day_start').val())
      )
      date_end = new Date(
        parseInt($('#year_end').val()), 
        parseInt($('#month_end').val()),
        parseInt($('#day_end').val())
      )
      onFilterChange()
    }
  })  
}

function getSummary(day, params) {
  day = new Date(day.valueOf())
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

var plots = {}

var plot_data = {
  counts: []
}

function addPoint(date, summary) {
  plot_data.counts.push([date.valueOf(), summary['Count']])
  drawPoints()
}

function resetPoints() {
  counts = []
}

function initPlots() {
  plots.counts = $.plot(
    $('#graph_counts'),
    [],
    {
      xaxis: {
        mode: "time",
        minTickSize: [1, "day"],
      },
      yaxis: {
        min: 0,
      },
    }
  )
}

function drawPoints() {
  plot_data.counts.sort(function(a, b) {
    return a[0] - b[0]
  })
  plots.counts.setData([plot_data.counts])
  plots.counts.setupGrid()
  plots.counts.draw()
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
    day.setDate(day.getDate() + 1)
  }
}

$(document).ready(function() {
  $.getScript('assets/flot/jquery.flot.js', function() {
    $.getScript('assets/flot/jquery.flot.time.js', function() {
      initFilters();
      initRange();
      var filterForm = $('#filters').parent()
      initPlots();
    })
  })
})

// vim: ts=2:sw=2:et

//To do: figure out how time zones will work.


function formatPercent(value) {
  return Math.floor(value * 100) + '%'
}

var PLOT_TYPES = {
  'Number of jobs': {},
  'Successful jobs': {
    formatter: formatPercent
  },
  'CPU time used': {}
}

function dateToString(date) {
  return date.getFullYear() + '-' + (date.getMonth() + 1) + '-' + date.getDate()
}

var MSECS_PER_DAY = 24 * 3600 * 1000

var MAX_CONCURRENT_REQUESTS = 10

var date_start, date_end

var active_requests = {}

function initControls() {
  var dateBoxes = $('#date_range').children('.date_box')
  
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
  
  //To do: check to see if any graphs are displayed?
  $('#do_graph').click(function() {
    var inputs = dateBoxes.children()
  //Check to see if the form is filled out.
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
  
  var add_graph = $('#add_graph')
  for(var name in PLOT_TYPES) {
    var opt = $('<option/>')
    opt.text(name)
    opt.val(name)
    add_graph.append(opt)
  }
  
  $('#add_graph').change(function() {
    var $this = $(this)
    if($this.val() == 0) {
      return
    }
    addGraph($this.val())
    $this.val(0)
  })
}

function addGraph(type) {
  var container = $('<div>')
  container.addClass('graph_container')
  
  var graph = $('<div/>')
  graph.addClass('graph')
  container.append(graph)
  
  var remover = $('<div/>')
  remover.addClass('graph_remover')
  remover.text('X')
  remover.click(function() {
    $(this).parent().remove()
  })
  container.append(remover)
  
  graph.data('type', type)
  $('#add_graph').before(container)
  
  var type_data = PLOT_TYPES[type]
  
  //To do: how to handle overlapping attempts to graph?
  graph.data('plot', $.plot(
    graph,
    [],
    {
      xaxis: {
      mode: "time",
      timezone: "browser",
      minTickSize: [1, "day"],
    },
      yaxis: {
      min: 0,
      tickDecimals: 2,
      tickFormatter: type_data.formatter,
      },
    }
  ))
  
  drawPoints()
}

function getSummary(day, params, request_index) {
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
  var request = $.getJSON('jobs.json?' + queryParams.join('&'), function(data) {
    addPoint(day, data)
    var next_date = new Date(day)
    next_date.setDate(next_date.getDate() + MAX_CONCURRENT_REQUESTS)
    if(next_date < date_end) {
      getSummary(next_date, params, request_index)
    }
  })
  active_requests[request_index] = request
}

var plots = {}

var plot_data = {}

function addPoint(date, summary) {
  plot_data['Number of jobs'].push([date.valueOf(), summary['Count']])
  plot_data['Successful jobs'].push([date.valueOf(), summary['Successful']])
  plot_data['CPU time used'].push([date.valueOf(), summary['CPU time used']])
  drawPoints()
}

function resetPoints() {
  //Cancel all active requests.
  for(var i = 0; i < active_requests.length; ++i) {
    var request = active_requests[i]
    if(request) {
      request.abort()
      //Cut out the callback so it can't spawn the next request in line.
      request.done(function() {})
     }
  }
  active_requests = []

  for(type in PLOT_TYPES) {
    plot_data[type] = []
  }
  
  var end = new Date(date_end)
  end.setDate(end.getDate() - 1)

 
  //Currently broken
  /*$('.graph').each(function() {
    var graph = $(this)
    var plot = graph.data('plot')
    var xaxis = plot.getAxes().xaxis
    xaxis.min = date_start.valueOf()
    xaxis.max = end.valueOf()
  })*/
}

//Calculates the resolution value that should be used for the selected time interval
function resolution() {

}


function drawPoints() {
  for(type in plot_data) {
    plot_data[type].sort(function(a, b) {
      return a[0] - b[0]
    })
  }
  graphs = $('.graph')
  graphs.each(function() {
    var graph = $(this)
    var type = graph.data('type')
    var type_data = PLOT_TYPES[type]
    var plot = graph.data('plot')
    plot.setData([
      {
        label: type,
        data: plot_data[type],
      }
    ])
    plot.setupGrid()
    plot.draw()
  })
}

function onFilterChange(evt) {
  if(evt) {
    evt.preventDefault()
  }
  resetPoints()
  if(!date_start || !date_end) {
    return
  }
  
  var params = getFilterData()
  
  var date_max = new Date(date_start)
  date_max.setDate(date_max.getDate() + MAX_CONCURRENT_REQUESTS)
  date_max = Math.min(date_end, date_max)
  
  var d = new Date(date_start)
  for(var i = 0; i < MAX_CONCURRENT_REQUESTS; ++i) {
    if date 
    getSummary(day, params, i)
  	d.setDate(d.getDate() + 1)
  }
}

$(document).ready(function() {
  $.getScript('assets/flot/jquery.flot.js', function() {
    $.getScript('assets/flot/jquery.flot.time.js', function() {
      initFilters()
      $('#filter_form').submit(onFilterChange)
      initControls()
      resetPoints()
      var filterForm = $('#filters').parent()
    })
  })
})


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

var MSECS_PER_HOUR = 3600 * 1000
var MSECS_PER_DAY = MSECS_PER_HOUR * 24
var MSECS_PER_WEEK = MSECS_PER_DAY * 7
//This doesn't account for leap years, but it's not used for anything where exact precision is critical.
var MSECS_PER_YEAR = MSECS_PER_DAY * 365

//The rough goal for graph resolution
//To do: make configurable?
var NUM_GRAPH_POINTS = 20

//To do: find the "right" value for this.
var MAX_CONCURRENT_REQUESTS = 5

var time_start, time_end

var active_requests = []

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
      time_start = new Date(
        parseInt($('#year_start').val()), 
        parseInt($('#month_start').val()),
        parseInt($('#day_start').val())
      )
      time_end = new Date(
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

//The object passed as start_time should not be modified after calling this function.
function getSummary(start_time, interval, params, request_index) {
  var start = start_time.toISOString()
  var end_time = new Date(start_time)
  end_time.setSeconds(end_time.getSeconds() + interval)
  var end = end_time.toISOString()
  
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
    addPoint(start_time, data)
    var next_start = new Date(start_time)
    next_start.setSeconds(next_start.getSeconds() + interval * MAX_CONCURRENT_REQUESTS)
    if(next_start < time_end) {
      getSummary(next_start, interval, params, request_index)
    } else {
      active_requests[request_index] = null
    }
  })
  active_requests[request_index] = request
}

var plots = {}

var plot_data = {}

function addPoint(date, summary) {
  plot_data['Number of jobs'].push([date.getTime(), summary['Count']])
  plot_data['Successful jobs'].push([date.getTime(), summary['Successful']])
  plot_data['CPU time used'].push([date.getTime(), summary['CPU time used']])
  drawPoints()
}

function resetPoints() {
  //Cancel all active requests.
  for(var i = 0; i < active_requests.length; ++i) {
    var request = active_requests[i]
    if(request) {
      request.abort()
      //Cut out the callback so it can't spawn the next request in line.
      //(If the request has already come in, but its callback has not been called, I'm not sure if abort() will prevent the call.)
      //To consider: verify and possibly remove
      request.done(function() {})
     }
     active_requests[i] = null
  }

  for(type in PLOT_TYPES) {
    plot_data[type] = []
  }
  
  var end = new Date(time_end)
  end.setDate(end.getDate() - 1)

  //Currently broken
  /*
  $('.graph').each(function() {
    var graph = $(this)
    var plot = graph.data('plot')
    var xaxis = plot.getAxes().xaxis
    xaxis.min = time_start.valueOf()
    xaxis.max = end.valueOf()
  })*/

  drawPoints()
}

//Calculates the time step value that should be used for the selected time interval
function timeStep() {
  var difference = time_end.valueOf() - time_start.valueOf()
  var time_step = difference / NUM_GRAPH_POINTS

  alert(time_step)

  return time_step
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
  if(!time_start || !time_end) {
    return
  }
  
  var params = getFilterData()

  var time_step = timeStep()
  
  var time_max = new Date(time_start)
  time_max.setTime(time_max.getTime() + time_step * MAX_CONCURRENT_REQUESTS)
  time_max = Math.min(time_end, time_max)
  
  //Start the first batch of requests.
  var d = new Date(time_start)
  for(var i = 0; i < MAX_CONCURRENT_REQUESTS; ++i) {
    if(d >= time_max) {
      break
    }
    getSummary(new Date(d), time_step, params, i)
  	d.setTime(d.getTime() + time_step)
  }
}

$(document).ready(function() {
  $.getScript('assets/flot/jquery.flot.js', function() {
    $.getScript('assets/flot/jquery.flot.time.js', function() {
      initFilters()
      $('#filter_form').submit(onFilterChange)
      initControls()
      resetPoints()
      addGraph('Number of jobs')
    })
  })
})


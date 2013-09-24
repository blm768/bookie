// vim: ts=2:sw=2:et

"use strict";

function formatPercent(value) {
  return Math.floor(value * 100) + '%'
}

var PLOT_TYPES = {
  'Number of jobs': {},
  '% Successful': {
    formatter: formatPercent
  },
  'CPU time used': {},
}

var MSECS_PER_MINUTE = 60 * 1000
var MSECS_PER_HOUR = 60 * MSECS_PER_MINUTE
var MSECS_PER_DAY = MSECS_PER_HOUR * 24
var MSECS_PER_WEEK = MSECS_PER_DAY * 7

//Base time steps for resolution purposes
//Must be sorted in descending order
//To consider: change/add bases?
var TIME_STEP_BASES = [
  MSECS_PER_DAY,
  MSECS_PER_HOUR,
]

//The minimum number of points to display on the graph
//To consider: make configurable?
var NUM_GRAPH_POINTS = 20

//To consider: find the optimal value for this?
var MAX_CONCURRENT_REQUESTS = 5

//Contains the start/end time from the input boxes
var time_start, time_end

//Contains all pending AJAX requests
var active_requests = []

function initControls() {
  var date_boxes = $('#date_range').children('.date_box')
  
  //Set the boxes' initial values:
  var date = new Date(Date.now())
  date.setDate(1)
  
  date_boxes.children().filter('.day').val(1)
  
  date_boxes.each(function() {
    var $this = $(this)
    var inputs = $this.children()
    inputs.filter('.month').val(date.getMonth())
    inputs.filter('.year').val(date.getFullYear())
    date.setMonth(date.getMonth() + 1)
  })
  
  //Prepare callbacks:
  $('#do_graph').click(function() {
    //If no graphs are being displayed, just return.
    if($('.graph_container').length == 0) {
      return
    }
    var inputs = date_boxes.children().filter('input')
    //Check to see if the form is filled out.
    var complete = true
    inputs.each(function() {
      if(this.value.length == 0) {
        complete = false
        //Should work like a break statement:
        return false
      }
    })
    if(complete) {
      //TODO: validate correctness of the day of month?
      //(The Date class doesn't care, but the user might be confused.)
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
  
  //Set up the 'Add graph' selection box:
  var add_graph = $('#add_graph')
  for(var name in PLOT_TYPES) {
    var opt = $('<option/>')
    opt.text(name)
    opt.val(name)
    add_graph.append(opt)
  }
  
  add_graph.change(function() {
    var $this = $(this)
    if($this.val() == 0) {
      return
    }
    addGraph($this.val())
    $this.val(0)
  })
}

function addGraph(type) {
  //Create the graph box:
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
  //Put the graph container into the page:
  $('#add_graph').before(container)
  
  var type_info = PLOT_TYPES[type]
  
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
      tickFormatter: type_info.formatter,
      },
    }
  ))
  
  drawPoints()
}

/*
 * Sends an AJAX request to get the summary data for a single graph point
 *
 * The request_index identifies this request's position in the active_requests
 * array. It must be in the range [0, MAX_CONCURRENT_REQUESTS).
 *
 * Once the request is received, its callback will automatically spawn a
 * request to get one of the remaining data points. This new request will
 * replace the received request in the active_requests array.
 *
 * The object passed as start_time should not be modified after calling this function.
 */
function getSummary(start_time, interval, queryParams, request_index) {
  var start = start_time.toISOString()
  var end_time = new Date(start_time)
  end_time.setTime(end_time.getTime() + interval)
  if(end_time < time_end) {
    end_time = time_end
  }
  var end = end_time.toISOString()
  
  var paramsWithTime
  if(queryParams.length > 0) {
    paramsWithTime = queryParams + '&'
  } else {
    paramsWithTime = ""
  }
  paramsWithTime += 'time[]=' + start + '&time[]=' + end
  var request = $.getJSON('/jobs.json?' + paramsWithTime, function(data) {
    addPoint(start_time, data)
    //Prepare to get the next data point.
    var next_start = new Date(start_time)
    next_start.setTime(next_start.getTime() + interval * MAX_CONCURRENT_REQUESTS)
    //Is there another data point?
    if(next_start < time_end) {
      //Get the data point.
      getSummary(next_start, interval, queryParams, request_index)
    } else {
      active_requests[request_index] = null
    }
  })

  //Register this request in the active_requests array so it can be
  //cancelled if needed.
  active_requests[request_index] = request
}

var plots = {}

var plot_data = {}

function addPoint(date, summary) {
  var time = date.getTime()
  var count = summary['Count']
  plot_data['Number of jobs'].push([time, count])
  var successful
  //The number of successful jobs is converted to a percentage.
  if(count == 0) {
    successful = 0
  } else {
    successful = summary['Successful'] / count
  }
  plot_data['% Successful'].push([time, successful])
  plot_data['CPU time used'].push([time, summary['CPU time used']])
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

  for(var type in PLOT_TYPES) {
    plot_data[type] = []
  }
  
  var end = new Date(time_end)
  end.setDate(end.getDate() - 1)

  //Currently broken
  //To consider: Fix? Move?
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
  var difference = time_end.getTime() - time_start.getTime()
  var time_step = difference / NUM_GRAPH_POINTS

  //Fit the time interval to one of the base timesteps.
  for(var i = 0; i < TIME_STEP_BASES.length; ++i) {
    var base = TIME_STEP_BASES[i];
    var num_bases = Math.floor(difference / base)
    //Is this base timestep the right fit?
    if(num_bases >= NUM_GRAPH_POINTS) {
      //Set time_step to be a multiple of base.
      var bases_per_point = Math.floor(num_bases / NUM_GRAPH_POINTS)
      time_step = base * bases_per_point
      break
    }
  }

  return time_step
}


function drawPoints() {
  for(var type in plot_data) {
    plot_data[type].sort(function(a, b) {
      return a[0] - b[0]
    })
  }
  var graphs = $('.graph')
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

//Called when the time range or filters have changed
function onFilterChange(evt) {
  //If this is being called as a DOM event handler, it should be
  //from the filter form's onSubmit event. That event should
  //be cancelled.
  if(evt) {
    evt.preventDefault()
  }
  resetPoints()
  //TODO: error messages?
  if(!time_start || !time_end || time_start >= time_end) {
    return
  }

  var time_step = timeStep()
  
  //Find the upper bound on the start_time of the first
  //batch of concurrent requests (handles the case when
  //the interval is too short to allow the full set of
  //requests to be submitted)
  var time_max = new Date(time_start)
  time_max.setTime(time_max.getTime() + time_step * MAX_CONCURRENT_REQUESTS)
  time_max = Math.min(time_end, time_max)
  
  //Start the first batch of requests.
  var requestParams = $('#filter_form').serialize()
  var d = new Date(time_start)
  for(var i = 0; i < MAX_CONCURRENT_REQUESTS; ++i) {
    if(d >= time_max) {
      break
    }
    getSummary(new Date(d), time_step, requestParams, i)
  	d.setTime(d.getTime() + time_step)
  }
}

$(document).ready(function() {
  $.getScript('assets/flot/jquery.flot.js', function() {
    $.getScript('assets/flot/jquery.flot.time.js', function() {
      $.getScript('assets/flot/jquery.flot.resize.js', function() {
        initFilters()
        $('#filter_form').submit(onFilterChange)
        initControls()
        resetPoints()
        addGraph('Number of jobs')
      })
    })
  })
})


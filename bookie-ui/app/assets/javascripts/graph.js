// vim: ts=2:sw=2:et

//TODO: figure out how time zones are working here.

"use strict";

function formatPercent(value) {
  return Math.floor(value * 100) + '%'
}

var PLOT_TYPES = {
  num_jobs: {
    series: {
      total: 'Total jobs',
      successful: 'Successful jobs',
    },
  },
  cpu_time_used: {
    series: {
      data: 'CPU time used',
    },
  },
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
  $('#do_graph').click(onFilterChange)
  $('#filter_form').submit(onFilterChange)
}

function addPlot(type) {
  //Create the graph box:
  var container = $('<div>')
  container.addClass('plot_container')
  
  var plot = $('<div/>')
  plot.addClass('plot')
  container.append(plot)
  
  plot.data('type', type)
  //Put the graph container into the page:
  $('#content').append(container)
  
  var type_info = PLOT_TYPES[type]
  var series = type_info['series']
  
  plot.plot(
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
        tickFormatter: type_info['formatter'],
      },
    }
  )
  
  drawPoints()
}

/*
 * Sends an AJAX request to get the summary data for a single graph point
 *
 * Once the request is received, its callback will automatically spawn a new
 * request to get one of the remaining data points. This new request will
 * replace the received request in the active_requests array.
 *
 * Unless otherwise noted, the objects passed as parameters must not be modified after this
 * function is called.
 *
 * Parameters:
 * time_range: the entire time range of points being graphed
 * point_time: the time value for this data point
 * interval: the amount of time that this point covers
 * queryParams: the query parameters for the JSON request (excluding time-related parameters)
 * request_index: identifies this request's position in the active_requests array.
 *  * It must be in the range [0, MAX_CONCURRENT_REQUESTS).
 */
function getSummary(time_range, point_time, interval, queryParams, request_index) {
  var start = point_time.toISOString()
  var end_time = new Date(point_time)
  end_time.setTime(end_time.getTime() + interval)
  if(end_time < time_range.end) {
    end_time = time_range.end
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
    addPoint(point_time, data)
    //Prepare to get the next data point.
    var next_start = new Date(point_time)
    next_start.setTime(next_start.getTime() + interval * MAX_CONCURRENT_REQUESTS)
    //Is there another data point?
    if(next_start < time_range.end) {
      //Get the data point.
      getSummary(time_range, next_start, interval, queryParams, request_index)
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

/*
 * Adds a point to the graph
 *
 * Typically called from an AJAX callback
 *
 * TODO: handle filter errors.
 */
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

/*
 * Resets data points on all graphs
 */
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
  
  drawPoints()
}

//Calculates the time step value that should be used for the selected time interval
function timeStep(time_range) {
  var difference = time_range.end.getTime() - time_range.start.getTime()
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
  //To consider: optimize?
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

function getTimeRange() {
  var date_boxes = $('#date_range').children('.date_box')
  var inputs = date_boxes.children().filter('input')
  //Check to see if the form is filled out.
  //TODO: validation (remove negative values.)
  var complete = true
  inputs.each(function() {
    if(this.value.length == 0) {
      complete = false
      //Should work like a break statement:
      return false
    }
  })
  if(complete) {
    var start = new Date(
      parseInt($('#year_start').val()), 
      parseInt($('#month_start').val()),
      parseInt($('#day_start').val())
    )
    var end = new Date(
      parseInt($('#year_end').val()), 
      parseInt($('#month_end').val()),
      parseInt($('#day_end').val())
    )
    //If the day of the month is too high, Date will just advance
    //to the next month. Make the boxes reflect that.
    $('#year_start').val(start.getFullYear())
    $('#month_start').val(start.getMonth())
    $('#day_start').val(start.getDate())
    $('#year_end').val(end.getFullYear())
    $('#month_end').val(end.getMonth())
    $('#day_end').val(end.getDate())

    return {start: start, end: end};
  } else {
    return null;
  }
}

//Called when the time range or filters have changed
function onFilterChange(evt) {
  if(evt.type == 'submit') {
    evt.preventDefault()
  }
  resetPoints()

  var time_range = getTimeRange()
  //TODO: error messages?
  if(!time_range) {
    return
  }

  var time_step = timeStep(time_range)
  
  //Find the upper bound on the start_time of the first
  //batch of concurrent requests (handles the case when
  //the interval is too short to allow the full set of
  //requests to be submitted)
  var time_max = new Date(time_range.start)
  time_max.setTime(time_max.getTime() + time_step * MAX_CONCURRENT_REQUESTS)
  time_max = Math.min(time_range.end, time_max)
  
  //Start the first batch of requests.
  var requestParams = $('#filter_form').serialize()
  var d = new Date(time_range.start)
  for(var i = 0; i < MAX_CONCURRENT_REQUESTS; ++i) {
    if(d >= time_max) {
      break
    }
    getSummary(time_range, new Date(d), time_step, requestParams, i)
  	d.setTime(d.getTime() + time_step)
  }
}

$(document).ready(function() {
  $.getScript('assets/flot/jquery.flot.js', function() {
    $.getScript('assets/flot/jquery.flot.time.js', function() {
      $.getScript('assets/flot/jquery.flot.resize.js', function() {
        initFilters()
        initControls()
        resetPoints()
        for(var type in plot_data) {
          addPlot(type)
        }
      })
    })
  })
})


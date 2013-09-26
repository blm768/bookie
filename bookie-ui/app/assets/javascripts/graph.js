// vim: ts=2:sw=2:et

//TODO: figure out how time zones are working here.

"use strict";

function formatPercent(value) {
  return Math.floor(value * 100) + '%'
}

var plots = {
  num_jobs: {
    series: [
      {
        json_field: 'total',
        label: 'Total jobs',
      },
      {
        json_field: 'successful',
        label: 'Successful jobs',
      },
    ],
  },
  cpu_time_used: {
    series: [
      {
        json_field: 'data',
        label: 'CPU time used',
      },
    ],
  },
}

var MSECS_PER_MINUTE = 60 * 1000
var MSECS_PER_HOUR = 60 * MSECS_PER_MINUTE
var MSECS_PER_DAY = MSECS_PER_HOUR * 24

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

//The current pending AJAX request
var active_request

function initControls() {
  var date_boxes = $('#date_range').children('.date_box')
  
  //Set the boxes' initial values:
  var date = new Date(Date.now())
  //Set the date to the beginning of the month.
  date.setDate(1)
  date_boxes.children().filter('.day').val(1)
  date_boxes.each(function() {
    var $this = $(this)
    var inputs = $this.children()
    inputs.filter('.month').val(date.getMonth())
    inputs.filter('.year').val(date.getFullYear())
    //Move to the next month:
    date.setMonth(date.getMonth() + 1)
  })
  
  //Prepare callbacks:
  $('#do_graph').click(onFilterChange)
  $('#filter_form').submit(onFilterChange)
}

function addPlot(type) {
  var plot = $('<div/>')
  plot.addClass('plot')
  plot.data('plot_type', type)
  $('#content').append(plot)
  
  var type_info = plots[type]
  var series = type_info.series
  for(var i = 0; i < series.length; ++i) {
    series[i].data = []
  }
  
  plot.plot(
    type_info.series,
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
  )
}

/*
 * Sends an AJAX request to get the summary data for a single graph point
 *
 * Once the request is received, its callback will automatically spawn a new
 * request to get the next data point.
 *
 * Unless otherwise noted, the objects passed as parameters must not be
 * modified after this function is called.
 *
 * Parameters:
 * time_range: the entire time range of points being graphed
 * point_time: the time value for this data point
 * interval: the amount of time that this point covers
 * queryParams: the query parameters for the JSON request (excluding time-related parameters)
 */
function getSummary(time_range, point_time, interval, queryParams) {
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
    addPoints(point_time, data)
    //Prepare to get the next data point.
    var next_start = new Date(point_time)
    next_start.setTime(next_start.getTime() + interval)
    //Is there another data point?
    if(next_start < time_range.end) {
      //Get the data point.
      getSummary(time_range, next_start, interval, queryParams)
    } else {
      active_request = null
    }
  })

  active_request = request
}

/*
 * Adds a point to the graph
 *
 * Typically called from an AJAX callback
 *
 * TODO: handle filter errors.
 */
function addPoints(date, summary) {
  var time = date.getTime()
  for(var plot_name in plots) {
    var series = plots[plot_name].series
    var points = summary[plot_name]
    for(var i = 0; i < series.length; ++i) {
      var series = series[i]
      var point = points[series.json_field]
      series.data.push([time, point])
    }
  }
  drawPoints()
}

/*
 * Resets data points on all graphs
 */
function resetPoints() {
  //Cancel the active request.
  if(active_request) {
  active_request.abort()
    //Cut out the callback so it can't spawn the next request in line.
    //(If the request has already come in, but its callback has not been called, I'm not sure if abort() will prevent the call.)
    //To consider: verify and possibly remove
    active_request.done(function() {})
    active_request = null
  }

  for(var plot_name in plots) {
    var series = plots[plot_name].series
    for(var i = 0; i < series.length; ++i) {
      series[i].data = []
    }
  }
  
  drawPoints()
}

//Calculates the time step value that should be used for the selected time interval
function timeStep(time_range) {
  var difference = time_range.end.getTime() - time_range.start.getTime()
  var time_step = difference / NUM_GRAPH_POINTS

  //Fit the time interval to one of the base timesteps if possible.
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
  var plot_divs = $('.plot')
  plot_divs.each(function() {
    var plot_div = $(this)
    var plot = plot_div.data('plot')
    plot.setData(plots[plot_div.data('plot_type')].series)
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
  
  //Start the first request.
  var requestParams = $('#filter_form').serialize()
  getSummary(time_range, new Date(time_range.start), time_step, requestParams)
}

$(document).ready(function() {
  $.getScript('assets/flot/jquery.flot.js', function() {
    $.getScript('assets/flot/jquery.flot.time.js', function() {
      $.getScript('assets/flot/jquery.flot.resize.js', function() {
        initFilters()
        initControls()
        resetPoints()
        for(var type in plots) {
          addPlot(type)
        }
      })
    })
  })
})


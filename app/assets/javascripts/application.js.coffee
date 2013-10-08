# This is a manifest file that'll be compiled into application.js, which will include all the files
# listed below.
#
# Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
# or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
#
# It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
# compiled file.
#
# Read Sprockets README (https://github.com/sstephenson/sprockets#sprockets-directives) for details
# about supported directives.
#
#= require jquery
#= require jquery_ujs
#= require turbolinks
#= require bootstrap.min
#= require_tree .

workTimer =
  timerId: null,
  start: (start_time) ->
    this.render(start_time)
    this.timerId = setInterval ->
      workTimer.render(start_time)
    , 1000
  ,
  stop: ->
    clearInterval(this.timerId)
  ,
  render: (start_time) ->
    end_time = new Date()
    total = end_time.getTime() - start_time.getTime()
    hour = Math.floor(total/(60*60*1000))
    total = total-(hour*60*60*1000)
    min = Math.floor(total/(60*1000))
    total = total-(min*60*1000)
    sec = Math.floor(total/1000)
    hour = "0" + hour if hour < 10
    min = "0" + min if min < 10
    sec = "0" + sec if sec < 10
    $('.timer-true').text("#{hour} hour #{min} min #{sec} sec")
    $('title').text("#{hour}:#{min}:#{sec}")

$(document).ready ->
  start_time = $("body").data('timer')
  start_time = new Date(Date.parse(start_time))
  if not isNaN(start_time)
    workTimer.start(start_time)

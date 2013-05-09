if io?
  socket = io.connect('/')
  socket.on('connect', (data) ->
    $('#body').prepend('</br>'+data) if data
  )
  socket.on('message', (data) ->
    for msg in data.messages
      $('#body').prepend("</br>#{msg.user} says: #{msg.message}")
  )
  socket.on('disconnect', (data) ->
      $('#body').prepend('</br>'+data)
  )
  $(document).ready(()->
    $('#send').click(() ->
      msg = $('#field').val()
      if msg
        socket.send(msg)
        $('#body').prepend('</br>You say: '+msg)
        $('#field').val('')
      )
    $('form').on('submit', () ->
      return false
    )
  )


window.helpers = {
  enter: (dom, callback) ->
    $(dom).keypress((e) ->
      if e.which == 13
        callback(e, this)
    )
  ,
  click: (dom, callback) ->
    $(dom).click((e)->
      callback(e)
    )
  ,
  dblclick: (dom, callback) ->
    $(dom).dblclick((e)->
      callback(e)
    )
  ,
  href2title: (dom) ->
    title = ""
    href = $(dom).attr("href")
    title = href.replace(/^#/,"") if href.match("#")
    return title
  ,
  hash2title: (defaulttitle) ->
    res = location.hash.replace(/^#/,"")
    res = defaulttitle if !res or res == ""
    res
}
    

init = () ->
  $(window).focus((e) ->
    stopWorkLog()
  )
  cdown()
  #prepareNodeServer()
  prepareAddProject()
  prepareShowProjects()
  prepareAddServer()
  prepareDoExport()
  prepareDoImport()
  prepareDoCheckedDdt()
  renderProjects()
  renderIssues()
  renderWorkLogs()
  #renderCalendars()
  $(".calendar").hide()
  loopRenderWorkLogs()
  #loopFetch()

subWin = {}

fetch = (server) ->
  domain = server.domain
  token = server.token
  projects = []
  issues = []
  work_logs = []
  for project in findWillUploads("projects")
    projects = pushIfHasIssue(project, projects)
  for issue in findWillUploads("issues")
    issues.push(forUploadIssue(issue))
  for work_log in findWillUploads("work_logs")
    work_logs.push(forUploadWorkLog(work_log))
  diffs =  {
    projects: projects,
    issues: issues,
    work_logs: work_logs
  }
  working_logs = []
  wlsis = db.one("infos", {key: "working_log_server_ids"})
  if wlsis and wlsis.val
    for working_log_server_id in wlsis.val.split(",")
      server_id = parseInt(working_log_server_id)
      working_logs.push(db.one(
        "work_logs", {server_id: server_id})
      )
  params = {
    token: token,
    last_fetch: last_fetch(),
    diffs: diffs,
    working_logs: working_logs
  }
  url = "#{domain}/api/v1/diffs.json"

  $.ajax({
    type : "POST",
    url  : url,
    data : params,
    complete: (res) ->
      data = res.responseText
      data = JSON.parse(data)
      updtWorkLogServerIds(data)
      sync(server, "server_ids", data.server_ids)
      sync(server, "projects", data.projects)
      sync(server, "issues", data.issues)
      sync(server, "work_logs", data.work_logs)
      renderWorkLogs(server)
      last_fetch(now())
    ,
    async: false,
    dataType: "json"
  })

updtWorkLogServerIds = (data) ->
  if data.working_log_server_ids
    wlsis = db.one("infos", {key: "working_log_server_ids"})
    unless wlsis
      wlsis = db.ins("infos",
        {key: "working_log_server_ids"}
      )
    wlsis.val = data.working_log_server_ids.join(",")
    db.upd("infos", wlsis)

sync = (server, table_name, data) ->
  if table_name == "server_ids"
    for table_name, server_ids of data
      if server_ids and server_ids[0]
        for local_id, aserver of server_ids
          item = db.one(table_name, {id: local_id})
          if item
            item.server_id = aserver.id
            db.upd(table_name, item)
  else
    if data
      for i in data
        sync_item(server, table_name, i)

sync_item = (server, table_name, i) ->
  if i.project_id
    project = db.one("projects", {server_id: i.project_id})
    i.project_id = project.id
  if i.issue_id
    issue = db.one("issues", {server_id: i.issue_id})
    if issue
      i.issue_id = issue.id
    else
      url = "#{server.domain}/api/v1/issues/"
      url += "#{i.issue_id}.json?token=#{server.token}"
      $.get(url, (item) ->
        sync_item(server, "issues", item)
      )
      i.issue_id = 0
  if i.closed_at > 0
    i.is_closed = true
  item = db.one(table_name, {server_id: i.id})
  item = db.one(table_name, {id: i.local_id}) unless item
  if item
    item.server_id = i.id
    i.id = item.id
    item = i
    db.upd(table_name, item)
  else
    i.server_id = i.id
    delete i.id
    item = db.ins(table_name, i)

renderProjects = () ->
  projects = db.find(
    "projects", null, {order: {upd_at: "desc"}}
  )
  $("#issues").html("")
  for project in projects
    renderProject(project)
  $("#issues").append(innerLink())

prepareNodeServer = () ->
  unless db.one("servers", {domain: "http://localhost:3000"})
    dbtype = "local"
    url = "http://localhost:3000/api/users.json"
    $.get(url, (data) ->
      server = db.ins("servers", {
        domain: "http://localhost:3000",
        user_id: data.id,
        has_connect: true,
        dbtype: dbtype
      })
    )

prepareShowProjects = () ->
  $(".show_projects").click(() ->
    $(".project").fadeIn(100)
    $(".issue").fadeIn(100)
  )

prepareAddServer = () ->
  hl.click(".add_server", (e, target)->
    domain = prompt(
      'please input domain', 'http://crowdsourcing.dev
    ')
    if domain.match("crowdsourcing") or domain.match("cs.mindia.jp")
      dbtype = "cs"
      token = prompt('please input the token', '83070ba0c407e9cc80978207e1ea36f66fcaad29b60d2424a7f1ea4f4e332c3c')
      url = "#{domain}/api/v1/users.json?token=#{token}"
      $.get(url, (data) ->
        server = db.ins("servers", {
          domain: domain,
          token: token,
          user_id: data.id,
          has_connect: true,
          dbtype: dbtype
        })
      )
    else if domain.match("redmine")
      dbtype = "redmine"
      #url = "#{domain}/api/v1/users.json"
      token = prompt('please input login id', 'nishiko')
      token = prompt('please input login pass', '')
      $.get(url, (data) ->
        db.ins("servers", {
          domain: domain,
          login: login,
          pass: pass,
          user_id: data.id,
          has_connect: true,
          dbtype: dbtype
        })
      )
    else
      alert "invalid domain"
  )

prepareAddProject = () ->
  hl.click(".add_project", (e, target)->
    title = prompt('please input the project name', '')
    issue_title = prompt('please input the issue title', 'add issues')
    if title.length > 0 && issue_title.length > 0
      project = addProject(title)
      addIssue(project.id, issue_title)
    else
      alert "please input the title of project and issue."
  )

prepareDoExport = () ->
  hl.click(".do_export", (e, target)->
    result = {
      projects: db.find("projects"),
      issues: db.find("issues"),
      work_logs: db.find("work_logs"),
      servers: db.find("servers"),
      infos: db.find("infos"),
    }
    blob = new Blob([JSON.stringify(result)])
    url = window.URL.createObjectURL(blob)
    d = new Date()
    caseTitle = "Timecard"
    title = caseTitle + "_" + d.getFullYear() + zp(d.getMonth()+1) + d.getDate() + ".json"

    a = $('<a id="download"></a>').text("download").attr("href", url).attr("target", '_blank').attr("download", title).hide()
    $(".do_export").after(a)
    $("#download")[0].click()
    return false
  )

prepareDoImport = () ->
  hl.click(".do_import", (e, target)->
    datafile = $("#import_file").get(0).files[0]
    if datafile
      checkImport(datafile)
    else
      $("#import_file").click()
  )

  $("#import_file").change(()->
    datafile = $("#import_file").get(0).files[0]
    if datafile
      checkImport(datafile)
    else
      alert "invalid data."
  )

checkImport = (datafile) ->
  reader = new FileReader()
  reader.onload = (evt) ->
    json = JSON.parse(evt.target.result)
    result = doImport(json)
    if result
      alert "import is done."
      location.reload()
    else
      alert "import is failed."
  reader.readAsText(datafile, 'utf-8')
  return false

doImport = (json) ->
  for table_name, data of json
    db.del(table_name)
    for item in data
      db.ins(table_name, item)
  return true


prepareDoCheckedDdt = () ->
  $(".do_checked_ddt").click(() ->
    $checked = $("input:checkbox:checked")
    if $checked.length == 0
      alert "please select issues"
    else
      for i in $checked
        $(i).parent().parent().parent().find(".btn-toolbar").find(".btn-group").find(".ddt").click()
  )



renderProject = (project) ->
  project_name = project.name
  project_name = "<a href=\"#{project.url}\" target=\"_blank\">#{project.name}</a>" if project.url
  $("#issues").append("""
    <div id=\"project_#{project.id}\"class=\"project\" style=\"display:none;\">
    #{innerLink()}
    <div class=\"span12\">
    <h1>
      #{project_name}#{if project.server_id then "" else uicon}
    </h1>
    <div class=\"issues\"></div>
    <div class=\"input-append\"> 
      <input type=\"text\" class=\"input\" />
      <input type=\"submit\" value=\"add issue\" class=\"btn\" />
    </div>
    <div class=\"ddt\"> 
      <a href="#" class=\"btn\">DDT</a>
    </div>
    <div class=\"edit\"> 
      <a href="#" class=\"btn\">Edit</a>
    </div>
    </div>
    </div>
  """)
  $("#project_#{project.id}").hide()
  hl.enter("#project_#{project.id} div div .input", (e, target)->
    title = $(target).val()
    $project = $(target).parent().parent().parent()
    project_id = $project.attr("id").replace("project_","")
    if title.length > 0
      addIssue(project_id, title)
      $(target).val("")
    else
      alert "please input the title"
  )

  hl.click("#project_#{project.id} div .edit a", (e, target)->
    doEditProject(project.id)
  )

  hl.click("#project_#{project.id} div .ddt a", (e, target)->
    doDdtProject(project.id)
  )

  $("#project_#{project.id} div h1").droppable({
    over: (event, ui) ->
      $(this).css("background", "#fc0")
    ,
    out: (event, ui) ->
      $(this).css("background", "#efe")
    drop: (event, ui) ->
      issue = db.one("issues", {id: window.dragging_issue_id})
      issue.project_id = project.id
      db.upd("issues", issue)
      location.reload()
  })

innerLink = () ->
  res = "<div class=\"innerlink\"> | "
  projects = db.find("projects", null, {order: {upd_at: "desc"}})
  for project in projects
    res += "<span class=\"project_#{project.id}\"><a href=\"#project_#{project.id}\">#{project.name}</a> | </span>"
  res += "</div>"
  return res

renderIssues = (issues=null) ->
  issues = db.find("issues", null, {order:{upd_at:"desc"}}) unless issues
  $(".issues").html("")
  i = 1
  for issue in issues
    renderIssue(issue, null, i)
    i = i + 0
  doCard()

prepareCards = (issue_id) ->
  $(() ->
    $("#issue_#{issue_id} h2").click(() ->
      issue = db.one("issues", {id: issue_id})
      project = db.one("projects", {id: issue.project_id})
      url = issue.url
      url = project.url if project.url and !url
      if url
        startWorkLog(issue_id)
        subWin = window.open(url, "issue_#{issue_id}")
      else
        $e = $(this).parent().find(".body")
        turnback($e)
      return false
    )
    $("#issue_#{issue_id} div div .card").click(() ->
      doCard(issue_id)
      return false
    )
    $("#issue_#{issue_id} div div .ddt").click(() ->
      doDdt(issue_id)
      return false
    )
    $("#issue_#{issue_id} div div .cls").click(() ->
      doCls(issue_id)
      return false
    )
    $("#issue_#{issue_id} div div .edit").click(() ->
      doEditIssue(issue_id)
      return false
    )
  )

renderIssue = (issue, target=null, i = null) ->
  target = "append" unless target
  $project = $("#project_#{issue.project_id}")
  $project_issues = $("#project_#{issue.project_id} .issues")
  title = "#{issue.title}"
  project = db.one("projects", {id: issue.project_id})
  if (issue.url or project.url)
    title = "<a class=\"title\" href=\"#\">#{issue.title}</a>" 
  icon = if issue.server_id then "" else uicon

  disp = "Start"
  btn_type = "btn-primary"
  if working_log() && working_log().issue_id == issue.id
    disp = "Stop"
    btn_type = "btn-warning"

  style = ""
  if i%4 == 1
    style = "style=\"margin-left:0;\""

  #umecob({use: 'jquery', tpl_id: "./partials/issue.html", data:{
  umecob({use: 'jquery', tpl: views_issue, data:{
    issue: issue,
    title: title,
    icon: icon,
    disp: disp,
    btn_type: btn_type,
    style: style
  }}).next((html) ->
    if target == "append"
      $project_issues.append(html)
    else
      $project_issues.prepend(html)
    if (!issue.will_start_at or issue.will_start_at < now() ) and (!issue.closed_at or issue.closed_at == 0)
      $("#issue_#{issue.id}").fadeIn(200)
      $(".innerlink .project_#{issue.project_id}").fadeIn(200)
      $("#project_#{issue.project_id}").fadeIn(200)
    else
      $("#issue_#{issue.id}").fadeOut(200)
      $("#issue_#{issue.id}").css("background", "#666")
    prepareCards(issue.id)
    prepareDD(issue.id)
  )

prepareDD = (issue_id) ->
  $issue = $("#issue_#{issue_id}")
  $issue.draggable({
    drag: ()->
      window.dragging_issue_id = issue_id
  })

doDdt = (issue_id) ->
  issue = db.one("issues", {id: issue_id})
  if issue.will_start_at < now()
    issue.will_start_at = now() + 12*3600 + parseInt(Math.random(10)*10000)
    db.upd("issues", issue)
    $("#issue_#{issue.id}").fadeOut(200)
  else
    issue.will_start_at = null
    db.upd("issues", issue)
    location.reload()

doCls = (issue_id) ->
  issue = db.one("issues", {id: issue_id})
  issue.closed_at = now()
  db.upd("issues", issue)
  $("#issue_#{issue.id}").fadeOut(200)

doEditIssue = (issue_id) ->
  issue = db.one("issues", {id: issue_id})
  issue.title = prompt('issue title', issue.title)
  if issue.title.length > 1
    db.upd("issues", issue)
  issue.url = prompt('issue url', issue.url)
  if issue.url.length > 1
    db.upd("issues", issue)
  issue.body = prompt('issue body', issue.body)
  if issue.body.length > 1
    db.upd("issues", issue)
  location.reload()

doEditProject = (project_id) ->
  project = db.one("projects", {id: project_id})
  project.name = prompt('project name', project.name)
  if project.name.length > 1
    db.upd("projects", project)
  project.url = prompt('project url', project.url)
  if project.url.length > 1
    db.upd("projects", project)
  location.reload()

doDdtProject = (project_id) ->
  for issue in db.find("issues", {project_id: project_id})
    doDdt(issue.id) if issue.will_start_at < now()

doCard = (issue_id = null) ->
  updateWorkingLog(null, issue_id)

startWorkLog = (issue_id) ->
  updateWorkingLog(true, issue_id)

stopWorkLog = () ->
  updateWorkingLog(false)

updateWorkingLog = (is_start=null, issue_id=null) ->
  $all_cards = $(".card")
  $all_cards.html("Start")
  $all_cards.removeClass("btn-warning")
  $all_cards.addClass("btn-primary")
  wl = working_log()
  issue_id = wl.issue_id if is_start == false
  if wl && issue_id #stop
    wl.end_at = now()
    db.upd("work_logs", wl)
    issue = db.one("issues", {id: issue_id})
    issue.upd_at = now()
    project = db.one("projects", {id: issue.project_id})
    project.upd_at = now()
    db.upd("issues", issue)
    db.upd("projects", project)
    $("title").html("Timecard")
  if is_start == null
    if wl && parseInt(wl.issue_id) == parseInt(issue_id)
      is_start = false
    else
      is_start = true
  if is_start && issue_id #start
    db.ins("work_logs", {issue_id: issue_id, started_at: now()})
    
  issue_id = working_log().issue_id if working_log()
  if working_log()
    $issue_cards = $(".issue_#{issue_id} .card")
    console.log $issue_cards
    $issue_cards.html("Stop")
    $issue_cards.removeClass("btn-primary")
    $issue_cards.addClass("btn-warning")
  renderWorkLogs()

addIssue = (project_id, title) ->
  issue = db.ins("issues", {title: title, project_id: project_id, body:""})
  renderIssue(issue, "prepend")

addProject = (name) ->
  project = db.ins("projects", {name: name})
  renderProject(project)
  $("#project_#{project.id}").hide()
  return project

renderWorkLogs = (server=null) ->
  $("#work_logs").html("")
  for work_log in db.find("work_logs", null, {order: {started_at: "desc"}, limit: 20})
    if !work_log.issue_id && server
      url = "#{server.domain}/api/v1/work_logs/#{work_log.server_id}.json?token=#{server.token}"
      $.get(url, (item) ->
        sync_item(server, "work_logs", item)
      )
    if work_log.issue_id != 0
      issue = db.one("issues", {id: work_log.issue_id})
    else
      issue = {title: "issue名取得中"}
    disp = "Start"
    btn_type = "btn-primary"
    if working_log() && working_log().issue_id == work_log.issue_id
      disp = "Stop"
      btn_type = "btn-warning"
    s = new Date(work_log.started_at*1000)
    $(".md_#{s.getMonth()+1}_#{s.getDate()}").append("<div>#{issue.title}</div>")
    $("#work_logs").append("""
      <tr class=\"work_log_#{work_log.id}\">
      <td class=\"word_break\">
      #{wbr(issue.title, 9)}
      </td>
      <td>
      #{dispDate(work_log)}
      </td>
      <td>
      <span class=\"time\">#{dispTime(work_log)}</span>
      </td>
      <td>
      #{if work_log.server_id then "" else uicon}
      <div class="work_log_#{work_log.id} issue_#{issue.id}" style=\"padding:10px;\">
      <a href=\"#\" class=\"card btn #{btn_type}\" data-issue-id=\"#{issue.id}\">#{disp}</a>
      </div>
      </td>
      </tr>
    """)

    $(".work_log_#{work_log.id} .card").click(() ->
      work_log_id = parseInt($(this).attr("data-issue-id"))
      doCard(work_log_id)
      return false
    )
    if false
      if !work_log.end_at
        wl = work_log


wbr = (str, num) ->
  return str.replace(RegExp("(\\w{" + num + "})(\\w)", "g"), (all,text,char) ->
    return text + "<wbr>" + char
  )

renderCalendars = () ->
  now = new Date()
  year = now.getYear() + 1900
  mon = now.getMonth() + 1
  renderCalendar("this_month", now)
  now = new Date(year, mon, 1)
  renderCalendar("next_month", now)

renderCalendar = (key, now) ->
  year = now.getYear() + 1900
  mon = now.getMonth() + 1
  day = now.getDate()
  wday = now.getDay()
  start = wday - day%7 -1
  w = 1
  $(".#{key} h2").html("#{year}-#{zp(mon)}")
  for i in [1..31]
    d = (i + start)%7 + 1
    $day = $(".#{key} table .w#{w} .d#{d}")
    $day.html(i).addClass("day#{i}")
    $day.css("background", "#fc0") if i == day && key == "this_month"
    $day.addClass("md_#{mon}_#{i}")
    w += 1 if d == 7
  renderWorkLogs()

renderWorkingLog = () ->
  wl = working_log()
  if wl
    time = dispTime(wl)
    $(".work_log_#{wl.id} .time").html(time)
    $("#issue_#{wl.issue_id} h2 .time").html("(#{time})")
    $("#issue_#{wl.issue_id} div div .card").html("Stop")
    issue = db.one("issues", {id: wl.issue_id})
    $(".hero-unit h1").html(issue.title)
    $(".hero-unit p").html(issue.body)
  $("title").html(time)

loopRenderWorkLogs = () ->
  renderWorkingLog()
  setTimeout(()->
    loopRenderWorkLogs()
  ,1000)

loopFetch = () ->
  for server in db.find("servers")
    fetch(server)
  setTimeout(()->
    loopFetch()
  ,1000*10)

last_fetch = (sec = null) ->
  setInfo("last_fetch", sec) if sec
  info = db.one("infos", {key: "last_fetch"})
  if info then info.val else 0

dispTime = (work_log) ->
  msec = 0
  if work_log.end_at
    sec = work_log.end_at - work_log.started_at 
  else
    sec = now() - work_log.started_at
  if sec > 3600
    hour = parseInt(sec/3600)
    min = parseInt((sec-hour*3600)/60)
    res = "#{zero(hour)}:#{zero(min)}:#{zero(sec - hour*3600 - min*60)}"
  else if sec > 60
    min = parseInt(sec/60)
    res = "#{zero(min)}:#{zero(sec - min*60)}"
  else
    res = "#{sec}秒"
  res

dispDate = (work_log) ->
  time = new Date(work_log.started_at*1000)
  "#{time.getMonth()+1}/#{time.getDate()}"


setInfo = (key, val) ->
  info = db.one("infos", {key: key})
  if info
    info.val = val
    info = db.upd("infos", info)
  else
    info = db.ins("infos", {key: key, val: val})
  info


db = JSRel.use("crowdsourcing", {
  schema: window.schema,
  autosave: true
})

hl = window.helpers

zero = (int) ->
  if int < 10 then "0#{int}" else int

now = () ->
  parseInt((new Date().getTime())/1000)

uicon = "<i class=\"icon-circle-arrow-up\"></i>"

turnback = ($e) ->
  if $e.css("display") == "none" then $e.fadeIn(400) else  $e.fadeOut(400)

findWillUploads = (table_name) ->
  db.find(table_name, {server_id: null})
  #db.find(table_name, {upd_at:{gt: last_fetch()}}) #こちらにすると自分担当の物もassignee_idが上書きされてアップされてしまうので注意

pushIfHasIssue = (project, projects) ->
  if db.one("issues", {project_id: project.id})
    project.local_id = project.id
    delete project.id
    projects.push(project)
  projects

findProjectByIssue = (issue) ->
  db.one("projects", {id: issue.project_id})

findIssueByWorkLog = (work_log) ->
  db.one("issues", {id: work_log.issue_id})

forUploadIssue = (issue) ->
  project = findProjectByIssue(issue)
  if project.server_id
    issue.project_server_id = project.server_id
  issue.local_id = issue.id
  delete issue.id
  return issue

forUploadWorkLog = (work_log) ->
  issue = findIssueByWorkLog(work_log)
  if issue.server_id
    work_log.issue_server_id = issue.server_id
  work_log.local_id = work_log.id
  delete work_log.id
  return work_log

debug = (title, data=null) ->
  console.log title
  console.log data if data

working_log = (issue_id=null, is_start=true) ->
  cond = {end_at: null}
  db.one("work_logs", cond)

cdown = () ->
  start = apDay(2007, 5, 11)
  end   = apDay(2017, 5, 11)
  $("#cdown").html("#{addFigure(start)}<br />#{addFigure(end)}")

apDay = (y,m,d) ->
  today = new Date()
  apday = new Date(y,m-1,d)
  dayms = 24 * 60 * 60 * 100
  n = Math.floor((apday.getTime()-today.getTime())/dayms) + 1
  return n

window.db = db

zp = (n) ->
  if n >= 10 then n else '0' + n

addFigure = (str) ->
  num = new String(str).replace(/,/g, "")
  while num != num.replace(/^(-?\d+)(\d{3})/, "$1,$2")
    num = num.replace(/^(-?\d+)(\d{3})/, "$1,$2")
  return num

$(() ->
  init()
)

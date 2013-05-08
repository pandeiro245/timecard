working_log = null

init = () ->
  #prepareNodeServer()
  prepareAddServer()
  prepareAddProject()
  renderProjects()
  renderIssues()
  renderWorkLogs()
  loopRenderWorkLogs()
  loopFetch()

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
      working_logs.push(db.one("work_logs", {server_id: parseInt(working_log_server_id)}))
  params = {
    token: token,
    last_fetch: last_fetch(),
    diffs: diffs,
    working_logs: working_logs
  }
  debug "fetch diffs", diffs
  url = "#{domain}/api/v1/diffs.json"
  $.post(url, params, (data) ->
    wlsis = db.one("infos", {key: "working_log_server_ids"})
    wlsis = db.ins("infos", {key: "working_log_server_ids"}) unless wlsis
    if data.working_log_server_ids
      wlsis.val = data.working_log_server_ids.join(",")
    db.upd("infos", wlsis)
    sync(server, "server_ids", data.server_ids)
    sync(server, "projects", data.projects)
    sync(server, "issues", data.issues)
    sync(server, "work_logs", data.work_logs)
    renderWorkLogs(server)
    last_fetch(now())
  )

sync = (server, table_name, data) ->
  if table_name == "server_ids"
    for table_name, server_ids of data
      for local_id, server_id of server_ids
        item = db.one(table_name, {id: local_id})
        if item
          item.server_id = server_id
          db.upd(table_name, item)
  else
    if data
      for i in data
        sync_item(server, table_name, i)

sync_item = (server, table_name, i) ->
  if i.project_id
    i.project_id = db.one("projects", {server_id: i.project_id}).id
  if i.issue_id
    issue = db.one("issues", {server_id: i.issue_id})
    if issue
      i.issue_id = issue.id
    else
      url = "#{server.domain}/api/v1/issues/#{i.issue_id}.json?token=#{server.token}"
      $.get(url, (item) ->
        sync_item(server, "issues", item)
      )
      i.issue_id = 0
  if i.closed_at > 0
    i.is_closed = true
  item = db.one(table_name, {server_id: i.id})
  if item
    i.id = item.id
    item = i
    db.upd(table_name, item)
  else
    i.server_id = i.id
    delete i.id
    item = db.ins(table_name, i)

renderProjects = () ->
  projects = db.find("projects", null, {order: {id: "asc"}})
  $("#issues").html("")
  for project in projects
    renderProject(project)
  hl.enter(".input", (e, target)->
    title = $(target).val()
    $project = $(target).parent().parent().parent()
    project_id = $project.attr("id").replace("project_","")
    if title.length > 0
      addIssue(project_id, title)
      $(target).val("")
    else
      alert "please input the title"
  )

prepareNodeServer = () ->
    if location.href.match("local") and !db.one("servers", {domain: ""}) 
      console.log location.href
      dbtype = "local"
      url = "/api/users.json"
      $.get(url, (data) ->
        console.log data
        console.log "aaa"
        server = db.ins("servers", {
          domain: "",
          user_id: data.id,
          has_connect: true,
          dbtype: dbtype
        })
      )

prepareAddServer = () ->
  hl.click(".add_server", (e, target)->
    domain = prompt('please input domain', 'http://crowdsourcing.dev')
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

renderProject = (project) ->
  $("#issues").append("""
    <div id=\"project_#{project.id}\"class=\"project\" style=\"display:none;\">
    <div class=\"span12\">
    <h1>
      #{project.name}#{if project.server_id then "" else uploading_icon}
    </h1>
    <div class=\"input-append\"> 
      <input type=\"text\" class=\"input\" />
      <input type=\"submit\" value=\"add issue\" class=\"btn\" />
    </div>
    </div>
    <div class=\"issues\"></div>
    </div>
  """)

renderIssues = (issues=null) ->
  issues = db.find("issues",{assignee_id: 1, closed_at: {le: 1}}, {order:{upd_at:"desc"}}) unless issues
  $(".issues").html("")
  i = 1
  for issue in issues
    renderIssue(issue, null, i) if !issue.is_ddt && !issue.will_start_on
    i = i + 0
  renderCards()

prepareCards = (issue_id) ->
  $(() ->
    $("#issue_#{issue_id} div div h2").click(() ->
      $e = $(this).parent().find(".body")
      turnback($e)
      return false
    )
    $("#issue_#{issue_id} div div .card").click(() ->
      renderCards(issue_id)
      return false
    )
    $("#issue_#{issue_id} div div .ddt").click(() ->
      renderDdt(issue_id)
      return false
    )
    $("#issue_#{issue_id} div div .cls").click(() ->
      renderCls(issue_id)
      return false
    )
  )

renderIssue = (issue, target=null, i = null) ->
  target = "append" unless target
  $project = $("#project_#{issue.project_id}")
  $project_issues = $("#project_#{issue.project_id} .issues")
  $project.fadeIn(200)
  title = "#{issue.title}"
  title = "<a class=\"title\" href=\"#\">#{issue.title}</a>" if issue.body && issue.body.length > 0
  icon = if issue.server_id then "" else uploading_icon
  start_or_end = if working_log && working_log.issue_id == issue.id then "Stop" else "Start"

  if i%4 == 1
    style = "style=\"margin-left:0;\""
  else
    style = ""

  umecob({use: 'jquery', tpl_id: "./partials/issue.html", data:{
    issue: issue,
    title: title,
    icon: icon,
    start_or_end: start_or_end,
    style: style
  }}).next((html) ->
    if target == "append"
      $project_issues.append(html)
    else
      $project_issues.prepend(html)
    $("issue_#{issue.id}").hide().fadeIn(200)
    prepareCards(issue.id)

  )

renderDdt = (issue_id) ->
  issue = db.one("issues", {id: issue_id})
  issue.is_ddt = true
  db.upd("issues", issue)
  $("#issue_#{issue.id}").fadeOut(200)

renderCls = (issue_id) ->
  issue = db.one("issues", {id: issue_id})
  issue.closed_at = now()
  db.upd("issues", issue)
  debug "renderCls", issue
  $("#issue_#{issue.id}").fadeOut(200)

renderCards = (issue_id = null) ->
  if working_log
    stopWorkLog() if issue_id
    if  parseInt(issue_id) != parseInt(working_log.issue_id)
      startWorkLog(issue_id)
    else
      working_log = null
  else
    if !issue_id
      $(".card").html("Start")
    else
      startWorkLog(issue_id)

stopWorkLog = () ->
  working_log.end_at = now()
  db.upd("work_logs", working_log)
  $("#issue_#{working_log.issue_id} .card").html("start")

startWorkLog = (issue_id = null) ->
  if issue_id && !working_log
    cond = {issue_id: issue_id, started_at: now(), user_id:0}
    working_log = db.one("work_logs", cond)
    working_log = db.ins("work_logs", cond) unless working_log
    $("#issue_#{issue_id} .card").html("stop")

addIssue = (project_id, title) ->
  issue = db.ins("issues", {title: title, project_id: project_id, body:"", assignee_id:1, user_id:1})
  renderIssue(issue, "prepend")

addProject = (name) ->
  project = db.ins("projects", {name: name})
  renderProject(project)
  $("#project_#{project.id}").fadeIn(200)
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
    stop = ""
    stop = "<a href=\"#\" class=\"cardw\">STOP</a>" unless work_log.end_at
    $("#work_logs").append("""
      <li class=\"work_log_#{work_log.id}\">
      #{issue.title}
      <span class=\"time\">#{dispTime(work_log)}</span>
      #{if work_log.server_id then "" else uploading_icon}
      #{stop}
      </li>
    """)
    $(".cardw").click(() ->
      issue_id = working_log.issue_id
      renderCards(issue_id)
      return false
    )
    if !work_log.end_at
      working_log = work_log

renderWorkingLog = () ->
  if working_log
    time = dispTime(working_log)
    $(".work_log_#{working_log.id} .time").html(time)
    $("#issue_#{working_log.issue_id} h2 .time").html("(#{time})")
    $("#issue_#{working_log.issue_id} div div .card").html("Stop")

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

uploading_icon = "<i class=\"icon-circle-arrow-up\"></i>"

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

debug = (title, data) ->
  console.log title
  console.log data

window.db = db

$(() ->
  init()
)

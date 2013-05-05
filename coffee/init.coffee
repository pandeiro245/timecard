working_log = null

init = () ->
  prepareAddServer()
  prepareAddProject()
  renderProjects()
  renderIssues()
  loopFetch()
  loopRenderWorkLogs()

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
  if wlsis
    for working_log_server_id in wlsis.val.split(",")
      working_logs.push(db.one("work_logs", {server_id: parseInt(working_log_server_id)}))

  params = {
    token: token,
    last_fetch: last_fetch(),
    diffs: diffs,
    working_logs: working_logs
  }

  debug "diffs", diffs
  debug "fetch at", now()
  url = "#{domain}/api/v1/diffs.json"
  $.post(url, params, (data) ->
    wlsis = db.one("infos", {key: "working_log_server_ids"})
    wlsis = db.ins("infos", {key: "working_log_server_ids",}) unless wlsis
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
        item.server_id = server_id
        db.upd(table_name, item)
  else
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
  if i.closed_at
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

prepareAddServer = () ->
  hl.click(".add_server", (e, target)->
    #domain = prompt('please input the domain', 'http://redmine.dev/')
    domain = prompt('please input the domain', 'http://crowdsourcing.dev')
    if domain.match("crowdsourcing") or domain.match("cs.mindia.jp")
      dbtype = "cs"
      token = prompt('please input the token', '83070ba0c407e9cc80978207e1ea36f66fcaad29b60d2424a7f1ea4f4e332c3c')
      url = "#{domain}/api/v1/users.json?token=#{token}"
      $.get(url, (data) ->
        db.ins("servers", {
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
    <div class="span12">
    <h1>
      #{project.name}#{if project.server_id then "" else uploading_icon}
    </h1>
    <div class=\"input-append\"> 
      <input type=\"text\" class=\"input\" />
      <input type=\"submit\" value=\"add issue\" class=\"btn\" />
    </div>
    </div>
    <div style=\"clear:both;\"></div>
    </div>
  """)

renderIssues = (issues=null) ->
  issues = db.find("issues",{is_closed: false, assignee_id: 1}, {order:{ins_at:"desc"}}) unless issues
  $(".issues").html("")
  for issue in issues
    renderIssue(issue) if !issue.is_ddt && !issue.will_start_on
  renderCards()
  $(() ->
    $(".issue .title").click(() ->
      $e = $(this).parent().find(".body")
      turnback($e)
      return false
    )
    $(".card").click(() ->
      issue_id = $(this).parent().parent().parent().attr("id").replace("issue_", "")
      renderCards(issue_id)
      return false
    )
    $(".ddt").click(() ->
      issue_id = $(this).parent().parent().parent().attr("id").replace("issue_", "")
      renderDdt(issue_id)
      return false
    )
  )

renderIssue = (issue, target="append") ->
  $project = $("#project_#{issue.project_id}")
  $project.fadeIn(200)
  title = "#{issue.title}"
  title = "<a class=\"title\" href=\"#\">#{issue.title}</a>" if issue.body && issue.body.length > 0
  icon = if issue.server_id then "" else uploading_icon
  umecob({use: 'jquery', tpl_id: "./partials/issue.html", data:{
    issue: issue,
    title: title,
    icon: icon
  }}).next((html) ->
    if target == "append"
      $project.append(html)
    else
      $project.prepend(html)
    $("issue_#{issue.id}").hide().fadeIn(200)
  )

renderDdt = (issue_id) ->
  issue = db.one("issues", {id: issue_id})
  issue.is_ddt = true
  db.upd("issues", issue)
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
  if issue_id
    working_log = db.ins("work_logs", {issue_id: issue_id})
    working_log.started_at = now()
    db.upd("work_logs", working_log)
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
    if !work_log.issue_id
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
      <li class=\"work_log_#{work_log.id}\">#{issue.title}
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
    $(".work_log_#{working_log.id} .time").html(dispTime(working_log))

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

$(() ->
  init()
)

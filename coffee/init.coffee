working_log = null
domain = null
token = null
last_fetch = null

getLastFetch = () ->
  info = db.one("infos", {key: "last_fetch"})
  if info then info.val else 0

getDomain = () ->
  info = db.one("infos", {key: "domain"})
  if !info or info.val.length < 10
    val = prompt('please input the domain', 'http://crowdsourcing.dev')
    info = setInfo("domain", val)
  return info.val

getToken = () ->
  info = db.one("infos", {key: "token"})
  if location.hash && location.hash.length > 10
    val = location.hash.replace(/#/,"")
    info = setInfo("token",val)
  else if !info or  info.val.length < 10
    location.href = "#{domain}/token?url=#{location.href}"
  return info.val

init = () ->
  prepareAddProject()
  domain = getDomain() unless domain
  token = getToken() unless token
  last_fetch = getLastFetch() unless last_fetch
  renderProjects()
  renderIssues()
  #fetch()
  #loopFetch()
  loopRenderWorkLogs()

fetch = () ->
  projects = []
  issues = []
  work_logs = []
  for project in db.find("projects", {server_id: null})
    has_issue = db.one("issues", {project_id: project.id})
    if has_issue
      project.local_id = project.id
      delete project.id
      projects.push(project) 
  for issue in db.find("issues", {server_id: null})
    project = db.one("projects", {id: issue.project_id})
    issue.project_server_id = project.server_id if project.server_id
    issue.local_id = issue.id
    delete issue.id
    issues.push(issue)
  for work_log in db.find("work_logs", {server_id: null})
    issue = db.one("issues", {id: work_log.issue_id})
    work_log.issue_server_id = issue.server_id if issue.server_id
    work_log.local_id = work_log.id
    delete work_log.id
    work_logs.push(work_log)

  diffs =  {
    projects: projects,
    issues: issues,
    work_logs: work_logs
  }

  working_logs = []
  wlsis = db.one("infos", {key: "working_log_server_ids"})
  if wlsis
    console.log wlsis
    for working_log_server_id in wlsis.val.split(",")
      working_logs.push(db.one("work_logs", {server_id: parseInt(working_log_server_id)}))

  params = {
    token: token,
    last_fetch: last_fetch,
    diffs: diffs,
    working_logs: working_logs
  }

  debug "diffs", diffs
  debug "fetch at", now()
  url = "#{domain}/api/v1/diffs.json"
  $.post(url, params, (data) ->
    debug "fetch callback", data
    wlsis = db.one("infos", {key: "working_log_server_ids"})
    wlsis = db.ins("infos", {key: "working_log_server_ids",}) unless wlsis
    wlsis.val = data.working_log_server_ids.join(",")
    db.upd("infos", wlsis)
    sync("server_ids", data.server_ids)
    sync("projects", data.projects)
    sync("issues", data.issues)
    sync("work_logs", data.work_logs)
    last_fetch = now()
    setInfo("last_fetch", last_fetch)
  )

sync = (table_name, data) ->
  if table_name == "server_ids"
    for table_name, server_ids of data
      for local_id, server_id of server_ids
        item = db.one(table_name, {id: local_id})
        item.server_id = server_id
        db.upd(table_name, item)
  else
    for i in data
      sync_item(table_name, i)
    debug "sync is done", data

sync_item = (table_name, i) ->
  if i.project_id
    i.project_id = db.one("projects", {server_id: i.project_id}).id
  if i.issue_id
    issue = db.one("issues", {server_id: i.issue_id})
    if issue
      i.issue_id = issue.id
    else
      url = "#{domain}/api/v1/issues/#{i.issue_id}.json?token=#{token}"
      $.get(url, (item) ->
        sync_item("issues", item)
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
  if i.is_github
    db.ins("server_issues", {server_id: 1, issue_id: item.id, issue_server_id: i.github_issue_id})
  if i.github_repository_id
    project = db.one("projects", {id: item.project_id})
    cond = {server_id: 1, project_id: project.id, project_server_id: i.github_repository_id }
    server_project = db.one("server_projects", cond)
    db.ins("server_projects", cond)

renderProjects = (projects=null) ->
  projects = db.find("projects") unless projects
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
  title = "#{issue.title} #{issue.is_ddt}"
  title = "<a class=\"title\" href=\"#\">#{issue.title}</a>" if issue.body && issue.body.length > 0
  html = """
    <div id=\"issue_#{issue.id}\" class=\"issue span3\">
      <h2>#{title}
      #{if issue.server_id then "" else uploading_icon}
      </h2>
      <div class="btn-toolbar">
      <div class="btn-group">
      <a class=\"card btn\" href="#"></a>
      <a class=\"ddt btn\" href="#">DDT</a>
      <a class=\"cls btn\" href="#">close</a>
      <div class=\"body\">#{issue.body}</div>
      </div>
      </div>
    </div>
  """
  if target == "append"
    $project.append(html)
  else
    $project.prepend(html)
  $("issue_#{issue.id}").hide().fadeIn(200)

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
      $(".card").html("start")
    else
      startWorkLog(issue_id)
  renderWorkLogs()

stopWorkLog = () ->
  working_log.end_at = now()
  db.upd("work_logs", working_log)
  $("#issue_#{working_log.issue_id} .card").html("start")

startWorkLog = (issue_id = null) ->
  debug "startWorkLog", issue_id
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
  #renderProject(project)
  renderProjects()
  $("#project_#{project.id}").fadeIn(200)
  return project

renderWorkLogs = () ->
  $("#work_logs").html("")
  title = "crowdsourciing"
  for work_log in db.find("work_logs", null, {order: {started_at: "desc"}, limit: 20})
    if !work_log.issue_id
      url = "#{domain}/api/v1/work_logs/#{work_log.server_id}.json?token=#{token}"
      $.get(url, (item) ->
        sync_item("work_logs", item)
      )
    if work_log.issue_id != 0
      issue = db.one("issues", {id: work_log.issue_id})
    else
      issue = {title: "issue名取得中"}
    stop = ""
    stop = "<a href=\"#\" class=\"cardw\">STOP</a>" unless work_log.end_at
    $("#work_logs").append("""
      <li>#{issue.title} #{dispTime(work_log)}
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
      title = dispTime(work_log)
      working_log = work_log
  title

loopRenderWorkLogs = () ->
  window.title = renderWorkLogs()
  setTimeout(()->
    loopRenderWorkLogs()
  ,1000)

loopFetch = () ->
  if last_fetch > 0
    fetch()
    setTimeout(()->
      loopFetch()
    ,1000*10)

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

schema = {
  servers: {
    domain: "",
    $uniques: "domain",
  }
  users: {
    server_id:0,
    name: ""
    #$uniques: "server_id"
  }
  projects: {
    name: ""
    body: "",
    server_id: 0,
    #$uniques: "server_id"
  },
  issues: {
    title: ""
    body: "",
    project_id: 0,
    server_id: 0,
    is_ddt: "off",
    is_closed: "off",
    user_id: 0,
    assignee_id: 0,
    will_start_on: "",
    #$uniques: "server_id"
  },
  work_logs: {
    issue_id: 0
    started_at: 0,
    end_at: 0,
    server_id: 0,
    #$uniques: "server_id"
  },
  work_comments: {
    issue_id: 0,
    user_id: 0,
    body: "",
  },
  infos: {
    key: "",
    val: "",
    $uniques: "key"
  },
  server_projects:{
    server_id: 0,
    project_id: 0,
    project_server_id: 0
  },
  server_issues:{
    server_id: 0,
    issue_id: 0,
    issue_server_id: 0,
  },
}

db = JSRel.use("crowdsourcing", {
  schema: schema,
  autosave: true
})

hl = window.helpers

zero = (int) ->
  if int < 10 then "0#{int}" else int

now = () ->
  parseInt((new Date().getTime())/1000)

uploading_icon = "<i class=\"icon-circle-arrow-up\"></i>"

turnback = ($e) ->
  if $e.css("display") == "none"
    $e.fadeIn(400)
  else
    $e.fadeOut(400)

debug = (title, data) ->
  console.log title
  console.log data

$(() ->
  init()
)

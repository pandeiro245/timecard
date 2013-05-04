working_log = null
domain = null
token = null
last_fetch = null

getLastFetch = () ->
  info = db.one("infos", {key: "last_fetch"})
  if info then info.val else 0

getDomain = () ->
  info = db.one("infos", {key: "domain"})
  if !info or  info.val.length < 10
    val = prompt('please input the domain', 'http://crowdsourcing.dev')
    info = setInfo("domain", val)
  return info.val

getToken = () ->
  info = db.one("infos", {key: "token"})
  if !info or  info.val.length < 10
    val = prompt('please input your API token', '')
    info = setInfo("token",val)
  return info.val

init = () ->
  #setInfo("last_fetch", 0)
  domain = getDomain() unless domain
  token = getToken() unless token
  last_fetch = getLastFetch() unless last_fetch
  renderProjects()
  renderIssues()
  fetch()
  loopFetch()
  loopRenderWorkLogs()

fetch = () ->
  projects = []
  issues = []
  work_logs = []
  for p in db.find("projects")
    project = db.one("issues", {project_id: p.id})
    projects.push(p) if project && !project.server_id
  for i in db.find("issues")
    issues.push(i) if !i.server_id
  for w in db.find("work_logs")
    work_logs.push(w) if !w.server_id
  diffs =  {
    projects: projects,
    issues: issues,
    work_logs: work_logs
  }
  params = {
    token: token,
    last_fetch: last_fetch,
    diffs: diffs
  }
  console.log "fetch at #{now()}"
  url = "#{domain}/api/v1/diffs.json"
  $.post(url, params, (data) ->
    sync("server_ids", data.server_ids)
    sync("projects", data.projects)
    sync("issues", data.issues)
    sync("work_logs", data.work_logs)
    last_fetch = parseInt(new Date().getTime())
    setInfo("last_fetch", last_fetch)
  )

sync = (table_name, data) ->
  if table_name == "server_ids"
    for table_name, local_ids of data 
      for local_id, server_id of local_ids
        item = db.one(table_name, {id: local_id})
        item.server_id = server_id
        db.upd(table_name, item)
  else
    for i in data
      if i.project_id
        i.project_id = db.one("projects", {server_id: i.project_id}).id
      if i.issue_id
        issue = db.one("issues", {server_id: i.issue_id})
        i.issue_id = issue.id
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
    console.log "sync is done"

renderProjects = (projects=null) ->
  projects = db.find("projects") unless projects
  $("#projects-tab").html("<div id=\"new_project\"></div>")
  $("#new_project").html("""
      <input type=\"text\" class=\"input\" />
      <input type=\"submit\" value=\"add project\" />
  """)
  for project in projects
    renderProject(project)
  hl.enter(".input", (e, target)->
    title = $(target).val()
    $project = $(target).parent()
    if $project.attr("id").match("project_")
      project_id = $project.attr("id").replace("project_","")
      if title.length > 0
        addIssue(project_id, title)
        $(target).val("")
      else
        alert "please input the title"
    else #new_project
      if title.length > 0
        addProject(title)
        $(target).val("")
      else
        alert "please input the title"
  )

renderProject = (project) ->
  $("#projects-tab").append("""
    <div id=\"project_#{project.id}\" class=\"project\">
      <h1>#{project.name}</h1>
      <input type=\"text\" class=\"input\" />
      <input type=\"submit\" value=\"add issue\" />
      <div class="issues"></div>
    </div>
  """)

renderIssues = (issues=null) ->
  issues = db.find("issues",{is_closed: false, assignee_id: 1}) unless issues
  $(".issues").html("")
  for issue in issues
    renderIssue(issue) if !issue.is_ddt
  renderCards()
  $(() ->
    $(".issue .title").click(() ->
      $e = $(this).parent().find(".body")
      if $e.css("display") == "none"
        $e.css("display", "block")
      else
        $e.css("display", "none")
      return false
    )
    $(".card").click(() ->
      issue_id = $(this).parent().attr("id").replace("issue_", "")
      renderCards(issue_id)
      return false
    )
    $(".ddt").click(() ->
      issue_id = $(this).parent().attr("id").replace("issue_", "")
      renderDdt(issue_id)
      return false
    )
  )

renderIssue = (issue) ->
  $project = $("#project_#{issue.project_id}")
  $project.css("display", "block")
  title = "#{issue.title} #{issue.is_ddt}"
  title = "<a class=\"title\" href=\"#\">#{issue.title}</a>" if issue.body && issue.body.length > 0
  $project.append("""
    <div id=\"issue_#{issue.id}\" class=\"issue\">
      #{title} 
      <a class=\"card\" href="#"></a>
      <a class=\"ddt\" href="#">DDT</a>
      <div class=\"body\">#{issue.body}</div>
    </div>
  """)

renderDdt = (issue_id) ->
  issue = db.one("issues", {id: issue_id})
  issue.is_ddt = true
  db.upd("issues", issue)
  $("#issue_#{issue.id}").css("display", "none")

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
  console.log work_log
  working_log.end_at = now()
  db.upd("work_logs", working_log)
  $("#issue_#{working_log.issue_id} .card").html("start")

startWorkLog = (issue_id = null) ->
  if issue_id
    working_log = db.ins("work_logs", {issue_id: issue_id})
    working_log.started_at = working_log.ins_at
    db.upd("work_logs", working_log)
    $("#issue_#{issue_id} .card").html("stop")

addIssue = (project_id, title) ->
  issue = db.ins("issues", {title: title, project_id: project_id, body:"", assignee_id:1, user_id:1})
  renderIssue(issue)

addProject = (name) ->
  project = db.ins("projects", {name: name})
  #renderProject(project)
  renderProjects()
  $("#project_#{project.id}").css("display", "block")

renderWorkLogs = () ->
  $("#work_logs").html("")
  title = "crowdsourciing"
  for work_log in db.find("work_logs")
    if !work_log.issue_id
      url = "#{domain}/api/v1/work_logs/#{work_log.server_id}.json?token=#{token}"
      $.get(url, (data) ->
        issue = db.one("issues", {server_id: data.id})
        work_log.issue_id = issue.id
        db.upd("work_logs", work_log)
      )
    console.log work_log
    issue = db.one("issues", {id: work_log.issue_id})
    stop = ""
    stop = "<a href=\"#\" class=\"cardw\">STOP</a>" unless work_log.end_at
    $("#work_logs").prepend("""
      <div>#{issue.title} #{dispTime(work_log)}</div>#{stop}
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
    msec = work_log.end_at - work_log.started_at 
  else
    msec = parseInt(new Date().getTime()) - work_log.started_at
  sec = parseInt((msec)/1000)
  if sec > 60
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
  }
  infos: {
    key: "",
    val: "",
    $uniques: "key"
  }
}

db = JSRel.use("crowdsourcing", {
  schema: schema,
  autosave: true
})

hl = window.helpers

zero = (int) ->
  if int < 10 then "0#{int}" else int

now = () ->
  new Date().getTime()

$(() ->
  init()
)

working_log = null

init = () ->
  renderProjects()
  renderIssues()
  fetch()

fetch = () ->
  url = "http://crowdsourcing.dev/api/v1/projects.json?device_token=1"
  $.get(url, (projects) ->
    syncProjects(projects)
    renderProjects(projects)
    url = "http://crowdsourcing.dev/api/v1/issues.json?device_token=1"
    $.get(url, (issues) ->
      syncIssues(issues)
      renderIssues(issues)
    )
  )

syncProjects = (projects) ->
  for p in projects
    cond = {server_id: p.id}
    project = db.one("projects", cond)
    if project
      db.upd("projects", project)
    else
      cond.name = p.name
      cond.body = p.body
      db.ins("projects", cond)

syncIssues = (issues) ->
  for i in issues
    cond = {server_id: i.id}
    issue = db.one("issues", cond)
    cond.title = i.title
    cond.project_id = db.one("projects", {server_id: i.project_id}).id
    cond.body = i.body
    if issue
      db.upd("issues", issue)
    else
      db.ins("issues", cond)


renderProjects = (projects) ->
  projects = db.find("projects")
  $("#projects-tab").html("")
  for project in projects
    $("#projects-tab").append("""
      <div id=\"project_#{project.id}\" class=\"project\">
        <h1>#{project.name}</h1>
        <input type=\"text\" class=\"input\" />
        <input type=\"submit\" value=\"add issue\" />
        <div class="issues"></div>
      </div>
    """)

  hl.enter(".input", (e, target)->
    project_id = $(target).parent().attr("id").replace("project_","")
    title = $(target).val()
    if title.length > 0
      addIssue(project_id, title)
      $("#input").val("")
    else
      alert "please input the title"
  )


renderIssues = (issues) ->
  issues = db.find("issues")
  $(".issues").html("")
  for issue in issues
    renderIssue(issue)
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
  )

renderIssue = (issue) ->
  $project = $("#project_#{issue.project_id}")
  $project.css("display", "block")
  title = issue.title
  title = "<a class=\"title\" href=\"#\">#{issue.title}</a>" if issue.body.length > 0
  $project.append("""
    <div id=\"issue_#{issue.id}\" class=\"issue\">
      #{title} 
      <a class=\"card\" href="#"></a>
      <div class=\"body\">#{issue.body}</div>
    </div>
  """)

renderCards = (issue_id = null) ->
  if !issue_id 
    $(".card").html("start")
  else
    if working_log
      stopWorkLog()
      if  Math.floor(issue_id) != Math.floor(working_log.issue_id)
        startWorkLog(issue_id)
      else
        working_log = null
    else
      startWorkLog(issue_id)
  renderWorkLogs()

stopWorkLog = () ->
  working_log.end_at = new Date().getTime()
  db.upd("work_logs", working_log)
  $("#issue_#{working_log.issue_id} .card").html("start")

startWorkLog = (issue_id) ->
  working_log = db.ins("work_logs", {issue_id: issue_id})
  working_log.started_at = working_log.ins_at
  db.upd("work_logs", working_log)
  $("#issue_#{issue_id} .card").html("stop")

addIssue = (project_id, title) ->
  issue = db.ins("issues", {title: title, project_id: project_id, body:""})
  renderIssue(issue)

renderWorkLogs = () ->
  $("#work_logs").html("")
  for work_log in db.find("work_logs")
    issue = db.one("issues", work_log.issue_id)
    $("#work_logs").prepend("""
      <div>#{issue.title} #{parseInt((work_log.end_at - work_log.started_at)/1000)}</div>
    """)

schema = {
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
    #$uniques: "server_id"
  },
  work_logs: {
    issue_id: 0
    started_at: 0,
    end_at: 0,
  }
}

db = JSRel.use("crowdsourcing", {
  schema: schema,
  autosave: true
})

hl = window.helpers

$(() ->
  init()
)

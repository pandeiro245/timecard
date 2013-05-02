init = () ->
  renderProjects()
  renderIssues()
  fetch()

fetch = () ->
  url = "http://crowdsourcing.dev/api/v1/projects.json?device_token=1"
  $.get(url, (projects) ->
    syncProjects(projects)
    renderProjects(projects)
  )
  url = "http://crowdsourcing.dev/api/v1/issues.json?device_token=1"
  $.get(url, (issues) ->
    syncIssues(issues)
    renderIssues(issues)
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
    cond.project_id = i.project_id
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
      <div id=\"project_#{project.server_id}\" class=\"project\">
        <h1>#{project.name}</h1>
        <input type=\"text\" class=\"input\" />
        <input type=\"submit\" value=\"add issue\" />
        <div class="issues"></div>
      </div>
    """)

  hl.enter(".input", (e, target)->
    project_id = $(target).parent().attr("id").replace("project_","")
    console.log project_id
    title = $(target).val()
    console.log title
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
  $(() ->
    $(".issue .title").click(() ->
      $e = $(this).parent().find(".body")
      if $e.css("display") == "none"
        $e.css("display", "block")
      else
        $e.css("display", "none")
      return false
    )
  )

renderIssue = (issue) ->
  $project = $("#project_#{issue.project_id}")
  $project.css("display", "block")
  title = issue.title
  title = "<a class=\"title\" href=\"#\">#{issue.title}</a>" if issue.body.length > 0
  $project.append("""
    <div id=\"issue_#{issue.server_id}\" class=\"issue\">
      #{title} 
      <div class=\"body\">#{issue.body}</div>
    </div>
  """)

addIssue = (project_id, title) ->
  issue = db.ins("issues", {title: title, project_id: project_id, body:""})
  renderIssue(issue)

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

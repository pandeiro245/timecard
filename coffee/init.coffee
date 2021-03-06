init = () ->
  cdown()
  #prepareNodeServer()
  prepareShowProjects()
  #prepareAddServer()
  prepareDoExport()
  prepareDoImport()
  renderProjects()
  renderWorkLogs()
  #renderCalendars()
  $(".calendar").hide()
  loopRenderWorkLogs()
  #loopFetch()

renderProjects = () ->
  projects = new Project().find_all()
  projectsView = new ProjectsView({
    collection: projects
  })
  addProjectView = new AddProjectView({
    collection: projects
  })
  $("#wrapper").html(projectsView.render().el)
  issues = new Issue().find_all()
  for issue in issues.models
    issueView = new IssueView({
      model: issue
      id   : "issue_#{issue.id}"
    })
    $("#project_#{issue.get('project_id')} div .issues").append(
      issueView.render().el
    )

prepareShowProjects = () ->
  $(".show_projects").click(() ->
    $(".project").fadeIn(100)
    $(".issue").fadeIn(100)
  )

prepareDoExport = () ->
  hl.click(".do_export", (e, target)->
    result = {
      projects : db.find("projects"),
      issues   : db.find("issues"),
      work_logs: db.find("work_logs"),
      servers  : db.find("servers"),
      infos    : db.find("infos"),
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

innerLink = () ->
  res = "<div class=\"innerlink\"> | "
  projects = Project.find_all
  for project in projects
    res += "<span class=\"project_#{project.id}\"><a href=\"#project_#{project.id}\">#{project.name}</a> | </span>"
  res += "</div>"
  return res

doDdtProject = (project_id) ->
  for issue in db.find("issues", {project_id: project_id})
    doDdt(issue.id) if issue.will_start_at < now()

@doCard = (issue_id = null) ->
  updateWorkingLog(null, issue_id)

startWorkLog = (issue_id) ->
  updateWorkingLog(true, issue_id)

@stopWorkLog = () ->
  updateWorkingLog(false) if working_log()

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
    $issue_cards.html("Stop")
    $issue_cards.removeClass("btn-primary")
    $issue_cards.addClass("btn-warning")
  renderWorkLogs()

@addIssue = (project_id, title) ->
  issue = db.ins("issues", {title: title, project_id: project_id, body:""})
  renderIssue(issue, "prepend")

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

@now = () ->
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

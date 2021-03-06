JSRel = require('jsrel')
express = require("express")
app = express()
app.use(express.bodyParser())
http = require('http')
server = http.createServer(app)
io = require('socket.io').listen(server)

app.get('*', (req, res) ->
  if req.url == "/node_dev"
    node_dev(req, res)
  else if req.url == "/projects"
    node_projects(req, res)
  else if req.url == "/issues"
    node_issues(req, res)
  else if req.url == "/work_logs"
    node_work_logs(req, res)
  else if req.url.match("api")
    api(req, res)
  else
    res.sendfile(__dirname + "/public" + req.url)
)

app.post('*', (req, res) ->
  api(req, res)
)

api = (req, res) ->
  if req.url.match("users")
    body = JSON.stringify({id: 1})
  else if(req.url.match("diff"))
    save_diffs(req.body)
    body = JSON.stringify(callback(req.body.last_fetch))
  else
    body = JSON.stringify({id: req.query["id"]})
  res.setHeader('Content-Type', 'application/json')
  res.setHeader('Access-Control-Allow-Origin', '*')
  #res.setHeader('Content-Length', body.length)
  res.end(body)

save_diffs = (data) ->
  ###
  db.del("projects")
  db.del("issues")
  db.del("work_logs")
  JSRel.free("crowdsourcing3")
  ###
  server = null
  if data.diffs
    sync(server, "projects", data.diffs.projects)
    sync(server, "issues", data.diffs.issues)
    sync(server, "work_logs", data.diffs.work_logs)

schema = {
  servers: {
    domain: "",
    login: "",
    pass: "",
    token: "",
    user_id: 0,
    dbtype: "",
    has_connect: "off",
    $uniques: "domain",
  },
  projects: {
    name: "",
    body: "",
    url: "",
    server_id: 0,
    origin_at: 0,
  },
  issues: {
    title: "",
    body: "",
    project_id: 0,
    server_id: 0,
    is_ddt: "off",
    closed_at: 0,
    user_id: 0,
    url: "",
    assignee_id: 0,
    will_start_on: "",
    parent_id:0,
    origin_at: 0,
  },
  work_logs: {
    issue_id: 0,
    started_at: 0,
    end_at: 0,
    server_id: 0,
    user_id: 0,
  },
  infos: {
    key: "",
    val: "",
    $uniques: "key"
  },
}

working_log = null

#fetch = () ->
callback = (last_fetch) ->
  projects = []
  issues = []
  work_logs = []
  projects = db.find("projects", { upd_at: {le: last_fetch}})
  if projects[0]
    for project in projects
      delete project.ins_at
      delete project.upd_at
      project.server_id = project.id
      project.local_id = project.server_id
      projects.push(project)
  issues = db.find("issues", { upd_at: {le: last_fetch}})
  if issues
    for issue in issues
      delete issue.ins_at
      delete issue.upd_at
      issue.server_id = issue.id
      issue.local_id = issue.server_id
      issues.push(issue)
  work_logs = db.find("work_logs", { upd_at: {le: last_fetch}})
  if work_logs
    for work_log in work_logs
      delete work_log.ins_at
      delete work_log.upd_at
      work_log.server_id = work_log.id
      work_log.local_id = work_log.server_id
      work_logs.push(work_log)

  project_ids = {}
  issue_ids = {}
  work_log_ids = {}
  for project in projects
    project_ids[project.server_id] = project.id
  for issue in issues
    issue_ids[issue.server_id] = issue.id
  for work_log in work_logs
    work_log_ids[work_log.server_id] = work_log.id

  server_ids = {
    projects:  project_ids,
    issue:  issue_ids,
    work_logs:  work_log_ids
  }
  res =  {
    projects: projects,
    issues: issues,
    work_logs: work_logs,
    server_ids: server_ids
  }
  return res

sync = (server, table_name, data) ->
  if table_name == "server_ids"
    for table_name, server_ids of data
      for local_id, server_id of server_ids
        item = db.one(table_name, {id: local_id})
        item.server_id = server_id
        db.upd(table_name, item)
  else
    if data
      for i in data
        sync_item(server, table_name, i)

sync_item = (server, table_name, i) ->
  if i.project_id
    project = db.one("projects", {server_id: parseInt(i.project_id)})
    i.project_id = project.id
  if i.issue_id
    issue = db.one("issues", {server_id: parseInt(i.issue_id)})
    if issue
      i.issue_id = issue.id
  item = db.one(table_name, {server_id: i.local_id})
  if item
    i.id = item.id
    item = i
    db.upd(table_name, item)
  else
    i.server_id = parseInt(i.local_id)
    delete i.local_id
    is_new = true
    if table_name == "projects"
      is_new = false if db.one("projects", {name: i.name, origin_at: parseInt(i.ins_at)})
    if table_name == "issues"
      is_new = false if db.one("issues", {title: i.title, origin_at: parseInt(i.ins_at)})
    if table_name == "work_logs"
      is_new = false if db.one("work_logs", {started_at: parseInt(i.started_at)})
    if is_new
      if table_name == "projects" or table_name == "issues"
        i.origin_at = i.ins_at
      item = db.ins(table_name, i)

addIssue = (project_id, title) ->
  issue = db.ins("issues", {title: title, project_id: project_id, body:"", assignee_id:1, user_id:1})
  renderIssue(issue, "prepend")

addProject = (name) ->
  project = db.ins("projects", {name: name})
  renderProject(project)
  $("#project_#{project.id}").fadeIn(200)
  return project


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

db = JSRel.use("crowdsourcing3", {
  schema: schema,
  autosave: true
})

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

buffer = []
io.sockets.on('connection', (client)->
  clientId = 'User'+client.id.substr(client.id.length-3,3)

  client.broadcast.emit('connect',clientId + ' connected')
  client.emit('message',{'messages':buffer})

  client.on('message', (message)->
    msg = { user: clientId, message: message}
    buffer.push(msg)
    if (buffer.length > 15)
      buffer.shift()
      client.broadcast.emit('message',{'messages':[msg]})
  )
  client.on('disconnect', ()->
    client.broadcast.emit('disconnect',clientId + ' disconnected')
  )
)
#app.listen(3000)

node_dev = (req, res)->
  body = "<a href=\"/\">back</a>"
  body += "<hr />"
  for i in req
    body += i + ' is ' + req[i]
    body += "<br />"
  body += "<hr />"
  body += "<a href=\"/\">back</a>"
  res.setHeader('Content-Type', 'text/html')
  res.setHeader('Content-Length', body.length)
  res.end(body)

node_projects = (req, res)->
  body = "<meta charset=\"UTF-8\" /><a href=\"/\">back</a>"
  body += "<hr />"
  for project in db.find("projects")
    body += "<h2>#{project.name}</h2>"
    for key, val of project
      body += "#{key} : #{val}<br />" unless key == "name"

  body += "<hr />"
  body += "<a href=\"/\">back</a>"
  res.setHeader('Content-Type', 'text/html')
  res.setHeader('Content-Length', body.length)
  res.end(body)

node_issues = (req, res)->
  body = "<meta charset=\"UTF-8\" /><a href=\"/\">back</a>"
  body += "<hr />"
  for issue in db.find("issues")
    body += "<h2>#{issue.title}</h2>"
    for key, val of issue
      body += "#{key} : #{val}<br />" unless key == "title"

  body += "<hr />"
  body += "<a href=\"/\">back</a>"
  res.setHeader('Content-Type', 'text/html')
  res.setHeader('Content-Length', body.length)
  res.end(body)

node_work_logs = (req, res)->
  body = "<meta charset=\"UTF-8\" /><a href=\"/\">back</a>"
  body += "<hr />"
  for work_log in db.find("work_logs")
    body += "<h2>#{work_log.title}</h2>"
    for key, val of work_log
      body += "#{key} : #{val}<br />" unless key == "title"

  body += "<hr />"
  body += "<a href=\"/\">back</a>"
  res.setHeader('Content-Type', 'text/html')
  res.setHeader('Content-Length', body.length)
  res.end(body)

server.listen(3000)

###
class Server extends JSRelModel
  #for JSRelmodel start
  table_name: "servers"
  thisclass:  (params) ->
    return new Server(params)
  collection: (params) ->
    return new Servers(params)
  #for JSRelmodel end

  fetch: () ->
    server = this.toJSON()
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

  updtWorkLogServerIds: (data) ->
    if data.working_log_server_ids
      wlsis = db.one("infos", {key: "working_log_server_ids"})
      unless wlsis
        wlsis = db.ins("infos",
          {key: "working_log_server_ids"}
        )
      wlsis.val = data.working_log_server_ids.join(",")
      db.upd("infos", wlsis)

  sync:  (server, table_name, data) ->
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

  sync_item: = (server, table_name, i) ->
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

  prepareNodeServer: () ->
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

  prepareAddServer: () ->
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



class Servers extends Backbone.collection
  model: Server

@Server = Server
@Servers = Servers
###

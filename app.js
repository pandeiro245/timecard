(function() {
  var JSRel, addIssue, addProject, api, app, buffer, callback, db, dispTime, express, findIssueByWorkLog, findProjectByIssue, findWillUploads, forUploadIssue, forUploadWorkLog, http, io, last_fetch, node_dev, node_issues, node_projects, node_work_logs, now, pushIfHasIssue, save_diffs, schema, server, setInfo, sync, sync_item, turnback, uploading_icon, working_log, zero;

  JSRel = require('jsrel');

  express = require("express");

  app = express();

  app.use(express.bodyParser());

  http = require('http');

  server = http.createServer(app);

  io = require('socket.io').listen(server);

  app.get('*', function(req, res) {
    if (req.url === "/node_dev") {
      return node_dev(req, res);
    } else if (req.url === "/projects") {
      return node_projects(req, res);
    } else if (req.url === "/issues") {
      return node_issues(req, res);
    } else if (req.url === "/work_logs") {
      return node_work_logs(req, res);
    } else if (req.url.match("api")) {
      return api(req, res);
    } else {
      return res.sendfile(__dirname + "/public" + req.url);
    }
  });

  app.post('*', function(req, res) {
    return api(req, res);
  });

  api = function(req, res) {
    var body;

    if (req.url.match("users")) {
      body = JSON.stringify({
        id: 1
      });
    } else if (req.url.match("diff")) {
      save_diffs(req.body);
      body = JSON.stringify(callback(req.body.last_fetch));
    } else {
      body = JSON.stringify({
        id: req.query["id"]
      });
    }
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Access-Control-Allow-Origin', '*');
    return res.end(body);
  };

  save_diffs = function(data) {
    /*
    db.del("projects")
    db.del("issues")
    db.del("work_logs")
    JSRel.free("crowdsourcing3")
    */
    server = null;
    if (data.diffs) {
      sync(server, "projects", data.diffs.projects);
      sync(server, "issues", data.diffs.issues);
      return sync(server, "work_logs", data.diffs.work_logs);
    }
  };

  schema = {
    servers: {
      domain: "",
      login: "",
      pass: "",
      token: "",
      user_id: 0,
      dbtype: "",
      has_connect: "off",
      $uniques: "domain"
    },
    projects: {
      name: "",
      body: "",
      url: "",
      server_id: 0,
      origin_at: 0
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
      parent_id: 0,
      origin_at: 0
    },
    work_logs: {
      issue_id: 0,
      started_at: 0,
      end_at: 0,
      server_id: 0,
      user_id: 0
    },
    infos: {
      key: "",
      val: "",
      $uniques: "key"
    }
  };

  working_log = null;

  callback = function(last_fetch) {
    var issue, issue_ids, issues, project, project_ids, projects, res, server_ids, work_log, work_log_ids, work_logs, _i, _j, _k, _l, _len, _len1, _len2, _len3, _len4, _len5, _m, _n;

    projects = [];
    issues = [];
    work_logs = [];
    projects = db.find("projects", {
      upd_at: {
        le: last_fetch
      }
    });
    if (projects[0]) {
      for (_i = 0, _len = projects.length; _i < _len; _i++) {
        project = projects[_i];
        delete project.ins_at;
        delete project.upd_at;
        project.server_id = project.id;
        project.local_id = project.server_id;
        projects.push(project);
      }
    }
    issues = db.find("issues", {
      upd_at: {
        le: last_fetch
      }
    });
    if (issues) {
      for (_j = 0, _len1 = issues.length; _j < _len1; _j++) {
        issue = issues[_j];
        delete issue.ins_at;
        delete issue.upd_at;
        issue.server_id = issue.id;
        issue.local_id = issue.server_id;
        issues.push(issue);
      }
    }
    work_logs = db.find("work_logs", {
      upd_at: {
        le: last_fetch
      }
    });
    if (work_logs) {
      for (_k = 0, _len2 = work_logs.length; _k < _len2; _k++) {
        work_log = work_logs[_k];
        delete work_log.ins_at;
        delete work_log.upd_at;
        work_log.server_id = work_log.id;
        work_log.local_id = work_log.server_id;
        work_logs.push(work_log);
      }
    }
    project_ids = {};
    issue_ids = {};
    work_log_ids = {};
    for (_l = 0, _len3 = projects.length; _l < _len3; _l++) {
      project = projects[_l];
      project_ids[project.server_id] = project.id;
    }
    for (_m = 0, _len4 = issues.length; _m < _len4; _m++) {
      issue = issues[_m];
      issue_ids[issue.server_id] = issue.id;
    }
    for (_n = 0, _len5 = work_logs.length; _n < _len5; _n++) {
      work_log = work_logs[_n];
      work_log_ids[work_log.server_id] = work_log.id;
    }
    server_ids = {
      projects: project_ids,
      issue: issue_ids,
      work_logs: work_log_ids
    };
    res = {
      projects: projects,
      issues: issues,
      work_logs: work_logs,
      server_ids: server_ids
    };
    return res;
  };

  sync = function(server, table_name, data) {
    var i, item, local_id, server_id, server_ids, _i, _len, _results, _results1;

    if (table_name === "server_ids") {
      _results = [];
      for (table_name in data) {
        server_ids = data[table_name];
        _results.push((function() {
          var _results1;

          _results1 = [];
          for (local_id in server_ids) {
            server_id = server_ids[local_id];
            item = db.one(table_name, {
              id: local_id
            });
            item.server_id = server_id;
            _results1.push(db.upd(table_name, item));
          }
          return _results1;
        })());
      }
      return _results;
    } else {
      if (data) {
        _results1 = [];
        for (_i = 0, _len = data.length; _i < _len; _i++) {
          i = data[_i];
          _results1.push(sync_item(server, table_name, i));
        }
        return _results1;
      }
    }
  };

  sync_item = function(server, table_name, i) {
    var is_new, issue, item, project;

    if (i.project_id) {
      project = db.one("projects", {
        server_id: parseInt(i.project_id)
      });
      i.project_id = project.id;
    }
    if (i.issue_id) {
      issue = db.one("issues", {
        server_id: parseInt(i.issue_id)
      });
      if (issue) {
        i.issue_id = issue.id;
      }
    }
    item = db.one(table_name, {
      server_id: i.local_id
    });
    if (item) {
      i.id = item.id;
      item = i;
      return db.upd(table_name, item);
    } else {
      i.server_id = parseInt(i.local_id);
      delete i.local_id;
      is_new = true;
      if (table_name === "projects") {
        if (db.one("projects", {
          name: i.name,
          origin_at: parseInt(i.ins_at)
        })) {
          is_new = false;
        }
      }
      if (table_name === "issues") {
        if (db.one("issues", {
          title: i.title,
          origin_at: parseInt(i.ins_at)
        })) {
          is_new = false;
        }
      }
      if (table_name === "work_logs") {
        if (db.one("work_logs", {
          started_at: parseInt(i.started_at)
        })) {
          is_new = false;
        }
      }
      if (is_new) {
        if (table_name === "projects" || table_name === "issues") {
          i.origin_at = i.ins_at;
        }
        return item = db.ins(table_name, i);
      }
    }
  };

  addIssue = function(project_id, title) {
    var issue;

    issue = db.ins("issues", {
      title: title,
      project_id: project_id,
      body: "",
      assignee_id: 1,
      user_id: 1
    });
    return renderIssue(issue, "prepend");
  };

  addProject = function(name) {
    var project;

    project = db.ins("projects", {
      name: name
    });
    renderProject(project);
    $("#project_" + project.id).fadeIn(200);
    return project;
  };

  last_fetch = function(sec) {
    var info;

    if (sec == null) {
      sec = null;
    }
    if (sec) {
      setInfo("last_fetch", sec);
    }
    info = db.one("infos", {
      key: "last_fetch"
    });
    if (info) {
      return info.val;
    } else {
      return 0;
    }
  };

  dispTime = function(work_log) {
    var hour, min, msec, res, sec;

    msec = 0;
    if (work_log.end_at) {
      sec = work_log.end_at - work_log.started_at;
    } else {
      sec = now() - work_log.started_at;
    }
    if (sec > 3600) {
      hour = parseInt(sec / 3600);
      min = parseInt((sec - hour * 3600) / 60);
      res = "" + (zero(hour)) + ":" + (zero(min)) + ":" + (zero(sec - hour * 3600 - min * 60));
    } else if (sec > 60) {
      min = parseInt(sec / 60);
      res = "" + (zero(min)) + ":" + (zero(sec - min * 60));
    } else {
      res = "" + sec + "秒";
    }
    return res;
  };

  setInfo = function(key, val) {
    var info;

    info = db.one("infos", {
      key: key
    });
    if (info) {
      info.val = val;
      info = db.upd("infos", info);
    } else {
      info = db.ins("infos", {
        key: key,
        val: val
      });
    }
    return info;
  };

  db = JSRel.use("crowdsourcing3", {
    schema: schema,
    autosave: true
  });

  zero = function(int) {
    if (int < 10) {
      return "0" + int;
    } else {
      return int;
    }
  };

  now = function() {
    return parseInt((new Date().getTime()) / 1000);
  };

  uploading_icon = "<i class=\"icon-circle-arrow-up\"></i>";

  turnback = function($e) {
    if ($e.css("display") === "none") {
      return $e.fadeIn(400);
    } else {
      return $e.fadeOut(400);
    }
  };

  findWillUploads = function(table_name) {
    return db.find(table_name, {
      server_id: null
    });
  };

  pushIfHasIssue = function(project, projects) {
    if (db.one("issues", {
      project_id: project.id
    })) {
      project.local_id = project.id;
      delete project.id;
      projects.push(project);
    }
    return projects;
  };

  findProjectByIssue = function(issue) {
    return db.one("projects", {
      id: issue.project_id
    });
  };

  findIssueByWorkLog = function(work_log) {
    return db.one("issues", {
      id: work_log.issue_id
    });
  };

  forUploadIssue = function(issue) {
    var project;

    project = findProjectByIssue(issue);
    if (project.server_id) {
      issue.project_server_id = project.server_id;
    }
    issue.local_id = issue.id;
    delete issue.id;
    return issue;
  };

  forUploadWorkLog = function(work_log) {
    var issue;

    issue = findIssueByWorkLog(work_log);
    if (issue.server_id) {
      work_log.issue_server_id = issue.server_id;
    }
    work_log.local_id = work_log.id;
    delete work_log.id;
    return work_log;
  };

  buffer = [];

  io.sockets.on('connection', function(client) {
    var clientId;

    clientId = 'User' + client.id.substr(client.id.length - 3, 3);
    client.broadcast.emit('connect', clientId + ' connected');
    client.emit('message', {
      'messages': buffer
    });
    client.on('message', function(message) {
      var msg;

      msg = {
        user: clientId,
        message: message
      };
      buffer.push(msg);
      if (buffer.length > 15) {
        buffer.shift();
        return client.broadcast.emit('message', {
          'messages': [msg]
        });
      }
    });
    return client.on('disconnect', function() {
      return client.broadcast.emit('disconnect', clientId + ' disconnected');
    });
  });

  node_dev = function(req, res) {
    var body, i, _i, _len;

    body = "<a href=\"/\">back</a>";
    body += "<hr />";
    for (_i = 0, _len = req.length; _i < _len; _i++) {
      i = req[_i];
      body += i + ' is ' + req[i];
      body += "<br />";
    }
    body += "<hr />";
    body += "<a href=\"/\">back</a>";
    res.setHeader('Content-Type', 'text/html');
    res.setHeader('Content-Length', body.length);
    return res.end(body);
  };

  node_projects = function(req, res) {
    var body, key, project, val, _i, _len, _ref;

    body = "<meta charset=\"UTF-8\" /><a href=\"/\">back</a>";
    body += "<hr />";
    _ref = db.find("projects");
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      project = _ref[_i];
      body += "<h2>" + project.name + "</h2>";
      for (key in project) {
        val = project[key];
        if (key !== "name") {
          body += "" + key + " : " + val + "<br />";
        }
      }
    }
    body += "<hr />";
    body += "<a href=\"/\">back</a>";
    res.setHeader('Content-Type', 'text/html');
    res.setHeader('Content-Length', body.length);
    return res.end(body);
  };

  node_issues = function(req, res) {
    var body, issue, key, val, _i, _len, _ref;

    body = "<meta charset=\"UTF-8\" /><a href=\"/\">back</a>";
    body += "<hr />";
    _ref = db.find("issues");
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      issue = _ref[_i];
      body += "<h2>" + issue.title + "</h2>";
      for (key in issue) {
        val = issue[key];
        if (key !== "title") {
          body += "" + key + " : " + val + "<br />";
        }
      }
    }
    body += "<hr />";
    body += "<a href=\"/\">back</a>";
    res.setHeader('Content-Type', 'text/html');
    res.setHeader('Content-Length', body.length);
    return res.end(body);
  };

  node_work_logs = function(req, res) {
    var body, key, val, work_log, _i, _len, _ref;

    body = "<meta charset=\"UTF-8\" /><a href=\"/\">back</a>";
    body += "<hr />";
    _ref = db.find("work_logs");
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      work_log = _ref[_i];
      body += "<h2>" + work_log.title + "</h2>";
      for (key in work_log) {
        val = work_log[key];
        if (key !== "title") {
          body += "" + key + " : " + val + "<br />";
        }
      }
    }
    body += "<hr />";
    body += "<a href=\"/\">back</a>";
    res.setHeader('Content-Type', 'text/html');
    res.setHeader('Content-Length', body.length);
    return res.end(body);
  };

  server.listen(3000);

}).call(this);

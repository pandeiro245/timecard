(function() {
  var socket;

  socket = io.connect('/');

  socket.on('connect', function(data) {
    if (data) {
      return $('#body').prepend('</br>' + data);
    }
  });

  socket.on('message', function(data) {
    var msg, _i, _len, _ref, _results;

    _ref = data.messages;
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      msg = _ref[_i];
      _results.push($('#body').prepend("</br>" + msg.user + " says: " + msg.message));
    }
    return _results;
  });

  socket.on('disconnect', function(data) {
    return $('#body').prepend('</br>' + data);
  });

  $(document).ready(function() {
    $('#send').click(function() {
      var msg;

      msg = $('#field').val();
      if (msg) {
        socket.send(msg);
        $('#body').prepend('</br>You say: ' + msg);
        return $('#field').val('');
      }
    });
    return $('form').on('submit', function() {
      return false;
    });
  });

}).call(this);

(function() {
  window.helpers = {
    enter: function(dom, callback) {
      return $(dom).keypress(function(e) {
        if (e.which === 13) {
          return callback(e, this);
        }
      });
    },
    click: function(dom, callback) {
      return $(dom).click(function(e) {
        return callback(e);
      });
    },
    dblclick: function(dom, callback) {
      return $(dom).dblclick(function(e) {
        return callback(e);
      });
    },
    href2title: function(dom) {
      var href, title;

      title = "";
      href = $(dom).attr("href");
      if (href.match("#")) {
        title = href.replace(/^#/, "");
      }
      return title;
    },
    hash2title: function(defaulttitle) {
      var res;

      res = location.hash.replace(/^#/, "");
      if (!res || res === "") {
        res = defaulttitle;
      }
      return res;
    }
  };

}).call(this);

(function() {
  var addIssue, addProject, db, debug, dispTime, fetch, findIssueByWorkLog, findProjectByIssue, findWillUploads, forUploadIssue, forUploadWorkLog, hl, init, last_fetch, loopFetch, loopRenderWorkLogs, now, prepareAddProject, prepareAddServer, prepareCards, prepareNodeServer, pushIfHasIssue, renderCards, renderCls, renderDdt, renderIssue, renderIssues, renderProject, renderProjects, renderWorkLogs, renderWorkingLog, setInfo, startOrStopWorkingLog, startWorkLog, stopWorkLog, sync, sync_item, turnback, uicon, working_log, zero;

  init = function() {
    prepareAddServer();
    prepareAddProject();
    renderProjects();
    renderIssues();
    renderWorkLogs();
    loopRenderWorkLogs();
    return loopFetch();
  };

  fetch = function(server) {
    var diffs, domain, issue, issues, params, project, projects, token, url, wlsis, work_log, work_logs, working_log_server_id, working_logs, _i, _j, _k, _l, _len, _len1, _len2, _len3, _ref, _ref1, _ref2, _ref3;

    domain = server.domain;
    token = server.token;
    projects = [];
    issues = [];
    work_logs = [];
    _ref = findWillUploads("projects");
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      project = _ref[_i];
      projects = pushIfHasIssue(project, projects);
    }
    _ref1 = findWillUploads("issues");
    for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
      issue = _ref1[_j];
      issues.push(forUploadIssue(issue));
    }
    _ref2 = findWillUploads("work_logs");
    for (_k = 0, _len2 = _ref2.length; _k < _len2; _k++) {
      work_log = _ref2[_k];
      work_logs.push(forUploadWorkLog(work_log));
    }
    diffs = {
      projects: projects,
      issues: issues,
      work_logs: work_logs
    };
    working_logs = [];
    wlsis = db.one("infos", {
      key: "working_log_server_ids"
    });
    if (wlsis && wlsis.val) {
      _ref3 = wlsis.val.split(",");
      for (_l = 0, _len3 = _ref3.length; _l < _len3; _l++) {
        working_log_server_id = _ref3[_l];
        working_logs.push(db.one("work_logs", {
          server_id: parseInt(working_log_server_id)
        }));
      }
    }
    params = {
      token: token,
      last_fetch: last_fetch(),
      diffs: diffs,
      working_logs: working_logs
    };
    debug("fetch diffs", diffs);
    url = "" + domain + "/api/v1/diffs.json";
    return $.post(url, params, function(data) {
      wlsis = db.one("infos", {
        key: "working_log_server_ids"
      });
      if (!wlsis) {
        wlsis = db.ins("infos", {
          key: "working_log_server_ids"
        });
      }
      if (data.working_log_server_ids) {
        wlsis.val = data.working_log_server_ids.join(",");
      }
      db.upd("infos", wlsis);
      sync(server, "server_ids", data.server_ids);
      sync(server, "projects", data.projects);
      sync(server, "issues", data.issues);
      sync(server, "work_logs", data.work_logs);
      renderWorkLogs(server);
      return last_fetch(now());
    });
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
            if (item) {
              item.server_id = server_id;
              _results1.push(db.upd(table_name, item));
            } else {
              _results1.push(void 0);
            }
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
    var issue, item, url;

    if (i.project_id) {
      i.project_id = db.one("projects", {
        server_id: i.project_id
      }).id;
    }
    if (i.issue_id) {
      issue = db.one("issues", {
        server_id: i.issue_id
      });
      if (issue) {
        i.issue_id = issue.id;
      } else {
        url = "" + server.domain + "/api/v1/issues/" + i.issue_id + ".json?token=" + server.token;
        $.get(url, function(item) {
          return sync_item(server, "issues", item);
        });
        i.issue_id = 0;
      }
    }
    if (i.closed_at > 0) {
      i.is_closed = true;
    }
    item = db.one(table_name, {
      server_id: i.id
    });
    if (item) {
      i.id = item.id;
      item = i;
      return db.upd(table_name, item);
    } else {
      i.server_id = i.id;
      delete i.id;
      return item = db.ins(table_name, i);
    }
  };

  renderProjects = function() {
    var project, projects, _i, _len;

    projects = db.find("projects", null, {
      order: {
        id: "asc"
      }
    });
    $("#issues").html("");
    for (_i = 0, _len = projects.length; _i < _len; _i++) {
      project = projects[_i];
      renderProject(project);
    }
    return hl.enter(".input", function(e, target) {
      var $project, project_id, title;

      title = $(target).val();
      $project = $(target).parent().parent().parent();
      project_id = $project.attr("id").replace("project_", "");
      if (title.length > 0) {
        addIssue(project_id, title);
        return $(target).val("");
      } else {
        return alert("please input the title");
      }
    });
  };

  prepareNodeServer = function() {
    var dbtype, url;

    if (location.href.match("local") && !db.one("servers", {
      domain: ""
    })) {
      console.log(location.href);
      dbtype = "local";
      url = "/api/users.json";
      return $.get(url, function(data) {
        var server;

        console.log(data);
        console.log("aaa");
        return server = db.ins("servers", {
          domain: "",
          user_id: data.id,
          has_connect: true,
          dbtype: dbtype
        });
      });
    }
  };

  prepareAddServer = function() {
    return hl.click(".add_server", function(e, target) {
      var dbtype, domain, token, url;

      domain = prompt('please input domain', 'http://crowdsourcing.dev');
      if (domain.match("crowdsourcing") || domain.match("cs.mindia.jp")) {
        dbtype = "cs";
        token = prompt('please input the token', '83070ba0c407e9cc80978207e1ea36f66fcaad29b60d2424a7f1ea4f4e332c3c');
        url = "" + domain + "/api/v1/users.json?token=" + token;
        return $.get(url, function(data) {
          var server;

          return server = db.ins("servers", {
            domain: domain,
            token: token,
            user_id: data.id,
            has_connect: true,
            dbtype: dbtype
          });
        });
      } else if (domain.match("redmine")) {
        dbtype = "redmine";
        token = prompt('please input login id', 'nishiko');
        token = prompt('please input login pass', '');
        return $.get(url, function(data) {
          return db.ins("servers", {
            domain: domain,
            login: login,
            pass: pass,
            user_id: data.id,
            has_connect: true,
            dbtype: dbtype
          });
        });
      } else {
        return alert("invalid domain");
      }
    });
  };

  prepareAddProject = function() {
    return hl.click(".add_project", function(e, target) {
      var issue_title, project, title;

      title = prompt('please input the project name', '');
      issue_title = prompt('please input the issue title', 'add issues');
      if (title.length > 0 && issue_title.length > 0) {
        project = addProject(title);
        return addIssue(project.id, issue_title);
      } else {
        return alert("please input the title of project and issue.");
      }
    });
  };

  renderProject = function(project) {
    return $("#issues").append("<div id=\"project_" + project.id + "\"class=\"project\" style=\"display:none;\">\n<div class=\"span12\">\n<h1>\n  " + project.name + (project.server_id ? "" : uicon) + "\n</h1>\n<div class=\"input-append\"> \n  <input type=\"text\" class=\"input\" />\n  <input type=\"submit\" value=\"add issue\" class=\"btn\" />\n</div>\n</div>\n<div class=\"issues\"></div>\n</div>");
  };

  renderIssues = function(issues) {
    var i, issue, _i, _len;

    if (issues == null) {
      issues = null;
    }
    if (!issues) {
      issues = db.find("issues", {
        closed_at: {
          le: 1
        }
      }, {
        order: {
          upd_at: "desc"
        }
      });
    }
    $(".issues").html("");
    i = 1;
    for (_i = 0, _len = issues.length; _i < _len; _i++) {
      issue = issues[_i];
      if (!issue.is_ddt && !issue.will_start_on) {
        renderIssue(issue, null, i);
      }
      i = i + 0;
    }
    return renderCards();
  };

  prepareCards = function(issue_id) {
    return $(function() {
      $("#issue_" + issue_id + " div div h2").click(function() {
        var $e;

        $e = $(this).parent().find(".body");
        turnback($e);
        return false;
      });
      $("#issue_" + issue_id + " div div .card").click(function() {
        renderCards(issue_id);
        return false;
      });
      $("#issue_" + issue_id + " div div .ddt").click(function() {
        renderDdt(issue_id);
        return false;
      });
      return $("#issue_" + issue_id + " div div .cls").click(function() {
        renderCls(issue_id);
        return false;
      });
    });
  };

  renderIssue = function(issue, target, i) {
    var $project, $project_issues, icon, start_or_end, style, title;

    if (target == null) {
      target = null;
    }
    if (i == null) {
      i = null;
    }
    if (!target) {
      target = "append";
    }
    $project = $("#project_" + issue.project_id);
    $project_issues = $("#project_" + issue.project_id + " .issues");
    $project.fadeIn(200);
    title = "" + issue.title;
    if (issue.body && issue.body.length > 0) {
      title = "<a class=\"title\" href=\"#\">" + issue.title + "</a>";
    }
    icon = issue.server_id ? "" : uicon;
    start_or_end = working_log() && working_log().issue_id === issue.id ? "Stop" : "Start";
    if (i % 4 === 1) {
      style = "style=\"margin-left:0;\"";
    } else {
      style = "";
    }
    return umecob({
      use: 'jquery',
      tpl_id: "./partials/issue.html",
      data: {
        issue: issue,
        title: title,
        icon: icon,
        start_or_end: start_or_end,
        style: style
      }
    }).next(function(html) {
      if (target === "append") {
        $project_issues.append(html);
      } else {
        $project_issues.prepend(html);
      }
      $("issue_" + issue.id).hide().fadeIn(200);
      return prepareCards(issue.id);
    });
  };

  renderDdt = function(issue_id) {
    var issue;

    issue = db.one("issues", {
      id: issue_id
    });
    issue.is_ddt = true;
    db.upd("issues", issue);
    return $("#issue_" + issue.id).fadeOut(200);
  };

  renderCls = function(issue_id) {
    var issue;

    issue = db.one("issues", {
      id: issue_id
    });
    issue.closed_at = now();
    db.upd("issues", issue);
    debug("renderCls", issue);
    return $("#issue_" + issue.id).fadeOut(200);
  };

  renderCards = function(issue_id) {
    if (issue_id == null) {
      issue_id = null;
    }
    $(".card").html("Start");
    $(".card").removeClass("btn-worning");
    $(".card").addClass("btn-primary");
    return startOrStopWorkingLog(null, issue_id);
  };

  startWorkLog = function(issue_id) {
    return startOrStopWorkingLog(true, issue_id);
  };

  stopWorkLog = function(issue_id) {
    return startOrStopWorkingLog(false, issue_id);
  };

  startOrStopWorkingLog = function(is_start, issue_id) {
    var wl;

    if (is_start == null) {
      is_start = null;
    }
    if (issue_id == null) {
      issue_id = null;
    }
    wl = working_log();
    if (wl && issue_id) {
      wl.end_at = now();
      db.upd("work_logs", wl);
    }
    if (is_start === null) {
      if (wl && parseInt(wl.issue_id) === parseInt(issue_id)) {
        is_start = false;
      } else {
        is_start = true;
      }
    }
    if (is_start && issue_id) {
      db.ins("work_logs", {
        issue_id: issue_id,
        started_at: now()
      });
    }
    if (working_log()) {
      issue_id = working_log().issue_id;
    }
    $("#issue_" + issue_id + " .card").html("Stop");
    $("#issue_" + issue_id + " .card").removeClass("btn-primary");
    return $("#issue_" + issue_id + " .card").addClass("btn-warning");
  };

  addIssue = function(project_id, title) {
    var issue;

    issue = db.ins("issues", {
      title: title,
      project_id: project_id,
      body: ""
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

  renderWorkLogs = function(server) {
    var issue, stop, url, work_log, working_log, _i, _len, _ref, _results;

    if (server == null) {
      server = null;
    }
    $("#work_logs").html("");
    _ref = db.find("work_logs", null, {
      order: {
        started_at: "desc"
      },
      limit: 20
    });
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      work_log = _ref[_i];
      if (!work_log.issue_id && server) {
        url = "" + server.domain + "/api/v1/work_logs/" + work_log.server_id + ".json?token=" + server.token;
        $.get(url, function(item) {
          return sync_item(server, "work_logs", item);
        });
      }
      if (work_log.issue_id !== 0) {
        issue = db.one("issues", {
          id: work_log.issue_id
        });
      } else {
        issue = {
          title: "issue名取得中"
        };
      }
      stop = "";
      if (!work_log.end_at) {
        stop = "<a href=\"#\" class=\"cardw\">STOP</a>";
      }
      $("#work_logs").append("<li class=\"work_log_" + work_log.id + "\">\n" + issue.title + "\n<span class=\"time\">" + (dispTime(work_log)) + "</span>\n" + (work_log.server_id ? "" : uicon) + "\n" + stop + "\n</li>");
      $(".cardw").click(function() {
        var issue_id;

        issue_id = working_log.issue_id;
        renderCards(issue_id);
        return false;
      });
      if (!work_log.end_at) {
        _results.push(working_log = work_log);
      } else {
        _results.push(void 0);
      }
    }
    return _results;
  };

  renderWorkingLog = function() {
    var time, wl;

    wl = working_log();
    if (wl) {
      time = dispTime(wl);
      $(".work_log_" + wl.id + " .time").html(time);
      $("#issue_" + wl.issue_id + " h2 .time").html("(" + time + ")");
      return $("#issue_" + wl.issue_id + " div div .card").html("Stop");
    }
  };

  loopRenderWorkLogs = function() {
    renderWorkingLog();
    return setTimeout(function() {
      return loopRenderWorkLogs();
    }, 1000);
  };

  loopFetch = function() {
    var server, _i, _len, _ref;

    _ref = db.find("servers");
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      server = _ref[_i];
      fetch(server);
    }
    return setTimeout(function() {
      return loopFetch();
    }, 1000 * 10);
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

  db = JSRel.use("crowdsourcing", {
    schema: window.schema,
    autosave: true
  });

  hl = window.helpers;

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

  uicon = "<i class=\"icon-circle-arrow-up\"></i>";

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

  debug = function(title, data) {
    console.log(title);
    return console.log(data);
  };

  working_log = function(issue_id, is_start) {
    var cond, work_log;

    if (issue_id == null) {
      issue_id = null;
    }
    if (is_start == null) {
      is_start = true;
    }
    cond = {
      end_at: null
    };
    return work_log = db.one("work_logs", cond);
  };

  window.db = db;

  $(function() {
    return init();
  });

}).call(this);

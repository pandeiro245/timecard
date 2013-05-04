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
  var addIssue, addProject, db, debug, dispTime, domain, fetch, getDomain, getLastFetch, getToken, hl, init, last_fetch, loopFetch, loopRenderWorkLogs, now, renderCards, renderDdt, renderIssue, renderIssues, renderProject, renderProjects, renderWorkLogs, schema, setInfo, startWorkLog, stopWorkLog, sync, token, turnback, working_log, zero;

  working_log = null;

  domain = null;

  token = null;

  last_fetch = null;

  getLastFetch = function() {
    var info;

    info = db.one("infos", {
      key: "last_fetch"
    });
    if (info) {
      return info.val;
    } else {
      return 0;
    }
  };

  getDomain = function() {
    var info, val;

    info = db.one("infos", {
      key: "domain"
    });
    if (!info || info.val.length < 10) {
      val = prompt('please input the domain', 'http://crowdsourcing.dev');
      info = setInfo("domain", val);
    }
    return info.val;
  };

  getToken = function() {
    var info, val;

    info = db.one("infos", {
      key: "token"
    });
    if (location.hash && location.hash.length > 10) {
      val = location.hash.replace(/#/, "");
      info = setInfo("token", val);
    } else if (!info || info.val.length < 10) {
      location.href = "" + domain + "/token?url=" + location.href;
    }
    return info.val;
  };

  init = function() {
    if (!domain) {
      domain = getDomain();
    }
    if (!token) {
      token = getToken();
    }
    if (!last_fetch) {
      last_fetch = getLastFetch();
    }
    renderProjects();
    renderIssues();
    fetch();
    loopFetch();
    return loopRenderWorkLogs();
  };

  fetch = function() {
    var diffs, has_issue, issue, issues, params, project, projects, url, wlsis, work_log, work_logs, working_log_server_id, working_logs, _i, _j, _k, _l, _len, _len1, _len2, _len3, _ref, _ref1, _ref2, _ref3;

    projects = [];
    issues = [];
    work_logs = [];
    _ref = db.find("projects", {
      server_id: null
    });
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      project = _ref[_i];
      has_issue = db.one("issues", {
        project_id: project.id
      });
      if (has_issue) {
        project.local_id = project.id;
        delete project.id;
        projects.push(project);
      }
    }
    _ref1 = db.find("issues", {
      server_id: null
    });
    for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
      issue = _ref1[_j];
      project = db.one("projects", {
        id: issue.project_id
      });
      if (project.server_id) {
        issue.project_server_id = project.server_id;
      }
      issue.local_id = issue.id;
      delete issue.id;
      issues.push(issue);
    }
    _ref2 = db.find("work_logs", {
      server_id: null
    });
    for (_k = 0, _len2 = _ref2.length; _k < _len2; _k++) {
      work_log = _ref2[_k];
      issue = db.one("issues", {
        id: work_log.issue_id
      });
      if (issue.server_id) {
        work_log.issue_server_id = issue.server_id;
      }
      work_log.local_id = work_log.id;
      delete work_log.id;
      work_logs.push(work_log);
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
    if (wlsis) {
      console.log(wlsis);
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
      last_fetch: last_fetch,
      diffs: diffs,
      working_logs: working_logs
    };
    debug("diffs", diffs);
    debug("fetch at", now());
    url = "" + domain + "/api/v1/diffs.json";
    return $.post(url, params, function(data) {
      debug("fetch callback", data);
      wlsis = db.one("infos", {
        key: "working_log_server_ids"
      });
      if (!wlsis) {
        wlsis = db.ins("infos", {
          key: "working_log_server_ids"
        });
      }
      wlsis.val = data.working_log_server_ids.join(",");
      db.upd("infos", wlsis);
      sync("server_ids", data.server_ids);
      sync("projects", data.projects);
      sync("issues", data.issues);
      sync("work_logs", data.work_logs);
      last_fetch = now();
      return setInfo("last_fetch", last_fetch);
    });
  };

  sync = function(table_name, data) {
    var i, issue, item, local_id, server_id, server_ids, _i, _len, _results;

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
      for (_i = 0, _len = data.length; _i < _len; _i++) {
        i = data[_i];
        if (i.project_id) {
          i.project_id = db.one("projects", {
            server_id: i.project_id
          }).id;
        }
        if (i.issue_id) {
          issue = db.one("issues", {
            server_id: i.issue_id
          });
          i.issue_id = issue.id;
        }
        if (i.closed_at) {
          i.is_closed = true;
        }
        item = db.one(table_name, {
          server_id: i.id
        });
        if (item) {
          i.id = item.id;
          item = i;
          db.upd(table_name, item);
        } else {
          i.server_id = i.id;
          delete i.id;
          item = db.ins(table_name, i);
        }
      }
      return debug("sync is done", data);
    }
  };

  renderProjects = function(projects) {
    var project, _i, _len;

    if (projects == null) {
      projects = null;
    }
    if (!projects) {
      projects = db.find("projects");
    }
    $("#projects-tab").html("<div id=\"new_project\"></div>");
    $("#new_project").html("<input type=\"text\" class=\"input\" />\n<input type=\"submit\" value=\"add project\" />");
    for (_i = 0, _len = projects.length; _i < _len; _i++) {
      project = projects[_i];
      renderProject(project);
    }
    return hl.enter(".input", function(e, target) {
      var $project, project_id, title;

      title = $(target).val();
      $project = $(target).parent();
      if ($project.attr("id").match("project_")) {
        project_id = $project.attr("id").replace("project_", "");
        if (title.length > 0) {
          addIssue(project_id, title);
          return $(target).val("");
        } else {
          return alert("please input the title");
        }
      } else {
        if (title.length > 0) {
          addProject(title);
          return $(target).val("");
        } else {
          return alert("please input the title");
        }
      }
    });
  };

  renderProject = function(project) {
    return $("#projects-tab").append("<div id=\"project_" + project.id + "\" class=\"project\">\n  <h1>" + project.name + (project.server_id ? "" : "(サーバ待機中)") + "</h1>\n  <input type=\"text\" class=\"input\" />\n  <input type=\"submit\" value=\"add issue\" />\n  <div class=\"issues\"></div>\n</div>");
  };

  renderIssues = function(issues) {
    var issue, _i, _len;

    if (issues == null) {
      issues = null;
    }
    if (!issues) {
      issues = db.find("issues", {
        is_closed: false,
        assignee_id: 1
      });
    }
    $(".issues").html("");
    for (_i = 0, _len = issues.length; _i < _len; _i++) {
      issue = issues[_i];
      if (!issue.is_ddt) {
        renderIssue(issue);
      }
    }
    renderCards();
    return $(function() {
      $(".issue .title").click(function() {
        var $e;

        $e = $(this).parent().find(".body");
        turnback($e);
        return false;
      });
      $(".card").click(function() {
        var issue_id;

        issue_id = $(this).parent().attr("id").replace("issue_", "");
        renderCards(issue_id);
        return false;
      });
      return $(".ddt").click(function() {
        var issue_id;

        issue_id = $(this).parent().attr("id").replace("issue_", "");
        renderDdt(issue_id);
        return false;
      });
    });
  };

  renderIssue = function(issue) {
    var $project, title;

    $project = $("#project_" + issue.project_id);
    $project.fadeIn(200);
    title = "" + issue.title + " " + issue.is_ddt;
    if (issue.body && issue.body.length > 0) {
      title = "<a class=\"title\" href=\"#\">" + issue.title + "</a>";
    }
    $project.append("<div id=\"issue_" + issue.id + "\" class=\"issue\">\n  " + title + " \n  " + (issue.server_id ? "" : "(サーバ待機中)") + "\n  <a class=\"card\" href=\"#\"></a>\n  <a class=\"ddt\" href=\"#\">DDT</a>\n  <div class=\"body\">" + issue.body + "</div>\n</div>");
    return $("issue_" + issue.id).hide().fadeIn(200);
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

  renderCards = function(issue_id) {
    if (issue_id == null) {
      issue_id = null;
    }
    if (working_log) {
      if (issue_id) {
        stopWorkLog();
      }
      if (parseInt(issue_id) !== parseInt(working_log.issue_id)) {
        startWorkLog(issue_id);
      } else {
        working_log = null;
      }
    } else {
      if (!issue_id) {
        $(".card").html("start");
      } else {
        startWorkLog(issue_id);
      }
    }
    return renderWorkLogs();
  };

  stopWorkLog = function() {
    working_log.end_at = now();
    db.upd("work_logs", working_log);
    return $("#issue_" + working_log.issue_id + " .card").html("start");
  };

  startWorkLog = function(issue_id) {
    if (issue_id == null) {
      issue_id = null;
    }
    debug("startWorkLog", issue_id);
    if (issue_id) {
      working_log = db.ins("work_logs", {
        issue_id: issue_id
      });
      working_log.started_at = now();
      db.upd("work_logs", working_log);
      return $("#issue_" + issue_id + " .card").html("stop");
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
    return renderIssue(issue);
  };

  addProject = function(name) {
    var project;

    project = db.ins("projects", {
      name: name
    });
    renderProjects();
    return $("#project_" + project.id).fadeIn(200);
  };

  renderWorkLogs = function() {
    var issue, stop, title, url, work_log, _i, _len, _ref;

    $("#work_logs").html("");
    title = "crowdsourciing";
    _ref = db.find("work_logs", null, {
      order: {
        started_at: "desc"
      },
      limit: 20
    });
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      work_log = _ref[_i];
      if (!work_log.issue_id) {
        url = "" + domain + "/api/v1/work_logs/" + work_log.server_id + ".json?token=" + token;
        $.get(url, function(data) {
          var issue;

          issue = db.one("issues", {
            server_id: data.id
          });
          work_log.issue_id = issue.id;
          return db.upd("work_logs", work_log);
        });
      }
      issue = db.one("issues", {
        id: work_log.issue_id
      });
      if (!issue.title) {
        console.log(issue);
      }
      stop = "";
      if (!work_log.end_at) {
        stop = "<a href=\"#\" class=\"cardw\">STOP</a>";
      }
      $("#work_logs").append("<div>" + issue.title + " " + (dispTime(work_log)) + "\n" + (work_log.server_id ? "" : "(サーバ待機中)"));
      $(".cardw").click(function() {
        var issue_id;

        issue_id = working_log.issue_id;
        renderCards(issue_id);
        return false;
      });
      if (!work_log.end_at) {
        title = dispTime(work_log);
        working_log = work_log;
      }
    }
    return title;
  };

  loopRenderWorkLogs = function() {
    window.title = renderWorkLogs();
    return setTimeout(function() {
      return loopRenderWorkLogs();
    }, 1000);
  };

  loopFetch = function() {
    if (last_fetch > 0) {
      fetch();
      return setTimeout(function() {
        return loopFetch();
      }, 1000 * 10);
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

  schema = {
    users: {
      server_id: 0,
      name: ""
    },
    projects: {
      name: "",
      body: "",
      server_id: 0
    },
    issues: {
      title: "",
      body: "",
      project_id: 0,
      server_id: 0,
      is_ddt: "off",
      is_closed: "off",
      user_id: 0,
      assignee_id: 0
    },
    work_logs: {
      issue_id: 0,
      started_at: 0,
      end_at: 0,
      server_id: 0
    },
    work_comments: {
      issue_id: 0,
      user_id: 0,
      body: ""
    },
    infos: {
      key: "",
      val: "",
      $uniques: "key"
    }
  };

  db = JSRel.use("crowdsourcing", {
    schema: schema,
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

  turnback = function($e) {
    if ($e.css("display") === "none") {
      return $e.fadeIn(400);
    } else {
      return $e.fadeOut(400);
    }
  };

  debug = function(title, data) {
    console.log(title);
    return console.log(data);
  };

  $(function() {
    return init();
  });

}).call(this);

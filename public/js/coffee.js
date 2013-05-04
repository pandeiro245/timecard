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
  var addIssue, addProject, db, dispTime, domain, fetch, getDomain, getLastFetch, getToken, hl, init, last_fetch, loopFetch, loopRenderWorkLogs, now, renderCards, renderDdt, renderIssue, renderIssues, renderProject, renderProjects, renderWorkLogs, schema, setInfo, startWorkLog, stopWorkLog, sync, token, working_log, zero;

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
    if (!info || info.val.length < 10) {
      val = prompt('please input your API token', '');
      info = setInfo("token", val);
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
    var diffs, i, issues, p, params, project, projects, url, w, work_logs, _i, _j, _k, _len, _len1, _len2, _ref, _ref1, _ref2;

    projects = [];
    issues = [];
    work_logs = [];
    _ref = db.find("projects");
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      p = _ref[_i];
      project = db.one("issues", {
        project_id: p.id
      });
      if (project && !project.server_id) {
        projects.push(p);
      }
    }
    _ref1 = db.find("issues");
    for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
      i = _ref1[_j];
      if (!i.server_id) {
        issues.push(i);
      }
    }
    _ref2 = db.find("work_logs");
    for (_k = 0, _len2 = _ref2.length; _k < _len2; _k++) {
      w = _ref2[_k];
      if (!w.server_id) {
        work_logs.push(w);
      }
    }
    diffs = {
      projects: projects,
      issues: issues,
      work_logs: work_logs
    };
    params = {
      token: token,
      last_fetch: last_fetch,
      diffs: diffs
    };
    console.log("fetch at " + (now()));
    url = "" + domain + "/api/v1/diffs.json";
    return $.post(url, params, function(data) {
      sync("server_ids", data.server_ids);
      sync("projects", data.projects);
      sync("issues", data.issues);
      sync("work_logs", data.work_logs);
      last_fetch = parseInt(new Date().getTime());
      return setInfo("last_fetch", last_fetch);
    });
  };

  sync = function(table_name, data) {
    var i, issue, item, local_id, local_ids, server_id, _i, _len, _results;

    if (table_name === "server_ids") {
      _results = [];
      for (table_name in data) {
        local_ids = data[table_name];
        _results.push((function() {
          var _results1;

          _results1 = [];
          for (local_id in local_ids) {
            server_id = local_ids[local_id];
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
      return console.log("sync is done");
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
    return $("#projects-tab").append("<div id=\"project_" + project.id + "\" class=\"project\">\n  <h1>" + project.name + "</h1>\n  <input type=\"text\" class=\"input\" />\n  <input type=\"submit\" value=\"add issue\" />\n  <div class=\"issues\"></div>\n</div>");
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
        if ($e.css("display") === "none") {
          $e.css("display", "block");
        } else {
          $e.css("display", "none");
        }
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
    $project.css("display", "block");
    title = "" + issue.title + " " + issue.is_ddt;
    if (issue.body && issue.body.length > 0) {
      title = "<a class=\"title\" href=\"#\">" + issue.title + "</a>";
    }
    return $project.append("<div id=\"issue_" + issue.id + "\" class=\"issue\">\n  " + title + " \n  <a class=\"card\" href=\"#\"></a>\n  <a class=\"ddt\" href=\"#\">DDT</a>\n  <div class=\"body\">" + issue.body + "</div>\n</div>");
  };

  renderDdt = function(issue_id) {
    var issue;

    issue = db.one("issues", {
      id: issue_id
    });
    issue.is_ddt = true;
    db.upd("issues", issue);
    return $("#issue_" + issue.id).css("display", "none");
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
    console.log(work_log);
    working_log.end_at = now();
    db.upd("work_logs", working_log);
    return $("#issue_" + working_log.issue_id + " .card").html("start");
  };

  startWorkLog = function(issue_id) {
    if (issue_id == null) {
      issue_id = null;
    }
    if (issue_id) {
      working_log = db.ins("work_logs", {
        issue_id: issue_id
      });
      working_log.started_at = working_log.ins_at;
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
    return $("#project_" + project.id).css("display", "block");
  };

  renderWorkLogs = function() {
    var issue, stop, title, url, work_log, _i, _len, _ref;

    $("#work_logs").html("");
    title = "crowdsourciing";
    _ref = db.find("work_logs");
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
      console.log(work_log);
      issue = db.one("issues", {
        id: work_log.issue_id
      });
      stop = "";
      if (!work_log.end_at) {
        stop = "<a href=\"#\" class=\"cardw\">STOP</a>";
      }
      $("#work_logs").prepend("<div>" + issue.title + " " + (dispTime(work_log)) + "</div>" + stop);
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
    var min, msec, res, sec;

    msec = 0;
    if (work_log.end_at) {
      msec = work_log.end_at - work_log.started_at;
    } else {
      msec = parseInt(new Date().getTime()) - work_log.started_at;
    }
    sec = parseInt(msec / 1000);
    if (sec > 60) {
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
    return new Date().getTime();
  };

  $(function() {
    return init();
  });

}).call(this);

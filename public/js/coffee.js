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
  var addIssue, db, fetch, hl, init, renderIssue, renderIssues, renderProjects, schema, syncIssues, syncProjects;

  init = function() {
    renderProjects();
    renderIssues();
    return fetch();
  };

  fetch = function() {
    var url;

    url = "http://crowdsourcing.dev/api/v1/projects.json?device_token=1";
    $.get(url, function(projects) {
      syncProjects(projects);
      return renderProjects(projects);
    });
    url = "http://crowdsourcing.dev/api/v1/issues.json?device_token=1";
    return $.get(url, function(issues) {
      syncIssues(issues);
      return renderIssues(issues);
    });
  };

  syncProjects = function(projects) {
    var cond, p, project, _i, _len, _results;

    _results = [];
    for (_i = 0, _len = projects.length; _i < _len; _i++) {
      p = projects[_i];
      cond = {
        server_id: p.id
      };
      project = db.one("projects", cond);
      if (project) {
        _results.push(db.upd("projects", project));
      } else {
        cond.name = p.name;
        cond.body = p.body;
        _results.push(db.ins("projects", cond));
      }
    }
    return _results;
  };

  syncIssues = function(issues) {
    var cond, i, issue, _i, _len, _results;

    _results = [];
    for (_i = 0, _len = issues.length; _i < _len; _i++) {
      i = issues[_i];
      cond = {
        server_id: i.id
      };
      issue = db.one("issues", cond);
      cond.title = i.title;
      cond.project_id = i.project_id;
      cond.body = i.body;
      if (issue) {
        _results.push(db.upd("issues", issue));
      } else {
        _results.push(db.ins("issues", cond));
      }
    }
    return _results;
  };

  renderProjects = function(projects) {
    var project, _i, _len;

    projects = db.find("projects");
    $("#projects-tab").html("");
    for (_i = 0, _len = projects.length; _i < _len; _i++) {
      project = projects[_i];
      $("#projects-tab").append("<div id=\"project_" + project.server_id + "\" class=\"project\">\n  <h1>" + project.name + "</h1>\n  <input type=\"text\" class=\"input\" />\n  <input type=\"submit\" value=\"add issue\" />\n  <div class=\"issues\"></div>\n</div>");
    }
    return hl.enter(".input", function(e, target) {
      var project_id, title;

      project_id = $(target).parent().attr("id").replace("project_", "");
      console.log(project_id);
      title = $(target).val();
      console.log(title);
      if (title.length > 0) {
        addIssue(project_id, title);
        return $("#input").val("");
      } else {
        return alert("please input the title");
      }
    });
  };

  renderIssues = function(issues) {
    var issue, _i, _len;

    issues = db.find("issues");
    $(".issues").html("");
    for (_i = 0, _len = issues.length; _i < _len; _i++) {
      issue = issues[_i];
      renderIssue(issue);
    }
    return $(function() {
      return $(".issue .title").click(function() {
        var $e;

        $e = $(this).parent().find(".body");
        if ($e.css("display") === "none") {
          $e.css("display", "block");
        } else {
          $e.css("display", "none");
        }
        return false;
      });
    });
  };

  renderIssue = function(issue) {
    var $project, title;

    $project = $("#project_" + issue.project_id);
    $project.css("display", "block");
    title = issue.title;
    if (issue.body.length > 0) {
      title = "<a class=\"title\" href=\"#\">" + issue.title + "</a>";
    }
    return $project.append("<div id=\"issue_" + issue.server_id + "\" class=\"issue\">\n  " + title + " \n  <div class=\"body\">" + issue.body + "</div>\n</div>");
  };

  addIssue = function(project_id, title) {
    var issue;

    issue = db.ins("issues", {
      title: title,
      project_id: project_id,
      body: ""
    });
    return renderIssue(issue);
  };

  schema = {
    projects: {
      name: "",
      body: "",
      server_id: 0
    },
    issues: {
      title: "",
      body: "",
      project_id: 0,
      server_id: 0
    }
  };

  db = JSRel.use("crowdsourcing", {
    schema: schema,
    autosave: true
  });

  hl = window.helpers;

  $(function() {
    return init();
  });

}).call(this);

(function() {
  var JSRelModel, _ref,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  JSRelModel = (function(_super) {
    __extends(JSRelModel, _super);

    function JSRelModel() {
      _ref = JSRelModel.__super__.constructor.apply(this, arguments);
      return _ref;
    }

    JSRelModel.prototype.initialize = function() {
      return this.on('invalid', function(model, error) {
        return alert(error);
      });
    };

    JSRelModel.prototype.save = function() {
      var cond, p;

      cond = this.toJSON();
      if (cond.id) {
        return p = db.upd(this.table_name, cond);
      } else {
        p = db.ins(this.table_name, cond);
        return this.set("id", p.id);
      }
    };

    JSRelModel.prototype.find = function(id) {
      return new this.thisclass(db.one(this.table_name, {
        id: id
      }));
    };

    JSRelModel.prototype.find_all = function() {
      return this.collection(db.find(this.table_name, null, {
        order: {
          upd_at: "desc"
        }
      }));
    };

    JSRelModel.prototype.where = function(cond) {
      return this.collection(db.find(this.table_name, cond, {
        order: {
          upd_at: "desc"
        }
      }));
    };

    return JSRelModel;

  })(Backbone.Model);

  this.JSRelModel = JSRelModel;

}).call(this);

(function() {
  var Issue, Issues, _ref, _ref1,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  Issue = (function(_super) {
    __extends(Issue, _super);

    function Issue() {
      _ref = Issue.__super__.constructor.apply(this, arguments);
      return _ref;
    }

    Issue.prototype.table_name = "issues";

    Issue.prototype.thisclass = function(params) {
      return new Issue(params);
    };

    Issue.prototype.collection = function(params) {
      return new Issues(params);
    };

    Issue.prototype.validate = function(attrs) {
      if (_.isEmpty(attrs.title)) {
        return "issue.title must not be empty";
      }
    };

    Issue.prototype.is_ddt = function() {
      var wsat;

      wsat = this.get("will_start_at");
      return !(!wsat || wsat < now());
    };

    Issue.prototype.set_ddt = function() {
      this.set("will_start_at", now() + 12 * 3600 + parseInt(Math.random(10) * 10000));
      return this.save();
    };

    Issue.prototype.cancel_ddt = function() {
      this.set("will_start_at", null);
      return this.save();
    };

    Issue.prototype.is_closed = function() {
      var cat;

      cat = this.get("closed_at");
      if (cat > 0) {
        return true;
      } else {
        return false;
      }
    };

    Issue.prototype.set_closed = function() {
      this.set("closed_at", now());
      return this.save();
    };

    Issue.prototype.cancel_closed = function() {
      this.set("closed_at", 0);
      this.cancel_ddt();
      return this.save();
    };

    Issue.prototype.is_active = function() {
      if (!this.is_closed() && !this.is_ddt()) {
        return true;
      }
      return false;
    };

    Issue.prototype.project = function() {
      return Project.find(this.project_id);
    };

    return Issue;

  })(JSRelModel);

  Issues = (function(_super) {
    __extends(Issues, _super);

    function Issues() {
      _ref1 = Issues.__super__.constructor.apply(this, arguments);
      return _ref1;
    }

    Issues.prototype.model = Issue;

    return Issues;

  })(Backbone.Collection);

  this.Issue = Issue;

  this.Issues = Issues;

}).call(this);

(function() {
  var Project, Projects, _ref, _ref1,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  Project = (function(_super) {
    __extends(Project, _super);

    function Project() {
      _ref = Project.__super__.constructor.apply(this, arguments);
      return _ref;
    }

    Project.prototype.table_name = "projects";

    Project.prototype.thisclass = function(params) {
      return new Project(params);
    };

    Project.prototype.collection = function(params) {
      return new Projects(params);
    };

    Project.prototype.validate = function(attrs) {
      if (_.isEmpty(attrs.name)) {
        return "project name must not be empty";
      }
    };

    return Project;

  })(JSRelModel);

  Projects = (function(_super) {
    __extends(Projects, _super);

    function Projects() {
      _ref1 = Projects.__super__.constructor.apply(this, arguments);
      return _ref1;
    }

    Projects.prototype.model = Project;

    return Projects;

  })(Backbone.Collection);

  this.Project = Project;

  this.Projects = Projects;

}).call(this);

/*
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
*/


(function() {


}).call(this);

(function() {
  var CdownView, _ref,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  CdownView = (function(_super) {
    __extends(CdownView, _super);

    function CdownView() {
      _ref = CdownView.__super__.constructor.apply(this, arguments);
      return _ref;
    }

    return CdownView;

  })(Backbone.View);

  this.CdownView = CdownView;

}).call(this);

(function() {
  var IssueView, IssuesView, _ref, _ref1,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  IssueView = (function(_super) {
    __extends(IssueView, _super);

    function IssueView() {
      _ref = IssueView.__super__.constructor.apply(this, arguments);
      return _ref;
    }

    IssueView.prototype.tagName = 'div';

    IssueView.prototype.className = "issue span3";

    IssueView.prototype.template = _.template($('#issue-template').html());

    IssueView.prototype.events = {
      "click h2": "doOpenStart",
      "click div div .card": "doStart",
      "click div div .cls": "doClose",
      "click div div .ddt": "doDdt",
      "click div div .edit": "doEdit"
    };

    IssueView.prototype.doOpenStart = function() {
      var $e, issue, project, url;

      issue = this.model.toJSON();
      project = new Project().find(issue.project_id).toJSON();
      console.log(issue);
      url = issue.url;
      if (project.url && !url) {
        url = project.url;
      }
      if (url) {
        startWorkLog(issue_id);
        window.open(url, "issue_" + issue_id);
      } else {
        $e = $(this).parent().find(".body");
        turnback($e);
      }
      return false;
    };

    IssueView.prototype.doStart = function() {
      return doCard(this.model.id);
    };

    IssueView.prototype.doClose = function() {
      var issue;

      issue = this.model;
      if (!issue.is_closed()) {
        issue.set_closed();
        stopWorkLog();
        return this.$el.fadeOut(200);
      } else {
        issue.cancel_closed();
        return location.reload();
      }
    };

    IssueView.prototype.doDdt = function() {
      var issue;

      issue = this.model;
      if (!issue.is_ddt()) {
        issue.set_ddt();
        stopWorkLog();
        return this.$el.fadeOut(200);
      } else {
        issue.cancel_ddt();
        return location.reload();
      }
    };

    IssueView.prototype.doEdit = function() {
      var i, issue;

      issue = this.model;
      i = issue.toJSON();
      issue.set({
        title: prompt('issue title', i.title),
        url: prompt('issue url', i.url),
        body: prompt('issue body', i.body)
      });
      issue.save();
      return location.reload();
    };

    IssueView.prototype.render = function() {
      var issue, template;

      issue = this.model.toJSON();
      template = this.template(issue);
      this.$el.html(template);
      if (this.model.is_active()) {
        $("#project_" + issue.project_id).show();
      } else {
        this.$el.hide();
      }
      return this;
    };

    return IssueView;

  })(Backbone.View);

  IssuesView = (function(_super) {
    __extends(IssuesView, _super);

    function IssuesView() {
      _ref1 = IssuesView.__super__.constructor.apply(this, arguments);
      return _ref1;
    }

    IssuesView.prototype.tagName = 'div';

    return IssuesView;

  })(Backbone.View);

  this.IssueView = IssueView;

  this.IssuesView = IssuesView;

}).call(this);

(function() {
  var AddProjectView, ProjectView, ProjectsView, _ref, _ref1, _ref2,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  ProjectView = (function(_super) {
    __extends(ProjectView, _super);

    function ProjectView() {
      _ref = ProjectView.__super__.constructor.apply(this, arguments);
      return _ref;
    }

    ProjectView.prototype.tagName = 'div';

    ProjectView.prototype.className = 'project';

    ProjectView.prototype.initialize = function() {
      return this.model.on('change', this.render, this);
    };

    ProjectView.prototype.events = {
      "click div .edit a": "clickEdit",
      "click div .ddt a": "clickDdt",
      "keypress div .input-append .input": "pressAddIssue"
    };

    ProjectView.prototype.pressAddIssue = function(e) {
      var project_id, title;

      if (e.which === 13) {
        title = $(e.target).val();
        project_id = this.model.id;
        if (title.length > 0) {
          addIssue(project_id, title);
          return $(e.target).val("");
        } else {
          return alert("please input the title");
        }
      }
    };

    ProjectView.prototype.clickEdit = function() {
      var p, project;

      project = new Project().find(this.model.id);
      p = project.toJSON();
      project.set({
        name: prompt('project name', p.name),
        url: prompt('project url', p.url)
      });
      return project.save();
    };

    ProjectView.prototype.clickDdt = function() {
      return doDdtProject(this.model.id);
    };

    ProjectView.prototype.template = _.template($('#project-template').html());

    ProjectView.prototype.render = function() {
      var template;

      template = this.template(this.model.toJSON());
      this.$el.html(template);
      return this;
    };

    return ProjectView;

  })(Backbone.View);

  ProjectsView = (function(_super) {
    __extends(ProjectsView, _super);

    function ProjectsView() {
      _ref1 = ProjectsView.__super__.constructor.apply(this, arguments);
      return _ref1;
    }

    ProjectsView.prototype.id = "issues";

    ProjectsView.prototype.tagName = 'div';

    ProjectsView.prototype.initialize = function() {
      return this.collection.on('add', this.addNew, this);
    };

    ProjectsView.prototype.addNew = function(project) {
      var projectView;

      projectView = new ProjectView({
        model: project,
        id: "project_" + project.id
      });
      return this.$el.append(projectView.render().el);
    };

    ProjectsView.prototype.className = "row-fluid";

    ProjectsView.prototype.render = function() {
      this.collection.each(function(project) {
        var projectView;

        projectView = new ProjectView({
          model: project,
          id: "project_" + project.id
        });
        return this.$el.append(projectView.render().el);
      }, this);
      return this;
    };

    return ProjectsView;

  })(Backbone.View);

  AddProjectView = (function(_super) {
    __extends(AddProjectView, _super);

    function AddProjectView() {
      _ref2 = AddProjectView.__super__.constructor.apply(this, arguments);
      return _ref2;
    }

    AddProjectView.prototype.el = ".add_project";

    AddProjectView.prototype.events = {
      "click": "clicked"
    };

    AddProjectView.prototype.clicked = function(e) {
      var issue, name, project, title;

      e.preventDefault();
      name = prompt('please input the project name', '');
      title = prompt('please input the issue title', 'add issues');
      project = new Project();
      issue = new Issue();
      if (project.set({
        name: name
      }, {
        validate: true
      })) {
        project.save();
        this.collection.add(project);
        if (issue.set({
          title: title,
          project_id: project.get("id")
        }, {
          validate: true
        })) {
          return issue.save();
        }
      }
    };

    return AddProjectView;

  })(Backbone.View);

  this.ProjectView = ProjectView;

  this.ProjectsView = ProjectsView;

  this.AddProjectView = AddProjectView;

}).call(this);

(function() {
  var socket;

  if (typeof io !== "undefined" && io !== null) {
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
  }

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
  var addFigure, apDay, cdown, checkImport, db, debug, dispDate, dispTime, doDdtProject, doImport, findIssueByWorkLog, findProjectByIssue, findWillUploads, forUploadIssue, forUploadWorkLog, hl, init, innerLink, last_fetch, loopFetch, loopRenderWorkLogs, prepareDoExport, prepareDoImport, prepareShowProjects, pushIfHasIssue, renderCalendar, renderCalendars, renderProjects, renderWorkLogs, renderWorkingLog, setInfo, startWorkLog, turnback, uicon, updateWorkingLog, wbr, working_log, zero, zp;

  init = function() {
    cdown();
    prepareShowProjects();
    prepareDoExport();
    prepareDoImport();
    renderProjects();
    renderWorkLogs();
    $(".calendar").hide();
    return loopRenderWorkLogs();
  };

  renderProjects = function() {
    var addProjectView, issue, issueView, issues, projects, projectsView, _i, _len, _ref, _results;

    projects = new Project().find_all();
    projectsView = new ProjectsView({
      collection: projects
    });
    addProjectView = new AddProjectView({
      collection: projects
    });
    $("#wrapper").html(projectsView.render().el);
    issues = new Issue().find_all();
    _ref = issues.models;
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      issue = _ref[_i];
      issueView = new IssueView({
        model: issue,
        id: "issue_" + issue.id
      });
      _results.push($("#project_" + (issue.get('project_id')) + " div .issues").append(issueView.render().el));
    }
    return _results;
  };

  prepareShowProjects = function() {
    return $(".show_projects").click(function() {
      $(".project").fadeIn(100);
      return $(".issue").fadeIn(100);
    });
  };

  prepareDoExport = function() {
    return hl.click(".do_export", function(e, target) {
      var a, blob, caseTitle, d, result, title, url;

      result = {
        projects: db.find("projects"),
        issues: db.find("issues"),
        work_logs: db.find("work_logs"),
        servers: db.find("servers"),
        infos: db.find("infos")
      };
      blob = new Blob([JSON.stringify(result)]);
      url = window.URL.createObjectURL(blob);
      d = new Date();
      caseTitle = "Timecard";
      title = caseTitle + "_" + d.getFullYear() + zp(d.getMonth() + 1) + d.getDate() + ".json";
      a = $('<a id="download"></a>').text("download").attr("href", url).attr("target", '_blank').attr("download", title).hide();
      $(".do_export").after(a);
      $("#download")[0].click();
      return false;
    });
  };

  prepareDoImport = function() {
    hl.click(".do_import", function(e, target) {
      var datafile;

      datafile = $("#import_file").get(0).files[0];
      if (datafile) {
        return checkImport(datafile);
      } else {
        return $("#import_file").click();
      }
    });
    return $("#import_file").change(function() {
      var datafile;

      datafile = $("#import_file").get(0).files[0];
      if (datafile) {
        return checkImport(datafile);
      } else {
        return alert("invalid data.");
      }
    });
  };

  checkImport = function(datafile) {
    var reader;

    reader = new FileReader();
    reader.onload = function(evt) {
      var json, result;

      json = JSON.parse(evt.target.result);
      result = doImport(json);
      if (result) {
        alert("import is done.");
        return location.reload();
      } else {
        return alert("import is failed.");
      }
    };
    reader.readAsText(datafile, 'utf-8');
    return false;
  };

  doImport = function(json) {
    var data, item, table_name, _i, _len;

    for (table_name in json) {
      data = json[table_name];
      db.del(table_name);
      for (_i = 0, _len = data.length; _i < _len; _i++) {
        item = data[_i];
        db.ins(table_name, item);
      }
    }
    return true;
  };

  innerLink = function() {
    var project, projects, res, _i, _len;

    res = "<div class=\"innerlink\"> | ";
    projects = Project.find_all;
    for (_i = 0, _len = projects.length; _i < _len; _i++) {
      project = projects[_i];
      res += "<span class=\"project_" + project.id + "\"><a href=\"#project_" + project.id + "\">" + project.name + "</a> | </span>";
    }
    res += "</div>";
    return res;
  };

  doDdtProject = function(project_id) {
    var issue, _i, _len, _ref, _results;

    _ref = db.find("issues", {
      project_id: project_id
    });
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      issue = _ref[_i];
      if (issue.will_start_at < now()) {
        _results.push(doDdt(issue.id));
      } else {
        _results.push(void 0);
      }
    }
    return _results;
  };

  this.doCard = function(issue_id) {
    if (issue_id == null) {
      issue_id = null;
    }
    return updateWorkingLog(null, issue_id);
  };

  startWorkLog = function(issue_id) {
    return updateWorkingLog(true, issue_id);
  };

  this.stopWorkLog = function() {
    if (working_log()) {
      return updateWorkingLog(false);
    }
  };

  updateWorkingLog = function(is_start, issue_id) {
    var $all_cards, $issue_cards, issue, project, wl;

    if (is_start == null) {
      is_start = null;
    }
    if (issue_id == null) {
      issue_id = null;
    }
    $all_cards = $(".card");
    $all_cards.html("Start");
    $all_cards.removeClass("btn-warning");
    $all_cards.addClass("btn-primary");
    wl = working_log();
    if (is_start === false) {
      issue_id = wl.issue_id;
    }
    if (wl && issue_id) {
      wl.end_at = now();
      db.upd("work_logs", wl);
      issue = db.one("issues", {
        id: issue_id
      });
      issue.upd_at = now();
      project = db.one("projects", {
        id: issue.project_id
      });
      project.upd_at = now();
      db.upd("issues", issue);
      db.upd("projects", project);
      $("title").html("Timecard");
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
    if (working_log()) {
      $issue_cards = $(".issue_" + issue_id + " .card");
      $issue_cards.html("Stop");
      $issue_cards.removeClass("btn-primary");
      $issue_cards.addClass("btn-warning");
    }
    return renderWorkLogs();
  };

  this.addIssue = function(project_id, title) {
    var issue;

    issue = db.ins("issues", {
      title: title,
      project_id: project_id,
      body: ""
    });
    return renderIssue(issue, "prepend");
  };

  renderWorkLogs = function(server) {
    var btn_type, disp, issue, s, url, wl, work_log, _i, _len, _ref, _results;

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
      disp = "Start";
      btn_type = "btn-primary";
      if (working_log() && working_log().issue_id === work_log.issue_id) {
        disp = "Stop";
        btn_type = "btn-warning";
      }
      s = new Date(work_log.started_at * 1000);
      $(".md_" + (s.getMonth() + 1) + "_" + (s.getDate())).append("<div>" + issue.title + "</div>");
      $("#work_logs").append("<tr class=\"work_log_" + work_log.id + "\">\n<td class=\"word_break\">\n" + (wbr(issue.title, 9)) + "\n</td>\n<td>\n" + (dispDate(work_log)) + "\n</td>\n<td>\n<span class=\"time\">" + (dispTime(work_log)) + "</span>\n</td>\n<td>\n" + (work_log.server_id ? "" : uicon) + "\n<div class=\"work_log_" + work_log.id + " issue_" + issue.id + "\" style=\"padding:10px;\">\n<a href=\"#\" class=\"card btn " + btn_type + "\" data-issue-id=\"" + issue.id + "\">" + disp + "</a>\n</div>\n</td>\n</tr>");
      $(".work_log_" + work_log.id + " .card").click(function() {
        var work_log_id;

        work_log_id = parseInt($(this).attr("data-issue-id"));
        doCard(work_log_id);
        return false;
      });
      if (false) {
        if (!work_log.end_at) {
          _results.push(wl = work_log);
        } else {
          _results.push(void 0);
        }
      } else {
        _results.push(void 0);
      }
    }
    return _results;
  };

  wbr = function(str, num) {
    return str.replace(RegExp("(\\w{" + num + "})(\\w)", "g"), function(all, text, char) {
      return text + "<wbr>" + char;
    });
  };

  renderCalendars = function() {
    var mon, now, year;

    now = new Date();
    year = now.getYear() + 1900;
    mon = now.getMonth() + 1;
    renderCalendar("this_month", now);
    now = new Date(year, mon, 1);
    return renderCalendar("next_month", now);
  };

  renderCalendar = function(key, now) {
    var $day, d, day, i, mon, start, w, wday, year, _i;

    year = now.getYear() + 1900;
    mon = now.getMonth() + 1;
    day = now.getDate();
    wday = now.getDay();
    start = wday - day % 7 - 1;
    w = 1;
    $("." + key + " h2").html("" + year + "-" + (zp(mon)));
    for (i = _i = 1; _i <= 31; i = ++_i) {
      d = (i + start) % 7 + 1;
      $day = $("." + key + " table .w" + w + " .d" + d);
      $day.html(i).addClass("day" + i);
      if (i === day && key === "this_month") {
        $day.css("background", "#fc0");
      }
      $day.addClass("md_" + mon + "_" + i);
      if (d === 7) {
        w += 1;
      }
    }
    return renderWorkLogs();
  };

  renderWorkingLog = function() {
    var issue, time, wl;

    wl = working_log();
    if (wl) {
      time = dispTime(wl);
      $(".work_log_" + wl.id + " .time").html(time);
      $("#issue_" + wl.issue_id + " h2 .time").html("(" + time + ")");
      $("#issue_" + wl.issue_id + " div div .card").html("Stop");
      issue = db.one("issues", {
        id: wl.issue_id
      });
      $(".hero-unit h1").html(issue.title);
      $(".hero-unit p").html(issue.body);
    }
    return $("title").html(time);
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

  dispDate = function(work_log) {
    var time;

    time = new Date(work_log.started_at * 1000);
    return "" + (time.getMonth() + 1) + "/" + (time.getDate());
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

  this.now = function() {
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
    if (data == null) {
      data = null;
    }
    console.log(title);
    if (data) {
      return console.log(data);
    }
  };

  working_log = function(issue_id, is_start) {
    var cond;

    if (issue_id == null) {
      issue_id = null;
    }
    if (is_start == null) {
      is_start = true;
    }
    cond = {
      end_at: null
    };
    return db.one("work_logs", cond);
  };

  cdown = function() {
    var end, start;

    start = apDay(2007, 5, 11);
    end = apDay(2017, 5, 11);
    return $("#cdown").html("" + (addFigure(start)) + "<br />" + (addFigure(end)));
  };

  apDay = function(y, m, d) {
    var apday, dayms, n, today;

    today = new Date();
    apday = new Date(y, m - 1, d);
    dayms = 24 * 60 * 60 * 100;
    n = Math.floor((apday.getTime() - today.getTime()) / dayms) + 1;
    return n;
  };

  window.db = db;

  zp = function(n) {
    if (n >= 10) {
      return n;
    } else {
      return '0' + n;
    }
  };

  addFigure = function(str) {
    var num;

    num = new String(str).replace(/,/g, "");
    while (num !== num.replace(/^(-?\d+)(\d{3})/, "$1,$2")) {
      num = num.replace(/^(-?\d+)(\d{3})/, "$1,$2");
    }
    return num;
  };

  $(function() {
    return init();
  });

}).call(this);

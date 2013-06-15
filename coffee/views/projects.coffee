class ProjectView extends Backbone.View
  tagName: 'div',
  className: 'project',
  initialize: () ->
    this.model.on('change', this.render, this)
  events: {
    "click div .edit a": "clickEdit"
    "click div .ddt a" : "clickDdt"
    "keypress div .input-append .input": "pressAddIssue"
  }
  pressAddIssue: (e) ->
    if e.which == 13
      console.log
      title = $(e.target).val()
      project_id = this.model.id
      if title.length > 0
        addIssue(project_id, title)
        $(e.target).val("")
      else
        alert "please input the title"
  clickEdit: () ->
    doEditProject(this.model.id)
  clickDdt: () ->
    doDdtProject(this.model.id)
  template: _.template($('#project-template').html()),
  render : () ->
    template = this.template(this.model.toJSON())
    this.$el.html(template)
    return this

class ProjectsView extends Backbone.View
  id: "issues"
  tagName: 'div'
  initialize: () ->
    this.collection.on('add', this.addNew, this)
  addNew: (project) ->
    projectView = new ProjectView({model: project})
    this.$el.append(projectView.render().el)
  className: "row-fluid"
  render: () ->
    this.collection.each((project) ->
      projectView = new ProjectView({
        model: project
        id   : "project_#{project.id}"
      })
      this.$el.append(projectView.render().el)
    , this)
    return this

class AddProjectView extends Backbone.View
  el: ".add_project"
  events: {
    "click": "clicked"
  },
  clicked: (e) ->
    e.preventDefault()
    project = new Project()
    name = prompt('please input the project name', '')
    issue_title = prompt('please input the issue title', 'add issues')
    if project.set({name: name}, {validate: true})
      p = db.ins("projects", {name: name})
      db.ins("issues", {title: issue_title, project_id: p.id})
      this.collection.add(project)

@ProjectView = ProjectView
@ProjectsView = ProjectsView
@AddProjectView = AddProjectView

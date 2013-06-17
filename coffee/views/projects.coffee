class ProjectView extends Backbone.View
  tagName: 'div'
  className: 'project'
  initialize: () ->
    this.model.on('change', this.render, this)
  events: {
    "click div .edit a": "clickEdit"
    "click div .ddt a" : "clickDdt"
    "keypress div .input-append .input": "pressAddIssue"
  }
  pressAddIssue: (e) ->
    if e.which == 13
      title = $(e.target).val()
      project_id = this.model.id
      if title.length > 0
        addIssue(project_id, title)
        $(e.target).val("")
      else
        alert "please input the title"
  clickEdit: () ->
    project = new Project().find(this.model.id)
    p = project.toJSON()
    project.set({
      name: prompt('project name', p.name)
      url : prompt('project url',  p.url)
    })
    project.save()
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
    projectView = new ProjectView({
      model: project
      id   : "project_#{project.id}"
    })
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
    name = prompt('please input the project name', '')
    title = prompt('please input the issue title', 'add issues')
    project = new Project()
    issue   = new Issue()
    if project.set({name: name}, {validate: true})
      project.save()
      this.collection.add(project)
      if issue.set(
        {
          title     : title,
          project_id: project.get("id")
        }, {validate: true})
        issue.save()

@ProjectView = ProjectView
@ProjectsView = ProjectsView
@AddProjectView = AddProjectView

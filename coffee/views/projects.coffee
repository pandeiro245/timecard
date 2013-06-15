class ProjectView extends Backbone.View
  tagName: 'div',
  className: 'project',
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
  tagName: 'div',
  id: "issues",
  className: "row-fluid",
  render: () ->
    this.collection.each((project) ->
      projectView = new ProjectView({
        model: project
        id   : "project_#{project.id}"
      })
      this.$el.append(projectView.render().el)
    , this)
    return this

@ProjectView = ProjectView
@ProjectsView = ProjectsView

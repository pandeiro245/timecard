class Project extends Backbone.Model
  validate: (attrs) ->
    if _.isEmpty(attrs.name)
      return "project name must not be empty"
  initialize: () ->
    this.on('invalid', (model, error) ->
      alert(error)
    )

class Projects extends Backbone.Collection
  model: Project

@Project = Project
@Projects = Projects

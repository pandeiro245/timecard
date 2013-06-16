class Project extends JSRelModel
  #for JSRelmodel start
  table_name: "projects"
  thisclass:  (params) ->
    return new Project(params)
  collection: (params) ->
    return new Projects(params)
  #for JSRelmodel end

  validate: (attrs) ->
    if _.isEmpty(attrs.name)
      return "project name must not be empty"

class Projects extends Backbone.Collection
  model: Project

@Project = Project
@Projects = Projects

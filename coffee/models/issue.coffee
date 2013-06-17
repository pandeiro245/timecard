class Issue extends JSRelModel
  #for JSRelmodel start
  table_name: "issues"
  thisclass:  (params) ->
    return new Issue(params)
  collection: (params) ->
    return new Issues(params)
  #for JSRelmodel end

  validate: (attrs) ->
    if _.isEmpty(attrs.title)
      return "issue.title must not be empty"
  is_ddt: () ->
    wsat = this.get("will_start_at")
    return !(!wsat or wsat < now())
  set_ddt: () ->
    this.set(
      "will_start_at"
      now() + 12*3600 + parseInt(Math.random(10)*10000)
    )
    this.save()
  cancel_ddt: () ->
    this.set("will_start_at", null)
    this.save()
  is_closed: () ->
    cat = this.get("closed_at")
    return if cat > 0 then true else false
  set_closed: () ->
    this.set("closed_at", now())
    this.save()
  cancel_closed: () ->
    this.set("closed_at", 0)
    this.cancel_ddt()
    this.save()
  is_active: () ->
    return true if !this.is_closed() && !this.is_ddt()
    return false

  project: () ->
    return Project.find(this.project_id)
class Issues extends Backbone.Collection
  model: Issue

@Issue = Issue
@Issues = Issues

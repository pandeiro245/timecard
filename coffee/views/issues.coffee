class IssueView extends Backbone.View
  tagName : 'div'
  className : "issue span3"
  template: _.template(
    $('#issue-template').html()
  )
  events:{
    "click h2"            : "doOpenStart"
    "click div div .card" : "doStart"
    "click div div .cls"  : "doClose"
    "click div div .ddt"  : "doDdt"
    "click div div .edit" : "doEdit"
  }
  doOpenStart: () ->
    issue =this.model.toJSON()
    project = new Project().find(issue.project_id).toJSON()
    console.log issue
    url = issue.url
    url = project.url if project.url and !url
    if url
      startWorkLog(issue_id)
      window.open(url, "issue_#{issue_id}")
    else
      $e = $(this).parent().find(".body")
      turnback($e)
    return false

  doStart: () ->
    doCard(this.model.id)
  doClose: () ->
    issue =this.model
    unless issue.is_closed()
      issue.set_closed()
      stopWorkLog()
      this.$el.fadeOut(200)
    else
      issue.cancel_closed()
      location.reload()
  doDdt: () ->
    issue = this.model
    unless issue.is_ddt()
      issue.set_ddt()
      stopWorkLog()
      this.$el.fadeOut(200)
    else
      issue.cancel_ddt()
      location.reload()
  doEdit: () ->
    issue = this.model
    i = issue.toJSON()
    issue.set({
      title: prompt('issue title', i.title)
      url  : prompt('issue url',   i.url)
      body : prompt('issue body',  i.body)
    })
    issue.save()
    location.reload()

  render  : () ->
    issue = this.model.toJSON()
    template = this.template(
      issue
    )
    this.$el.html(template)
    if this.model.is_active()
      $("#project_#{issue.project_id}").show()
    else
      this.$el.hide()
    return this

class IssuesView extends Backbone.View
  tagName : 'div'

@IssueView = IssueView
@IssuesView = IssuesView

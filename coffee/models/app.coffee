class JSRelModel extends Backbone.Model
  initialize: () ->
    this.on('invalid', (model, error) ->
      alert(error)
    )
  save: () ->
    cond = this.toJSON()
    if cond.id
      p = db.upd(this.table_name, cond)
    else
      p = db.ins(this.table_name, cond)
      this.set("id", p.id)
  find : (id) ->
    return new this.thisclass(
      db.one(this.table_name, {id: id})
    )
  find_all : () ->
    return this.collection(
      db.find(this.table_name, null, {
        order: {upd_at: "desc"}
      })
    )
@JSRelModel = JSRelModel

class DataController < ApplicationController
  def show
    raise unless current_user
    raise if Member.where(user_id: current_user.id, project_id: params[:id].to_i).blank?
    res = {}
    project = Project.find(params[:id])
    res["name"] = project.name
    res["issues"] = project.issues.map do |issue|
      iss = JSON.parse(issue.to_json)
      iss["author_email"] = issue.author.email
      iss.delete("author_id")
      iss["created_at"] = issue.created_at.to_i
      iss["updated_at"] = issue.updated_at.to_i
      iss["work_logs"] = WorkLog.where(issue_id: issue["id"]).map{|wl|
        wl_hash = JSON.parse(wl.to_json)
        wl_hash["start_at"] = wl.start_at.to_i
        wl_hash["end_at"] = wl.end_at.to_i
        wl_hash["user_email"] = wl.user.email
        wl_hash.delete("user_id")
        wl_hash
      }.map{|wl|
        wl.delete("id")
        wl.delete("issue_id")
        wl.delete("created_at")
        wl.delete("updated_at")
        wl
      }
      iss.delete("id")
      iss.delete("project_id")
      iss
    end

    render json: res.to_json
  end

  def create
    project = JSON.parse(params[:import].read)
    @project = Project.new(name: project["name"])
    @project.save
    project["issues"].each do |iss|
      issue = Issue.new(subject: iss["subject"])
      issue.created_at = Time.at(iss["created_at"])
      issue.author_id = User.find_or_create_by(email: iss["author_email"]).id
      issue.project_id = @project.id
      issue.save
      iss["work_logs"].each do |wl|
        work_log = WorkLog.new
        work_log.user_id = User.find_or_create_by(email: wl["user_email"]).id
        work_log.start_at = Time.at(wl["start_at"])
        work_log.end_at = Time.at(wl["end_at"])
        work_log.issue_id = issue.id
        work_log.save
      end
    end
    redirect_to project_path(@project)
  end
end

class MembersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [:index, :create]
  before_action :set_member, only: [:destroy]
  before_action :require_admin

  def index
    @members = @project.members
  end

  def create
    @member = @project.members.build(user_id: params[:user_id])
    respond_to do |format|
      if @member.save
        format.html { redirect_to project_members_path(@project), notice: 'Member was successfully added.' }
        format.json { render action: 'show', status: :created, location: @member }
      end
    end
  end

  def destroy
    @member.destroy
    respond_to do |format|
      format.html { redirect_to project_members_path(@member.project) }
      format.json { head :no_content }
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_member
    @member = Member.find(params[:id])
  end

  def require_admin
    project = @project ? @project : @member.project
    redirect_to root_path, alert: "You are not project admin." unless project.admin?(current_user)
  end
end

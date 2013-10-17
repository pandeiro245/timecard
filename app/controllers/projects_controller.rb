class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [:show, :edit, :update, :destroy, :archive, :active, :close]
  before_action :reject_archived, except: [:index, :new, :create, :active]
  before_action :require_admin, only: [:edit, :update, :destroy, :archive, :active, :close]
  before_action :require_member, only: [:show]

  # GET /projects
  # GET /projects.json
  def index
    status = params[:status] || 1
    case status.to_i
    when Project::STATUS_ACTIVE
      public_projects = Project.public.active.where_values.reduce(:and)
      my_projects = Project.active.where(id: Member.where(user_id: current_user.id).pluck(:project_id)).where_values.reduce(:and)
    when Project::STATUS_CLOSED
      public_projects = Project.public.closed.where_values.reduce(:and)
      my_projects = Project.closed.where(id: Member.where(user_id: current_user.id).pluck(:project_id)).where_values.reduce(:and)
    when Project::STATUS_ARCHIVED
      public_projects = Project.public.archive.where_values.reduce(:and)
      my_projects = Project.archive.where(id: Member.where(user_id: current_user.id).pluck(:project_id)).where_values.reduce(:and)
    end
    @projects = Project.where(public_projects.or(my_projects))
  end

  # GET /projects/1
  # GET /projects/1.json
  def show
    @title = @project.name
  end

  # GET /projects/new
  def new
    @project = Project.new
  end

  # GET /projects/1/edit
  def edit
  end

  # POST /projects
  # POST /projects.json
  def create
    @project = Project.new(project_params)

    respond_to do |format|
      if @project.save
        m = Member.new(user: current_user, is_admin: true)
        @project.members << m
        format.html { redirect_to @project, notice: 'Project was successfully created.' }
        format.json { render action: 'show', status: :created, location: @project }
      else
        format.html { render action: 'new' }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /projects/1
  # PATCH/PUT /projects/1.json
  def update
    respond_to do |format|
      if @project.update(project_params)
        format.html { redirect_to @project, notice: 'Project was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  def archive
    respond_to do |format|
      if @project.update(status: Project::STATUS_ARCHIVED)
        format.html { redirect_to projects_path, notice: 'Project was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'show' }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  def active
    respond_to do |format|
      if @project.update(status: Project::STATUS_ACTIVE)
        format.html { redirect_to @project, notice: 'Project was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'show' }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  def close
    respond_to do |format|
      if @project.update(status: Project::STATUS_CLOSED)
        format.html { redirect_to @project, notice: 'Project was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'show' }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_project
      @project = Project.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def project_params
      params.require(:project).permit(:name, :description, :is_public, :parent_id, :status)
    end

    def require_admin
      redirect_to root_path, alert: "You are not project admin." unless @project.admin?(current_user)
    end

    def require_member
      return if @project.is_public
      redirect_to root_path, alert: "You are not project member." unless @project.member?(current_user)
    end

    def reject_archived
      redirect_to root_path, alert: "You need to sign in or sign up before continuing." if @project.status == Project::STATUS_ARCHIVED
    end
end

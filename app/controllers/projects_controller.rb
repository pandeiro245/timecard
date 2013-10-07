class ProjectsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [:show, :edit, :update, :destroy]
  before_action :require_admin, only: [:edit, :update, :destroy]
  before_action :require_member, only: [:show]

  # GET /projects
  # GET /projects.json
  def index
    active_projects = Project.active.public.where_values.reduce(:and)
    my_projects = Project.where(id: Member.where(user_id: current_user.id).pluck(:project_id)).where_values.reduce(:and)
    @projects = Project.where(active_projects.or(my_projects))
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

  # DELETE /projects/1
  # DELETE /projects/1.json
  def destroy
    @project.destroy
    respond_to do |format|
      format.html { redirect_to projects_url }
      format.json { head :no_content }
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
end

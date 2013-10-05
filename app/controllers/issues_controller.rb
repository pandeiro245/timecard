class IssuesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project, only: [:new, :create]
  before_action :set_issue, only: [:show, :edit, :update, :destroy, :close, :reopen]

  # GET /issues
  # GET /issues.json
  def index
    @issues = Issue.all
  end

  # GET /issues/1
  # GET /issues/1.json
  def show
    @title = @issue.subject
  end

  # GET /issues/new
  def new
    @issue = @project.issues.build
  end

  # GET /issues/1/edit
  def edit
  end

  # POST /issues
  # POST /issues.json
  def create
    @issue = @project.issues.build(issue_params)

    respond_to do |format|
      if @issue.save
        format.html { redirect_to @issue, notice: 'Issue was successfully created.' }
        format.json { render action: 'show', status: :created, location: @issue }
      else
        format.html { render action: 'new' }
        format.json { render json: @issue.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /issues/1
  # PATCH/PUT /issues/1.json
  def update
    respond_to do |format|
      if @issue.update(issue_params)
        format.html { redirect_to @issue, notice: 'Issue was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @issue.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /issues/1
  # DELETE /issues/1.json
  def destroy
    @issue.destroy
    respond_to do |format|
      format.html { redirect_to issues_url }
      format.json { head :no_content }
    end
  end

  # PATCH/PUT projects/1/issues/1/close
  # PATCH/PUT projects/1/issues/1/close.json
  def close
    if @issue.update_attribute(:status, 9)
      respond_to do |format|
        format.html { redirect_to @issue, notice: 'Issue was successfully updated.' }
        format.json { head :no_content }
      end
    end
  end

  # PATCH/PUT projects/1/issues/1/reopen
  # PATCH/PUT projects/1/issues/1/reopen.json
  def reopen
    if @issue.update_attribute(:status, 1)
      respond_to do |format|
        format.html { redirect_to @issue, notice: 'Issue was successfully updated.' }
        format.json { head :no_content }
      end
    end
  end

  private
    def set_project
      @project = Project.find(params[:project_id])
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_issue
      @issue = Issue.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def issue_params
      params.require(:issue).permit(:subject, :description, :author_id, :assignee_id)
    end
end

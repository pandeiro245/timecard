json.array!(@issues) do |issue|
  json.extract! issue, :subject, :description, :start_date, :integer, :closed_on, :project_id, :author_id, :assignee_id
  json.url issue_url(issue, format: :json)
end

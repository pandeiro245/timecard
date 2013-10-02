json.array!(@work_logs) do |work_log|
  json.extract! work_log, :start_at, :end_at, :issue_id, :user_id
  json.url work_log_url(work_log, format: :json)
end

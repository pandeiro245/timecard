window.schema = {
  servers: {
    domain: "",
    login: "",
    pass: "",
    token: "",
    user_id: 0,
    dbtype: "",
    has_connect: "off",
    $uniques: "domain",
  },
  projects: {
    name: "",
    body: "",
    server_id: 0,
    //$uniques: "server_id"
  },
  issues: {
    title: "",
    body: "",
    project_id: 0,
    server_id: 0,
    is_ddt: "off",
    closed_at: 0,
    user_id: 0,
    assignee_id: 0,
    will_start_at: 0,
    parent_id:0,
    //$uniques: "server_id"
  },
  work_logs: {
    issue_id: 0,
    started_at: 0,
    end_at: 0,
    server_id: 0,
    user_id: 0,
    //$uniques: "server_id"
  },
  infos: {
    key: "",
    val: "",
    $uniques: "key"
  },
}

defmodule Jira.API do
  use HTTPoison.Base

  defp config_or_env(key, env_var) do
    Application.get_env(:jira, key, System.get_env(env_var))
  end

  defp host do
    config_or_env(:host, "JIRA_HOST")
  end

  defp username do
    config_or_env(:username, "JIRA_USERNAME")
  end

  defp password do
    config_or_env(:password, "JIRA_PASSWORD")
  end

  ### HTTPoison.Base callbacks
  def process_url(url) do
    host() <> url
  end

  def process_response_body(body) do
    body
    |> decode_body()
  end

  def process_request_headers(headers) do
    [{"authorization", authorization_header()}|headers]
  end

  defp decode_body(""), do: ""
  defp decode_body(<<"\n\n",_::binary>> = body), do: body
  defp decode_body(<<"<",_::binary>> = body), do: body
  defp decode_body(body) do
    body |> Poison.decode!
  end

  ### Internal Helpers
  def authorization_header do
    credentials = encoded_credentials(username(), password())
    "Basic #{credentials}"
  end

  defp encoded_credentials(user, pass) do
    "#{user}:#{pass}"
    |> Base.encode64()
  end

  ### API
  def mysels do
    get!("/rest/api/2/myself").body
  end

  def projects do
    get!("/rest/api/2/project").body
  end

  def issues(project) do
    get!("/rest/api/2/search?jql=project=\"#{project}\"").body
  end

  def boards do
    get!("/rest/greenhopper/1.0/rapidview").body
  end

  def sprints(board_id) when is_integer(board_id) do
    get!("/rest/greenhopper/1.0/sprintquery/#{board_id}").body
  end
  def sprints(%{"id"=>board_id}), do: sprints(board_id)

  def sprint_report(board_id, sprint_id) do
    get!("/rest/greenhopper/1.0/rapid/charts/sprintreport?rapidViewId=#{board_id}&sprintId=#{sprint_id}").body
  end

  def ticket_details(key) do
    get!("/rest/api/2/issue/#{key}").body
  end

  def ticket_transitions(key) do
    get!("/rest/api/2/issue/#{key}/transitions?expand=transitions.fields").body
  end

  def move_ticket(key, transitions_id) do
    body = %{"transition" => %{"id" => transitions_id}} |> Poison.encode!
    url = "/rest/api/latest/issue/#{key}/transitions?expand=transitions.fields"
    post!(url, body, [{"Content-type", "application/json"}])
  end

  def add_comment(key, comment) do
    body = %{"body" => comment} |> Poison.encode!
    url = "/rest/api/2/issue/#{key}/comment"
    post!(url, body, [{"Content-type", "application/json"}])
  end

  def add_ticket_watcher(key, username) do
    body = username |> Poison.encode!
    post!("/rest/api/2/issue/#{key}/watchers", body, [{"Content-type", "application/json"}])
  end

  def search(query) do
    body = query |> Poison.encode!
    post!("/rest/api/2/search", body, [{"Content-type", "application/json"}])
  end
end

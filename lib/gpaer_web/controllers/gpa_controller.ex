defmodule GpaerWeb.GpaController do
  use GpaerWeb, :controller
  alias Core.JwxtExtractor

  def index(conn, params) do
    %{"password" => password,
      "username" => username} = params
    list = JwxtExtractor.crawler(username, password)
    render conn, "gpa.json", data: list
  end
end

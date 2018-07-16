defmodule GpaerWeb.PageController do
  use GpaerWeb, :controller

  def index(conn, _params) do
    # conn
    # |> put_status(304)
    # |> render("login.html")
    # render conn, "index.html"
    redirect conn, to: "/login.html"
  end
end

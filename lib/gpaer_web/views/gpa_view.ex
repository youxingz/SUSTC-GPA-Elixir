defmodule GpaerWeb.GpaView do
  use GpaerWeb, :view
  # alias GpaerWeb.GpaView

  def render("gpa.json", %{data: data}) do
    data
    # |> Poison.encode!()
    # IO.inspect(data)
    # %{data: render_many(data, GpaView, "term.json")}
    # render_many(data, GpaView, "term.json")
  end

  def render("term.json", %{item: item}) do
    IO.inspect(item)
    %{item: item[:date]}
  end
end

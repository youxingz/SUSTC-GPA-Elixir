defmodule Core.CASConnector do
  @moduledoc """
  Documentation for CASConnector.
  """
  @cas_redirect_url "https://cas.sustc.edu.cn/cas/login?service=http://jwxt.sustc.edu.cn/jsxsd/"
  @cas_login_url "https://cas.sustc.edu.cn/cas/login"

  @headers_default [
    {"Connection", "keep-alive"},
    {"User-Agent", "Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.99 Mobile Safari/537.36"},
    {"Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"},
    {"Host", "cas.sustc.edu.cn"},
    {"Cache-Control", "max-age=0"},
    {"Upgrade-Insecure-Requests", "1"},
    {"Content-Type", "application/x-www-form-urlencoded"},
    {"Origin", "https://cas.sustc.edu.cn"},
    {"Referer", "https://cas.sustc.edu.cn/cas/login?service=http%3A%2F%2Fjwxt.sustc.edu.cn%2Fjsxsd%2F"}
  ]

  def obtain_session_id(uid, password) do
    # step1 get a cookie
    # %{
    #   cookie: cookie,
    #   execution: execution
    # }
    # step2 do login
    # %{
    #   tgc: tgc,
    #   redirect_url: url
    # }
    # step3 get session id
    # %{
    #   session_id: cookie,
    #   redirect_url: location
    # }
    %{
      session_id: cookie,
    } = take_cookie()
        |> do_login("#{uid}", "#{password}")
        |> take_session_id
    {:ok, cookie}
  end

  def take_session_id(%{redirect_url: url} = _param) do
    {:ok, %{headers: headers}} = HTTPoison.get url
    # cookie is JSESSIONID
    {"Set-Cookie", cookie} = List.keyfind(headers, "Set-Cookie", 0)
    # location is http://jwxt.sustc.edu.cn/jsxsd/framework/xsMain.jsp
    {"Location", location} = List.keyfind(headers, "Location", 0)
    %{
      session_id: cookie,
      redirect_url: location
    }
  end

  def do_login(%{execution: execution, cookie: cookie} = _param, uid, password) do
    form = [{"execution", execution},
            {"_eventId", "submit"},
            {"submit", "登录"},
            {"geolocation", ""},
            {"username", uid},
            {"password", password}]
    # |> IO.inspect
    {:ok, %{headers: headers}} = HTTPoison.post @cas_login_url, {:form, form}, [ {"Cookie", cookie} | @headers_default]
    {"Set-Cookie", cookie} = List.keyfind(headers, "Set-Cookie", 0)
    {"Location", location} = List.keyfind(headers, "Location", 0)
    %{
      tgc: cookie,
      redirect_url: location
    }
  end

  def take_cookie do
    {:ok, %{body: body, headers: headers}} = HTTPoison.get @cas_redirect_url, @headers_default
    # IO.inspect(headers, label: ">>>> CAS Page Headers")
    # IO.inspect(body, label: ">>>> CAS Page Body")
    {"Set-Cookie", cookie} =
      List.keyfind(headers, "Set-Cookie", 0)
    {"value", execution} =
      body
      |> Floki.find("input[name=execution]")
      |> List.first
      |> Tuple.to_list
      |> List.flatten
      |> List.keyfind("value", 0)
    %{
      cookie: cookie,
      execution: execution
    }
  end
end

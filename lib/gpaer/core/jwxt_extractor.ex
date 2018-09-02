defmodule Core.JwxtExtractor do
  @doc """
  Core.JwxtExtractor.h
  """

  alias Core.CASConnector

  @term_url "http://jwxt.sustc.edu.cn/jsxsd/kscj/cjcx_list"

  def crawler(uid, password) do
    IO.inspect("uid: #{uid}")
    {:ok, cookie} =
      CASConnector.obtain_session_id(uid, password)
    # uid
    # |> list_all_dates
    # |> Enum.map(fn date ->
    #   cookie
    #   |> extract_single_page(date)
    #   |> flatten_list(date)
    # end)
    # |> Enum.filter(fn x -> x != nil end)
    %{
      :personal_info => personal_info,
      :courses => courses
    } = extract_page(cookie)


    data = courses
    |> Enum.group_by(fn course -> # 组成 date, list 形式
      course.course_date
    end)
    # |> IO.inspect
    |> Enum.map(fn {date, courses} ->
      %{
        date: date,
        list: courses
      }
    end)
    |> fliter_courses_available() # 筛选哪些课程可以计算 GPA 的
    |> Enum.filter(fn {_date, list} ->
      list != []
    end)
    |> Enum.map(fn {date, list} ->
      %{
        date: date,
        list: list
      }
    end)
    # final result
    %{
      info: personal_info,
      data: data
    }
  end

  @doc """
  list = [{date, list},{}]
  有效课程：需要加入到 GPA 计算的课程
  """
  def fliter_courses_available(list) do
    mul_courses = list |> find_courses_multiple()
    bad_course_ids = mul_courses |> find_bad_courses()
    regex = Regex.compile!("^[+-]?[0-9]*\.?[0-9]*$")
    # 如果该课程只修读了一遍，则默认计入总 GPA，is_available 为 true
    list
    |> Enum.map(fn term ->
      list = term.list
      |> Enum.map(fn course ->
        course_list = mul_courses |> Map.get(course.course_id)
        if course_list == nil do
          # 如果该课程只修读了一遍，说明分数直接有效
          course |> invoke_values(true)
        else
          # 如果该课程修读不止一遍，则暂不处理，下一步会判断是否为可计算GPA的有效课程
          #case1 如果该课程修读了多遍，则找到课程最大分数，设定为有效课程
          course_max = course_list |> List.first
          if course_max.course_season_id ==  course.course_season_id do
            # IO.inspect("#{course.course_season_id}")
            course |> invoke_values(true)
          else
            #case2 如果该课程修读了多遍，且课程标志为 "缺考"、"违纪" 则设为有效课程
            course_id_bad = bad_course_ids |> List.keyfind(course.course_id, 0)
            if course_id_bad != nil do
              course |> invoke_values(true)
            else
              course
            end
          end
        end
      end)
      {term.date, list}
    end)
    # 设定 "通过"、"未通过" 这种课程为 is_available = false
    |> Enum.map(fn {date, list} ->
      final_list = list
      |> Enum.map(fn course ->
        dl = course.course_detail
        if regex |> Regex.match?(dl) do
          course
        else
          # "通过" "未通过"
          course |> invoke_values(false)
        end
      end)
      {date, final_list}
    end)
    # 如果该课程修读了多遍，则找到课程最大分数，设定为有效课程
    # 如果该课程修读了多遍，且课程标志为 "缺考"、"违纪" 则设为有效课程
  end

  # 找出多次修读的课程 id, season_id (CS101, 201720181000666)
  # 按课程分数从高到低排序
  def find_courses_multiple(list) do
    list
    |> Enum.map(fn term ->
      term.list
      |> Enum.map(fn course ->
        {course.course_id, course}
      end)
    end)
    # |> List.insert_at(0, "CH101")
    |> List.flatten
    |> Enum.group_by(fn {x, _y} ->
      x
    end)
    |> Enum.filter(fn {_x, y} ->
      Kernel.length(y) > 1
    end)
    |> Enum.map(fn {x, y} ->
      courses = y |> Enum.map(fn {_, course} ->
        course
      end)
      |> Enum.sort_by(fn course ->
        course.course_detail
      end)
      |> Enum.reverse()
      {x, courses}
    end)
    |> Enum.into(%{})
  end

  def find_bad_courses(map) do
    map
    |> Enum.filter(fn {_course_id, course_list} ->
      filter_course_list = course_list
      |> Enum.filter(fn course ->
        course.course_tag == "缺考" or
        course.course_tag == "违纪"
      end)
      filter_course_list != []
    end)
    |> Enum.map(fn {course_id, _course_list} ->
      course_id
    end)
  end

  defp invoke_values(course, is_available) do
    %{
      index: course.index,
      course_date: course.course_date,
      course_id: course.course_id,
      course_name: course.course_name,
      course_season_id: course.course_season_id,
      course_detail: course.course_detail,
      course_level: course.course_level,
      course_credit: course.course_credit,
      course_period: course.course_period,
      course_method: course.course_method,
      course_property: course.course_property,
      course_nature: course.course_nature,
      course_tag: course.course_tag,
      is_available: is_available
    }
  end

  @doc """
  crawler
  """

  def extract_page(cookie) do
    request_body = {:form, []}
    request_headers = [{"Cookie", cookie}]
    {:ok, %{body: body}} = HTTPoison.post @term_url, request_body, request_headers
    courses = body
    |> Floki.find("table#dataList > tr")
    |> List.flatten
    |> List.delete_at(0)
    |> Enum.map(fn {"tr", [], details} = _item ->
      extract_course_item(details)
    end)
    personal_info = body
    |> Floki.find("div#Top1_divLoginName")
    |> Floki.text
    %{
      :personal_info => personal_info,
      :courses => courses
    }
  end

  def extract_course_item([{"td", [{"colspan", "11"}], ["未查询到数据"]}] = _course_list) do
  end

  def extract_course_item([
      {"td", [], [index]},
      {"td", [], [date]},
      {"td", [{"align", "left"}], [course_id]},
      {"td", [{"align", "left"}], [course_name]},
      {"td", [], [course_level]},
      {"td", [], [course_credit]},
      {"td", [], [course_times]},
      {"td", [], [course_method]},
      {"td", [], [course_property]},
      {"td", [], [course_nature]},
      {"td", [], [course_tag]}
    ] = _course_list) do
      %{
        index: index,
        course_date: date,
        course_id: course_id,
        course_name: course_name,
        course_season_id: "unknow",
        course_detail: "0",
        course_level: course_level |> extract_course_level,
        course_credit: course_credit,
        course_period: course_times,
        course_method: course_method,
        course_property: course_property,
        course_nature: course_nature,
        course_tag: course_tag,
        is_available: false
      }
  end

  def extract_course_item([
    {"td", [], [index]},
    {"td", [], [date]},
    {"td", [{"align", "left"}], [course_id]},
    {"td", [{"align", "left"}], [course_name]},
    {"td", [], [course_level]},
    {"td", [], [course_credit]},
    {"td", [], [course_times]},
    {"td", [], [course_method]},
    {"td", [], [course_property]},
    {"td", [], [course_nature]},
    {"td", [], []}
  ] = _course_list) do
    %{
      index: index,
      course_date: date,
      course_id: course_id,
      course_name: course_name,
      course_season_id: "unknow",
      course_detail: "0",
      course_level: course_level |> extract_course_level,
      course_credit: course_credit,
      course_period: course_times,
      course_method: course_method,
      course_property: course_property,
      course_nature: course_nature,
      course_tag: "",
      is_available: false
    }
end
  def extract_course_item([
      {"td", [], [index]},
      {"td", [], [date]},
      {"td", [{"align", "left"}], [course_id]},
      {"td", [{"align", "left"}], [course_name]},
      {"td", [], [course_level]},
      {"td", [], [course_credit]},
      {"td", [], [course_times]},
      {"td", [], []},
      {"td", [], [course_property]},
      {"td", [], [course_nature]},
      {"td", [], []}
    ] = _course_list) do
      %{
        index: index,
        course_date: date,
        course_id: course_id,
        course_name: course_name,
        course_season_id: "unknow",
        course_detail: "0",
        course_level: course_level |> extract_course_level,
        course_credit: course_credit,
        course_period: course_times,
        course_method: "",
        course_property: course_property,
        course_nature: course_nature,
        course_tag: "",
        is_available: false
      }
  end

  def extract_course_item([
    {"td", [], [index]},
    {"td", [], [date]},
    {"td", [{"align", "left"}], [course_id]},
    {"td", [{"align", "left"}], [course_name]},
    {"td", [{"style", " "}],
     [
       {"a",
        [
          {"href",
          course_detail}
        ], [course_level]}
     ]},
    {"td", [], [course_credit]},
    {"td", [], [course_times]},
    {"td", [], [course_method]},
    {"td", [], [course_property]},
    {"td", [], [course_nature]},
    {"td", [], []}
  ] = _course_list) do
    %{
      index: index,
      course_date: date,
      course_id: course_id,
      course_name: course_name,
      course_season_id: course_detail |> extract_course_season,
      course_detail: course_detail |> extract_course_detail,
      course_level: course_level |> extract_course_level,
      course_credit: course_credit,
      course_period: course_times,
      course_method: course_method,
      course_property: course_property,
      course_nature: course_nature,
      course_tag: "",
      is_available: false
    }
  end

  def extract_course_item([
    {"td", [], [index]},
    {"td", [], [date]},
    {"td", [{"align", "left"}], [course_id]},
    {"td", [{"align", "left"}], [course_name]},
    {"td", [{"style", " "}],
     [
       {"a",
        [
          {"href",
          course_detail}
        ], [course_level]}
     ]},
    {"td", [], [course_credit]},
    {"td", [], [course_times]},
    {"td", [], [course_method]},
    {"td", [], [course_property]},
    {"td", [], [course_nature]},
    {"td", [], [course_tag]}
  ] = _course_list) do
    %{
      index: index,
      course_date: date,
      course_id: course_id,
      course_name: course_name,
      course_season_id: course_detail |> extract_course_season, # 课程唯一 id 标示
      course_detail: course_detail |> extract_course_detail,
      course_level: course_level |> extract_course_level,
      course_credit: course_credit,
      course_period: course_times,
      course_method: course_method,
      course_property: course_property,
      course_nature: course_nature,
      course_tag: course_tag,
      is_available: false
    }
  end

  # [{"td", [], ["41"]},
  #   {"td", [], ["2017-2018-1"]},
  #   {"td", [{"align", "left"}], ["BIO206-15"]},
  #   {"td", [{"align", "left"}], ["细胞生物学"]},
  #   {"td", [{"style", " "}],
  #    [{"a", [{"href", "javascript:JsMod('/jsxsd/kscj/pscj_list.do?xs0101id=11510055&jx0404id=201720181001090&zcj=84',700,500)"}], ["\r\n\t\t\tB\r\n\t\t\t"]}]},
  #   {"td", [], ["4"]},
  #   {"td", [], ["64"]},
  #   {"td", [], []},
  #   {"td", [], ["必修"]},
  #   {"td", [], ["专业核心课"]},
  #   {"td", [], []}]

  def extract_course_item([
    {"td", [], [index]},
    {"td", [], [date]},
    {"td", [{"align", "left"}], [course_id]},
    {"td", [{"align", "left"}], [course_name]},
    {"td", [{"style", " "}],
     [
       {"a",
        [
          {"href",
          course_detail}
        ], [course_level]}
     ]},
    {"td", [], [course_credit]},
    {"td", [], [course_times]},
    {"td", [], []},
    {"td", [], [course_property]},
    {"td", [], [course_nature]},
    {"td", [], []}
  ] = _course_list) do
    %{
      index: index,
      course_date: date,
      course_id: course_id,
      course_name: course_name,
      course_season_id: course_detail |> extract_course_season, # 课程唯一 id 标示
      course_detail: course_detail |> extract_course_detail,
      course_level: course_level |> extract_course_level,
      course_credit: course_credit,
      course_period: course_times,
      course_method: "",
      course_property: course_property,
      course_nature: course_nature,
      course_tag: "",
      is_available: false
    }
  end


  defp extract_course_season(href) do
    {season_id, _} = href
                      |> String.split(["jx0404id=", "&zcj="])
                      |> List.pop_at(1)
    season_id
  end

  defp extract_course_detail(href) do
    {score, _} = href
                  |> String.split(["zcj=", "'"])
                  |> List.pop_at(2)
    score
  end

  defp extract_course_level(course_level) do
    course_level
    |> String.replace("\r", "")
    |> String.replace("\t", "")
    |> String.replace("\n", "")
  end
end

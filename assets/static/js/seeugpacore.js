function loadData() {
    var name = getCookie("username");
    var pass = getCookie("password");
    $.ajax({
        url: '/api/gpa', // 跳转到 action
        data: {
            username: name,
            password: pass
        },
        type: 'get',
        dataType: 'json',
        success: function (data) {
            initPersonalInfo(data.info); // special exec
            // initialPageData(data);
            ready4data(data.data);
            flushUI();
        },
        error: function () {
            alert("请确认帐号密码再重新尝试");
        }
    });
}

function setCookie(c_name, value, expiredays) {
    var exdate = new Date();
    exdate.setDate(exdate.getDate() + expiredays);
    document.cookie = c_name + "=" + escape(value) +
        ((expiredays == null) ? "" : ";expires=" + exdate.toGMTString());
}

function getCookie(c_name) {
    if (document.cookie.length > 0) {
        var c_start = document.cookie.indexOf(c_name + "=");
        if (c_start != -1) {
            c_start = c_start + c_name.length + 1;
            var c_end = document.cookie.indexOf(";", c_start);
            if (c_end == -1) c_end = document.cookie.length;
            return unescape(document.cookie.substring(c_start, c_end));
        }
    }
    return "";
}

//////////////////////////////////////////////////////
var state = {
    data: [],
    banner: {
        total_gpa: 0,
        calculated_credit: 0,
        total_credit: 0
    }
}

/**
 * 
 * @param {*} data []
 */
function ready4data(data) {
    console.log("Ready for Data...")
    // main panel
    list = []
    for(var i = 0; i < data.length; i += 1){
        list.push(ready4item(data[i]))
    }
    state.data = list; // set it

    // footer panel
    state.banner = calTotalGPA(data);
}

// private
function ready4item(item) {
    var date = item.date;
    var list = item.list; // []
    var gpa = calTermGPA(list);
    return {
        date: date,
        list: list,
        gpa: gpa
    };
}

function calTermGPA(list) {
    var total_credit = 0;
    var total_gpa = 0;
    for(var i = 0; i < list.length; i += 1) {
        var course = list[i];
        // 是否需要计算
        if(!course.is_available){
            continue;
        }
        if(course.course_selected == true){
            continue;
        }
        var gpa = calGPAPoint(course.course_detail);
        var credit = parseFloat(course.course_credit);
        total_gpa += gpa * credit; // weight
        total_credit += credit;
    }
    var final_avg_gpa = (total_gpa / total_credit).toFixed(2);
    return final_avg_gpa;
}

function calTotalGPA(lists) {
    var total_credit = 0;
    var total_gpa = 0; // 加了权重的
    var total_credit_pure = 0; // 加入计算的总学分
    var total_credit_all = 0; // 所有修读了的学分
    for(var i = 0; i < lists.length; i += 1){
        var list = lists[i].list;
        for(var j = 0; j < list.length; j += 1) {
            var course = list[j];
            var credit = parseFloat(course.course_credit);
            total_credit_all += credit; // 所有修读了的学分
            // 是否需要计算
            if(!course.is_available){
                continue;
            }
            if(course.course_selected == true){
                continue;
            }
            total_credit_pure += credit; // 加入计算的总学分
            var gpa = calGPAPoint(course.course_detail);
            total_gpa += gpa * credit; // weight
            total_credit += credit;
        }
    }
    var final_avg_gpa = (total_gpa / total_credit).toFixed(2);
    // console.log(final_avg_gpa, total_credit_all, total_credit_pure)
    return {
        total_gpa: final_avg_gpa,
        calculated_credit: total_credit_pure.toFixed(2),
        total_credit: total_credit_all.toFixed(2)
    };
}


/** flush data like setState */
function flushUI() {
    console.log("Flush UI...")
    ready4data(state.data)
    var yixiudu = formTermYiXiuDu(state.data);
    $("#course__container").html(yixiudu || '');
    // and gpa banner
    // state.banner
    // $("#dadada").html("dadada");
    var banner = state.banner;
    // console.log(banner)
    document.getElementById("xff_total_static").innerHTML = banner.total_credit;
    document.getElementById("xff_total").innerHTML = banner.calculated_credit;
    document.getElementById("gpa_total").innerHTML = banner.total_gpa;
}

/**
 * 个人信息
 */
function initPersonalInfo(info) {
    if (info === undefined) {
        var sid = getCookie('username');
        info = {
            name: sid,
            sid: sid,
        };
    }
    document.getElementById("nickname").innerHTML = info || '';
    document.getElementById("sid").innerHTML = info.sid || '';
}

/**
 * 已修读的成绩
 */
function formTermYiXiuDu(ed) {
    if (ed === undefined) {
        return;
    }
    var content = "";
    for (var i = 0; i < ed.length; i++) {
        var term = formTerm(ed[i], i);
        content += term;
    }
    return content;
}

/*
 * 创建每学期所有的记录
 */
function formTerm(edi, index) {
    var term = edi.date;
    var data = edi.list;
    var text = "<div class=\"row\"><div class=\"list-group list-group--block tasks-lists\">" +
        "<div class=\"list-group__header text-left\">" +
        term +
        "</div>";
    text += "<input id='term_" + index + "' type='hidden' value='" + data.length + "'></input>";
    for (var i = 0; i < data.length; i++) {
        var item = formListItem(term, data[i]);
        text += item;
    }
    text += "<div class=\"list-group__header text-right\" style=\"border-bottom:none;float: right;\">" +
        "GPA:&nbsp;<seeuvalue id=\"gpa_" + index + "\" style=\"color:#e0a333\" >" +
        edi.gpa +
        "</seeuvalue>";
    text += "</div></div></div>";
    return text;
}

/**
 * 创建每学期里每一条成绩记录
 * @param {Object} data
 */
function formListItem(term, data) {
    var id = term + "_" + data.index;
    var varchar = data.course_id.toString().charAt(0);
    var color = getColor(varchar);
    var checked = data.course_selected == true ? "checked" : "" // checked means unchoose
    var item = "<div class=\"list-group-item\"><div class=\"checkbox checkbox--char\">"+
        "<label onclick=\"clickBox('" + term + "'," + data.index + ");\">"+
        "<input id=\"checkbox_" + id + "\" type=\"checkbox\" "+ 
        checked + ">"+
        "<span class=\"checkbox__helper\">" +
        "<i class=\"" + color + "\">" + varchar + "</i></span><span class=\"tasks-list__info\">" +
        data.course_id + "  " + data.course_name +
        " <small class=\"text-muted\"><div class=\"listdetail\">" +
        "<item style=\"min-width:70px;\"><l>学分</l><xff id=\"xff_" + id + "\">" + data.course_credit + "</xff></item>" +
        "<item style=\"min-width:70px;\"><l>学时</l>" + data.course_period + "</item>" +
        "<item style=\"min-width:150px;\"><l>课程性质</l>" + data.course_nature + "</item>" +
        "<item style=\"min-width:80px;\"><l>课程属性</l>" + data.course_property + "</item>" +
        "<item style=\"min-width:80px;\"><l>考核方式</l>" + data.course_method + "</item>" +
        "<item style=\"min-width:80px;\"><l>分数</l><cjj id=\"cjj_" + id + "\">" + data.course_detail + "</cjj></item>" +
        "<item><l>评价</l>" + data.course_tag + "</item>" +
        "</div></small></span></label></div></div>";
    // document.write(item);
    return item;
}

// private
function getColor(varchar) {
    switch (varchar) {
        case "C":
            return "mdc-bg-blue-300";
        case "G":
            return "mdc-bg-amber-300";
        case "H":
            return "mdc-bg-purple-300";
        case "B":
            return "mdc-bg-green-300";
        case "F":
            return "mdc-bg-blue-grey-300";
        case "M":
            return "mdc-bg-pink-300";
        case "E":
            return "mdc-bg-teal-300";
        case "S":
            return "mdc-bg-cyan-300";
        case "X":
            return "mdc-bg-orange-300";
        case "P":
            return "mdc-bg-indigo-300";
        case "I":
            return "mdc-bg-yellow-300";
        default:
            return "mdc-bg-red-300";
    }
}

function clickBox(term, index) {
    // calTotalScore(totaltermLength);
    // calItemScore(which);
    console.log({term, index})
    // change state data
    var data = state.data;
    for(var i = 0; i < data.length; i += 1){
        var item = data[i];
        if(item.date == term) {
            console.log("selected term: " + term)
            for(var j = 0; j < item.list.length; j += 1){
                var course = item.list[j];
                if(course.index == index){
                    console.log("selected index: " + term)
                    // change state
                    var selected = data[i].list[j].course_selected || false;
                    data[i].list[j].course_selected = !selected;
                    break;
                }
            }
        }
    }
    state.data = data;
    flushUI()
}
/**
 * 计算总共修读的学分
 * @param {Object} totaltermLength
 */
function calInitialXffStatic(totaltermLength) {
    var sumxf_all = 0;
    var sumxf = 0;
    for (var index = 0; index < totaltermLength; index++) {
        var itemdex = document.getElementById("term_" + index);
        // var itemNum = $("#term_" + index).val();
        var itemNum = itemdex.value;
        // 进入某一个学期：
        for (var i = 1; i <= itemNum; i++) {
            var xff = document.getElementById("xff_" + index + "_" + i);
            var cjj = document.getElementById("cjj_" + index + "_" + i);

            if (isNum(cjj.innerHTML)) {
                var cj = parseFloat(cjj.innerHTML);
                if (cj < 60) {
                    // 不计入总学分（属于挂科）
                    var xf = parseFloat(xff.innerHTML);
                    sumxf_all += xf;
                    continue;
                }
            } else if (cjj.innerHTML.toString() != "通过") {
                // 不计入总学分（属于未通过）
                var xf = parseFloat(xff.innerHTML);
                sumxf_all += xf;
                continue;
            }
            var xf = parseFloat(xff.innerHTML);
            sumxf += xf;
            sumxf_all += xf;
        }
    }
    if (sumxf != 0) {
        document.getElementById("xff_total_static").innerHTML = sumxf.toFixed(2)+" / "+sumxf_all;
    }
}
/**
 * 计算被勾选的总 GPA
 * @param {Object} totaltermLength
 */
function calTotalScore(totaltermLength) {
    var sumxf = 0;
    var sumscore = 0;
    var sumgpa = 0;
    for (var index = 0; index < totaltermLength; index++) {
        var itemdex = document.getElementById("term_" + index);
        var itemNum = itemdex.value;
        // 进入某一个学期：
        for (var i = 1; i <= itemNum; i++) {
            // 判断是否选中
            if ($("#checkbox_" + index + "_" + i).prop("checked") == false) {
                var xff = document.getElementById("xff_" + index + "_" + i);
                var cjj = document.getElementById("cjj_" + index + "_" + i);
                if (isNum(cjj.innerHTML)) {
                    var xf = parseFloat(xff.innerHTML);
                    var cj = parseFloat(cjj.innerHTML);
                    // alert(typeof cj);
                    var gpa = calGPAPoint(cj);
                    sumxf += xf;
                    sumscore += xf * cj;
                    sumgpa += xf * gpa;
                }
            }
        }
    }
    // if (sumxf != 0) {
        // var finalscore = parseFloat(sumscore) / parseFloat(sumxf); // 期望分数（直接算平均分）
        var wujigpa = parseFloat(sumgpa) / parseFloat(sumxf); // 期望绩点（先算GPA再平均）（15级）
        if( isNaN(wujigpa) ){
            wujigpa = 0;
        }
        // var baifengpa = parseFloat(sumgpa2) / parseFloat(sumxf); // 期望绩点（先算GPA再平均）（14级）
        document.getElementById("xff_total").innerHTML = sumxf.toFixed(2);
        document.getElementById("gpa_total").innerHTML = wujigpa.toFixed(2);
        // document.getElementById("baifen_gpa_total").innerHTML = baifengpa.toFixed(2);
    // }
}
/**
 * 计算每学期被勾选的 GPA
 * @param {Object} index:第几个学期
 */
function calItemScore(index) {
    var sumxf = 0;
    var sumscore = 0;
    var sumgpa = 0;
    var itemdex = document.getElementById("term_" + index);
    var itemNum = itemdex.value;
    for (var i = 0; i <= itemNum; i++) {
        // 判断是否选中
        if ($("#checkbox_" + index + "_" + i).prop("checked") == false) {
            var xff = document.getElementById("xff_" + index + "_" + i);
            var cjj = document.getElementById("cjj_" + index + "_" + i);
            if (isNum(cjj.innerHTML)) {
                var xf = parseFloat(xff.innerHTML);
                var cj = parseFloat(cjj.innerHTML);
                // alert(typeof cj);
                var gpa = calGPAPoint(cj);
                sumxf += xf;
                sumscore += xf * cj;
                sumgpa += xf * gpa;
            }
        }

    }
    if (sumxf != 0) {
        // var finalscore = parseFloat(sumscore) / parseFloat(sumxf); // 期望分数（直接算平均分）
        var wujigpa = parseFloat(sumgpa) / parseFloat(sumxf); // 期望绩点（先算GPA再平均）（15级）
        // var baifengpa = parseFloat(sumgpa2) / parseFloat(sumxf); // 期望绩点（先算GPA再平均）（14级）
        document.getElementById("gpa_" + index).innerHTML = wujigpa.toFixed(2);
        // document.getElementById("baifen_gpa" + index).innerHTML = baifengpa.toFixed(2);

    }

}

function isNum(str) {
    if (parseFloat(str) == "" + str) {
        return true;
    } else return false;
}

// 五级制计分（绩点 by score）2015级
function calGPAPoint(score) {
    score = parseFloat(score);
    if (score >= 97) return 4.00;
    if (score >= 93) return 3.94;
    if (score >= 90) return 3.85;
    if (score >= 87) return 3.73;
    if (score >= 83) return 3.55;
    if (score >= 80) return 3.32;
    if (score >= 77) return 3.09;
    if (score >= 73) return 2.78;
    if (score >= 70) return 2.42;
    if (score >= 67) return 2.08;
    if (score >= 63) return 1.63;
    if (score >= 60) return 1.15;
    if (score >= 0) return 0;
    else return 0;
}
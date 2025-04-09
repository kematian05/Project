<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.Date" %>
<%@ page import="java.text.SimpleDateFormat" %>
<%@ page import="java.util.Calendar" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="../css/animations.css">
    <link rel="stylesheet" href="../css/main.css">
    <link rel="stylesheet" href="../css/admin.css">

    <title>Psychology Admin Dashboard</title>
    <style>
        .dashbord-tables {
            animation: transitionIn-Y-over 0.5s;
        }

        .filter-container {
            animation: transitionIn-Y-bottom 0.5s;
        }

        .sub-table {
            animation: transitionIn-Y-bottom 0.5s;
        }
    </style>
</head>
<body>
<%
    String user = (String) session.getAttribute("user");
    String usertype = (String) session.getAttribute("usertype");
    if (user == null || !usertype.equals("a")) {
        response.sendRedirect("../login.jsp");
        return;
    }
    String url = System.getenv("DB_URL");
    String dbUser = System.getenv("DB_USER");
    String dbPassword = System.getenv("DB_PASSWORD");

    Connection connection = null;
    Statement statement = null;
    ResultSet resultSet = null;
    int clientCount = 0;
    int therapistCount = 0;
    int appointmentCount = 0;
    int scheduleCount = 0;

    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        connection = DriverManager.getConnection(url, dbUser, dbPassword);
        statement = connection.createStatement();

        SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd");
        Date currentDate = new Date();
        String today = dateFormat.format(currentDate);

        Calendar calendar = Calendar.getInstance();
        calendar.add(Calendar.DAY_OF_WEEK, 7);
        Date nextWeekDate = calendar.getTime();
        String nextWeek = dateFormat.format(nextWeekDate);

        resultSet = statement.executeQuery("SELECT COUNT(*) FROM patient");
        if (resultSet.next()) {
            clientCount = resultSet.getInt(1);
        }

        resultSet = statement.executeQuery("SELECT COUNT(*) FROM doctor");
        if (resultSet.next()) {
            therapistCount = resultSet.getInt(1);
        }

        resultSet = statement.executeQuery("SELECT COUNT(*) FROM appointment WHERE appodate >= '" + today + "'");
        if (resultSet.next()) {
            appointmentCount = resultSet.getInt(1);
        }

        resultSet = statement.executeQuery("SELECT COUNT(*) FROM schedule WHERE scheduledate = '" + today + "'");
        if (resultSet.next()) {
            scheduleCount = resultSet.getInt(1);
        }

%>
<div class="container">
    <div class="menu">
        <table class="menu-container" border="0">
            <tr>
                <td style="padding:10px" colspan="2">
                    <table border="0" class="profile-container">
                        <tr>
                            <td width="30%" style="padding-left:20px">
                                <img src="../img/user.png" alt="" width="100%" style="border-radius:50%">
                            </td>
                            <td style="padding:0px;margin:0px;">
                                <p class="profile-title">Administrator</p>
                                <p class="profile-subtitle"><%= user %>
                                </p>
                            </td>
                        </tr>
                        <tr>
                            <td colspan="2">
                                <a href="../logout.jsp"><input type="button" value="Log out"
                                                               class="logout-btn btn-primary-soft btn"></a>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-dashbord menu-active menu-icon-dashbord-active">
                    <a href="index.jsp" class="non-style-link-menu non-style-link-menu-active">
                        <div>
                            <p class="menu-text">Dashboard</p>
                        </div>
                    </a>
                </td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-doctor "><a href="therapists.jsp" class="non-style-link-menu ">
                    <div>
                        <p class="menu-text">Therapists</p>
                    </div>
                </a>
                </td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-schedule">
                    <a href="schedule.jsp" class="non-style-link-menu">
                        <div>
                            <p class="menu-text">Schedules</p>
                        </div>
                    </a>
                </td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-appoinment">
                    <a href="appointment.jsp" class="non-style-link-menu">
                        <div>
                            <p class="menu-text">Appointments</p>
                        </div>
                    </a>
                </td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-patient"><a href="clients.jsp" class="non-style-link-menu">
                    <div>
                        <p class="menu-text">Clients</p>
                    </div>
                </a>
                </td>
            </tr>
        </table>
    </div>
    <div class="dash-body" style="margin-top: 15px">
        <table border="0" width="100%" style=" border-spacing: 0;margin:0;padding:0;">
            <tr>
                <td colspan="2" class="nav-bar">
                    <form action="therapists.jsp" method="post" class="header-search">
                        <input type="search" name="search" class="input-text header-searchbar"
                               placeholder="Search Therapist name or Email" list="therapists">&nbsp;&nbsp;
                        <datalist id="therapists">
                            <%
                                resultSet = statement.executeQuery("SELECT docname, docemail FROM doctor");
                                while (resultSet.next()) {
                                    String therapistName = resultSet.getString("docname");
                                    String therapistEmail = resultSet.getString("docemail");
                            %>
                            <option value="<%= therapistName %>"><br/>
                            <option value="<%= therapistEmail %>"><br/>
                                    <%
                                }
                            %>
                        </datalist>
                        <input type="Submit" value="Search" class="login-btn btn-primary-soft btn"
                               style="padding-left: 25px;padding-right: 25px;padding-top: 10px;padding-bottom: 10px;">
                    </form>
                </td>
                <td width="15%">
                    <p style="font-size: 14px;color: rgb(119, 119, 119);padding: 0;margin: 0;text-align: right;">
                        Today's Date
                    </p>
                    <p class="heading-sub12" style="padding: 0;margin: 0;">
                        <%= today %>
                    </p>
                </td>
                <td width="10%">
                    <button class="btn-label" style="display: flex;justify-content: center;align-items: center;">
                        <img src="../img/calendar.svg" width="100%">
                    </button>
                </td>
            </tr>
            <tr>
                <td colspan="4">
                    <center>
                        <table class="filter-container" style="border: none;" border="0">
                            <tr>
                                <td colspan="4">
                                    <p style="font-size: 20px;font-weight:600;padding-left: 12px;">Status Overview</p>
                                </td>
                            </tr>
                            <tr>
                                <td style="width: 25%;">
                                    <div class="dashboard-items"
                                         style="padding:20px;margin:auto;width:95%;display: flex">
                                        <div>
                                            <div class="h1-dashboard">
                                                <%= therapistCount %>
                                            </div>
                                            <br>
                                            <div class="h3-dashboard">
                                                Therapists &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
                                            </div>
                                        </div>
                                        <div class="btn-icon-back dashboard-icons"
                                             style="background-image: url('../img/icons/doctors-hover.svg');"></div>
                                    </div>
                                </td>
                                <td style="width: 25%;">
                                    <div class="dashboard-items"
                                         style="padding:20px;margin:auto;width:95%;display: flex;">
                                        <div>
                                            <div class="h1-dashboard">
                                                <%= clientCount %>
                                            </div>
                                            <br>
                                            <div class="h3-dashboard">
                                                Clients &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
                                            </div>
                                        </div>
                                        <div class="btn-icon-back dashboard-icons"
                                             style="background-image: url('../img/icons/patients-hover.svg');"></div>
                                    </div>
                                </td>
                                <td style="width: 25%;">
                                    <div class="dashboard-items"
                                         style="padding:20px;margin:auto;width:95%;display: flex; ">
                                        <div>
                                            <div class="h1-dashboard">
                                                <%= appointmentCount %>
                                            </div>
                                            <br>
                                            <div class="h3-dashboard">
                                                Upcoming Appts &nbsp;&nbsp;
                                            </div>
                                        </div>
                                        <div class="btn-icon-back dashboard-icons"
                                             style="margin-left: 0px;background-image: url('../img/icons/book-hover.svg');"></div>
                                    </div>
                                </td>
                                <td style="width: 25%;">
                                    <div class="dashboard-items"
                                         style="padding:20px;margin:auto;width:95%;display: flex;padding-top:22px;padding-bottom:22px;">
                                        <div>
                                            <div class="h1-dashboard">
                                                <%= scheduleCount %>
                                            </div>
                                            <br>
                                            <div class="h3-dashboard" style="font-size: 15px">
                                                Today's Scheduled Slots
                                            </div>
                                        </div>
                                        <div class="btn-icon-back dashboard-icons"
                                             style="background-image: url('../img/icons/session-iceblue.svg');"></div>
                                    </div>
                                </td>
                            </tr>
                        </table>
                    </center>
                </td>
            </tr>
            <tr>
                <td colspan="4">
                    <table width="100%" border="0" class="dashbord-tables">
                        <tr>
                            <td>
                                <p style="padding:10px;padding-left:48px;padding-bottom:0;font-size:23px;font-weight:700;color:var(--primarycolor);">
                                    Upcoming Appointments until
                                    Next <%= new SimpleDateFormat("EEEE").format(nextWeekDate) %>
                                </p>
                                <p style="padding-bottom:19px;padding-left:50px;font-size:15px;font-weight:500;color:#212529e3;line-height: 20px;">
                                    Quick view of booked client appointments for the next 7 days.<br>
                                    Full details available in the @Appointments section.
                                </p>
                            </td>
                            <td>
                                <p style="text-align:right;padding:10px;padding-right:48px;padding-bottom:0;font-size:23px;font-weight:700;color:var(--primarycolor);">
                                    Upcoming Therapist Schedules until
                                    Next <%= new SimpleDateFormat("EEEE").format(nextWeekDate) %>
                                </p>
                                <p style="padding-bottom:19px;text-align:right;padding-right:50px;font-size:15px;font-weight:500;color:#212529e3;line-height: 20px;">
                                    Quick view of therapist availability schedules for the next 7 days.<br>
                                    Manage schedules in the @Therapist Schedules section.
                                </p>
                            </td>
                        </tr>
                        <tr>
                            <td width="50%">
                                <center>
                                    <div class="abc scroll" style="height: 200px;">
                                        <table width="85%" class="sub-table scrolldown" border="0">
                                            <thead>
                                            <tr>
                                                <th class="table-headin" style="font-size: 12px;">
                                                    Appt. Number
                                                </th>
                                                <th class="table-headin">
                                                    Client Name
                                                </th>
                                                <th class="table-headin">
                                                    Therapist
                                                </th>
                                                <th class="table-headin">
                                                    Session Title
                                                </th>
                                            </tr>
                                            </thead>
                                            <tbody>
                                            <%
                                                String sqlAppointments = "SELECT appointment.appoid, schedule.scheduleid, schedule.title, doctor.docname, patient.pname, schedule.scheduledate, schedule.scheduletime, appointment.apponum, appointment.appodate FROM schedule INNER JOIN appointment ON schedule.scheduleid = appointment.scheduleid INNER JOIN patient ON patient.pid = appointment.pid INNER JOIN doctor ON schedule.docid = doctor.docid WHERE schedule.scheduledate >= '" + today + "' AND schedule.scheduledate <= '" + nextWeek + "' ORDER BY schedule.scheduledate DESC, schedule.scheduletime ASC";
                                                ResultSet rsAppointments = statement.executeQuery(sqlAppointments);
                                                if (!rsAppointments.isBeforeFirst()) {
                                            %>
                                            <tr>
                                                <td colspan='4'><br><br><br><br>
                                                    <center><img src='../img/notfound.svg' width='25%'><br>
                                                        <p class='heading-main12'
                                                           style='margin-left: 45px;font-size:20px;color:rgb(49, 49, 49)'>
                                                            No upcoming appointments found for the next 7 days.</p><a
                                                                class='non-style-link' href='appointment.jsp'>
                                                            <button class='login-btn btn-primary-soft btn'
                                                                    style='display: flex;justify-content: center;align-items: center;margin-left:20px;'>
                                                                &nbsp; Show all Appointments &nbsp;
                                                            </button>
                                                        </a></center>
                                                    <br><br><br><br></td>
                                            </tr>
                                            <%
                                            } else {
                                                while (rsAppointments.next()) {
                                                    String appoid = rsAppointments.getString("appoid");
                                                    String title = rsAppointments.getString("title");
                                                    String therapistName = rsAppointments.getString("docname");
                                                    String clientName = rsAppointments.getString("pname");
                                                    String apponum = rsAppointments.getString("apponum");
                                                    String scheduleDate = rsAppointments.getString("scheduledate");
                                                    String scheduleTime = rsAppointments.getString("scheduletime");
                                            %>
                                            <tr>
                                                <td style='text-align:center;font-size:23px;font-weight:500; color: var(--btnnicetext);padding:20px;'><%= apponum %>
                                                </td>
                                                <td style='font-weight:600;'>
                                                    &nbsp;<%= clientName.substring(0, Math.min(clientName.length(), 25)) %>
                                                </td>
                                                <td style='font-weight:600;'>
                                                    &nbsp;<%= therapistName.substring(0, Math.min(therapistName.length(), 25)) %>
                                                </td>
                                                <td><%= title.substring(0, Math.min(title.length(), 15)) %>
                                                </td>
                                            </tr>
                                            <%
                                                    }
                                                }
                                                if (rsAppointments != null) rsAppointments.close();
                                            %>
                                            </tbody>
                                        </table>
                                    </div>
                                </center>
                            </td>
                            <td width="50%" style="padding: 0;">
                                <center>
                                    <div class="abc scroll" style="height: 200px;padding: 0;margin: 0;">
                                        <table width="85%" class="sub-table scrolldown" border="0">
                                            <thead>
                                            <tr>
                                                <th class="table-headin">
                                                    Session Slot Title
                                                </th>
                                                <th class="table-headin">
                                                    Therapist
                                                </th>
                                                <th class="table-headin">
                                                    Scheduled Date & Time
                                                </th>
                                            </tr>
                                            </thead>
                                            <tbody>
                                            <%
                                                String sqlSchedules = "SELECT schedule.scheduleid, schedule.title, doctor.docname, schedule.scheduledate, schedule.scheduletime, schedule.nop FROM schedule INNER JOIN doctor ON schedule.docid = doctor.docid WHERE schedule.scheduledate >= '" + today + "' AND schedule.scheduledate <= '" + nextWeek + "' ORDER BY schedule.scheduledate DESC, schedule.scheduletime ASC";
                                                ResultSet rsSchedules = statement.executeQuery(sqlSchedules);
                                                if (!rsSchedules.isBeforeFirst()) {
                                            %>
                                            <tr>
                                                <td colspan='3'><br><br><br><br>
                                                    <center><img src='../img/notfound.svg' width='25%'><br>
                                                        <p class='heading-main12'
                                                           style='margin-left: 45px;font-size:20px;color:rgb(49, 49, 49)'>
                                                            No upcoming therapist schedules found for the next 7
                                                            days.</p><a class='non-style-link' href='schedule.jsp'>
                                                            <button class='login-btn btn-primary-soft btn'
                                                                    style='display: flex;justify-content: center;align-items: center;margin-left:20px;'>
                                                                &nbsp; Show all Schedules &nbsp;
                                                            </button>
                                                        </a></center>
                                                    <br><br><br><br></td>
                                            </tr>
                                            <%
                                            } else {
                                                while (rsSchedules.next()) {
                                                    String title = rsSchedules.getString("title");
                                                    String therapistName = rsSchedules.getString("docname");
                                                    String scheduledate = rsSchedules.getString("scheduledate");
                                                    String scheduletime = rsSchedules.getString("scheduletime");
                                            %>
                                            <tr>
                                                <td style='padding:20px;'>
                                                    &nbsp;<%= title.substring(0, Math.min(title.length(), 30)) %>
                                                </td>
                                                <td><%= therapistName.substring(0, Math.min(therapistName.length(), 20)) %>
                                                </td>
                                                <td style='text-align:center;'><%= scheduledate %> <%= scheduletime.substring(0, 5) %>
                                                </td>
                                            </tr>
                                            <%
                                                    }
                                                }
                                                if (rsSchedules != null) rsSchedules.close();
                                            %>
                                            </tbody>
                                        </table>
                                    </div>
                                </center>
                            </td>
                        </tr>
                        <tr>
                            <td>
                                <center>
                                    <a href="appointment.jsp" class="non-style-link">
                                        <button class="btn-primary btn"
                                                style="width:85%">Show all Appointments
                                        </button>
                                    </a>
                                </center>
                            </td>
                            <td>
                                <center>
                                    <a href="schedule.jsp" class="non-style-link">
                                        <button class="btn-primary btn"
                                                style="width:85%">Show all Schedules
                                        </button>
                                    </a>
                                </center>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>
        </table>
    </div>
</div>
<%
    } catch (Exception e) {
        e.printStackTrace();
        System.out.println("<p style='color:red;'>An error occurred: " + e.getMessage() + "</p>");
    } finally {
        try {
            if (resultSet != null && !resultSet.isClosed()) resultSet.close();
            if (statement != null) statement.close();
            if (connection != null) connection.close();
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }
%>
</body>
</html>
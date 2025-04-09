<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*, java.util.*, java.text.*, java.time.LocalDate, java.time.format.DateTimeFormatter" %>
<%@ page import="org.apache.commons.text.StringEscapeUtils" %>
<%!
    private void closeQuietly(AutoCloseable resource) {
        if (resource != null) {
            try {
                resource.close();
            } catch (Exception e) { /* ignore */ }
        }
    }

    private boolean isNullOrEmpty(String str) {
        return str == null || str.trim().isEmpty();
    }

    private String safeSubstring(String str, int start, int end) {
        if (str == null) return "";
        int actualEnd = Math.min(end, str.length());
        if (start >= actualEnd) return "";
        return str.substring(start, actualEnd);
    }

    private int getCount(Connection conn, String sql, Object... params) throws SQLException {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            ps = conn.prepareStatement(sql);
            for (int i = 0; i < params.length; i++) {
                ps.setObject(i + 1, params[i]);
            }
            rs = ps.executeQuery();
            if (rs.next()) {
                return rs.getInt(1);
            }
            return 0;
        } finally {
            closeQuietly(rs);
            closeQuietly(ps);
        }
    }

    private String escapeHtml(String input) {
        if (input == null) return null;
        return StringEscapeUtils.escapeHtml4(input);
    }
%>
<%
    String useremail = (String) session.getAttribute("user");
    String usertype = (String) session.getAttribute("usertype");

    if (isNullOrEmpty(useremail) || !"d".equals(usertype)) {
        response.sendRedirect("../login.jsp");
        return;
    }

    String url = System.getenv("DB_URL");
    String dbUser = System.getenv("DB_USER");
    String dbPassword = System.getenv("DB_PASSWORD");

    Connection connection = null;
    PreparedStatement psUser = null;
    ResultSet rsUser = null;
    PreparedStatement psSession = null;
    ResultSet rsSession = null;

    int therapistId = 0;
    String therapistName = "";
    String errorMessage = null;

    int clientCount = 0;
    int therapistCount = 0;
    int appointmentCount = 0;
    int scheduleCount = 0;

    LocalDate todayDate = LocalDate.now();
    LocalDate nextWeekDate = todayDate.plusWeeks(1);
    DateTimeFormatter dtf = DateTimeFormatter.ofPattern("yyyy-MM-dd");
    String today = todayDate.format(dtf);
    String nextweek = nextWeekDate.format(dtf);

    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        connection = DriverManager.getConnection(url, dbUser, dbPassword);

        String sqlUser = "SELECT docid, docname FROM doctor WHERE docemail = ?";
        psUser = connection.prepareStatement(sqlUser);
        psUser.setString(1, useremail);
        rsUser = psUser.executeQuery();

        if (rsUser.next()) {
            therapistId = rsUser.getInt("docid");
            therapistName = rsUser.getString("docname");
        } else {
            session.invalidate();
            response.sendRedirect("../login.jsp?error=user_not_found");
            return;
        }
        closeQuietly(rsUser);
        closeQuietly(psUser);

        therapistCount = getCount(connection, "SELECT COUNT(*) FROM doctor");
        clientCount = getCount(connection, "SELECT COUNT(DISTINCT patient.pid) FROM patient INNER JOIN appointment ON patient.pid = appointment.pid INNER JOIN schedule ON appointment.scheduleid = schedule.scheduleid WHERE schedule.docid = ?", therapistId);
        appointmentCount = getCount(connection, "SELECT COUNT(*) FROM appointment INNER JOIN schedule ON appointment.scheduleid = schedule.scheduleid WHERE schedule.docid = ? AND appointment.appodate >= ?", therapistId, today);
        scheduleCount = getCount(connection, "SELECT COUNT(*) FROM schedule WHERE docid = ? AND scheduledate = ?", therapistId, today);

        String sqlSessions = "SELECT scheduleid, title, scheduledate, scheduletime FROM schedule WHERE docid = ? AND scheduledate >= ? AND scheduledate <= ? ORDER BY scheduledate ASC, scheduletime ASC";
        psSession = connection.prepareStatement(sqlSessions);
        psSession.setInt(1, therapistId);
        psSession.setString(2, today);
        psSession.setString(3, nextweek);
        rsSession = psSession.executeQuery();

%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="../css/animations.css">
    <link rel="stylesheet" href="../css/main.css">
    <link rel="stylesheet" href="../css/admin.css">
    <title>Therapist Dashboard</title>
    <style>
        .dashbord-tables, .doctor-header { /* Corrected typo */
            animation: transitionIn-Y-over 0.5s;
        }

        .filter-container {
            animation: transitionIn-Y-bottom 0.5s;
        }

        .sub-table, #anim {
            animation: transitionIn-Y-bottom 0.5s;
        }

        /* Removed duplicate .doctor-heade */
    </style>
</head>
<body>
<div class="container">
    <div class="menu">
        <table class="menu-container" border="0">
            <tr>
                <td style="padding:10px" colspan="2">
                    <table border="0" class="profile-container">
                        <tr>
                            <td width="30%" style="padding-left:20px"><img src="../img/user.png" alt="" width="100%"
                                                                           style="border-radius:50%"></td>
                            <td style="padding:0px;margin:0px;">
                                <p class="profile-title"><%= escapeHtml(safeSubstring(therapistName, 0, 30)) %>
                                </p>
                                <p class="profile-subtitle"><%= escapeHtml(safeSubstring(useremail, 0, 30)) %>
                                </p>
                            </td>
                        </tr>
                        <tr>
                            <td colspan="2"><a href="../logout.jsp"><input type="button" value="Log out"
                                                                           class="logout-btn btn-primary-soft btn"></a>
                            </td>
                        </tr>
                    </table>
                </td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-dashbord menu-active menu-icon-dashbord-active"><a href="index.jsp"
                                                                                                 class="non-style-link-menu non-style-link-menu-active">
                    <div><p class="menu-text">Dashboard</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-appoinment"><a href="appointment.jsp" class="non-style-link-menu">
                    <div><p class="menu-text">My Appointments</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-session"><a href="schedule.jsp" class="non-style-link-menu">
                    <div><p class="menu-text">My Sessions</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-patient"><a href="client.jsp" class="non-style-link-menu">
                    <div><p class="menu-text">My Clients</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-settings"><a href="settings.jsp" class="non-style-link-menu">
                    <div><p class="menu-text">Settings</p></div>
                </a></td>
            </tr>
        </table>
    </div>
    <div class="dash-body" style="margin-top: 15px">
        <table border="0" width="100%" style=" border-spacing: 0;margin:0;padding:0;">
            <tr>
                <td colspan="1" class="nav-bar">
                    <p style="font-size: 23px;padding-left:12px;font-weight: 600;margin-left:20px;"> Dashboard</p>
                </td>
                <td width="25%"></td>
                <td width="15%">
                    <p style="font-size: 14px;color: rgb(119, 119, 119);padding: 0;margin: 0;text-align: right;">Today's
                        Date</p>
                    <p class="heading-sub12" style="padding: 0;margin: 0;"><%= today %>
                    </p>
                </td>
                <td width="10%">
                    <button class="btn-label" style="display: flex;justify-content: center;align-items: center;"><img
                            src="../img/calendar.svg" width="100%"></button>
                </td>
            </tr>
            <tr>
                <td colspan="4">
                    <center>
                        <table class="filter-container doctor-header" style="border: none;width:95%" border="0">
                            <tr>
                                <td>
                                    <h3>Welcome!</h3>
                                    <h1><%= escapeHtml(therapistName) %>.</h1>
                                    <p>Thank you for your dedication to mental wellness. Here you can manage your
                                        schedule and client appointments efficiently.<br>
                                        Access your upcoming sessions and client information easily.<br><br>
                                    </p>
                                    <a href="appointment.jsp" class="non-style-link">
                                        <button class="btn-primary btn" style="width:30%">View My Appointments</button>
                                    </a>
                                    <br><br>
                                </td>
                            </tr>
                        </table>
                    </center>
                </td>
            </tr>
            <tr>
                <td colspan="4">
                    <table border="0" width="100%">
                        <tr>
                            <td width="50%">
                                <center>
                                    <table class="filter-container" style="border: none;" border="0">
                                        <tr>
                                            <td colspan="4"><p
                                                    style="font-size: 20px;font-weight:600;padding-left: 12px;">Status
                                                Overview</p></td>
                                        </tr>
                                        <tr>
                                            <td style="width: 25%;">
                                                <div class="dashboard-items"
                                                     style="padding:20px;margin:auto;width:95%;display: flex">
                                                    <div>
                                                        <div class="h1-dashboard"><%= therapistCount %>
                                                        </div>
                                                        <br>
                                                        <div class="h3-dashboard">All Therapists &nbsp;&nbsp;&nbsp;&nbsp;</div>
                                                    </div>
                                                    <div class="btn-icon-back dashboard-icons"
                                                         style="background-image: url('../img/icons/doctors-hover.svg');"></div>
                                                </div>
                                            </td>
                                            <td style="width: 25%;">
                                                <div class="dashboard-items"
                                                     style="padding:20px;margin:auto;width:95%;display: flex;">
                                                    <div>
                                                        <div class="h1-dashboard"><%= clientCount %>
                                                        </div>
                                                        <br>
                                                        <div class="h3-dashboard">My Clients &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</div>
                                                    </div>
                                                    <div class="btn-icon-back dashboard-icons"
                                                         style="background-image: url('../img/icons/patients-hover.svg');"></div>
                                                </div>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td style="width: 25%;">
                                                <div class="dashboard-items"
                                                     style="padding:20px;margin:auto;width:95%;display: flex; ">
                                                    <div>
                                                        <div class="h1-dashboard"><%= appointmentCount %>
                                                        </div>
                                                        <br>
                                                        <div class="h3-dashboard">New Appointments</div>
                                                    </div>
                                                    <div class="btn-icon-back dashboard-icons"
                                                         style="margin-left: 0px;background-image: url('../img/icons/book-hover.svg');"></div>
                                                </div>
                                            </td>
                                            <td style="width: 25%;">
                                                <div class="dashboard-items"
                                                     style="padding:20px;margin:auto;width:95%;display: flex;padding-top:21px;padding-bottom:21px;">
                                                    <div>
                                                        <div class="h1-dashboard"><%= scheduleCount %>
                                                        </div>
                                                        <br>
                                                        <div class="h3-dashboard" style="font-size: 15px">Today
                                                            Sessions
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
                            <td>
                                <p id="anim" style="font-size: 20px;font-weight:600;padding-left: 40px;">Your Upcoming
                                    Sessions until <%= escapeHtml(nextweek) %>
                                </p>
                                <center>
                                    <div class="abc scroll" style="height: 250px;padding: 0;margin: 0;">
                                        <table width="85%" class="sub-table scrolldown" border="0">
                                            <thead>
                                            <tr>
                                                <th class="table-headin">Session Title</th>
                                                <th class="table-headin">Scheduled Date</th>
                                                <th class="table-headin">Time</th>
                                            </tr>
                                            </thead>
                                            <tbody>
                                            <%
                                                boolean sessionsFound = false;
                                                if (rsSession != null) {
                                                    while (rsSession.next()) {
                                                        sessionsFound = true;
                                                        String title = rsSession.getString("title");
                                                        String scheduledate = rsSession.getString("scheduledate");
                                                        String scheduletime = rsSession.getString("scheduletime");
                                            %>
                                            <tr>
                                                <td style="padding:15px 10px;"><%= escapeHtml(safeSubstring(title, 0, 30)) %>
                                                </td>
                                                <td style="text-align:center;"><%= escapeHtml(scheduledate) %>
                                                </td>
                                                <td style="text-align:center;"><%= escapeHtml(safeSubstring(scheduletime, 0, 5)) %>
                                                </td>
                                            </tr>
                                            <% }
                                            }
                                                if (!sessionsFound) { %>
                                            <tr>
                                                <td colspan="3" style="text-align: center; padding: 30px 0;">
                                                    <img src="../img/notfound.svg" width="120px"
                                                         style="display: block; margin: 0 auto 15px auto;">
                                                    <p class="heading-main12"
                                                       style="font-size:18px;color:rgb(49, 49, 49)">No sessions
                                                        scheduled within the next week.</p>
                                                    <a class="non-style-link" href="schedule.jsp">
                                                        <button class="login-btn btn-primary-soft btn"
                                                                style="margin-top:10px;">&nbsp; Show all Sessions &nbsp;
                                                        </button>
                                                    </a>
                                                </td>
                                            </tr>
                                            <% } %>
                                            </tbody>
                                        </table>
                                    </div>
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
    } catch (ClassNotFoundException e) {
        errorMessage = "Database Driver not found.";
        e.printStackTrace();
        System.out.println("<div style='color:red; text-align:center; padding: 20px; font-family: sans-serif;'>CRITICAL ERROR: Database Driver not found. " + e.getMessage() + "</div>");
    } catch (SQLException e) {
        errorMessage = "Database Error: " + e.getMessage();
        e.printStackTrace();
        System.out.println("<div style='color:red; text-align:center; padding: 20px; font-family: sans-serif;'>DATABASE ERROR: " + e.getMessage() + " (SQLState: " + e.getSQLState() + ")</div>");
    } catch (Exception e) {
        errorMessage = "An unexpected error occurred: " + e.getMessage();
        e.printStackTrace();
        System.out.println("<div style='color:red; text-align:center; padding: 20px; font-family: sans-serif;'>UNEXPECTED ERROR: " + e.getMessage() + "</div>");
    } finally {
        closeQuietly(rsUser);
        closeQuietly(psUser);
        closeQuietly(rsSession);
        closeQuietly(psSession);
        closeQuietly(connection);
    }
%>
</body>
</html>
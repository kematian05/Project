<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page
        import="java.sql.*, java.util.*, java.text.*, java.time.LocalDate, java.time.format.DateTimeFormatter, java.net.URLEncoder" %>
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

    private String escapeHtml(String input) {
        if (input == null) return "";
        return StringEscapeUtils.escapeHtml4(input);
    }
%>
<%
    String useremail = (String) session.getAttribute("user");
    String usertype = (String) session.getAttribute("usertype");

    if (useremail == null || useremail.isEmpty() || !"p".equals(usertype)) {
        response.sendRedirect("../login.jsp");
        return;
    }

    String url = System.getenv("DB_URL");
    String dbUser = System.getenv("DB_USER");
    String dbPassword = System.getenv("DB_PASSWORD");

    Connection connection = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    PreparedStatement psUser = null;
    ResultSet rsUser = null;

    int patientId = 0;
    String patientName = "";
    String errorMessage = null;

    List<Map<String, Object>> sessionList = new ArrayList<>();
    List<String> doctorDatalist = new ArrayList<>();
    List<String> titleDatalist = new ArrayList<>();
    int sessionCount = 0;

    String searchKeyword = request.getParameter("search");
    searchKeyword = escapeHtml(searchKeyword);
    String searchTypeDisplay = "All";
    String insertKeyDisplay = "";
    String quoteDisplay = "";


    SimpleDateFormat displayTimeFormat = new SimpleDateFormat("HH:mm");
    SimpleDateFormat dbTimeFormat = new SimpleDateFormat("HH:mm:ss");
    String today = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd"));

    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        connection = DriverManager.getConnection(url, dbUser, dbPassword);

        String sqlUser = "SELECT pid, pname FROM patient WHERE pemail = ?";
        psUser = connection.prepareStatement(sqlUser);
        psUser.setString(1, useremail);
        rsUser = psUser.executeQuery();

        if (rsUser.next()) {
            patientId = rsUser.getInt("pid");
            patientName = rsUser.getString("pname");
        } else {
            closeQuietly(rsUser);
            closeQuietly(psUser);
            closeQuietly(connection);
            session.invalidate();
            response.sendRedirect("../login.jsp?error=user_not_found");
            return;
        }
        closeQuietly(rsUser);
        closeQuietly(psUser);

        StringBuilder sqlMain = new StringBuilder("SELECT schedule.scheduleid, schedule.title, doctor.docname, schedule.scheduledate, schedule.scheduletime, schedule.nop FROM schedule INNER JOIN doctor ON schedule.docid=doctor.docid WHERE schedule.scheduledate >= ? ");
        List<Object> params = new ArrayList<>();
        params.add(today);

        if (!isNullOrEmpty(searchKeyword)) {
            sqlMain.append(" AND (doctor.docname LIKE ? OR schedule.title LIKE ? OR schedule.scheduledate LIKE ?) ");
            String wildcardKeyword = "%" + searchKeyword + "%";
            params.add(wildcardKeyword);
            params.add(wildcardKeyword);
            params.add(wildcardKeyword);
            searchTypeDisplay = "Search Result : ";
            insertKeyDisplay = searchKeyword;
            quoteDisplay = "\"";
        }
        sqlMain.append(" ORDER BY schedule.scheduledate ASC, schedule.scheduletime ASC");

        ps = connection.prepareStatement(sqlMain.toString());
        for (int i = 0; i < params.size(); i++) {
            ps.setObject(i + 1, params.get(i));
        }
        rs = ps.executeQuery();

        while (rs.next()) {
            sessionCount++;
            Map<String, Object> sessionData = new HashMap<>();
            sessionData.put("scheduleid", rs.getInt("scheduleid"));
            sessionData.put("title", rs.getString("title"));
            sessionData.put("docname", rs.getString("docname"));
            sessionData.put("scheduledate", rs.getString("scheduledate"));
            sessionData.put("scheduletime", rs.getString("scheduletime"));
            sessionData.put("nop", rs.getInt("nop"));
            sessionList.add(sessionData);
        }
        closeQuietly(rs);
        closeQuietly(ps);

        ps = connection.prepareStatement("SELECT DISTINCT docname FROM doctor ORDER BY docname ASC");
        rs = ps.executeQuery();
        while (rs.next()) {
            doctorDatalist.add(rs.getString("docname"));
        }
        closeQuietly(rs);
        closeQuietly(ps);

        ps = connection.prepareStatement("SELECT DISTINCT title FROM schedule ORDER BY title ASC");
        rs = ps.executeQuery();
        while (rs.next()) {
            titleDatalist.add(rs.getString("title"));
        }


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
    <title>Sessions</title>
    <style>
        .popup {
            animation: transitionIn-Y-bottom 0.5s;
        }

        .sub-table {
            animation: transitionIn-Y-bottom 0.5s;
        }

        .info-message {
            padding: 10px 15px;
            margin: 10px 45px;
            border-radius: 5px;
            text-align: center;
            font-weight: 500;
            border: 1px solid #ccc;
            background-color: #f8f8f8;
            color: #555;
        }
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
                            <td width="30%" style="padding-left:20px">
                                <img src="../img/user.png" alt="" width="100%" style="border-radius:50%">
                            </td>
                            <td style="padding:0px;margin:0px;">
                                <p class="profile-title"><%= safeSubstring(patientName, 0, 30) %>
                                </p>
                                <p class="profile-subtitle"><%= safeSubstring(useremail, 0, 30) %>
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
                <td class="menu-btn menu-icon-home "><a href="index.jsp" class="non-style-link-menu ">
                    <div><p class="menu-text">Home</p>
                </a>
    </div>
    </a></td></tr>
    <tr class="menu-row">
        <td class="menu-btn menu-icon-doctor"><a href="therapists.jsp" class="non-style-link-menu">
            <div><p class="menu-text">All Therapists</p>
        </a>
</div>
</td></tr>
<tr class="menu-row">
    <td class="menu-btn menu-icon-session menu-active menu-icon-session-active"><a href="schedule.jsp"
                                                                                   class="non-style-link-menu non-style-link-menu-active">
        <div><p class="menu-text">Scheduled Sessions</p></div>
    </a></td>
</tr>
<tr class="menu-row">
    <td class="menu-btn menu-icon-appoinment"><a href="appointment.jsp" class="non-style-link-menu">
        <div><p class="menu-text">My Bookings</p>
    </a></div></td>
</tr>
<tr class="menu-row">
    <td class="menu-btn menu-icon-settings"><a href="settings.jsp" class="non-style-link-menu">
        <div><p class="menu-text">Settings</p>
    </a></div></td>
</tr>
</table>
</div>
<div class="dash-body">
    <table border="0" width="100%" style=" border-spacing: 0;margin:0;padding:0;margin-top:25px; ">
        <tr>
            <td width="13%"><a href="index.jsp">
                <button class="login-btn btn-primary-soft btn btn-icon-back"
                        style="padding-top:11px;padding-bottom:11px;margin-left:20px;width:140px"><font
                        class="tn-in-text">Dashboard</font></button>
            </a></td>
            <td>
                <form action="schedule.jsp" method="post" class="header-search">
                    <input type="search" name="search" class="input-text header-searchbar"
                           placeholder="Search Therapist name or Session Title or Date (YYYY-MM-DD)" list="doctors"
                           value="<%= insertKeyDisplay %>">&nbsp;&nbsp;
                    <datalist id="doctors">
                        <% for (String name : doctorDatalist) { %>
                        <option value="<%= name %>"><br/><% } %>
                                <% for (String title : titleDatalist) { %>
                        <option value="<%= title %>"><br/><% } %>
                    </datalist>
                    <input type="Submit" value="Search" class="login-btn btn-primary btn"
                           style="padding-left: 25px;padding-right: 25px;padding-top: 10px;padding-bottom: 10px;">
                </form>
            </td>
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
        <% if (errorMessage != null) { %>
        <tr>
            <td colspan="4">
                <div class="info-message"><%= errorMessage %>
                </div>
            </td>
        </tr>
        <% } %>
        <tr>
            <td colspan="4" style="padding-top:10px;width: 100%;">
                <p class="heading-main12"
                   style="margin-left: 45px;font-size:18px;color:rgb(49, 49, 49)"><%= searchTypeDisplay %> Sessions
                    (<%= sessionCount %>)</p>
                <p class="heading-main12"
                   style="margin-left: 45px;font-size:22px;color:rgb(49, 49, 49)"><%= quoteDisplay %><%= insertKeyDisplay %><%= quoteDisplay %>
                </p>
            </td>
        </tr>
        <tr>
            <td colspan="4">
                <center>
                    <div class="abc scroll">
                        <table width="100%" class="sub-table scrolldown" border="0" style="padding: 50px;border:none">
                            <tbody>
                            <% if (sessionList.isEmpty()) { %>
                            <tr>
                                <td colspan="4"><br><br><br><br>
                                    <center>
                                        <img src="../img/notfound.svg" width="25%"><br>
                                        <p class="heading-main12"
                                           style="margin-left: 45px;font-size:20px;color:rgb(49, 49, 49)">
                                            <%= !isNullOrEmpty(searchKeyword) ? "We couldn't find anything related to your keywords!" : "No sessions available." %>
                                        </p>
                                        <a class="non-style-link" href="schedule.jsp">
                                            <button class="login-btn btn-primary-soft btn"
                                                    style="display: flex;justify-content: center;align-items: center;margin-left:20px;">
                                                &nbsp; Show all Sessions &nbsp;
                                            </button>
                                        </a>
                                    </center>
                                    <br><br><br><br></td>
                            </tr>
                            <% } else {
                                int numSessions = sessionList.size();
                                for (int i = 0; i < numSessions; i += 3) { %>
                            <tr>
                                <% for (int j = 0; j < 3; j++) {
                                    int index = i + j;
                                    if (index < numSessions) {
                                        Map<String, Object> sessionData = sessionList.get(index);
                                        int scheduleid = (Integer) sessionData.get("scheduleid");
                                        String title = (String) sessionData.get("title");
                                        String docname = (String) sessionData.get("docname");
                                        String scheduledate = (String) sessionData.get("scheduledate");
                                        String scheduletime = (String) sessionData.get("scheduletime");
                                        String displayTime = "";
                                        try {
                                            if (scheduletime != null)
                                                displayTime = displayTimeFormat.format(dbTimeFormat.parse(scheduletime));
                                        } catch (ParseException e) {
                                            displayTime = safeSubstring(scheduletime, 0, 5);
                                        }
                                %>
                                <td style="width: 25%;">
                                    <div class="dashboard-items search-items">
                                        <div style="width:100%">
                                            <div class="h1-search"><%= safeSubstring(title, 0, 21) %>
                                            </div>
                                            <br>
                                            <div class="h3-search"><%= safeSubstring(docname, 0, 30) %>
                                            </div>
                                            <div class="h4-search"><%= scheduledate %><br>Starts: <b>@<%= displayTime %>
                                            </b> (24h)
                                            </div>
                                            <br>
                                            <a href="booking.jsp?id=<%= scheduleid %>">
                                                <button class="login-btn btn-primary-soft btn "
                                                        style="padding-top:11px;padding-bottom:11px;width:100%"><font
                                                        class="tn-in-text">Book Now</font></button>
                                            </a>
                                        </div>
                                    </div>
                                </td>
                                <% } else { %>
                                <td style="width: 25%;"></td>
                                <% }
                                } %>
                            </tr>
                            <% }
                            } %>
                            </tbody>
                        </table>
                    </div>
                </center>
            </td>
        </tr>
    </table>
</div>
</div>
<%
    } catch (ClassNotFoundException e) {
        errorMessage = "Database Driver not found.";
        e.printStackTrace();
        System.out.println("<div class='info-message error'>CRITICAL ERROR: Database Driver not found. " + e.getMessage() + "</div>");
    } catch (SQLException e) {
        errorMessage = "Database Error: " + e.getMessage();
        e.printStackTrace();
        System.out.println("<div class='info-message error'>DATABASE ERROR: " + e.getMessage() + " (SQLState: " + e.getSQLState() + ")</div>");
    } catch (Exception e) {
        errorMessage = "An unexpected error occurred: " + e.getMessage();
        e.printStackTrace();
        System.out.println("<div class='info-message error'>UNEXPECTED ERROR: " + e.getMessage() + "</div>");
    } finally {
        closeQuietly(rs);
        closeQuietly(ps);
        closeQuietly(rsUser);
        closeQuietly(psUser);
        closeQuietly(connection);
    }
%>
</body>
</html>
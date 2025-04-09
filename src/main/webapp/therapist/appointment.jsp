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

    if (useremail == null || useremail.isEmpty() || !"d".equals(usertype)) {
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

    int doctorId = 0;
    String doctorName = "";
    String errorMessage = null;
    String successMessage = null;
    String messageType = "error";

    String action = request.getParameter("action");
    action = escapeHtml(action);
    String idParam = request.getParameter("id");
    idParam = escapeHtml(idParam);
    String nameParam = request.getParameter("name");
    nameParam = escapeHtml(nameParam);
    String sessionParam = request.getParameter("session");
    sessionParam = escapeHtml(sessionParam);
    String apponumParam = request.getParameter("apponum");
    String apponum = request.getParameter("apponum");

    String filterDate = request.getParameter("sheduledate");
    filterDate = escapeHtml(filterDate);

    List<Map<String, Object>> appointmentList = new ArrayList<>();
    int appointmentCount = 0;

    SimpleDateFormat displayTimeFormat = new SimpleDateFormat("HH:mm");
    SimpleDateFormat dbTimeFormat = new SimpleDateFormat("HH:mm:ss");

    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        connection = DriverManager.getConnection(url, dbUser, dbPassword);
        connection.setAutoCommit(false);

        String sqlUser = "SELECT docid, docname FROM doctor WHERE docemail = ?";
        psUser = connection.prepareStatement(sqlUser);
        psUser.setString(1, useremail);
        rsUser = psUser.executeQuery();

        if (rsUser.next()) {
            doctorId = rsUser.getInt("docid");
            doctorName = rsUser.getString("docname");
        } else {
            session.invalidate();
            response.sendRedirect("../login.jsp?error=user_not_found");
            return;
        }
        closeQuietly(rsUser);
        closeQuietly(psUser);

        if ("confirm-delete".equals(action)) {
            String idToDeleteStr = request.getParameter("deleteid");
            idToDeleteStr = escapeHtml(idToDeleteStr);
            if (isNullOrEmpty(idToDeleteStr)) {
                errorMessage = "Cancellation failed: Missing Appointment ID.";
            } else {
                PreparedStatement psDel = null;
                PreparedStatement psCheckOwner = null;
                ResultSet rsCheckOwner = null;
                boolean allowedToDelete = false;
                try {
                    int appoIdToDelete = Integer.parseInt(idToDeleteStr);

                    psCheckOwner = connection.prepareStatement("SELECT COUNT(*) FROM appointment INNER JOIN schedule ON appointment.scheduleid = schedule.scheduleid WHERE appointment.appoid = ? AND schedule.docid = ?");
                    psCheckOwner.setInt(1, appoIdToDelete);
                    psCheckOwner.setInt(2, doctorId);
                    rsCheckOwner = psCheckOwner.executeQuery();
                    if (rsCheckOwner.next() && rsCheckOwner.getInt(1) > 0) {
                        allowedToDelete = true;
                    }
                    closeQuietly(rsCheckOwner);
                    closeQuietly(psCheckOwner);

                    if (allowedToDelete) {
                        psDel = connection.prepareStatement("DELETE FROM appointment WHERE appoid = ?");
                        psDel.setInt(1, appoIdToDelete);
                        int rowsAffected = psDel.executeUpdate();
                        if (rowsAffected > 0) {
                            connection.commit();
                            successMessage = "Appointment cancelled successfully.";
                            messageType = "success";
                        } else {
                            connection.rollback();
                            errorMessage = "Cancellation failed: Appointment not found (may have already been cancelled).";
                        }
                    } else {
                        errorMessage = "Cancellation failed: You do not have permission to cancel this appointment.";
                    }
                } catch (NumberFormatException e) {
                    connection.rollback();
                    errorMessage = "Cancellation failed: Invalid Appointment ID.";
                } catch (SQLException e) {
                    connection.rollback();
                    errorMessage = "Cancellation failed due to database error: " + e.getMessage();
                    e.printStackTrace();
                } finally {
                    closeQuietly(rsCheckOwner);
                    closeQuietly(psCheckOwner);
                    closeQuietly(psDel);
                }
            }
            action = null;
        }


        StringBuilder sqlMain = new StringBuilder("SELECT appointment.appoid, schedule.scheduleid, schedule.title, patient.pname, schedule.scheduledate, schedule.scheduletime, appointment.apponum, appointment.appodate, appointment.meeting_link ")
                .append("FROM schedule INNER JOIN appointment ON schedule.scheduleid=appointment.scheduleid ")
                .append("INNER JOIN patient ON patient.pid=appointment.pid ")
                .append("WHERE schedule.docid = ? ");

        List<Object> params = new ArrayList<>();
        params.add(doctorId);

        if (!isNullOrEmpty(filterDate)) {
            sqlMain.append(" AND schedule.scheduledate = ? ");
            params.add(filterDate);
        }

        sqlMain.append(" ORDER BY schedule.scheduledate ASC, schedule.scheduletime ASC, appointment.apponum ASC");


        String countSql = "SELECT count(*) FROM schedule INNER JOIN appointment ON schedule.scheduleid=appointment.scheduleid INNER JOIN patient ON patient.pid=appointment.pid WHERE schedule.docid = ?";
        ps = connection.prepareStatement(countSql);
        ps.setInt(1, doctorId);
        rs = ps.executeQuery();
        if (rs.next()) {
            appointmentCount = rs.getInt(1);
        }
        closeQuietly(rs);
        closeQuietly(ps);


        ps = connection.prepareStatement(sqlMain.toString());
        for (int i = 0; i < params.size(); i++) {
            ps.setObject(i + 1, params.get(i));
        }
        rs = ps.executeQuery();

        while (rs.next()) {
            Map<String, Object> app = new HashMap<>();
            app.put("appoid", rs.getInt("appoid"));
            app.put("scheduleid", rs.getInt("scheduleid"));
            app.put("title", rs.getString("title"));
            app.put("pname", rs.getString("pname"));
            app.put("scheduledate", rs.getString("scheduledate"));
            app.put("scheduletime", rs.getString("scheduletime"));
            app.put("apponum", rs.getInt("apponum"));
            app.put("appodate", rs.getString("appodate"));
            app.put("meeting_link", rs.getString("meeting_link"));
            appointmentList.add(app);
        }

        String today = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd"));
        action = request.getParameter("action");
        action = escapeHtml(action);
        idParam = request.getParameter("id");
        idParam = escapeHtml(idParam);
        nameParam = request.getParameter("name");
        nameParam = escapeHtml(nameParam);
        apponumParam = request.getParameter("apponum");
        apponumParam = escapeHtml(apponumParam);


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
    <title>Appointments</title>
    <style>
        .popup {
            animation: transitionIn-Y-bottom 0.5s;
            z-index: 100;
        }

        .sub-table {
            animation: transitionIn-Y-bottom 0.5s;
        }

        .overlay {
            position: fixed;
            top: 0;
            bottom: 0;
            left: 0;
            right: 0;
            background: rgba(0, 0, 0, 0.7);
            transition: opacity 500ms;
            visibility: hidden;
            opacity: 0;
            z-index: 99;
        }

        .overlay.visible {
            visibility: visible;
            opacity: 1;
        }

        .info-message {
            padding: 10px 15px;
            margin: 10px 45px;
            border-radius: 5px;
            text-align: center;
            font-weight: 500;
            border: 1px solid;
        }

        .info-message.success {
            color: #388E3C;
            background-color: #C8E6C9;
            border-color: #81C784;
        }

        .info-message.error {
            color: #D32F2F;
            background-color: #FFCDD2;
            border-color: #E57373;
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
                                <p class="profile-title"><%= safeSubstring(doctorName, 0, 30) %></p>
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
                <td class="menu-btn menu-icon-dashbord "><a href="index.jsp" class="non-style-link-menu ">
                    <div><p class="menu-text">Dashboard</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-appoinment menu-active menu-icon-appoinment-active"><a
                        href="appointment.jsp" class="non-style-link-menu non-style-link-menu-active">
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
    <div class="dash-body">
        <table border="0" width="100%" style=" border-spacing: 0;margin:0;padding:0;margin-top:25px; ">
            <tr>
                <td width="13%"><a href="index.jsp">
                    <button class="login-btn btn-primary-soft btn btn-icon-back"
                            style="padding-top:11px;padding-bottom:11px;margin-left:20px;width:125px"><font
                            class="tn-in-text">Back</font></button>
                </a></td>
                <td><p style="font-size: 23px;padding-left:12px;font-weight: 600;">Appointment Manager</p></td>
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
                    <div class="info-message error"><%= errorMessage %>
                    </div>
                </td>
            </tr>
            <% } %>
            <% if (successMessage != null) { %>
            <tr>
                <td colspan="4">
                    <div class="info-message success"><%= successMessage %>
                    </div>
                </td>
            </tr>
            <% } %>
            <tr>
                <td colspan="4" style="padding-top:10px;width: 100%;"><p class="heading-main12"
                                                                         style="margin-left: 45px;font-size:18px;color:rgb(49, 49, 49)">
                    My Appointments (<%= appointmentCount %>)</p></td>
            </tr>
            <tr>
                <td colspan="4" style="padding-top:0px;width: 100%;">
                    <center>
                        <table class="filter-container" border="0">
                            <tr>
                                <td width="10%"></td>
                                <td width="5%" style="text-align: center;">Date:</td>
                                <td width="30%">
                                    <form action="appointment.jsp" method="post">
                                        <input type="date" name="sheduledate" id="date"
                                               class="input-text filter-container-items" style="margin: 0;width: 95%;"
                                               value="<%= filterDate != null ? filterDate : "" %>">
                                </td>
                                <td width="12%">
                                    <input type="submit" name="filter" value=" Filter"
                                           class=" btn-primary-soft btn button-icon btn-filter"
                                           style="padding: 15px; margin :0;width:100%">
                                    </form>
                                </td>
                                <td width="10%"></td>
                            </tr>
                        </table>
                    </center>
                </td>
            </tr>
            <tr>
                <td colspan="4">
                    <center>
                        <div class="abc scroll">
                            <table width="93%" class="sub-table scrolldown" border="0">
                                <thead>
                                <tr>
                                    <th class="table-headin">Client name</th>
                                    <th class="table-headin">Appointment number</th>
                                    <th class="table-headin">Session Title</th>
                                    <th class="table-headin">Session Date & Time</th>
                                    <th class="table-headin">Appointment Date</th>
                                    <th class="table-headin">Events</th>
                                    <th class="table-headin">Meeting Link</th>
                                </tr>
                                </thead>
                                <tbody>
                                <% if (appointmentList.isEmpty()) { %>
                                <tr>
                                    <td colspan="7"><br><br><br><br>
                                        <center>
                                            <img src="../img/notfound.svg" width="25%"><br>
                                            <p class="heading-main12"
                                               style="margin-left: 45px;font-size:20px;color:rgb(49, 49, 49)">
                                                <%= !isNullOrEmpty(filterDate) ? "No appointments found for the selected date!" : "No appointments scheduled yet." %>
                                            </p>
                                            <a class="non-style-link" href="appointment.jsp">
                                                <button class="login-btn btn-primary-soft btn"
                                                        style="display: flex;justify-content: center;align-items: center;margin-left:20px;">
                                                    &nbsp; Show all Appointments &nbsp;
                                                </button>
                                            </a>
                                        </center>
                                        <br><br><br><br></td>
                                </tr>
                                <% } else {
                                    for (Map<String, Object> app : appointmentList) {
                                        int appoid = (Integer) app.get("appoid");
                                        String title = (String) app.get("title");
                                        String scheduledate = (String) app.get("scheduledate");
                                        String scheduletime = (String) app.get("scheduletime");
                                        String pname = (String) app.get("pname");
                                        int apponum = (Integer) app.get("apponum");
                                        String appodate = (String) app.get("appodate");
                                        String meetingLink = (String) app.get("meeting_link");
                                        String displayTime = "";
                                        try {
                                            if (scheduletime != null)
                                                displayTime = displayTimeFormat.format(dbTimeFormat.parse(scheduletime));
                                        } catch (ParseException e) {
                                            displayTime = safeSubstring(scheduletime, 0, 5);
                                        }
                                %>
                                <tr>
                                    <td style="font-weight:600;">&nbsp;<%= safeSubstring(pname, 0, 25) %>
                                    </td>
                                    <td style="text-align:center;font-size:23px;font-weight:500; color: var(--btnnicetext);"><%= apponum %>
                                    </td>
                                    <td><%= safeSubstring(title, 0, 15) %>
                                    </td>
                                    <td style="text-align:center;"><%= safeSubstring(scheduledate, 0, 10) %>
                                        @ <%= displayTime %>
                                    </td>
                                    <td style="text-align:center;"><%= appodate %>
                                    </td>
                                    <td>
                                        <div style="display:flex;justify-content: center;">
                                            <a href="?action=drop&id=<%= appoid %>&name=<%= URLEncoder.encode(pname != null ? pname : "", "UTF-8") %>&session=<%= URLEncoder.encode(title != null ? title : "", "UTF-8") %>&apponum=<%= apponum %>"
                                               class="non-style-link">
                                                <button class="btn-primary-soft btn button-icon btn-delete"
                                                        style="padding-left: 40px;padding-top: 12px;padding-bottom: 12px;margin-top: 10px;">
                                                    <font class="tn-in-text">Cancel</font></button>
                                            </a>&nbsp;&nbsp;&nbsp;
                                        </div>
                                    </td>
                                    <td style="text-align:center;">
                                        <% if (!isNullOrEmpty(meetingLink)) { %>
                                        <a href="<%= meetingLink %>" target="_blank" class="non-style-link">
                                            <button class="btn-primary-soft btn button-icon"
                                                    style="padding-left: 40px;padding-top: 12px;padding-bottom: 12px;margin-top: 10px; margin-top: 10px; background-image: url('../img/icons/video-call.svg'); background-repeat: no-repeat; background-position: 10px center; padding-left: 40px;">
                                                <font class="tn-in-text">Join</font>
                                            </button>
                                        </a>
                                        <% } else { %>
                                        &nbsp;
                                        <% } %>
                                    </td>
                                </tr>
                                <%
                                        }
                                    }
                                %>
                                </tbody>
                            </table>
                        </div>
                    </center>
                </td>
            </tr>
        </table>
    </div>
</div>
<% if ("drop".equals(action) && !isNullOrEmpty(idParam)) { %>
<div id="popup1" class="overlay visible">
    <div class="popup">
        <center>
            <h2>Are you sure?</h2>
            <a class="close" href="appointment.jsp">&times;</a>
            <div class="content">
                You want to cancel this appointment?<br><br>
                Client Name: &nbsp;<b><%= safeSubstring(nameParam, 0, 40) %>
            </b><br>
                Appointment number &nbsp; : <b><%= safeSubstring(apponumParam, 0, 40) %>
            </b><br><br>
            </div>
            <div style="display: flex;justify-content: center;">
                <a href="appointment.jsp?action=confirm-delete&deleteid=<%= idParam %>" class="non-style-link">
                    <button class="btn-primary btn"
                            style="display: flex;justify-content: center;align-items: center;margin:10px;padding:10px;">
                        <font class="tn-in-text">&nbsp;Yes&nbsp;</font></button>
                </a>&nbsp;&nbsp;&nbsp;
                <a href="appointment.jsp" class="non-style-link">
                    <button class="btn-primary-soft btn"
                            style="display: flex;justify-content: center;align-items: center;margin:10px;padding:10px;">
                        <font class="tn-in-text">&nbsp;&nbsp;No&nbsp;&nbsp;</font></button>
                </a>
            </div>
        </center>
    </div>
</div>
<% } %>
<%
    } catch (ClassNotFoundException e) {
        errorMessage = "Database Driver not found.";
        e.printStackTrace();
        System.out.println("<div class='info-message error'>CRITICAL ERROR: Database Driver not found. " + e.getMessage() + "</div>");
    } catch (SQLException e) {
        errorMessage = "Database Error: " + e.getMessage();
        if (connection != null && !connection.getAutoCommit()) {
            try {
                connection.rollback();
            } catch (SQLException re) {
            }
        }
        e.printStackTrace();
        System.out.println("<div class='info-message error'>DATABASE ERROR: " + e.getMessage() + " (SQLState: " + e.getSQLState() + ")</div>");
    } catch (Exception e) {
        errorMessage = "An unexpected error occurred: " + e.getMessage();
        if (connection != null && !connection.getAutoCommit()) {
            try {
                connection.rollback();
            } catch (SQLException re) {
            }
        }
        e.printStackTrace();
        System.out.println("<div class='info-message error'>UNEXPECTED ERROR: " + e.getMessage() + "</div>");
    } finally {
        if (connection != null) {
            try {
                if (!connection.getAutoCommit()) {
                    connection.setAutoCommit(true);
                }
            } catch (SQLException se) {
            }
        }
        closeQuietly(rs);
        closeQuietly(ps);
        closeQuietly(rsUser);
        closeQuietly(psUser);
        closeQuietly(connection);
    }
%>
</body>
</html>
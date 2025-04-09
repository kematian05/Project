<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page
        import="java.sql.*, java.util.*, java.text.*, java.net.URLEncoder, java.time.LocalDate, java.time.format.DateTimeFormatter" %>
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
        if (input == null) return null;
        return StringEscapeUtils.escapeHtml4(input);
    }
%>
<%
    String user = (String) session.getAttribute("user");
    String usertype = (String) session.getAttribute("usertype");

    if (isNullOrEmpty(user) || !"a".equals(usertype)) {
        response.sendRedirect("../login.jsp");
        return;
    }

    String url = System.getenv("DB_URL");
    String dbUser = System.getenv("DB_USER");
    String dbPassword = System.getenv("DB_PASSWORD");

    Connection connection = null;
    PreparedStatement ps = null;
    ResultSet rs = null;
    PreparedStatement psDoc = null;
    ResultSet rsDoc = null;

    String errorMessage = null;
    String successMessage = null;
    String deleteStatus = null;

    String action = request.getParameter("action");
    action = escapeHtml(action);
    String idParam = request.getParameter("id");
    idParam = escapeHtml(idParam);

    if ("confirm-delete".equals(action)) {
        String idToDeleteStr = request.getParameter("deleteid");
        idToDeleteStr = escapeHtml(idToDeleteStr);
        Connection deleteConn = null;
        PreparedStatement deletePs = null;
        try {
            if (isNullOrEmpty(idToDeleteStr)) {
                deleteStatus = "missing_id";
            } else {
                int idToDelete = Integer.parseInt(idToDeleteStr);
                Class.forName("com.mysql.cj.jdbc.Driver");
                deleteConn = DriverManager.getConnection(url, dbUser, dbPassword);
                String sql = "DELETE FROM appointment WHERE appoid = ?";
                deletePs = deleteConn.prepareStatement(sql);
                deletePs.setInt(1, idToDelete);
                int rowsAffected = deletePs.executeUpdate();
                deleteStatus = (rowsAffected > 0) ? "success" : "not_found";
            }
        } catch (NumberFormatException e) {
            deleteStatus = "invalid_id";
        } catch (ClassNotFoundException | SQLException e) {
            deleteStatus = "db_error";
            e.printStackTrace();
        } catch (Exception e) {
            deleteStatus = "unknown_error";
            e.printStackTrace();
        } finally {
            closeQuietly(deletePs);
            closeQuietly(deleteConn);
        }
        response.sendRedirect("appointment.jsp?deleteStatus=" + deleteStatus);
        return;
    }

    deleteStatus = request.getParameter("deleteStatus");
    deleteStatus = escapeHtml(deleteStatus);
    if (deleteStatus != null) {
        switch (deleteStatus) {
            case "success":
                successMessage = "Appointment cancelled successfully.";
                break;
            case "not_found":
                errorMessage = "Cancellation failed: Appointment not found.";
                break;
            case "invalid_id":
            case "missing_id":
                errorMessage = "Cancellation failed: Invalid ID.";
                break;
            default:
                errorMessage = "Cancellation failed: Server error.";
                break;
        }
    }

    String filterDate = request.getParameter("sheduledate");
    filterDate = escapeHtml(filterDate);
    String filterDocId = request.getParameter("docid");
    filterDocId = escapeHtml(filterDocId);
    String nameParam = request.getParameter("name");
    nameParam = escapeHtml(nameParam);
    String sessionParam = request.getParameter("session");
    sessionParam = escapeHtml(sessionParam);
    String apponumParam = request.getParameter("apponum");
    apponumParam = escapeHtml(apponumParam);

    boolean showDeleteConfirmPopup = "drop".equals(action) && idParam != null;

    LocalDate todayDate = LocalDate.now();
    DateTimeFormatter dtf = DateTimeFormatter.ofPattern("yyyy-MM-dd");
    String today = todayDate.format(dtf);

    List<Object> params = new ArrayList<>();
    StringBuilder sqlWhere = new StringBuilder();

    if (!isNullOrEmpty(filterDate)) {
        sqlWhere.append(" WHERE schedule.scheduledate = ?");
        params.add(filterDate);
    }

    if (!isNullOrEmpty(filterDocId)) {
        try {
            int docIdInt = Integer.parseInt(filterDocId);
            sqlWhere.append(sqlWhere.length() > 0 ? " AND" : " WHERE");
            sqlWhere.append(" doctor.docid = ?");
            params.add(docIdInt);
        } catch (NumberFormatException e) {
            if (errorMessage == null) errorMessage = "Invalid Doctor ID for filtering.";
        }
    }

    String baseSql = " FROM schedule " +
            "INNER JOIN appointment ON schedule.scheduleid=appointment.scheduleid " +
            "INNER JOIN patient ON patient.pid=appointment.pid " +
            "INNER JOIN doctor ON schedule.docid=doctor.docid";

    String sqlMain = "SELECT appointment.appoid, schedule.scheduleid, schedule.title, doctor.docname, patient.pname, " +
            "schedule.scheduledate, schedule.scheduletime, appointment.apponum, appointment.appodate, appointment.meeting_link " +
            baseSql + sqlWhere.toString() +
            " ORDER BY schedule.scheduledate DESC, schedule.scheduletime ASC, appointment.apponum ASC";

    String countSql = "SELECT count(*)" + baseSql + sqlWhere.toString();

    int totalAppointments = 0;

    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        connection = DriverManager.getConnection(url, dbUser, dbPassword);

        ps = connection.prepareStatement(countSql);
        for (int i = 0; i < params.size(); i++) {
            ps.setObject(i + 1, params.get(i));
        }
        rs = ps.executeQuery();
        if (rs.next()) {
            totalAppointments = rs.getInt(1);
        }
        closeQuietly(rs);
        closeQuietly(ps);
        rs = null;
        ps = null;

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
            background: #fff;
            border-radius: 8px;
            box-shadow: 0 5px 15px rgba(0, 0, 0, 0.3);
            max-width: 450px;
            width: 90%;
        }

        .sub-table {
            animation: transitionIn-Y-bottom 0.5s;
            border-collapse: collapse;
        }

        .overlay {
            position: fixed;
            top: 0;
            bottom: 0;
            left: 0;
            right: 0;
            background: rgba(0, 0, 0, 0.6);
            transition: opacity 500ms;
            visibility: hidden;
            opacity: 0;
            z-index: 99;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .overlay.visible {
            visibility: visible;
            opacity: 1;
        }

        .message-bar {
            padding: 12px 20px;
            margin: 15px 45px;
            border-radius: 6px;
            text-align: center;
            font-weight: 500;
            border: 1px solid transparent;
        }

        .message-error {
            color: #a94442;
            background-color: #f2dede;
            border-color: #ebccd1;
        }

        .message-success {
            color: #3c763d;
            background-color: #dff0d8;
            border-color: #d6e9c6;
        }

        .filter-section {
            background-color: #f8f9fa;
            padding: 15px 25px;
            margin: 10px 45px;
            border-radius: 8px;
            display: flex;
            align-items: center;
            gap: 15px;
            flex-wrap: wrap;
            border: 1px solid #dee2e6;
        }

        .filter-item {
            display: flex;
            flex-direction: column;
            gap: 5px;
        }

        .filter-item label {
            font-size: 0.85em;
            color: #495057;
            font-weight: 500;
        }

        .filter-item .input-text, .filter-item .box {
            height: 38px;
            border-radius: 4px;
            border: 1px solid #ced4da;
            padding: 0 10px;
            font-size: 0.95em;
        }

        .filter-item .box {
            padding-right: 30px;
        }

        .btn-filter {
            padding: 0 20px !important;
            height: 38px;
            align-self: flex-end;
        }

        .table-headin {
            background-color: #f2f2f2;
            padding: 12px 10px;
            font-size: 0.9em;
            text-align: left;
            border-bottom: 2px solid #ddd;
        }

        .sub-table td {
            padding: 10px 10px;
            border-bottom: 1px solid #eee;
            font-size: 0.95em;
            vertical-align: middle;
        }

        .sub-table tbody tr:hover {
            background-color: #f9f9f9;
        }

        .action-buttons-cell button {
            padding: 5px 15px !important;
            font-size: 0.85em !important;
            height: auto !important;
            margin: 0 !important;
        }

        .popup .content {
            padding: 20px 25px;
            line-height: 1.6;
        }

        .popup .content b {
            color: #333;
        }

        .popup .button-container {
            display: flex;
            justify-content: center;
            gap: 15px;
            padding: 15px 25px;
            border-top: 1px solid #eee;
        }

        .popup .button-container button {
            min-width: 80px;
        }

        .button-icon-video {
            background-image: url('../img/icons/video-call.svg');
            background-repeat: no-repeat;
            background-position: 10px center;
            padding-left: 40px !important;
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
                            <td width="30%" style="padding-left:20px"><img src="../img/user.png" alt="Admin"
                                                                           width="100%" style="border-radius:50%"></td>
                            <td style="padding:0px;margin:0px;"><p class="profile-title">Administrator</p>
                                <p class="profile-subtitle"><%= escapeHtml(user) %>
                                </p></td>
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
                <td class="menu-btn menu-icon-dashbord"><a href="index.jsp" class="non-style-link-menu">
                    <div><p class="menu-text">Dashboard</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-doctor"><a href="therapists.jsp" class="non-style-link-menu">
                    <div><p class="menu-text">Therapists</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-schedule"><a href="schedule.jsp" class="non-style-link-menu">
                    <div><p class="menu-text">Schedules</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-appoinment menu-active menu-icon-appoinment-active"><a
                        href="appointment.jsp" class="non-style-link-menu non-style-link-menu-active">
                    <div><p class="menu-text">Appointments</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-patient"><a href="clients.jsp" class="non-style-link-menu">
                    <div><p class="menu-text">Clients</p></div>
                </a></td>
            </tr>
        </table>
    </div>
    <div class="dash-body">
        <table border="0" width="100%" style=" border-spacing: 0;margin:0;padding:0;margin-top:25px;">
            <tr>
                <td width="13%"><a href="index.jsp">
                    <button class="login-btn btn-primary-soft btn btn-icon-back"
                            style="padding:11px 0; margin-left:20px; width:140px;">&emsp;&emsp;Dashboard
                    </button>
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
                    <div class="message-bar message-error"><%= escapeHtml(errorMessage) %>
                    </div>
                </td>
            </tr>
            <% } %>
            <% if (successMessage != null) { %>
            <tr>
                <td colspan="4">
                    <div class="message-bar message-success"><%= escapeHtml(successMessage) %>
                    </div>
                </td>
            </tr>
            <% } %>
            <tr>
                <td colspan="4" style="padding-top:10px;width: 100%;"><p class="heading-main12"
                                                                         style="margin-left: 45px;font-size:18px;color:rgb(49, 49, 49)">
                    All Appointments (<%= totalAppointments %>)</p></td>
            </tr>
            <tr>
                <td colspan="4" style="width: 100%;">
                    <form action="appointment.jsp" method="post" class="filter-section">
                        <div class="filter-item">
                            <label for="date">Date:</label>
                            <input type="date" name="sheduledate" id="date" class="input-text"
                                   value="<%= filterDate != null ? filterDate : "" %>">
                        </div>
                        <div class="filter-item">
                            <label for="docid">Therapist:</label>
                            <select name="docid" id="docid" class="box">
                                <option value="">All Therapists</option>
                                <% try {
                                    psDoc = connection.prepareStatement("SELECT docid, docname FROM doctor ORDER BY docname ASC");
                                    rsDoc = psDoc.executeQuery();
                                    while (rsDoc.next()) {
                                        String docId = rsDoc.getString("docid");
                                        String docName = rsDoc.getString("docname");
                                        String selected = (filterDocId != null && filterDocId.equals(docId)) ? "selected" : "";
                                %>
                                <option value="<%= escapeHtml(docId) %>" <%= selected %>><%= escapeHtml(docName) %>
                                </option>
                                <% }
                                } catch (SQLException e) {
                                    System.out.println("<option value=''>Error loading doctors</option>");
                                    e.printStackTrace();
                                } finally {
                                    closeQuietly(rsDoc);
                                    closeQuietly(psDoc);
                                    rsDoc = null;
                                    psDoc = null;
                                } %>
                            </select>
                        </div>
                        <input type="submit" name="filter" value="Filter" class="login-btn btn-primary btn btn-filter">
                    </form>
                </td>
            </tr>
            <tr>
                <td colspan="4">
                    <center>
                        <div class="abc scroll">
                            <table width="93%" class="sub-table scrolldown" border="0" style="margin-top: 15px;">
                                <thead>
                                <tr>
                                    <th class="table-headin">Client Name</th>
                                    <th class="table-headin" style="text-align:center;">Appt. No</th>
                                    <th class="table-headin">Therapist</th>
                                    <th class="table-headin">Session Title</th>
                                    <th class="table-headin">Session Date & Time</th>
                                    <th class="table-headin" style="text-align:center;">Booked On</th>
                                    <th class="table-headin" style="text-align: center;">Actions</th>
                                    <th class="table-headin" style="text-align: center;">Meeting Link</th>
                                </tr>
                                </thead>
                                <tbody>
                                <%
                                    ps = connection.prepareStatement(sqlMain);
                                    for (int i = 0; i < params.size(); i++) {
                                        ps.setObject(i + 1, params.get(i));
                                    }
                                    rs = ps.executeQuery();
                                    boolean found = false;
                                    while (rs.next()) {
                                        found = true;
                                        int appoid = rs.getInt("appoid");
                                        String title = rs.getString("title");
                                        String docname = rs.getString("docname");
                                        String scheduledate = rs.getString("scheduledate");
                                        String scheduletime = rs.getString("scheduletime");
                                        String pname = rs.getString("pname");
                                        int apponum = rs.getInt("apponum");
                                        String appodate = rs.getString("appodate");
                                        String meetingLink = rs.getString("meeting_link");
                                        String displayTime = safeSubstring(scheduletime, 0, 5);
                                %>
                                <tr>
                                    <td><%= escapeHtml(safeSubstring(pname, 0, 25)) %>
                                    </td>
                                    <td style="text-align:center; font-weight:500; color: var(--btnnicetext);"><%= apponum %>
                                    </td>
                                    <td><%= escapeHtml(safeSubstring(docname, 0, 25)) %>
                                    </td>
                                    <td><%= escapeHtml(safeSubstring(title, 0, 20)) %>
                                    </td>
                                    <td><%= escapeHtml(safeSubstring(scheduledate, 0, 10)) %>&nbsp;&nbsp;<%= escapeHtml(displayTime) %>
                                    </td>
                                    <td style="text-align:center;"><%= escapeHtml(appodate) %>
                                    </td>
                                    <td style="text-align:center;">
                                        <a href="?action=drop&id=<%= appoid %>&name=<%= URLEncoder.encode(pname != null ? pname : "", "UTF-8") %>&session=<%= URLEncoder.encode(title != null ? title : "", "UTF-8") %>&apponum=<%= apponum %>"
                                           class="non-style-link">
                                            <button class="btn-primary-soft btn button-icon btn-delete">Cancel</button>
                                        </a>
                                    </td>
                                    <td style="text-align:center;">
                                        <% if (!isNullOrEmpty(meetingLink)) { %>
                                        <a href="<%= escapeHtml(meetingLink) %>" target="_blank" class="non-style-link">
                                            <button class="btn-primary-soft btn button-icon button-icon-video">Join</button>
                                        </a>
                                        <% } else { %>
                                        &nbsp;
                                        <% } %>
                                    </td>
                                </tr>
                                <% }
                                    if (!found) { %>
                                <tr>
                                    <td colspan="8" style="text-align:center; padding: 40px 20px;">
                                        <img src="../img/notfound.svg" width="150px"
                                             style="display:block; margin:0 auto 20px auto;">
                                        <p class="heading-main12" style="font-size:18px;color:rgb(49, 49, 49)">
                                            <% if (sqlWhere.length() > 0) { %>No appointments found matching your filter
                                            criteria.<% } else { %>No appointments scheduled yet.<% } %>
                                        </p>
                                        <% if (sqlWhere.length() > 0) { %><a class="non-style-link"
                                                                             href="appointment.jsp">
                                        <button class="login-btn btn-primary-soft btn" style="margin-top:15px;">Show all
                                            Appointments
                                        </button>
                                    </a><% } %>
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
    </div>
</div>

<% if (showDeleteConfirmPopup) {
    String safeName = escapeHtml(safeSubstring(nameParam, 0, 40));
    String safeApptNum = escapeHtml(safeSubstring(apponumParam, 0, 10));
%>
<div id="popup1" class="overlay visible">
    <div class="popup">
        <a class="close" href="appointment.jsp">&times;</a>
        <center><h2 style="margin-top:25px; margin-bottom:10px;">Confirm Cancellation</h2></center>
        <div class="content">
            Are you sure you want to cancel the appointment for:<br>
            Client: &nbsp;<b><%= safeName %>
        </b><br>
            Appt. No: &nbsp;<b><%= safeApptNum %>
        </b><br>
        </div>
        <div class="button-container">
            <a href="appointment.jsp?action=confirm-delete&deleteid=<%= escapeHtml(idParam) %>" class="non-style-link">
                <button class="btn-primary btn">Yes, Cancel</button>
            </a>
            <a href="appointment.jsp" class="non-style-link">
                <button class="btn-primary-soft btn">No, Keep it</button>
            </a>
        </div>
    </div>
</div>
<% } %>

<%
    } catch (ClassNotFoundException e) {
        System.out.println("<div class='message-bar message-error'>CRITICAL: Database Driver not found.</div>");
        e.printStackTrace();
    } catch (SQLException e) {
        System.out.println("<div class='message-bar message-error'>Database access error: " + e.getMessage() + "</div>");
        e.printStackTrace();
    } catch (Exception e) {
        System.out.println("<div class='message-bar message-error'>An unexpected error occurred: " + e.getMessage() + "</div>");
        e.printStackTrace();
    } finally {
        closeQuietly(rs);
        closeQuietly(ps);
        closeQuietly(rsDoc);
        closeQuietly(psDoc);
        closeQuietly(connection);
    }
%>
</body>
</html>
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

    String filterDate = request.getParameter("sheduledate");
    filterDate = escapeHtml(filterDate);

    List<Map<String, Object>> sessionList = new ArrayList<>();
    int sessionCount = 0;

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
                errorMessage = "Cancellation failed: Missing Session ID.";
            } else {
                PreparedStatement psDelApp = null;
                PreparedStatement psDelSch = null;
                try {
                    int scheduleIdToDelete = Integer.parseInt(idToDeleteStr);

                    psDelApp = connection.prepareStatement("DELETE FROM appointment WHERE scheduleid = ?");
                    psDelApp.setInt(1, scheduleIdToDelete);
                    psDelApp.executeUpdate();

                    psDelSch = connection.prepareStatement("DELETE FROM schedule WHERE scheduleid = ? AND docid = ?");
                    psDelSch.setInt(1, scheduleIdToDelete);
                    psDelSch.setInt(2, doctorId);
                    int rowsAffected = psDelSch.executeUpdate();

                    if (rowsAffected > 0) {
                        connection.commit();
                        successMessage = "Session cancelled successfully along with associated appointments.";
                        messageType = "success";
                    } else {
                        connection.rollback();
                        errorMessage = "Cancellation failed: Session not found or already cancelled.";
                    }
                } catch (NumberFormatException e) {
                    connection.rollback();
                    errorMessage = "Cancellation failed: Invalid Session ID.";
                } catch (SQLException e) {
                    connection.rollback();
                    errorMessage = "Cancellation failed due to database error: " + e.getMessage();
                    e.printStackTrace();
                } finally {
                    closeQuietly(psDelApp);
                    closeQuietly(psDelSch);
                }
            }
            action = null;
        }


        StringBuilder sqlMain = new StringBuilder("SELECT scheduleid, title, scheduledate, scheduletime, nop FROM schedule WHERE docid = ? ");
        List<Object> params = new ArrayList<>();
        params.add(doctorId);

        if (!isNullOrEmpty(filterDate)) {
            sqlMain.append(" AND scheduledate = ? ");
            params.add(filterDate);
        }
        sqlMain.append(" ORDER BY scheduledate ASC, scheduletime ASC");

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
            sessionData.put("scheduledate", rs.getString("scheduledate"));
            sessionData.put("scheduletime", rs.getString("scheduletime"));
            sessionData.put("nop", rs.getInt("nop"));
            sessionList.add(sessionData);
        }

        sessionList = sessionList.reversed();

        String today = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd"));
        action = request.getParameter("action");
        action = escapeHtml(action);
        idParam = request.getParameter("id");
        idParam = escapeHtml(idParam);
        nameParam = request.getParameter("name");
        nameParam = escapeHtml(nameParam);

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
    <title>Schedule</title>
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
                                <p class="profile-title"><%= safeSubstring(doctorName, 0, 30) %>
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
                <td class="menu-btn menu-icon-dashbord"><a href="index.jsp" class="non-style-link-menu">
                    <div><p class="menu-text">Dashboard</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-appoinment"><a href="appointment.jsp" class="non-style-link-menu">
                    <div><p class="menu-text">My Appointments</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-session menu-active menu-icon-session-active"><a href="schedule.jsp"
                                                                                               class="non-style-link-menu non-style-link-menu-active">
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
                            style="padding-top:11px;padding-bottom:11px;margin-left:20px;width:140px"><font
                            class="tn-in-text">Dashboard</font></button>
                </a></td>
                <td><p style="font-size: 23px;padding-left:12px;font-weight: 600;">My Sessions</p></td>
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
                    My Sessions (<%= sessionCount %>)</p></td>
            </tr>
            <tr>
                <td colspan="4" style="padding-top:0px;width: 100%;">
                    <center>
                        <table class="filter-container" border="0">
                            <tr>
                                <td width="10%"></td>
                                <td width="5%" style="text-align: center;">Date:</td>
                                <td width="30%">
                                    <form action="schedule.jsp" method="post">
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
                                    <th class="table-headin">Session Title</th>
                                    <th class="table-headin">Scheduled Date & Time</th>
                                    <th class="table-headin">Max num that can be booked</th>
                                    <th class="table-headin">Events</th>
                                </tr>
                                </thead>
                                <tbody>
                                <% if (sessionList.isEmpty()) { %>
                                <tr>
                                    <td colspan="4"><br><br><br><br>
                                        <center>
                                            <img src="../img/notfound.svg" width="25%"><br>
                                            <p class="heading-main12"
                                               style="margin-left: 45px;font-size:20px;color:rgb(49, 49, 49)">
                                                <%= !isNullOrEmpty(filterDate) ? "We couldn't find any sessions for the selected date!" : "No sessions available." %>
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
                                    for (Map<String, Object> sessionData : sessionList) {
                                        int scheduleid = (Integer) sessionData.get("scheduleid");
                                        String title = (String) sessionData.get("title");
                                        String scheduledate = (String) sessionData.get("scheduledate");
                                        String scheduletime = (String) sessionData.get("scheduletime");
                                        int nop = (Integer) sessionData.get("nop");
                                        String displayTime = "";
                                        try {
                                            if (scheduletime != null) {
                                                displayTime = displayTimeFormat.format(dbTimeFormat.parse(scheduletime));
                                            }
                                        } catch (ParseException e) {
                                            displayTime = safeSubstring(scheduletime, 0, 5);
                                        }
                                %>
                                <tr>
                                    <td>&nbsp;<%= safeSubstring(title, 0, 30) %>
                                    </td>
                                    <td style="text-align:center;"><%= scheduledate %> <%= displayTime %>
                                    </td>
                                    <td style="text-align:center;"><%= nop %>
                                    </td>
                                    <td>
                                        <div style="display:flex;justify-content: center;">
                                            <a href="?action=view&id=<%= scheduleid %>" class="non-style-link">
                                                <button class="btn-primary-soft btn button-icon btn-view"
                                                        style="padding-left: 40px;padding-top: 12px;padding-bottom: 12px;margin-top: 10px;">
                                                    <font class="tn-in-text">View</font></button>
                                            </a>&nbsp;&nbsp;&nbsp;
                                            <a href="?action=drop&id=<%= scheduleid %>&name=<%= URLEncoder.encode(title != null ? title : "", "UTF-8") %>"
                                               class="non-style-link">
                                                <button class="btn-primary-soft btn button-icon btn-delete"
                                                        style="padding-left: 40px;padding-top: 12px;padding-bottom: 12px;margin-top: 10px;">
                                                    <font class="tn-in-text">Cancel Session</font></button>
                                            </a>
                                        </div>
                                    </td>
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
<% if ("drop".equals(action) && !isNullOrEmpty(idParam)) { %>
<div id="popup1" class="overlay visible">
    <div class="popup">
        <center>
            <h2>Are you sure?</h2>
            <a class="close" href="schedule.jsp">&times;</a>
            <div class="content">You want to cancel this session?<br>(<%= safeSubstring(nameParam, 0, 40) %>
                ).<br><br><i>All client appointments for this session will also be cancelled.</i></div>
            <div style="display: flex;justify-content: center;">
                <a href="schedule.jsp?action=confirm-delete&deleteid=<%= idParam %>" class="non-style-link">
                    <button class="btn-primary btn"
                            style="display: flex;justify-content: center;align-items: center;margin:10px;padding:10px;">
                        <font class="tn-in-text">&nbsp;Yes&nbsp;</font></button>
                </a>&nbsp;&nbsp;&nbsp;
                <a href="schedule.jsp" class="non-style-link">
                    <button class="btn-primary-soft btn"
                            style="display: flex;justify-content: center;align-items: center;margin:10px;padding:10px;">
                        <font class="tn-in-text">&nbsp;&nbsp;No&nbsp;&nbsp;</font></button>
                </a>
            </div>
        </center>
    </div>
</div>
<% } %>

<% if ("view".equals(action) && !isNullOrEmpty(idParam)) {
    Map<String, Object> viewSessionData = null;
    List<Map<String, String>> viewPatientList = new ArrayList<>();
    String viewError = null;
    int bookedCount = 0;
    PreparedStatement psViewS = null, psViewP = null;
    ResultSet rsViewS = null, rsViewP = null;

    try {
        int scheduleId = Integer.parseInt(idParam);
        String sqlViewS = "SELECT title, scheduledate, scheduletime, nop FROM schedule WHERE scheduleid = ? AND docid = ?";
        psViewS = connection.prepareStatement(sqlViewS);
        psViewS.setInt(1, scheduleId);
        psViewS.setInt(2, doctorId);
        rsViewS = psViewS.executeQuery();

        if (rsViewS.next()) {
            viewSessionData = new HashMap<>();
            viewSessionData.put("title", rsViewS.getString("title"));
            viewSessionData.put("scheduledate", rsViewS.getString("scheduledate"));
            viewSessionData.put("scheduletime", rsViewS.getString("scheduletime"));
            viewSessionData.put("nop", rsViewS.getInt("nop"));

            String sqlViewP = "SELECT patient.pid, patient.pname, appointment.apponum, patient.ptel FROM appointment INNER JOIN patient ON patient.pid=appointment.pid WHERE appointment.scheduleid = ? ORDER BY appointment.apponum ASC";
            psViewP = connection.prepareStatement(sqlViewP);
            psViewP.setInt(1, scheduleId);
            rsViewP = psViewP.executeQuery();
            while (rsViewP.next()) {
                bookedCount++;
                Map<String, String> patientData = new HashMap<>();
                patientData.put("pid", "P-" + rsViewP.getInt("pid"));
                patientData.put("pname", rsViewP.getString("pname"));
                patientData.put("apponum", String.valueOf(rsViewP.getInt("apponum")));
                patientData.put("ptel", rsViewP.getString("ptel"));
                viewPatientList.add(patientData);
            }
        } else {
            viewError = "Session not found or access denied.";
        }

    } catch (NumberFormatException e) {
        viewError = "Invalid Session ID.";
        e.printStackTrace();
    } catch (SQLException e) {
        viewError = "Database error loading session details: " + e.getMessage();
        e.printStackTrace();
    } finally {
        closeQuietly(rsViewP);
        closeQuietly(psViewP);
        closeQuietly(rsViewS);
        closeQuietly(psViewS);
    }

    if (viewSessionData != null) {
        String displayTimeView = "";
        try {
            String rawTime = (String) viewSessionData.get("scheduletime");
            if (rawTime != null) {
                displayTimeView = displayTimeFormat.format(dbTimeFormat.parse(rawTime));
            }
        } catch (ParseException e) {
            displayTimeView = safeSubstring((String) viewSessionData.get("scheduletime"), 0, 5);
        }
        int nopView = (Integer) viewSessionData.get("nop");
%>
<div id="popup1" class="overlay visible">
    <div class="popup" style="width: 70%;">
        <center>
            <h2></h2><a class="close" href="schedule.jsp">&times;</a>
            <div class="content"></div>
            <div class="abc scroll" style="display: flex;justify-content: center;">
                <table width="80%" class="sub-table scrolldown add-doc-form-container" border="0">
                    <tr>
                        <td><p style="padding: 0;margin: 0;text-align: left;font-size: 25px;font-weight: 500;">View
                            Details.</p><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Session Title: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= viewSessionData.get("title") %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Therapist of this session: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= doctorName %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Scheduled Date: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= viewSessionData.get("scheduledate") %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Scheduled Time: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= displayTimeView %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label"><b>Clients that Already
                            registered:</b> (<%= bookedCount %>/<%= nopView %>)</label><br><br></td>
                    </tr>
                    <tr>
                        <td colspan="4">
                            <center>
                                <div class="abc scroll" style="max-height: 200px;">
                                    <table width="100%" class="sub-table scrolldown" border="0">
                                        <thead>
                                        <tr>
                                            <th class="table-headin">Client ID</th>
                                            <th class="table-headin">Client name</th>
                                            <th class="table-headin">Appointment number</th>
                                            <th class="table-headin">Client Telephone</th>
                                        </tr>
                                        </thead>
                                        <tbody>
                                        <% if (viewPatientList.isEmpty()) { %>
                                        <tr>
                                            <td colspan="4">
                                                <center><br>No clients registered yet.<br><br></center>
                                            </td>
                                        </tr>
                                        <% } else {
                                            for (Map<String, String> pData : viewPatientList) {
                                        %>
                                        <tr style="text-align:center;">
                                            <td><%= pData.get("pid") %>
                                            </td>
                                            <td style="font-weight:600;padding:10px"><%= pData.get("pname") %>
                                            </td>
                                            <td style="text-align:center;font-size:23px;font-weight:500; color: var(--btnnicetext);"><%= pData.get("apponum") %>
                                            </td>
                                            <td><%= pData.get("ptel") %>
                                            </td>
                                        </tr>
                                        <% }
                                        } %>
                                        </tbody>
                                    </table>
                                </div>
                            </center>
                        </td>
                    </tr>
                    <tr>
                        <td colspan="2"><br><a href="schedule.jsp"><input type="button" value="OK"
                                                                          class="login-btn btn-primary-soft btn"></a><br>
                        </td>
                    </tr>
                </table>
            </div>
        </center>
        <br><br>
    </div>
</div>
<% } else if ("view".equals(action)) { %>
<div id="popup1" class="overlay visible">
    <div class="popup">
        <center><h2>Error</h2><a class="close" href="schedule.jsp">&times;</a>
            <div class="content"><%= viewError != null ? viewError : "Could not load session details." %>
            </div>
            <br><a href="schedule.jsp" class="non-style-link">
                <button class="btn-primary btn">OK</button>
            </a><br><br></center>
    </div>
</div>
<% } %>
<% } %>

<%
    } catch (ClassNotFoundException e) {
        errorMessage = "Database Driver not found.";
        e.printStackTrace();
        System.out.println("<div class='info-message error'>CRITICAL ERROR: Database Driver not found. " + e.getMessage() + "</div>");
    } catch (SQLException e) {
        errorMessage = "Database Error: " + e.getMessage();
        if (!connection.getAutoCommit()) {
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
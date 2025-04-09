<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*, java.util.*, java.text.*, java.net.URLEncoder" %>
<%@ page import="java.util.Date" %>
<%!
    private void closeQuietly(AutoCloseable resource) {
        if (resource != null) {
            try {
                resource.close();
            } catch (Exception e) {
                // Ignore
            }
        }
    }

    private boolean isNullOrEmpty(String str) {
        return str == null || str.trim().isEmpty();
    }

    private String getUserErrorMessage(String errorCode) {
        if (isNullOrEmpty(errorCode)) return null;
        switch (errorCode) {
            case "1":
                return "Add Session Failed: Please fill in all required fields.";
            case "2":
                return "Add Session Failed: Could not save the session. Please try again.";
            case "3":
                return "Add Session Failed: Session date cannot be in the past.";
            case "4":
                return "Add Session Failed: Invalid number format provided (e.g., for patient count).";
            case "5":
                return "Add Session Failed: Invalid date format provided.";
            case "6":
                return "Add Session Failed: A database error occurred during creation.";
            case "session-delete-failed":
                return "Delete Failed: Could not remove the session. It might have been already deleted.";
            case "invalid_id":
                return "Operation Failed: The provided ID was invalid.";
            case "db_delete_error":
                return "Delete Failed: A database error occurred while trying to remove the session.";
            case "missing_delete_id":
                return "Delete Failed: Session ID was missing.";
            case "view_failed":
                return "Could not load session details.";
            case "invalid_view_id":
                return "Could not load details: Invalid ID.";
            case "db_view_error":
                return "Could not load details due to a database error.";
            case "db_error":
                return "A database error occurred. Please try again later.";
            default:
                return "An unexpected error occurred (" + errorCode + "). Please report this code if the issue persists.";
        }
    }
%>
<%
    String user = (String) session.getAttribute("user");
    String usertype = (String) session.getAttribute("usertype");
    if (user == null || !"a".equals(usertype)) {
        response.sendRedirect("../login.jsp?error=auth_required");
        return;
    }

    String url = System.getenv("DB_URL");
    String dbUser = System.getenv("DB_USER");
    String dbPassword = System.getenv("DB_PASSWORD");

    Connection connection = null;
    PreparedStatement preparedStatement = null;
    ResultSet resultSet = null;

    String action = request.getParameter("action");
    String idParam = request.getParameter("id");
    String nameParam = request.getParameter("name");
    String errorParam = request.getParameter("error");
    String titleParam = request.getParameter("title");

    String scheduledateFilter = request.getParameter("sheduledate");
    String docidFilter = request.getParameter("docid");

    boolean showAddPopup = "add-session".equals(action);
    boolean showAddSuccessPopup = "session-added".equals(action);
    boolean showDeleteConfirmPopup = "drop".equals(action) && idParam != null;
    boolean showDeleteSuccessPopup = "session-deleted".equals(action);
    boolean showViewPopup = "view".equals(action) && idParam != null;

    String generalUserErrorMessage = getUserErrorMessage(errorParam);

    String today = "";
    SimpleDateFormat sqlDateFormat = new SimpleDateFormat("yyyy-MM-dd");
    SimpleDateFormat displayTimeFormat = new SimpleDateFormat("HH:mm");
    String errorMessageForView = null;

    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        connection = DriverManager.getConnection(url, dbUser, dbPassword);
        connection.setAutoCommit(false);

        today = sqlDateFormat.format(new Date());

        if ("add-session-submit".equals(action) && "POST".equalsIgnoreCase(request.getMethod())) {
            String newTitle = request.getParameter("title");
            String newDocId = request.getParameter("docid");
            String newNopStr = request.getParameter("nop");
            String newDate = request.getParameter("date");
            String newTime = request.getParameter("time");

            String redirectUrl = "schedule.jsp?action=add-session&error=1";

            if (!isNullOrEmpty(newTitle) && !isNullOrEmpty(newDocId) && !isNullOrEmpty(newNopStr) && !isNullOrEmpty(newDate) && !isNullOrEmpty(newTime)) {
                try {
                    int newDocIdInt = Integer.parseInt(newDocId);
                    int newNopInt = Integer.parseInt(newNopStr);
                    Date sessionDate = sqlDateFormat.parse(newDate);

                    if (!sessionDate.before(sqlDateFormat.parse(today))) {
                        String sqlInsert = "INSERT INTO schedule (title, docid, nop, scheduledate, scheduletime) VALUES (?, ?, ?, ?, ?)";
                        preparedStatement = connection.prepareStatement(sqlInsert);
                        preparedStatement.setString(1, newTitle);
                        preparedStatement.setInt(2, newDocIdInt);
                        preparedStatement.setInt(3, newNopInt);
                        preparedStatement.setDate(4, new java.sql.Date(sessionDate.getTime()));
                        preparedStatement.setString(5, newTime + ":00");

                        int rowsAffected = preparedStatement.executeUpdate();

                        if (rowsAffected > 0) {
                            connection.commit();
                            redirectUrl = "schedule.jsp?action=session-added&title=" + URLEncoder.encode(newTitle, "UTF-8");
                        } else {
                            connection.rollback();
                            redirectUrl = "schedule.jsp?action=add-session&error=2";
                        }
                    } else {
                        redirectUrl = "schedule.jsp?action=add-session&error=3";
                    }
                } catch (NumberFormatException nfe) {
                    redirectUrl = "schedule.jsp?action=add-session&error=4";
                } catch (ParseException pe) {
                    redirectUrl = "schedule.jsp?action=add-session&error=5";
                } catch (SQLException sqle) {
                    connection.rollback();
                    sqle.printStackTrace();
                    redirectUrl = "schedule.jsp?action=add-session&error=6";
                } finally {
                    closeQuietly(preparedStatement);
                }
            }
            response.sendRedirect(redirectUrl);
            return;
        }

        if ("delete-session-confirm".equals(action) && "POST".equalsIgnoreCase(request.getMethod())) {
            String sessionIdToDelete = request.getParameter("scheduletodelete");
            String redirectUrl = "schedule.jsp";

            if (!isNullOrEmpty(sessionIdToDelete)) {
                try {
                    int scheduleIdInt = Integer.parseInt(sessionIdToDelete);

                    String sqlDeleteApp = "DELETE FROM appointment WHERE scheduleid = ?";
                    preparedStatement = connection.prepareStatement(sqlDeleteApp);
                    preparedStatement.setInt(1, scheduleIdInt);
                    preparedStatement.executeUpdate();
                    closeQuietly(preparedStatement);

                    String sqlDeleteSched = "DELETE FROM schedule WHERE scheduleid = ?";
                    preparedStatement = connection.prepareStatement(sqlDeleteSched);
                    preparedStatement.setInt(1, scheduleIdInt);
                    int rowsAffected = preparedStatement.executeUpdate();

                    if (rowsAffected > 0) {
                        connection.commit();
                        redirectUrl = "schedule.jsp?action=session-deleted";
                    } else {
                        connection.rollback();
                        redirectUrl = "schedule.jsp?error=session-delete-failed";
                    }

                } catch (NumberFormatException nfe) {
                    connection.rollback();
                    redirectUrl = "schedule.jsp?error=invalid_id";
                } catch (SQLException sqle) {
                    connection.rollback();
                    sqle.printStackTrace();
                    redirectUrl = "schedule.jsp?error=db_delete_error";
                } finally {
                    closeQuietly(preparedStatement);
                }
            } else {
                redirectUrl = "schedule.jsp?error=missing_delete_id";
            }
            response.sendRedirect(redirectUrl);
            return;
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
    <title>Schedule Management</title>
    <style>
        .popup {
            animation: transitionIn-Y-bottom 0.5s;
            z-index: 100;
            max-height: 90vh;
            overflow-y: auto;
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

        .popup .content {
            max-height: 60vh;
            overflow-y: auto;
        }

        .add-doc-form-container {
            padding: 15px;
        }

        .error-message {
            color: #D32F2F;
            background-color: #FFCDD2;
            border: 1px solid #E57373;
            padding: 12px;
            margin: 15px 45px;
            border-radius: 5px;
            text-align: center;
            font-weight: 500;
        }

        .filter-container td {
            padding: 5px 10px;
            vertical-align: middle;
        }

        .table-headin {
            background-color: #f2f2f2;
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
                            <td width="30%" style="padding-left:20px"><img src="../img/user.png" alt="User Avatar"
                                                                           width="100%" style="border-radius:50%"></td>
                            <td style="padding:0px;margin:0px;"><p class="profile-title">Administrator</p>
                                <p class="profile-subtitle"><%= user %>
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
                <td class="menu-btn menu-icon-doctor "><a href="therapists.jsp" class="non-style-link-menu ">
                    <div><p class="menu-text">Therapists</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-schedule menu-active menu-icon-schedule-active"><a href="schedule.jsp"
                                                                                                 class="non-style-link-menu non-style-link-menu-active">
                    <div><p class="menu-text">Schedules</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-appoinment"><a href="appointment.jsp" class="non-style-link-menu">
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
        <table border="0" width="100%" style=" border-spacing: 0;margin:0;padding:0;margin-top:25px; ">
            <tr>
                <td width="13%"><a href="index.jsp">
                    <button class="login-btn btn-primary-soft btn btn-icon-back"
                            style="padding-top:11px;padding-bottom:11px;margin-left:20px;width:140px">
                        <font class="tn-in-text">Dashboard</font>
                    </button>
                </a></td>
                <td><p style="font-size: 23px;padding-left:12px;font-weight: 600;">Schedule Manager</p></td>
                <td width="15%"><p style="font-size: 14px;color: #777;padding: 0;margin: 0;text-align: right;">Today's
                    Date</p>
                    <p class="heading-sub12" style="padding: 0;margin: 0;"><%= today %>
                    </p></td>
                <td width="10%">
                    <button class="btn-label" style="display: flex;justify-content: center;align-items: center;"><img
                            src="../img/calendar.svg" width="100%"></button>
                </td>
            </tr>

            <% if (generalUserErrorMessage != null && !showAddPopup) { %>
            <tr>
                <td colspan="4">
                    <div class="error-message"><%= generalUserErrorMessage %>
                    </div>
                </td>
            </tr>
            <% } %>

            <tr>
                <td colspan="4">
                    <div style="display: flex; margin-top: 20px; align-items: center;">
                        <div class="heading-main12"
                             style="margin-left: 45px;font-size:20px;color:#313131;margin-top: 5px; margin-right: 25px;">
                            Schedule a Session
                        </div>
                        <a href="?action=add-session&error=0" class="non-style-link">
                            <button class="login-btn btn-primary btn button-icon"
                                    style="background-image: url('../img/icons/add.svg');">Add a Session
                            </button>
                        </a>
                    </div>
                </td>
            </tr>

            <tr>
                <td colspan="4" style="padding-top:15px;width: 100%;">
                    <center>
                        <table class="filter-container" border="0"
                               style="background-color: #f8f8f8; border-radius: 8px; padding: 10px;">
                            <tr>
                                <td width="5%"></td>
                                <td style="text-align: right; padding-right: 5px; font-weight: 500;">Date:</td>
                                <td width="28%">
                                    <form action="schedule.jsp" method="post" id="filterForm">
                                        <input type="date" name="sheduledate" id="date"
                                               class="input-text filter-container-items" style="margin: 0;width: 95%;"
                                               value="<%= scheduledateFilter != null ? scheduledateFilter : "" %>">
                                </td>
                                <td style="text-align: right; padding-right: 5px; font-weight: 500;">Therapist:</td>
                                <td width="28%">
                                    <select name="docid" id="docid" class="box filter-container-items"
                                            style="width:95% ;height: 37px;margin: 0;">
                                        <option value="" <%
                                            if (isNullOrEmpty(docidFilter)) System.out.print("selected"); %> >
                                            All Therapists
                                        </option>
                                        <%
                                            PreparedStatement psDocFilter = null;
                                            ResultSet rsDocFilter = null;
                                            try {
                                                psDocFilter = connection.prepareStatement("SELECT docid, docname FROM doctor ORDER BY docname ASC");
                                                rsDocFilter = psDocFilter.executeQuery();
                                                while (rsDocFilter.next()) {
                                                    String docId = rsDocFilter.getString("docid");
                                                    String docName = rsDocFilter.getString("docname");
                                                    String selected = (docidFilter != null && docidFilter.equals(docId)) ? "selected" : "";
                                        %>
                                        <option value="<%= docId %>" <%= selected %>><%= docName %>
                                        </option>
                                        <%
                                            }
                                        } catch (SQLException se) {
                                            se.printStackTrace(); %>
                                        <option value="" disabled>Error loading therapists</option>
                                        <% } finally {
                                            closeQuietly(rsDocFilter);
                                            closeQuietly(psDocFilter);
                                        } %>
                                    </select>
                                </td>
                                <td width="12%">
                                    <button type="submit" name="filter"
                                            class="login-btn btn-primary-soft btn button-icon btn-filter"
                                            style="padding: 10px 15px; margin :0; width:90%">Filter
                                    </button>
                                    </form>
                                </td>
                                <td width="5%">
                                    <% if (!isNullOrEmpty(scheduledateFilter) || !isNullOrEmpty(docidFilter)) { %>
                                    <a href="schedule.jsp" style="text-decoration: none; margin-left: 0;">
                                        <button type="button" class="login-btn btn-primary-soft btn"
                                                style="padding: 10px 15px;">Clear
                                        </button>
                                    </a>
                                    <% } %>
                                </td>
                            </tr>
                        </table>
                    </center>
                </td>
            </tr>

            <%
                StringBuilder sqlMainSelect = new StringBuilder("SELECT schedule.scheduleid, schedule.title, doctor.docname, schedule.scheduledate, schedule.scheduletime, schedule.nop ");
                StringBuilder sqlMainFrom = new StringBuilder("FROM schedule INNER JOIN doctor ON schedule.docid=doctor.docid");
                StringBuilder sqlWhere = new StringBuilder();
                List<Object> params = new ArrayList<>();
                boolean whereClauseAdded = false;
                String filterErrorMessage = null;

                if (!isNullOrEmpty(scheduledateFilter)) {
                    sqlWhere.append(" WHERE schedule.scheduledate = ?");
                    params.add(scheduledateFilter);
                    whereClauseAdded = true;
                }
                if (!isNullOrEmpty(docidFilter)) {
                    sqlWhere.append(whereClauseAdded ? " AND" : " WHERE");
                    sqlWhere.append(" doctor.docid = ?");
                    try {
                        params.add(Integer.parseInt(docidFilter));
                        whereClauseAdded = true;
                    } catch (NumberFormatException e) {
                        filterErrorMessage = "Invalid Doctor ID in filter. Showing results for selected date (if any) across all doctors.";
                        docidFilter = null;
                        if (sqlWhere.toString().endsWith(" doctor.docid = ?")) {
                            if (sqlWhere.toString().contains(" AND")) {
                                sqlWhere.setLength(sqlWhere.lastIndexOf(" AND"));
                            } else {
                                sqlWhere.setLength(0);
                                whereClauseAdded = false;
                            }
                        }
                    }
                }

                String finalSql = sqlMainSelect.toString() + sqlMainFrom.toString() + sqlWhere.toString() + " ORDER BY schedule.scheduledate DESC, schedule.scheduletime ASC";
                String countSQL = "SELECT count(*) " + sqlMainFrom.toString() + sqlWhere.toString();

                int sessionCount = 0;
                PreparedStatement psCount = null;
                ResultSet rsCount = null;
                try {
                    psCount = connection.prepareStatement(countSQL);
                    for (int i = 0; i < params.size(); i++) {
                        if (params.get(i) instanceof String) psCount.setString(i + 1, (String) params.get(i));
                        else if (params.get(i) instanceof Integer) psCount.setInt(i + 1, (Integer) params.get(i));
                    }
                    rsCount = psCount.executeQuery();
                    if (rsCount.next()) sessionCount = rsCount.getInt(1);
                } catch (SQLException e) {
                    e.printStackTrace();
                } finally {
                    closeQuietly(rsCount);
                    closeQuietly(psCount);
                }
            %>
            <% if (filterErrorMessage != null) { %>
            <tr>
                <td colspan="4">
                    <div class="error-message"><%= filterErrorMessage %>
                    </div>
                </td>
            </tr>
            <% } %>
            <tr>
                <td colspan="4" style="padding-top:15px;">
                    <p class="heading-main12" style="margin-left: 45px;font-size:18px;color:#313131">
                        <%= (whereClauseAdded ? "Filtered Sessions" : "All Sessions") %> (<%= sessionCount %>)
                    </p>
                </td>
            </tr>

            <tr>
                <td colspan="4">
                    <center>
                        <div class="abc scroll">
                            <table width="93%" class="sub-table scrolldown" border="0" style="margin-top: 10px;">
                                <thead>
                                <tr style="background-color: #e0e0e0;">
                                    <th class="table-headin" style="width: 25%;">Session Title</th>
                                    <th class="table-headin" style="width: 20%;">Therapist</th>
                                    <th class="table-headin" style="width: 20%;">Scheduled Date & Time</th>
                                    <th class="table-headin" style="width: 15%; text-align:center;">Max Clients</th>
                                    <th class="table-headin" style="width: 20%; text-align:center;">Actions</th>
                                </tr>
                                </thead>
                                <tbody>
                                <%
                                    boolean dataFound = false;
                                    String listLoadingError = null;
                                    try {
                                        preparedStatement = connection.prepareStatement(finalSql);
                                        for (int i = 0; i < params.size(); i++) {
                                            if (params.get(i) instanceof String)
                                                preparedStatement.setString(i + 1, (String) params.get(i));
                                            else if (params.get(i) instanceof Integer)
                                                preparedStatement.setInt(i + 1, (Integer) params.get(i));
                                        }
                                        resultSet = preparedStatement.executeQuery();

                                        if (resultSet.isBeforeFirst()) {
                                            dataFound = true;
                                            while (resultSet.next()) {
                                                int scheduleid = resultSet.getInt("scheduleid");
                                                String title = resultSet.getString("title");
                                                String docname = resultSet.getString("docname");
                                                String scheduledate = resultSet.getString("scheduledate");
                                                String scheduletime = resultSet.getString("scheduletime");
                                                int nop = resultSet.getInt("nop");
                                                String displayTime = scheduletime;
                                                try {
                                                    displayTime = displayTimeFormat.format(new SimpleDateFormat("HH:mm:ss").parse(scheduletime));
                                                } catch (Exception e) {
                                                }
                                %>
                                <tr>
                                    <td style="padding-left: 10px;">&nbsp;<%= title %>
                                    </td>
                                    <td><%= docname %>
                                    </td>
                                    <td style="text-align:center;"><%= scheduledate %> <%= displayTime %>
                                    </td>
                                    <td style="text-align:center;"><%= nop %>
                                    </td>
                                    <td>
                                        <div style="display:flex; justify-content: center; gap: 5px;">
                                            <a href="?action=view&id=<%= scheduleid %>" class="non-style-link">
                                                <button class="btn-primary-soft btn button-icon btn-view"
                                                        style="padding-top: 8px; padding-bottom: 8px; padding-right: 15px; padding-left: 40px; margin-top: 0;">
                                                    View
                                                </button>
                                            </a>
                                            <a href="?action=drop&id=<%= scheduleid %>&name=<%= URLEncoder.encode(title, "UTF-8") %>"
                                               class="non-style-link">
                                                <button class="btn-primary-soft btn button-icon btn-delete"
                                                        style="padding-top: 8px; padding-bottom: 8px; padding-right: 15px; padding-left: 40px; margin-top: 0;">
                                                    Remove
                                                </button>
                                            </a>
                                        </div>
                                    </td>
                                </tr>
                                <%
                                            }
                                        }
                                    } catch (SQLException e) {
                                        e.printStackTrace();
                                        listLoadingError = "Error retrieving schedule list. Please try refreshing.";
                                    } finally {
                                        closeQuietly(resultSet);
                                        closeQuietly(preparedStatement);
                                    }

                                    if (!dataFound) {
                                %>
                                <tr>
                                    <td colspan="5">
                                        <br><br><br><br>
                                        <center>
                                            <img src="../img/notfound.svg" width="150px"
                                                 style="margin-bottom: 15px;"><br>
                                            <p class="heading-main12" style="font-size:18px; color:#555;">
                                                <%= (listLoadingError != null) ? listLoadingError : "No sessions found matching your criteria." %>
                                            </p>
                                            <% if (whereClauseAdded) { %>
                                            <a class="non-style-link" href="schedule.jsp">
                                                <button class="login-btn btn-primary-soft btn"
                                                        style="padding: 10px 20px; margin-top: 10px;">&nbsp; Show all
                                                    Sessions &nbsp;
                                                </button>
                                            </a>
                                            <% } %>
                                        </center>
                                        <br><br><br><br>
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

<% if (showAddPopup) { %>
<div id="popup-add-session" class="overlay visible">
    <div class="popup">
        <center>
            <a class="close" href="schedule.jsp">&times;</a>
            <div style="display: flex;justify-content: center;">
                <div class="abc">
                    <table width="80%" class="sub-table scrolldown add-doc-form-container" border="0">
                        <tr>
                            <td class="label-td" colspan="2" style="text-align:center;">
                                <% String addSessionErrorMsg = getUserErrorMessage(errorParam); %>
                                <% if (addSessionErrorMsg != null && !"0".equals(errorParam)) { %> <p
                                    class="error-message" style="margin: 0 0 15px 0;"><%= addSessionErrorMsg %>
                            </p> <% } %>
                            </td>
                        </tr>
                        <tr>
                            <td><p style="padding: 0;margin: 0;text-align: left;font-size: 25px;font-weight: 500;">Add
                                New Session</p><br></td>
                        </tr>
                        <form action="schedule.jsp?action=add-session-submit" method="POST" class="add-new-form">
                            <tr>
                                <td class="label-td" colspan="2"><%--@declare id="title"--%><label for="title"
                                                                                                   class="form-label">Session
                                    Title:</label></td>
                            </tr>
                            <tr>
                                <td colspan="2"><input type="text" name="title" class="input-text"
                                                       placeholder="e.g., Evening Consultation" required><br></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><label for="docid" class="form-label">Select
                                    Therapist:</label></td>
                            </tr>
                            <tr>
                                <td colspan="2">
                                    <select name="docid" class="box" required>
                                        <option value="" disabled selected hidden>Choose Therapist Name</option>
                                        <%
                                            PreparedStatement psDocAdd = null;
                                            ResultSet rsDocAdd = null;
                                            try {
                                                psDocAdd = connection.prepareStatement("SELECT docid, docname FROM doctor ORDER BY docname ASC");
                                                rsDocAdd = psDocAdd.executeQuery();
                                                while (rsDocAdd.next()) {
                                                    String docId = rsDocAdd.getString("docid");
                                                    String docName = rsDocAdd.getString("docname");
                                        %>
                                        <option value="<%= docId %>"><%= docName %>
                                        </option>
                                        <%
                                            }
                                        } catch (SQLException se) {
                                            se.printStackTrace(); %>
                                        <option value="" disabled>Error loading therapists</option>
                                        <% } finally {
                                            closeQuietly(rsDocAdd);
                                            closeQuietly(psDocAdd);
                                        } %>
                                    </select><br><br>
                                </td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><%--@declare id="nop"--%><label for="nop"
                                                                                                 class="form-label">Number
                                    of
                                    Clients/Appointments:</label></td>
                            </tr>
                            <tr>
                                <td colspan="2"><input type="number" name="nop" class="input-text" min="1"
                                                       placeholder="Max appointments (e.g., 15)" required><br></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><label for="date" class="form-label">Session
                                    Date:</label></td>
                            </tr>
                            <tr>
                                <td colspan="2"><input type="date" name="date" class="input-text" min="<%= today %>"
                                                       required><br></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><%--@declare id="time"--%><label for="time"
                                                                                                  class="form-label">Schedule
                                    Time:</label></td>
                            </tr>
                            <tr>
                                <td colspan="2"><input type="time" name="time" class="input-text" placeholder="Time"
                                                       required><br></td>
                            </tr>
                            <tr>
                                <td colspan="2" style="text-align:center; padding-top: 15px;">
                                    <input type="reset" value="Reset" class="login-btn btn-primary-soft btn">&nbsp;&nbsp;&nbsp;
                                    <input type="submit" value="Place Session" class="login-btn btn-primary btn"
                                           name="shedulesubmit">
                                </td>
                            </tr>
                        </form>
                    </table>
                </div>
            </div>
        </center>
        <br><br></div>
</div>
<% } %>

<% if (showAddSuccessPopup && titleParam != null) { %>
<div id="popup-add-success" class="overlay visible">
    <div class="popup">
        <center><br><br>
            <h2>Session Placed Successfully</h2><a class="close" href="schedule.jsp">&times;</a>
            <div class="content" style="font-size: 16px;">Session '<b><%= titleParam %>
            </b>' was scheduled.<br><br></div>
            <div style="display: flex;justify-content: center;"><a href="schedule.jsp" class="non-style-link">
                <button class="btn-primary btn" style="padding:10px 25px;">OK</button>
            </a></div>
            <br><br></center>
    </div>
</div>
<% } %>

<% if (showDeleteConfirmPopup && nameParam != null && idParam != null) { %>
<div id="popup-delete-confirm" class="overlay visible">
    <div class="popup">
        <center><h2>Confirm Deletion</h2><a class="close" href="schedule.jsp">&times;</a>
            <div class="content" style="font-size: 16px;">Are you sure you want to delete this
                session:<br><b>'<%= nameParam %>'</b>?<br><br><i>(This action also removes all associated appointments
                    and cannot be undone.)</i><br><br></div>
            <div style="display: flex;justify-content: center; gap: 15px;">
                <form action="schedule.jsp?action=delete-session-confirm" method="POST"><input type="hidden"
                                                                                               name="scheduletodelete"
                                                                                               value="<%= idParam %>">
                    <button type="submit" class="btn-primary-soft btn-delete btn"
                            style="padding:10px 25px; background-color: #ef5350; color: white;">Yes, Delete
                    </button>
                </form>
                <a href="schedule.jsp" class="non-style-link">
                    <button type="button" class="btn-primary-soft btn" style="padding:10px 25px;">No, Cancel</button>
                </a></div>
            <br></center>
    </div>
</div>
<% } %>

<% if (showDeleteSuccessPopup) { %>
<div id="popup-delete-success" class="overlay visible">
    <div class="popup">
        <center><br><br>
            <h2>Session Deleted</h2><a class="close" href="schedule.jsp">&times;</a>
            <div class="content" style="font-size: 16px;">The selected session and its appointments have been
                removed.<br><br></div>
            <div style="display: flex;justify-content: center;"><a href="schedule.jsp" class="non-style-link">
                <button class="btn-primary btn" style="padding:10px 25px;">OK</button>
            </a></div>
            <br><br></center>
    </div>
</div>
<% } %>

<% if (showViewPopup) {
    PreparedStatement psViewSched = null, psViewApp = null;
    ResultSet rsViewSched = null, rsViewApp = null;
    String viewTitle = "N/A", viewDocName = "N/A", viewDate = "N/A", viewTime = "N/A";
    int viewNop = 0, bookedCount = 0;
    int viewScheduleId = -1;

    try {
        viewScheduleId = Integer.parseInt(idParam);

        String sqlViewSched = "SELECT schedule.title, doctor.docname, schedule.scheduledate, schedule.scheduletime, schedule.nop FROM schedule INNER JOIN doctor ON schedule.docid=doctor.docid WHERE schedule.scheduleid = ?";
        psViewSched = connection.prepareStatement(sqlViewSched);
        psViewSched.setInt(1, viewScheduleId);
        rsViewSched = psViewSched.executeQuery();

        if (!rsViewSched.next()) {
            errorMessageForView = "Session details could not be found (ID: " + viewScheduleId + "). It might have been deleted.";
        } else {
            viewTitle = rsViewSched.getString("title");
            viewDocName = rsViewSched.getString("docname");
            viewDate = rsViewSched.getString("scheduledate");
            String rawTime = rsViewSched.getString("scheduletime");
            viewNop = rsViewSched.getInt("nop");
            try {
                viewTime = displayTimeFormat.format(new SimpleDateFormat("HH:mm:ss").parse(rawTime));
            } catch (Exception e) {
                viewTime = rawTime;
            }

            String sqlViewAppCount = "SELECT COUNT(*) as booked_count FROM appointment WHERE scheduleid = ?";
            psViewApp = connection.prepareStatement(sqlViewAppCount);
            psViewApp.setInt(1, viewScheduleId);
            rsViewApp = psViewApp.executeQuery();
            if (rsViewApp.next()) bookedCount = rsViewApp.getInt("booked_count");
            closeQuietly(rsViewApp);
            closeQuietly(psViewApp);
        }

    } catch (NumberFormatException nfe) {
        errorMessageForView = "Invalid Session ID provided.";
    } catch (SQLException sqle) {
        sqle.printStackTrace();
        errorMessageForView = "A database error occurred while loading session details.";
    } finally {
        closeQuietly(rsViewSched);
        closeQuietly(psViewSched);
        closeQuietly(rsViewApp);
        closeQuietly(psViewApp);
    }
%>
<div id="popup-view-session" class="overlay visible">
    <div class="popup" style="width: 75%; max-width: 800px;">
        <center>
            <a class="close" href="schedule.jsp">&times;</a>
            <h2 style="margin-bottom: 20px;">Session Details</h2>
            <div class="abc scroll" style="display: flex;justify-content: center;">
                <% if (errorMessageForView != null) { %>
                <div class="error-message" style="margin: 20px;"><%= errorMessageForView %>
                </div>
                <br><a href="schedule.jsp"><input type="button" value="OK"
                                                  class="login-btn btn-primary-soft btn"></a><br>
                <% } else { %>
                <table width="95%" class="sub-table scrolldown add-doc-form-container" border="0">
                    <tr>
                        <td class="label-td" width="35%">Session Title:</td>
                        <td class="label-td"><b><%= viewTitle %>
                        </b></td>
                    </tr>
                    <tr>
                        <td class="label-td">Therapist:</td>
                        <td class="label-td"><b><%= viewDocName %>
                        </b></td>
                    </tr>
                    <tr>
                        <td class="label-td">Scheduled Date:</td>
                        <td class="label-td"><b><%= viewDate %>
                        </b></td>
                    </tr>
                    <tr>
                        <td class="label-td">Scheduled Time:</td>
                        <td class="label-td"><b><%= viewTime %>
                        </b></td>
                    </tr>
                    <tr>
                        <td class="label-td">Maximum Appointments:</td>
                        <td class="label-td"><b><%= viewNop %>
                        </b></td>
                    </tr>
                    <tr>
                        <td class="label-td">Currently Booked:</td>
                        <td class="label-td" style="padding-bottom: 20px;"><b><%= bookedCount %> / <%= viewNop %>
                        </b></td>
                    </tr>

                    <tr>
                        <td colspan="2" style="border-top: 1px solid #eee; padding-top: 15px;"><p
                                style="margin: 0; text-align: left; font-size: 20px; font-weight: 500;">Registered
                            Clients List</p><br></td>
                    </tr>
                    <tr>
                        <td colspan="2">
                            <div class="abc scroll" style="max-height: 250px;">
                                <table width="100%" class="sub-table scrolldown" border="0">
                                    <thead style="position: sticky; top: 0; background-color: #f8f8f8;">
                                    <tr>
                                        <th class="table-headin">Client ID</th>
                                        <th class="table-headin">Client Name</th>
                                        <th class="table-headin">App. Num</th>
                                        <th class="table-headin">Telephone</th>
                                    </tr>
                                    </thead>
                                    <tbody>
                                    <%
                                        String patientListError = null;
                                        try {
                                            String sqlViewAppList = "SELECT patient.pid, patient.pname, appointment.apponum, patient.ptel FROM appointment INNER JOIN patient ON patient.pid=appointment.pid WHERE appointment.scheduleid = ? ORDER BY appointment.apponum ASC";
                                            psViewApp = connection.prepareStatement(sqlViewAppList);
                                            psViewApp.setInt(1, viewScheduleId);
                                            rsViewApp = psViewApp.executeQuery();
                                            if (!rsViewApp.isBeforeFirst()) {
                                    %>
                                    <tr>
                                        <td colspan='4'>
                                            <center><br>No clients registered for this session yet.<br><br></center>
                                        </td>
                                    </tr>
                                    <%
                                    } else {
                                        while (rsViewApp.next()) { %>
                                    <tr style="text-align:center;">
                                        <td>P-<%= rsViewApp.getString("pid") %>
                                        </td>
                                        <td style="text-align:left; padding-left:10px;"><%= rsViewApp.getString("pname") %>
                                        </td>
                                        <td style="font-weight:600; color: var(--btnnicetext);"><%= rsViewApp.getInt("apponum") %>
                                        </td>
                                        <td><%= rsViewApp.getString("ptel") != null ? rsViewApp.getString("ptel") : "N/A" %>
                                        </td>
                                    </tr>
                                    <% }
                                    }
                                    } catch (Exception e_app) {
                                        e_app.printStackTrace();
                                        patientListError = "Error loading patient list.";
                                    } finally {
                                        closeQuietly(rsViewApp);
                                        closeQuietly(psViewApp);
                                    }
                                        if (patientListError != null) { %>
                                    <tr>
                                        <td colspan='4' style='color:red;text-align:center;'><br><%= patientListError %>
                                            <br><br></td>
                                    </tr>
                                    <% } %>
                                    </tbody>
                                </table>
                            </div>
                        </td>
                    </tr>
                    <tr>
                        <td colspan="2" style="text-align: center; padding-top: 25px;"><a href="schedule.jsp"><input
                                type="button" value="Close" class="login-btn btn-primary-soft btn"
                                style="padding: 10px 25px;"></a><br><br></td>
                    </tr>
                </table>
                <% } %>
            </div>
        </center>
    </div>
</div>
<% } %>

<%
    } catch (ClassNotFoundException cnfe) {
        cnfe.printStackTrace();
        System.out.print("<div style='color:red; text-align:center; padding: 20px;'>A critical server configuration error occurred (Database Driver Not Found). Please contact support.</div>");
    } catch (SQLException sqle) {
        sqle.printStackTrace();
        if (connection != null) {
            try {
                connection.rollback();
            } catch (SQLException re) { /* ignore */ }
        }
        System.out.print("<div style='color:red; text-align:center; padding: 20px;'>A database connection error occurred. Please check the server logs and database status.</div>");
    } catch (Exception e) {
        e.printStackTrace();
        if (connection != null) {
            try {
                connection.rollback();
            } catch (SQLException re) { /* ignore */ }
        }
        System.out.print("<div style='color:red; text-align:center; padding: 20px;'>An unexpected error occurred. Please check the server logs.</div>");
    } finally {
        if (connection != null) {
            try {
                if (!connection.getAutoCommit()) {
                    connection.setAutoCommit(true);
                }
            } catch (SQLException se) { /* ignore */ }
            closeQuietly(connection);
        }
        closeQuietly(resultSet);
        closeQuietly(preparedStatement);
    }
%>
</body>
</html>
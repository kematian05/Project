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

    private Map<Integer, String> getSpecialtiesMap(Connection conn) throws SQLException {
        Map<Integer, String> map = new LinkedHashMap<>();
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            ps = conn.prepareStatement("SELECT id, sname FROM specialties ORDER BY sname ASC");
            rs = ps.executeQuery();
            while (rs.next()) {
                map.put(rs.getInt("id"), rs.getString("sname"));
            }
        } finally {
            closeQuietly(rs);
            closeQuietly(ps);
        }
        return map;
    }

    private String escapeHtml(String input) {
        if (input == null) return null;
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

    List<Map<String, Object>> doctorList = new ArrayList<>();
    List<Map<String, String>> doctorDatalist = new ArrayList<>();
    Map<Integer, String> specialtiesMap = new HashMap<>();
    int doctorListCount = 0;

    String searchKeyword = request.getParameter("search");
    searchKeyword = escapeHtml(searchKeyword);
    String action = request.getParameter("action");
    action = escapeHtml(action);
    String idParam = request.getParameter("id");
    idParam = escapeHtml(idParam);
    String nameParam = request.getParameter("name");
    nameParam = escapeHtml(nameParam);


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

        specialtiesMap = getSpecialtiesMap(connection);

        String sqlMain;
        List<String> queryParams = new ArrayList<>();
        if (!isNullOrEmpty(searchKeyword)) {
            sqlMain = "SELECT * FROM doctor WHERE docemail LIKE ? OR docname LIKE ? ORDER BY docname ASC";
            queryParams.add("%" + searchKeyword + "%");
            queryParams.add("%" + searchKeyword + "%");
        } else {
            sqlMain = "SELECT * FROM doctor ORDER BY docname ASC";
        }

        ps = connection.prepareStatement(sqlMain);
        for (int i = 0; i < queryParams.size(); i++) {
            ps.setString(i + 1, queryParams.get(i));
        }
        rs = ps.executeQuery();

        while (rs.next()) {
            doctorListCount++;
            Map<String, Object> doc = new HashMap<>();
            doc.put("docid", rs.getInt("docid"));
            doc.put("docname", rs.getString("docname"));
            doc.put("docemail", rs.getString("docemail"));
            doc.put("specialties", rs.getInt("specialties"));
            doc.put("docnic", rs.getString("docnic"));
            doc.put("doctel", rs.getString("doctel"));
            doctorList.add(doc);

            Map<String, String> item = new HashMap<>();
            item.put("name", rs.getString("docname"));
            item.put("email", rs.getString("docemail"));
            doctorDatalist.add(item);
        }
        closeQuietly(rs);
        closeQuietly(ps);

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
    <title>Therapists</title>
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
        <td class="menu-btn menu-icon-doctor menu-active menu-icon-doctor-active"><a href="therapists.jsp"
                                                                                     class="non-style-link-menu non-style-link-menu-active">
            <div><p class="menu-text">All Therapists</p>
        </a>
</div>
</td></tr>
<tr class="menu-row">
    <td class="menu-btn menu-icon-session"><a href="schedule.jsp" class="non-style-link-menu">
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
                <form action="therapists.jsp" method="post" class="header-search">
                    <input type="search" name="search" class="input-text header-searchbar"
                           placeholder="Search Therapist name or Email" list="doctors"
                           value="<%= searchKeyword != null ? searchKeyword : "" %>">&nbsp;&nbsp;
                    <datalist id="doctors">
                        <% for (Map<String, String> item : doctorDatalist) { %>
                        <option value="<%= item.get("name") %>"><%= item.get("email") %>
                        </option>
                        <option value="<%= item.get("email") %>"><%= item.get("name") %>
                        </option>
                        <% } %>
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
            <td colspan="4" style="padding-top:10px;"><p class="heading-main12"
                                                         style="margin-left: 45px;font-size:18px;color:rgb(49, 49, 49)">
                All Therapists (<%= doctorListCount %>)</p></td>
        </tr>
        <tr>
            <td colspan="4">
                <center>
                    <div class="abc scroll">
                        <table width="93%" class="sub-table scrolldown" border="0">
                            <thead>
                            <tr>
                                <th class="table-headin">Therapist Name</th>
                                <th class="table-headin">Email</th>
                                <th class="table-headin">Specialties</th>
                                <th class="table-headin">Events</th>
                            </tr>
                            </thead>
                            <tbody>
                            <% if (doctorList.isEmpty()) { %>
                            <tr>
                                <td colspan="4"><br><br><br><br>
                                    <center>
                                        <img src="../img/notfound.svg" width="25%"><br>
                                        <p class="heading-main12"
                                           style="margin-left: 45px;font-size:20px;color:rgb(49, 49, 49)">
                                            <%= !isNullOrEmpty(searchKeyword) ? "We couldn't find anything related to your keywords!" : "No therapists found." %>
                                        </p>
                                        <a class="non-style-link" href="therapists.jsp">
                                            <button class="login-btn btn-primary-soft btn"
                                                    style="display: flex;justify-content: center;align-items: center;margin-left:20px;">
                                                &nbsp; Show all Therapists &nbsp;
                                            </button>
                                        </a>
                                    </center>
                                    <br><br><br><br></td>
                            </tr>
                            <% } else {
                                for (Map<String, Object> doc : doctorList) {
                                    int docid = (Integer) doc.get("docid");
                                    String docName = (String) doc.get("docname");
                                    String docEmail = (String) doc.get("docemail");
                                    int specId = (Integer) doc.get("specialties");
                                    String specName = specialtiesMap.getOrDefault(specId, "Unknown");
                            %>
                            <tr>
                                <td>&nbsp;<%= safeSubstring(docName, 0, 30) %>
                                </td>
                                <td><%= safeSubstring(docEmail, 0, 30) %>
                                </td>
                                <td><%= safeSubstring(specName, 0, 20) %>
                                </td>
                                <td>
                                    <div style="display:flex;justify-content: center;">
                                        <a href="?action=view&id=<%= docid %>" class="non-style-link">
                                            <button class="btn-primary-soft btn button-icon btn-view"
                                                    style="padding-left: 40px;padding-top: 12px;padding-bottom: 12px;margin-top: 10px;">
                                                <font class="tn-in-text">View</font></button>
                                        </a>&nbsp;&nbsp;&nbsp;
                                        <a href="?action=session&id=<%= docid %>&name=<%= URLEncoder.encode(docName != null ? docName : "", "UTF-8") %>"
                                           class="non-style-link">
                                            <button class="btn-primary-soft btn button-icon menu-icon-session-active"
                                                    style="padding-left: 40px;padding-top: 12px;padding-bottom: 12px;margin-top: 10px;">
                                                <font class="tn-in-text">Sessions</font></button>
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
<%
    boolean showViewPopup = "view".equals(action) && !isNullOrEmpty(idParam);
    boolean showSessionConfirmPopup = "session".equals(action) && !isNullOrEmpty(idParam);
%>

<% if (showViewPopup) {
    Map<String, String> viewData = null;
    String viewError = null;
    try {
        int docIdView = Integer.parseInt(idParam);
        ps = connection.prepareStatement("SELECT * FROM doctor WHERE docid = ?");
        ps.setInt(1, docIdView);
        rs = ps.executeQuery();
        if (rs.next()) {
            viewData = new HashMap<>();
            viewData.put("name", rs.getString("docname"));
            viewData.put("email", rs.getString("docemail"));
            viewData.put("nic", rs.getString("docnic"));
            viewData.put("tel", rs.getString("doctel"));
            int specId = rs.getInt("specialties");
            viewData.put("specName", specialtiesMap.getOrDefault(specId, "Unknown"));
        } else {
            viewError = "Therapist details not found.";
        }
    } catch (NumberFormatException e) {
        viewError = "Invalid Therapist ID.";
        e.printStackTrace();
    } catch (SQLException e) {
        viewError = "Error loading therapist details: " + e.getMessage();
        e.printStackTrace();
    } finally {
        closeQuietly(rs);
        closeQuietly(ps);
    }

    if (viewData != null) {
%>
<div id="popup1" class="overlay visible">
    <div class="popup">
        <center>
            <h2></h2><a class="close" href="therapists.jsp">&times;</a>
            <div class="content">PsychCare<br></div>
            <div style="display: flex;justify-content: center;">
                <table width="80%" class="sub-table scrolldown add-doc-form-container" border="0">
                    <tr>
                        <td><p style="padding: 0;margin: 0;text-align: left;font-size: 25px;font-weight: 500;">View
                            Details.</p><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Name: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= viewData.get("name") %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Email: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= viewData.get("email") %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">NIC: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= viewData.get("nic") %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Telephone: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= viewData.get("tel") %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Specialty: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= viewData.get("specName") %><br><br></td>
                    </tr>
                    <tr>
                        <td colspan="2"><a href="therapists.jsp"><input type="button" value="OK"
                                                                        class="login-btn btn-primary-soft btn"></a></td>
                    </tr>
                </table>
            </div>
        </center>
        <br><br>
    </div>
</div>
<% } else if (showViewPopup) { %>
<div id="popup1" class="overlay visible">
    <div class="popup">
        <center><h2>Error</h2><a class="close" href="therapists.jsp">&times;</a>
            <div class="content"><%= viewError != null ? viewError : "Could not load therapist details." %>
            </div>
            <br><a href="therapists.jsp" class="non-style-link">
                <button class="btn-primary btn">OK</button>
            </a><br><br></center>
    </div>
</div>
<% } %>
<% } %>

<% if (showSessionConfirmPopup) { %>
<div id="popup1" class="overlay visible">
    <div class="popup">
        <center>
            <h2>Redirect to Therapist's Sessions?</h2>
            <a class="close" href="therapists.jsp">&times;</a>
            <div class="content">You want to view all sessions by <br><%= safeSubstring(nameParam, 0, 40) %>.</div>
            <form action="schedule.jsp" method="post" style="display: inline-block;">
                <input type="hidden" name="search" value="<%= nameParam %>">
                <div style="display: flex;justify-content:center;margin-top:3%;margin-bottom:3%;">
                    <input type="submit" value="Yes" class="btn-primary btn" style="margin:5px; padding: 10px 25px;">
                    <a href="therapists.jsp" class="non-style-link">
                        <button type="button" class="btn-primary-soft btn" style="margin:5px; padding: 10px 25px;">No
                        </button>
                    </a>
                </div>
            </form>
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
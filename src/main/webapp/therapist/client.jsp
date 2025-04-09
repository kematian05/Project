<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*, java.util.*, java.text.*, java.time.LocalDate, java.time.format.DateTimeFormatter" %>
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

    String selectType = "My";
    String currentFilterText = "My Clients Only";
    List<Map<String, Object>> patientList = new ArrayList<>();
    List<Map<String, String>> patientDatalist = new ArrayList<>();
    int patientListCount = 0;

    String searchKeyword = request.getParameter("search12");
    String filterTypeParam = request.getParameter("showonly");
    String searchSubmit = request.getParameter("search");

    boolean isSearch = !isNullOrEmpty(searchKeyword) && searchSubmit != null;
    boolean isFilter = !isNullOrEmpty(filterTypeParam);

    String action = request.getParameter("action");
    String idParam = request.getParameter("id");

    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        connection = DriverManager.getConnection(url, dbUser, dbPassword);

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

        StringBuilder sqlBase = new StringBuilder("SELECT DISTINCT patient.pid, patient.pname, patient.pemail, patient.pnic, patient.pdob, patient.ptel, patient.paddress FROM patient");
        StringBuilder sqlWhere = new StringBuilder();
        List<Object> params = new ArrayList<>();
        boolean whereAdded = false;

        if (isFilter && "all".equals(filterTypeParam)) {
            selectType = "All";
            currentFilterText = "All clients";
        } else {
            selectType = "My";
            currentFilterText = "My clients Only";
            sqlBase.append(" INNER JOIN appointment ON patient.pid = appointment.pid INNER JOIN schedule ON appointment.scheduleid = schedule.scheduleid");
            sqlWhere.append(" WHERE schedule.docid = ?");
            params.add(doctorId);
            whereAdded = true;
        }

        if (isSearch) {
            sqlWhere.append(whereAdded ? " AND" : " WHERE");
            sqlWhere.append(" (patient.pemail LIKE ? OR patient.pname LIKE ?)");
            params.add("%" + searchKeyword + "%");
            params.add("%" + searchKeyword + "%");
        }

        String sqlMain = sqlBase.toString() + sqlWhere.toString() + " ORDER BY patient.pname ASC";

        ps = connection.prepareStatement(sqlMain);
        for (int i = 0; i < params.size(); i++) {
            ps.setObject(i + 1, params.get(i));
        }
        rs = ps.executeQuery();

        while (rs.next()) {
            patientListCount++;
            Map<String, Object> patient = new HashMap<>();
            patient.put("pid", rs.getInt("pid"));
            patient.put("pname", rs.getString("pname"));
            patient.put("pemail", rs.getString("pemail"));
            patient.put("pnic", rs.getString("pnic"));
            patient.put("pdob", rs.getString("pdob"));
            patient.put("ptel", rs.getString("ptel"));
            patient.put("paddress", rs.getString("paddress"));
            patientList.add(patient);

            Map<String, String> datalistItem = new HashMap<>();
            datalistItem.put("name", rs.getString("pname"));
            datalistItem.put("email", rs.getString("pemail"));
            patientDatalist.add(datalistItem);
        }
        closeQuietly(rs);
        closeQuietly(ps);

        String today = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd"));

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
    <title>Clients</title>
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
                <td class="menu-btn menu-icon-session"><a href="schedule.jsp" class="non-style-link-menu">
                    <div><p class="menu-text">My Sessions</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-patient menu-active menu-icon-patient-active"><a href="client.jsp"
                                                                                               class="non-style-link-menu non-style-link-menu-active">
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
                <td>
                    <form action="client.jsp" method="post" class="header-search">
                        <input type="search" name="search12" class="input-text header-searchbar"
                               placeholder="Search Client name or Email" list="patient"
                               value="<%= searchKeyword != null ? searchKeyword : "" %>">&nbsp;&nbsp;
                        <datalist id="patient">
                            <% for (Map<String, String> item : patientDatalist) { %>
                            <option value="<%= item.get("name") %>"><%= item.get("email") %>
                            </option>
                            <option value="<%= item.get("email") %>"><%= item.get("name") %>
                            </option>
                            <% } %>
                        </datalist>
                        <input type="Submit" value="Search" name="search" class="login-btn btn-primary btn"
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
            <tr>
                <td colspan="4" style="padding-top:10px;">
                    <p class="heading-main12"
                       style="margin-left: 45px;font-size:18px;color:rgb(49, 49, 49)"><%= selectType %> Clients
                        (<%= patientListCount %>)</p>
                </td>
            </tr>
            <tr>
                <td colspan="4" style="padding-top:0px;width: 100%;">
                    <center>
                        <table class="filter-container" border="0">
                            <form action="client.jsp" method="post">
                                <td style="text-align: right;">Show Details About : &nbsp;</td>
                                <td width="30%">
                                    <select name="showonly" id="showonly" class="box filter-container-items"
                                            style="width:90% ;height: 37px;margin: 0;">
                                        <option value="" disabled selected hidden><%= currentFilterText %>
                                        </option>
                                        <br/>
                                        <option value="my">My Clients Only</option>
                                        <br/>
                                        <option value="all">All Clients</option>
                                        <br/>
                                    </select>
                                </td>
                                <td width="12%">
                                    <input type="submit" name="filter" value=" Filter"
                                           class=" btn-primary-soft btn button-icon btn-filter"
                                           style="padding: 15px; margin :0;width:100%">
                            </form>
                </td>
        </table>
        </center>
        </td>
        </tr>
        <tr>
            <td colspan="4">
                <center>
                    <div class="abc scroll">
                        <table width="93%" class="sub-table scrolldown" style="border-spacing:0;">
                            <thead>
                            <tr>
                                <th class="table-headin">Name</th>
                                <th class="table-headin">NIC</th>
                                <th class="table-headin">Telephone</th>
                                <th class="table-headin">Email</th>
                                <th class="table-headin">Date of Birth</th>
                                <th class="table-headin">Events</th>
                            </tr>
                            </thead>
                            <tbody>
                            <% if (patientList.isEmpty()) { %>
                            <tr>
                                <td colspan="6"><br><br><br><br>
                                    <center>
                                        <img src="../img/notfound.svg" width="25%"><br>
                                        <p class="heading-main12"
                                           style="margin-left: 45px;font-size:20px;color:rgb(49, 49, 49)">
                                            <%= isSearch ? "We couldn't find anything related to your keywords!" : "No clients found matching the criteria." %>
                                        </p>
                                        <a class="non-style-link" href="client.jsp">
                                            <button class="login-btn btn-primary-soft btn"
                                                    style="display: flex;justify-content: center;align-items: center;margin-left:20px;">
                                                &nbsp; Show My clients &nbsp;
                                            </button>
                                        </a>
                                    </center>
                                    <br><br><br><br></td>
                            </tr>
                            <% } else {
                                for (Map<String, Object> patient : patientList) {
                                    int pid = (Integer) patient.get("pid");
                                    String name = (String) patient.get("pname");
                                    String email = (String) patient.get("pemail");
                                    String nic = (String) patient.get("pnic");
                                    String dob = (String) patient.get("pdob");
                                    String tel = (String) patient.get("ptel");
                            %>
                            <tr>
                                <td>&nbsp;<%= safeSubstring(name, 0, 35) %>
                                </td>
                                <td><%= safeSubstring(nic, 0, 12) %>
                                </td>
                                <td><%= safeSubstring(tel, 0, 10) %>
                                </td>
                                <td><%= safeSubstring(email, 0, 20) %>
                                </td>
                                <td><%= safeSubstring(dob, 0, 10) %>
                                </td>
                                <td>
                                    <div style="display:flex;justify-content: center;">
                                        <a href="?action=view&id=<%= pid %>" class="non-style-link">
                                            <button class="btn-primary-soft btn button-icon btn-view"
                                                    style="padding-left: 40px;padding-top: 12px;padding-bottom: 12px;margin-top: 10px;">
                                                <font class="tn-in-text">View</font></button>
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
<% if ("view".equals(action) && !isNullOrEmpty(idParam)) {
    Map<String, Object> viewData = null;
    try {
        int patientId = Integer.parseInt(idParam);
        ps = connection.prepareStatement("SELECT * FROM patient WHERE pid = ?");
        ps.setInt(1, patientId);
        rs = ps.executeQuery();
        if (rs.next()) {
            viewData = new HashMap<>();
            viewData.put("pid", rs.getInt("pid"));
            viewData.put("pname", rs.getString("pname"));
            viewData.put("pemail", rs.getString("pemail"));
            viewData.put("pnic", rs.getString("pnic"));
            viewData.put("pdob", rs.getString("pdob"));
            viewData.put("ptel", rs.getString("ptel"));
            viewData.put("paddress", rs.getString("paddress"));
        }
        closeQuietly(rs);
        closeQuietly(ps);
    } catch (NumberFormatException e) {
        errorMessage = "Invalid Patient ID for view.";
        e.printStackTrace();
    } catch (SQLException e) {
        errorMessage = "Error loading patient details: " + e.getMessage();
        e.printStackTrace();
    }

    if (viewData != null) {
%>
<div id="popup1" class="overlay visible">
    <div class="popup">
        <center>
            <a class="close" href="client.jsp">&times;</a>
            <div class="content"></div>
            <div style="display: flex;justify-content: center;">
                <table width="80%" class="sub-table scrolldown add-doc-form-container" border="0">
                    <tr>
                        <td><p style="padding: 0;margin: 0;text-align: left;font-size: 25px;font-weight: 500;">View
                            Details.</p><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Client ID: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2">P-<%= viewData.get("pid") %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Name: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= viewData.get("pname") %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Email: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= viewData.get("pemail") %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">NIC: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= viewData.get("pnic") %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Telephone: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= viewData.get("ptel") %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Address: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= viewData.get("paddress") %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Date of Birth: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= viewData.get("pdob") %><br><br></td>
                    </tr>
                    <tr>
                        <td colspan="2"><a href="client.jsp"><input type="button" value="OK"
                                                                    class="login-btn btn-primary-soft btn"></a></td>
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
        <center><h2>Error</h2><a class="close" href="client.jsp">&times;</a>
            <div class="content"><%= errorMessage != null ? errorMessage : "Could not load client details." %>
            </div>
            <br><a href="client.jsp" class="non-style-link">
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
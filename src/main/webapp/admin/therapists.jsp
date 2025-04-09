<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*, java.util.Date, java.text.SimpleDateFormat, java.util.Calendar" %>
<%@ page import="com.google.common.hash.Hashing" %>
<%@ page import="java.nio.charset.StandardCharsets" %>
<%@ page import="org.apache.commons.text.StringEscapeUtils" %>
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
    private String escapeHtml(String input) {
        if (input == null) return "";
        return StringEscapeUtils.escapeHtml4(input);
    }
%>
<%
    String user = (String) session.getAttribute("user");
    String usertype = (String) session.getAttribute("usertype");
    if (user == null || !"a".equals(usertype)) {
        response.sendRedirect("../login.jsp");
        return;
    }

    String url = System.getenv("DB_URL");
    String dbUser = System.getenv("DB_USER");
    String dbPassword = System.getenv("DB_PASSWORD");

    Connection connection = null;
    PreparedStatement preparedStatement = null;
    ResultSet resultSet = null;
    PreparedStatement psSpecialty = null;
    ResultSet rsSpecialty = null;

    String[] errorlist = {
            "", // 0
            "<label class='form-label' style='color:rgb(255, 62, 62);text-align:center;'>Account already exists for this Email address.</label>", // 1
            "<label class='form-label' style='color:rgb(255, 62, 62);text-align:center;'>Password Confirmation Error! Please reconfirm password.</label>", // 2
            "<label class='form-label' style='color:rgb(255, 62, 62);text-align:center;'>An unexpected error occurred.</label>", // 3
            "", // 4 - Success Flag
            "<label class='form-label' style='color:rgb(255, 62, 62);text-align:center;'>Operation failed. Please try again.</label>" // 5
    };

    String action = request.getParameter("action");
    action = escapeHtml(action);
    String id = request.getParameter("id");
    id = escapeHtml(id);
    String currentError = request.getParameter("error");
    currentError = escapeHtml(currentError);

    String editTherapistId = null;
    String viewTherapistId = null;
    String showAddPopupWithError = null;
    boolean showAddSuccessPopup = false;
    boolean showEditSuccessPopup = false;

    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        connection = DriverManager.getConnection(url, dbUser, dbPassword);

        SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd");
        String today = dateFormat.format(new Date());

        if ("add".equals(action) && request.getMethod().equalsIgnoreCase("POST")) {
            String name = request.getParameter("name");
            name = escapeHtml(name);
            String nic = request.getParameter("nic");
            nic = escapeHtml(nic);
            String spec = request.getParameter("spec");
            spec = escapeHtml(spec);
            String email = request.getParameter("email");
            email = escapeHtml(email);
            String tele = request.getParameter("Tele");
            tele = escapeHtml(tele);
            String password = request.getParameter("password");
            password = escapeHtml(password);
            String cpassword = request.getParameter("cpassword");
            cpassword = escapeHtml(cpassword);
            String errorCode = "5";

            if (password != null && password.equals(cpassword)) {
                preparedStatement = connection.prepareStatement("SELECT * FROM webuser WHERE email = ?");
                preparedStatement.setString(1, email);
                resultSet = preparedStatement.executeQuery();

                if (resultSet.next()) {
                    errorCode = "1";
                } else {
                    closeQuietly(resultSet);
                    closeQuietly(preparedStatement);
                    String hashedPassword = Hashing.sha256().hashString(password, StandardCharsets.UTF_8).toString();
                    preparedStatement = connection.prepareStatement("INSERT INTO doctor (docemail, docname, docpassword, docnic, doctel, specialties) VALUES (?, ?, ?, ?, ?, ?)");
                    preparedStatement.setString(1, email);
                    preparedStatement.setString(2, name);
                    preparedStatement.setString(3, hashedPassword);
                    preparedStatement.setString(4, nic);
                    preparedStatement.setString(5, tele);
                    preparedStatement.setString(6, spec);
                    int doctorRowsAffected = preparedStatement.executeUpdate();
                    closeQuietly(preparedStatement);

                    if (doctorRowsAffected > 0) {
                        preparedStatement = connection.prepareStatement("INSERT INTO webuser VALUES (?, 'd')");
                        preparedStatement.setString(1, email);
                        int webuserRowsAffected = preparedStatement.executeUpdate();
                        closeQuietly(preparedStatement);
                        if (webuserRowsAffected > 0) {
                            errorCode = "4";
                        } else {
                            errorCode = "5";
                        }
                    } else {
                        errorCode = "5";
                    }
                }
                closeQuietly(resultSet);
                closeQuietly(preparedStatement);
            } else {
                errorCode = "2";
            }

            if ("4".equals(errorCode)) {
                response.sendRedirect("therapists.jsp?action=add_success");
            } else {
                response.sendRedirect("therapists.jsp?action=add&error=" + errorCode);
            }
            return;
        }

        if ("edit".equals(action) && request.getMethod().equalsIgnoreCase("POST") && escapeHtml(request.getParameter("id00")) != null) {
            String editId = request.getParameter("id00");
            editId = escapeHtml(editId);
            String name = request.getParameter("name");
            name = escapeHtml(name);
            String nic = request.getParameter("nic");
            nic = escapeHtml(nic);
            String oldemail = request.getParameter("oldemail");
            oldemail = escapeHtml(oldemail);
            String spec = request.getParameter("spec");
            spec = escapeHtml(spec);
            String email = request.getParameter("email");
            email = escapeHtml(email);
            String tele = request.getParameter("Tele");
            tele = escapeHtml(tele);
            String password = request.getParameter("password");
            password = escapeHtml(password);
            String cpassword = request.getParameter("cpassword");
            cpassword = escapeHtml(cpassword);
            String errorCode = "5";

            if (password != null && password.equals(cpassword)) {
                boolean emailConflict = false;
                if (!email.equals(oldemail)) {
                    preparedStatement = connection.prepareStatement("SELECT docid FROM doctor WHERE docemail = ? AND docid != ?");
                    preparedStatement.setString(1, email);
                    preparedStatement.setString(2, editId);
                    resultSet = preparedStatement.executeQuery();
                    if (resultSet.next()) {
                        emailConflict = true;
                    }
                    closeQuietly(resultSet);
                    closeQuietly(preparedStatement);
                }

                if (emailConflict) {
                    errorCode = "1";
                } else {
                    String hashedPassword = Hashing.sha256().hashString(password, StandardCharsets.UTF_8).toString();
                    preparedStatement = connection.prepareStatement("UPDATE doctor SET docemail = ?, docname = ?, docpassword = ?, docnic = ?, doctel = ?, specialties = ? WHERE docid = ?");
                    preparedStatement.setString(1, email);
                    preparedStatement.setString(2, name);
                    preparedStatement.setString(3, hashedPassword);
                    preparedStatement.setString(4, nic);
                    preparedStatement.setString(5, tele);
                    preparedStatement.setString(6, spec);
                    preparedStatement.setString(7, editId);
                    int doctorRowsAffected = preparedStatement.executeUpdate();
                    closeQuietly(preparedStatement);

                    if (doctorRowsAffected > 0) {
                        if (!email.equals(oldemail)) {
                            preparedStatement = connection.prepareStatement("UPDATE webuser SET email = ? WHERE email = ?");
                            preparedStatement.setString(1, email);
                            preparedStatement.setString(2, oldemail);
                            int webuserRowsAffected = preparedStatement.executeUpdate();
                            closeQuietly(preparedStatement);
                            if (webuserRowsAffected > 0) {
                                errorCode = "4";
                            } else {
                                errorCode = "5";
                            }
                        } else {
                            errorCode = "4";
                        }
                    } else {
                        errorCode = "5";
                    }
                }
            } else {
                errorCode = "2";
            }

            if ("4".equals(errorCode)) {
                response.sendRedirect("therapists.jsp?action=edit_success");
            } else {
                response.sendRedirect("therapists.jsp?action=edit&id=" + editId + "&error=" + errorCode);
            }
            return;
        }

        if ("drop".equals(action) && id != null) {
            preparedStatement = connection.prepareStatement("SELECT docemail FROM doctor WHERE docid = ?");
            preparedStatement.setString(1, id);
            resultSet = preparedStatement.executeQuery();
            String emailToDelete = null;
            if (resultSet.next()) {
                emailToDelete = resultSet.getString("docemail");
            }
            closeQuietly(resultSet);
            closeQuietly(preparedStatement);

            if (emailToDelete != null) {
                preparedStatement = connection.prepareStatement("DELETE FROM webuser WHERE email = ?");
                preparedStatement.setString(1, emailToDelete);
                preparedStatement.executeUpdate();
                closeQuietly(preparedStatement);

                preparedStatement = connection.prepareStatement("DELETE FROM doctor WHERE docid = ?");
                preparedStatement.setString(1, id);
                preparedStatement.executeUpdate();
                closeQuietly(preparedStatement);
            }
            response.sendRedirect("therapists.jsp");
            return;
        }

        if ("add".equals(action)) {
            if (currentError != null && !"4".equals(currentError)) {
                showAddPopupWithError = currentError;
            } else if (currentError == null) {
                showAddPopupWithError = "0";
            }
        } else if ("add_success".equals(action)) {
            showAddSuccessPopup = true;
        } else if ("edit".equals(action) && id != null) {
            editTherapistId = id;
        } else if ("edit_success".equals(action)) {
            showEditSuccessPopup = true;
        } else if ("view".equals(action) && id != null) {
            viewTherapistId = id;
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
    <title>Therapists</title>
    <style>
        .popup {
            animation: transitionIn-Y-bottom 0.5s;
            z-index: 100;
            max-height: 90vh;
            overflow-y: auto;
        }

        .overlay {
            position: fixed;
            top: 0;
            bottom: 0;
            left: 0;
            right: 0;
            background: rgba(0, 0, 0, 0.7);
            transition: opacity 500ms;
            visibility: visible;
            opacity: 1;
            z-index: 99;
        }

        .overlay:not(.visible) {
            visibility: hidden;
            opacity: 0;
        }

        .popup .content {
            max-height: 60vh;
            overflow-y: auto;
        }

        .add-doc-form-container {
            padding: 15px;
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
                                <p class="profile-title">Administrator</p>
                                <p class="profile-subtitle"><%= (user != null) ? user : "admin@example.com" %>
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
                <td class="menu-btn menu-icon-dashbord"><a href="index.jsp" class="non-style-link-menu">
                    <div><p class="menu-text">Dashboard</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-doctor menu-active menu-icon-doctor-active"><a href="therapists.jsp"
                                                                                             class="non-style-link-menu non-style-link-menu-active">
                    <div><p class="menu-text">Therapists</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-schedule"><a href="schedule.jsp" class="non-style-link-menu">
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
                <td width="13%">
                    <a href="index.jsp">
                        <button class="login-btn btn-primary-soft btn btn-icon-back"
                                style="padding-top:11px;padding-bottom:11px;margin-left:20px;width:140px"><font
                                class="tn-in-text">Dashboard</font></button>
                    </a>
                </td>
                <td>
                    <form action="therapists.jsp" method="post" class="header-search">
                        <input type="search" name="search" class="input-text header-searchbar"
                               placeholder="Search Therapist name or Email" list="therapists"
                               value="<%= escapeHtml(request.getParameter("search")) != null ? escapeHtml(request.getParameter("search")) : "" %>">&nbsp;&nbsp;
                        <datalist id="therapists">
                            <%
                                PreparedStatement psSearch = null;
                                ResultSet rsSearch = null;
                                try {
                                    psSearch = connection.prepareStatement("SELECT docname, docemail FROM doctor ORDER BY docname ASC");
                                    rsSearch = psSearch.executeQuery();
                                    while (rsSearch.next()) {
                                        String therapistName = rsSearch.getString("docname");
                                        String therapistEmail = rsSearch.getString("docemail");
                            %>
                            <option value="<%= therapistName %>"></option>
                            <option value="<%= therapistEmail %>"></option>
                            <% }
                            } catch (SQLException se) {
                            } finally {
                                closeQuietly(rsSearch);
                                closeQuietly(psSearch);
                            } %>
                        </datalist>
                        <input type="Submit" value="Search" class="login-btn btn-primary btn"
                               style="padding-left: 25px;padding-right: 25px;padding-top: 10px;padding-bottom: 10px;">
                        <% if (escapeHtml(request.getParameter("search")) != null) { %>
                        <a href="therapists.jsp" style="text-decoration: none;">
                            <button type="button" class="login-btn btn-primary-soft btn"
                                    style="margin-left: 10px; padding: 10px 15px;">Clear
                            </button>
                        </a>
                        <% } %>
                    </form>
                </td>
                <td width="15%"><p
                        style="font-size: 14px;color: rgb(119, 119, 119);padding: 0;margin: 0;text-align: right;">
                    Today's Date</p>
                    <p class="heading-sub12" style="padding: 0;margin: 0;"><%= today %>
                    </p></td>
                <td width="10%">
                    <button class="btn-label" style="display: flex;justify-content: center;align-items: center;"><img
                            src="../img/calendar.svg" width="100%"></button>
                </td>
            </tr>
            <tr>
                <td colspan="2" style="padding-top:30px;"><p class="heading-main12"
                                                             style="margin-left: 45px;font-size:20px;color:rgb(49, 49, 49)">
                    Manage Therapists</p></td>
                <td colspan="2" style="text-align: right; padding-right: 35px;"><a href="?action=add&error=0"
                                                                                   class="non-style-link">
                    <button class="login-btn btn-primary btn button-icon"
                            style="display: inline-flex;justify-content: center;align-items: center;background-image: url('../img/icons/add.svg');">
                        Add New Therapist
                    </button>
                </a></td>
            </tr>
            <tr>
                <td colspan="4" style="padding-top:10px;">
                    <%
                        String searchKeyword = request.getParameter("search");
                        searchKeyword = escapeHtml(searchKeyword);
                        String sqlCount;
                        int therapistCount = 0;
                        PreparedStatement psCount = null;
                        ResultSet rsCount = null;
                        try {
                            if (searchKeyword != null && !searchKeyword.trim().isEmpty()) {
                                sqlCount = "SELECT COUNT(*) FROM doctor WHERE docemail LIKE ? OR docname LIKE ?";
                                psCount = connection.prepareStatement(sqlCount);
                                psCount.setString(1, "%" + searchKeyword + "%");
                                psCount.setString(2, "%" + searchKeyword + "%");
                            } else {
                                sqlCount = "SELECT COUNT(*) FROM doctor";
                                psCount = connection.prepareStatement(sqlCount);
                            }
                            rsCount = psCount.executeQuery();
                            if (rsCount.next()) {
                                therapistCount = rsCount.getInt(1);
                            }
                        } catch (SQLException se) {
                        } finally {
                            closeQuietly(rsCount);
                            closeQuietly(psCount);
                        }
                    %>
                    <p class="heading-main12" style="margin-left: 45px;font-size:18px;color:rgb(49, 49, 49)">All
                        Therapists (<%= therapistCount %>)</p>
                </td>
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
                                    <th class="table-headin" style="text-align:center;">Events</th>
                                </tr>
                                </thead>
                                <tbody>
                                <%
                                    String sqlMain;
                                    if (searchKeyword != null && !searchKeyword.trim().isEmpty()) {
                                        sqlMain = "SELECT d.*, s.sname FROM doctor d LEFT JOIN specialties s ON d.specialties = s.id WHERE d.docemail LIKE ? OR d.docname LIKE ? ORDER BY d.docid DESC";
                                        preparedStatement = connection.prepareStatement(sqlMain);
                                        preparedStatement.setString(1, "%" + searchKeyword + "%");
                                        preparedStatement.setString(2, "%" + searchKeyword + "%");
                                    } else {
                                        sqlMain = "SELECT d.*, s.sname FROM doctor d LEFT JOIN specialties s ON d.specialties = s.id ORDER BY d.docid DESC";
                                        preparedStatement = connection.prepareStatement(sqlMain);
                                    }
                                    resultSet = preparedStatement.executeQuery();
                                    if (!resultSet.isBeforeFirst()) {
                                %>
                                <tr>
                                    <td colspan="4"><br><br><br><br>
                                        <center><img src="../img/notfound.svg" width="25%"><br>
                                            <p class="heading-main12"
                                               style="margin-left: 45px;font-size:20px;color:rgb(49, 49, 49)">We
                                                couldn't find anything
                                                related<% if (searchKeyword != null && !searchKeyword.trim().isEmpty()) { %>
                                                to your keywords: '<%= searchKeyword %>'<% } %>
                                                !</p><% if (searchKeyword != null && !searchKeyword.trim().isEmpty()) { %><a
                                                    class="non-style-link" href="therapists.jsp">
                                                <button class="login-btn btn-primary-soft btn"
                                                        style="display: flex;justify-content: center;align-items: center;margin-left:20px;">
                                                    &nbsp; Show all Therapists &nbsp;
                                                </button>
                                            </a><% } %></center>
                                        <br><br><br><br></td>
                                </tr>
                                <% } else {
                                    while (resultSet.next()) {
                                        String therapistId_list = resultSet.getString("docid");
                                        String therapistName_list = resultSet.getString("docname");
                                        String email_list = resultSet.getString("docemail");
                                        String spcilName_list = resultSet.getString("sname");
                                        if (spcilName_list == null || spcilName_list.isEmpty()) {
                                            spcilName_list = "N/A";
                                        } %>
                                <tr>
                                    <td>&nbsp;<%= therapistName_list %>
                                    </td>
                                    <td><%= email_list %>
                                    </td>
                                    <td><%= spcilName_list %>
                                    </td>
                                    <td>
                                        <div style="display:flex;justify-content: center;">
                                            <a href="?action=edit&id=<%= therapistId_list %>&error=0"
                                               class="non-style-link">
                                                <button class="btn-primary-soft btn button-icon btn-edit"
                                                        style="padding-left: 40px;padding-top: 12px;padding-bottom: 12px;margin-top: 10px;">
                                                    <font class="tn-in-text">Edit</font></button>
                                            </a>&nbsp;&nbsp;&nbsp;
                                            <a href="?action=view&id=<%= therapistId_list %>" class="non-style-link">
                                                <button class="btn-primary-soft btn button-icon btn-view"
                                                        style="padding-left: 40px;padding-top: 12px;padding-bottom: 12px;margin-top: 10px;">
                                                    <font class="tn-in-text">View</font></button>
                                            </a>&nbsp;&nbsp;&nbsp;
                                            <a href="?action=drop&id=<%= therapistId_list %>&name=<%= java.net.URLEncoder.encode(therapistName_list, "UTF-8") %>"
                                               class="non-style-link"
                                               onclick="return confirm('Are you sure you want to remove Therapist <%= therapistName_list.replace("'", "\\'") %>? This action cannot be undone.');">
                                                <button class="btn-primary-soft btn button-icon btn-delete"
                                                        style="padding-left: 40px;padding-top: 12px;padding-bottom: 12px;margin-top: 10px;">
                                                    <font class="tn-in-text">Remove</font></button>
                                            </a>
                                        </div>
                                    </td>
                                </tr>
                                <% }
                                }
                                    closeQuietly(resultSet);
                                    closeQuietly(preparedStatement); %>
                                </tbody>
                            </table>
                        </div>
                    </center>
                </td>
            </tr>
        </table>
    </div>
</div>

<% if (showAddPopupWithError != null) { %>
<div id="popup-add" class="overlay visible">
    <div class="popup">
        <center>
            <a class="close" href="therapists.jsp">&times;</a>
            <div style="display: flex;justify-content: center;">
                <div class="abc">
                    <table width="80%" class="sub-table scrolldown add-doc-form-container" border="0">
                        <tr>
                            <td class="label-td" colspan="2"
                                style="text-align:center;"><% if (!"0".equals(showAddPopupWithError) && !"4".equals(showAddPopupWithError)) { %><%= errorlist[Integer.parseInt(showAddPopupWithError)] %><% } %></td>
                        </tr>
                        <tr>
                            <td><p style="padding: 0;margin: 0;text-align: left;font-size: 25px;font-weight: 500;">Add
                                New Therapist.</p><br><br></td>
                        </tr>
                        <form action="therapists.jsp?action=add" method="POST" class="add-new-form">
                            <tr>
                                <td class="label-td" colspan="2"><%--@declare id="name"--%><label for="name"
                                                                                                  class="form-label">Name: </label>
                                </td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><input type="text" name="name" class="input-text"
                                                                        placeholder="Therapist Name" required><br></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><%--@declare id="email"--%><label for="Email"
                                                                                                   class="form-label">Email: </label>
                                </td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><input type="email" name="email" class="input-text"
                                                                        placeholder="Email Address" required><br></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><%--@declare id="nic"--%><label for="nic"
                                                                                                 class="form-label">NIC: </label>
                                </td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><input type="text" name="nic" class="input-text"
                                                                        placeholder="NIC Number" required><br></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><%--@declare id="tele"--%><label for="Tele"
                                                                                                  class="form-label">Telephone: </label>
                                </td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><input type="tel" name="Tele" class="input-text"
                                                                        placeholder="Telephone Number" required
                                                                        pattern="[0-9]{10,15}"><br></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><%--@declare id="spec"--%><label for="spec"
                                                                                                  class="form-label">Choose
                                    specialties: </label></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2">
                                    <select name="spec" id="spec_add" class="box" required>
                                        <option value="" disabled selected>Select Specialty</option>
                                        <% PreparedStatement psSpecAdd = null;
                                            ResultSet rsSpecAdd = null;
                                            try {
                                                psSpecAdd = connection.prepareStatement("SELECT * FROM specialties ORDER BY sname ASC");
                                                rsSpecAdd = psSpecAdd.executeQuery();
                                                while (rsSpecAdd.next()) {
                                                    String sn = rsSpecAdd.getString("sname");
                                                    String id00 = rsSpecAdd.getString("id"); %>
                                        <option value="<%= id00 %>"><%= sn %>
                                        </option>
                                        <% }
                                        } catch (SQLException se) {
                                        } finally {
                                            closeQuietly(rsSpecAdd);
                                            closeQuietly(psSpecAdd);
                                        } %>
                                    </select><br></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><label for="password"
                                                                        class="form-label">Password: </label></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><input type="password" name="password"
                                                                        class="input-text"
                                                                        placeholder="Define a Password" required><br>
                                </td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><label for="cpassword" class="form-label">Confirm
                                    Password: </label></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><input type="password" name="cpassword"
                                                                        class="input-text"
                                                                        placeholder="Confirm Password" required><br>
                                </td>
                            </tr>
                            <tr>
                                <td colspan="2" style="text-align:center;"><input type="reset" value="Reset"
                                                                                  class="login-btn btn-primary-soft btn">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<input
                                        type="submit" value="Add" class="login-btn btn-primary btn"></td>
                            </tr>
                        </form>
                    </table>
                </div>
            </div>
        </center>
        <br><br>
    </div>
</div>
<% } %>

<% if (showAddSuccessPopup) { %>
<div id="popup-add-success" class="overlay visible">
    <div class="popup">
        <center><br><br><br><br>
            <h2>New Therapist Added Successfully!</h2><a class="close" href="therapists.jsp">&times;</a>
            <div class="content">The therapist record has been created.</div>
            <div style="display: flex;justify-content: center;"><a href="therapists.jsp" class="non-style-link">
                <button class="btn-primary btn"
                        style="display: flex;justify-content: center;align-items: center;margin:10px;padding:10px;">OK
                </button>
            </a></div>
            <br><br></center>
    </div>
</div>
<% } %>


<% if (editTherapistId != null) {
    String edit_name = "";
    String edit_email = "";
    String edit_spe = "";
    String edit_nic = "";
    String edit_tele = "";
    String edit_spcilName = "N/A";
    PreparedStatement psEdit = null;
    ResultSet rsEdit = null;
    try {
        psEdit = connection.prepareStatement("SELECT * FROM doctor WHERE docid = ?");
        psEdit.setString(1, editTherapistId);
        rsEdit = psEdit.executeQuery();
        if (rsEdit.next()) {
            edit_name = rsEdit.getString("docname");
            edit_email = rsEdit.getString("docemail");
            edit_spe = rsEdit.getString("specialties");
            edit_nic = rsEdit.getString("docnic");
            edit_tele = rsEdit.getString("doctel");
            if (edit_spe != null && !edit_spe.isEmpty()) {
                closeQuietly(rsSpecialty);
                closeQuietly(psSpecialty);
                psSpecialty = connection.prepareStatement("SELECT sname FROM specialties WHERE id = ?");
                psSpecialty.setString(1, edit_spe);
                rsSpecialty = psSpecialty.executeQuery();
                if (rsSpecialty.next()) {
                    edit_spcilName = rsSpecialty.getString("sname");
                }
            }
        } else {
            currentError = "3";
        }
    } catch (SQLException se) {
        currentError = "3";
    } finally {
        closeQuietly(rsEdit);
        closeQuietly(psEdit);
    } %>
<div id="popup-edit" class="overlay visible">
    <div class="popup">
        <center><a class="close" href="therapists.jsp">&times;</a>
            <h2>Edit Therapist Details</h2>
            <div style="display: flex;justify-content: center;">
                <div class="abc">
                    <table width="80%" class="sub-table scrolldown add-doc-form-container" border="0">
                        <tr>
                            <td class="label-td" colspan="2"
                                style="text-align:center;"><% if (currentError != null && !"0".equals(currentError) && !"4".equals(currentError)) { %><%= errorlist[Integer.parseInt(currentError)] %><% } %></td>
                        </tr>
                        <tr>
                            <td><p style="padding: 0;margin: 0;text-align: left;font-size: 25px;font-weight: 500;">Edit
                                Therapist Details.</p>Therapist ID : <%= editTherapistId %> (Auto Generated)<br><br>
                            </td>
                        </tr>
                        <form action="therapists.jsp?action=edit" method="POST" class="add-new-form">
                            <input type="hidden" name="id00" value="<%= editTherapistId %>"><input type="hidden"
                                                                                                   name="oldemail"
                                                                                                   value="<%= edit_email %>">
                            <tr>
                                <td class="label-td" colspan="2"><label for="Email" class="form-label">Email: </label>
                                </td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><input type="email" name="email" class="input-text"
                                                                        placeholder="Email Address"
                                                                        value="<%= edit_email %>" required><br></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><label for="name" class="form-label">Name: </label>
                                </td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><input type="text" name="name" class="input-text"
                                                                        placeholder="Therapist Name"
                                                                        value="<%= edit_name %>" required><br></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><label for="nic" class="form-label">NIC: </label></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><input type="text" name="nic" class="input-text"
                                                                        placeholder="NIC Number" value="<%= edit_nic %>"
                                                                        required><br></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><label for="Tele"
                                                                        class="form-label">Telephone: </label></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><input type="tel" name="Tele" class="input-text"
                                                                        placeholder="Telephone Number"
                                                                        value="<%= edit_tele %>" required
                                                                        pattern="[0-9]{10,15}"><br></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><label for="spec"
                                                                        class="form-label">Specialties: </label></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2">
                                    <select name="spec" id="spec_edit" class="box" required>
                                        <option value="" disabled>Select Specialty</option>
                                        <% PreparedStatement psSpecEdit = null;
                                            ResultSet rsSpecEdit = null;
                                            try {
                                                psSpecEdit = connection.prepareStatement("SELECT * FROM specialties ORDER BY sname ASC");
                                                rsSpecEdit = psSpecEdit.executeQuery();
                                                while (rsSpecEdit.next()) {
                                                    String sn = rsSpecEdit.getString("sname");
                                                    String id00 = rsSpecEdit.getString("id");
                                                    String selected = (edit_spe != null && edit_spe.equals(id00)) ? "selected" : ""; %>
                                        <option value="<%= id00 %>" <%= selected %>><%= sn %>
                                        </option>
                                        <% }
                                        } catch (SQLException se) {
                                        } finally {
                                            closeQuietly(rsSpecEdit);
                                            closeQuietly(psSpecEdit);
                                        } %>
                                    </select><br><br></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><%--@declare id="password"--%><label for="password"
                                                                                                      class="form-label">New
                                    Password: </label></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><input type="password" name="password"
                                                                        class="input-text"
                                                                        placeholder="Enter New Password" required><br>
                                </td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><%--@declare id="cpassword"--%><label for="cpassword"
                                                                                                       class="form-label">Confirm
                                    New
                                    Password: </label></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><input type="password" name="cpassword"
                                                                        class="input-text"
                                                                        placeholder="Confirm New Password" required><br>
                                </td>
                            </tr>
                            <tr>
                                <td colspan="2" style="text-align:center;"><input type="reset" value="Reset"
                                                                                  class="login-btn btn-primary-soft btn">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<input
                                        type="submit" value="Save Changes" class="login-btn btn-primary btn"></td>
                            </tr>
                        </form>
                    </table>
                </div>
            </div>
        </center>
        <br><br>
    </div>
</div>
<% } %>

<% if (showEditSuccessPopup) { %>
<div id="popup-edit-success" class="overlay visible">
    <div class="popup">
        <center><br><br><br><br>
            <h2>Therapist Details Updated Successfully!</h2><a class="close" href="therapists.jsp">&times;</a>
            <div class="content">The therapist record has been modified.</div>
            <div style="display: flex;justify-content: center;"><a href="therapists.jsp" class="non-style-link">
                <button class="btn-primary btn"
                        style="display: flex;justify-content: center;align-items: center;margin:10px;padding:10px;">OK
                </button>
            </a></div>
            <br><br></center>
    </div>
</div>
<% } %>


<% if (viewTherapistId != null) {
    String view_name = "N/A";
    String view_email = "N/A";
    String view_nic = "N/A";
    String view_tele = "N/A";
    String view_spcilName = "N/A";
    PreparedStatement psView = null;
    ResultSet rsView = null;
    try {
        psView = connection.prepareStatement("SELECT d.*, s.sname FROM doctor d LEFT JOIN specialties s ON d.specialties = s.id WHERE d.docid = ?");
        psView.setString(1, viewTherapistId);
        rsView = psView.executeQuery();
        if (rsView.next()) {
            view_name = rsView.getString("docname");
            view_email = rsView.getString("docemail");
            view_nic = rsView.getString("docnic");
            view_tele = rsView.getString("doctel");
            view_spcilName = rsView.getString("sname");
            if (view_spcilName == null || view_spcilName.isEmpty()) {
                view_spcilName = "N/A";
            }
        }
    } catch (SQLException se) {
    } finally {
        closeQuietly(rsView);
        closeQuietly(psView);
    } %>
<div id="popup-view" class="overlay visible">
    <div class="popup">
        <center><h2>View Therapist Details</h2><a class="close" href="therapists.jsp">&times;</a>
            <div style="display: flex;justify-content: center;">
                <table width="80%" class="sub-table scrolldown add-doc-form-container" border="0">
                    <tr>
                        <td><p style="padding: 0;margin: 0;text-align: left;font-size: 25px;font-weight: 500;">
                            Details</p><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Therapist Name: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= view_name %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Email: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= view_email %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">NIC: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= view_nic %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Telephone: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= view_tele %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Specialties: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= view_spcilName %><br><br></td>
                    </tr>
                    <tr>
                        <td colspan="2" style="text-align:center;"><a href="therapists.jsp"><input type="button"
                                                                                                   value="OK"
                                                                                                   class="login-btn btn-primary-soft btn"></a>
                        </td>
                    </tr>
                </table>
            </div>
        </center>
        <br><br>
    </div>
</div>
<% } %>

<%
    } catch (ClassNotFoundException cnfe) {
        System.out.println("Database Driver not found: " + cnfe.getMessage());
        cnfe.printStackTrace();
    } catch (SQLException sqle) {
        System.out.println("Database Error: " + sqle.getMessage());
        sqle.printStackTrace();
    } catch (Exception e) {
        System.out.println("An unexpected error occurred: " + e.getMessage());
        e.printStackTrace();
    } finally {
        closeQuietly(rsSpecialty);
        closeQuietly(psSpecialty);
        closeQuietly(resultSet);
        closeQuietly(preparedStatement);
        closeQuietly(connection);
    }
%>
</body>
</html>
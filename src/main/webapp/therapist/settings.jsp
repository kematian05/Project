<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page
        import="java.sql.*, java.util.*, java.text.*, java.time.LocalDate, java.time.format.DateTimeFormatter, java.net.URLEncoder" %>
<%@ page import="com.google.common.hash.Hashing" %>
<%@ page import="java.nio.charset.StandardCharsets" %>
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

    int doctorId = 0;
    String doctorName = "";
    String errorMessage = null;
    String successMessage = null;
    String messageType = "error";
    boolean forceLogout = false;
    Map<Integer, String> specialtiesMap = new HashMap<>();
    Map<String, Object> doctorData = null;

    String action = request.getParameter("action");
    action = escapeHtml(action);
    String idParam = request.getParameter("id");
    idParam = escapeHtml(idParam);
    String nameParam = request.getParameter("name");
    nameParam = escapeHtml(nameParam);
    String errorParam = request.getParameter("error");
    errorParam = escapeHtml(errorParam);


    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        connection = DriverManager.getConnection(url, dbUser, dbPassword);
        connection.setAutoCommit(false);

        ps = connection.prepareStatement("SELECT * FROM doctor WHERE docemail = ?");
        ps.setString(1, useremail);
        rs = ps.executeQuery();

        if (rs.next()) {
            doctorId = rs.getInt("docid");
            doctorName = rs.getString("docname");
            doctorData = new HashMap<>();
            doctorData.put("docid", doctorId);
            doctorData.put("docname", doctorName);
            doctorData.put("docemail", rs.getString("docemail"));
            doctorData.put("docnic", rs.getString("docnic"));
            doctorData.put("doctel", rs.getString("doctel"));
            doctorData.put("specialties", rs.getInt("specialties"));
        } else {
            closeQuietly(rs);
            closeQuietly(ps);
            closeQuietly(connection);
            session.invalidate();
            response.sendRedirect("../login.jsp?error=user_not_found");
            return;
        }
        closeQuietly(rs);
        closeQuietly(ps);

        specialtiesMap = getSpecialtiesMap(connection);


        if ("confirm-delete".equals(action)) {
            String idToDeleteStr = request.getParameter("id");
            idToDeleteStr = escapeHtml(idToDeleteStr);
            if (idToDeleteStr != null && idToDeleteStr.equals(String.valueOf(doctorId))) {
                PreparedStatement psDelDoc = null;
                PreparedStatement psDelWeb = null;
                try {
                    psDelWeb = connection.prepareStatement("DELETE FROM webuser WHERE email = ?");
                    psDelWeb.setString(1, useremail);
                    int webRows = psDelWeb.executeUpdate();

                    psDelDoc = connection.prepareStatement("DELETE FROM doctor WHERE docid = ?");
                    psDelDoc.setInt(1, doctorId);
                    int docRows = psDelDoc.executeUpdate();

                    if (docRows > 0 && webRows > 0) {
                        connection.commit();
                        forceLogout = true;
                    } else {
                        connection.rollback();
                        errorMessage = "Account deletion failed. Could not remove core records.";
                    }
                } catch (SQLException e) {
                    connection.rollback();
                    if (e.getErrorCode() == 1451) {
                        errorMessage = "Account deletion failed. Cannot delete therapist with existing schedules or appointments. Please cancel them first.";
                    } else {
                        errorMessage = "Database error during deletion: " + e.getMessage();
                    }
                    e.printStackTrace();
                } finally {
                    closeQuietly(psDelDoc);
                    closeQuietly(psDelWeb);
                }
            } else {
                errorMessage = "Invalid request for account deletion.";
            }
            action = null;
        }


        if ("edit-submit".equals(action) && "POST".equalsIgnoreCase(request.getMethod())) {
            String docIdStr = request.getParameter("id00");
            docIdStr = escapeHtml(docIdStr);
            String name = request.getParameter("name");
            name = escapeHtml(name);
            String email = request.getParameter("email");
            email = escapeHtml(email);
            String nic = request.getParameter("nic");
            nic = escapeHtml(nic);
            String tel = request.getParameter("Tele");
            tel = escapeHtml(tel);
            String specStr = request.getParameter("spec");
            specStr = escapeHtml(specStr);
            String password = request.getParameter("password");
            password = escapeHtml(password);
            String cpassword = request.getParameter("cpassword");
            cpassword = escapeHtml(cpassword);
            String oldemail = request.getParameter("oldemail");
            oldemail = escapeHtml(oldemail);

            int spec = 0;
            int editDocId = 0;
            boolean error = false;

            if (isNullOrEmpty(docIdStr) || isNullOrEmpty(name) || isNullOrEmpty(email) || isNullOrEmpty(nic) || isNullOrEmpty(tel) || isNullOrEmpty(specStr) || isNullOrEmpty(password) || isNullOrEmpty(cpassword) || isNullOrEmpty(oldemail)) {
                errorMessage = "Please fill all required fields for editing.";
                error = true;
                errorParam = "3";
            } else if (!password.equals(cpassword)) {
                errorMessage = "Password confirmation does not match.";
                error = true;
                errorParam = "2";
            } else {
                try {
                    spec = Integer.parseInt(specStr);
                } catch (NumberFormatException e) {
                    errorMessage = "Invalid specialty selected for editing.";
                    error = true;
                    errorParam = "3";
                }
                try {
                    editDocId = Integer.parseInt(docIdStr);
                } catch (NumberFormatException e) {
                    errorMessage = "Invalid Therapist ID for editing.";
                    error = true;
                    errorParam = "3";
                }
                if (editDocId != doctorId || !oldemail.equals(useremail)) {
                    errorMessage = "Unauthorized edit attempt detected.";
                    error = true;
                    errorParam = "3";
                }
            }

            if (!error) {
                PreparedStatement psCheck = null;
                ResultSet rsCheck = null;
                PreparedStatement psUpdateDoc = null;
                PreparedStatement psUpdateWeb = null;
                boolean emailChanged = !oldemail.equals(email);

                try {
                    if (emailChanged) {
                        psCheck = connection.prepareStatement("SELECT COUNT(*) FROM webuser WHERE email = ?");
                        psCheck.setString(1, email);
                        rsCheck = psCheck.executeQuery();
                        if (rsCheck.next() && rsCheck.getInt(1) > 0) {
                            errorMessage = "Cannot change email. This email address is already in use.";
                            error = true;
                            errorParam = "1";
                            connection.rollback();
                        }
                        closeQuietly(rsCheck);
                        closeQuietly(psCheck);
                    }

                    if (!error) {
                        String hashedPassword = Hashing.sha256().hashString(password, StandardCharsets.UTF_8).toString();
                        psUpdateDoc = connection.prepareStatement("UPDATE doctor SET docemail=?, docname=?, docpassword=?, docnic=?, doctel=?, specialties=? WHERE docid=?");
                        psUpdateDoc.setString(1, email);
                        psUpdateDoc.setString(2, name);
                        psUpdateDoc.setString(3, hashedPassword);
                        psUpdateDoc.setString(4, nic);
                        psUpdateDoc.setString(5, tel);
                        psUpdateDoc.setInt(6, spec);
                        psUpdateDoc.setInt(7, doctorId);
                        psUpdateDoc.executeUpdate();

                        if (emailChanged) {
                            psUpdateWeb = connection.prepareStatement("UPDATE webuser SET email = ? WHERE email = ?");
                            psUpdateWeb.setString(1, email);
                            psUpdateWeb.setString(2, oldemail);
                            psUpdateWeb.executeUpdate();
                            closeQuietly(psUpdateWeb);
                        }

                        connection.commit();
                        successMessage = "Account details updated successfully!";
                        messageType = "success";
                        if (emailChanged) {
                            successMessage += " Please log out and log in again with your new email.";
                            session.setAttribute("user", email);
                            useremail = email;
                        }
                        doctorData.put("docname", name);
                        doctorData.put("docemail", email);
                        doctorData.put("docnic", nic);
                        doctorData.put("doctel", tel);
                        doctorData.put("specialties", spec);
                        doctorName = name;

                        action = null;
                        idParam = null;
                    }

                } catch (SQLException e) {
                    connection.rollback();
                    errorMessage = "Database error during update: " + e.getMessage();
                    e.printStackTrace();
                    errorParam = "3";
                } finally {
                    closeQuietly(rsCheck);
                    closeQuietly(psCheck);
                    closeQuietly(psUpdateDoc);
                    closeQuietly(psUpdateWeb);
                }
            }
            if (error) {
                action = "edit";
                idParam = String.valueOf(doctorId);
            }
        }


        if (forceLogout) {
            session.invalidate();
            response.sendRedirect("../login.jsp?message=account_deleted");
            return;
        }

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
    <title>Settings</title>
    <style>
        .dashbord-tables {
            animation: transitionIn-Y-over 0.5s;
        }

        .filter-container {
            animation: transitionIn-X 0.5s;
        }

        .sub-table {
            animation: transitionIn-Y-bottom 0.5s;
        }

        .popup {
            animation: transitionIn-Y-bottom 0.5s;
            z-index: 100;
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
                <td class="menu-btn menu-icon-dashbord"><a href="index.jsp" class="non-style-link-menu ">
                    <div><p class="menu-text">Dashboard</p>
                </a>
    </div>
    </a></td></tr>
    <tr class="menu-row">
        <td class="menu-btn menu-icon-appoinment"><a href="appointment.jsp" class="non-style-link-menu">
            <div><p class="menu-text">My Appointments</p>
        </a>
</div>
</td></tr>
<tr class="menu-row">
    <td class="menu-btn menu-icon-session"><a href="schedule.jsp" class="non-style-link-menu">
        <div><p class="menu-text">My Sessions</p></div>
    </a></td>
</tr>
<tr class="menu-row">
    <td class="menu-btn menu-icon-patient"><a href="client.jsp" class="non-style-link-menu">
        <div><p class="menu-text">My Clients</p>
    </a></div></td>
</tr>
<tr class="menu-row">
    <td class="menu-btn menu-icon-settings menu-active menu-icon-settings-active"><a href="settings.jsp"
                                                                                     class="non-style-link-menu non-style-link-menu-active">
        <div><p class="menu-text">Settings</p>
    </a></div></td>
</tr>
</table>
</div>
<div class="dash-body" style="margin-top: 15px">
    <table border="0" width="100%" style=" border-spacing: 0;margin:0;padding:0;">
        <tr>
            <td width="13%"><a href="index.jsp">
                <button class="login-btn btn-primary-soft btn btn-icon-back"
                        style="padding-top:11px;padding-bottom:11px;margin-left:20px;width:140px"><font
                        class="tn-in-text">Dashboard</font></button>
            </a></td>
            <td><p style="font-size: 23px;padding-left:12px;font-weight: 600;">Settings</p></td>
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
            <td colspan="4"> &nbsp;</td>
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
            <td colspan="4">
                <center>
                    <table class="filter-container" style="border: none;" border="0">
                        <tr>
                            <td colspan="4"><p style="font-size: 20px">&nbsp;</p></td>
                        </tr>
                        <tr>
                            <td style="width: 25%;">
                                <a href="?action=edit&id=<%= doctorId %>&error=0" class="non-style-link">
                                    <div class="dashboard-items setting-tabs"
                                         style="padding:20px;margin:auto;width:95%;display: flex">
                                        <div class="btn-icon-back dashboard-icons-setting"
                                             style="background-image: url('../img/icons/doctors-hover.svg');"></div>
                                        <div>
                                            <div class="h1-dashboard">Account Settings&nbsp;</div>
                                            <br>
                                            <div class="h3-dashboard" style="font-size: 15px;">Edit your Account Details
                                                & Change Password
                                            </div>
                                        </div>
                                    </div>
                                </a>
                            </td>
                        </tr>
                        <tr>
                            <td colspan="4"><p style="font-size: 5px">&nbsp;</p></td>
                        </tr>
                        <tr>
                            <td style="width: 25%;">
                                <a href="?action=view&id=<%= doctorId %>" class="non-style-link">
                                    <div class="dashboard-items setting-tabs"
                                         style="padding:20px;margin:auto;width:95%;display: flex;">
                                        <div class="btn-icon-back dashboard-icons-setting "
                                             style="background-image: url('../img/icons/view-iceblue.svg');"></div>
                                        <div>
                                            <div class="h1-dashboard">View Account Details</div>
                                            <br>
                                            <div class="h3-dashboard" style="font-size: 15px;">View Personal information
                                                About Your Account
                                            </div>
                                        </div>
                                    </div>
                                </a>
                            </td>
                        </tr>
                        <tr>
                            <td colspan="4"><p style="font-size: 5px">&nbsp;</p></td>
                        </tr>
                        <tr>
                            <td style="width: 25%;">
                                <a href="?action=drop&id=<%= doctorId %>&name=<%= URLEncoder.encode(doctorName, "UTF-8") %>"
                                   class="non-style-link">
                                    <div class="dashboard-items setting-tabs"
                                         style="padding:20px;margin:auto;width:95%;display: flex;">
                                        <div class="btn-icon-back dashboard-icons-setting"
                                             style="background-image: url('../img/icons/delete-iceblue.svg');"></div>
                                        <div>
                                            <div class="h1-dashboard" style="color: #ff5050;">Delete Account</div>
                                            <br>
                                            <div class="h3-dashboard" style="font-size: 15px;">Will Permanently Remove
                                                your Account
                                            </div>
                                        </div>
                                    </div>
                                </a>
                            </td>
                        </tr>
                    </table>
                </center>
            </td>
        </tr>
    </table>
</div>
</div>
<%
    boolean showViewPopup = "view".equals(action) && idParam != null && idParam.equals(String.valueOf(doctorId));
    boolean showEditPopup = "edit".equals(action) && idParam != null && idParam.equals(String.valueOf(doctorId));
    boolean showDropPopup = "drop".equals(action) && idParam != null && idParam.equals(String.valueOf(doctorId));

    String popupErrorMsg = null;
    if (!isNullOrEmpty(errorParam) && (showEditPopup)) {
        switch (errorParam) {
            case "1":
                popupErrorMsg = "Email address already in use by another account.";
                break;
            case "2":
                popupErrorMsg = "Password Confirmation Error! Please reconfirm password.";
                break;
            default:
                popupErrorMsg = errorMessage != null ? errorMessage : "An error occurred. Please check details.";
                break;
        }
    } else if (errorMessage != null && (showEditPopup)) {
        popupErrorMsg = errorMessage;
    }

%>

<% if (showViewPopup && doctorData != null) {
    int currentSpecIdView = (Integer) doctorData.get("specialties");
    String currentSpecNameView = specialtiesMap.getOrDefault(currentSpecIdView, "Unknown");
%>
<div id="popup1" class="overlay visible">
    <div class="popup">
        <center>
            <h2></h2><a class="close" href="settings.jsp">&times;</a>
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
                        <td class="label-td" colspan="2"><%= doctorData.get("docname") %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Email: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= doctorData.get("docemail") %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">NIC: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= doctorData.get("docnic") %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Telephone: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= doctorData.get("doctel") %><br><br></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><label class="form-label">Specialties: </label></td>
                    </tr>
                    <tr>
                        <td class="label-td" colspan="2"><%= currentSpecNameView %><br><br></td>
                    </tr>
                    <tr>
                        <td colspan="2"><a href="settings.jsp"><input type="button" value="OK"
                                                                      class="login-btn btn-primary-soft btn"></a></td>
                    </tr>
                </table>
            </div>
        </center>
        <br><br>
    </div>
</div>
<% } %>

<% if (showEditPopup && doctorData != null) {
    int currentSpecIdEdit = (Integer) doctorData.get("specialties");
%>
<div id="popup1" class="overlay visible">
    <div class="popup">
        <center>
            <a class="close" href="settings.jsp">&times;</a>
            <div style="display: flex;justify-content: center;">
                <div class="abc">
                    <table width="80%" class="sub-table scrolldown add-doc-form-container" border="0">
                        <%--                        <tr>--%>
                        <%--                            <td class="label-td" colspan="2">--%>
                        <%--                                <% if (popupErrorMsg != null) { %><label class="form-label"--%>
                        <%--                                                                         style="color:rgb(255, 62, 62);text-align:center;"><%= popupErrorMsg %>--%>
                        <%--                            </label><% } %>--%>
                        <%--                            </td>--%>
                        <%--                        </tr>--%>
                        <tr>
                            <td><p style="padding: 0;margin: 0;text-align: left;font-size: 25px;font-weight: 500;">Edit
                                Account Details.</p></td>
                        </tr>
                        <form action="settings.jsp?action=edit-submit" method="POST" class="add-new-form">
                            <input type="hidden" value="<%= doctorId %>" name="id00">
                            <input type="hidden" name="oldemail" value="<%= (String)doctorData.get("docemail") %>">
                            <tr>
                                <td class="label-td" colspan="2"><%--@declare id="email"--%><label for="Email"
                                                                                                   class="form-label">Email: </label>
                                </td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><input type="email" name="email" class="input-text"
                                                                        placeholder="Email Address"
                                                                        value="<%= (String)doctorData.get("docemail") %>"
                                                                        required><br></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><%--@declare id="name"--%><label for="name"
                                                                                                  class="form-label">Name: </label>
                                </td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><input type="text" name="name" class="input-text"
                                                                        placeholder="Therapist Name"
                                                                        value="<%= (String)doctorData.get("docname") %>"
                                                                        required><br></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><%--@declare id="nic"--%><label for="nic"
                                                                                                 class="form-label">NIC: </label>
                                </td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><input type="text" name="nic" class="input-text"
                                                                        placeholder="NIC Number"
                                                                        value="<%= (String)doctorData.get("docnic") %>"
                                                                        required><br></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><%--@declare id="tele"--%><label for="Tele"
                                                                                                  class="form-label">Telephone: </label>
                                </td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><input type="tel" name="Tele" class="input-text"
                                                                        placeholder="Telephone Number"
                                                                        value="<%= (String)doctorData.get("doctel") %>"
                                                                        required><br></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><label for="spec" class="form-label">Choose
                                    specialties: </label></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2">
                                    <select name="spec" id="spec" class="box" required>
                                        <% for (Map.Entry<Integer, String> entry : specialtiesMap.entrySet()) {
                                            boolean selected = entry.getKey() == currentSpecIdEdit;
                                        %>
                                        <option value="<%= entry.getKey() %>" <%= selected ? "selected" : "" %>><%= entry.getValue() %>
                                        </option>
                                        <% } %>
                                    </select><br><br>
                                </td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><%--@declare id="password"--%><label for="password"
                                                                                                      class="form-label">New
                                    Password: </label></td>
                            </tr>
                            <tr>
                                <td class="label-td" colspan="2"><input type="password" name="password"
                                                                        class="input-text"
                                                                        placeholder="Define a New Password"
                                                                        required><br></td>
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
                                <td colspan="2"><input type="reset" value="Reset"
                                                       class="login-btn btn-primary-soft btn">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<input
                                        type="submit" value="Save" class="login-btn btn-primary btn"></td>
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

<% if (showDropPopup) { %>
<div id="popup1" class="overlay visible">
    <div class="popup">
        <center>
            <h2>Are you sure?</h2>
            <a class="close" href="settings.jsp">&times;</a>
            <div class="content">You want to permanently delete your account?<br>(<%= safeSubstring(nameParam, 0, 40) %>
                )<br><br>This action cannot be undone.
            </div>
            <div style="display: flex;justify-content: center;">
                <a href="settings.jsp?action=confirm-delete&id=<%= doctorId %>" class="non-style-link">
                    <button class="btn-primary btn"
                            style="display: flex;justify-content: center;align-items: center;margin:10px;padding:10px;">
                        <font class="tn-in-text">&nbsp;Yes&nbsp;</font></button>
                </a>&nbsp;&nbsp;&nbsp;
                <a href="settings.jsp" class="non-style-link">
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
//        closeQuietly(rsUser);
//        closeQuietly(psUser);
        closeQuietly(connection);
    }
%>
</body>
</html>
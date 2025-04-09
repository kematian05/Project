<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*, java.util.Date, java.text.SimpleDateFormat, java.util.Calendar" %>
<%@ page import="org.apache.commons.text.StringEscapeUtils" %>
<%!
    private void closeQuietly(AutoCloseable resource) {
        if (resource != null) {
            try {
                resource.close();
            } catch (Exception e) {
                // Handle exception silently
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

    String today = "";
    String searchKeyword = request.getParameter("search");
    searchKeyword = escapeHtml(searchKeyword);
    String action = request.getParameter("action");
    action = escapeHtml(action);
    String clientIdParam = request.getParameter("id");
    clientIdParam = escapeHtml(clientIdParam);

    String viewClientId = null;
    String editClientId = null;
    String errorMessage = null;
    String successMessage = null;

    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        connection = DriverManager.getConnection(url, dbUser, dbPassword);

        SimpleDateFormat dateFormat = new SimpleDateFormat("yyyy-MM-dd");
        today = dateFormat.format(new Date());

        if ("delete".equals(action) && clientIdParam != null) {
            PreparedStatement psDelete = null;
            try {
                int clientIdToDelete = Integer.parseInt(clientIdParam);
                psDelete = connection.prepareStatement("DELETE FROM patient WHERE pid = ?");
                psDelete.setInt(1, clientIdToDelete);
                int rowsAffected = psDelete.executeUpdate();
                if (rowsAffected > 0) {
                    successMessage = "Client deleted successfully.";
                } else {
                    errorMessage = "Client not found or could not be deleted.";
                }
                response.sendRedirect("clients.jsp");
                return;
            } catch (NumberFormatException nfe) {
                errorMessage = "Invalid Client ID for deletion.";
            } catch (SQLException se) {
                errorMessage = "Database error during deletion: " + se.getMessage();
            } finally {
                closeQuietly(psDelete);
            }
        } else if ("update".equals(action) && clientIdParam != null) {
            PreparedStatement psUpdate = null;
            try {
                int clientIdToUpdate = Integer.parseInt(clientIdParam);
                String name = request.getParameter("edit_name");
                name = escapeHtml(name);
                String email = request.getParameter("edit_email");
                email = escapeHtml(email);
                String nic = request.getParameter("edit_nic");
                nic = escapeHtml(nic);
                String tel = request.getParameter("edit_tel");
                tel = escapeHtml(tel);
                String address = request.getParameter("edit_address");
                address = escapeHtml(address);
                String dob = request.getParameter("edit_dob");
                dob = escapeHtml(dob);

                psUpdate = connection.prepareStatement("UPDATE patient SET pname = ?, pemail = ?, pnic = ?, ptel = ?, paddress = ?, pdob = ? WHERE pid = ?");
                psUpdate.setString(1, name);
                psUpdate.setString(2, email);
                psUpdate.setString(3, nic);
                psUpdate.setString(4, tel);
                psUpdate.setString(5, address);
                psUpdate.setString(6, dob);
                psUpdate.setInt(7, clientIdToUpdate);

                int rowsAffected = psUpdate.executeUpdate();
                if (rowsAffected > 0) {
                    successMessage = "Client updated successfully.";
                } else {
                    errorMessage = "Client not found or could not be updated.";
                }
                response.sendRedirect("clients.jsp");
                return;
            } catch (NumberFormatException nfe) {
                errorMessage = "Invalid Client ID for update.";
            } catch (SQLException se) {
                errorMessage = "Database error during update: " + se.getMessage();
            } finally {
                closeQuietly(psUpdate);
            }
        }


        if ("view".equals(action) && clientIdParam != null) {
            viewClientId = clientIdParam;
        } else if ("edit".equals(action) && clientIdParam != null) {
            editClientId = clientIdParam;
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
    <title>Clients Management</title>
    <style>
        .popup {
            animation: transitionIn-Y-bottom 0.5s;
            z-index: 100;
            max-height: 90vh;
            overflow-y: auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 5px 15px rgba(0, 0, 0, 0.2);
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
            max-height: 70vh;
            overflow-y: auto;
            padding: 20px 30px;
        }

        .form-container {
            paddingr: 15px;
            background-color: #ffffff;
            border-radius: 8px;
        }

        .detail-row, .form-row {
            margin-bottom: 15px;
        }

        .detail-label, .form-label {
            font-weight: 600;
            color: #555;
            display: block;
            margin-bottom: 5px;
            font-size: 0.9em;
        }

        .detail-value {
            font-size: 1em;
            color: #333;
        }

        .form-input {
            width: 100%;
            padding: 8px 10px;
            border: 1px solid #ccc;
            border-radius: 4px;
            box-sizing: border-box;
            font-size: 0.95em;
        }

        textarea.form-input {
            min-height: 80px;
            resize: vertical;
        }

        .button-icon {
            display: flex;
            align-items: center;
            gap: 20px;
            justify-content: center;
            padding-right: 15px !important;
            padding-left: 15px !important;
        }

        .btn-edit {
            background-color: #ffc107;
            color: #333;
        }

        .btn-delete {
            background-color: #dc3545;
            color: white;
        }

        .action-buttons-cell > div {
            gap: 8px;
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
                                <img src="../img/user.png" alt="User" width="100%" style="border-radius:50%">
                            </td>
                            <td style="padding:0px;margin:0px;">
                                <p class="profile-title">Administrator</p>
                                <p class="profile-subtitle"><%= user %>
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
                <td class="menu-btn menu-icon-appoinment"><a href="appointment.jsp" class="non-style-link-menu">
                    <div><p class="menu-text">Appointments</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-patient menu-active menu-icon-patient-active"><a href="clients.jsp"
                                                                                               class="non-style-link-menu non-style-link-menu-active">
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
                            style="padding-top:11px;padding-bottom:11px;margin-left:20px;width:140px"><font
                            class="tn-in-text">Dashboard</font></button>
                </a></td>
                <td>
                    <form action="clients.jsp" method="post" class="header-search">
                        <input type="search" name="search" class="input-text header-searchbar"
                               placeholder="Search Client Name or Email" list="client"
                               value="<%= searchKeyword != null ? searchKeyword : "" %>">&nbsp;&nbsp;
                        <datalist id="client">
                            <%
                                PreparedStatement psDatalist = null;
                                ResultSet rsDatalist = null;
                                try {
                                    psDatalist = connection.prepareStatement("SELECT pname, pemail FROM patient ORDER BY pname ASC");
                                    rsDatalist = psDatalist.executeQuery();
                                    while (rsDatalist.next()) {
                            %>
                            <option value="<%= rsDatalist.getString("pname") %>"></option>
                            <option value="<%= rsDatalist.getString("pemail") %>"></option>
                            <%
                                    }
                                } catch (SQLException se) { /* Silent */ } finally {
                                    closeQuietly(rsDatalist);
                                    closeQuietly(psDatalist);
                                }
                            %>
                        </datalist>
                        <input type="Submit" value="Search" class="login-btn btn-primary btn"
                               style="padding: 10px 25px;">
                        <% boolean isSearchActive = searchKeyword != null && !searchKeyword.trim().isEmpty(); %>
                        <% if (isSearchActive) { %>
                        <a href="clients.jsp" style="text-decoration: none;">
                            <button type="button" class="login-btn btn-primary-soft btn"
                                    style="margin-left: 10px; padding: 10px 15px;">Clear
                            </button>
                        </a>
                        <% } %>
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
                <td colspan="4"><p style="color: red; text-align: center; padding: 10px;"><%= errorMessage %>
                </p></td>
            </tr>
            <% } %>
            <% if (successMessage != null) { %>
            <tr>
                <td colspan="4"><p style="color: green; text-align: center; padding: 10px;"><%= successMessage %>
                </p></td>
            </tr>
            <% } %>
            <tr>
                <td colspan="4" style="padding-top:10px;">
                    <%
                        String sqlCount;
                        int clientCount = 0;
                        PreparedStatement psCount = null;
                        ResultSet rsCount = null;
                        try {
                            if (isSearchActive) {
                                sqlCount = "SELECT COUNT(*) FROM patient WHERE pemail LIKE ? OR pname LIKE ?";
                                psCount = connection.prepareStatement(sqlCount);
                                psCount.setString(1, "%" + searchKeyword + "%");
                                psCount.setString(2, "%" + searchKeyword + "%");
                            } else {
                                sqlCount = "SELECT COUNT(*) FROM patient";
                                psCount = connection.prepareStatement(sqlCount);
                            }
                            rsCount = psCount.executeQuery();
                            if (rsCount.next()) clientCount = rsCount.getInt(1);
                        } catch (SQLException se) { /* Silent */ } finally {
                            closeQuietly(rsCount);
                            closeQuietly(psCount);
                        }
                    %>
                    <p class="heading-main12"
                       style="margin-left: 45px;font-size:18px;color:rgb(49, 49, 49)"><%= isSearchActive ? "Search Results for Clients" : "All Clients" %>
                        (<%= clientCount %>)</p>
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
                                    <th class="table-headin">NIC / ID</th>
                                    <th class="table-headin">Telephone</th>
                                    <th class="table-headin">Email</th>
                                    <th class="table-headin">Date of Birth</th>
                                    <th class="table-headin" style="text-align: center;">Actions</th>
                                </tr>
                                </thead>
                                <tbody>
                                <%
                                    String sqlMain;
                                    if (isSearchActive) {
                                        sqlMain = "SELECT * FROM patient WHERE pemail LIKE ? OR pname LIKE ? ORDER BY pid DESC";
                                        preparedStatement = connection.prepareStatement(sqlMain);
                                        preparedStatement.setString(1, "%" + searchKeyword + "%");
                                        preparedStatement.setString(2, "%" + searchKeyword + "%");
                                    } else {
                                        sqlMain = "SELECT * FROM patient ORDER BY pid DESC";
                                        preparedStatement = connection.prepareStatement(sqlMain);
                                    }
                                    resultSet = preparedStatement.executeQuery();
                                    if (!resultSet.isBeforeFirst()) {
                                %>
                                <tr>
                                    <td colspan="6"><br><br>
                                        <center><img src="../img/notfound.svg" width="25%">
                                            <p class="heading-main12" style="font-size:20px;color:rgb(49, 49, 49)">No
                                                clients found<% if (isSearchActive) { %> matching '<%= searchKeyword %>
                                                '<% } %> !</p><% if (isSearchActive) { %><a class="non-style-link"
                                                                                            href="clients.jsp">
                                                <button class="login-btn btn-primary-soft btn"
                                                        style="display: inline-block; margin-top:15px;">&nbsp; Show all
                                                    Clients &nbsp;
                                                </button>
                                            </a><% } %></center>
                                        <br><br></td>
                                </tr>
                                <%
                                } else {
                                    while (resultSet.next()) {
                                        int clientId = resultSet.getInt("pid");
                                        String name = resultSet.getString("pname");
                                        String email = resultSet.getString("pemail");
                                        String nic = resultSet.getString("pnic");
                                        String dob = resultSet.getString("pdob");
                                        String tel = resultSet.getString("ptel");
                                %>
                                <tr>
                                    <td>&nbsp;<%= name != null ? name : "N/A" %>
                                    </td>
                                    <td><%= nic != null ? nic : "N/A" %>
                                    </td>
                                    <td><%= tel != null ? tel : "N/A" %>
                                    </td>
                                    <td><%= email != null ? email : "N/A" %>
                                    </td>
                                    <td><%= dob != null ? dob : "N/A" %>
                                    </td>
                                    <td class="action-buttons-cell">
                                        <div style="display:flex; justify-content: center;">
                                            <a href="?action=view&id=<%= clientId %>" class="non-style-link">
                                                <button class="btn-primary-soft btn button-icon btn-view"
                                                        style="height:30px">
                                                    <i class="fa fa-eye"></i>
                                                    <span class="tn-in-text">View</span>
                                                </button>
                                            </a>
                                            <a href="?action=edit&id=<%= clientId %>" class="non-style-link">
                                                <button class="btn-primary-soft btn button-icon btn-edit"
                                                        style="height:30px">
                                                    <i class="fa fa-edit"></i>
                                                    <span class="tn-in-text">Edit</span>
                                                </button>
                                            </a>
                                            <a href="?action=delete&id=<%= clientId %>" class="non-style-link"
                                               onclick="return confirm('Are you sure you want to delete client: <%= name %>? This action cannot be undone.');">
                                                <button class="btn-primary-soft btn button-icon btn-delete"
                                                        style="height:30px">
                                                    <i class="fa fa-trash"></i>
                                                    <span class="tn-in-text">Remove</span>
                                                </button>
                                            </a>
                                        </div>
                                    </td>
                                </tr>
                                <%
                                        }
                                    }
                                    closeQuietly(resultSet);
                                    closeQuietly(preparedStatement);
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

<% if (viewClientId != null) {
    PreparedStatement psView = null;
    ResultSet rsView = null;
    String view_name = "N/A", view_email = "N/A", view_nic = "N/A", view_dob = "N/A", view_tele = "N/A", view_address = "N/A";
    boolean clientFound = false;
    try {
        psView = connection.prepareStatement("SELECT * FROM patient WHERE pid = ?");
        psView.setInt(1, Integer.parseInt(viewClientId));
        rsView = psView.executeQuery();
        if (rsView.next()) {
            clientFound = true;
            view_name = rsView.getString("pname");
            view_email = rsView.getString("pemail");
            view_nic = rsView.getString("pnic");
            view_dob = rsView.getString("pdob");
            view_tele = rsView.getString("ptel");
            view_address = rsView.getString("paddress");
        }
    } catch (Exception e) { /* Error handled below */ } finally {
        closeQuietly(rsView);
        closeQuietly(psView);
    }
%>
<div id="popup-view" class="overlay visible">
    <div class="popup" style="width: 50%; max-width: 500px;">
        <a class="close" href="clients.jsp">&times;</a>
        <center><h2 style="margin-bottom: 20px;">Client Details</h2></center>
        <div class="content">
            <% if (clientFound) { %>
            <div class="detail-row"><span class="detail-label">Client ID:</span><span
                    class="detail-value">C-<%= viewClientId %></span></div>
            <div class="detail-row"><span class="detail-label">Name:</span><span
                    class="detail-value"><%= view_name %></span></div>
            <div class="detail-row"><span class="detail-label">Email:</span><span
                    class="detail-value"><%= view_email != null ? view_email : "N/A" %></span></div>
            <div class="detail-row"><span class="detail-label">NIC / ID:</span><span
                    class="detail-value"><%= view_nic != null ? view_nic : "N/A" %></span></div>
            <div class="detail-row"><span class="detail-label">Telephone:</span><span
                    class="detail-value"><%= view_tele != null ? view_tele : "N/A" %></span></div>
            <div class="detail-row"><span class="detail-label">Address:</span><span
                    class="detail-value"><%= view_address != null && !view_address.trim().isEmpty() ? view_address : "N/A" %></span>
            </div>
            <div class="detail-row"><span class="detail-label">Date of Birth:</span><span
                    class="detail-value"><%= view_dob != null ? view_dob : "N/A" %></span></div>
            <% } else { %>
            <p style="text-align: center; color: red;">Client not found or error loading details.</p>
            <% } %>
            <div style="text-align: center; margin-top: 30px;">
                <a href="clients.jsp"><input type="button" value="Close" class="login-btn btn-primary-soft btn"
                                             style="min-width: 100px;"></a>
            </div>
        </div>
        <br>
    </div>
</div>
<% } %>

<% if (editClientId != null) {
    PreparedStatement psEdit = null;
    ResultSet rsEdit = null;
    String edit_name = "", edit_email = "", edit_nic = "", edit_dob = "", edit_tele = "", edit_address = "";
    boolean clientFoundForEdit = false;
    try {
        psEdit = connection.prepareStatement("SELECT * FROM patient WHERE pid = ?");
        psEdit.setInt(1, Integer.parseInt(editClientId));
        rsEdit = psEdit.executeQuery();
        if (rsEdit.next()) {
            clientFoundForEdit = true;
            edit_name = rsEdit.getString("pname");
            edit_email = rsEdit.getString("pemail");
            edit_nic = rsEdit.getString("pnic");
            edit_dob = rsEdit.getString("pdob");
            edit_tele = rsEdit.getString("ptel");
            edit_address = rsEdit.getString("paddress");
        }
    } catch (Exception e) { /* Error handled below */ } finally {
        closeQuietly(rsEdit);
        closeQuietly(psEdit);
    }
%>
<div id="popup-edit" class="overlay visible">
    <div class="popup" style="width: 60%; max-width: 600px;">
        <a class="close" href="clients.jsp">&times;</a>
        <center><h2 style="margin-bottom: 20px;">Edit Client Information</h2></center>
        <div class="content">
            <% if (clientFoundForEdit) { %>
            <form action="clients.jsp" method="post">
                <input type="hidden" name="action" value="update">
                <input type="hidden" name="id" value="<%= editClientId %>">

                <div class="form-row">
                    <label for="edit_name" class="form-label">Name:</label>
                    <input type="text" id="edit_name" name="edit_name" class="form-input"
                           value="<%= edit_name != null ? edit_name : "" %>" required>
                </div>
                <div class="form-row">
                    <label for="edit_email" class="form-label">Email:</label>
                    <input type="email" id="edit_email" name="edit_email" class="form-input"
                           value="<%= edit_email != null ? edit_email : "" %>" required>
                </div>
                <div class="form-row">
                    <label for="edit_nic" class="form-label">NIC / ID:</label>
                    <input type="text" id="edit_nic" name="edit_nic" class="form-input"
                           value="<%= edit_nic != null ? edit_nic : "" %>">
                </div>
                <div class="form-row">
                    <label for="edit_tel" class="form-label">Telephone:</label>
                    <input type="tel" id="edit_tel" name="edit_tel" class="form-input"
                           value="<%= edit_tele != null ? edit_tele : "" %>">
                </div>
                <div class="form-row">
                    <label for="edit_dob" class="form-label">Date of Birth:</label>
                    <input type="date" id="edit_dob" name="edit_dob" class="form-input"
                           value="<%= edit_dob != null ? edit_dob : "" %>">
                </div>
                <div class="form-row">
                    <label for="edit_address" class="form-label">Address:</label>
                    <textarea id="edit_address" name="edit_address"
                              class="form-input"><%= edit_address != null ? edit_address : "" %></textarea>
                </div>
                <div style="text-align: center; margin-top: 30px;">
                    <input type="submit" value="Save Changes" class="login-btn btn-primary btn"
                           style="min-width: 120px; margin-right: 10px;">
                    <a href="clients.jsp"><input type="button" value="Cancel" class="login-btn btn-primary-soft btn"
                                                 style="min-width: 100px;"></a>
                </div>
            </form>
            <% } else { %>
            <p style="text-align: center; color: red;">Client not found or error loading details for editing.</p>
            <div style="text-align: center; margin-top: 30px;">
                <a href="clients.jsp"><input type="button" value="Close" class="login-btn btn-primary-soft btn"
                                             style="min-width: 100px;"></a>
            </div>
            <% } %>
        </div>
        <br>
    </div>
</div>
<% } %>

<%
    } catch (ClassNotFoundException cnfe) {
        System.out.println("<div style='color:red; text-align:center; padding: 20px; font-family: sans-serif;'>Database Driver not found.</div>");
    } catch (SQLException sqle) {
        System.out.println("<div style='color:red; text-align:center; padding: 20px; font-family: sans-serif;'>Database Error [" + sqle.getErrorCode() + "].</div>");
    } catch (Exception e) {
        System.out.println("<div style='color:red; text-align:center; padding: 20px; font-family: sans-serif;'>An unexpected error occurred.</div>");
    } finally {
        closeQuietly(resultSet);
        closeQuietly(preparedStatement);
        closeQuietly(connection);
    }
%>
</body>
</html>
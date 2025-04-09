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

    private int getCount(Connection conn, String sql, Object... params) throws SQLException {
        PreparedStatement ps = null;
        ResultSet rs = null;
        try {
            ps = conn.prepareStatement(sql);
            for (int i = 0; i < params.length; i++) {
                ps.setObject(i + 1, params[i]);
            }
            rs = ps.executeQuery();
            if (rs.next()) {
                return rs.getInt(1);
            }
            return 0;
        } finally {
            closeQuietly(rs);
            closeQuietly(ps);
        }
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

    int patientId = 0;
    String patientName = "";
    String errorMessage = null;

    int patientCount = 0;
    int doctorCount = 0;
    int appointmentCount = 0;
    int scheduleCount = 0;

    List<Map<String, String>> doctorDatalist = new ArrayList<>();
    List<Map<String, Object>> upcomingBookings = new ArrayList<>();

    SimpleDateFormat displayTimeFormat = new SimpleDateFormat("HH:mm");
    SimpleDateFormat dbTimeFormat = new SimpleDateFormat("HH:mm:ss");

    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        connection = DriverManager.getConnection(url, dbUser, dbPassword);

        String sqlUser = "SELECT pid, pname FROM patient WHERE pemail = ?";
        ps = connection.prepareStatement(sqlUser);
        ps.setString(1, useremail);
        rs = ps.executeQuery();

        if (rs.next()) {
            patientId = rs.getInt("pid");
            patientName = rs.getString("pname");
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

        String today = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd"));

        doctorCount = getCount(connection, "SELECT COUNT(*) FROM doctor");
        patientCount = getCount(connection, "SELECT COUNT(*) FROM patient");
        appointmentCount = getCount(connection, "SELECT COUNT(*) FROM appointment WHERE appodate >= ?", today);
        scheduleCount = getCount(connection, "SELECT COUNT(*) FROM schedule WHERE scheduledate = ?", today);


        ps = connection.prepareStatement("SELECT docname, docemail FROM doctor");
        rs = ps.executeQuery();
        while (rs.next()) {
            Map<String, String> item = new HashMap<>();
            item.put("name", rs.getString("docname"));
            item.put("email", rs.getString("docemail"));
            doctorDatalist.add(item);
        }
        closeQuietly(rs);
        closeQuietly(ps);


        String sqlBookings = "SELECT appointment.apponum, schedule.title, doctor.docname, schedule.scheduledate, schedule.scheduletime " +
                "FROM schedule " +
                "INNER JOIN appointment ON schedule.scheduleid=appointment.scheduleid " +
                "INNER JOIN patient ON patient.pid=appointment.pid " +
                "INNER JOIN doctor ON schedule.docid=doctor.docid " +
                "WHERE patient.pid = ? AND schedule.scheduledate >= ? " +
                "ORDER BY schedule.scheduledate ASC, schedule.scheduletime ASC";
        ps = connection.prepareStatement(sqlBookings);
        ps.setInt(1, patientId);
        ps.setString(2, today);
        rs = ps.executeQuery();

        while (rs.next()) {
            Map<String, Object> booking = new HashMap<>();
            booking.put("apponum", rs.getInt("apponum"));
            booking.put("title", rs.getString("title"));
            booking.put("docname", rs.getString("docname"));
            booking.put("scheduledate", rs.getString("scheduledate"));
            booking.put("scheduletime", rs.getString("scheduletime"));
            upcomingBookings.add(booking);
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
    <title>Dashboard</title>
    <style>
        .dashbord-tables {
            animation: transitionIn-Y-over 0.5s;
        }

        .filter-container {
            animation: transitionIn-Y-bottom 0.5s;
        }

        .sub-table, .anime {
            animation: transitionIn-Y-bottom 0.5s;
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
                <td class="menu-btn menu-icon-home menu-active menu-icon-home-active"><a href="index.jsp"
                                                                                         class="non-style-link-menu non-style-link-menu-active">
                    <div><p class="menu-text">Home</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-doctor"><a href="therapists.jsp" class="non-style-link-menu">
                    <div><p class="menu-text">All Therapists</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-session"><a href="schedule.jsp" class="non-style-link-menu">
                    <div><p class="menu-text">Scheduled Sessions</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-appoinment"><a href="appointment.jsp" class="non-style-link-menu">
                    <div><p class="menu-text">My Bookings</p></div>
                </a></td>
            </tr>
            <tr class="menu-row">
                <td class="menu-btn menu-icon-settings"><a href="settings.jsp" class="non-style-link-menu">
                    <div><p class="menu-text">Settings</p></div>
                </a></td>
            </tr>
        </table>
    </div>
    <div class="dash-body" style="margin-top: 15px">
        <table border="0" width="100%" style=" border-spacing: 0;margin:0;padding:0;">
            <tr>
                <td colspan="1" class="nav-bar"><p
                        style="font-size: 23px;padding-left:12px;font-weight: 600;margin-left:20px;">Home</p></td>
                <td width="25%"></td>
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
                <td colspan="4">
                    <center>
                        <table class="filter-container doctor-header patient-header" style="border: none;width:95%"
                               border="0">
                            <tr>
                                <td>
                                    <h3>Welcome!</h3>
                                    <h1><%= patientName %>.</h1>
                                    <p>Haven't any idea about therapists? No problem let's jumping to
                                        <a href="therapists.jsp" class="non-style-link"><b>"All Therapists"</b></a>
                                        section or
                                        <a href="schedule.jsp" class="non-style-link"><b>"Sessions"</b> </a><br>
                                        Track your past and future appointments history.<br>Also find out the expected
                                        arrival time of your therapist or medical consultant.<br><br>
                                    </p>
                                    <h3>Channel a Therapist Here</h3>
                                    <form action="schedule.jsp" method="post" style="display: flex">
                                        <input type="search" name="search" class="input-text "
                                               placeholder="Search Therapist and We will Find The Session Available"
                                               list="doctors" style="width:45%;">&nbsp;&nbsp;
                                        <datalist id="doctors">
                                            <% for (Map<String, String> item : doctorDatalist) { %>
                                            <option value="<%= item.get("name") %>"><%= item.get("email") %>
                                            </option>
                                            <% } %>
                                        </datalist>
                                        <input type="Submit" value="Search" class="login-btn btn-primary btn"
                                               style="padding-left: 25px;padding-right: 25px;padding-top: 10px;padding-bottom: 10px;">
                                        <br><br>
                                </td>
                            </tr>
                        </table>
                    </center>
                </td>
            </tr>
            <tr>
                <td colspan="4">
                    <table border="0" width="100%">
                        <tr>
                            <td width="50%">
                                <center>
                                    <table class="filter-container" style="border: none;" border="0">
                                        <tr>
                                            <td colspan="4"><p
                                                    style="font-size: 20px;font-weight:600;padding-left: 12px;">
                                                Status</p></td>
                                        </tr>
                                        <tr>
                                            <td style="width: 25%;">
                                                <div class="dashboard-items"
                                                     style="padding:20px;margin:auto;width:95%;display: flex">
                                                    <div>
                                                        <div class="h1-dashboard"><%= doctorCount %>
                                                        </div>
                                                        <br>
                                                        <div class="h3-dashboard">All Therapists &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</div>
                                                    </div>
                                                    <div class="btn-icon-back dashboard-icons"
                                                         style="background-image: url('../img/icons/doctors-hover.svg');"></div>
                                                </div>
                                            </td>
                                            <td style="width: 25%;">
                                                <div class="dashboard-items"
                                                     style="padding:20px;margin:auto;width:95%;display: flex;">
                                                    <div>
                                                        <div class="h1-dashboard"><%= patientCount %>
                                                        </div>
                                                        <br>
                                                        <div class="h3-dashboard">All Clients &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</div>
                                                    </div>
                                                    <div class="btn-icon-back dashboard-icons"
                                                         style="background-image: url('../img/icons/patients-hover.svg');"></div>
                                                </div>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td style="width: 25%;">
                                                <div class="dashboard-items"
                                                     style="padding:20px;margin:auto;width:95%;display: flex; ">
                                                    <div>
                                                        <div class="h1-dashboard"><%= appointmentCount %>
                                                        </div>
                                                        <br>
                                                        <div class="h3-dashboard">New Booking &nbsp;&nbsp;</div>
                                                    </div>
                                                    <div class="btn-icon-back dashboard-icons"
                                                         style="margin-left: 0px;background-image: url('../img/icons/book-hover.svg');"></div>
                                                </div>
                                            </td>
                                            <td style="width: 25%;">
                                                <div class="dashboard-items"
                                                     style="padding:20px;margin:auto;width:95%;display: flex;padding-top:21px;padding-bottom:21px;">
                                                    <div>
                                                        <div class="h1-dashboard"><%= scheduleCount %>
                                                        </div>
                                                        <br>
                                                        <div class="h3-dashboard" style="font-size: 15px">Today
                                                            Sessions
                                                        </div>
                                                    </div>
                                                    <div class="btn-icon-back dashboard-icons"
                                                         style="background-image: url('../img/icons/session-iceblue.svg');"></div>
                                                </div>
                                            </td>
                                        </tr>
                                    </table>
                                </center>
                            </td>
                            <td>
                                <p style="font-size: 20px;font-weight:600;padding-left: 40px;" class="anime">Your
                                    Upcoming Booking</p>
                                <center>
                                    <div class="abc scroll" style="height: 250px;padding: 0;margin: 0;">
                                        <table width="85%" class="sub-table scrolldown" border="0">
                                            <thead>
                                            <tr>
                                                <th class="table-headin">Appoint. Number</th>
                                                <th class="table-headin">Session Title</th>
                                                <th class="table-headin">Therapist</th>
                                                <th class="table-headin">Scheduled Date & Time</th>
                                            </tr>
                                            </thead>
                                            <tbody>
                                            <%
                                                if (upcomingBookings.isEmpty()) {
                                            %>
                                            <tr>
                                                <td colspan="4"><br><br><br><br>
                                                    <center>
                                                        <img src="../img/notfound.svg" width="25%"><br>
                                                        <p class="heading-main12"
                                                           style="margin-left: 45px;font-size:20px;color:rgb(49, 49, 49)">
                                                            Nothing to show here!</p>
                                                        <a class="non-style-link" href="schedule.jsp">
                                                            <button class="login-btn btn-primary-soft btn"
                                                                    style="display: flex;justify-content: center;align-items: center;margin-left:20px;">
                                                                &nbsp; Channel a Therapist &nbsp;
                                                            </button>
                                                        </a>
                                                    </center>
                                                    <br><br><br><br></td>
                                            </tr>
                                            <%
                                            } else {
                                                for (Map<String, Object> booking : upcomingBookings) {
                                                    String displayTime = "";
                                                    try {
                                                        String timeStr = (String) booking.get("scheduletime");
                                                        if (timeStr != null)
                                                            displayTime = displayTimeFormat.format(dbTimeFormat.parse(timeStr));
                                                    } catch (ParseException e) {
                                                        displayTime = safeSubstring((String) booking.get("scheduletime"), 0, 5);
                                                    }
                                            %>
                                            <tr>
                                                <td style="padding:30px;font-size:25px;font-weight:700; text-align:center;"><%= booking.get("apponum") %>
                                                </td>
                                                <td style="padding:20px;">
                                                    &nbsp;<%= safeSubstring((String) booking.get("title"), 0, 30) %>
                                                </td>
                                                <td><%= safeSubstring((String) booking.get("docname"), 0, 20) %>
                                                </td>
                                                <td style="text-align:center;"><%= booking.get("scheduledate") %> <%= displayTime %>
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
//        closeQuietly(rsUser);
//        closeQuietly(psUser);
        closeQuietly(connection);
    }
%>
</body>
</html>
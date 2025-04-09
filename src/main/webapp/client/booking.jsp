<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page
        import="java.sql.*, java.util.*, java.text.*, java.time.LocalDate, java.time.format.DateTimeFormatter, java.net.URLEncoder" %>
<%@ page import="java.util.Date" %>
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
    String pageErrorMessage = null;
    String bookStatus = null;

    Map<String, Object> sessionData = null;
    int calculatedAppoNum = 0;
    boolean sessionFull = false;
    boolean alreadyBooked = false;
    int scheduleId = 0;

    String today = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd"));
    SimpleDateFormat displayTimeFormat = new SimpleDateFormat("HH:mm");
    SimpleDateFormat dbTimeFormat = new SimpleDateFormat("HH:mm:ss");

    String errorMessage;
    try {
        Class.forName("com.mysql.cj.jdbc.Driver");
        connection = DriverManager.getConnection(url, dbUser, dbPassword);
        connection.setAutoCommit(false);

        ps = connection.prepareStatement("SELECT pid, pname FROM patient WHERE pemail = ?");
        ps.setString(1, useremail);
        rs = ps.executeQuery();
        if (rs.next()) {
            patientId = rs.getInt("pid");
            patientName = rs.getString("pname");
        } else {
            throw new Exception("Patient user not found in database.");
        }
        closeQuietly(rs);
        closeQuietly(ps);


        if ("confirm-booking".equals(request.getParameter("action")) && "POST".equalsIgnoreCase(request.getMethod())) {
            String scheduleIdStr = request.getParameter("scheduleid");
            String appoNumStr = request.getParameter("apponum");
            String bookDate = request.getParameter("date");

            int bookScheduleId = 0;
            int bookAppoNum = 0;
            boolean inputError = false;
            int newAppointmentId = -1;

            try {
                bookScheduleId = Integer.parseInt(scheduleIdStr);
                bookAppoNum = Integer.parseInt(appoNumStr);
                if (isNullOrEmpty(bookDate)) throw new Exception("Booking date missing");
            } catch (Exception e) {
                pageErrorMessage = "Invalid booking data submitted.";
                inputError = true;
            }

            if (!inputError) {
                PreparedStatement psCheckBooked = null;
                ResultSet rsCheckBooked = null;
                PreparedStatement psCheckFull = null;
                ResultSet rsCheckFull = null;
                PreparedStatement psInsert = null;
                ResultSet generatedKeys = null;
                PreparedStatement psUpdateLink = null;

                try {
                    psCheckBooked = connection.prepareStatement("SELECT COUNT(*) FROM appointment WHERE scheduleid = ? AND pid = ?");
                    psCheckBooked.setInt(1, bookScheduleId);
                    psCheckBooked.setInt(2, patientId);
                    rsCheckBooked = psCheckBooked.executeQuery();
                    if (rsCheckBooked.next() && rsCheckBooked.getInt(1) > 0) {
                        pageErrorMessage = "You already have an appointment for this session.";
                        alreadyBooked = true;
                    }
                    closeQuietly(rsCheckBooked);
                    closeQuietly(psCheckBooked);

                    if (!alreadyBooked) {
                        psCheckFull = connection.prepareStatement("SELECT nop, (SELECT COUNT(*) FROM appointment WHERE scheduleid = ?) as booked FROM schedule WHERE scheduleid = ?");
                        psCheckFull.setInt(1, bookScheduleId);
                        psCheckFull.setInt(2, bookScheduleId);
                        rsCheckFull = psCheckFull.executeQuery();
                        if (rsCheckFull.next()) {
                            int nop = rsCheckFull.getInt("nop");
                            int booked = rsCheckFull.getInt("booked");
                            if (booked >= nop) {
                                pageErrorMessage = "Sorry, this session is already full.";
                                sessionFull = true;
                            }
                        } else {
                            pageErrorMessage = "Could not verify session capacity.";
                            sessionFull = true;
                        }
                        closeQuietly(rsCheckFull);
                        closeQuietly(psCheckFull);
                    }

                    if (!alreadyBooked && !sessionFull) {
                        psInsert = connection.prepareStatement(
                                "INSERT INTO appointment (pid, apponum, scheduleid, appodate) VALUES (?, ?, ?, ?)",
                                Statement.RETURN_GENERATED_KEYS
                        );
                        psInsert.setInt(1, patientId);
                        psInsert.setInt(2, bookAppoNum);
                        psInsert.setInt(3, bookScheduleId);
                        psInsert.setString(4, bookDate);
                        int rowsAffected = psInsert.executeUpdate();

                        if (rowsAffected > 0) {
                            generatedKeys = psInsert.getGeneratedKeys();
                            if (generatedKeys.next()) {
                                newAppointmentId = generatedKeys.getInt(1);
                            }
                            closeQuietly(generatedKeys);

                            if (newAppointmentId > 0) {
                                String uniquePart = "PsychCare-" +
                                        new SimpleDateFormat("yyyyMMdd-HHmmss").format(new Date()) + "-" +
                                        String.format("%04d", newAppointmentId);
                                String meetingLink = "https://meet.jit.si/" + uniquePart;

                                psUpdateLink = connection.prepareStatement("UPDATE appointment SET meeting_link = ? WHERE appoid = ?");
                                psUpdateLink.setString(1, meetingLink);
                                psUpdateLink.setInt(2, newAppointmentId);
                                int updateRows = psUpdateLink.executeUpdate();

                                if (updateRows > 0) {
                                    connection.commit();
                                    response.sendRedirect("appointment.jsp?book_status=success");
                                    return;
                                } else {
                                    connection.rollback();
                                    pageErrorMessage = "Booking created, but failed to save meeting link.";
                                }
                            } else {
                                connection.rollback();
                                pageErrorMessage = "Booking failed (could not retrieve booking ID).";
                            }
                        } else {
                            connection.rollback();
                            pageErrorMessage = "Booking failed. Please try again.";
                        }
                    } else {
                        connection.rollback();
                    }

                } catch (SQLException e) {
                    connection.rollback();
                    pageErrorMessage = "Database error during booking: " + e.getMessage();
                    e.printStackTrace();
                } finally {
                    closeQuietly(rsCheckBooked);
                    closeQuietly(psCheckBooked);
                    closeQuietly(rsCheckFull);
                    closeQuietly(psCheckFull);
                    closeQuietly(generatedKeys);
                    closeQuietly(psInsert);
                    closeQuietly(psUpdateLink);
                }
            }
            scheduleId = bookScheduleId;
        } else {
            String sessionIdStr = request.getParameter("id");
            if (isNullOrEmpty(sessionIdStr)) {
                throw new Exception("Session ID is missing from the request.");
            }
            try {
                scheduleId = Integer.parseInt(sessionIdStr);
            } catch (NumberFormatException e) {
                throw new Exception("Invalid Session ID format.");
            }
        }


        if (scheduleId > 0) {
            String sqlSessionDetails = "SELECT schedule.*, doctor.docname, doctor.docemail FROM schedule INNER JOIN doctor ON schedule.docid=doctor.docid WHERE schedule.scheduleid = ?";
            ps = connection.prepareStatement(sqlSessionDetails);
            ps.setInt(1, scheduleId);
            rs = ps.executeQuery();

            if (rs.next()) {
                sessionData = new HashMap<>();
                sessionData.put("scheduleid", rs.getInt("scheduleid"));
                sessionData.put("title", rs.getString("title"));
                sessionData.put("docname", rs.getString("docname"));
                sessionData.put("docemail", rs.getString("docemail"));
                sessionData.put("scheduledate", rs.getString("scheduledate"));
                sessionData.put("scheduletime", rs.getString("scheduletime"));
                sessionData.put("nop", rs.getInt("nop"));
            } else {
                if (pageErrorMessage == null)
                    pageErrorMessage = "Selected session not found or is no longer available.";
            }
            closeQuietly(rs);
            closeQuietly(ps);

            if (sessionData != null) {
                ps = connection.prepareStatement("SELECT COUNT(*) FROM appointment WHERE scheduleid = ?");
                ps.setInt(1, scheduleId);
                rs = ps.executeQuery();
                if (rs.next()) {
                    calculatedAppoNum = rs.getInt(1) + 1;
                }
                closeQuietly(rs);
                closeQuietly(ps);

                if (calculatedAppoNum > (Integer) sessionData.get("nop")) {
                    sessionFull = true;
                    if (pageErrorMessage == null) pageErrorMessage = "Sorry, this session is already full.";
                }

                ps = connection.prepareStatement("SELECT COUNT(*) FROM appointment WHERE scheduleid = ? AND pid = ?");
                ps.setInt(1, scheduleId);
                ps.setInt(2, patientId);
                rs = ps.executeQuery();
                if (rs.next() && rs.getInt(1) > 0) {
                    alreadyBooked = true;
                    if (pageErrorMessage == null)
                        pageErrorMessage = "You already have an appointment for this session.";
                }
                closeQuietly(rs);
                closeQuietly(ps);
            }
        } else {
            if (pageErrorMessage == null) pageErrorMessage = "No session ID provided.";
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
    <title>Booking</title>
    <style>
        .popup {
            animation: transitionIn-Y-bottom 0.5s;
        }

        .sub-table {
            animation: transitionIn-Y-bottom 0.5s;
        }

        .info-message {
            padding: 10px 15px;
            margin: 10px 45px;
            border-radius: 5px;
            text-align: center;
            font-weight: 500;
            border: 1px solid;
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
                <td class="menu-btn menu-icon-home"><a href="index.jsp" class="non-style-link-menu">
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
    <div class="dash-body">
        <table border="0" width="100%" style=" border-spacing: 0;margin:0;padding:0;margin-top:25px;">
            <tr>
                <td width="13%"><a href="schedule.jsp">
                    <button class="login-btn btn-primary-soft btn btn-icon-back"
                            style="padding-top:11px;padding-bottom:11px;margin-left:20px;width:140px"><font
                            class="tn-in-text">Back</font></button>
                </a></td>
                <td><p style="font-size: 23px;padding-left:12px;font-weight: 600;">Booking Confirmation</p></td>
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
            <% if (pageErrorMessage != null) { %>
            <tr>
                <td colspan="4">
                    <div class="info-message error"><%= pageErrorMessage %>
                    </div>
                </td>
            </tr>
            <% } %>
            <tr>
                <td colspan="4">
                    <center>
                        <div class="abc scroll">
                            <table width="100%" class="sub-table scrolldown" border="0"
                                   style="padding: 50px;border:none">
                                <tbody>
                                    <% if (sessionData != null) {
                                    String title = (String) sessionData.get("title");
                                    String docname = (String) sessionData.get("docname");
                                    String docemail = (String) sessionData.get("docemail");
                                    String scheduledate = (String) sessionData.get("scheduledate");
                                    String scheduletime = (String) sessionData.get("scheduletime");
                                    String displayTime = "";
                                    try { if(scheduletime != null) displayTime = displayTimeFormat.format(dbTimeFormat.parse(scheduletime));}
                                    catch (ParseException e) { displayTime = safeSubstring(scheduletime,0,5); }
                                %>
                                <form action="booking.jsp?action=confirm-booking" method="post">
                                    <input type="hidden" name="scheduleid" value="<%= sessionData.get("scheduleid") %>">
                                    <input type="hidden" name="apponum" value="<%= calculatedAppoNum %>">
                                    <input type="hidden" name="date" value="<%= today %>">
                                    <tr>
                                        <td style="width: 50%;" rowspan="2">
                                            <div class="dashboard-items search-items">
                                                <div style="width:100%">
                                                    <div class="h1-search" style="font-size:25px;">Session Details</div>
                                                    <br><br>
                                                    <div class="h3-search" style="font-size:18px;line-height:30px">
                                                        Therapist name: &nbsp;&nbsp;<b><%= docname %>
                                                    </b><br>
                                                        Therapist Email: &nbsp;&nbsp;<b><%= docemail %>
                                                    </b>
                                                    </div>
                                                    <br>
                                                    <div class="h3-search" style="font-size:18px;">
                                                        Session Title: <%= title %><br>
                                                        Session Scheduled Date: <%= scheduledate %><br>
                                                        Session Starts : <%= displayTime %> (24h)<br>
                                                        Channeling fee : <b>10 AZN</b>
                                                    </div>
                                                    <br>
                                                </div>
                                            </div>
                                        </td>
                                        <td style="width: 25%;">
                                            <div class="dashboard-items search-items">
                                                <div style="width:100%;padding-top: 15px;padding-bottom: 15px;">
                                                    <div class="h1-search"
                                                         style="font-size:20px;line-height: 35px;margin-left:8px;text-align:center;">
                                                        Your Appointment Number
                                                    </div>
                                                    <center>
                                                        <div class="dashboard-icons"
                                                             style="margin-left: 0px;width:90%;font-size:70px;font-weight:800;text-align:center;color:var(--btnnicetext);background-color: var(--btnice)"><%= calculatedAppoNum %>
                                                        </div>
                                                    </center>
                                                </div>
                                                <br><br>
                                            </div>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td>
                                            <input type="Submit" class="login-btn btn-primary btn btn-book"
                                                   style="margin-left:10px;padding-left: 25px;padding-right: 25px;padding-top: 10px;padding-bottom: 10px;width:95%;text-align: center;"
                                                   value="Book now"
                                                   name="booknow" <%= (sessionFull || alreadyBooked) ? "disabled title='Session full or already booked'" : "" %>>
                                        </td>
                                </form>
            </tr>
            <% } else { %>
            <tr>
                <td colspan="4"><br><br><br><br>
                    <center>
                        <img src="../img/notfound.svg" width="25%"><br>
                        <p class="heading-main12" style="margin-left: 45px;font-size:20px;color:rgb(49, 49, 49)">
                            <%= pageErrorMessage != null ? pageErrorMessage : "Could not find the requested session." %>
                        </p>
                        <a class="non-style-link" href="schedule.jsp">
                            <button class="login-btn btn-primary-soft btn"
                                    style="display: flex;justify-content: center;align-items: center;margin-left:20px;">
                                &nbsp; Find Another Session &nbsp;
                            </button>
                        </a>
                    </center>
                    <br><br><br><br></td>
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
<%
    } catch (ClassNotFoundException e) {
        errorMessage = "Database Driver not found.";
        e.printStackTrace();
        System.out.println("<div class='info-message error'>CRITICAL ERROR: Database Driver not found. " + e.getMessage() + "</div>");
    } catch (SQLException e) {
        errorMessage = "Database Error: " + e.getMessage();
        if (connection != null) {
            try {
                if (!connection.getAutoCommit()) connection.rollback();
            } catch (SQLException re) {
            }
        }
        e.printStackTrace();
        System.out.println("<div class='info-message error'>DATABASE ERROR: " + e.getMessage() + " (SQLState: " + e.getSQLState() + ")</div>");
    } catch (Exception e) {
        errorMessage = "An unexpected error occurred: " + e.getMessage();
        if (connection != null) {
            try {
                if (!connection.getAutoCommit()) connection.rollback();
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
        closeQuietly(connection);
    }
%>
</body>
</html>
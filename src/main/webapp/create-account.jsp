<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*, java.util.*, javax.servlet.http.*, javax.servlet.*" %>
<%@ page import="com.google.common.hash.Hashing" %>
<%@ page import="java.nio.charset.StandardCharsets" %>
<%@ page import="org.apache.commons.text.StringEscapeUtils" %>
<%@ page session="true" %>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/animations.css">
    <link rel="stylesheet" href="css/main.css">
    <link rel="stylesheet" href="css/signup.css">

    <title>Create Account</title>
    <style>
        .container {
            animation: transitionIn-X 0.5s;
        }
    </style>
</head>
<body>

<%!
    private String escapeHtml(String input) {
        if (input == null) return "";
        return StringEscapeUtils.escapeHtml4(input);
    }
%>

<%
    String error = "";
    HashMap<String, String> personalDetails = (HashMap<String, String>) session.getAttribute("personal");
    String fname = personalDetails != null ? personalDetails.get("fname") : "";
    String lname = personalDetails != null ? personalDetails.get("lname") : "";
    String name = fname + " " + lname;
    String address = personalDetails != null ? personalDetails.get("address") : "";
    String nic = personalDetails != null ? personalDetails.get("nic") : "";
    String dob = personalDetails != null ? personalDetails.get("dob") : "";

    String newEmail = request.getParameter("newemail");
    newEmail = escapeHtml(newEmail);
    String tele = request.getParameter("tele");
    tele = escapeHtml(tele);
    String newPassword = request.getParameter("newpassword");
    newPassword = escapeHtml(newPassword);
    String confirmPassword = request.getParameter("cpassword");
    confirmPassword = escapeHtml(confirmPassword);

    if (newEmail != null && tele != null && newPassword != null && confirmPassword != null) {
        if (newPassword.equals(confirmPassword)) {
            String hashedPassword = Hashing.sha256().hashString(newPassword, StandardCharsets.UTF_8).toString();
            try {
                Class.forName("com.mysql.cj.jdbc.Driver");
                Connection conn = DriverManager.getConnection(System.getenv("DB_URL"), System.getenv("DB_USER"), System.getenv("DB_PASSWORD"));

                String sql = "SELECT * FROM webuser WHERE email=?";
                PreparedStatement stmt = conn.prepareStatement(sql);
                stmt.setString(1, newEmail);
                ResultSet rs = stmt.executeQuery();

                if (rs.next()) {
                    error = "Already have an account for this Email address.";
                } else {
                    sql = "INSERT INTO patient (pemail, pname, ppassword, paddress, pnic, pdob, ptel) VALUES (?, ?, ?, ?, ?, ?, ?)";
                    stmt = conn.prepareStatement(sql);
                    stmt.setString(1, newEmail);
                    stmt.setString(2, name);
                    stmt.setString(3, hashedPassword);
                    stmt.setString(4, address);
                    stmt.setString(5, nic);
                    stmt.setString(6, dob);
                    stmt.setString(7, tele);
                    stmt.executeUpdate();

                    sql = "INSERT INTO webuser (email, usertype) VALUES (?, 'p')";
                    stmt = conn.prepareStatement(sql);
                    stmt.setString(1, newEmail);
                    stmt.executeUpdate();

                    session.setAttribute("user", newEmail);
                    session.setAttribute("usertype", "p");
                    session.setAttribute("username", fname);

                    response.sendRedirect("client/index.jsp");
                }

                conn.close();

            } catch (SQLException e) {
                e.printStackTrace();
                error = "Database error, please try again later.";
            }
        } else {
            error = "Password Confirmation Error! Please re-confirm your password.";
        }
    }
%>

<center>
    <div class="container">
        <table border="0" style="width: 69%;">
            <tr>
                <td colspan="2">
                    <p class="header-text">Let's Get Started</p>
                    <p class="sub-text">It's Okey, Now Create User Account.</p>
                </td>
            </tr>
            <form action="" method="POST">
                <tr>
                    <td class="label-td" colspan="2">
                        <%--@declare id="newemail"--%><label for="newemail" class="form-label">Email: </label>
                    </td>
                </tr>
                <tr>
                    <td class="label-td" colspan="2">
                        <input type="email" name="newemail" class="input-text" placeholder="Email Address" required>
                    </td>
                </tr>
                <tr>
                    <td class="label-td" colspan="2">
                        <%--@declare id="tele"--%><label for="tele" class="form-label">Mobile Number: </label>
                    </td>
                </tr>
                <tr>
                    <td class="label-td" colspan="2">
                        <input type="tel" name="tele" class="input-text" placeholder="ex: 0712345678"
                               pattern="[0]{1}[0-9]{9}">
                    </td>
                </tr>
                <tr>
                    <td class="label-td" colspan="2">
                        <%--@declare id="newpassword"--%><label for="newpassword" class="form-label">Create New
                        Password: </label>
                    </td>
                </tr>
                <tr>
                    <td class="label-td" colspan="2">
                        <input type="password" name="newpassword" class="input-text" placeholder="New Password"
                               required>
                    </td>
                </tr>
                <tr>
                    <td class="label-td" colspan="2">
                        <%--@declare id="cpassword"--%><label for="cpassword" class="form-label">Confirm
                        Password: </label>
                    </td>
                </tr>
                <tr>
                    <td class="label-td" colspan="2">
                        <input type="password" name="cpassword" class="input-text" placeholder="Confirm Password"
                               required>
                    </td>
                </tr>

                <tr>
                    <td colspan="2" style="color:rgb(255, 62, 62); text-align:center;">
                        <%= error %>
                    </td>
                </tr>

                <tr>
                    <td>
                        <input type="reset" value="Reset" class="login-btn btn-primary-soft btn">
                    </td>
                    <td>
                        <input type="submit" value="Sign Up" class="login-btn btn-primary btn">
                    </td>
                </tr>

                <tr>
                    <td colspan="2">
                        <%--@declare id=""--%><br>
                        <label for="" class="sub-text" style="font-weight: 280;">Already have an account&#63; </label>
                        <a href="login.jsp" class="hover-link1 non-style-link">Login</a>
                        <br><br><br>
                    </td>
                </tr>
            </form>
        </table>
    </div>
</center>

</body>
</html>
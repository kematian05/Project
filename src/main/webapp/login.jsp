<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.*, javax.servlet.http.*, javax.servlet.*" %>
<%@ page import="static java.security.spec.MGF1ParameterSpec.SHA256" %>
<%@ page import="java.nio.charset.StandardCharsets" %>
<%@ page import="com.google.common.hash.Hashing" %>
<%@ page session="true" %>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/animations.css">
    <link rel="stylesheet" href="css/main.css">
    <link rel="stylesheet" href="css/login.css">

    <title>Login</title>
</head>
<body>

<%
    String error = "";
    String useremail = request.getParameter("useremail");
    String password = request.getParameter("userpassword");

    if (useremail != null && password != null) {
        String hashedPassword = Hashing.sha256().hashString(password, StandardCharsets.UTF_8).toString();
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            String dbURL = System.getenv("DB_URL");
            String dbUsername = System.getenv("DB_USER");
            String dbPassword = System.getenv("DB_PASSWORD");
            Connection conn = DriverManager.getConnection(dbURL, dbUsername, dbPassword);

            String sql = "SELECT * FROM webuser WHERE email=?";
            PreparedStatement stmt = conn.prepareStatement(sql);
            stmt.setString(1, useremail);
            ResultSet rs = stmt.executeQuery();

            if (rs.next()) {
                String utype = rs.getString("usertype");
                if ("p".equals(utype)) {
                    sql = "SELECT * FROM patient WHERE pemail=? AND ppassword=?";
                    stmt = conn.prepareStatement(sql);
                    stmt.setString(1, useremail);
                    stmt.setString(2, hashedPassword);
                    ResultSet patientResult = stmt.executeQuery();
                    if (patientResult.next()) {
                        session.setAttribute("user", useremail);
                        session.setAttribute("usertype", "p");
                        response.sendRedirect("client/index.jsp");
                    } else {
                        error = "Wrong credentials: Invalid email or password";
                    }
                } else if ("a".equals(utype)) {
                    sql = "SELECT * FROM admin WHERE aemail=? AND apassword=?";
                    stmt = conn.prepareStatement(sql);
                    stmt.setString(1, useremail);
                    stmt.setString(2, hashedPassword);
                    ResultSet adminResult = stmt.executeQuery();
                    if (adminResult.next()) {
                        session.setAttribute("user", useremail);
                        session.setAttribute("usertype", "a");
                        response.sendRedirect("admin/index.jsp");
                    } else {
                        error = "Wrong credentials: Invalid email or password";
                    }
                } else if ("d".equals(utype)) {
                    sql = "SELECT * FROM doctor WHERE docemail=? AND docpassword=?";
                    stmt = conn.prepareStatement(sql);
                    stmt.setString(1, useremail);
                    stmt.setString(2, hashedPassword);
                    ResultSet doctorResult = stmt.executeQuery();
                    if (doctorResult.next()) {
                        session.setAttribute("user", useremail);
                        session.setAttribute("usertype", "d");
                        response.sendRedirect("therapist/index.jsp");
                    } else {
                        error = "Wrong credentials: Invalid email or password";
                    }
                }
            } else {
                error = "We can't find any account for this email.";
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

%>

<center>
    <div class="container">
        <table border="0" style="margin: 0;padding: 0;width: 60%;">
            <tr>
                <td>
                    <p class="header-text">Welcome Back!</p>
                </td>
            </tr>
            <div class="form-body">
                <tr>
                    <td>
                        <p class="sub-text">Login with your details to continue</p>
                    </td>
                </tr>
                <tr>
                    <form action="" method="POST">
                        <td class="label-td">
                            <%--@declare id="useremail"--%><label for="useremail" class="form-label">Email: </label>
                        </td>
                </tr>
                <tr>
                    <td class="label-td">
                        <input type="email" name="useremail" class="input-text" placeholder="Email Address" required>
                    </td>
                </tr>
                <tr>
                    <td class="label-td">
                        <%--@declare id="userpassword"--%><label for="userpassword"
                                                                 class="form-label">Password: </label>
                    </td>
                </tr>

                <tr>
                    <td class="label-td">
                        <input type="Password" name="userpassword" class="input-text" placeholder="Password" required>
                    </td>
                </tr>

                <tr>
                    <td><%--@declare id="promter"--%><br>
                        <label for="promter" class="form-label" style="color:rgb(255, 62, 62);text-align:center;">
                            <%= error %>
                        </label>
                    </td>
                </tr>

                <tr>
                    <td>
                        <input type="submit" value="Login" class="login-btn btn-primary btn">
                    </td>
                </tr>
            </div>
            <tr>
                <td>
                    <%--@declare id=""--%><br>
                    <label for="" class="sub-text" style="font-weight: 280;">Don't have an account&#63; </label>
                    <a href="signup.jsp" class="hover-link1 non-style-link">Sign Up</a>
                    <br><br><br>
                </td>
            </tr>

            </form>
        </table>
    </div>
</center>
</body>
</html>

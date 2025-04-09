<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.util.*, javax.servlet.http.*, javax.servlet.*" %>
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

    <title>Sign Up</title>
</head>
<body>
<%!
    private String escapeHtml(String input) {
        if (input == null) return null;
        return StringEscapeUtils.escapeHtml4(input);
    }
%>

<%
    if (request.getMethod().equalsIgnoreCase("POST")) {
        HashMap<String, String> personalDetails = new HashMap<>();
        personalDetails.put("fname", escapeHtml(request.getParameter("fname")));
        personalDetails.put("lname", escapeHtml(request.getParameter("lname")));
        personalDetails.put("address", escapeHtml(request.getParameter("address")));
        personalDetails.put("nic", escapeHtml(request.getParameter("nic")));
        personalDetails.put("dob", escapeHtml(request.getParameter("dob")));
        session.setAttribute("personal", personalDetails);

        response.sendRedirect("create-account.jsp");
    }
%>

<center>
    <div class="container">
        <table border="0">
            <tr>
                <td colspan="2">
                    <p class="header-text">Let's Get Started</p>
                    <p class="sub-text">Add Your Personal Details to Continue</p>
                </td>
            </tr>
            <form action="" method="POST">
                <tr>
                    <td class="label-td" colspan="2">
                        <%--@declare id="name"--%><label for="name" class="form-label">Name: </label>
                    </td>
                </tr>
                <tr>
                    <td class="label-td">
                        <input type="text" name="fname" class="input-text" placeholder="First Name" required>
                    </td>
                    <td class="label-td">
                        <input type="text" name="lname" class="input-text" placeholder="Last Name" required>
                    </td>
                </tr>
                <tr>
                    <td class="label-td" colspan="2">
                        <%--@declare id="address"--%><label for="address" class="form-label">Address: </label>
                    </td>
                </tr>
                <tr>
                    <td class="label-td" colspan="2">
                        <input type="text" name="address" class="input-text" placeholder="Address" required>
                    </td>
                </tr>
                <tr>
                    <td class="label-td" colspan="2">
                        <%--@declare id="nic"--%><label for="nic" class="form-label">NIC: </label>
                    </td>
                </tr>
                <tr>
                    <td class="label-td" colspan="2">
                        <input type="text" name="nic" class="input-text" placeholder="NIC Number" required>
                    </td>
                </tr>
                <tr>
                    <td class="label-td" colspan="2">
                        <%--@declare id="dob"--%><label for="dob" class="form-label">Date of Birth: </label>
                    </td>
                </tr>
                <tr>
                    <td class="label-td" colspan="2">
                        <input type="date" name="dob" class="input-text" required>
                    </td>
                </tr>
                <tr>
                    <td class="label-td" colspan="2">
                    </td>
                </tr>

                <tr>
                    <td>
                        <input type="reset" value="Reset" class="login-btn btn-primary-soft btn">
                    </td>
                    <td>
                        <input type="submit" value="Next" class="login-btn btn-primary btn">
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

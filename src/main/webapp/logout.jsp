<%@ page import="javax.servlet.http.Cookie" %>
<%@ page import="java.sql.*" %>
<%@ page import="java.util.Objects" %>
<%--<%@ page session="false" %>--%>
<%@ page contentType="text/html;charset=UTF-8" %>
<%
    session.invalidate();

    Cookie sessionCookie = new Cookie("JSESSIONID", "");
    sessionCookie.setMaxAge(0);
    sessionCookie.setPath(request.getContextPath());
    response.addCookie(sessionCookie);

    response.sendRedirect("login.jsp?action=logout");
%>

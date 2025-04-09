<%@ page contentType="text/html; charset=UTF-8" language="java" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="css/animations.css">
    <link rel="stylesheet" href="css/main.css">
    <link rel="stylesheet" href="css/index.css">
    <title>Psychological Appointment</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f0f8ff;
            margin: 0;
            padding: 0;
        }
        .container {
            width: 100%;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
        }
        .header {
            text-align: center;
            margin-bottom: 20px;
        }
        .header .app-logo {
            font-size: 36px;
            font-weight: bold;
            color: #0044cc;
        }
        .header .app-logo-sub {
            font-size: 18px;
            color: #666;
        }
        .content {
            text-align: center;
            max-width: 600px;
        }
        .buttons {
            margin-top: 20px;
        }
        .btn {
            padding: 12px 20px;
            font-size: 16px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            margin: 5px;
        }
        .btn-primary {
            background-color: #0044cc;
            color: white;
        }
        .btn-secondary {
            background-color: #f0f0f0;
            color: #333;
        }
        .footer {
            margin-top: 30px;
            font-size: 14px;
            color: #666;
        }
    </style>
</head>
<body>
<div class="container">
    <div class="header">
        <span class="app-logo">PsychCare</span>
<%--        <span class="app-logo-sub"> | Your Psychological Well-being Partner</span>--%>
    </div>
    <div class="content">
        <h2>Your Mental Health Matters</h2>
        <p>Feeling overwhelmed or stressed? You're not alone.<br>
            Find professional psychological support with PsychCare.<br>
            Book an appointment with experienced psychologists at your convenience.</p>
        <div class="buttons">
            <a href="login.jsp"><button class="btn btn-primary">Book an Appointment</button></a>
            <a href="signup.jsp"><button class="btn btn-secondary">Register</button></a>
        </div>
    </div>
<%--    <div class="footer">A Web Solution for Psychological Care.</div>--%>
</div>
</body>
</html>

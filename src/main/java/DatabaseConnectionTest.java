import java.sql.*;

public class DatabaseConnectionTest {
    public static void main(String[] args) {
        String dbURL = System.getenv("DB_URL");
        String dbUsername = "root";
        String dbPassword = "1234";

        try {
            // Establish connection
            Connection conn = DriverManager.getConnection(dbURL, dbUsername, dbPassword);
            if (conn != null) {
                System.out.println("Successfully connected to the database.");
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }
}

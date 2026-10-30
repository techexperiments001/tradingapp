package com.cloudfrm.trading.reports;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

/**
 * Builds the database state the mainframe report in {@code output/} was printed from.
 *
 * <p>The H2 database shipped in {@code db2/portable-db2-h2/} is the state <em>before</em> a
 * run: every order is still {@code ORD_STATUS='101'}, and its quantities and amounts differ
 * in the cents from the ones in the reference report, so the two artifacts are not from the
 * same run. To get a byte comparable fixture, the three run dependent columns
 * ({@code ORD_STATUS}, {@code ORD_QUANTITY}, {@code ORD_AMOUNT}) are replayed onto a copy of
 * the database from the reference report itself; everything the report is diffed on beyond
 * those three columns — the customer and security master data, the self join, the ordering,
 * the pagination and the formatting — still comes from the database and the port.
 */
final class GoldenReportFixture {

    record ReportedOrder(String customerId, String buySell, String status, String tradeIdPrefix,
                         String figi, BigDecimal quantity, BigDecimal amount) {
    }

    private GoldenReportFixture() {
    }

    /** Walks up from the working directory to the repository root. */
    static Path repositoryRoot() {
        Path candidate = Path.of("").toAbsolutePath();
        while (candidate != null && !Files.isDirectory(candidate.resolve("cobol"))) {
            candidate = candidate.getParent();
        }
        if (candidate == null) {
            throw new IllegalStateException("Cannot locate the repository root from " + Path.of("").toAbsolutePath());
        }
        return candidate;
    }

    static Path goldenReport() {
        return repositoryRoot().resolve("output/CLOUDFRM.TRADING.BATCHDB2.REPORDER.REPORT.MF");
    }

    static List<String> goldenLines() {
        try {
            return Files.readAllLines(goldenReport(), StandardCharsets.ISO_8859_1);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    /** Reconstructs one {@link ReportedOrder} per detail line of the reference report. */
    static List<ReportedOrder> parse(List<String> lines) {
        List<ReportedOrder> orders = new ArrayList<>();
        String customerId = null;
        String buySell = null;
        String status = null;
        for (String line : lines) {
            if (line.startsWith("1")) {
                buySell = line.startsWith(" Buy", 56) ? "B" : "S";
                customerId = line.substring(88, 100);
            } else if (line.startsWith("0Order Status : ")) {
                status = line.substring(16, 19);
            } else if (line.startsWith(" |") && Character.isDigit(line.charAt(2))) {
                orders.add(new ReportedOrder(
                        customerId,
                        buySell,
                        status,
                        line.substring(2, 12),
                        line.substring(39, 51),
                        number(line.substring(130, 142)),
                        number(line.substring(147, 159))));
            }
        }
        return orders;
    }

    private static BigDecimal number(String edited) {
        return new BigDecimal(edited.replace(",", "").trim());
    }

    /** Copies the shipped database and replays the reported status, quantity and amount onto it. */
    static Path buildDatabase(Path workingDirectory, List<ReportedOrder> orders) throws IOException, SQLException {
        Path database = workingDirectory.resolve("Trade-db.mv.db");
        Files.copy(repositoryRoot().resolve("db2/portable-db2-h2/Trade-db.mv.db"), database);
        String url = "jdbc:h2:file:" + workingDirectory.resolve("Trade-db") + ";SCHEMA=TRADE";

        String update = """
                UPDATE TBTRDORD
                   SET ORD_STATUS = ?, ORD_QUANTITY = ?, ORD_AMOUNT = ?
                 WHERE ORD_CUSTOMER_ID  = ?
                   AND ORD_BUY_SELL_IND = ?
                   AND ORD_FIGI         = ?
                   AND ORD_TRADEID LIKE ?
                """;
        try (Connection connection = DriverManager.getConnection(url, "sa", "");
             PreparedStatement statement = connection.prepareStatement(update)) {
            connection.setAutoCommit(false);
            for (ReportedOrder order : orders) {
                statement.setString(1, order.status());
                statement.setBigDecimal(2, order.quantity());
                statement.setBigDecimal(3, order.amount());
                statement.setString(4, order.customerId());
                statement.setString(5, order.buySell());
                statement.setString(6, order.figi());
                statement.setString(7, order.tradeIdPrefix() + "%");
                if (statement.executeUpdate() != 1) {
                    throw new IllegalStateException("Reported order does not match exactly one row: " + order);
                }
            }
            connection.commit();
        }
        return workingDirectory.resolve("Trade-db");
    }
}

package com.cloudfrm.trading.reports.report;

import com.cloudfrm.trading.reports.cobol.Pic;
import com.cloudfrm.trading.reports.domain.TradeOrderRow;
import java.util.Map;

/**
 * The {@code WORKING-STORAGE} print lines of {@code TRDPB006}, field for field.
 *
 * <p>Every literal, {@code FILLER} width and edited picture below is taken from the COBOL,
 * because the output is diffed byte for byte against the mainframe report.
 */
final class ReportLayout {

    private static final Map<String, String> STATUS_DESCRIPTIONS = Map.ofEntries(
            Map.entry("101", "Accepted"),
            Map.entry("201", "Matched"),
            Map.entry("301", "Overdue-Buyer Invld"),
            Map.entry("302", "Overdue-SellerInvld"),
            Map.entry("303", "Overdue-Security"),
            Map.entry("304", "Overdue-Buyer Acct"),
            Map.entry("305", "Overdue-Seller Acct"),
            Map.entry("306", "Overdue-OrderStatus"),
            Map.entry("307", "Overdue-OrderStatus"),
            Map.entry("308", "Overdue-MissingOrdr"),
            Map.entry("401", "Overdue-Rejected"),
            Map.entry("601", "Settled"));

    private ReportLayout() {
    }

    /** {@code WS-EMPTY-HDR}. */
    static String blank() {
        return "";
    }

    /** {@code WS-PAGE-HEADER}. */
    static String pageHeader(TradeOrderRow row, int pageNumber) {
        String title = row.isBuy() ? " Buy Orders Report for Client : " : "Sell Orders Report for Client : ";
        return " ".repeat(55)
                + Pic.x(title, 32)
                + Pic.x(row.customerId(), 12)
                + " : "
                + Pic.x(row.customerDescription(), 30)
                + " ".repeat(17)
                + "Page : "
                + Pic.z(pageNumber, 3);
    }

    /** {@code WS-HEADER1}. */
    static String statusHeader(String status) {
        return "Order Status : "
                + Pic.nine(Long.parseLong(status.trim()), 3)
                + " - "
                + Pic.x(STATUS_DESCRIPTIONS.getOrDefault(status, "Unknown"), 20)
                + " ".repeat(119);
    }

    /** {@code WS-DETAIL-HDR2}. */
    static String rule() {
        return "+" + "-".repeat(10)
                + "+" + "-".repeat(12)
                + "+" + "-".repeat(12)
                + "+" + "-".repeat(12)
                + "+" + "-".repeat(20)
                + "+" + "-".repeat(40)
                + "+" + "-".repeat(15)
                + "+" + "-".repeat(12)
                + "+" + "-".repeat(3)
                + "+" + "-".repeat(12)
                + "+";
    }

    /** {@code WS-DETAIL-HDR1} — the counterparty column is labelled from the other side. */
    static String detailHeader(TradeOrderRow row) {
        return "|" + Pic.x("Trade ID", 10)
                + "|" + Pic.x(row.isBuy() ? "Seller" : "Buyer", 12)
                + "|" + Pic.x("Exchange", 12)
                + "|" + Pic.x("FIGI ID", 12)
                + "|" + Pic.x("Security Symbol", 20)
                + "|" + Pic.x("Security Description", 40)
                + "|" + Pic.x("Security Type", 15)
                + "|" + Pic.x("    Quantity", 12)
                + "|" + Pic.x("Cur", 3)
                + "|" + Pic.x("      Amount", 12)
                + "|";
    }

    /** {@code WS-DETAIL-REC}. */
    static String detail(TradeOrderRow row) {
        return "|" + Pic.x(row.tradeId(), 10)
                + "|" + Pic.x(row.counterpartyCustomerId(), 12)
                + "|" + Pic.x(row.tradingExchange(), 12)
                + "|" + Pic.x(row.figi(), 12)
                + "|" + Pic.x(row.securitySymbol(), 20)
                + "|" + Pic.x(row.securityDescription(), 40)
                + "|" + Pic.x(row.securityType(), 15)
                + "|" + Pic.signedAmount(row.quantity())
                + "|" + Pic.x(row.currency(), 3)
                + "|" + Pic.signedAmount(row.amount())
                + "|";
    }
}

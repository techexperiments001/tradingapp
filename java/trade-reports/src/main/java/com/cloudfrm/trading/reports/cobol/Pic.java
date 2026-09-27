package com.cloudfrm.trading.reports.cobol;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * COBOL PICTURE clause semantics for the fields the report programs print.
 *
 * <p>These are deliberately literal ports: report output is compared byte for byte
 * against the mainframe listings, so zero suppression, floating signs and truncation
 * have to behave exactly as Enterprise COBOL does.
 */
public final class Pic {

    private Pic() {
    }

    /** {@code PIC X(n)}: truncate on the right, space pad to n. */
    public static String x(String value, int length) {
        String text = value == null ? "" : value;
        if (text.length() >= length) {
            return text.substring(0, length);
        }
        return text + " ".repeat(length - text.length());
    }

    /** {@code PIC 9(n)}: unsigned display, right justified, zero filled, low order truncation. */
    public static String nine(long value, int digits) {
        String text = Long.toString(Math.abs(value));
        if (text.length() > digits) {
            text = text.substring(text.length() - digits);
        }
        return "0".repeat(digits - text.length()) + text;
    }

    /** {@code PIC Z(n)}: like {@link #nine} but leading zeros become spaces; zero prints blank. */
    public static String z(long value, int digits) {
        if (value == 0) {
            return " ".repeat(digits);
        }
        String text = nine(value, digits);
        StringBuilder out = new StringBuilder(text);
        for (int i = 0; i < digits - 1 && out.charAt(i) == '0'; i++) {
            out.setCharAt(i, ' ');
        }
        return out.toString();
    }

    /**
     * {@code PIC -,---,---.99}: floating minus sign, comma grouping, two decimals.
     *
     * <p>The leftmost position is reserved for the sign, so the field holds at most seven
     * integer digits. Integer zeros to the left of the first significant digit are
     * suppressed along with the commas that would separate them, and a value of zero
     * suppresses the whole integer part.
     */
    public static String signedAmount(BigDecimal value) {
        final int width = 12;
        BigDecimal scaled = (value == null ? BigDecimal.ZERO : value).setScale(2, RoundingMode.HALF_UP);
        boolean negative = scaled.signum() < 0;
        BigDecimal magnitude = scaled.abs();

        String integerDigits = magnitude.toBigInteger().toString();
        if (integerDigits.length() > 7) {
            integerDigits = integerDigits.substring(integerDigits.length() - 7);
            integerDigits = integerDigits.replaceFirst("^0+(?=.)", "");
        }
        String grouped = "0".equals(integerDigits) ? "" : group(integerDigits);

        String decimals = magnitude.remainder(BigDecimal.ONE)
                .setScale(2, RoundingMode.HALF_UP)
                .toPlainString()
                .substring(1);
        String body = (negative ? "-" : "") + grouped + decimals;
        return body.length() >= width ? body.substring(body.length() - width) : " ".repeat(width - body.length()) + body;
    }

    private static String group(String digits) {
        StringBuilder out = new StringBuilder();
        int lead = digits.length() % 3 == 0 ? 3 : digits.length() % 3;
        out.append(digits, 0, lead);
        for (int i = lead; i < digits.length(); i += 3) {
            out.append(',').append(digits, i, i + 3);
        }
        return out.toString();
    }
}

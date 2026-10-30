package com.cloudfrm.trading.reports.cobol;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;

class PicTest {

    @Test
    void picXTruncatesAndPads() {
        assertThat(Pic.x("Common Stock", 15)).isEqualTo("Common Stock   ");
        assertThat(Pic.x("Depositary Receipt", 15)).isEqualTo("Depositary Rece");
        assertThat(Pic.x(null, 3)).isEqualTo("   ");
    }

    @Test
    void picZSuppressesLeadingZerosAndBlanksZero() {
        assertThat(Pic.z(1, 3)).isEqualTo("  1");
        assertThat(Pic.z(202, 3)).isEqualTo("202");
        assertThat(Pic.z(0, 3)).isEqualTo("   ");
    }

    @Test
    void picNineZeroFills() {
        assertThat(Pic.nine(101, 3)).isEqualTo("101");
        assertThat(Pic.nine(7, 3)).isEqualTo("007");
        assertThat(Pic.nine(1234, 3)).isEqualTo("234");
    }

    @Test
    void signedAmountMatchesFloatingSignPicture() {
        assertThat(Pic.signedAmount(new BigDecimal("59.00"))).isEqualTo("       59.00");
        assertThat(Pic.signedAmount(new BigDecimal("623.60"))).isEqualTo("      623.60");
        assertThat(Pic.signedAmount(new BigDecimal("1234.56"))).isEqualTo("    1,234.56");
        assertThat(Pic.signedAmount(new BigDecimal("1234567.89"))).isEqualTo("1,234,567.89");
        assertThat(Pic.signedAmount(new BigDecimal("-1234.56"))).isEqualTo("   -1,234.56");
        assertThat(Pic.signedAmount(BigDecimal.ZERO)).isEqualTo("         .00");
    }

    @Test
    void signedAmountRoundsHalfUpLikeCobol() {
        assertThat(Pic.signedAmount(new BigDecimal("0.125"))).isEqualTo("         .13");
        assertThat(Pic.signedAmount(new BigDecimal("0.135"))).isEqualTo("         .14");
    }
}

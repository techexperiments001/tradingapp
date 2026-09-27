package com.cloudfrm.trading.reports;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.SQLException;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.batch.core.BatchStatus;
import org.springframework.batch.core.Job;
import org.springframework.batch.core.JobExecution;
import org.springframework.batch.core.JobParametersBuilder;
import org.springframework.batch.core.launch.JobLauncher;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

/**
 * Proves the Spring Batch port of {@code TRDPB006} reproduces the mainframe report byte for
 * byte over the same data. See {@link GoldenReportFixture} for how the input state is
 * rebuilt, and {@code docs/discovery/03-equivalence-harness.md} for what this does and does
 * not cover.
 */
@SpringBootTest(properties = {"spring.batch.job.enabled=false"})
class TradeOrderReportEquivalenceTest {

    private static final Path WORKING_DIRECTORY;
    private static final Path DATABASE;
    private static final List<String> GOLDEN;

    // Built in a static initialiser, not in @BeforeAll: the application context — and with it
    // the trading DataSource — is created before @BeforeAll runs.
    static {
        try {
            WORKING_DIRECTORY = Files.createTempDirectory("trade-reports-equivalence");
            GOLDEN = GoldenReportFixture.goldenLines();
            DATABASE = GoldenReportFixture.buildDatabase(WORKING_DIRECTORY, GoldenReportFixture.parse(GOLDEN));
        } catch (IOException | SQLException e) {
            throw new IllegalStateException("Cannot build the golden report fixture", e);
        }
    }

    @Autowired
    private JobLauncher jobLauncher;

    @Autowired
    private Job tradeOrderReportJob;

    @DynamicPropertySource
    static void tradeDatabase(DynamicPropertyRegistry registry) {
        registry.add("trade.datasource.url", () -> "jdbc:h2:file:" + DATABASE + ";ACCESS_MODE_DATA=r;SCHEMA=TRADE");
    }

    @Test
    void reproducesTheMainframeTradeOrderReport() throws Exception {
        Path report = WORKING_DIRECTORY.resolve("REPORDER.REPORT");

        JobExecution execution = jobLauncher.run(tradeOrderReportJob, new JobParametersBuilder()
                .addString("reportFile", report.toString())
                .toJobParameters());

        assertThat(execution.getStatus()).isEqualTo(BatchStatus.COMPLETED);
        List<String> produced = Files.readAllLines(report, StandardCharsets.ISO_8859_1);
        assertThat(firstDifference(produced, GOLDEN)).isEqualTo("");
        assertThat(produced).hasSameSizeAs(GOLDEN);
        assertThat(Files.readAllBytes(report))
                .as("byte for byte identical to %s", GoldenReportFixture.goldenReport())
                .isEqualTo(Files.readAllBytes(GoldenReportFixture.goldenReport()));
    }

    /** A line diff that reports the first divergence with its context, instead of 11,816 lines of noise. */
    private static String firstDifference(List<String> produced, List<String> expected) {
        for (int i = 0; i < Math.min(produced.size(), expected.size()); i++) {
            if (!produced.get(i).equals(expected.get(i))) {
                return "line %d%nexpected: [%s]%nproduced: [%s]".formatted(i + 1, expected.get(i), produced.get(i));
            }
        }
        return produced.size() == expected.size()
                ? ""
                : "line count: expected %d, produced %d".formatted(expected.size(), produced.size());
    }
}

package com.cloudfrm.trading.reports.config;

import com.cloudfrm.trading.reports.domain.TradeOrderRow;
import com.cloudfrm.trading.reports.report.TradeOrderReportWriter;
import java.nio.charset.Charset;
import java.nio.file.Path;
import javax.sql.DataSource;
import org.springframework.batch.core.Job;
import org.springframework.batch.core.Step;
import org.springframework.batch.core.configuration.annotation.StepScope;
import org.springframework.batch.core.job.builder.JobBuilder;
import org.springframework.batch.core.repository.JobRepository;
import org.springframework.batch.core.step.builder.StepBuilder;
import org.springframework.batch.item.ItemStreamWriter;
import org.springframework.batch.item.database.JdbcCursorItemReader;
import org.springframework.batch.item.database.builder.JdbcCursorItemReaderBuilder;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.transaction.PlatformTransactionManager;

/** {@code TRADERPT} job: {@code TRDPB006}, the customer wise trading order report. */
@Configuration
public class TradeOrderReportJobConfig {

    /**
     * The {@code CLIENT_ORDERS} cursor of {@code TRDPB006}, unchanged.
     *
     * <p>{@code TBTRDORD} is self joined so that each leg of a trade is reported together
     * with the customer on the other side, and the ORDER BY is what drives the page and
     * section breaks — changing it changes the report.
     */
    static final String CLIENT_ORDERS = """
            SELECT  A.ORD_TRADEID
                   ,A.ORD_TRADING_XCHNG
                   ,A.ORD_BUY_SELL_IND
                   ,A.ORD_CUSTOMER_ID
                   ,CUS_DESCRIPTION
                   ,A.ORD_FIGI
                   ,SEC_SYMBOL
                   ,SEC_DESCRIPTION
                   ,SEC_TYPE
                   ,A.ORD_QUANTITY
                   ,A.ORD_CURRENCY
                   ,A.ORD_AMOUNT
                   ,A.ORD_STATUS
                   ,B.ORD_CUSTOMER_ID AS COUNTERPARTY_ID
              FROM TBTRDORD A, TBTRDCUS, TBTRDSEC, TBTRDORD B
             WHERE A.ORD_CUSTOMER_ID = CUS_CUSTOMER_ID
               AND A.ORD_FIGI        = SEC_FIGI
               AND A.ORD_CURRENCY     = B.ORD_CURRENCY
               AND A.ORD_TRADING_XCHNG= B.ORD_TRADING_XCHNG
               AND A.ORD_TRADEID      = B.ORD_TRADEID
               AND A.ORD_FIGI         = B.ORD_FIGI
               AND A.ORD_BUY_SELL_IND <> B.ORD_BUY_SELL_IND
             ORDER BY A.ORD_CUSTOMER_ID ASC
                     ,A.ORD_BUY_SELL_IND ASC
                     ,A.ORD_CURRENCY   ASC
                     ,A.ORD_STATUS     ASC
                     ,A.ORD_TRADEID    ASC
            """;

    @Bean
    public JdbcCursorItemReader<TradeOrderRow> clientOrdersReader(
            @Qualifier("tradeDataSource") DataSource tradeDataSource) {
        return new JdbcCursorItemReaderBuilder<TradeOrderRow>()
                .name("clientOrdersReader")
                .dataSource(tradeDataSource)
                .sql(CLIENT_ORDERS)
                .fetchSize(500)
                .rowMapper((rs, rowNum) -> new TradeOrderRow(
                        rs.getString("ORD_TRADEID"),
                        rs.getString("ORD_TRADING_XCHNG"),
                        rs.getString("ORD_BUY_SELL_IND"),
                        rs.getString("ORD_CUSTOMER_ID"),
                        rs.getString("CUS_DESCRIPTION"),
                        rs.getString("ORD_FIGI"),
                        rs.getString("SEC_SYMBOL"),
                        rs.getString("SEC_DESCRIPTION"),
                        rs.getString("SEC_TYPE"),
                        rs.getBigDecimal("ORD_QUANTITY"),
                        rs.getString("ORD_CURRENCY"),
                        rs.getBigDecimal("ORD_AMOUNT"),
                        rs.getString("ORD_STATUS"),
                        rs.getString("COUNTERPARTY_ID")))
                .build();
    }

    @Bean
    @StepScope
    public ItemStreamWriter<TradeOrderRow> tradeOrderReportWriter(
            @Value("#{jobParameters['reportFile'] ?: '${trade.report.reporder-file}'}") String reportFile,
            @Value("${trade.report.charset}") String charset) {
        return new TradeOrderReportWriter(Path.of(reportFile), Charset.forName(charset));
    }

    @Bean
    public Step tradeOrderReportStep(
            JobRepository jobRepository,
            PlatformTransactionManager transactionManager,
            JdbcCursorItemReader<TradeOrderRow> clientOrdersReader,
            ItemStreamWriter<TradeOrderRow> tradeOrderReportWriter) {
        return new StepBuilder("tradeOrderReportStep", jobRepository)
                .<TradeOrderRow, TradeOrderRow>chunk(500, transactionManager)
                .reader(clientOrdersReader)
                .writer(tradeOrderReportWriter)
                .build();
    }

    @Bean
    public Job tradeOrderReportJob(JobRepository jobRepository, Step tradeOrderReportStep) {
        return new JobBuilder("tradeOrderReportJob", jobRepository)
                .start(tradeOrderReportStep)
                .build();
    }
}

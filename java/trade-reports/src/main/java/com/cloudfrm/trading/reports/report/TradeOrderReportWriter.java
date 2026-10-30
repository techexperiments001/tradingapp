package com.cloudfrm.trading.reports.report;

import com.cloudfrm.trading.reports.cobol.PrintFile;
import com.cloudfrm.trading.reports.domain.TradeOrderRow;
import java.nio.charset.Charset;
import java.nio.file.Path;
import org.springframework.batch.item.Chunk;
import org.springframework.batch.item.ExecutionContext;
import org.springframework.batch.item.ItemStreamWriter;

/**
 * The print logic of {@code TRDPB006}, paragraph {@code 3000-FETCH-PROCESS-ORDERS}.
 *
 * <p>The COBOL keeps its header state in {@code WS-PRINT-HEADER} across fetches, so a page
 * overflow detected while printing one row is honoured on the next one. That flag is
 * modelled here by {@link #pending} rather than recomputed per row, because recomputing
 * it changes where the page breaks fall.
 */
public class TradeOrderReportWriter implements ItemStreamWriter<TradeOrderRow> {

    private static final int RECORD_LENGTH = 160;
    private static final int MAX_ORDERS_PER_PAGE = 60;

    private enum Pending { PAGE_HEADER, STATUS_HEADER, DETAIL_HEADER, DETAIL }

    private final Path outputPath;
    private final Charset charset;

    private PrintFile print;
    private Pending pending = Pending.PAGE_HEADER;
    private int pageNumber;
    private int ordersOnPage;
    private String previousCustomerId = "";
    private String previousBuySell = " ";
    private String previousStatus = "";

    public TradeOrderReportWriter(Path outputPath, Charset charset) {
        this.outputPath = outputPath;
        this.charset = charset;
    }

    @Override
    public void open(ExecutionContext executionContext) {
        print = new PrintFile(outputPath, charset, RECORD_LENGTH, true);
    }

    @Override
    public void write(Chunk<? extends TradeOrderRow> chunk) {
        for (TradeOrderRow row : chunk) {
            writeRow(row);
        }
    }

    private void writeRow(TradeOrderRow row) {
        if (!row.customerId().equals(previousCustomerId) || !row.buySellIndicator().equals(previousBuySell)) {
            pending = Pending.PAGE_HEADER;
        } else if (!row.status().equals(previousStatus)) {
            pending = Pending.STATUS_HEADER;
        }
        previousCustomerId = row.customerId();
        previousBuySell = row.buySellIndicator();
        previousStatus = row.status();

        if (pending == Pending.PAGE_HEADER) {
            pageNumber++;
            print.write(ReportLayout.blank());
            print.writeAfterPage(ReportLayout.pageHeader(row, pageNumber));
            pending = Pending.STATUS_HEADER;
            ordersOnPage = 0;
        }

        if (pending == Pending.STATUS_HEADER) {
            print.write(ReportLayout.blank());
            print.writeAfterAdvancing(2, ReportLayout.statusHeader(row.status()));
            print.write(ReportLayout.blank());
            pending = Pending.DETAIL_HEADER;
        }

        if (pending == Pending.DETAIL_HEADER) {
            print.write(ReportLayout.rule());
            print.writeAfterAdvancing(1, ReportLayout.detailHeader(row));
            print.write(ReportLayout.rule());
            pending = Pending.DETAIL;
        }

        ordersOnPage++;
        print.write(ReportLayout.detail(row));
        if (ordersOnPage > MAX_ORDERS_PER_PAGE) {
            print.write(ReportLayout.rule());
            pending = Pending.PAGE_HEADER;
        }
    }

    /** {@code WHEN 100} of the fetch: close the last table off with a rule. */
    @Override
    public void close() {
        if (print != null) {
            print.write(ReportLayout.rule());
            print.close();
            print = null;
        }
    }

    @Override
    public void update(ExecutionContext executionContext) {
        // TRDPB006 has no restart logic; the report is always produced from scratch.
    }
}

package com.cloudfrm.trading.reports.cobol;

import java.io.BufferedWriter;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.io.Writer;
import java.nio.charset.Charset;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * An {@code FBA} print file: every record carries an ANSI carriage control character in
 * column 1, which COBOL derives from the {@code ADVANCING} phrase of the {@code WRITE}.
 *
 * <p>Records are {@code recordLength} bytes on the mainframe. Trailing blanks are trimmed
 * here because that is what the transfer of the reference reports in {@code output/}
 * did; keep {@code trimTrailingBlanks} false to emit true fixed length records.
 */
public class PrintFile implements AutoCloseable {

    public static final char SINGLE_SPACE = ' ';
    public static final char DOUBLE_SPACE = '0';
    public static final char NEW_PAGE = '1';

    private final Writer writer;
    private final int recordLength;
    private final boolean trimTrailingBlanks;

    public PrintFile(Path path, Charset charset, int recordLength, boolean trimTrailingBlanks) {
        this.recordLength = recordLength;
        this.trimTrailingBlanks = trimTrailingBlanks;
        try {
            Files.createDirectories(path.toAbsolutePath().getParent());
            this.writer = new BufferedWriter(Files.newBufferedWriter(path, charset));
        } catch (IOException e) {
            throw new UncheckedIOException("Cannot open print file " + path, e);
        }
    }

    /** {@code WRITE record} — no ADVANCING phrase, i.e. single spacing. */
    public void write(String record) {
        write(SINGLE_SPACE, record);
    }

    /** {@code WRITE record AFTER ADVANCING <lines> LINES}. */
    public void writeAfterAdvancing(int lines, String record) {
        write(lines == 2 ? DOUBLE_SPACE : SINGLE_SPACE, record);
    }

    /** {@code WRITE record AFTER ADVANCING PAGE}. */
    public void writeAfterPage(String record) {
        write(NEW_PAGE, record);
    }

    private void write(char carriageControl, String record) {
        String line = carriageControl + Pic.x(record, recordLength);
        if (trimTrailingBlanks) {
            line = line.replaceAll("\\s+$", "");
        }
        try {
            writer.write(line);
            writer.write('\n');
        } catch (IOException e) {
            throw new UncheckedIOException("Cannot write print record", e);
        }
    }

    @Override
    public void close() {
        try {
            writer.close();
        } catch (IOException e) {
            throw new UncheckedIOException("Cannot close print file", e);
        }
    }
}

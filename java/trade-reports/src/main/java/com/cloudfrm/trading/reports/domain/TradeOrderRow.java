package com.cloudfrm.trading.reports.domain;

import java.math.BigDecimal;

/** One row of the {@code CLIENT_ORDERS} cursor in {@code TRDPB006}. */
public record TradeOrderRow(
        String tradeId,
        String tradingExchange,
        String buySellIndicator,
        String customerId,
        String customerDescription,
        String figi,
        String securitySymbol,
        String securityDescription,
        String securityType,
        BigDecimal quantity,
        String currency,
        BigDecimal amount,
        String status,
        String counterpartyCustomerId) {

    public boolean isBuy() {
        return "B".equals(buySellIndicator);
    }
}

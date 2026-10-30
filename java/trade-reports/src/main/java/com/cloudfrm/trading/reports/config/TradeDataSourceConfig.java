package com.cloudfrm.trading.reports.config;

import javax.sql.DataSource;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.jdbc.DataSourceProperties;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

/**
 * Two data sources: the primary one holds the Spring Batch metadata tables, and
 * {@code tradeDataSource} is the trading database the reports read. They are separate so
 * that the trading database can be opened read only, exactly as a report program uses it.
 */
@Configuration
public class TradeDataSourceConfig {

    @Bean
    @Primary
    @ConfigurationProperties("spring.datasource")
    public DataSourceProperties batchDataSourceProperties() {
        return new DataSourceProperties();
    }

    @Bean
    @Primary
    public DataSource batchDataSource(@Qualifier("batchDataSourceProperties") DataSourceProperties batchDataSourceProperties) {
        return batchDataSourceProperties.initializeDataSourceBuilder().build();
    }

    @Bean
    @ConfigurationProperties("trade.datasource")
    public DataSourceProperties tradeDataSourceProperties() {
        return new DataSourceProperties();
    }

    @Bean
    public DataSource tradeDataSource(@Qualifier("tradeDataSourceProperties") DataSourceProperties tradeDataSourceProperties) {
        return tradeDataSourceProperties.initializeDataSourceBuilder().build();
    }
}

package com.example.dbexample.config;

import com.zaxxer.hikari.HikariDataSource;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.jdbc.DataSourceProperties;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.datasource.LazyConnectionDataSourceProxy;

import javax.sql.DataSource;
import java.util.List;
import java.util.concurrent.ThreadLocalRandom;

@Configuration
public class DataSourceConfig {

    @Bean
    @Primary
    @ConfigurationProperties("spring.datasource.primary")
    public DataSourceProperties primaryDataSourceProperties() {
        return new DataSourceProperties();
    }

    @Bean
    @Primary
    public DataSource primaryDataSource() {
        return primaryDataSourceProperties()
                .initializeDataSourceBuilder()
                .type(HikariDataSource.class)
                .build();
    }

    @Bean
    @ConfigurationProperties("spring.datasource.replica1")
    public DataSourceProperties replica1DataSourceProperties() {
        return new DataSourceProperties();
    }

    @Bean
    public DataSource replica1DataSource() {
        return replica1DataSourceProperties()
                .initializeDataSourceBuilder()
                .type(HikariDataSource.class)
                .build();
    }

    @Bean
    @ConfigurationProperties("spring.datasource.replica2")
    public DataSourceProperties replica2DataSourceProperties() {
        return new DataSourceProperties();
    }

    @Bean
    public DataSource replica2DataSource() {
        return replica2DataSourceProperties()
                .initializeDataSourceBuilder()
                .type(HikariDataSource.class)
                .build();
    }

    @Bean
    public DataSource routingDataSource(
            @Qualifier("primaryDataSource") DataSource primaryDataSource,
            @Qualifier("replica1DataSource") DataSource replica1DataSource,
            @Qualifier("replica2DataSource") DataSource replica2DataSource) {
        
        ReplicationRoutingDataSource routingDataSource = new ReplicationRoutingDataSource();
        
        routingDataSource.setDefaultTargetDataSource(primaryDataSource);
        routingDataSource.setTargetDataSources(java.util.Map.of(
                ReplicationType.MASTER, primaryDataSource,
                ReplicationType.SLAVE1, replica1DataSource,
                ReplicationType.SLAVE2, replica2DataSource
        ));
        
        routingDataSource.afterPropertiesSet();
        return routingDataSource;
    }

    @Bean
    public DataSource dataSource(@Qualifier("routingDataSource") DataSource routingDataSource) {
        return new LazyConnectionDataSourceProxy(routingDataSource);
    }

    public enum ReplicationType {
        MASTER,
        SLAVE1,
        SLAVE2
    }

    public static class ReplicationRoutingDataSource extends org.springframework.jdbc.datasource.lookup.AbstractRoutingDataSource {
        
        private static final List<ReplicationType> REPLICA_TYPES = List.of(
                ReplicationType.SLAVE1, 
                ReplicationType.SLAVE2
        );

        @Override
        protected Object determineCurrentLookupKey() {
            String lookupKey = ReplicationContextHolder.getContext();
            
            if ("WRITE".equals(lookupKey)) {
                return ReplicationType.MASTER;
            } else if ("READ".equals(lookupKey)) {
                // 隨機選擇一個 replica
                ReplicationType replica = REPLICA_TYPES.get(
                        ThreadLocalRandom.current().nextInt(REPLICA_TYPES.size())
                );
                return replica;
            }
            
            return ReplicationType.MASTER;
        }
    }
}


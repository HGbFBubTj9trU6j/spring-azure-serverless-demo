package com.example.backend;

import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
@Profile("database")
public class DatabaseFortuneRepository implements FortuneRepository {

    private final JdbcClient jdbcClient;

    public DatabaseFortuneRepository(JdbcClient jdbcClient) {
        this.jdbcClient = jdbcClient;
    }

    @Override
    public String findRandom() {
        return jdbcClient.sql("""
                SELECT TOP (1) message
                FROM dbo.fortunes
                ORDER BY NEWID()
                """)
                .query(String.class)
                .single();
    }
}

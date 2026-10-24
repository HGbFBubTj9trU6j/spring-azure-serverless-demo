package com.example.backend;

import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
@Profile("database")
public class DatabaseFortuneRepository implements FortuneRepository, FortuneManagementRepository {

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

    @Override
    public List<Fortune> findAll() {
        return jdbcClient.sql("""
            SELECT id, message
            FROM dbo.fortunes
            ORDER BY id
            """)
                .query((rs, rowNum) -> new Fortune(
                        rs.getLong("id"),
                        rs.getString("message")
                ))
                .list();
    }

    @Override
    public Fortune save(String message) {
        return jdbcClient.sql("""
            INSERT INTO dbo.fortunes (message)
            OUTPUT INSERTED.id, INSERTED.message
            VALUES (:message)
            """)
                .param("message", message)
                .query((rs, rowNum) -> new Fortune(
                        rs.getLong("id"),
                        rs.getString("message")
                ))
                .single();
    }

    @Override
    public boolean deleteById(long id) {
        int affectedRows = jdbcClient.sql("""
            DELETE FROM dbo.fortunes
            WHERE id = :id
            """)
                .param("id", id)
                .update();

        return affectedRows > 0;
    }
}

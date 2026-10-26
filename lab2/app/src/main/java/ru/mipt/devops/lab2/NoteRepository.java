package ru.mipt.devops.lab2;

import java.time.OffsetDateTime;
import java.util.List;

import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

/**
 * Хранение заметок в PostgreSQL через JdbcTemplate.
 * Таблица создаётся лениво при первом обращении: так приложение стартует,
 * даже если база ещё не поднялась (или её нет вовсе при одиночном docker run).
 */
@Repository
public class NoteRepository {

    private static final RowMapper<Note> MAPPER = (rs, i) -> new Note(
            rs.getLong("id"),
            rs.getString("text"),
            rs.getObject("created_at", OffsetDateTime.class));

    private final JdbcTemplate jdbc;
    private volatile boolean schemaReady = false;

    public NoteRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<Note> findLatest(int limit) {
        ensureSchema();
        return jdbc.query("SELECT id, text, created_at FROM notes ORDER BY id DESC LIMIT ?", MAPPER, limit);
    }

    public long count() {
        ensureSchema();
        Long n = jdbc.queryForObject("SELECT count(*) FROM notes", Long.class);
        return n == null ? 0 : n;
    }

    public Note insert(String text) {
        ensureSchema();
        return jdbc.queryForObject(
                "INSERT INTO notes(text) VALUES (?) RETURNING id, text, created_at", MAPPER, text);
    }

    public boolean isDatabaseReachable() {
        try {
            jdbc.queryForObject("SELECT 1", Integer.class);
            return true;
        } catch (DataAccessException e) {
            return false;
        }
    }

    private void ensureSchema() {
        if (schemaReady) {
            return;
        }
        synchronized (this) {
            if (!schemaReady) {
                jdbc.execute("""
                        CREATE TABLE IF NOT EXISTS notes (
                            id         BIGSERIAL PRIMARY KEY,
                            text       VARCHAR(500) NOT NULL,
                            created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
                        )""");
                schemaReady = true;
            }
        }
    }

    public record Note(long id, String text, OffsetDateTime createdAt) {
    }
}

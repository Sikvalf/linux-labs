package ru.mipt.devops.lab2;

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * /health — liveness-проверка: отвечает 200, если JVM и веб-сервер живы.
 * Базу намеренно не трогает, чтобы образ можно было проверить одиночным
 * `docker run` без PostgreSQL (критерий приёмки Docker #1).
 * Состояние базы показывает отдельный эндпоинт /health/db.
 */
@RestController
public class HealthController {

    private final String version;
    private final NoteRepository notes;

    public HealthController(@Value("${app.version}") String version, NoteRepository notes) {
        this.version = version;
        this.notes = notes;
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        return Map.of("status", "UP");
    }

    @GetMapping("/health/db")
    public ResponseEntity<Map<String, Object>> dbHealth() {
        boolean up = notes.isDatabaseReachable();
        Map<String, Object> body = Map.of("db", up ? "UP" : "DOWN");
        return up
                ? ResponseEntity.ok(body)
                : ResponseEntity.status(503).body(body);
    }

    @GetMapping("/")
    public Map<String, Object> info() {
        Map<String, Object> info = new LinkedHashMap<>();
        info.put("app", "lab2-app");
        info.put("version", version);
        info.put("host", hostname());
        info.put("time", Instant.now().toString());
        info.put("endpoints", new String[] {"GET /health", "GET /health/db", "GET /api/notes", "POST /api/notes"});
        return info;
    }

    private static String hostname() {
        try {
            return InetAddress.getLocalHost().getHostName();
        } catch (UnknownHostException e) {
            return "unknown";
        }
    }
}

package ru.mipt.devops.lab2;

import java.util.Map;

import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Простое API заметок — нужно, чтобы показать, что данные PostgreSQL
 * сохраняются между перезапусками стека (критерий приёмки Docker #2).
 */
@RestController
@RequestMapping("/api/notes")
public class NoteController {

    private static final int MAX_TEXT = 500;

    private final NoteRepository notes;

    public NoteController(NoteRepository notes) {
        this.notes = notes;
    }

    @GetMapping
    public Map<String, Object> list(@RequestParam(defaultValue = "20") int limit) {
        int safeLimit = Math.max(1, Math.min(limit, 100));
        return Map.of(
                "total", notes.count(),
                "items", notes.findLatest(safeLimit));
    }

    @PostMapping
    public ResponseEntity<?> create(@RequestBody CreateNoteRequest request) {
        String text = request == null || request.text() == null ? "" : request.text().strip();
        if (text.isEmpty() || text.length() > MAX_TEXT) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", "text must be 1.." + MAX_TEXT + " characters"));
        }
        return ResponseEntity.status(HttpStatus.CREATED).body(notes.insert(text));
    }

    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Map<String, String>> databaseUnavailable(DataAccessException e) {
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(Map.of("error", "database unavailable"));
    }

    public record CreateNoteRequest(String text) {
    }
}

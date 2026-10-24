package com.example.backend;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@Profile("database")
@RequestMapping("/api/admin/fortunes")
public class FortuneManagementController {

    private final FortuneManagementService fortuneManagementService;

    public FortuneManagementController(
            FortuneManagementService fortuneManagementService
    ) {
        this.fortuneManagementService = fortuneManagementService;
    }

    @GetMapping
    public List<Fortune> findAll() {
        return fortuneManagementService.findAll();
    }

    @PostMapping
    public ResponseEntity<Fortune> add(
            @Valid @RequestBody CreateFortuneRequest request
    ) {
        Fortune fortune =
                fortuneManagementService.add(request.message().strip());

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(fortune);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable long id) {
        if (!fortuneManagementService.delete(id)) {
            return ResponseEntity.notFound().build();
        }

        return ResponseEntity.noContent().build();
    }

    public record CreateFortuneRequest(
            @NotBlank(message = "Fortune message must not be blank.")
            String message
    ) {
    }
}

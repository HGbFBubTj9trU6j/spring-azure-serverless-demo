package com.example.backend;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api")
public class VersionController {
    @Value("${application.version}")
    private String version;

    @GetMapping("/version")
    public Map<String, String> version() {
        return Map.of(
                "version", version
        );
    }
}
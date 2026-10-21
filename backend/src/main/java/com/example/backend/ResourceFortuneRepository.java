package com.example.backend;

import org.springframework.context.annotation.Profile;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Repository;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.ThreadLocalRandom;

@Repository
@Profile("resource")
public class ResourceFortuneRepository implements FortuneRepository {

    private final List<String> fortunes;

    public ResourceFortuneRepository() throws IOException {
        var resource = new ClassPathResource("fortunes/devops");

        String content = resource.getContentAsString(StandardCharsets.UTF_8);

        this.fortunes = Arrays.stream(content.split("(?m)^%\\s*$"))
                .map(String::trim)
                .filter(fortune -> !fortune.isEmpty())
                .toList();

        if (fortunes.isEmpty()) {
            throw new IllegalStateException("No fortunes were found.");
        }
    }

    @Override
    public String findRandom() {
        int index = ThreadLocalRandom.current().nextInt(fortunes.size());
        return fortunes.get(index);
    }
}
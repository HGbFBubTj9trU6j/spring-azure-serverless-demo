package com.example.backend;

import org.junit.jupiter.api.Test;

import java.io.IOException;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;

class ResourceFortuneRepositoryTest {

    @Test
    void findRandomReturnsFortune() throws IOException {
        var repository = new ResourceFortuneRepository();

        String fortune = repository.findRandom();

        assertNotNull(fortune);
        assertFalse(fortune.isBlank());
    }
}
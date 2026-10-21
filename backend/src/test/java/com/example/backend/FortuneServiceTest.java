package com.example.backend;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class FortuneServiceTest {

    @Test
    void getRandomFortuneReturnsFortuneFromRepository() {
        FortuneRepository repository = mock(FortuneRepository.class);

        when(repository.findRandom())
                .thenReturn("Deployments should be boring.");

        FortuneService service = new FortuneService(repository);

        String fortune = service.getRandomFortune();

        assertEquals("Deployments should be boring.", fortune);
    }
}
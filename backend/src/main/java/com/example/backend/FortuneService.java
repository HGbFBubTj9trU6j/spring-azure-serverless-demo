package com.example.backend;

import org.springframework.stereotype.Service;

@Service
public class FortuneService {

    private final FortuneRepository fortuneRepository;

    public FortuneService(FortuneRepository fortuneRepository) {
        this.fortuneRepository = fortuneRepository;
    }

    public String getRandomFortune() {
        return fortuneRepository.findRandom();
    }
}
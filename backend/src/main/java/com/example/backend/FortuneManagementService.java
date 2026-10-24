package com.example.backend;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@Profile("database")
public class FortuneManagementService {

    private final FortuneManagementRepository fortuneManagementRepository;

    public FortuneManagementService(
            FortuneManagementRepository fortuneManagementRepository
    ) {
        this.fortuneManagementRepository = fortuneManagementRepository;
    }

    public List<Fortune> findAll() {
        return fortuneManagementRepository.findAll();
    }

    public Fortune add(String message) {
        return fortuneManagementRepository.save(message.strip());
    }

    public boolean delete(long id) {
        return fortuneManagementRepository.deleteById(id);
    }
}

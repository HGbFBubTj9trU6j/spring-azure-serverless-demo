package com.example.backend;

import java.util.List;

public interface FortuneManagementRepository {

    List<Fortune> findAll();

    Fortune save(String message);

    boolean deleteById(long id);
}

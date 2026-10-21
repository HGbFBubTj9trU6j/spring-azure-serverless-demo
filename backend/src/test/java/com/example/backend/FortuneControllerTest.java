package com.example.backend;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(FortuneController.class)
class FortuneControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private FortuneService fortuneService;

    @Test
    void fortuneReturnsFortune() throws Exception {
        when(fortuneService.getRandomFortune())
                .thenReturn("Deployments should be boring.");

        mockMvc.perform(get("/api/fortune"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fortune")
                        .value("Deployments should be boring."));
    }
}
package com.example.backend;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(FortuneManagementController.class)
@ActiveProfiles("database")
class FortuneManagementControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private FortuneManagementService fortuneManagementService;

    @Test
    void findAllReturnsFortunes() throws Exception {
        when(fortuneManagementService.findAll())
                .thenReturn(List.of(
                        new Fortune(1L, "When in doubt, check the logs."),
                        new Fortune(2L, "Deployments should be boring.")
                ));

        mockMvc.perform(get("/api/admin/fortunes"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(1))
                .andExpect(jsonPath("$[0].message")
                        .value("When in doubt, check the logs."))
                .andExpect(jsonPath("$[1].id").value(2))
                .andExpect(jsonPath("$[1].message")
                        .value("Deployments should be boring."));
    }

    @Test
    void addReturnsCreatedFortune() throws Exception {
        when(fortuneManagementService.add("Ship small, learn fast."))
                .thenReturn(new Fortune(
                        6L,
                        "Ship small, learn fast."
                ));

        mockMvc.perform(post("/api/admin/fortunes")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "message": "Ship small, learn fast."
                                }
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(6))
                .andExpect(jsonPath("$.message")
                        .value("Ship small, learn fast."));
    }

    @Test
    void addStripsLeadingAndTrailingWhitespace() throws Exception {
        when(fortuneManagementService.add("Ship small, learn fast."))
                .thenReturn(new Fortune(
                        6L,
                        "Ship small, learn fast."
                ));

        mockMvc.perform(post("/api/admin/fortunes")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "message": "  Ship small, learn fast.  "
                                }
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.message")
                        .value("Ship small, learn fast."));
    }

    @Test
    void addRejectsBlankMessage() throws Exception {
        mockMvc.perform(post("/api/admin/fortunes")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "message": "   "
                                }
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void addRejectsMissingMessage() throws Exception {
        mockMvc.perform(post("/api/admin/fortunes")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {}
                                """))
                .andExpect(status().isBadRequest());
    }

    @Test
    void deleteReturnsNoContentWhenFortuneExists() throws Exception {
        when(fortuneManagementService.delete(6L))
                .thenReturn(true);

        mockMvc.perform(delete("/api/admin/fortunes/6"))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""));
    }

    @Test
    void deleteReturnsNotFoundWhenFortuneDoesNotExist() throws Exception {
        when(fortuneManagementService.delete(999L))
                .thenReturn(false);

        mockMvc.perform(delete("/api/admin/fortunes/999"))
                .andExpect(status().isNotFound());
    }
}

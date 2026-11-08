package com.example.backend;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("database")
class FortuneManagementControllerSecurityTest {

    @MockitoBean
    private FortuneManagementService fortuneManagementService;

    @Autowired
    private MockMvc mockMvc;

    /**
     * Test that accessing the /api/admin/fortunes endpoint without an access token
     * returns a 401 Unauthorized response.
     */
    @Test
    void shouldReturnUnauthorizedWhenAccessTokenIsMissing()
            throws Exception {

        mockMvc.perform(
                        get("/api/admin/fortunes")
                )
                .andExpect(
                        status().isUnauthorized()
                );
    }

    /**
     * Test that accessing the /api/admin/fortunes endpoint without the ROLE_Fortune.Admin role
     * returns a 403 Forbidden response.
     */
    @Test
    void shouldReturnForbiddenWhenFortuneAdminRoleIsMissing()
            throws Exception {

        mockMvc.perform(
                        get("/api/admin/fortunes")
                                .with(jwt())
                )
                .andExpect(
                        status().isForbidden()
                );
    }

    /**
     * Test that accessing the /api/admin/fortunes endpoint with the ROLE_Fortune.Admin role
     * returns a 200 OK response.
     */
    @Test
    void shouldAllowAccessWhenFortuneAdminRoleIsPresent()
            throws Exception {

        mockMvc.perform(
                        get("/api/admin/fortunes")
                                .with(jwt().authorities(
                                        new SimpleGrantedAuthority(
                                                "ROLE_Fortune.Admin"
                                        )
                                ))
                )
                .andExpect(
                        status().isOk()
                );
    }

    /**
     * Test that posting to the /api/admin/fortunes endpoint with the ROLE_Fortune.Admin role
     * returns a 201 Created response.
     */
    @Test
    void shouldAllowPostWhenFortuneAdminRoleIsPresent()
            throws Exception {
        when(fortuneManagementService.add("Test fortune"))
                .thenReturn(new Fortune(
                        1L,
                        "Test fortune"
                ));
        mockMvc.perform(
                        post("/api/admin/fortunes")
                                .with(jwt().authorities(
                                        new SimpleGrantedAuthority(
                                                "ROLE_Fortune.Admin"
                                        )
                                ))
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {
                                          "message": "Test fortune"
                                        }
                                        """)
                )
                .andExpect(
                        status().isCreated()
                );
    }

    /**
     * Test that deleting from the /api/admin/fortunes endpoint with the ROLE_Fortune.Admin role
     * returns a 204 No Content response.
     */
    @Test
    void shouldAllowDeleteWhenFortuneAdminRoleIsPresent()
            throws Exception {

        when(fortuneManagementService.delete(1L))
                .thenReturn(true);

        mockMvc.perform(
                        delete("/api/admin/fortunes/1")
                                .with(jwt().authorities(
                                        new SimpleGrantedAuthority(
                                                "ROLE_Fortune.Admin"
                                        )
                                ))
                )
                .andExpect(
                        status().isNoContent()
                );
    }

    /**
     * Test that posting to the /api/admin/fortunes endpoint without the ROLE_Fortune.Admin role
     * returns a 403 Forbidden response.
     */
    @Test
    void shouldReturnForbiddenWhenPostingWithoutFortuneAdminRole()
            throws Exception {

        mockMvc.perform(post("/api/admin/fortunes")
                        .with(jwt())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "message": "Test fortune"
                                }
                                """))
                .andExpect(status().isForbidden());
    }

    /**
     * Test that deleting from the /api/admin/fortunes endpoint without the ROLE_Fortune.Admin role
     * returns a 403 Forbidden response.
     */
    @Test
    void shouldReturnForbiddenWhenDeletingWithoutFortuneAdminRole()
            throws Exception {

        mockMvc.perform(delete("/api/admin/fortunes/1")
                        .with(jwt()))
                .andExpect(status().isForbidden());
    }
}

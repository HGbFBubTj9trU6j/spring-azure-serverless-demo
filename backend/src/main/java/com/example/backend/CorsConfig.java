package com.example.backend;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class CorsConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        // Azure Static Web Apps とローカル開発環境からの
        // Spring Boot API 呼び出しを許可する
        registry.addMapping("/api/**")
                .allowedOriginPatterns(
                        "https://*.azurestaticapps.net",
                        "http://localhost:5173"
                )
                .allowedMethods("*")
                .allowedHeaders("*");
    }
}

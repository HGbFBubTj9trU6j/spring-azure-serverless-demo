package com.example.backend;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
class FortuneController {

	private final FortuneService fortuneService;

	FortuneController(FortuneService fortuneService) {
		this.fortuneService = fortuneService;
	}

	@GetMapping("/fortune")
	FortuneResponse fortune() {
		return new FortuneResponse(fortuneService.getRandomFortune());
	}

	record FortuneResponse(String fortune) {
	}
}
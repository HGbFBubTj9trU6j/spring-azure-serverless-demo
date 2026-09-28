package com.example.backend;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
class HelloController {

	@GetMapping("/hello")
	HelloResponse hello() {
		return new HelloResponse("hello");
	}

	record HelloResponse(String message) {
	}

}

package com.dancepractice.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

/** Turns on {@code @Scheduled} methods (currently the rate limiter's idle-bucket cleanup). */
@Configuration
@EnableScheduling
public class SchedulingConfig {
}

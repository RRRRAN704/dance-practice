package com.dancepractice.stats;

import com.dancepractice.common.BadRequestException;
import com.dancepractice.common.CurrentUser;
import java.time.DateTimeException;
import java.time.ZoneId;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/stats")
public class StatsController {

    private final StatsService statsService;

    public StatsController(StatsService statsService) {
        this.statsService = statsService;
    }

    /** @param zone IANA time zone such as Europe/London; decides where each day starts */
    @GetMapping("/summary")
    public StatsSummary summary(@AuthenticationPrincipal Jwt jwt, @RequestParam(defaultValue = "UTC") String zone) {
        ZoneId zoneId;
        try {
            zoneId = ZoneId.of(zone);
        } catch (DateTimeException e) {
            throw new BadRequestException("Unknown time zone: " + zone);
        }
        return statsService.summary(CurrentUser.id(jwt), zoneId);
    }
}

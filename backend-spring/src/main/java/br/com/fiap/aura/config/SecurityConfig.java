package br.com.fiap.aura.config;

import br.com.fiap.aura.security.JwtAuthenticationFilter;
import br.com.fiap.aura.web.error.ApiErrorResponse;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Arrays;
import java.util.List;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.MediaType;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

/**
 * API stateless: nenhuma sessão no servidor, autorização derivada do JWT.
 * Rotas públicas: signup/login/refresh, health, página de status e Swagger.
 */
@Configuration
@EnableMethodSecurity
public class SecurityConfig {

    private static final String[] PUBLIC = {
        "/", "/status", "/api/v1/health",
        "/api/v1/auth/signup", "/api/v1/auth/login", "/api/v1/auth/refresh",
        "/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html", "/h2-console/**",
        "/favicon.ico", "/css/**"
    };

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http,
                                           JwtAuthenticationFilter jwtFilter,
                                           ObjectMapper mapper,
                                           AuraProperties props) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)
            .cors(Customizer.withDefaults())
            .headers(h -> h.frameOptions(f -> f.sameOrigin()))   // H2 console na demo
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(reg -> reg
                .requestMatchers(PUBLIC).permitAll()
                .requestMatchers("/api/v1/ops/**").hasRole("ADMIN")
                .anyRequest().authenticated())
            .exceptionHandling(e -> e
                .authenticationEntryPoint((req, res, ex) ->
                    write(mapper, res, 401, "UNAUTHORIZED", "Autenticação necessária."))
                .accessDeniedHandler((req, res, ex) ->
                    write(mapper, res, 403, "FORBIDDEN", "Acesso negado a este recurso.")))
            .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    private static void write(ObjectMapper mapper, jakarta.servlet.http.HttpServletResponse res,
                              int status, String code, String message) throws java.io.IOException {
        res.setStatus(status);
        res.setContentType(MediaType.APPLICATION_JSON_VALUE);
        res.setCharacterEncoding("UTF-8");
        mapper.writeValue(res.getWriter(), ApiErrorResponse.of(code, message, null));
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource(AuraProperties props) {
        List<String> origins = Arrays.stream(props.cors().allowedOrigins().split(",")).map(String::trim).toList();
        CorsConfiguration cfg = new CorsConfiguration();
        if (origins.contains("*")) {
            cfg.setAllowedOriginPatterns(List.of("*"));
        } else {
            cfg.setAllowedOrigins(origins);
        }
        cfg.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        cfg.setAllowedHeaders(List.of("*"));
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", cfg);
        return source;
    }
}

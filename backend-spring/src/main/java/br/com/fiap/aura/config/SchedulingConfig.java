package br.com.fiap.aura.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Liga o agendador do Spring. Existe por causa de <b>uma</b> feature: o disparo do SOS em T+5s é
 * responsabilidade do servidor (C3, regra 2), e sem isto o {@code EmergencyService} teria um
 * cronômetro que nunca dispara e um varredor que nunca roda — o pior estado possível, porque a API
 * responderia "aviso agendado" e nada aconteceria.
 *
 * <p>O {@code TaskScheduler} injetado no {@code EmergencyService} é o autoconfigurado pelo Spring
 * Boot. Com {@code spring.threads.virtual.enabled: true} (é o caso deste projeto) ele vem como
 * {@code SimpleAsyncTaskScheduler} sobre threads virtuais, então uma tarefa lenta não ocupa um slot
 * de pool escasso — o que importa aqui porque cada disparo faz uma chamada de rede ao Firebase.
 */
@Configuration
@EnableScheduling
public class SchedulingConfig {
}

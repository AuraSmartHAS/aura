package br.com.fiap.aura;

import br.com.fiap.aura.config.AuraProperties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;

@SpringBootApplication
@EnableConfigurationProperties(AuraProperties.class)
public class AuraApiApplication {

    public static void main(String[] args) {
        SpringApplication.run(AuraApiApplication.class, args);
    }
}

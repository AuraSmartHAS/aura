# Build com Maven + JDK 21; execução em JRE enxuto. O perfil dev sobe H2 em memória com o
# seed completo da demonstração — nenhum banco externo, nenhuma credencial, nenhum passo manual.
# Reiniciar o container recompõe o cenário limpo (o mesmo botão de reset do ensaio).
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -q -DskipTests dependency:go-offline
COPY src ./src
RUN mvn -q -DskipTests package

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/target/aura-api-*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]

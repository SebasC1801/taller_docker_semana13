# ---------- Etapa 1: compilacion ----------
FROM maven:3.9.6-eclipse-temurin-17-alpine AS builder

ARG STUDENT_ID

WORKDIR /build

# Solo se copia el pom y se descargan las dependencias: esta capa se
# reutiliza del cache mientras el pom.xml no cambie.
COPY pom.xml .
RUN mvn dependency:go-offline -B

COPY src ./src
RUN mvn package -DskipTests -B

# ---------- Etapa 2: runtime ----------
FROM eclipse-temurin:17-jre-alpine

ARG STUDENT_ID

RUN addgroup -S sensorgroup \
    && adduser -S -u 10001 -G sensorgroup sensor_user

WORKDIR /app

COPY --from=builder /build/target/eco-air-backend.jar app.jar
RUN chown -R sensor_user:sensorgroup /app

ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UseSerialGC -XX:+ExitOnOutOfMemoryError"
ENV OPERATOR_ID=${STUDENT_ID}

EXPOSE 8080

USER sensor_user

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]

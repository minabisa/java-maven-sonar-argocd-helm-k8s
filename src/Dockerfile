# You can change this base image to anything else
# But make sure to use the correct version of Java
FROM eclipse-temurin:17-jre

# Simply the artifact path
ARG artifact=target/hello-cicd-1.0.0.jar

WORKDIR /opt/app

COPY ${artifact} app.jar

# This should not be changed
ENTRYPOINT ["java","-jar","app.jar"]
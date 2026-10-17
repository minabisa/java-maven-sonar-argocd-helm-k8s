<div align="center">

# 🚀 End-to-End CI/CD & GitOps Pipeline

### Java Spring Boot · Jenkins · SonarQube · Docker · Kubernetes · Argo CD

**Automating application delivery from GitHub commit to Kubernetes deployment**

![AWS](https://img.shields.io/badge/AWS-EC2-FF9900?logo=amazonwebservices&logoColor=white) ![Terraform](https://img.shields.io/badge/Terraform-IaC-844FBA?logo=terraform&logoColor=white) ![Jenkins](https://img.shields.io/badge/Jenkins-CI%2FCD-D24939?logo=jenkins&logoColor=white) ![Docker](https://img.shields.io/badge/Docker-Containers-2496ED?logo=docker&logoColor=white) ![Kubernetes](https://img.shields.io/badge/Kubernetes-Minikube-326CE5?logo=kubernetes&logoColor=white) ![Argo CD](https://img.shields.io/badge/Argo_CD-GitOps-EF7B4D?logo=argo&logoColor=white)

</div>

---

## 📌 Project Overview

Built a hands-on CI/CD and GitOps workflow for a **Java 17 Spring Boot** application. **Terraform** provisions AWS infrastructure for Jenkins and SonarQube. Jenkins builds and tests the app, runs SonarQube analysis, publishes a versioned Docker image, and updates the Kubernetes manifest. **Argo CD** synchronizes that manifest to a local **Minikube** cluster.

## 🏗️ Architecture

```mermaid
flowchart TD
    A[Developer pushes code] --> B[GitHub Repository]
    B -->|Webhook| C[Jenkins on AWS EC2]
    C --> D[Maven Build & Unit Tests]
    D --> E[SonarQube Analysis & Quality Gate]
    E -->|Passed| F[Docker Build & Push]
    F --> G[(Docker Hub)]
    F --> H[Update image tag in GitHub manifest]
    H --> I[Argo CD GitOps Sync]
    I --> J[Kubernetes / Minikube]
    G -->|Pull image| J
    T[Terraform] -.->|Provision| C
```

## ⚙️ Pipeline Workflow

1. **Code:** GitHub webhook triggers Jenkins after an application change.
2. **Build & Test:** Maven compiles the application and runs unit tests.
3. **Code Quality:** SonarQube analyzes code; the Quality Gate must pass.
4. **Containerize:** Jenkins builds and pushes a tagged image to Docker Hub.
5. **GitOps:** Jenkins updates `spring-boot-app-manifests/deployment.yml` in GitHub.
6. **Deploy:** Argo CD synchronizes the updated manifest to Minikube.

## 📸 Project Screenshots

| Jenkins Pipeline | SonarQube Quality Gate |
|---|---|
| ![Successful Jenkins pipeline](screenshots/jenkins-pipeline.png) | ![Passed SonarQube Quality Gate](screenshots/sonarqube-quality-gate.png) |

| Docker Hub | Argo CD Deployment |
|---|---|
| ![Published Docker image](screenshots/dockerhub-image.png) | ![Healthy Argo CD deployment](screenshots/argocd-deployment.png) |

> Add your screenshots to the `screenshots/` folder using the filenames above.

## 🛠️ Challenges Solved

- Fixed **Java/Maven agent version mismatches** and failing unit tests.
- Resolved **SonarScanner cache permissions**, server configuration, and Quality Gate integration.
- Corrected **Docker CLI access** and **Docker Hub token permissions** in Jenkins.
- Debugged **Kubernetes Deployment YAML** and **Argo CD synchronization** errors.
- Addressed **recursive Jenkins builds** caused by CI-generated GitOps commits.

## 🧰 Tech Stack

**Infrastructure:** AWS EC2, Terraform  
**CI & Quality:** Jenkins, Maven, SonarQube, GitHub Webhooks  
**Containers & CD:** Docker, Docker Hub, Kubernetes, Minikube, Argo CD  
**Application:** Java 17, Spring Boot

## 🔗 Repository & Image

- **Source:** [GitHub repository](https://github.com/minabisa/java-maven-sonar-argocd-helm-k8s)
- **Docker image:** `minabisa90/ultimate-cicd`

---

<div align="center">

**Built to practice real-world DevOps automation, troubleshooting, and GitOps delivery.**

</div>

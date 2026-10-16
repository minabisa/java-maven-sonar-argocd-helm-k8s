
pipeline {
    agent {
        docker {
            image 'minabisa90/maven-abhishek-docker-agent:v1'
            args '-v /var/run/docker.sock:/var/run/docker.sock'
            reuseNode true
        }
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
    APP_DIR = '.'
    DOCKERFILE = 'src/Dockerfile'
    MANIFEST = 'spring-boot-app-manifests/deployment.yml'

    DOCKER_REPO = 'minabisa90/ultimate-cicd'
    GIT_BRANCH = 'main'
}

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                sh 'git status --short'
            }
        }

        stage('Build and Test') {
    steps {
        sh 'mvn clean verify'
    }
}

stage('Build Docker Image') {
    steps {
        sh '''
            docker build \
              -f src/Dockerfile \
              -t minabisa90/ultimate-cicd:${BUILD_NUMBER} \
              .
        '''
    }
}

        stage('Static Code Analysis') {
            steps {
                dir("${APP_DIR}") {
                    withSonarQubeEnv('SonarQube') {
                        sh '''
                            mvn -B sonar:sonar \
                              -Dsonar.projectKey=hello-cicd
                        '''
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build Docker Image') {
    steps {
        sh '''
            docker build \
              -f src/Dockerfile \
              -t ${DOCKER_REPO}:${BUILD_NUMBER} \
              .
        '''
    }
}

        stage('Push Docker Image') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'docker-cred',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_TOKEN'
                    )
                ]) {
                    sh '''
                        set +x
                        echo "$DOCKER_TOKEN" | docker login \
                          -u "$DOCKER_USER" \
                          --password-stdin

                        docker push ${DOCKER_REPO}:${BUILD_NUMBER}

                        docker logout
                    '''
                }
            }
        }

        stage('Update GitOps Manifest') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'github-cred',
                        usernameVariable: 'GIT_USER',
                        passwordVariable: 'GIT_TOKEN'
                    )
                ]) {
                    sh '''
                        set -eu
                        set +x

                        git config user.email "YOUR_EMAIL"
                        git config user.name "YOUR_NAME"

                        python3 - <<'PY'
import os
import re
from pathlib import Path

path = Path(os.environ["MANIFEST"])
text = path.read_text()
repository = os.environ["DOCKER_REPO"]
tag = os.environ["BUILD_NUMBER"]

pattern = (
    r"(?m)^(\\s*image:\\s*)"
    + re.escape(repository)
    + r":[^\\s]+"
)

updated, count = re.subn(
    pattern,
    lambda m: m.group(1) + repository + ":" + tag,
    text
)

if count != 1:
    raise SystemExit(
        f"Expected one matching image, found {count}"
    )

path.write_text(updated)
PY

                        git add "$MANIFEST"

                        if git diff --cached --quiet; then
                            echo "No manifest changes"
                            exit 0
                        fi

                        git commit -m \
                          "ci: deploy image ${BUILD_NUMBER}"

                        AUTH=$(printf '%s:%s' \
                          "$GIT_USER" "$GIT_TOKEN" | base64 -w0)

                        git -c \
                          http.https://github.com/.extraheader="AUTHORIZATION: basic $AUTH" \
                          push \
                          "https://github.com/${GIT_REPO}.git" \
                          HEAD:${GIT_BRANCH}
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'CI pipeline completed successfully.'
            echo 'Argo CD can now sync the GitOps changes.'
        }

        failure {
            echo 'Pipeline failed. Check the Jenkins stage logs.'
        }

        always {
            cleanWs()
        }
    }

    sed -i -E \
  "s|(image: minabisa90/ultimate-cicd:)[^[:space:]]+|\1${BUILD_NUMBER}|" \
  spring-boot-app-manifests/deployment.yml
}

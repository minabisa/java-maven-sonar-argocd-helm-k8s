
pipeline {
    agent {
    docker {
        image 'maven:3.9-eclipse-temurin-17'
        args '-v /var/run/docker.sock:/var/run/docker.sock'
        reuseNode true
    }
}

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        DOCKER_REPO = 'minabisa90/ultimate-cicd'
        MANIFEST = 'spring-boot-app-manifests/deployment.yml'
        GIT_REPO = 'minabisa/java-maven-sonar-argocd-helm-k8s'
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
        sh '''
            java -version
            javac -version
            mvn -version
            mvn clean verify
        '''
    }
}
stage('Static Code Analysis') {
    steps {
        withSonarQubeEnv('sonarqube') {
            sh '''
                mvn -B org.sonarsource.scanner.maven:sonar-maven-plugin:sonar \
                  -Dsonar.projectKey=hello-cicd
            '''
        }
    }
}
        

        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
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

                        git config user.email "YOUR_GITHUB_EMAIL"
                        git config user.name "minabisa"

                        sed -i -E \
                          's|image: minabisa90/ultimate-cicd:[^[:space:]]+|image: minabisa90/ultimate-cicd:'"${BUILD_NUMBER}"'|' \
                          "$MANIFEST"

                        grep 'image:' "$MANIFEST"

                        git add "$MANIFEST"

                        if git diff --cached --quiet; then
                            echo "No manifest changes"
                            exit 0
                        fi

                        git commit -m \
                          "ci: update image to ${BUILD_NUMBER} [skip ci]"

                        AUTH=$(printf '%s:%s' \
                          "$GIT_USER" "$GIT_TOKEN" | base64 | tr -d '\\n')

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
            echo 'Argo CD can now synchronize the GitOps changes.'
        }

        failure {
            echo 'Pipeline failed. Check the Jenkins console output.'
        }

        always {
            cleanWs()
        }
    }
}

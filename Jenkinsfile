pipeline {
    agent any

    environment {
        // Nom de l'image Docker avec votre compte DockerHub
        DOCKER_IMAGE = "bahloulfares/angular-app"
        // Le tag sera défini dynamiquement dans le stage Setup
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Clonage du repository GitHub...'
                git branch: 'main', url: 'https://github.com/bahloulfares/datacamp_docker_angular.git'
            }
        }

        stage('Setup Tag') {
            steps {
                script {
                    // Utilisation de git rev-parse pour obtenir le hash court du commit
                    env.DOCKER_TAG = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    echo "Docker Tag généré : ${env.DOCKER_TAG}"
                }
            }
        }

        stage('Build Image') {
            steps {
                echo "Construction de l'image Docker : ${DOCKER_IMAGE}:${DOCKER_TAG}..."
                // Utilisation du cache Docker pour optimiser la durée de build
                sh "docker build --pull --cache-from ${DOCKER_IMAGE}:latest -t ${DOCKER_IMAGE}:${DOCKER_TAG} -t ${DOCKER_IMAGE}:latest ."
            }
        }

        stage('Test & Healthcheck Docker') {
            steps {
                echo "Test de l'image Docker..."
                // Validation très simple : on vérifie que Nginx peut être lancé
                sh "docker run --rm ${DOCKER_IMAGE}:${DOCKER_TAG} nginx -t"
            }
        }

        stage('Push to DockerHub') {
            steps {
                // Nécessite un credential de type "Username with password" nommé 'dockerhub-credentials'
                withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', passwordVariable: 'DOCKERHUB_PASS', usernameVariable: 'DOCKERHUB_USER')]) {
                    echo 'Connexion à DockerHub...'
                    sh "echo \$DOCKERHUB_PASS | docker login -u \$DOCKERHUB_USER --password-stdin"
                    echo "Push de l'image sur DockerHub..."
                    sh "docker push ${DOCKER_IMAGE}:${DOCKER_TAG}"
                    sh "docker push ${DOCKER_IMAGE}:latest"
                }
            }
        }

        stage('Deploy to Agent (SSH)') {
            steps {
                echo "Déploiement sur le serveur distant jenkins-agent..."
                // Utilisation de sshagent comme demandé avec les credentials 'Vagrant_ssh'
                sshagent(credentials: ['Vagrant_ssh']) {
                    sh """
                        # Désactivation de la vérification stricte des clés hôtes pour le déploiement interne
                        SSH_CMD="ssh -o StrictHostKeyChecking=no jenkins@jenkins-agent"

                        echo "1. Récupération de la nouvelle image..."
                        \$SSH_CMD "docker pull ${DOCKER_IMAGE}:${DOCKER_TAG}"

                        echo "2. Arrêt et suppression de l'ancien conteneur s'il existe..."
                        \$SSH_CMD "docker stop angular-app-container || true"
                        \$SSH_CMD "docker rm angular-app-container || true"

                        echo "3. Lancement du nouveau conteneur (mapping 8085 -> 80)..."
                        \$SSH_CMD "docker run -d --name angular-app-container -p 8085:80 ${DOCKER_IMAGE}:${DOCKER_TAG}"
                    """
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                echo "Vérification du déploiement..."
                // Attente que le conteneur soit prêt
                sleep time: 5, unit: 'SECONDS'
                // Test sur le port exposé. Comme le conteneur tourne sur l'agent, on le contacte depuis le workspace Jenkins.
                // Selon le mapping de port de la machine hôte/agent (8085).
                sh """
                    if curl -s http://jenkins-agent:8085 > /dev/null; then
                        echo "Le déploiement est un succès ! L'application répond."
                    else
                        echo "Échec : L'application ne répond pas sur jenkins-agent:8085."
                        exit 1
                    fi
                """
            }
        }
    }

    post {
        success {
            echo "Pipeline terminée avec succès !"
            // Nettoyage de l'image en local pour libérer de l'espace
            sh "docker rmi ${DOCKER_IMAGE}:${DOCKER_TAG} || true"
        }
        failure {
            echo "La pipeline a échoué. Exécution d'un rollback..."
            // Rollback basique: redémarrer la dernière image stable (latest)
            sshagent(credentials: ['Vagrant_ssh']) {
                sh """
                    ssh -o StrictHostKeyChecking=no jenkins@jenkins-agent "docker stop angular-app-container || true && docker rm angular-app-container || true && docker run -d --name angular-app-container -p 8085:80 ${DOCKER_IMAGE}:latest"
                """
            }
            error("La pipeline a échoué. Vérifiez les logs.")
        }
        always {
            echo "Fin du job."
        }
    }
}

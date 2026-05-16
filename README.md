# Déploiement CI/CD Angular avec Docker et Jenkins

Ce dossier contient l'ensemble des fichiers nécessaires à l'intégration continue de votre application Angular (`datacamp_docker_angular`).

## Architecture CI/CD

L'architecture s'appuie sur le *Docker-out-of-Docker* : l'agent Jenkins exécute les commandes Docker, mais le démon Docker qui les traite est celui de votre machine hôte (grâce au montage de `/var/run/docker.sock`).

1. **Jenkins Controller** pilote le pipeline.
2. **Jenkins Agent** exécute le pipeline. Il build l'image et la pousse vers DockerHub.
3. À la fin, via **SSH**, Jenkins Agent se connecte à lui-même (ou à tout autre serveur distant SSH configuré avec la clé) pour pull l'image depuis DockerHub et lancer un conteneur Angular.

## Explication du Dockerfile Multi-Stage

Le `Dockerfile` est divisé en deux étapes (multi-stage) pour optimiser la taille de l'image finale :

1. **Stage 1 (Build)** : Utilise l'image `node:12.7-alpine`. Il télécharge les dépendances (`npm install`) puis compile l'application Angular avec la commande `npm run build --prod`. Ce conteneur est "lourd" mais ne sert que pour la compilation.
2. **Stage 2 (Runtime)** : Utilise l'image `nginx:1.17.1-alpine`. Cette image récupère **uniquement** les fichiers générés (fichiers HTML, JS, CSS) de l'Étape 1 et les copie dans son dossier racine (`/usr/share/nginx/html`). Elle utilise le fichier `nginx.conf` optimisé pour les SPA (Single Page Applications) qui gère le routing (redirection des URL vers `index.html`).

*Résultat : l'image finale est très légère (quelques Mo) et sécurisée, car elle ne contient ni le code source Angular ni NodeJS.*

## Instructions de mise en place

### 1. Mettre à jour l'infrastructure (Déjà fait)

Votre fichier `docker-compose.yml` et `jenkins-agent/Dockerfile` ont été mis à jour.
Re-créez les conteneurs :
```bash
docker compose up -d --build
```

### 2. Ajouter les fichiers au repo GitLab

Copiez ces trois fichiers (`Dockerfile`, `Jenkinsfile`, `nginx.conf`) à la **racine** de votre repository GitLab `datacamp_docker_angular` et poussez le tout.

*N'oubliez pas de modifier la variable `DOCKER_IMAGE` dans le Jenkinsfile avec votre vrai nom de compte DockerHub.*

### 3. Configurer les Credentials dans Jenkins

Rendez-vous dans **Jenkins > Manage Jenkins > Credentials > System > Global credentials**.

1. **Credentials DockerHub** :
   - Type : *Username with password*
   - Username : *Votre identifiant DockerHub*
   - Password : *Votre mot de passe ou Access Token DockerHub*
   - ID : **dockerhub-credentials**

2. **Credentials SSH pour le déploiement (Vagrant_ssh)** :
   - Type : *SSH Username with private key*
   - Username : `jenkins` (ou le nom de l'utilisateur distant)
   - Private Key : Entrez la clé privée (si vous utilisez le jenkins-agent local, c'est le contenu de votre fichier `jenkins_agent_key`)
   - ID : **Vagrant_ssh**

### 4. Créer le Pipeline Jenkins

1. Allez sur le Dashboard Jenkins > **New Item**
2. Nommez-le "Angular-Pipeline" et choisissez **Pipeline**. Cliquez sur OK.
3. Allez dans la section **Pipeline** en bas :
   - Definition : *Pipeline script from SCM*
   - SCM : *Git*
   - Repository URL : `https://gitlab.com/jmlhmd/datacamp_docker_angular.git`
   - Branch Specifier : `*/main`
   - Script Path : `Jenkinsfile`
4. Cliquez sur **Save** et lancez **Build Now**.

---
*Ce tutoriel garantit un déploiement sécurisé, performant (grâce au cache Docker et au multi-stage) et facile à surveiller.*

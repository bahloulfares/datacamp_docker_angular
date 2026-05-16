# Étape 1 : Build de l'application Angular
FROM node:12.7-alpine AS build
WORKDIR /app

# Copie des fichiers de configuration pour installer les dépendances
COPY package.json package-lock.json ./
RUN npm install

# Copie du reste de l'application et build
COPY . .
RUN npm run build -- --prod

# Étape 2 : Serveur Nginx pour le runtime
FROM nginx:1.17.1-alpine

# Copie de la configuration Nginx optimisée
COPY nginx.conf /etc/nginx/nginx.conf

# Copie des fichiers compilés depuis l'étape de build vers le dossier Nginx
# Assurez-vous que "aston-villa-app" correspond au nom de sortie (outputPath) dans votre angular.json
COPY --from=build /app/dist/aston-villa-app /usr/share/nginx/html

# Exposition du port
EXPOSE 80

# Démarrage de Nginx
CMD ["nginx", "-g", "daemon off;"]

#!/bin/bash
set -e

# Variables nécessaires
DB_HOST=${WORDPRESS_DB_HOST}
DB_PORT=${WORDPRESS_DB_PORT:-3306}
DB_NAME=${WORDPRESS_DB_NAME}
DB_USER=${WORDPRESS_DB_USER}
DB_PASSWORD=${WORDPRESS_DB_PASSWORD}
WP_URL=${HTTP_HOST}
WP_TITLE=${WORDPRESS_TITLE}
WP_ADMIN=${WP_ADMIN}
WP_ADMIN_PASSWORD=${WP_ADMIN_PASSWORD}
WP_ADMIN_EMAIL=${WP_ADMIN_EMAIL}

# Dossier WordPress
WP_PATH="/var/www/html"

# Installer WP-CLI si nécessaire
if ! command -v wp &> /dev/null; then
    echo "Installation de WP-CLI..."
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp
    echo "WP-CLI installé avec succès."
fi

# Attendre que la base de données soit prête
echo "Attente de 20 secondes pour permettre à la base de données de démarrer..."
sleep 20

# Télécharger WordPress et écraser les fichiers existants
echo "Téléchargement et écrasement des fichiers WordPress..."
wp core download --path="$WP_PATH" --force --allow-root

# Forcer la création du fichier wp-config.php
echo "Création ou écrasement du fichier wp-config.php..."
wp config create \
    --path="$WP_PATH" \
    --dbname="$DB_NAME" \
    --dbuser="$DB_USER" \
    --dbpass="$DB_PASSWORD" \
    --dbhost="$DB_HOST:$DB_PORT" \
    --force \
    --allow-root

# Vérifier si WordPress est déjà installé
if ! wp core is-installed --path="$WP_PATH" --allow-root; then
    echo "Installation de WordPress..."
    wp core install \
        --path="$WP_PATH" \
        --url="$WP_URL" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email \
        --allow-root
else
    echo "WordPress est déjà installé."
fi

# Supprimer tous les plugins
echo "Suppression de tous les plugins..."
wp plugin delete $(wp plugin list --field=name --allow-root) --allow-root || echo "Aucun plugin à supprimer."

# Supprimer tous les thèmes sauf Twenty Twenty-Four
echo "Suppression des thèmes existants..."
wp theme delete $(wp theme list --field=name --allow-root | grep -v twentytwentyfour) --allow-root || echo "Aucun thème à supprimer."

# Installer et activer le thème Twenty Twenty-Four
echo "Installation et activation du thème Twenty Twenty-Four..."
wp theme install twentytwentyfour --activate --allow-root

# Supprimer tous les contenus (posts, médias, pages, commentaires)
echo "Suppression des contenus existants (posts, médias, pages, commentaires)..."
wp post delete $(wp post list --post_type='post' --format=ids --allow-root) --force --allow-root || echo "Aucun post à supprimer."
wp post delete $(wp post list --post_type='page' --format=ids --allow-root) --force --allow-root || echo "Aucune page à supprimer."
wp comment delete $(wp comment list --format=ids --allow-root) --force --allow-root || echo "Aucun commentaire à supprimer."
wp media delete $(wp media list --format=ids --allow-root) --force --allow-root || echo "Aucun média à supprimer."

# Ajouter la gestion HTTPS dans wp-config.php
if ! grep -q "HTTP_X_FORWARDED_PROTO" /var/www/html/wp-config.php; then
    echo "Adding code for HTTPS proxy to wp-config.php..."
    sed -i "/\/\* That's all, stop editing! Happy publishing. \*\//i \
// Handle HTTPS behind a proxy\nif (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {\n    \$_SERVER['HTTPS'] = 'on';\n}" /var/www/html/wp-config.php
    echo "Code for HTTPS proxy successfully added to wp-config.php."
else
    echo "Code for HTTPS proxy already exists in wp-config.php."
fi
wp config set FORCE_SSL_ADMIN true --raw --path=/var/www/html --allow-root;

echo "Configuration terminée. WordPress est prêt à l'emploi."

exec apache2-foreground;

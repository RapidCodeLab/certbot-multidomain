#!/bin/bash

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

# add you domains
domains=(domain1.com domain2.com domain3.com)
rsa_key_size=4096
data_path="./data/certbot"
email="admin@gmail.com" # Adding a valid address is strongly recommended
staging=0 # Set to 1 if you're testing your setup to avoid hitting request limits


if [ -d "$data_path" ]; then
  read -p "Existing data found for $domains. Continue and replace existing certificate? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi



if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
  echo
fi

 
#for domain in ${domains[@]}; do
  #echo "### Creating dummy certificate for $domain ..."
  echo "### Creating dummy multi-domain sertificate..."
  path="/etc/letsencrypt/live/multi"
  mkdir -p "$data_path/conf/live/multi"
  docker-compose run --rm --entrypoint "\
    openssl req -x509 -nodes -newkey rsa:1024 -days 1\
      -keyout '$path/privkey.pem' \
      -out '$path/fullchain.pem' \
      -subj '/CN=localhost'" certbot
  echo
#done





echo "### Starting nginx ..."
docker-compose up --force-recreate -d openresty
echo


#for domain in ${domains[@]}; do
  echo "### Deleting dummy multi-domain sertificate ..."
  docker-compose run --rm --entrypoint "\
    rm -Rf /etc/letsencrypt/live/multi && \
    rm -Rf /etc/letsencrypt/archive/multi && \
    rm -Rf /etc/letsencrypt/renewal/multi.conf" certbot
  echo
#done

# Select appropriate email arg
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# Enable staging mode if needed
if [ $staging != "0" ]; then staging_arg="--staging"; fi

domain_args=""
for domain in ${domains[@]}; do

     echo "### Add $domain to certificate request ..."

    domain_args+=" -d $domain"
done     
    docker-compose run --rm --entrypoint "\
      certbot certonly --webroot -w /var/www/certbot \
        $staging_arg \
        $email_arg \
        $domain_args \
        --rsa-key-size $rsa_key_size \
        --agree-tos \
        --break-my-certs \
        --cert-name multi \
        --force-renewal" certbot
    echo

#done



echo "### Reloading nginx ..."
docker-compose exec openresty nginx -s reload

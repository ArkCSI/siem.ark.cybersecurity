#!/bin/bash

# Verificar si se está ejecutando como root
if [[ $EUID -ne 0 ]]; then
   echo "Este script debe ejecutarse como root" 
   exit 1
fi

# Instalando las dependencias
apt-get install curl

# Descargando la clave de Elasticsearch
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch |  gpg --dearmor -o /etc/apt/trusted.gpg.d/elastic-archive-keyring.gpg

# Agregando el repositorio de Elasticsearch
echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" |  tee -a /etc/apt/sources.list.d/elastic-8.x.list

# Instalando Elasticsearch
bash -c "export HOSTNAME=siem.ark.cybersecurity; apt-get install elasticsearch -y | tee ~/ElasticLogs.md"

# Comentando una línea en el archivo de configuración de Elasticsearch
sed -e '/cluster.initial_master_nodes/ s/^#*/#/' -i /etc/elasticsearch/elasticsearch.yml

# Agregando una configuración adicional en el archivo de configuración de Elasticsearch
echo "discovery.type: single-node" |  tee -a /etc/elasticsearch/elasticsearch.yml

# Instalando Kibana
apt install kibana

# Generando claves de encriptación para Kibana
/usr/share/kibana/bin/kibana-encryption-keys generate -q

# Configurando el host de Kibana
echo "server.host: \"siem.ark.cybersecurity\"" |  tee -a /etc/kibana/kibana.yml

# Habilitando y reiniciando los servicios de Elasticsearch y Kibana
systemctl enable elasticsearch kibana --now

# Generando un certificado de autoridad (CA) para Elasticsearch
/usr/share/elasticsearch/bin/elasticsearch-certutil ca

# Generando un certificado firmado para el servidor de Kibana
/usr/share/elasticsearch/bin/elasticsearch-certutil cert --ca elastic-stack-ca.p12 --dns siem.ark.cybersecurity,elastic.ark.cybersecurity,PurpleTeam --out kibana-server.p12

# Extrayendo el certificado del archivo PKCS12 y guardándolo como archivo separado
openssl pkcs12 -in /usr/share/elasticsearch/kibana-server.p12 -out /etc/kibana/kibana-server.crt -clcerts -nokeys

# Extrayendo la clave privada del archivo PKCS12 y guardándola como archivo separado
openssl pkcs12 -in /usr/share/elasticsearch/kibana-server.p12 -out /etc/kibana/kibana-server.key -nocerts -nodes

# Configurando los permisos y propietarios de los archivos de certificado y clave
chown root:kibana /etc/kibana/kibana-server.key
chown root:kibana /etc/kibana/kibana-server.crt
chmod 660 /etc/kibana/kibana-server.key
chmod 660 /etc/kibana/kibana-server.crt

# Configurando Kibana para habilitar SSL
echo "server.ssl.enabled: true" |  tee -a /etc/kibana/kibana.yml
echo "server.ssl.certificate: /etc/kibana/kibana-server.crt" |  tee -a /etc/kibana/kibana.yml
echo "server.ssl.key: /etc/kibana/kibana-server.key" |  tee -a /etc/kibana/kibana.yml
echo "server.publicBaseUrl: \"https://siem.ark.cybersecurity:5601\"" |  tee -a /etc/kibana/kibana.yml

# Reiniciando el servicio  Kibana y Elasitcsearch
systemctl restart kibana elasticsearch

# Generando token de enrolamiento y codigo de verificacion
echo " "
echo "Por favor revisa que siem.ark.cybersecurity esté asociado a la  IP de tu Kali en /etc/hosts para permitir la conexión a Kibana"
echo " "
echo "Deberia ser algo similar a:"
echo " "
echo " 192.168.100.25   siem.ark.cybersecurity"
echo " "
echo " "
echo " Token de enrolamiento:"
/usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana
echo " "
echo " Codigo de verificacion:"
/usr/share/kibana/bin/kibana-verification-code


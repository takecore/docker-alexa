
if [ ! -f /opt/alexa/.initialized ]; then
  touch /opt/alexa/.initialized

  cd /opt/alexa/certs

  # Create ssl certificats
  sed -i 's/YOUR_/$ENV::/' ssl.cnf 
  sed -i -r 's/(10.0.2.2)/\1\nDNS.2                   = $ENV::COMPANION_DNS_NAME/' ssl.cnf

  mkdir -p ca server client

  export COUNTRY_NAME=${SSL_COUNTRY_NAME}
  export STATE_OR_PROVINCE=${SSL_STATE_OR_PROVINCE}
  export CITY=${SSL_CITY}
  export ORGANIZATION=${SSL_ORGANIZATION}
  export ORGANIZATIONAL_UNIT=${SSL_ORGANIZATIONAL_UNIT}
  
  # Create the CA
  openssl genrsa -out ca/ca.key 4096
  COMMON_NAME=${SSL_CA_COMMON_NAME} openssl req -new -x509 -days 365 -key ca/ca.key -out ca/ca.crt -config ssl.cnf -sha256

  # Create the Client KeyPair for the Device Code
  openssl genrsa -out client/client.key 2048
  COMMON_NAME="${ALEXA_DEVICE_ID}:${ALEXA_DEVICE_SERIAL_NUMBER}" openssl req -new -key client/client.key -out client/client.csr -config ssl.cnf -sha256
  openssl x509 -req -days 365 -in client/client.csr -CA ca/ca.crt -CAkey ca/ca.key -set_serial 01 -out client/client.crt -sha256
  openssl pkcs12 -inkey client/client.key -in client/client.crt -export -out client/client.pkcs12 -password pass:""

  # Create the KeyPair for the Node.js Companion Service
  openssl genrsa -out server/node.key 2048
  COMMON_NAME="${COMPANION_DNS_NAME}" openssl req -new -key server/node.key -out server/node.csr -config ssl.cnf -sha256
  openssl x509 -req -days 365 -in server/node.csr -CA ca/ca.crt -CAkey ca/ca.key -set_serial 02 -out server/node.crt -sha256

  # Create the KeyPair for the Jetty server running on the Device Code in companionApp mode
  openssl genrsa -out server/jetty.key 2048
  COMMON_NAME="${COMPANION_DNS_NAME}" openssl req -new -key server/jetty.key -out server/jetty.csr -config ssl.cnf -sha256
  COMMON_NAME="${COMPANION_DNS_NAME}" openssl x509 -req -days 365 -in server/jetty.csr -CA ca/ca.crt -CAkey ca/ca.key -set_serial 03 -out server/jetty.crt -extensions v3_req -extfile ssl.cnf -sha256
  openssl pkcs12 -inkey server/jetty.key -in server/jetty.crt -export -out server/jetty.pkcs12 -password pass:""

  # Configure companion service
  cd /opt/alexa/companionService
  sed -i -r "s/(redirectUrl: )[^,]+,/\1\"\${COMPANION_URL}\/authresponse\",/" template_config_js
  ClientID=${ALEXA_OAUTH_CLIENT_ID} \
  ClientSecret=${ALEXA_OAUTH_CLIENT_SECRET} \
  Java_Client_Loc=/opt/alexa \
  ProductID=${ALEXA_DEVICE_ID} \
  DeviceSerialNumber=${ALEXA_DEVICE_SERIAL_NUMBER} \
  envsubst < template_config_js > config.js

  # Configure java client
  cd /opt/alexa/javaclient
  sed -i -r "s/(\"serviceUrl\":)[^,]+,/\1\"\${COMPANION_URL}\",/" template_config_json
  Java_Client_Loc=/opt/alexa \
  KeyStorePassword="" \
  Locale=${ALEXA_LOCALE} \
  ProductID=${ALEXA_DEVICE_ID} \
  DeviceSerialNumber=${ALEXA_DEVICE_SERIAL_NUMBER} \
  Wake_Word_Detection_Enabled=1 \
  envsubst < template_config_json > config.json


fi



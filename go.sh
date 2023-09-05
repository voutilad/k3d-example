#!/bin/sh
set -e

DOMAIN="${DOMAIN:-customredpandadomain.local}"
AGENTS="${AGENTS:-3}"
SERVERS="${SERVERS:-1}"
MEM="${MEM:-3G}"
TOPIC="${TOPIC:-twitch_chat}"

### 0. Pre-requisites
for cmd in k3d helm kubectl; do
    if [ -z "$(which "${cmd}")" ]; then
        echo "!! Failed to find ${cmd} in path. Is it installed?"
        exit 1;
    else
        echo "> Using ${cmd} @ $(which ${cmd})"
    fi
done

### 1. We need a k3d cluster.
echo "> Looking for existing k3d Redpanda cluster..."
if ! k3d cluster list redpanda 2>&1 > /dev/null; then
    echo ">> Creating a new ${SERVERS} node cluster..."
    k3d cluster create redpanda \
        --servers "${SERVERS}" --agents "${AGENTS}" \
        --agents-memory "${MEM}" \
        --registry-create rp-registry
else
    echo ">> Found! Making sure cluster is started..."
    k3d cluster start redpanda --wait 2>&1 > /dev/null
fi

### 2. Update Helm.
echo "> Updating Helm charts..."
helm repo add redpanda https://charts.redpanda.com > /dev/null
helm repo add jetstack https://charts.jetstack.io > /dev/null
helm repo update > /dev/null

### 3. Install Cert-Manager (if needed)
echo "> Looking for Cert-Manager..."
if ! kubectl get service cert-manager -n cert-manager > /dev/null; then
    echo ">> Installing Cert-Manager..."
    helm install cert-manager jetstack/cert-manager \
         --set installCRDs=true \
         --namespace cert-manager \
         --create-namespace
    echo ">> Waiting for rollout..."
    kubectl -n cert-manager rollout status deployment cert-manager --watch
fi

### 4. Install Redpanda (if needed)
echo "> Looking for Redpanda..."
if ! kubectl get service redpanda -n redpanda > /dev/null; then
    echo ">> Installing Redpanda broker cluster..."
    helm install redpanda redpanda/redpanda \
         --namespace redpanda \
         --create-namespace \
         --set external.domain=${DOMAIN} \
         --set statefulset.initContainers.setDataDirOwnership.enabled=true
    echo ">> Waiting for rollout..."
    kubectl -n redpanda rollout status statefulset redpanda --watch
fi

### 5. Bootstrap our Topic(s)
echo "> Checking if topic ${TOPIC} exists..."
if ! kubectl -n redpanda exec -it redpanda-0 -c redpanda -- \
     rpk topic list \
     --brokers redpanda.redpanda.svc.cluster.local.:9093 \
     --tls-truststore /etc/tls/certs/default/ca.crt --tls-enabled \
   | grep "${TOPIC}"; then
    echo ">> Creating topic ${TOPIC}"
    kubectl -n redpanda exec -it redpanda-0 -c redpanda -- \
            rpk topic create "${TOPIC}" -r "${SERVERS}" \
            --brokers redpanda.redpanda.svc.cluster.local.:9093 \
            --tls-truststore /etc/tls/certs/default/ca.crt --tls-enabled
fi

### 5. Update our copy of the self-signed root CA file
echo "> Fetching copy of root CA..."
kubectl -n redpanda get secret \
	redpanda-default-root-certificate \
	-o go-template='{{ index .data "ca.crt" | base64decode }}' \
	> ca.crt

### 6. Finding the port for our Docker Registry
PORT=$(docker ps --filter "name=rp-registry" --format "{{.Ports}}" \
           | sed 's/.*:\([0-9]*\).*->.*/\1/')
if [ -z "${PORT}" ]; then
    echo "!! Unable to find the locally mapped TCP port for the Docker registry!"
    exit 1
fi

### 7. Building our Docker image.
echo "> Building Docker image..."
docker build -t "python-app:latest" .

### 8. Push the image to the Repository
echo "> Pushing image to localhost:${PORT}..."
docker tag "python-app:latest" "localhost:${PORT}/python-app:latest" > /dev/null
docker push "localhost:${PORT}/python-app:latest" > /dev/null

### 9. Running our application.
echo "> Running our app..."
kubectl run "python-app" \
	-it --rm=true \
        --restart=Never \
	--image "rp-registry:5000/python-app:latest" \
        -- "${TOPIC}"

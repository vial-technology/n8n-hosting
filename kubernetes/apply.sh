#!/bin/bash

echo "Applying nginx-ingress-controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

echo "Apply cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml

echo "Apply letsencrypt-prod..."
kubectl apply -f letsencrypt-prod.yaml

echo "Applying n8n ingress..."
kubectl apply -f n8n-ingress.yaml

echo "Applying n8n Kubernetes resources..."

echo "Applying updated PostgreSQL secret..."
kubectl apply -f postgres-secret.yaml

echo "Applying updated PostgreSQL deployment..."
kubectl apply -f postgres-deployment.yaml

echo "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l service=postgres-n8n -n n8n --timeout=300s

echo "Applying updated n8n deployment..."
kubectl apply -f n8n-deployment.yaml

echo "Waiting for n8n to be ready..."
kubectl wait --for=condition=ready pod -l service=n8n -n n8n --timeout=300s

echo "Checking pod status..."
kubectl get pods -n n8n

echo "Checking n8n logs..."
kubectl logs -l service=n8n -n n8n --tail=50

#!/bin/bash

# =============================================================================
# N8N Kubernetes Deployment Script
# =============================================================================
# This script deploys n8n with all required dependencies to a Kubernetes cluster
# including Istio, cert-manager, PostgreSQL, and the n8n application itself.

set -e  # Exit on any error

# =============================================================================
# 1. INSTALL ISTIO AND GATEWAY API
# =============================================================================
echo "🔧 Installing Gateway API CRDs..."
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  { kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.3.0" | kubectl apply -f -; }

echo "🔧 Installing Istio..."
istioctl install --set profile=minimal -y

echo "🔧 Setting up Istio ingress namespace and gateway..."
kubectl create namespace istio-ingress &> /dev/null || true
kubectl apply -f n8n-ingress.yaml
kubectl wait -n istio-ingress --for=condition=programmed gateways.gateway.networking.k8s.io n8n-gateway

# =============================================================================
# 2. INSTALL CERT-MANAGER AND SSL CERTIFICATES
# =============================================================================
echo "🔐 Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml

echo "🔐 Configuring Let's Encrypt production certificates..."
kubectl apply -f letsencrypt-prod.yaml

# =============================================================================
# 3. DEPLOY DATABASE LAYER
# =============================================================================
echo "🗄️  Deploying PostgreSQL..."
kubectl apply -f postgres-secret.yaml
kubectl apply -f postgres-deployment.yaml

echo "⏳ Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l service=postgres-n8n -n n8n --timeout=300s

# =============================================================================
# 4. DEPLOY N8N APPLICATION
# =============================================================================
echo "🚀 Deploying n8n services..."
kubectl apply -f n8n-service.yaml
kubectl apply -f n8n-service-local.yaml

echo "🚀 Deploying n8n application..."
kubectl apply -f n8n-deployment.yaml
kubectl apply -f n8n-deployment-local.yaml

echo "⏳ Waiting for n8n to be ready..."
kubectl wait --for=condition=ready pod -l service=n8n -n n8n --timeout=300s

# =============================================================================
# 5. VERIFICATION AND STATUS
# =============================================================================
echo "✅ Deployment complete! Checking status..."
echo ""
echo "📊 Pod status:"
kubectl get pods -n n8n

echo ""
echo "📋 Recent n8n logs:"
kubectl logs -l service=n8n -n n8n --tail=50

echo ""
echo "🎉 Deployment finished successfully!"

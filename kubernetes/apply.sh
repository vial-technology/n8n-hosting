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

echo "🔧 Installing Istio with Ambient Mesh enabled..."
istioctl install --set profile=ambient -y

echo "🔧 Creating n8n namespace with Ambient Mesh..."
kubectl apply -f namespace.yaml

echo "🔧 Setting up Istio ingress namespace and gateway..."
kubectl create namespace istio-ingress &> /dev/null || true
kubectl apply -f n8n-ingress.yaml
kubectl wait -n istio-ingress --for=condition=programmed gateways.gateway.networking.k8s.io n8n-gateway

# =============================================================================
# 2. INSTALL OBSERVABILITY TOOLS (KIALI & PROMETHEUS)
# =============================================================================
echo "📊 Installing Prometheus for metrics collection..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml

echo "📊 Installing Kiali for service mesh visualization..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml

echo "⏳ Waiting for observability tools to be ready..."
kubectl wait --for=condition=ready pod -l app=kiali -n istio-system --timeout=300s
kubectl wait --for=condition=ready pod -l app=prometheus -n istio-system --timeout=300s

# =============================================================================
# 3. INSTALL CERT-MANAGER AND SSL CERTIFICATES
# =============================================================================
echo "🔐 Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.4/cert-manager.yaml

echo "🔐 Configuring Let's Encrypt production certificates..."
kubectl apply -f letsencrypt-prod.yaml

# =============================================================================
# 4. DEPLOY DATABASE LAYER
# =============================================================================
echo "🗄️  Deploying PostgreSQL..."
kubectl apply -f postgres-secret.yaml
kubectl apply -f postgres-deployment.yaml

echo "⏳ Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l service=postgres-n8n -n n8n --timeout=300s

# =============================================================================
# 5. DEPLOY N8N APPLICATION
# =============================================================================
echo "🚀 Deploying n8n services..."
kubectl apply -f n8n-service.yaml

echo "🚀 Deploying n8n application..."
kubectl apply -f n8n-deployment.yaml

echo "⏳ Waiting for n8n to be ready..."
kubectl wait --for=condition=ready pod -l service=n8n -n n8n --timeout=300s

echo "🔧 Deploying Ambient Mesh waypoint proxy..."
kubectl apply -f n8n-waypoint.yaml

# =============================================================================
# 6. VERIFICATION AND STATUS
# =============================================================================
echo "✅ Deployment complete! Checking status..."
echo ""
echo "📊 Pod status:"
kubectl get pods -n n8n

echo ""
echo "📋 Recent n8n logs:"
kubectl logs -l service=n8n -n n8n --tail=50

echo ""
echo "🔍 Observability tools status:"
kubectl get pods -n istio-system | grep -E "(kiali|prometheus)"

echo ""
echo "🔧 Ambient Mesh status:"
kubectl get gateway -n n8n
kubectl get pods -n istio-system | grep -E "(ztunnel|waypoint)"

echo ""
echo "🌐 Access URLs:"
echo "   - n8n: https://n8n.vial.com"
echo "   - Kiali: http://localhost:20001 (run: kubectl port-forward -n istio-system svc/kiali 20001:20001)"
echo "   - Prometheus: http://localhost:9090 (run: kubectl port-forward -n istio-system svc/prometheus 9090:9090)"

echo ""
echo "🎉 Deployment finished successfully!"

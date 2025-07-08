kubectl get service n8n -n n8n -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

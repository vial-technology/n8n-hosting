get-ip:
	kubectl get service n8n -n n8n -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

port-forward:
	kubectl port-forward -n n8n service/n8n-local 5678:5678

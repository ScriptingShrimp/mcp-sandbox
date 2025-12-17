# SearXNG Kubernetes Deployment Guide

This guide explains how to deploy SearXNG using `podman play kube` for local development with the MCP server.

## Prerequisites

- Podman installed and configured
- Kubernetes support enabled in Podman (usually available by default)

## Deployment

### 1. Deploy the Stack

Deploy all SearXNG components:

```bash
podman play kube searxng-k8s.yaml
```

This will create:
- A `searxng` namespace
- ConfigMaps for SearXNG settings and limiter configuration
- PersistentVolumeClaims for data persistence
- Services for SearXNG and Valkey
- Deployments for both services

### 2. Verify Deployment

Check that all pods are running:

```bash
podman kube down searxng-k8s.yaml  # This won't work, let me check the right command
```

Actually, use kubectl-style commands or podman commands:

```bash
# List pods in the namespace
podman pod ps

# Or if using kubectl with podman
kubectl get pods -n searxng

# Check services
kubectl get svc -n searxng
```

### 3. Access SearXNG

SearXNG should be accessible at:

- **Web UI**: http://localhost:8080
- **Search API**: http://localhost:8080/search?q=<query>&format=json
- **Config API**: http://localhost:8080/config

If using LoadBalancer service type, Podman will typically bind it to localhost. If not accessible directly, you can use port forwarding:

```bash
# Port forward the service (if needed)
kubectl port-forward -n searxng svc/searxng 8080:8080
```

### 4. Test the API

Test the search API:

```bash
curl "http://localhost:8080/search?q=test&format=json"
```

Test the config API:

```bash
curl "http://localhost:8080/config"
```

## Undeployment

To remove all resources:

```bash
# Delete the namespace (removes everything)
kubectl delete namespace searxng

# Or if using podman directly
podman kube down searxng-k8s.yaml
```

## Configuration

### Secret Key

The secret key in `settings.yml` is generated using:

```bash
openssl rand -hex 32
```

To regenerate and update:

1. Generate a new key: `openssl rand -hex 32`
2. Update the `secret_key` value in the `searxng-settings` ConfigMap in `searxng-k8s.yaml`
3. Redeploy: `podman play kube searxng-k8s.yaml`

### Settings

Key settings in `searxng-settings` ConfigMap:

- `secret_key`: Session encryption key (change from default!)
- `limiter: false`: Disabled for local development
- `image_proxy: true`: Proxy images through SearXNG
- `redis.url: redis://valkey:6379/0`: Connection to Valkey service

### Persistent Storage

Data is persisted in:
- `valkey-data` PVC: Valkey/Redis data
- `searxng-data` PVC: SearXNG cache

Both use 1Gi storage. Adjust in the PVC definitions if needed.

## Troubleshooting

### Pods Not Starting

Check pod status:

```bash
kubectl get pods -n searxng
kubectl describe pod <pod-name> -n searxng
kubectl logs <pod-name> -n searxng
```

### Service Not Accessible

1. Verify service is running: `kubectl get svc -n searxng`
2. Check service endpoints: `kubectl get endpoints -n searxng`
3. Use port forwarding if LoadBalancer doesn't bind to localhost

### Valkey Connection Issues

SearXNG connects to Valkey using the service name `valkey` on port 6379. Verify:

```bash
kubectl exec -it -n searxng deployment/searxng -- ping valkey
```

## Integration with MCP Server

SearXNG provides a REST API that can be accessed by MCP servers:

- **Search Endpoint**: `GET /search?q=<query>&format=json`
- **Config Endpoint**: `GET /config`

To use SearXNG with an MCP server, you can:

1. Create a custom MCP server that wraps the SearXNG API
2. Use the built-in `http` MCP server to make requests to SearXNG
3. Access it directly via HTTP from your MCP server implementation

See [mcp.json](mcp.json) for configuration notes.

## References

- SearXNG Documentation: https://docs.searxng.org
- Search API: [doc-src/searxng/docs/dev/search_api.rst](doc-src/searxng/docs/dev/search_api.rst)
- Admin API: [doc-src/searxng/docs/admin/api.rst](doc-src/searxng/docs/admin/api.rst)
- Original Docker Compose: [doc-src/searxng-docker/docker-compose.yaml](doc-src/searxng-docker/docker-compose.yaml)


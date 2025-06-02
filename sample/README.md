# Generic Workload Helm Chart

A comprehensive, flexible Helm chart that can deploy various Kubernetes workloads including Deployments, StatefulSets, DaemonSets, Jobs, CronJobs, and Argo Rollouts. This chart follows the DRY principle by using reusable pod templates and supports multiple jobs and cronjobs in a single chart.

## Features

- **Multiple Workload Types**: Supports Deployment, StatefulSet, DaemonSet, Job, CronJob, and Argo Rollout
- **Reusable Pod Templates**: Consistent pod configuration across all workload types
- **Multiple Jobs/CronJobs**: Create multiple jobs and cronjobs with individual configurations
- **Comprehensive Configuration**: Extensive configuration options for all Kubernetes features
- **Production Ready**: Includes HPA, PDB, health checks, and security contexts

## Supported Workloads

| Workload Type | Single Instance | Multiple Instances | Template Used |
|---------------|----------------|-------------------|---------------|
| Deployment    | ✅             | ❌                | `podTemplate` |
| StatefulSet   | ✅             | ❌                | `podTemplate` |
| DaemonSet     | ✅             | ❌                | `podTemplate` |
| Job           | ✅             | ✅                | `jobPodTemplate` |
| CronJob       | ✅             | ✅                | `jobPodTemplate` |
| Argo Rollout  | ✅             | ❌                | `podTemplate` |

## Quick Start

### 1. Basic Deployment

```yaml
# values.yaml
workload:
  type: deployment
  deployment:
    enabled: true
    replicas: 3

image:
  repository: nginx
  tag: "1.21"

service:
  enabled: true
  port: 80
  targetPort: 80
```

### 2. StatefulSet with Persistent Storage

```yaml
# values.yaml
workload:
  type: statefulset
  statefulset:
    enabled: true
    replicas: 3
    serviceName: "my-statefulset"
    volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 10Gi

image:
  repository: postgres
  tag: "13"
```

### 3. Multiple Jobs

```yaml
# values.yaml
jobs:
  migration:
    enabled: true
    backoffLimit: 3
    restartPolicy: Never
    image:
      repository: my-app
      tag: "migrate-v1.0"
    command: ["python", "migrate.py"]
    env:
    - name: DB_HOST
      value: "postgres-service"
  
  data-import:
    enabled: true
    completions: 5
    parallelism: 2
    image:
      repository: my-app
      tag: "import-v1.0"
    command: ["python", "import_data.py"]
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
```

### 4. Multiple CronJobs

```yaml
# values.yaml
cronjobs:
  backup:
    enabled: true
    schedule: "0 2 * * *"
    concurrencyPolicy: Forbid
    image:
      repository: postgres
      tag: "13"
    command: ["pg_dump", "-h", "postgres", "mydb"]
    env:
    - name: PGPASSWORD
      valueFrom:
        secretKeyRef:
          name: postgres-secret
          key: password
  
  cleanup:
    enabled: true
    schedule: "0 0 * * 0"  # Weekly
    image:
      repository: busybox
      tag: "latest"
    command: ["find", "/tmp", "-type", "f", "-mtime", "+7", "-delete"]
```

### 5. Argo Rollout with Canary Strategy

```yaml
# values.yaml
workload:
  type: rollout
  rollout:
    enabled: true
    replicas: 5
    strategy:
      canary:
        steps:
        - setWeight: 20
        - pause: {duration: 30}
        - setWeight: 50
        - pause: {duration: 60}
        - setWeight: 80
        - pause: {duration: 30}

image:
  repository: my-app
  tag: "v2.0"
```

## File Structure

```
generic-workload-chart/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── _helpers.tpl          # Reusable template helpers
│   ├── workload.yaml         # Main workload templates
│   ├── jobs.yaml             # Multiple jobs template
│   ├── cronjobs.yaml         # Multiple cronjobs template
│   ├── serviceaccount.yaml   # Service account
│   ├── service.yaml          # Service
│   ├── ingress.yaml          # Ingress
│   ├── hpa.yaml              # Horizontal Pod Autoscaler
│   ├── pdb.yaml              # Pod Disruption Budget
│   ├── configmap.yaml        # ConfigMap
│   └── secret.yaml           # Secret
└── README.md
```

## Template Helpers

The chart includes two main pod templates:

### `podTemplate`
Used for long-running workloads (Deployment, StatefulSet, DaemonSet, Rollout):
- Includes health checks (liveness, readiness, startup probes)
- Service ports configuration
- Full container lifecycle management

### `jobPodTemplate`
Used for job-based workloads (Job, CronJob):
- Optimized for batch processing
- Includes restart policy configuration
- No service ports or health checks

## Configuration Examples

### Environment Variables

```yaml
env:
- name: ENV_VAR
  value: "production"
- name: SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: my-secret
      key: secret-key

envFrom:
- configMapRef:
    name: my-config
- secretRef:
    name: my-secret
```

### Resource Management

```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

# Auto-scaling
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

### Health Checks

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5

startupProbe:
  httpGet:
    path: /startup
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10
  failureThreshold: 30
```

### Volume Management

```yaml
volumes:
- name: config-volume
  configMap:
    name: my-config
- name: secret-volume
  secret:
    secretName: my-secret

volumeMounts:
- name: config-volume
  mountPath: /etc/config
- name: secret-volume
  mountPath: /etc/secrets
  readOnly: true
```

### Security Configuration

```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
    - ALL
```

## Installation

```bash
# Add the chart repository (if hosted)
helm repo add my-charts https://charts.example.com

# Install with default values
helm install my-release my-charts/generic-workload-chart

# Install with custom values
helm install my-release my-charts/generic-workload-chart -f custom-values.yaml

# Upgrade release
helm upgrade my-release my-charts/generic-workload-chart -f updated-values.yaml
```

## Advanced Use Cases

### Mixed Workload Deployment

You can deploy a main application with supporting jobs and cronjobs:

```yaml
# Main application as deployment
workload:
  type: deployment
  deployment:
    enabled: true
    replicas: 3

# Database migration job
jobs:
  migrate:
    enabled: true
    image:
      repository: my-app
      tag: "migrate"
    command: ["python", "migrate.py"]

# Regular backup cronjob
cronjobs:
  backup:
    enabled: true
    schedule: "0 1 * * *"
    image:
      repository: backup-tool
      tag: "latest"
    command: ["backup.sh"]
```

### Blue-Green Deployment with Argo Rollouts

```yaml
workload:
  type: rollout
  rollout:
    enabled: true
    strategy:
      blueGreen:
        activeService: my-app-active
        previewService: my-app-preview
        autoPromotionEnabled: false
        scaleDownDelaySeconds: 30
        prePromotionAnalysis:
          templates:
          - templateName: success-rate
          args:
          - name: service-name
            value: my-app-preview
```

## Best Practices

1. **Use specific image tags** instead of `latest` for production deployments
2. **Set resource limits and requests** for all containers
3. **Configure health checks** for long-running applications
4. **Use secrets** for sensitive data instead of plain text in values
5. **Enable PodDisruptionBudget** for high-availability applications
6. **Configure appropriate restart policies** for jobs based on their nature
7. **Use nodeSelector, affinity, and tolerations** for proper pod placement

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with different workload types
5. Submit a pull request

## License

This chart is licensed under the Apache 2.0 License.
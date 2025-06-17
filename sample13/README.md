# Sample13 - Refactored Workload Dict Construction

This sample demonstrates the refactoring of workload templates to use a common dict constructor function, eliminating code duplication and providing a centralized place for workload configuration.

## Changes Made

### 1. Added Common Dict Constructor Function

In `templates/_templates.tpl`, added a new template function:

```yaml
{{- define "generic-chart.workloadDictConfig" -}}
```

This function:
- Takes `global` context and `workloadType` as parameters
- Constructs standardized `podConfig` and `containerConfig` dictionaries
- Extracts configuration from workload-specific values (e.g., `.Values.workload.deployment`)
- Returns both dictionaries as a combined YAML object

### 2. Refactored workloads.yaml

Each workload type (deployment, statefulset, daemonset, rollout) now:
- Uses the common dict constructor: `{{- $dictConfig := include "generic-chart.workloadDictConfig" (dict "global" . "workloadType" "deployment") | fromYaml }}`
- Passes the constructed dicts to the pod template: `"podConfig" $dictConfig.podConfig "containerConfig" $dictConfig.containerConfig`

### 3. Benefits

- **DRY Principle**: Eliminates duplicate dict construction code across workload types
- **Centralized Configuration**: Changes to dict structure only need to be made in one place
- **Consistency**: Ensures all workload types use the same configuration pattern
- **Maintainability**: Easier to add new configuration options or modify existing ones

### 4. Comparison with Sample12

**Before (Sample12):**
```yaml
{{- include "generic-chart.podTemplate" (dict "globalName" (include "generic-chart.fullname" .) "globalConfig" . "podConfig" (dict) "containerConfig" (dict "name" (include "generic-chart.fullname" .))) | nindent 4 }}
```

**After (Sample13):**
```yaml
{{- $dictConfig := include "generic-chart.workloadDictConfig" (dict "global" . "workloadType" "deployment") | fromYaml }}
{{- include "generic-chart.podTemplate" (dict "globalName" (include "generic-chart.fullname" .) "globalConfig" . "podConfig" $dictConfig.podConfig "containerConfig" $dictConfig.containerConfig) | nindent 4 }}
```

### 5. Usage

When you need to modify workload configuration:
1. Update the `generic-chart.workloadDictConfig` function in `_templates.tpl`
2. The changes will automatically apply to all workload types (deployment, statefulset, daemonset, rollout)

This approach ensures consistency and reduces maintenance overhead when managing multiple workload types.

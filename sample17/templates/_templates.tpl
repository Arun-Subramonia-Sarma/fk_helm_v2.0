{{/*
Expand the name of the chart.
*/}}
{{- define "generic-chart.name" -}}
{{- default .Chart.Name .Values.global.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "generic-chart.fullname" -}}
{{- if .Values.global.fullnameOverride }}
{{- .Values.global.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.global.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "generic-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Business labels - Applied to all resources
Dynamically iterates over all key-value pairs in businessLabels
*/}}
{{- define "generic-chart.businessLabels" -}}
{{- range $key, $value := .Values.businessLabels }}
{{- if $value }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels - Includes business labels and Helm standard labels
*/}}
{{- define "generic-chart.labels" -}}
helm.sh/chart: {{ include "generic-chart.chart" . }}
{{ include "generic-chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- include "generic-chart.businessLabels" . | nindent 0 }}
{{- end }}

{{/*
Selector labels - Used for pod selectors (minimal and stable labels only)
*/}}
{{- define "generic-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "generic-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "generic-chart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "generic-chart.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Merge labels helper - Merges multiple label dictionaries
*/}}
{{- define "generic-chart.mergeLabels" -}}
{{- $result := dict }}
{{- range . }}
  {{- range $key, $value := . }}
    {{- $_ := set $result $key $value }}
  {{- end }}
{{- end }}
{{- toYaml $result }}
{{- end }}

{{/*
Merge annotations helper - Merges multiple annotation dictionaries
*/}}
{{- define "generic-chart.mergeAnnotations" -}}
{{- $result := dict }}
{{- range . }}
  {{- range $key, $value := . }}
    {{- $_ := set $result $key $value }}
  {{- end }}
{{- end }}
{{- toYaml $result }}
{{- end }}

{{/*
Merge job labels - Combines global workload labels and job-specific labels
Usage: {{ include "generic-chart.jobLabels" (dict "global" . "jobConfig" $jobConfig "jobName" $jobName) }}
*/}}
{{- define "generic-chart.jobLabels" -}}
{{- $global := .global }}
{{- $jobConfig := .jobConfig }}
{{- $jobName := .jobName }}
{{- $jobLabels := list }}

{{/* Add global workload labels */}}
{{- if $global.Values.workloadLabels }}
  {{- $jobLabels = append $jobLabels $global.Values.workloadLabels }}
{{- end }}

{{/* Add job-specific labels */}}
{{- if $jobConfig.labels }}
  {{- $jobLabels = append $jobLabels $jobConfig.labels }}
{{- end }}

{{- if $jobLabels }}
{{- include "generic-chart.mergeLabels" $jobLabels }}
{{- end }}
{{- end }}

{{/*
Merge job annotations - Combines global workload annotations and job-specific annotations
Usage: {{ include "generic-chart.jobAnnotations" (dict "global" . "jobConfig" $jobConfig) }}
*/}}
{{- define "generic-chart.jobAnnotations" -}}
{{- $global := .global }}
{{- $jobConfig := .jobConfig }}
{{- $jobAnnotations := list }}

{{/* Add global workload annotations */}}
{{- if $global.Values.workloadAnnotations }}
  {{- $jobAnnotations = append $jobAnnotations $global.Values.workloadAnnotations }}
{{- end }}

{{/* Add job-specific annotations */}}
{{- if $jobConfig.annotations }}
  {{- $jobAnnotations = append $jobAnnotations $jobConfig.annotations }}
{{- end }}

{{- if $jobAnnotations }}
{{- include "generic-chart.mergeAnnotations" $jobAnnotations }}
{{- end }}
{{- end }}

{{/*
Generate job metadata - Creates standardized metadata for jobs and cronjobs
Usage: {{ include "generic-chart.jobMetadata" (dict "global" . "jobConfig" $jobConfig "jobName" $jobName "jobType" "Job") }}
*/}}
{{- define "generic-chart.jobMetadata" -}}
{{- $global := .global }}
{{- $jobConfig := .jobConfig }}
{{- $jobName := .jobName }}
{{- $jobType := .jobType | default "Job" }}
name: {{ include "generic-chart.fullname" $global }}-{{ $jobName }}
labels:
  {{- include "generic-chart.labels" $global | nindent 2 }}
  jobname: {{ $jobName | quote }}
  {{- if eq $jobType "CronJob" }}
  job-type: "cronjob"
  {{- else }}
  job-type: "job"
  {{- end }}
  {{- $jobLabels := include "generic-chart.jobLabels" (dict "global" $global "jobConfig" $jobConfig "jobName" $jobName) }}
  {{- if $jobLabels }}
  {{- $jobLabels | nindent 2 }}
  {{- end }}
{{- $jobAnnotations := include "generic-chart.jobAnnotations" (dict "global" $global "jobConfig" $jobConfig) }}
{{- if $jobAnnotations }}
annotations:
  {{- $jobAnnotations | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Merge workload labels - Combines global, workload-level, and workload-type-specific labels
Usage: {{ include "generic-chart.workloadLabels" (dict "global" . "workloadType" "deployment") }}
*/}}
{{- define "generic-chart.workloadLabels" -}}
{{- $global := .global }}
{{- $workloadType := .workloadType }}
{{- $workloadLabels := list }}

{{/* Add global workload labels */}}
{{- if $global.Values.workloadLabels }}
  {{- $workloadLabels = append $workloadLabels $global.Values.workloadLabels }}
{{- end }}

{{/* Add generic workload labels */}}
{{- if $global.Values.workload.labels }}
  {{- $workloadLabels = append $workloadLabels $global.Values.workload.labels }}
{{- end }}

{{/* Add workload-type-specific labels */}}
{{- if and $workloadType (index $global.Values.workload $workloadType "labels") }}
  {{- $workloadLabels = append $workloadLabels (index $global.Values.workload $workloadType "labels") }}
{{- end }}

{{- if $workloadLabels }}
{{- include "generic-chart.mergeLabels" $workloadLabels }}
{{- end }}
{{- end }}

{{/*
Merge workload annotations - Combines global, workload-level, and workload-type-specific annotations
Usage: {{ include "generic-chart.workloadAnnotations" (dict "global" . "workloadType" "deployment") }}
*/}}
{{- define "generic-chart.workloadAnnotations" -}}
{{- $global := .global }}
{{- $workloadType := .workloadType }}
{{- $workloadAnnotations := list }}

{{/* Add global workload annotations */}}
{{- if $global.Values.workloadAnnotations }}
  {{- $workloadAnnotations = append $workloadAnnotations $global.Values.workloadAnnotations }}
{{- end }}

{{/* Add generic workload annotations */}}
{{- if $global.Values.workload.annotations }}
  {{- $workloadAnnotations = append $workloadAnnotations $global.Values.workload.annotations }}
{{- end }}

{{/* Add workload-type-specific annotations */}}
{{- if and $workloadType (index $global.Values.workload $workloadType "annotations") }}
  {{- $workloadAnnotations = append $workloadAnnotations (index $global.Values.workload $workloadType "annotations") }}
{{- end }}

{{- if $workloadAnnotations }}
{{- include "generic-chart.mergeAnnotations" $workloadAnnotations }}
{{- end }}
{{- end }}

{{/*
Generate workload metadata - Creates standardized metadata for all workload types
Usage: {{ include "generic-chart.workloadMetadata" (dict "global" . "workloadType" "deployment" "name" (include "generic-chart.fullname" .)) }}
*/}}
{{- define "generic-chart.workloadMetadata" -}}
{{- $global := .global }}
{{- $workloadType := .workloadType }}
{{- $name := .name }}
name: {{ $name }}
labels:
  {{- include "generic-chart.labels" $global | nindent 2 }}
  {{- $workloadLabels := include "generic-chart.workloadLabels" (dict "global" $global "workloadType" $workloadType) }}
  {{- if $workloadLabels }}
  {{- $workloadLabels | nindent 2 }}
  {{- end }}
{{- $workloadAnnotations := include "generic-chart.workloadAnnotations" (dict "global" $global "workloadType" $workloadType) }}
{{- if $workloadAnnotations }}
annotations:
  {{- $workloadAnnotations | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Generate volumes from secrets, configmaps, and external secrets that have mountPath
*/}}
{{- define "generic-chart.autoVolumes" -}}
{{- $globalConfig := .globalConfig }}
{{- $volumes := list }}

{{/* Add volumes from secrets with mountPath */}}
{{- if $globalConfig.Values.secrets }}
{{- range $secretName, $secretConfig := $globalConfig.Values.secrets }}
{{- if and $secretConfig.enabled $secretConfig.mountPath }}
{{- $volume := dict 
    "name" (printf "secret-%s" $secretName)
    "secret" (dict 
      "secretName" (printf "%s-%s" (include "generic-chart.fullname" $globalConfig) $secretName)
      "defaultMode" ($secretConfig.defaultMode | default 420)
    )
}}
{{- if $secretConfig.items }}
{{- $_ := set $volume.secret "items" $secretConfig.items }}
{{- end }}
{{- $volumes = append $volumes $volume }}
{{- end }}
{{- end }}
{{- end }}

{{/* Add volumes from configmaps with mountPath */}}
{{- if $globalConfig.Values.configMaps }}
{{- range $configMapName, $configMapConfig := $globalConfig.Values.configMaps }}
{{- if and $configMapConfig.enabled $configMapConfig.mountPath }}
{{- $volume := dict 
    "name" (printf "configmap-%s" $configMapName)
    "configMap" (dict 
      "name" (printf "%s-%s" (include "generic-chart.fullname" $globalConfig) $configMapName)
      "defaultMode" ($configMapConfig.defaultMode | default 420)
    )
}}
{{- if $configMapConfig.items }}
{{- $_ := set $volume.configMap "items" $configMapConfig.items }}
{{- end }}
{{- $volumes = append $volumes $volume }}
{{- end }}
{{- end }}
{{- end }}

{{/* Add volumes from external secrets with mountPath */}}
{{- if and $globalConfig.Values.externalSecrets $globalConfig.Values.externalSecrets.enabled $globalConfig.Values.externalSecrets.es }}
{{- range $externalSecretName, $externalSecretConfig := $globalConfig.Values.externalSecrets.es }}
{{- if $externalSecretConfig.mountPath }}
{{- $volume := dict 
    "name" (printf "external-secret-%s" $externalSecretName)
    "secret" (dict 
      "secretName" (printf "%s-%s" (include "generic-chart.fullname" $globalConfig) $externalSecretName)
      "defaultMode" ($externalSecretConfig.defaultMode | default 420)
    )
}}
{{- if $externalSecretConfig.items }}
{{- $_ := set $volume.secret "items" $externalSecretConfig.items }}
{{- end }}
{{- $volumes = append $volumes $volume }}
{{- end }}
{{- end }}
{{- end }}

{{- if and $volumes (gt (len $volumes) 0) }}
{{- toYaml $volumes }}
{{- end }}
{{- end }}

{{/*
Generate volume mounts from secrets, configmaps, and external secrets that have mountPath
*/}}
{{- define "generic-chart.autoVolumeMounts" -}}
{{- $globalConfig := .globalConfig }}
{{- $volumeMounts := list }}

{{/* Add volume mounts from secrets with mountPath */}}
{{- if $globalConfig.Values.secrets }}
{{- range $secretName, $secretConfig := $globalConfig.Values.secrets }}
{{- if and $secretConfig.enabled $secretConfig.mountPath }}
{{- $volumeMount := dict 
    "name" (printf "secret-%s" $secretName)
    "mountPath" $secretConfig.mountPath
    "readOnly" ($secretConfig.readOnly | default true)
}}
{{- if $secretConfig.subPath }}
{{- $_ := set $volumeMount "subPath" $secretConfig.subPath }}
{{- end }}
{{- $volumeMounts = append $volumeMounts $volumeMount }}
{{- end }}
{{- end }}
{{- end }}

{{/* Add volume mounts from configmaps with mountPath */}}
{{- if $globalConfig.Values.configMaps }}
{{- range $configMapName, $configMapConfig := $globalConfig.Values.configMaps }}
{{- if and $configMapConfig.enabled $configMapConfig.mountPath }}
{{- $volumeMount := dict 
    "name" (printf "configmap-%s" $configMapName)
    "mountPath" $configMapConfig.mountPath
    "readOnly" ($configMapConfig.readOnly | default true)
}}
{{- if $configMapConfig.subPath }}
{{- $_ := set $volumeMount "subPath" $configMapConfig.subPath }}
{{- end }}
{{- $volumeMounts = append $volumeMounts $volumeMount }}
{{- end }}
{{- end }}
{{- end }}

{{/* Add volume mounts from external secrets with mountPath */}}
{{- if and $globalConfig.Values.externalSecrets $globalConfig.Values.externalSecrets.enabled $globalConfig.Values.externalSecrets.es }}
{{- range $externalSecretName, $externalSecretConfig := $globalConfig.Values.externalSecrets.es }}
{{- if $externalSecretConfig.mountPath }}
{{- $volumeMount := dict 
    "name" (printf "external-secret-%s" $externalSecretName)
    "mountPath" $externalSecretConfig.mountPath
    "readOnly" ($externalSecretConfig.readOnly | default true)
}}
{{- if $externalSecretConfig.subPath }}
{{- $_ := set $volumeMount "subPath" $externalSecretConfig.subPath }}
{{- end }}
{{- $volumeMounts = append $volumeMounts $volumeMount }}
{{- end }}
{{- end }}
{{- end }}

{{- if and $volumeMounts (gt (len $volumeMounts) 0) }}
{{- toYaml $volumeMounts }}
{{- end }}
{{- end }}

{{/*
Generate envFrom for secrets and configmaps that do NOT have mountPath
*/}}
{{- define "generic-chart.autoEnvFrom" -}}
{{- $globalConfig := .globalConfig }}
{{- $envFrom := list }}

{{/* Add envFrom for secrets without mountPath */}}
{{- if $globalConfig.Values.secrets }}
{{- range $secretName, $secretConfig := $globalConfig.Values.secrets }}
{{- if and $secretConfig.enabled (not $secretConfig.mountPath) }}
{{- $envFrom = append $envFrom (dict 
    "secretRef" (dict 
      "name" (printf "%s-%s" (include "generic-chart.fullname" $globalConfig) $secretName)
    )
) }}
{{- end }}
{{- end }}
{{- end }}

{{/* Add envFrom for configmaps without mountPath */}}
{{- if $globalConfig.Values.configMaps }}
{{- range $configMapName, $configMapConfig := $globalConfig.Values.configMaps }}
{{- if and $configMapConfig.enabled (not $configMapConfig.mountPath) }}
{{- $envFrom = append $envFrom (dict 
    "configMapRef" (dict 
      "name" (printf "%s-%s" (include "generic-chart.fullname" $globalConfig) $configMapName)
    )
) }}
{{- end }}
{{- end }}
{{- end }}

{{/* Add envFrom for external secrets without mountPath */}}
{{- if and $globalConfig.Values.externalSecrets $globalConfig.Values.externalSecrets.enabled $globalConfig.Values.externalSecrets.es }}
{{- range $externalSecretName, $externalSecretConfig := $globalConfig.Values.externalSecrets.es }}
{{- if not $externalSecretConfig.mountPath }}
{{- $envFrom = append $envFrom (dict 
    "secretRef" (dict 
      "name" (printf "%s-%s" (include "generic-chart.fullname" $globalConfig) $externalSecretName)
    )
) }}
{{- end }}
{{- end }}
{{- end }}

{{- if and $envFrom (gt (len $envFrom) 0) }}
{{- toYaml $envFrom }}
{{- end }}
{{- end }}

{{/*
Merge environment variables from multiple sources
Usage: {{ include "generic-chart.mergedEnvVars" (dict "globalConfig" . "containerConfig" $containerConfig) }}
*/}}
{{- define "generic-chart.mergedEnvVars" -}}
{{- $globalConfig := .globalConfig }}
{{- $containerConfig := .containerConfig }}
{{- $envVars := list }}

{{/* Add global environment variables */}}
{{- if $globalConfig.Values.env }}
  {{- $envVars = concat $envVars $globalConfig.Values.env }}
{{- end }}

{{/* Add container-specific environment variables */}}
{{- if $containerConfig.env }}
  {{- $envVars = concat $envVars $containerConfig.env }}
{{- end }}

{{/* Convert key=value format to Kubernetes env format */}}
{{- $keyValueEnvVars := list }}

{{/* Add global envVars */}}
{{- if $globalConfig.Values.envVars }}
{{- range $key, $value := $globalConfig.Values.envVars }}
{{- $keyValueEnvVars = append $keyValueEnvVars (dict "name" $key "value" ($value | toString)) }}
{{- end }}
{{- end }}

{{/* Add container-specific envVars */}}
{{- if $containerConfig.envVars }}
{{- range $key, $value := $containerConfig.envVars }}
{{- $keyValueEnvVars = append $keyValueEnvVars (dict "name" $key "value" ($value | toString)) }}
{{- end }}
{{- end }}

{{/* Add valueFrom environment variables */}}
{{- $valueFromEnvVars := list }}

{{/* Add global envValueFrom */}}
{{- if $globalConfig.Values.envValueFrom }}
{{- range $key, $valueFrom := $globalConfig.Values.envValueFrom }}
{{- $valueFromEnvVars = append $valueFromEnvVars (dict "name" $key "valueFrom" $valueFrom) }}
{{- end }}
{{- end }}

{{/* Add container-specific envValueFrom */}}
{{- if $containerConfig.envValueFrom }}
{{- range $key, $valueFrom := $containerConfig.envValueFrom }}
{{- $valueFromEnvVars = append $valueFromEnvVars (dict "name" $key "valueFrom" $valueFrom) }}
{{- end }}
{{- end }}

{{/* Combine all environment variables */}}
{{- $allEnvVars := concat $envVars $keyValueEnvVars $valueFromEnvVars }}

{{- if and $allEnvVars (gt (len $allEnvVars) 0) }}
{{- toYaml $allEnvVars }}
{{- end }}
{{- end }}

{{/*
Common workload dict constructor - Creates standardized dict objects for workload pod templates
Usage: {{ include "generic-chart.workloadDictConfig" (dict "global" . "workloadType" "deployment") }}
*/}}
{{- define "generic-chart.workloadDictConfig" -}}
{{- $global := .global }}
{{- $workloadType := .workloadType }}
{{- $workloadConfig := index $global.Values.workload $workloadType }}

{{/* Construct podConfig dict */}}
{{- $podConfig := dict }}
{{- if $workloadConfig.podAnnotations }}
  {{- $_ := set $podConfig "annotations" $workloadConfig.podAnnotations }}
{{- end }}
{{- if $workloadConfig.podLabels }}
  {{- $_ := set $podConfig "labels" $workloadConfig.podLabels }}
{{- end }}
{{- if $workloadConfig.nodeSelector }}
  {{- $_ := set $podConfig "nodeSelector" $workloadConfig.nodeSelector }}
{{- end }}
{{- if $workloadConfig.affinity }}
  {{- $_ := set $podConfig "affinity" $workloadConfig.affinity }}
{{- end }}
{{- if $workloadConfig.tolerations }}
  {{- $_ := set $podConfig "tolerations" $workloadConfig.tolerations }}
{{- end }}
{{- if $workloadConfig.imagePullSecrets }}
  {{- $_ := set $podConfig "imagePullSecrets" $workloadConfig.imagePullSecrets }}
{{- end }}
{{- if $workloadConfig.podSecurityContext }}
  {{- $_ := set $podConfig "podSecurityContext" $workloadConfig.podSecurityContext }}
{{- end }}

{{/* Construct containerConfig dict */}}
{{- $containerConfig := dict }}
{{- $_ := set $containerConfig "name" (include "generic-chart.fullname" $global) }}
{{- if $workloadConfig.image }}
  {{- if $workloadConfig.image.repository }}
    {{- $_ := set $containerConfig "repository" $workloadConfig.image.repository }}
  {{- end }}
  {{- if $workloadConfig.image.tag }}
    {{- $_ := set $containerConfig "tag" $workloadConfig.image.tag }}
  {{- end }}
  {{- if $workloadConfig.image.pullPolicy }}
    {{- $_ := set $containerConfig "pullPolicy" $workloadConfig.image.pullPolicy }}
  {{- end }}
{{- end }}
{{- if $workloadConfig.command }}
  {{- $_ := set $containerConfig "command" $workloadConfig.command }}
{{- end }}
{{- if $workloadConfig.args }}
  {{- $_ := set $containerConfig "args" $workloadConfig.args }}
{{- end }}
{{- if $workloadConfig.env }}
  {{- $_ := set $containerConfig "env" $workloadConfig.env }}
{{- end }}
{{- if $workloadConfig.envVars }}
  {{- $_ := set $containerConfig "envVars" $workloadConfig.envVars }}
{{- end }}
{{- if $workloadConfig.envValueFrom }}
  {{- $_ := set $containerConfig "envValueFrom" $workloadConfig.envValueFrom }}
{{- end }}
{{- if $workloadConfig.envFrom }}
  {{- $_ := set $containerConfig "envFrom" $workloadConfig.envFrom }}
{{- end }}
{{- if $workloadConfig.resources }}
  {{- $_ := set $containerConfig "resources" $workloadConfig.resources }}
{{- end }}
{{- if $workloadConfig.volumeMounts }}
  {{- $_ := set $containerConfig "volumeMounts" $workloadConfig.volumeMounts }}
{{- end }}
{{- if $workloadConfig.volumes }}
  {{- $_ := set $containerConfig "volumes" $workloadConfig.volumes }}
{{- end }}
{{- if $workloadConfig.sidecarContainers }}
  {{- $_ := set $containerConfig "sidecarContainers" $workloadConfig.sidecarContainers }}
{{- end }}
{{- if $workloadConfig.securityContext }}
  {{- $_ := set $containerConfig "securityContext" $workloadConfig.securityContext }}
{{- end }}
{{- if $workloadConfig.initContainers }}
  {{- $_ := set $containerConfig "initContainers" $workloadConfig.initContainers }}
{{- end }}
{{- if $workloadConfig.podAnnotations }}
  {{- $_ := set $containerConfig "podAnnotations" $workloadConfig.podAnnotations }}
{{- end }}
{{- if $workloadConfig.podLabels }}
  {{- $_ := set $containerConfig "podLabels" $workloadConfig.podLabels }}
{{- end }}

{{/* Return the constructed dicts as a combined object */}}
{{- dict "global" $global "workloadType" $workloadType "podConfig" $podConfig "containerConfig" $containerConfig | toYaml }}
{{- end }}

{{/*
Universal Pod Template - Used by all workload types
*/}}
{{- define "generic-chart.podTemplate" -}}
{{- $workloadConfig := .workloadConfig | default dict }}
{{- $globalConfig := .globalConfig | default . }}
{{- $podConfig := .podConfig | default dict }}
{{- $containerConfig := .containerConfig | default dict }}
{{- $jobName := .jobName | default "" }}
{{- $globalName := .globalName | default "" }}
metadata:
  {{- $podAnnotations := list }}
  {{- if $globalConfig.Values.podAnnotations }}
    {{- $podAnnotations = append $podAnnotations $globalConfig.Values.podAnnotations }}
  {{- end }}
  {{- if $podConfig.annotations }}
    {{- $podAnnotations = append $podAnnotations $podConfig.annotations }}
  {{- end }}
  {{- if $containerConfig.podAnnotations }}
    {{- $podAnnotations = append $podAnnotations $containerConfig.podAnnotations }}
  {{- end }}
  {{- if $podAnnotations }}
  annotations:
    {{- include "generic-chart.mergeAnnotations" $podAnnotations | nindent 4 }}
  {{- end }}
  labels:
    {{- include "generic-chart.selectorLabels" $globalConfig | nindent 4 }}
    {{- $podLabels := list }}
    {{- if $globalConfig.Values.podLabels }}
      {{- $podLabels = append $podLabels $globalConfig.Values.podLabels }}
    {{- end }}
    {{- if $podConfig.labels }}
      {{- $podLabels = append $podLabels $podConfig.labels }}
    {{- end }}
    {{- if $containerConfig.podLabels }}
      {{- $podLabels = append $podLabels $containerConfig.podLabels }}
    {{- end }}
    {{- if $podConfig.additionalLabels }}
      {{- $podLabels = append $podLabels $podConfig.additionalLabels }}
    {{- end }}
    {{- if $jobName }}
    jobname: {{ $jobName | quote }}
    {{- end }}
    {{- if $podLabels }}
    {{- include "generic-chart.mergeLabels" $podLabels | nindent 4 }}
    {{- end }}
spec:
  {{- with (coalesce $containerConfig.imagePullSecrets $globalConfig.Values.imagePullSecrets) }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  serviceAccountName: {{ include "generic-chart.serviceAccountName" $globalConfig }}
  securityContext:
    {{- toYaml (coalesce $containerConfig.podSecurityContext $globalConfig.Values.podSecurityContext) | nindent 4 }}
  {{- with $podConfig.restartPolicy }}
  restartPolicy: {{ . }}
  {{- end }}
  {{- $initContainers := list }}
  {{- if $globalConfig.Values.initContainers }}
    {{- $initContainers = concat $initContainers $globalConfig.Values.initContainers }}
  {{- end }}
  {{- if $containerConfig.initContainers }}
    {{- $initContainers = concat $initContainers $containerConfig.initContainers }}
  {{- end }}
  {{- if $initContainers }}
  initContainers:
    {{- range $initContainers }}
    - {{- toYaml . | nindent 6 }}
    {{- end }}
  {{- end }}
  containers:
    - name: {{ $containerConfig.name | default $globalConfig.Chart.Name }}
      securityContext:
        {{- toYaml (coalesce $containerConfig.securityContext $globalConfig.Values.securityContext) | nindent 8 }}
      image: "{{ coalesce $containerConfig.repository $globalConfig.Values.image.repository }}:{{ coalesce $containerConfig.tag $globalConfig.Values.image.tag $globalConfig.Chart.AppVersion }}"
      imagePullPolicy: {{ coalesce $containerConfig.pullPolicy $globalConfig.Values.image.pullPolicy }}
      {{- with $containerConfig.command }}
      command:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $containerConfig.args }}
      args:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- $mergedEnvVarsStr := include "generic-chart.mergedEnvVars" (dict "globalConfig" $globalConfig "containerConfig" $containerConfig) }}
      {{- if and $mergedEnvVarsStr (ne $mergedEnvVarsStr "") }}
        {{- $mergedEnvVarsParsed := $mergedEnvVarsStr | fromYaml }}
        {{- if and $mergedEnvVarsParsed (kindIs "slice" $mergedEnvVarsParsed) }}
      env:
        {{- toYaml $mergedEnvVarsParsed | nindent 8 }}
        {{- end }}
      {{- end }}
      {{- $envFromVars := list }}
      {{- if $globalConfig.Values.envFrom }}
        {{- $envFromVars = concat $envFromVars $globalConfig.Values.envFrom }}
      {{- end }}
      {{- if $containerConfig.envFrom }}
        {{- $envFromVars = concat $envFromVars $containerConfig.envFrom }}
      {{- end }}
      {{/* Add auto-generated envFrom for secrets/configmaps without mountPath */}}
      {{- $autoEnvFromStr := include "generic-chart.autoEnvFrom" (dict "globalConfig" $globalConfig) }}
      {{- if and $autoEnvFromStr (ne $autoEnvFromStr "") }}
        {{- $autoEnvFromParsed := $autoEnvFromStr | fromYaml }}
        {{- if and $autoEnvFromParsed (kindIs "slice" $autoEnvFromParsed) }}
          {{- $envFromVars = concat $envFromVars $autoEnvFromParsed }}
        {{- end }}
      {{- end }}
      {{- if $envFromVars }}
      envFrom:
        {{- toYaml $envFromVars | nindent 8 }}
      {{- end }}
      {{- if and (or $globalConfig.Values.services (and $globalConfig.Values.service $globalConfig.Values.service.enabled)) (not $podConfig.restartPolicy) }}
      ports:
        - name: {{ $globalName | default "http" }}-cp
          containerPort: {{ $globalConfig.Values.service.targetPort | default 8080 }}
          protocol: TCP
      {{- end }}
      {{- if and (not $podConfig.restartPolicy) $globalConfig.Values.livenessProbe }}
      livenessProbe:
        {{- toYaml $globalConfig.Values.livenessProbe | nindent 8 }}
      {{- end }}
      {{- if and (not $podConfig.restartPolicy) $globalConfig.Values.readinessProbe }}
      readinessProbe:
        {{- toYaml $globalConfig.Values.readinessProbe | nindent 8 }}
      {{- end }}
      {{- if and (not $podConfig.restartPolicy) $globalConfig.Values.startupProbe }}
      startupProbe:
        {{- toYaml $globalConfig.Values.startupProbe | nindent 8 }}
      {{- end }}
      resources:
        {{- toYaml (coalesce $containerConfig.resources $globalConfig.Values.resources) | nindent 8 }}
      {{- $volumeMounts := list }}
      {{- if $globalConfig.Values.volumeMounts }}
        {{- $volumeMounts = concat $volumeMounts $globalConfig.Values.volumeMounts }}
      {{- end }}
      {{- if $containerConfig.volumeMounts }}
        {{- $volumeMounts = concat $volumeMounts $containerConfig.volumeMounts }}
      {{- end }}
      {{/* Add auto-generated volume mounts from secrets/configmaps with mountPath */}}
      {{- $autoVolumeMountsStr := include "generic-chart.autoVolumeMounts" (dict "globalConfig" $globalConfig) }}
      {{- if and $autoVolumeMountsStr (ne $autoVolumeMountsStr "") }}
        {{- $autoVolumeMountsParsed := $autoVolumeMountsStr | fromYaml }}
        {{- if and $autoVolumeMountsParsed (kindIs "slice" $autoVolumeMountsParsed) }}
          {{- $volumeMounts = concat $volumeMounts $autoVolumeMountsParsed }}
        {{- end }}
      {{- end }}
      {{- if $volumeMounts }}
      volumeMounts:
        {{- toYaml $volumeMounts | nindent 8 }}
      {{- end }}
    {{- $sidecarContainers := list }}
    {{- if $globalConfig.Values.sidecarContainers }}
      {{- $sidecarContainers = concat $sidecarContainers $globalConfig.Values.sidecarContainers }}
    {{- end }}
    {{- if $containerConfig.sidecarContainers }}
      {{- $sidecarContainers = concat $sidecarContainers $containerConfig.sidecarContainers }}
    {{- end }}
    {{- if $sidecarContainers }}
    {{- range $sidecarContainers }}
    - {{- toYaml . | nindent 6 }}
    {{- end }}
    {{- end }}
  {{- $volumes := list }}
  {{- if $globalConfig.Values.volumes }}
    {{- $volumes = concat $volumes $globalConfig.Values.volumes }}
  {{- end }}
  {{- if $containerConfig.volumes }}
    {{- $volumes = concat $volumes $containerConfig.volumes }}
  {{- end }}
  {{/* Add auto-generated volumes from secrets/configmaps with mountPath */}}
  {{- $autoVolumesStr := include "generic-chart.autoVolumes" (dict "globalConfig" $globalConfig) }}
  {{- if and $autoVolumesStr (ne $autoVolumesStr "") }}
    {{- $autoVolumesParsed := $autoVolumesStr | fromYaml }}
    {{- if and $autoVolumesParsed (kindIs "slice" $autoVolumesParsed) }}
      {{- $volumes = concat $volumes $autoVolumesParsed }}
    {{- end }}
  {{- end }}
  {{- if $volumes }}
  volumes:
    {{- toYaml $volumes | nindent 4 }}
  {{- end }}
  {{- with (coalesce $containerConfig.nodeSelector $globalConfig.Values.nodeSelector) }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with (coalesce $containerConfig.affinity $globalConfig.Values.affinity) }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with (coalesce $containerConfig.tolerations $globalConfig.Values.tolerations) }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}

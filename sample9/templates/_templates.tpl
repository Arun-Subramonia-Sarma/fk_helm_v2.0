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
FIXED: Only includes business labels once through selectorLabels
*/}}
{{- define "generic-chart.labels" -}}
helm.sh/chart: {{ include "generic-chart.chart" . }}
{{ include "generic-chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels - Used for pod selectors (includes business labels for consistency)
*/}}
{{- define "generic-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "generic-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- include "generic-chart.businessLabels" . | nindent 0 }}
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
Merge environment variables from different sources
*/}}
{{- define "generic-chart.mergedEnvVars" -}}
{{- $globalConfig := .globalConfig }}
{{- $containerConfig := .containerConfig }}
{{- $envList := list }}

{{/* Add global envVars (key=value format) */}}
{{- if $globalConfig.Values.envVars }}
{{- range $key, $value := $globalConfig.Values.envVars }}
{{- $envList = append $envList (dict "name" $key "value" ($value | toString)) }}
{{- end }}
{{- end }}

{{/* Add container-specific envVars (key=value format) */}}
{{- if $containerConfig.envVars }}
{{- range $key, $value := $containerConfig.envVars }}
{{- $envList = append $envList (dict "name" $key "value" ($value | toString)) }}
{{- end }}
{{- end }}

{{/* Add global envValueFrom */}}
{{- if $globalConfig.Values.envValueFrom }}
{{- range $key, $valueFrom := $globalConfig.Values.envValueFrom }}
{{- $envList = append $envList (dict "name" $key "valueFrom" $valueFrom) }}
{{- end }}
{{- end }}

{{/* Add container-specific envValueFrom */}}
{{- if $containerConfig.envValueFrom }}
{{- range $key, $valueFrom := $containerConfig.envValueFrom }}
{{- $envList = append $envList (dict "name" $key "valueFrom" $valueFrom) }}
{{- end }}
{{- end }}

{{/* Add traditional env arrays */}}
{{- if $globalConfig.Values.env }}
{{- $envList = concat $envList $globalConfig.Values.env }}
{{- end }}

{{- if $containerConfig.env }}
{{- $envList = concat $envList $containerConfig.env }}
{{- end }}

{{- toYaml $envList }}
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
      {{- $mergedEnvVars := include "generic-chart.mergedEnvVars" (dict "globalConfig" $globalConfig "containerConfig" $containerConfig) }}
      {{- if $mergedEnvVars }}
      env:
        {{- $mergedEnvVars | nindent 8 }}
      {{- end }}
      {{- $envFromVars := list }}
      {{- if $globalConfig.Values.envFrom }}
        {{- $envFromVars = concat $envFromVars $globalConfig.Values.envFrom }}
      {{- end }}
      {{- if $containerConfig.envFrom }}
        {{- $envFromVars = concat $envFromVars $containerConfig.envFrom }}
      {{- end }}
      {{- if $envFromVars }}
      envFrom:
        {{- toYaml $envFromVars | nindent 8 }}
      {{- end }}
      {{- if and (or $globalConfig.Values.services (and $globalConfig.Values.service $globalConfig.Values.service.enabled)) (not $podConfig.restartPolicy) }}
      ports:
        - name: http
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
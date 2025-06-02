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
Common labels
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
Selector labels
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
Universal Pod Template - Used by all workload types
Accepts context with workload configuration and optional overrides
*/}}
{{- define "generic-chart.podTemplate" -}}
{{- $workloadConfig := .workloadConfig | default dict }}
{{- $globalConfig := .globalConfig | default . }}
{{- $podConfig := .podConfig | default dict }}
{{- $containerConfig := .containerConfig | default dict }}
metadata:
  {{- with (coalesce $podConfig.annotations $globalConfig.Values.podAnnotations) }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  labels:
    {{- include "generic-chart.selectorLabels" $globalConfig | nindent 4 }}
    {{- with (coalesce $podConfig.labels $globalConfig.Values.podLabels) }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $podConfig.additionalLabels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  {{- with (coalesce $podConfig.imagePullSecrets $globalConfig.Values.imagePullSecrets) }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  serviceAccountName: {{ include "generic-chart.serviceAccountName" $globalConfig }}
  securityContext:
    {{- toYaml (coalesce $podConfig.securityContext $globalConfig.Values.podSecurityContext) | nindent 4 }}
  {{- with $podConfig.restartPolicy }}
  restartPolicy: {{ . }}
  {{- end }}
  {{- with (coalesce $podConfig.initContainers $globalConfig.Values.initContainers) }}
  initContainers:
    {{- range . }}
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
      {{- $envVars := list }}
      {{- if $globalConfig.Values.env }}
        {{- $envVars = concat $envVars $globalConfig.Values.env }}
      {{- end }}
      {{- if $containerConfig.env }}
        {{- $envVars = concat $envVars $containerConfig.env }}
      {{- end }}
      {{- if $envVars }}
      env:
        {{- toYaml $envVars | nindent 8 }}
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
      {{- if and $globalConfig.Values.service.enabled (not $podConfig.restartPolicy) }}
      ports:
        - name: http
          containerPort: {{ $globalConfig.Values.service.targetPort }}
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
  {{- with (coalesce $podConfig.nodeSelector $globalConfig.Values.nodeSelector) }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with (coalesce $podConfig.affinity $globalConfig.Values.affinity) }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with (coalesce $podConfig.tolerations $globalConfig.Values.tolerations) }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
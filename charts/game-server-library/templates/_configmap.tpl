{{/*
Standard ConfigMap template for game configuration files
Usage: {{ include "game-server.configmap" . }}
*/}}
{{- define "game-server.configmap" -}}
{{- $hasEnabledConfigs := false }}
{{- range $key, $configGroup := .Values.gameConfig }}
  {{- if and (typeIs "map[string]interface {}" $configGroup) $configGroup.enabled }}
    {{- $hasEnabledConfigs = true }}
  {{- end }}
{{- end }}
{{- if $hasEnabledConfigs }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Values.name }}-config
  labels:
    {{- include "game-server.labels" . | nindent 4 }}
data:
  {{- range $key, $configGroup := .Values.gameConfig }}
  {{- if and (typeIs "map[string]interface {}" $configGroup) $configGroup.enabled }}
  {{- if $configGroup.file }}
  {{- /* Full file override provided */}}
  {{ $key }}: |
{{ $configGroup.file | indent 4 }}
  {{- else if $configGroup.config }}
  {{- /* Build file from config using specified format */}}
  {{- if eq $configGroup.configFormat "json" }}
  {{ $key }}.json: |
{{ $configGroup.config | toJson | indent 4 }}
  {{- else if eq $configGroup.configFormat "yaml" }}
  {{ $key }}.yaml: |
{{ $configGroup.config | toYaml | indent 4 }}
  {{- end }}
  {{- end }}
  {{- end }}
  {{- end }}
{{- end }}
{{- end -}}

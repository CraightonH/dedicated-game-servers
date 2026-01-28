{{/*
Standard ConfigMap template for game configuration files
Usage: {{ include "game-server.configmap" . }}
*/}}
{{- define "game-server.configmap" -}}
{{- if .Values.gameConfig.enabled }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Values.name }}-config
  labels:
    {{- include "game-server.labels" . | nindent 4 }}
data:
  {{- range $filename, $content := .Values.gameConfig.files }}
  {{ $filename }}: |
{{ $content | indent 4 }}
  {{- end }}
{{- end }}
{{- end -}}

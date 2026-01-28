{{/*
Standard Service template for game servers
Usage: {{ include "game-server.service" . }}
*/}}
{{- define "game-server.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.name }}
  labels:
    {{- include "game-server.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  selector:
    {{- include "game-server.selectorLabels" . | nindent 4 }}
  ports:
  {{- range .Values.service.ports }}
  - name: {{ .name }}
    port: {{ .port }}
    targetPort: {{ .port }}
    {{- if .nodePort }}
    nodePort: {{ .nodePort }}
    {{- end }}
    protocol: {{ .protocol | default "TCP" }}
  {{- end }}
{{- end -}}

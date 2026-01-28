{{/*
Standard Deployment template for game servers
Usage: {{ include "game-server.deployment" . }}
*/}}
{{- define "game-server.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.name }}
  labels:
    {{- include "game-server.labels" . | nindent 4 }}
spec:
  replicas: 1
  strategy:
    type: Recreate  # Game servers can't have multiple replicas
  selector:
    matchLabels:
      {{- include "game-server.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "game-server.selectorLabels" . | nindent 8 }}
      {{- if .Values.gameConfig.enabled }}
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap-game-config.yaml") . | sha256sum }}
      {{- end }}
    spec:
      {{- if .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml .Values.nodeSelector | nindent 8 }}
      {{- end }}
      {{- if .Values.tolerations }}
      tolerations:
        {{- toYaml .Values.tolerations | nindent 8 }}
      {{- end }}
      {{- if .Values.podSecurityContext }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      {{- end }}
      {{- if .Values.initContainers }}
      initContainers:
        {{- toYaml .Values.initContainers | nindent 8 }}
      {{- end }}
      containers:
      - name: game-server
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        {{- if .Values.containerSecurityContext }}
        securityContext:
          {{- toYaml .Values.containerSecurityContext | nindent 10 }}
        {{- end }}
        {{- if .Values.env }}
        env:
          {{- toYaml .Values.env | nindent 10 }}
        {{- end }}
        ports:
        {{- range .Values.service.ports }}
        - name: {{ .name }}
          containerPort: {{ .port }}
          protocol: {{ .protocol | default "TCP" }}
        {{- end }}
        volumeMounts:
        {{- if .Values.persistence.enabled }}
        - name: data
          mountPath: {{ .Values.persistence.mountPath }}
        {{- end }}
        {{- if .Values.gameConfig.enabled }}
        {{- range $filename, $content := .Values.gameConfig.files }}
        - name: game-config
          mountPath: {{ $.Values.gameConfig.mountPath }}/{{ $filename }}
          subPath: {{ $filename }}
        {{- end }}
        {{- end }}
        {{- if .Values.resources }}
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
        {{- end }}
      volumes:
      {{- if .Values.persistence.enabled }}
      - name: data
        persistentVolumeClaim:
          claimName: {{ .Values.name }}-data
      {{- end }}
      {{- if .Values.gameConfig.enabled }}
      - name: game-config
        configMap:
          name: {{ .Values.name }}-config
      {{- end }}
{{- end -}}

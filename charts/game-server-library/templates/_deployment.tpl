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
      {{- if .Values.gameConfig }}
      annotations:
        checksum/config: {{ include "game-server.configmap" . | sha256sum }}
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
        {{- range $key, $configGroup := .Values.gameConfig }}
        {{- if and (typeIs "map[string]interface {}" $configGroup) $configGroup.enabled }}
        {{- $filename := $key }}
        {{- if $configGroup.file }}
          {{- /* file override: use key as-is */}}
        {{- else if eq $configGroup.configFormat "json" }}
          {{- $filename = printf "%s.json" $key }}
        {{- else if eq $configGroup.configFormat "yaml" }}
          {{- $filename = printf "%s.yaml" $key }}
        {{- end }}
        - name: game-config
          mountPath: {{ $configGroup.mountPath }}/{{ $filename }}
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
      {{- $hasEnabledConfigs := false }}
      {{- range $key, $configGroup := $.Values.gameConfig }}
        {{- if and (typeIs "map[string]interface {}" $configGroup) $configGroup.enabled }}
          {{- $hasEnabledConfigs = true }}
        {{- end }}
      {{- end }}
      {{- if $hasEnabledConfigs }}
      - name: game-config
        configMap:
          name: {{ .Values.name }}-config
      {{- end }}
{{- end -}}

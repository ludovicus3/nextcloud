{{- define "nextcloud.postgresql.serviceName" -}}
{{- include "postgresql.v1.primary.fullname" .Subcharts.postgresql -}}
{{- end -}}

{{- define "nextcloud.postgresql.env" -}}
{{- if .Values.postgresql.enabled }}
{{- with .Subcharts.postgresql }}
- name: POSTGRES_HOST
  value: {{ template "postgresql.v1.primary.fullname" . }}
- name: POSTGRES_DB
  value: {{ include "postgresql.v1.database" . }}
- name: POSTGRES_USER
  value: {{ include "postgresql.v1.username" . }}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "postgresql.v1.secretName" . }}
      key: {{ include "postgresql.v1.userPasswordKey" . }}
{{- end }}
{{- end }}
{{- end -}}
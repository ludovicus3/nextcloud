{{- define "nextcloud.smtp.host" -}}
{{- required "A valid host needed for smtp" .Values.smtp.host -}}
{{- end -}}

{{- define "nextcloud.smtp.domain" -}}
{{- $default := splitList "." (include "nextcloud.smtp.host" .) | rest | join "." -}}
{{- default $default .Values.smtp.domain -}}
{{- end -}}

{{- define "nextcloud.smtp.env" -}}
{{- if .Values.smtp.enabled }}
- name: MAIL_FROM_ADDRESS
  value: {{ default "nextcloud" .Values.smtp.mailFromAddress }}
- name: MAIL_DOMAIN
  value: {{ include "nextcloud.smtp.domain" . }}
- name: SMTP_HOST
  value: {{ .Values.smtp.host }}
- name: SMTP_PORT
  value: {{ .Values.smtp.port | quote }}
- name: SMTP_SECURE
  value: {{ .Values.smtp.secure }}
- name: SMTP_AUTHTYPE
  value: {{ .Values.smtp.authtype }}
{{- if .Values.smtp.auth.secretName }}
- name: SMTP_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ .Values.smtp.auth.secretName }}
      key: {{ default "username" .Values.smtp.auth.usernameKey }}
- name: SMTP_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.smtp.auth.secretName }}
      key: {{ default "password" .Values.smtp.auth.passwordKey }}
{{- end }}
{{- end }}
{{- end -}}
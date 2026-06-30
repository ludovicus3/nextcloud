{{- define "nextcloud.tls.mountPath" -}}
{{- default "/etc/ssl/nginx" .Values.proxy.tls.mountPath -}}
{{- end -}}

{{- define "nextcloud.tls.certificatePath" -}}
{{- printf "%s/tls.crt" (include "nextcloud.tls.mountPath" .) -}}
{{- end -}}

{{- define "nextcloud.tls.certificateKeyPath" -}}
{{- printf "%s/tls.key" (include "nextcloud.tls.mountPath" .) -}}
{{- end -}}

{{- define "nextcloud.tls.secretName" -}}
{{- if and .Values.proxy.tls.create (.Capabilities.APIVersions.Has "cert-manager.io/v1") -}}
{{-   printf "%s-tls" (include "nextcloud.fullname" .) -}}
{{- else -}}
{{-   .Values.proxy.tls.existingSecret -}}
{{- end -}}
{{- end -}}
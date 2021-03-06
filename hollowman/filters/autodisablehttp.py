class AutoDisableHTTPFilter:

    name = "autodisablehttp"

    def write(self, user, request_app, original_app):
        if self.is_http_app(request_app) and request_app.instances is not None:
            if request_app.instances == 0:
                self._set_traefik_label_to(request_app, "false")
            if request_app.instances > 0:
                self._set_traefik_label_to(request_app, "true")

        return request_app

    def is_http_app(self, app):
        return "traefik.enable" in app.labels

    def _set_traefik_label_to(self, app, value):
        app.labels["traefik.enable"] = value

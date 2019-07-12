from abc import ABC, abstractmethod
from typing import Dict, List, Any

from asgard.conf import settings
from asgard.http.client import http_client
from asgard.workers.models.app_stats import AppStats
from asgard.workers.models.scalable_app import ScalableApp


class CloudInterface(ABC):
    @abstractmethod
    def should_scale(self, labels):
        pass

    @abstractmethod
    async def fetch_all_apps(self):
        pass

    @abstractmethod
    async def get_all_scalable_apps(self):
        pass

    @abstractmethod
    async def get_app_stats(self, app_id):
        pass


class AsgardInterface(CloudInterface):
    def should_scale(self, app: ScalableApp) -> bool:
        meets_criteria = False

        if app.autoscale_ignore:
            if "all" in app.autoscale_ignore:
                return False
            if app.autoscale_cpu:
                if "cpu" not in app.autoscale_ignore:
                    meets_criteria = True
            elif app.autoscale_mem:
                if "mem" not in app.autoscale_ignore:
                    meets_criteria = True
        else:
            if app.autoscale_cpu:
                meets_criteria = True
            elif app.autoscale_mem:
                meets_criteria = True

        return meets_criteria

    async def fetch_all_apps(self) -> List[ScalableApp]:
        def to_scalable_app(json: Dict[str, Any]) -> ScalableApp:
            app = ScalableApp(json["id"])
            if "labels" in json:
                if "asgard.autoscale.ignore" in json["labels"]:
                    app.autoscale_ignore = json["labels"][
                        "asgard.autoscale.ignore"
                    ]

                if "asgard.autoscale.cpu" in json["labels"]:
                    app.autoscale_cpu = json["labels"]["asgard.autoscale.cpu"]

                if "asgard.autoscale.mem" in json["labels"]:
                    app.autoscale_mem = json["labels"]["asgard.autoscale.mem"]

            return app

        async with http_client as client:
            response = await client.get(
                f"{settings.ASGARD_API_ADDRESS}/v2/apps"
            )
            data = await response.json()

            if data:
                apps = list(map(to_scalable_app, data))
                return apps

            return None

    async def get_all_scalable_apps(self) -> List[ScalableApp]:
        all_apps = await self.fetch_all_apps()
        if all_apps:
            return list(filter(self.should_scale, all_apps))

        return None

    async def get_app_stats(self, app_id: int) -> AppStats:
        async with http_client as client:
            http_response = await client.get(
                f"{settings.ASGARD_API_ADDRESS}/apps{app_id}/stats"
            )

            response = await http_response.json()

            if (
                response["stats"]["ram_pct"] == "0"
                and response["stats"]["cpu_pct"] == "0"
            ):
                return None
            elif len(response["stats"]["errors"]) > 0:
                return None
            else:
                return AppStats(app_id, response["stats"]["type"], response["stats"]["cpu_pct"], response["stats"]["ram_pct"], response["stats"]["cpu_thr_pct"])

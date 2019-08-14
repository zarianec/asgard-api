from typing import List

from asgard.conf import settings
from asgard.workers.autoscaler.decision_component_interface import (
    DecisionComponentInterface,
)
from asgard.workers.models.decision import Decision
from asgard.workers.models.scalable_app import ScalableApp


class DecisionComponent(DecisionComponentInterface):
    def decide_scaling_actions(
        self, apps_stats: List[ScalableApp]
    ) -> List[Decision]:
        decisions = []
        for app in apps_stats:
            decision = Decision(app.id)
            deploy_decision = False

            if app.is_set_to_scale_cpu():

                if (
                    app.app_stats.cpu_usage
                    > app.cpu_threshold + settings.AUTOSCALER_MARGIN_THRESHOLD
                    or app.app_stats.cpu_usage
                    < app.cpu_threshold - settings.AUTOSCALER_MARGIN_THRESHOLD
                ):
                    decision.cpu = (
                        app.app_stats.cpu_usage * app.cpu_allocated
                    ) / app.cpu_threshold
                    deploy_decision = True
            if app.is_set_to_scale_mem():
                if (
                    app.app_stats.mem_usage
                    > app.mem_threshold + settings.AUTOSCALER_MARGIN_THRESHOLD
                    or app.app_stats.mem_usage
                    < app.mem_threshold - settings.AUTOSCALER_MARGIN_THRESHOLD
                ):
                    decision.mem = (
                        app.app_stats.mem_usage * app.mem_allocated
                    ) / app.mem_threshold
                    deploy_decision = True

            if deploy_decision:
                decisions.append(decision)

        return decisions

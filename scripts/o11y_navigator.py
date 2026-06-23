#!/usr/bin/env python3
"""Create, update, or delete Splunk O11y Infrastructure navigator tiles."""

from __future__ import annotations

import argparse
import json
import os
import urllib.error
import urllib.parse
import urllib.request


MEDIA_TYPE = "application/vnd.splunk.observability.navigator+json"

# Single primary entity metric (ArgoCD pattern). Table "Value" column uses property "value".
PRIMARY_METRIC = (
    "otel_host_cpu",
    "CPU utilization",
    "cpu.utilization",
    "Percentage",
    "CPU use",
)


def api_request(
    api_url: str,
    token: str,
    method: str,
    path: str,
    body: dict | None = None,
) -> dict:
    url = f"{api_url.rstrip('/')}{path}"
    headers = {
        "Accept": MEDIA_TYPE,
        "X-SF-TOKEN": token,
    }
    if body is not None:
        headers["Content-Type"] = MEDIA_TYPE
    data = json.dumps(body).encode("utf-8") if body is not None else None
    request = urllib.request.Request(url, data=data, headers=headers, method=method)

    try:
        with urllib.request.urlopen(request) as response:
            raw = response.read().decode("utf-8")
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"{method} {path} failed ({exc.code}): {detail}") from exc


def find_navigator(api_url: str, token: str, display_name: str) -> dict | None:
    query = urllib.parse.urlencode({"displayName": display_name, "limit": 200})
    response = api_request(api_url, token, "GET", f"/v2/navigator?{query}")
    for navigator in response.get("results", []):
        if navigator.get("displayName") == display_name:
            return navigator
    return None


def alert_query(os_type: str) -> str:
    return f"sf_metric:cpu.utilization AND os.type:{os_type}"


def coloring_scheme() -> dict:
    return {
        "palette": "GREEN_RED",
        "minValue": 0,
        "maxValue": 100,
        "thresholds": None,
    }


def entity_metrics(os_type: str) -> list[dict]:
    entity_id, display_name, selector, value_format, value_label = PRIMARY_METRIC
    os_filter = f"filter('os.type', '{os_type}')"

    return [
        {
            "id": entity_id,
            "displayName": display_name,
            "type": "metric",
            "metricSelectors": [selector],
            "valueFormat": value_format,
            "valueLabel": value_label,
            "description": f"Color {os_type} hosts based on CPU utilization",
            "coloringScheme": coloring_scheme(),
            "job": {
                "filters": [],
                "resolution": 60000,
                "varName": "CPU_UTILIZATION",
                "template": (
                    f'CPU_UTILIZATION = data("{selector}", filter={os_filter}'
                    "{{#filter}} and {{{filter}}}{{/filter}}).mean(by=['host.name'])"
                ),
            },
        }
    ]


def list_columns() -> list[dict]:
    """ArgoCD / Hosts pattern: property columns only (no metricClasses)."""
    return [
        {"displayName": "Host", "format": "id", "property": "id"},
        {"displayName": "CPU utilization", "format": "Percentage", "property": "value"},
        {"displayName": "OS", "format": None, "property": "host_kernel_name"},
        {"displayName": "Memory", "format": "Kilobytes", "property": "host_mem_total"},
        {"displayName": "vCPU", "format": None, "property": "host_logical_cpus"},
    ]


def build_payload(
    display_name: str,
    os_type: str,
    display_label: str,
    aggregate_dashboard_id: str,
    instance_dashboard_id: str,
) -> dict:
    summary_label = f"Active {display_label} Hosts"

    return {
        "displayName": display_name,
        "alertQuery": alert_query(os_type),
        "defaultGroupBy": "none",
        "categories": [
            {
                "categoryName": "Hosts overview",
                "categoryGroupName": "Hosts",
                "categoryInstanceLabel": None,
            }
        ],
        "propertyIdentifierTemplate": "{{host.name}}",
        "requiredProperties": ["host.name"],
        "idDisplayName": "{{host.name}}",
        "instanceLabel": "Host",
        "instanceDisplayText": f"{display_label} Host",
        "summaryMetricLabel": summary_label,
        "summaryMetricProgramText": (
            "A = data('cpu.utilization', filter=filter('os.type', "
            f"'{os_type}') and filter('host.name', '*'))"
            ".mean(by=['host.name']).count().publish(label='A')"
        ),
        "aggregateDashboards": [aggregate_dashboard_id],
        "instanceDashboards": [instance_dashboard_id],
        "listColumns": list_columns(),
        "requiresFilter": False,
        "entityMetrics": entity_metrics(os_type),
        "pinnedFilters": [],
        "systemTypes": [],
        "tooltipKeyList": [
            {"property": "host.name", "displayName": "Host Name", "format": None},
            {"property": "os.type", "displayName": "OS type", "format": None},
        ],
    }


def apply_navigator(args: argparse.Namespace) -> None:
    token = os.environ.get("SPLUNK_ACCESS_TOKEN")
    if not token:
        raise SystemExit("SPLUNK_ACCESS_TOKEN environment variable is required")

    payload = build_payload(
        display_name=args.display_name,
        os_type=args.os_type,
        display_label=args.display_label,
        aggregate_dashboard_id=args.aggregate_dashboard_id,
        instance_dashboard_id=args.instance_dashboard_id,
    )

    existing = find_navigator(args.api_url, token, args.display_name)
    if existing:
        navigator_id = existing["id"]
        api_request(args.api_url, token, "PUT", f"/v2/navigator/{navigator_id}", payload)
        action = "updated"
    else:
        created = api_request(args.api_url, token, "POST", "/v2/navigator", payload)
        navigator_id = created["id"]
        action = "created"

    print(f"Navigator {action}: {args.display_name} ({navigator_id})")


def destroy_navigator(args: argparse.Namespace) -> None:
    token = os.environ.get("SPLUNK_ACCESS_TOKEN")
    if not token:
        raise SystemExit("SPLUNK_ACCESS_TOKEN environment variable is required")

    existing = find_navigator(args.api_url, token, args.display_name)
    if not existing:
        print(f"Navigator not found, skipping delete: {args.display_name}")
        return

    api_request(args.api_url, token, "DELETE", f"/v2/navigator/{existing['id']}")
    print(f"Navigator deleted: {args.display_name} ({existing['id']})")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--api-url", required=True)
    common.add_argument("--display-name", required=True)

    apply_parser = subparsers.add_parser("apply", parents=[common], help="Create or update a navigator")
    apply_parser.add_argument("--os-type", required=True, choices=["linux", "windows"])
    apply_parser.add_argument("--display-label", required=True)
    apply_parser.add_argument("--aggregate-dashboard-id", required=True)
    apply_parser.add_argument("--instance-dashboard-id", required=True)
    apply_parser.set_defaults(func=apply_navigator)

    destroy_parser = subparsers.add_parser("destroy", parents=[common], help="Delete a navigator")
    destroy_parser.set_defaults(func=destroy_navigator)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()

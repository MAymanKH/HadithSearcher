#!/usr/bin/env python3
"""Send synthetic verification events to the app's configured ingestion endpoints."""

import argparse
import datetime
import json
from pathlib import Path
import re
import urllib.error
import urllib.parse
import urllib.request
import uuid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--send", action="store_true", help="Send one event to each service")
    args = parser.parse_args()
    if not args.send:
        parser.error("Pass --send to submit synthetic events in the verification environment")

    source = (Path(__file__).resolve().parents[1] / "lib/core/constants/telemetry_config.dart").read_text()

    def config(name):
        match = re.search(
            rf"const {name} = String.fromEnvironment\(.*?defaultValue:\s*'([^']+)'",
            source,
            re.S,
        )
        if match is None:
            raise ValueError(f"Missing default configuration for {name}")
        return match.group(1)

    timestamp = datetime.datetime.now(datetime.timezone.utc).isoformat()
    event_id = uuid.uuid4().hex
    dsn = config("sentryDsn")
    uri = urllib.parse.urlsplit(dsn)
    envelope = "\n".join(json.dumps(item) for item in [
        {"event_id": event_id, "dsn": dsn},
        {"type": "event"},
        {
            "event_id": event_id,
            "timestamp": timestamp,
            "platform": "other",
            "level": "info",
            "environment": "verification",
            "message": "Synthetic telemetry integration verification",
            "tags": {"operation": "verification.sentry", "verification": "true"},
        },
    ]) + "\n"
    payload = {
        "api_key": config("posthogProjectToken"),
        "event": "telemetry_integration_verified",
        "timestamp": timestamp,
        "properties": {
            "distinct_id": f"verification-{event_id}",
            "verification": True,
            "app_environment": "verification",
            "verification_path": "ingestion_http",
            "$geoip_disable": True,
            "$process_person_profile": False,
        },
    }
    requests = [
        ("Sentry", urllib.request.Request(
            f"{uri.scheme}://{uri.netloc.split('@')[-1]}/api/{uri.path.strip('/')}/envelope/",
            data=envelope.encode(),
            headers={
                "Content-Type": "application/x-sentry-envelope",
                "X-Sentry-Auth": f"Sentry sentry_version=7, sentry_key={uri.username}",
            },
        )),
        ("PostHog", urllib.request.Request(
            config("posthogHost").rstrip("/") + "/capture/",
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
        )),
    ]
    failed = False
    for name, request in requests:
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                body = json.loads(response.read())
                accepted = body.get("id") == event_id if name == "Sentry" else body.get("status") in (1, "Ok")
                failed |= not accepted
                print(f"{name}: HTTP {response.status}, event {'accepted' if accepted else 'not accepted'}")
        except (urllib.error.URLError, TimeoutError, ValueError) as error:
            failed = True
            print(f"{name}: request failed ({type(error).__name__})")
    return int(failed)


if __name__ == "__main__":
    raise SystemExit(main())

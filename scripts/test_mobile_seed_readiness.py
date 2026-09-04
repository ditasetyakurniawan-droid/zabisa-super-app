#!/usr/bin/env python3
"""Regression tests for the development seed dependency-readiness gate."""
from __future__ import annotations

import importlib.util
import io
import pathlib
import sys
import unittest
import urllib.error
from typing import Any
from unittest import mock


MODULE_PATH = pathlib.Path(__file__).with_name("mobile-seed-demo-all.py")
SPEC = importlib.util.spec_from_file_location("mobile_seed_demo_all", MODULE_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"unable to load seed module: {MODULE_PATH}")
seed = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = seed
SPEC.loader.exec_module(seed)


class FakeClock:
    def __init__(self) -> None:
        self.now = 0.0
        self.sleeps: list[float] = []

    def monotonic(self) -> float:
        return self.now

    def sleep(self, duration: float) -> None:
        self.sleeps.append(duration)
        self.now += duration


class SequencedClient:
    def __init__(self, outcomes: list[Any]) -> None:
        self.outcomes = outcomes
        self.calls = 0

    def login(self, _email: str, _device: str) -> tuple[str, dict[str, Any]]:
        outcome = self.outcomes[min(self.calls, len(self.outcomes) - 1)]
        self.calls += 1
        if isinstance(outcome, Exception):
            raise outcome
        return outcome


class IdentityReadinessTests(unittest.TestCase):
    def test_transient_gateway_failures_are_retried_with_bounded_backoff(self) -> None:
        client = SequencedClient(
            [
                seed.ApiFailure("HTTP 502", status_code=502, retryable=True),
                seed.ApiFailure("HTTP 503", status_code=503, retryable=True),
                ("access-token", {"id": "user-id"}),
            ]
        )
        clock = FakeClock()

        result = seed.login_when_identity_ready(
            client,
            "admin@zabisa.local",
            "test-device",
            timeout_seconds=10,
            monotonic=clock.monotonic,
            sleep=clock.sleep,
        )

        self.assertEqual(("access-token", {"id": "user-id"}), result)
        self.assertEqual(3, client.calls)
        self.assertEqual([0.5, 1.0], clock.sleeps)

    def test_semantic_authentication_failure_is_not_retried(self) -> None:
        failure = seed.ApiFailure("HTTP 401", status_code=401, retryable=False)
        client = SequencedClient([failure])
        clock = FakeClock()

        with self.assertRaises(seed.ApiFailure) as raised:
            seed.login_when_identity_ready(
                client,
                "admin@zabisa.local",
                "test-device",
                timeout_seconds=10,
                monotonic=clock.monotonic,
                sleep=clock.sleep,
            )

        self.assertIs(failure, raised.exception)
        self.assertEqual(1, client.calls)
        self.assertEqual([], clock.sleeps)

    def test_retry_deadline_fails_closed(self) -> None:
        client = SequencedClient(
            [seed.ApiFailure("HTTP 504", status_code=504, retryable=True)]
        )
        clock = FakeClock()

        with self.assertRaisesRegex(seed.ApiFailure, "within 1s"):
            seed.login_when_identity_ready(
                client,
                "admin@zabisa.local",
                "test-device",
                timeout_seconds=1,
                monotonic=clock.monotonic,
                sleep=clock.sleep,
            )

        self.assertEqual([0.5, 0.5], clock.sleeps)

    def test_client_classifies_only_transient_http_statuses_as_retryable(self) -> None:
        gateway_error = urllib.error.HTTPError(
            "http://127.0.0.1:8088/api/v1/auth/login",
            502,
            "Bad Gateway",
            {},
            io.BytesIO(b'{"error":"UPSTREAM_UNAVAILABLE"}'),
        )
        with mock.patch.object(seed.urllib.request, "urlopen", side_effect=gateway_error):
            with self.assertRaises(seed.ApiFailure) as raised:
                seed.Client("http://127.0.0.1:8088").call("/api/v1/auth/login")

        self.assertEqual(502, raised.exception.status_code)
        self.assertTrue(raised.exception.retryable)

        auth_error = urllib.error.HTTPError(
            "http://127.0.0.1:8088/api/v1/auth/login",
            401,
            "Unauthorized",
            {},
            io.BytesIO(b'{"error":"INVALID_CREDENTIALS"}'),
        )
        with mock.patch.object(seed.urllib.request, "urlopen", side_effect=auth_error):
            with self.assertRaises(seed.ApiFailure) as raised:
                seed.Client("http://127.0.0.1:8088").call("/api/v1/auth/login")

        self.assertEqual(401, raised.exception.status_code)
        self.assertFalse(raised.exception.retryable)


if __name__ == "__main__":
    unittest.main()

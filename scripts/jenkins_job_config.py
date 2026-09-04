#!/usr/bin/env python3
"""Render and verify the disabled Zabisa Jenkins Multibranch job config."""

from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def descendants(node: ET.Element, name: str) -> list[ET.Element]:
    return [child for child in node.iter() if local(child.tag) == name]


def direct_children(node: ET.Element, name: str) -> list[ET.Element]:
    return [child for child in node if local(child.tag) == name]


def one(nodes: list[ET.Element], label: str) -> ET.Element:
    if len(nodes) != 1:
        raise ValueError(f"expected one {label}, got {len(nodes)}")
    return nodes[0]


def github_coordinates(repository_url: str) -> tuple[str, str]:
    match = re.fullmatch(
        r"https://github\.com/([^/]+)/([^/]+?)(?:\.git)?", repository_url
    )
    if not match:
        raise ValueError("repository must be an HTTPS github.com URL")
    return match.group(1), match.group(2)


def scm_source(root: ET.Element) -> tuple[str, ET.Element]:
    def identifies(node: ET.Element, suffix: str) -> bool:
        return local(node.tag).endswith(suffix) or node.attrib.get(
            "class", ""
        ).endswith(suffix)

    github = [
        node
        for node in root.iter()
        if identifies(node, "GitHubSCMSource")
    ]
    git = [
        node
        for node in root.iter()
        if identifies(node, "GitSCMSource")
        and not identifies(node, "GitHubSCMSource")
    ]

    if len(github) == 1 and not git:
        return "github", github[0]
    if len(git) == 1 and not github:
        return "git", git[0]
    raise ValueError(
        "expected exactly one supported GitHubSCMSource or GitSCMSource; "
        f"github={len(github)} git={len(git)}"
    )


def configure_scm(
    root: ET.Element, repository_url: str, credentials: str
) -> str:
    source_type, source = scm_source(root)
    credential_node = one(descendants(source, "credentialsId"), "SCM credentialsId")
    credential_node.text = credentials

    if source_type == "github":
        owner, repository = github_coordinates(repository_url)
        one(descendants(source, "repoOwner"), "GitHub repoOwner").text = owner
        one(descendants(source, "repository"), "GitHub repository").text = repository
    else:
        one(descendants(source, "remote"), "Git remote").text = repository_url

    source_ids = direct_children(source, "id")
    if source_ids:
        one(source_ids, "SCM source id").text = "zabisa-super-app-v1-source"
    return source_type


def enforce_disabled(root: ET.Element) -> None:
    disabled_nodes = direct_children(root, "disabled")
    disabled = one(disabled_nodes, "root disabled") if disabled_nodes else ET.SubElement(root, "disabled")
    disabled.text = "true"

    for triggers in descendants(root, "triggers"):
        for child in list(triggers):
            triggers.remove(child)


def update_description(root: ET.Element) -> None:
    descriptions = direct_children(root, "description")
    if descriptions:
        one(descriptions, "root description").text = (
            "Zabisa existing-platform Multibranch job. Created disabled; "
            "manual approval is required before first indexing/build."
        )


def render(
    source_path: Path,
    output_path: Path,
    repository_url: str,
    credentials: str,
    script_path: str,
) -> str:
    tree = ET.parse(source_path)
    root = tree.getroot()
    if "WorkflowMultiBranchProject" not in local(root.tag):
        raise ValueError(f"unexpected root: {local(root.tag)}")

    source_type = configure_scm(root, repository_url, credentials)
    one(descendants(root, "scriptPath"), "scriptPath").text = script_path
    update_description(root)
    enforce_disabled(root)
    tree.write(output_path, encoding="utf-8", xml_declaration=True)
    verify(output_path, repository_url, credentials, script_path)
    return source_type


def verify(
    config_path: Path,
    repository_url: str,
    credentials: str,
    script_path: str,
) -> str:
    root = ET.parse(config_path).getroot()
    if "WorkflowMultiBranchProject" not in local(root.tag):
        raise ValueError(f"unexpected root: {local(root.tag)}")

    source_type, source = scm_source(root)
    actual_credentials = (one(descendants(source, "credentialsId"), "SCM credentialsId").text or "").strip()
    if actual_credentials != credentials:
        raise ValueError("SCM credential ID mismatch")

    if source_type == "github":
        expected_owner, expected_repository = github_coordinates(repository_url)
        actual_owner = (one(descendants(source, "repoOwner"), "GitHub repoOwner").text or "").strip()
        actual_repository = (one(descendants(source, "repository"), "GitHub repository").text or "").strip()
        if (actual_owner, actual_repository) != (expected_owner, expected_repository):
            raise ValueError("GitHub repository identity mismatch")
    else:
        actual_remote = (one(descendants(source, "remote"), "Git remote").text or "").strip()
        if actual_remote != repository_url:
            raise ValueError("Git remote mismatch")

    actual_script = (one(descendants(root, "scriptPath"), "scriptPath").text or "").strip()
    if actual_script != script_path:
        raise ValueError("scriptPath mismatch")

    disabled = (one(direct_children(root, "disabled"), "root disabled").text or "").strip()
    if disabled != "true":
        raise ValueError("job is not disabled")
    if any(len(node) != 0 for node in descendants(root, "triggers")):
        raise ValueError("automatic triggers remain")
    return source_type


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser()
    subparsers = result.add_subparsers(dest="action", required=True)

    render_parser = subparsers.add_parser("render")
    render_parser.add_argument("source", type=Path)
    render_parser.add_argument("output", type=Path)

    verify_parser = subparsers.add_parser("verify")
    verify_parser.add_argument("config", type=Path)

    for subparser in (render_parser, verify_parser):
        subparser.add_argument("--repository", required=True)
        subparser.add_argument("--credentials", required=True)
        subparser.add_argument("--script-path", required=True)
    return result


def main() -> int:
    args = parser().parse_args()
    try:
        if args.action == "render":
            source_type = render(
                args.source,
                args.output,
                args.repository,
                args.credentials,
                args.script_path,
            )
            print(f"[jenkins-job] rendered scm_type={source_type}")
            print("[jenkins-job] disabled=true automatic_triggers=none")
        else:
            source_type = verify(
                args.config,
                args.repository,
                args.credentials,
                args.script_path,
            )
            print(f"[jenkins-job] verified scm_type={source_type}")
            print("[jenkins-job] disabled=true automatic_triggers=none")
    except (ET.ParseError, OSError, ValueError) as exc:
        print(f"[jenkins-job] ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

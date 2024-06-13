from __future__ import annotations

import json
import os
from pathlib import Path
from typing import NamedTuple
import functools

from requests import get

DOCKERFILE_PATH = Path() / "docker" / "Dockerfile"
BASE_IMAGES_JSON = Path() / "base-images.json"
BASE_IMAGE_PREFIX = "ARG BASE_IMAGE=mambaorg/micromamba"
REGISTRY_QUERY_URL = (
    "https://hub.docker.com/v2/repositories/mambaorg/micromamba/tags?page_size=200"
)
GITHUB_ENV = Path(os.environ["GITHUB_ENV"]) if "GITHUB_ENV" in os.environ else None


class DockerImageTag(NamedTuple):
    """Represents a Docker image tag in the following format:

    DockerImageTag(
        repository='mambaorg/micromamba',
        git_tag='c160e88',
        distro='jammy',
        digest='sha256:e3a59f560211ded26e65afafafd20eafc31bad2745db9a2932e39574847a7159'
    )
    """

    repository: str
    git_tag: str
    distro: str
    digest: str

    def to_str(self) -> str:
        """mambaorg/micromamba:git-515d637-jammy@sha256:f53e550..."""
        return f"{self.repository}:git-{self.git_tag}-{self.distro}@{self.digest}"

    @staticmethod
    def parse(s: str) -> DockerImageTag:
        repository, tag_digest = s.split(":", 1)
        tag, digest = tag_digest.split("@", 1)

        if tag.startswith("git-"):
            parts = tag.split("-", 2)
            git_tag = parts[1]
            distro = parts[2] if len(parts) > 2 else ""
        else:
            git_tag = ""
            distro = tag

        return DockerImageTag(repository, git_tag, distro, digest)


def get_existing_base_images() -> dict[str, DockerImageTag]:
    if not BASE_IMAGES_JSON.exists():
        raise ValueError("Base images file not found")
    raw_data = json.loads(BASE_IMAGES_JSON.read_text())
    return {key: DockerImageTag.parse(value) for key, value in raw_data.items()}


def update_base_images_json(new_base_images: dict[str, str]) -> None:
    if not BASE_IMAGES_JSON.exists():
        raise ValueError("Base images file not found")
    BASE_IMAGES_JSON.write_text(json.dumps(new_base_images, indent=4) + "\n")


def parse_dockerfile() -> tuple[DockerImageTag, int, list[str]]:
    if not DOCKERFILE_PATH.exists():
        raise ValueError("Dockerfile not found")

    lines = DOCKERFILE_PATH.read_text().splitlines()
    for line_number, line in enumerate(lines):
        if line.startswith(BASE_IMAGE_PREFIX):
            tag_string = line.split("=", 1)[1]
            return DockerImageTag.parse(tag_string), line_number, lines

    raise ValueError("Base image line not found in Dockerfile")


@functools.cache
def get_registry_results() -> list[dict]:
    """Image metadata from the registry."""
    response = get(REGISTRY_QUERY_URL)
    response.raise_for_status()
    return response.json()["results"]


def fetch_new_image_info(
    image_tag: DockerImageTag,
    starts_with="git-",
) -> DockerImageTag:
    """Return the first result from the registry that ends with the distro name."""
    results = get_registry_results()

    for result in results:
        tag = result["name"]
        if tag.startswith(starts_with) and tag.endswith(image_tag.distro):
            new_git_tag = tag.split("-", maxsplit=2)[1]
            new_digest = result["digest"]
            return DockerImageTag(
                repository=image_tag.repository,
                git_tag=new_git_tag,
                distro=image_tag.distro,
                digest=new_digest,
            )

    # Return the original DockerImageTag if no update is found
    return image_tag


def update_dockerfile(
    lines: list[str], line_number: int, image_tag: DockerImageTag
) -> str:
    new_docker_tag = f"git-{image_tag.git_tag}-{image_tag.distro}"
    replacement_line = f"{BASE_IMAGE_PREFIX}:{new_docker_tag}@{image_tag.digest}"
    lines[line_number] = replacement_line

    DOCKERFILE_PATH.write_text("\n".join(lines) + "\n")
    return new_docker_tag


def main():
    print("Updating Dockerfile...")
    current_image_tag, line_number, lines = parse_dockerfile()
    print(f"Base image tag: {current_image_tag.git_tag}")
    print(f"Base image distro: {current_image_tag.distro}")
    print(f"Base image digest: {current_image_tag.digest}")

    updated_image_tag = fetch_new_image_info(current_image_tag)

    if updated_image_tag == current_image_tag:
        print("No update needed for Dockerfile.")
    else:
        new_docker_tag = update_dockerfile(lines, line_number, updated_image_tag)
        if GITHUB_ENV:
            with open(GITHUB_ENV, "a") as f:
                f.write(f"NEW_DOCKER_TAG={new_docker_tag}\n")
        print(f"✅ Update successful: {new_docker_tag}")

    print("Updating workflow file...")
    existing_base_images = get_existing_base_images()
    updated_base_images = {
        name: fetch_new_image_info(image).to_str()
        for name, image in existing_base_images.items()
    }
    update_base_images_json(updated_base_images)
    print("✅ Workflow file updated successfully.")


if __name__ == "__main__":
    main()

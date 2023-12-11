from __future__ import annotations

import os
from pathlib import Path
from typing import NamedTuple
import functools

from requests import get

DOCKERFILE_PATH = Path() / "docker" / "Dockerfile"
WORKFLOW_PATH = Path() / ".github" / "workflows" / "publish_image.yml"
BASE_IMAGE_PREFIX = "ARG BASE_IMAGE=mambaorg/micromamba"
REGISTRY_QUERY_URL = (
    "https://hub.docker.com/v2/repositories/mambaorg/micromamba/tags?page_size=200"
)
GITHUB_OUTPUT = (
    Path(os.environ["GITHUB_OUTPUT"]) if "GITHUB_OUTPUT" in os.environ else None
)


class DockerImageTag(NamedTuple):
    repository: str
    git_tag: str
    distro: str
    digest: str

    def to_str(self) -> str:
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


def get_existing_base_images() -> list[DockerImageTag]:
    if not WORKFLOW_PATH.exists():
        raise ValueError("Workflow file not found")

    with WORKFLOW_PATH.open("r") as file:
        lines = file.readlines()

    existing_base_images = []
    matrix_start = None
    for i, line in enumerate(lines):
        if "base-image:" in line:
            matrix_start = i + 1
        elif matrix_start is not None and line.strip().startswith("-"):
            image = line.strip()[2:].strip()
            existing_base_images.append(image)
        elif matrix_start is not None and not line.strip().startswith("-"):
            break
    return [DockerImageTag.parse(image) for image in existing_base_images]


def update_workflow_file(new_base_images: list[str]) -> None:
    if not WORKFLOW_PATH.exists():
        raise ValueError("Workflow file not found")

    with WORKFLOW_PATH.open("r") as file:
        lines = file.readlines()

    # Find the start of the matrix section
    matrix_start = None
    for i, line in enumerate(lines):
        if "base-image:" in line:
            matrix_start = i + 1
            break

    if matrix_start is None:
        raise ValueError("Matrix not found in the workflow file")

    # Find the end of the matrix section
    matrix_end = matrix_start
    for i in range(matrix_start, len(lines)):
        if not lines[i].strip().startswith("-"):
            break
        matrix_end = i

    # Replace the matrix entries with new base images
    matrix_lines = [f"          - {image}\n" for image in new_base_images]
    lines[matrix_start : matrix_end + 1] = matrix_lines

    with WORKFLOW_PATH.open("w") as file:
        file.writelines(lines)


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
    response = get(REGISTRY_QUERY_URL)
    response.raise_for_status()
    return response.json()["results"]


def fetch_new_image_info(
    image_tag: DockerImageTag,
    starts_with="git-",
) -> DockerImageTag:
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


def update_dockerfile(lines: list[str], line_number: int, image_tag: DockerImageTag) -> str:
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
        new_docker_tag = update_dockerfile(
            lines,
            line_number,
            updated_image_tag,
        )
        print(f"✅ Update successful: {new_docker_tag}")

    print("Updating workflow file...")
    existing_base_images = get_existing_base_images()
    updated_base_images = [
        fetch_new_image_info(image).to_str() for image in existing_base_images
    ]
    update_workflow_file(updated_base_images)
    print("✅ Workflow file updated successfully.")


if __name__ == "__main__":
    main()

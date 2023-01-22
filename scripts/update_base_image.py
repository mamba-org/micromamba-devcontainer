from pathlib import Path
from requests import get
import os

DOCKERFILE_PATH = Path() / "docker" / "Dockerfile"
BASE_IMAGE_PREFIX = "ARG BASE_IMAGE=mambaorg/micromamba"
REGISTRY_QUERY_URL = (
    "https://hub.docker.com/v2/repositories/mambaorg/micromamba/tags?page_size=200"
)
GITHUB_OUTPUT = os.environ.get("GITHUB_OUTPUT", None)

def main():
    if not DOCKERFILE_PATH.exists():
        raise ValueError("Dockerfile not found")

    lines = DOCKERFILE_PATH.read_text().splitlines()

    rest = None
    for line_number, line in enumerate(lines):
        if line.startswith(f"{BASE_IMAGE_PREFIX}:git-"):
            rest = line[len(f"{BASE_IMAGE_PREFIX}:git-") :]
            break

    if rest is None:
        raise ValueError("Could not find base image line")

    git_tag, distro_and_digest = rest.split("-", maxsplit=1)

    if len(distro_and_digest) == 0:
        raise ValueError("Could not find suffix")
    distro, digest = distro_and_digest.split("@", maxsplit=1)
    if len(digest) == 0:
        raise ValueError("Could not find digest")

    print(f"Base image tag: {git_tag}")
    print(f"Base image distro: {distro}")
    print(f"Base image digest: {digest}")

    response = get(REGISTRY_QUERY_URL)
    response.raise_for_status()
    json = response.json()
    results = json["results"]
    new_git_tag = None
    new_digest = None
    for result in results:
        tag = result["name"]
        if tag.startswith("git-"):
            parts = tag.split("-", maxsplit=2)
            if len(parts) < 3 or parts[2] != distro:
                continue
            new_git_tag = parts[1]
            new_digest = result["digest"]
            break
    if new_git_tag is None:
        raise ValueError("Could not find matching image on DockerHub")
    assert new_digest is not None
    
    if new_git_tag == git_tag:
        print("No new image found")
        if new_digest != digest:
            raise ValueError(
                f"Digest mismatch.\nCurrent: {digest}\n    New: {new_digest}"
            )
        return
    print(f"New base image tag: {new_git_tag}")
    if new_digest == digest:
        print("Digest is unchanged, no need to update")
        return
    new_docker_tag = f"git-{new_git_tag}-{distro}"
    if GITHUB_OUTPUT is not None:
        print(f"{new_docker_tag=}", file=GITHUB_OUTPUT)
    replacement_line = f"{BASE_IMAGE_PREFIX}:{new_docker_tag}@{new_digest}"
    print(f"Updating line {line_number}...\nOld: {line}\nNew: {replacement_line}")
    lines[line_number] = replacement_line
    DOCKERFILE_PATH.write_text("\n".join(lines) + "\n")
    print("Update successful.")

if __name__ == "__main__":
    main()

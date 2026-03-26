import subprocess

import decman
from decman import Module
from decman.plugins.pacman import packages as pacman_packages
from decman.plugins.systemd import units


class DockerModule(Module):
    def __init__(self, user: str):
        super().__init__("docker")
        self.user = user

    @pacman_packages
    def pacman_packages(self) -> set[str]:
        return {"docker", "docker-compose"}

    @units
    def units(self) -> set[str]:
        return {"docker.socket"}

    def after_update(self, store):
        result = subprocess.run(
            ["id", "-nG", self.user], capture_output=True, text=True
        )
        if result.returncode != 0:
            return
        if "docker" not in result.stdout.split():
            decman.prg(["gpasswd", "-a", self.user, "docker"])

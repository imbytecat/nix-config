from decman import Module
from decman.plugins.pacman import packages
from decman.plugins.systemd import units


class DockerModule(Module):
    def __init__(self):
        super().__init__("docker")

    @packages
    def packages(self) -> set[str]:
        return {"docker", "docker-compose"}

    @units
    def units(self) -> set[str]:
        return {"docker.service"}

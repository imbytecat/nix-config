import decman
from decman import Module
from decman.plugins.pacman import packages
from decman.plugins.systemd import units


class DockerModule(Module):
    def __init__(self, user: str):
        super().__init__("docker")
        self.user = user

    @packages
    def packages(self) -> set[str]:
        return {"docker", "docker-compose"}

    @units
    def units(self) -> set[str]:
        return {"docker.socket"}

    def on_enable(self, store):
        decman.prg(["gpasswd", "-a", self.user, "docker"])

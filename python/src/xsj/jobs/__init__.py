"""The registry of standard jobs."""

from .spdir import job as spdir
from .noise import job as noise

JOBS = [spdir, noise]


#!/usr/bin/env python3
import functools
from hashlib import sha1
import json
import os
import re
import shutil
from dataclasses import dataclass
import subprocess
import sys
import textwrap
from typing import List, Optional, Tuple
import yaml

import github  # PyGithub
import requests
from packaging import version
from bs4 import BeautifulSoup
from git import Repo


# Required Environment Vars
BLOBSTORE_SECRET_ACCESS_KEY = os.environ["GCP_SERVICE_KEY"]
gh = github.Github(login_or_token=os.environ["GITHUB_COM_TOKEN"])
PR_ORG = os.environ["PR_ORG"]
PR_BASE = os.environ["PR_BASE"]
PR_LABEL = os.environ["PR_LABEL"]
# if DRY_RUN is set, blobs will not be uploaded and no PR created (downloads and local changes are still performed)
DRY_RUN = "DRY_RUN" in os.environ

# Other Global Variables
BLOBS_PATH = "config/blobs.yml"
PACKAGING_PATH = "packages/{}/packaging"


class BoshHelper:
    """
    Helper class to interface with the bosh-cli.
    """

    @classmethod
    def add_blob(cls, path, blobs_path):
        cls._run_bosh_cmd("add-blob", path, blobs_path)

    @classmethod
    def remove_blob(cls, path):
        cls._run_bosh_cmd("remove-blob", path)

    @classmethod
    def upload_blobs(cls):
        cls._run_bosh_cmd("upload-blobs")

    @classmethod
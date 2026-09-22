"""Explicit, one-time download. Desktop inference itself stays offline."""
from pathlib import Path
from huggingface_hub import snapshot_download

REPO = "aac6fef/laya-multilingual-mlx"
REVISION = "f2b4faf51023039425946074e2cf1361d2db11d5"

if __name__ == "__main__":
    destination = Path(__file__).resolve().parents[1] / "models" / "laya-multilingual-mlx"
    snapshot_download(REPO, revision=REVISION, local_dir=destination)
    print(destination)

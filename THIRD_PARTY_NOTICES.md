# Third-party attribution

## Laya — original decision model

**Source: https://github.com/NandhaKishorM/laya**

Laya is the original typed-decision model used by this application. Credit belongs to NandhaKishorM, Convai Innovations, and the Laya contributors. The upstream project identifies its license as Apache-2.0.

Tuantuan is an independent desktop application. It is not an official Laya product and does not claim authorship of the Laya model, training method, or model weights.

## laya-mlx — Apple Silicon inference port

- Source: https://github.com/mizorewww/laya-mlx
- Installed package used for the initial prototype: `laya-mlx==0.2.0`.
- License: Apache-2.0.
- The exact license and NOTICE shipped in the installed package are preserved as `licenses/laya-mlx-LICENSE.txt` and `licenses/laya-mlx-NOTICE.txt`.
- The package NOTICE records its upstream source revision and derived components. Tuantuan's adapter calls its public prediction API; this source repository does not vendor the inference implementation.

## Model artifact

- Artifact: https://huggingface.co/aac6fef/laya-multilingual-mlx
- Revision used: `f2b4faf51023039425946074e2cf1361d2db11d5`.
- The MLX artifact is a converted distribution of upstream Laya weights, not a model trained by Tuantuan.
- Model weights are excluded from Git. The explicit download helper obtains them from the source above.

## Runtime and other dependencies

The full packaging option copies Python, MLX, NumPy, Hugging Face Hub, tokenizers and their dependencies into the application bundle. Their licenses remain applicable and are retained in Python's `LICENSE.txt` and package metadata/license directories. The repository's source-only distribution does not include those installed packages or weights.

The local packaging recipe rebases binary library paths and applies ad-hoc signatures for a self-contained Mac app. It does not change model weights or the inference implementation.

## Application code

Tuantuan's desktop UI, vector character, interaction state and movement logic were implemented separately for this project. Tuantuan's own application code, build scripts and documentation are licensed under the MIT License; see the repository's root `LICENSE` file. Copyright (c) 2026 JunbiaoXue. Third-party components and model weights remain subject to their respective licenses and notices; they are not relicensed under MIT.

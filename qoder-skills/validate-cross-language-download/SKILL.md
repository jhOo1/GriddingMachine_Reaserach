---
name: validate-cross-language-download
description: Validate and, if necessary, repair the C and Fortran automatic-download entry points in GriddingMachine.jl, then produce reproducible compiler and checksum evidence for the manuscript.
---

# Validate C and Fortran download entry points

## Objective

Work in the local GriddingMachine checkout and verify that the C and Fortran entry points in `clients/` can compile and download a file through the shared Python downloader. If a wrapper is broken, make the smallest safe repair, add a deterministic smoke test or validation script, and report the exact commit and evidence. Do not claim a language is supported until its entry point has compiled and completed a checksum-verified download.

## Workspace

- GriddingMachine repository: `/Users/haomin/Desktop/code/Emerald/GriddingMachine.jl`
- Client files:
  - `clients/download.py`
  - `clients/gm_download.c`
  - `clients/gm_download.f90`
  - `clients/README.md`
- Manuscript repository: `/Users/haomin/Desktop/code/Emerald/GriddingMachine_Reaserach`
- Manuscript source: `论文/GriddingMachine论文初稿_v0.3.md`

Use the repository branch intended for this work. Do not rewrite or force-push `main`. Preserve unrelated user changes and never commit `.DS_Store`.

## Required checks

1. Record OS, compiler versions, Python version, repository branch, and commit before changing files.
2. Compile C with warnings enabled:

   ```bash
   cc -Wall -Wextra -Werror clients/gm_download.c -o /tmp/gm_download_check
   ```

3. Compile Fortran with warnings enabled when `gfortran` is available:

   ```bash
   gfortran -Wall -Wextra -fcheck=all clients/gm_download.f90 -o /tmp/gm_download_f90_check
   ```

   If no Fortran compiler is installed, do not mark the Fortran check as passed. Report the missing compiler and use an available CI or development machine.

4. Start a temporary local HTTP server serving a small binary fixture. Run each compiled wrapper against that URL and a temporary output path. The fixture must include a path with spaces when the platform permits it.
5. Verify for every successful download:
   - exit status is zero;
   - output file exists;
   - output bytes exactly equal the fixture;
   - SHA-256 matches the independently computed fixture digest;
   - the wrapper does not leave an unintended temporary file.
6. Run the shared Python downloader test and syntax checks.
7. Test the documented direct-URL invocation exactly as shown in `clients/README.md`. If tag/catalog access is documented for Python, test that separately; do not imply that C or Fortran support tag lookup unless their interfaces actually implement it.

## Repair constraints

- Keep the public command-line contract `gm_download URL OUTPUT` unless the README and manuscript are updated together.
- Keep C and Fortran wrappers delegating to one shared download implementation unless there is a concrete portability reason to change it.
- Quote URLs and output paths safely. Do not introduce shell injection or break paths containing spaces.
- Keep Python 3 as an explicit dependency if the wrappers invoke `python3`.
- Avoid adding a large framework or unrelated refactor for a two-entry-point smoke test.
- If a platform restriction prevents a runtime check, move the check to a normal local/CI environment rather than treating a killed process as a passing result.

## Evidence to save

Create or update a concise validation record in the GriddingMachine repository, for example `clients/VALIDATION.md`, containing:

- date and machine/OS;
- compiler and Python versions;
- tested commit;
- exact commands;
- fixture size and SHA-256;
- C result;
- Fortran result;
- Python result;
- any unavailable compiler or environment limitation.

Do not fabricate a Fortran result when `gfortran` is unavailable. Distinguish compile-only, runtime, and checksum-verified results.

## Manuscript synchronization

Only after the client checks pass, update the manuscript claim if needed:

- State that C and Fortran provide automatic-download entry points through the shared Python 3 downloader.
- If only source files are available or one language lacks a compiled runtime check, narrow the manuscript wording rather than overstating support.
- Keep the existing distinction between the frozen experiment version and the separately recorded client commit.
- Synchronize the Word file with `论文/tools/export_docx.py`, render it, and inspect all pages before delivery.

## Completion report

Return:

1. files changed;
2. before/after behavior if code changed;
3. compiler and runtime evidence for C, Fortran, and Python;
4. fixture SHA-256;
5. commit and push/PR status;
6. any unresolved limitation that must not be described as completed support.

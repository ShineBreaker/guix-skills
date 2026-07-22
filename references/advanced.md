## Section 17: FHS container emulation

Some upstream binaries (Electron apps, AppImages, anything with hardcoded `/usr/bin` / `/lib`) expect a regular Filesystem Hierarchy Standard layout. Guix can emulate one inside `guix shell`:

```bash
guix shell --container --emulate-fhs --network \
  --manifest=myapp-manifest.scm -- myapp --flag
```

The `--emulate-fhs` flag synthesizes `/bin`, `/usr`, `/lib`, etc. on the fly. This is the standard way to run binaries that don't fit Guix's pure store model (e.g. a desktop GUI app built outside the store).

Pitfalls:

- `--emulate-fhs` does not bring in `bash` symlinks you'd expect — AppImages that exec `/bin/bash` will fail; pre-populate or use a real `/bin/sh`.
- GPU hardware acceleration through `--emulate-fhs` requires the host's libgl/libgbm/mesa plus DRM device passthrough; verify with `glxinfo | grep "OpenGL renderer"` inside the container.

## Section 18: Encrypting secrets in a config repo (age)

A common, repo-portable pattern: encrypt secrets with [`age`](https://age-encryption.org/) and keep the ciphertext in git; keep the private key out of git. The structure is generic — adapt the directory names to your repo:

```
<repo>/
  secrets/
    age.pub            # in git; public key
    <name>.age         # in git; ciphertext
  <out-of-tree>/.keys/age   # private key (NOT in git)
<user-data>/secrets-decrypted/<name>   # decrypted plaintext (NOT in git)
```

Hard rules that hold regardless of layout:

- The **private key never enters git**. Deploy it out-of-tree (e.g. via a stow/secret-manager step) to a path outside the repo.
- Decrypted plaintext goes to a path the config runner will **not** deploy — never a directory the dotfile/home service copies into `~/.config/`, or you'll expose secrets.
- `.gitignore` must exclude the private key wholesale, then un-ignore the **public** key so it ships. Verify both directions with `git check-ignore -v <path>`.
- Add the `age` package to the user-packages list so `age` is on PATH.

A `tools/secrets`-style helper script (sub-commands `encrypt / decrypt / edit / show / list / recipients`) is a convenient wrapper; the decryption target should be a non-deployed user-data path.

> One concrete instance of this layout (with exact paths) is in `repo-guix-configs-example.md`.

## Section 19: A typical config-repo layout

Repos that follow the `blue` pattern tend to share this shape (names vary):

```
<repo>/
├── README                    # orientation
├── AGENTS/CLAUDE.md          # (optional) agent orientation injected at session start
├── blueprint.scm / Makefile  # defines the task runner (e.g. `blue`)
├── source/                   # config *source* (config.org with Noweb, or .scm)
│   ├── config.org            #   tangled into config.scm
│   ├── channel.scm           #   declared channels
│   ├── channel.lock          #   pinned commits
│   └── files/                #   static templates deployed by home-files-service-type
├── dotfiles/
│   ├── immutable/<app>/      # Guix Home stow track
│   └── mutable/<pkg>/        # GNU Stow track
├── docs/                     # topical reference docs
├── tools/                    # bootstrap / build / secret helpers
└── examples/<name>.scm       # starter templates (not the live config)
```

The authoritative map for one real repo is `repo-guix-configs-example.md`.

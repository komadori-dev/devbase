# Tagging

## Develop

```bash
git clone git@github.com:robindeclerck/devbase.git
# Open in VS Code → Reopen in Container
```

Tag a release to publish a new image to GHCR:

```bash
git tag v0.2.0
git push origin v0.2.0
```

To see existing tags:

```bash
git tag --sort=-creatordate -l --format='%(creatordate:short) %(refname:short)'
```

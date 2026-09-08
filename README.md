# Lito Action

Check package formatting or publish packages to the
[litocpp Registry](https://pkgs.litocpp.org). The action downloads a verified Lito release into the
GitHub Runner tool cache and reuses it across subsequent invocations on the same runner.

## Usage

Check formatting with:

```yaml
- name: Check formatting
  uses: hypengw/lito-action@0.1.0
  with:
    command: format-check
```

To publish, create a repository secret named `LITO_TOKEN` under
**Settings → Secrets and variables → Actions**, then pass it to the action:

```yaml
- name: Publish package
  uses: hypengw/lito-action@0.1.0
  with:
    command: publish
    token: ${{ secrets.LITO_TOKEN }}
```

Publish multiple workspace packages in dependency order with one package name per line. The
optional interval is applied between successful publishes:

```yaml
- name: Publish packages
  uses: hypengw/lito-action@0.1.0
  with:
    command: publish
    token: ${{ secrets.LITO_TOKEN }}
    packages: |
      rstd-basic
      rstd-runtime
      rstd-core
    publish-interval-seconds: 10
```

Run `actions/checkout` before either operation. Multiple invocations in one job reuse the Lito
binary at `$RUNNER_TOOL_CACHE/lito/<version>/<architecture>/bin/lito`. GitHub-hosted jobs and
workflow runs use separate runners, while a persistent self-hosted runner can retain the same tool
cache between jobs.

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `command` | Yes | — | Operation to run: `format-check` or `publish`. |
| `token` | For publish | — | litocpp Registry publish token. Pass it from a GitHub Actions secret. |
| `package` | No | — | Single package selected by either operation. |
| `packages` | No | — | Package names to publish in order, one per line. Cannot be combined with `package`. |
| `publish-interval-seconds` | No | `0` | Seconds to wait between successful package publishes. |
| `lito-version` | No | `v0.7.1` | Lito release used by the action. |
| `working-directory` | No | `.` | Directory containing the Lito project. |

The action currently supports Linux x86_64 and aarch64 runners. The token is written with private
permissions below the runner's temporary directory and removed when publishing finishes.

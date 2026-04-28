### What's changed in v0.40.0

* chore(makefile): add generate-configuration target and fix shorthand (by @patrickleet)

  Wires hops validate generate-configuration as a prerequisite of
  validate:all / validate / validate:% so configuration.yaml is
  regenerated from upbound.yaml before each validation run.

  Also switches the render/validate shorthand aliases from
  `validate: validate\:all` (which fails "No rule to make target
  `validate\:all'") to the sub-make form `$(MAKE) 'validate:all'`.

  Implements [[tasks/update-xrd-makefiles-generate-config]]

* feat(deps): update crossplane-contrib/function-auto-ready docker tag to v0.6.4 (#77) (by @renovate[bot])

  Co-authored-by: renovate[bot] <29139614+renovate[bot]@users.noreply.github.com>


See full diff: [v0.39.0...v0.40.0](https://github.com/hops-ops/aws-foundation/compare/v0.39.0...v0.40.0)

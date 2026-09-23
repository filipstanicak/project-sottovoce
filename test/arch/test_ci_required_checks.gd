## ARCHITECTURE GUARD — the workflow and the applied ruleset must describe the
## same seven gates. A renamed job otherwise stays "expected" forever on GitHub.
extends GutTest

const WORKFLOW := "res://.github/workflows/ci.yml"
const RULESET := "res://.github/main-ruleset.json"
const ACTION_FILES: Array[String] = [
	WORKFLOW,
	"res://.github/actions/setup-godot/action.yml",
]
const REQUIRED: Array[String] = [
	"resolve engine version",
	"import",
	"lint",
	"ip-guard",
	"asset-inventory",
	"test",
	"export",
]


func test_workflow_defines_every_required_check_name() -> void:
	var body := SourceScanner.read(WORKFLOW)
	assert_false(body.is_empty(), "CI workflow is unreadable")
	for context: String in REQUIRED:
		var marker := "\n    name: %s\n" % context
		assert_eq(body.split(marker).size() - 1, 1, "CI job name must occur once: %s" % context)


func test_ruleset_requires_exactly_the_workflow_contract() -> void:
	var parsed: Variant = JSON.parse_string(SourceScanner.read(RULESET))
	assert_typeof(parsed, TYPE_DICTIONARY, "main ruleset is not valid JSON")
	if not parsed is Dictionary:
		return
	var contexts: Array[String] = []
	var found := false
	for rule: Dictionary in parsed.get("rules", []):
		if rule.get("type", "") != "required_status_checks":
			continue
		found = true
		var parameters: Dictionary = rule.get("parameters", {})
		assert_true(parameters.get("strict_required_status_checks_policy", false), "strict is off")
		for check: Dictionary in parameters.get("required_status_checks", []):
			contexts.append(check.get("context", ""))
	contexts.sort()
	var expected := REQUIRED.duplicate()
	expected.sort()
	assert_true(found, "ruleset has no required_status_checks rule")
	assert_eq(contexts, expected, "workflow and branch protection have drifted")


func test_workflow_has_minimum_permissions_and_no_privileged_pr_trigger() -> void:
	var body := SourceScanner.read(WORKFLOW)
	assert_true(
		body.contains("permissions:\n  contents: read"), "workflow permissions are not read-only"
	)
	assert_false(body.contains("pull_request_target:"), "privileged PR trigger is forbidden")


func test_required_test_check_aggregates_every_suite_partition() -> void:
	var body := SourceScanner.read(WORKFLOW)
	assert_true(
		body.contains("needs: [test-core, test-integration]"),
		"required test check does not wait for both workers",
	)
	for directory: String in ["test/arch", "test/unit", "test/integration"]:
		var invocation := "bash .ci/run_gut.sh %s" % directory
		assert_eq(body.split(invocation).size() - 1, 1, "%s does not run exactly once" % directory)


func test_pipeline_proves_generated_outputs_and_real_exports() -> void:
	var body := SourceScanner.read(WORKFLOW)
	for command: String in [
		"bash .ci/check_generated_code.sh",
		"bash .ci/check_generated_resources.sh",
		"bash .ci/export_packs.sh",
	]:
		assert_eq(body.split(command).size() - 1, 1, "missing or duplicated gate: %s" % command)


func test_external_actions_are_pinned_to_full_commits() -> void:
	var violations: PackedStringArray = []
	for path: String in ACTION_FILES:
		for raw_line: String in SourceScanner.read(path).split("\n"):
			var line := raw_line.strip_edges()
			if not line.begins_with("- uses:"):
				continue
			var target := line.trim_prefix("- uses:").strip_edges().split(" #", false, 1)[0]
			if target.begins_with("./"):
				continue
			var at := target.rfind("@")
			var ref := target.substr(at + 1) if at >= 0 else ""
			if at < 0 or ref.length() != 40 or not ref.is_valid_hex_number(false):
				violations.append("%s: %s" % [path, target])
	assert_eq(
		violations.size(), 0, "actions must use immutable commit SHAs:\n" + "\n".join(violations)
	)

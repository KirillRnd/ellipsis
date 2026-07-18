$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $repoRoot "Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
$project = Join-Path $repoRoot "godot"
$env:APPDATA = Join-Path $repoRoot ".godot_appdata"
$env:LOCALAPPDATA = Join-Path $repoRoot ".godot_localappdata"

if (-not (Test-Path -LiteralPath $godot)) {
	throw "Godot console executable not found: $godot"
}

$exitCode = 0
try {
	& $godot --headless --path $project --script "res://tests/onboarding_hud_smoke.gd"
	$exitCode = $LASTEXITCODE
}
finally {
	foreach ($generatedDirectory in @($env:APPDATA, $env:LOCALAPPDATA)) {
		$resolvedTarget = [IO.Path]::GetFullPath($generatedDirectory)
		if (-not $resolvedTarget.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar)) {
			throw "Refusing to clean a directory outside the repository: $resolvedTarget"
		}
		if (Test-Path -LiteralPath $resolvedTarget) {
			Remove-Item -LiteralPath $resolvedTarget -Recurse -Force
		}
	}
}

if ($exitCode -ne 0) {
	exit $exitCode
}

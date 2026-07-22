param(
  [Parameter(Mandatory = $true)]
  [string]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Errors = [System.Collections.Generic.List[string]]::new()
. (Join-Path $PSScriptRoot 'prototype-iteration-common.ps1')

function Add-BriefError {
  param([string]$Message)
  $script:Errors.Add($Message)
}

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
  [Console]::Error.WriteLine("ERROR: file not found: $Path")
  exit 1
}

$artifact = Read-MarkdownFields -Path $Path -Names @(
  'brief_id', 'status', 'active_region_ref', 'parent_seed_ref', 'run_mode', 'iteration_number',
  'checkpoint', 'restored_preconditions', 'changed_slice', 'evidence_goal', 'completion_criteria',
  'appetite', 'coverage_limit'
)
$text = $artifact.Text
if ($text -notmatch '(?m)^# Prototype Run Brief\s*$') {
  Add-BriefError 'document must start with a Prototype Run Brief heading'
}

$requiredFields = @(
  'brief_id', 'status', 'active_region_ref', 'parent_seed_ref', 'run_mode', 'iteration_number',
  'checkpoint', 'restored_preconditions', 'changed_slice', 'evidence_goal', 'completion_criteria',
  'appetite', 'coverage_limit'
)
$values = @{}
foreach ($field in $requiredFields) {
  $value = $artifact.Values[$field]
  $values[$field] = $value
  if ([string]::IsNullOrWhiteSpace($value)) { Add-BriefError "$field must be non-empty" }
}

if ($null -ne $values.status -and $values.status -notin @('draft', 'final')) {
  Add-BriefError "status '$($values.status)' is invalid"
}
if ($null -ne $values.run_mode -and $values.run_mode -notin @('full', 'changed_slice')) {
  Add-BriefError "run_mode '$($values.run_mode)' is invalid"
}
if ($null -ne $values.parent_seed_ref) {
  if (-not [System.IO.Path]::IsPathFullyQualified($values.parent_seed_ref)) {
    Add-BriefError 'parent_seed_ref must be an absolute file path'
  } elseif (-not (Test-Path -LiteralPath $values.parent_seed_ref -PathType Leaf)) {
    Add-BriefError "parent_seed_ref file does not exist: $($values.parent_seed_ref)"
  }
}

$iterationNumber = 0
if ($null -ne $values.iteration_number -and (-not [int]::TryParse($values.iteration_number, [ref]$iterationNumber) -or $iterationNumber -lt 1)) {
  Add-BriefError 'iteration_number must be a positive integer'
}
$appetite = 0
if ($null -ne $values.appetite -and (-not [int]::TryParse($values.appetite, [ref]$appetite) -or $appetite -lt 1)) {
  Add-BriefError 'appetite must be a positive integer'
}

if ($values.run_mode -eq 'changed_slice') {
  foreach ($field in @('parent_seed_ref', 'checkpoint', 'restored_preconditions', 'changed_slice')) {
    if ($values[$field] -in @('none', 'null', 'not_applicable')) {
      Add-BriefError "changed_slice requires concrete $field"
    }
  }
}

if ($script:Errors.Count -gt 0) {
  foreach ($briefError in $script:Errors) { [Console]::Error.WriteLine("ERROR: $briefError") }
  [Console]::Error.WriteLine("RESULT: invalid, errors=$($script:Errors.Count)")
  exit 1
}

'PASS: Prototype Run Brief is valid'
"RESULT: brief_id=$($values.brief_id), run_mode=$($values.run_mode), iteration=$iterationNumber, appetite=$appetite"

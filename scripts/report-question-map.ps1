param(
  [Parameter(Mandatory = $true)]
  [string]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PropertyValue {
  param([object]$Object, [string]$Name)
  if ($null -eq $Object) { return $null }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  $property.Value
}

function Get-ArrayValue {
  param([object]$Object, [string]$Name)
  $value = Get-PropertyValue -Object $Object -Name $Name
  if ($null -eq $value) { return @() }
  @($value)
}

function Format-Counts {
  param([object[]]$Items, [scriptblock]$Selector)
  if ($Items.Count -eq 0) { return 'none' }
  @($Items | Group-Object -Property $Selector | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ', '
}

function Get-DisplayValue {
  param([object]$Object, [string]$Name, [string]$Default = 'none')
  $value = Get-PropertyValue -Object $Object -Name $Name
  if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
  $value
}

function Get-PreferredDisplayValue {
  param([object]$Object, [string]$SelectedName, [string]$RecommendedName)
  $selected = Get-DisplayValue -Object $Object -Name $SelectedName
  if ($selected -ne 'none') { return $selected }
  Get-DisplayValue -Object $Object -Name $RecommendedName
}

if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
  [Console]::Error.WriteLine("ERROR: file not found: $Path")
  exit 1
}

try {
  $document = Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
} catch {
  [Console]::Error.WriteLine("ERROR: invalid JSON: $($_.Exception.Message)")
  exit 1
}

$questions = @(Get-ArrayValue -Object $document -Name 'questions')
$insights = @(Get-ArrayValue -Object $document -Name 'insights')
$possibleGaps = @(Get-ArrayValue -Object $document -Name 'possible_gaps')
$baseline = Get-PropertyValue -Object $document -Name 'design_baseline'
$intents = @(Get-ArrayValue -Object $baseline -Name 'intents')
$nodes = @(Get-ArrayValue -Object $baseline -Name 'nodes')
$delta = Get-PropertyValue -Object $document -Name 'delta'
$changes = @(Get-ArrayValue -Object $delta -Name 'changes')
$closure = Get-PropertyValue -Object $document -Name 'closure'
$iteration = Get-PropertyValue -Object $document -Name 'iteration'
$acceptance = Get-PropertyValue -Object $document -Name 'acceptance'
$integration = Get-PropertyValue -Object $acceptance -Name 'integration'
$closureStatus = Get-PropertyValue -Object $closure -Name 'status'
if ([string]::IsNullOrWhiteSpace($closureStatus)) { $closureStatus = 'legacy / not declared' }
$nextSkill = Get-PropertyValue -Object $closure -Name 'next_skill'
if ([string]::IsNullOrWhiteSpace($nextSkill)) { $nextSkill = 'none' }

$modeSummary = Format-Counts -Items $questions -Selector {
  $value = Get-PropertyValue -Object $_ -Name 'mode'
  if ([string]::IsNullOrWhiteSpace($value)) { 'unknown' } else { $value }
}
$statusSummary = Format-Counts -Items $questions -Selector {
  $value = Get-PropertyValue -Object $_ -Name 'status'
  if ([string]::IsNullOrWhiteSpace($value)) { 'legacy' } else { $value }
}

$blockers = [System.Collections.Generic.List[string]]::new()
foreach ($question in $questions) {
  $questionId = Get-PropertyValue -Object $question -Name 'id'
  $questionStatus = Get-PropertyValue -Object $question -Name 'status'
  if ($questionStatus -in @('resolved', 'superseded')) { continue }
  $relations = Get-PropertyValue -Object $question -Name 'relations'
  foreach ($relationName in @('blocks_decision', 'blocks_verification', 'blocks_build')) {
    foreach ($target in @(Get-ArrayValue -Object $relations -Name $relationName)) {
      $blockers.Add("$questionId [$relationName] -> $target")
    }
  }
}

$remaining = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($questionId in @(Get-ArrayValue -Object $closure -Name 'remaining_verifications')) {
  if ($questionId -is [string]) { $remaining.Add($questionId) | Out-Null }
}
foreach ($question in $questions) {
  if ((Get-PropertyValue -Object $question -Name 'mode') -ne 'verify') { continue }
  $verification = Get-PropertyValue -Object $question -Name 'verification'
  if ((Get-PropertyValue -Object $verification -Name 'status') -ne 'passed') {
    $questionId = Get-PropertyValue -Object $question -Name 'id'
    if ($questionId -is [string]) { $remaining.Add($questionId) | Out-Null }
  }
}

'# Question Map Report'
''
"- Question Map: $(Get-PropertyValue -Object $document -Name 'question_map_id')"
"- Destination: $(Get-PropertyValue -Object $document -Name 'destination')"
"- Closure: $closureStatus"
"- Next skill: $nextSkill"
"- Active region: $(Get-DisplayValue -Object $iteration -Name 'active_region_ref')"
"- Iteration state: $(Get-DisplayValue -Object $iteration -Name 'state')"
"- Rerun count: $(if ($null -eq $iteration) { 0 } else { Get-PropertyValue -Object $iteration -Name 'rerun_count' })"
"- Next run: $(Get-PreferredDisplayValue -Object $iteration -SelectedName 'selected_run_mode' -RecommendedName 'recommended_run_mode')"
"- Handoff: $(Get-PreferredDisplayValue -Object $iteration -SelectedName 'selected_handoff' -RecommendedName 'recommended_handoff')"
"- Brief: $(Get-DisplayValue -Object $iteration -Name 'brief_ref')"
"- Recommended run: $(Get-DisplayValue -Object $iteration -Name 'recommended_run_mode')"
"- Selected run: $(Get-DisplayValue -Object $iteration -Name 'selected_run_mode')"
"- Recommended handoff: $(Get-DisplayValue -Object $iteration -Name 'recommended_handoff')"
"- Selected handoff: $(Get-DisplayValue -Object $iteration -Name 'selected_handoff')"
"- Acceptance: $(if ($null -eq $acceptance) { 'not declared' } else { Get-PropertyValue -Object $acceptance -Name 'status' })"
"- Integration: $(if ($null -eq $integration) { 'not declared' } else { Get-PropertyValue -Object $integration -Name 'status' })"
''
'## Counts'
''
'| Item | Count |'
'|---|---:|'
"| Questions | $($questions.Count) |"
"| Insights | $($insights.Count) |"
"| Possible gaps | $($possibleGaps.Count) |"
"| Intents | $($intents.Count) |"
"| Nodes | $($nodes.Count) |"
"| Delta changes | $($changes.Count) |"
''
'## Modes'
''
$modeSummary
''
'## Statuses'
''
$statusSummary
''
'## Current blockers'
''
if ($blockers.Count -eq 0) { '- none' } else { foreach ($blocker in $blockers) { "- $blocker" } }
''
'## Remaining verifications'
''
if ($remaining.Count -eq 0) { '- none' } else { foreach ($questionId in @($remaining | Sort-Object)) { "- $questionId" } }
''
'## Closure rationale'
''
$closureRationale = Get-PropertyValue -Object $closure -Name 'rationale'
if ([string]::IsNullOrWhiteSpace($closureRationale)) { 'not declared' } else { $closureRationale }

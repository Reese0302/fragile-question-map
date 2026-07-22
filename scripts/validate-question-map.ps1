param(
  [Parameter(Mandatory = $true)]
  [string]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Errors = [System.Collections.Generic.List[string]]::new()
$script:Warnings = [System.Collections.Generic.List[string]]::new()
. (Join-Path $PSScriptRoot 'prototype-iteration-common.ps1')

function Add-ValidationError {
  param([string]$Message)
  $script:Errors.Add($Message)
}

function Add-ValidationWarning {
  param([string]$Message)
  $script:Warnings.Add($Message)
}

function Get-PropertyValue {
  param([object]$Object, [string]$Name)
  if ($null -eq $Object) { return $null }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  $property.Value
}

function Has-Property {
  param([object]$Object, [string]$Name)
  $null -ne $Object -and $null -ne $Object.PSObject.Properties[$Name]
}

function Require-Text {
  param([object]$Object, [string]$Name, [string]$Context)
  $value = Get-PropertyValue -Object $Object -Name $Name
  if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) {
    Add-ValidationError "$Context.$Name must be non-empty text"
    return $null
  }
  $value
}

function Assert-NullableTextProperty {
  param([object]$Object, [string]$Name, [string]$Context, [bool]$Required = $true)
  if (-not (Has-Property -Object $Object -Name $Name)) {
    if ($Required) { Add-ValidationError "$Context.$Name is required" }
    return $null
  }
  $value = Get-PropertyValue -Object $Object -Name $Name
  if ($null -ne $value -and ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value))) {
    Add-ValidationError "$Context.$Name must be non-empty text or null"
    return $null
  }
  $value
}

function Assert-NullableTimestampProperty {
  param([object]$Object, [string]$Name, [string]$Context, [bool]$Required = $true)
  if (-not (Has-Property -Object $Object -Name $Name)) {
    if ($Required) { Add-ValidationError "$Context.$Name is required" }
    return $null
  }
  $value = Get-PropertyValue -Object $Object -Name $Name
  if ($null -ne $value -and $value -isnot [string] -and $value -isnot [datetime]) {
    Add-ValidationError "$Context.$Name must be timestamp text or null"
    return $null
  }
  if ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) {
    Add-ValidationError "$Context.$Name must be timestamp text or null"
    return $null
  }
  $value
}

function Get-ArrayItems {
  param(
    [object]$Object,
    [string]$Name,
    [string]$Context,
    [bool]$Required = $true
  )
  $property = if ($null -eq $Object) { $null } else { $Object.PSObject.Properties[$Name] }
  if ($null -eq $property -or $null -eq $property.Value) {
    if ($Required) { Add-ValidationError "$Context.$Name must be an array" }
    return @()
  }
  $value = $property.Value
  if ($value -is [string] -or $value -is [System.Management.Automation.PSCustomObject]) {
    Add-ValidationError "$Context.$Name must be an array"
    return @()
  }
  @($value)
}

function Assert-TextItems {
  param([object[]]$Items, [string]$Context)
  foreach ($item in $Items) {
    if ($item -isnot [string] -or [string]::IsNullOrWhiteSpace($item)) {
      Add-ValidationError "$Context must contain only non-empty text"
    }
  }
}

function Assert-KnownProperties {
  param([object]$Object, [string[]]$Allowed, [string]$Context)
  if ($null -eq $Object) { return }
  foreach ($propertyName in @($Object.PSObject.Properties.Name)) {
    if ($propertyName -notin $Allowed) {
      Add-ValidationWarning "$Context.$propertyName is an undeclared extension field"
    }
  }
}

function Add-UniqueId {
  param(
    [System.Collections.Generic.HashSet[string]]$Set,
    [string]$Id,
    [string]$Context
  )
  if ([string]::IsNullOrWhiteSpace($Id)) { return }
  if (-not $Set.Add($Id)) { Add-ValidationError "$Context id '$Id' is duplicated" }
}

function Read-ReferencedMarkdownFields {
  param([string]$ReferencedPath, [string[]]$Names, [string]$Context)
  if (-not [System.IO.Path]::IsPathFullyQualified($ReferencedPath)) {
    Add-ValidationError "$Context must be an absolute file path"
    return $null
  }
  if (-not (Test-Path -LiteralPath $ReferencedPath -PathType Leaf)) {
    Add-ValidationError "$Context file does not exist: $ReferencedPath"
    return $null
  }
  try {
    Read-MarkdownFields -Path $ReferencedPath -Names $Names
  } catch {
    Add-ValidationError "$Context could not be read: $($_.Exception.Message)"
    $null
  }
}

function Assert-MarkdownFieldEquals {
  param([hashtable]$Fields, [string]$Name, [object]$Expected, [string]$Context)
  $actual = $Fields[$Name]
  if ([string]::IsNullOrWhiteSpace($actual)) {
    Add-ValidationError "$Context.$Name must be non-empty"
  } elseif ($actual -ne $Expected) {
    Add-ValidationError "$Context.$Name '$actual' does not match '$Expected'"
  }
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

$allowedModes = @('discuss', 'verify', 'fact', 'park')
$allowedConfidence = @('provisional', 'supported', 'uncertain')
$allowedQuestionStatuses = @('open', 'resolved', 'superseded', 'deferred')
$allowedVerificationStatuses = @('not_planned', 'planned', 'running', 'passed', 'failed', 'partial')
$allowedClosureStatuses = @('active', 'design_closed', 'fully_verified', 'superseded')
$allowedIterationStates = @('exploring', 'ready_for_rerun', 'brief_ready', 'awaiting_seed', 'evidence_received', 'stalled', 'accepted')
$allowedAcceptanceStatuses = @('not_requested', 'pending', 'accepted_with_unverified_integration', 'validated')
$allowedIntegrationStatuses = @('not_verified', 'planned', 'running', 'passed', 'failed', 'partial')
$relationNames = @('blocks_decision', 'blocks_verification', 'blocks_build', 'depends_on', 'informs', 'conflicts_with')
$allowedNodeStatuses = @('mvp', 'later', 'fog', 'deferred', 'rejected')
$scopeRelations = @('current', 'bubble_up', 'informs', 'park', 'build_dependency')
$changeTypes = @('clarified', 'split', 'linked', 'invalidated', 'new_intent', 'scope_change')

Assert-KnownProperties -Object $document -Allowed @(
  'question_map_id', 'destination', 'scope', 'out_of_scope', 'source_lineage', 'questions', 'insights',
  'possible_gaps', 'design_baseline', 'mvp_seed', 'delta', 'iteration', 'acceptance', 'closure'
) -Context 'root'

Require-Text -Object $document -Name 'question_map_id' -Context 'root' | Out-Null
Require-Text -Object $document -Name 'destination' -Context 'root' | Out-Null
$scope = @(Get-ArrayItems -Object $document -Name 'scope' -Context 'root')
$outOfScope = @(Get-ArrayItems -Object $document -Name 'out_of_scope' -Context 'root')
Assert-TextItems -Items $scope -Context 'root.scope'
Assert-TextItems -Items $outOfScope -Context 'root.out_of_scope'

$questions = @(Get-ArrayItems -Object $document -Name 'questions' -Context 'root')
if ($questions.Count -eq 0) { Add-ValidationError 'root.questions must contain at least one question' }
$baseline = Get-PropertyValue -Object $document -Name 'design_baseline'
$mvpSeed = Get-PropertyValue -Object $document -Name 'mvp_seed'
if ($null -eq $baseline) { Add-ValidationError 'root.design_baseline is required' }
if ($null -eq $mvpSeed) { Add-ValidationError 'root.mvp_seed is required' }

$isV03 = (Has-Property -Object $document -Name 'iteration') -or (Has-Property -Object $document -Name 'acceptance')
$isV02OrLater = $isV03 -or (Has-Property -Object $document -Name 'closure') -or
  (Has-Property -Object $document -Name 'possible_gaps') -or
  (Has-Property -Object $document -Name 'source_lineage')
foreach ($question in $questions) {
  if ((Has-Property -Object $question -Name 'status') -or
      (Has-Property -Object $question -Name 'resolution') -or
      (Has-Property -Object $question -Name 'verification')) {
    $isV02OrLater = $true
  }
}

$questionIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
for ($index = 0; $index -lt $questions.Count; $index++) {
  $id = Require-Text -Object $questions[$index] -Name 'id' -Context "questions[$index]"
  Add-UniqueId -Set $questionIds -Id $id -Context 'question'
}

$intentIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$nodeIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$intents = @()
$nodes = @()
$expectedBaselineRef = $null
if ($null -ne $baseline) {
  Assert-KnownProperties -Object $baseline -Allowed @('id', 'revision', 'intents', 'nodes') -Context 'design_baseline'
  $baselineId = Require-Text -Object $baseline -Name 'id' -Context 'design_baseline'
  $revision = Get-PropertyValue -Object $baseline -Name 'revision'
  if ($revision -isnot [long] -and $revision -isnot [int]) { Add-ValidationError 'design_baseline.revision must be an integer' }
  elseif ($revision -lt 1) { Add-ValidationError 'design_baseline.revision must be greater than zero' }
  if ($null -ne $baselineId -and $null -ne $revision) { $expectedBaselineRef = "$baselineId@$revision" }
  $intents = @(Get-ArrayItems -Object $baseline -Name 'intents' -Context 'design_baseline')
  $nodes = @(Get-ArrayItems -Object $baseline -Name 'nodes' -Context 'design_baseline')
  if ($intents.Count -eq 0) { Add-ValidationError 'design_baseline.intents must contain at least one intent' }
  if ($nodes.Count -eq 0) { Add-ValidationError 'design_baseline.nodes must contain at least one node' }
  for ($index = 0; $index -lt $intents.Count; $index++) {
    Assert-KnownProperties -Object $intents[$index] -Allowed @('id', 'statement', 'evidence') -Context "design_baseline.intents[$index]"
    $id = Require-Text -Object $intents[$index] -Name 'id' -Context "design_baseline.intents[$index]"
    Add-UniqueId -Set $intentIds -Id $id -Context 'intent'
  }
  for ($index = 0; $index -lt $nodes.Count; $index++) {
    Assert-KnownProperties -Object $nodes[$index] -Allowed @('id', 'title', 'status', 'intent_ids', 'parent_ids', 'rationale') -Context "design_baseline.nodes[$index]"
    $id = Require-Text -Object $nodes[$index] -Name 'id' -Context "design_baseline.nodes[$index]"
    Add-UniqueId -Set $nodeIds -Id $id -Context 'node'
  }
}

$knownIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($id in $questionIds) { $knownIds.Add($id) | Out-Null }
foreach ($id in $nodeIds) { $knownIds.Add($id) | Out-Null }

for ($index = 0; $index -lt $questions.Count; $index++) {
  $question = $questions[$index]
  $context = "questions[$index]"
  Assert-KnownProperties -Object $question -Allowed @(
    'id', 'title', 'mode', 'intent', 'question', 'evidence_needed', 'relations', 'confidence',
    'status', 'resolution', 'verification'
  ) -Context $context
  Require-Text -Object $question -Name 'title' -Context $context | Out-Null
  Require-Text -Object $question -Name 'intent' -Context $context | Out-Null
  Require-Text -Object $question -Name 'question' -Context $context | Out-Null
  $mode = Require-Text -Object $question -Name 'mode' -Context $context
  if ($null -ne $mode -and $mode -notin $allowedModes) { Add-ValidationError "$context.mode '$mode' is invalid" }
  $confidence = Require-Text -Object $question -Name 'confidence' -Context $context
  if ($null -ne $confidence -and $confidence -notin $allowedConfidence) { Add-ValidationError "$context.confidence '$confidence' is invalid" }
  if ($mode -eq 'verify') { Require-Text -Object $question -Name 'evidence_needed' -Context $context | Out-Null }

  $relations = Get-PropertyValue -Object $question -Name 'relations'
  if ($null -eq $relations) {
    Add-ValidationError "$context.relations is required"
  } else {
    Assert-KnownProperties -Object $relations -Allowed $relationNames -Context "$context.relations"
    foreach ($relationName in $relationNames) {
      $targets = @(Get-ArrayItems -Object $relations -Name $relationName -Context "$context.relations" -Required $false)
      foreach ($target in $targets) {
        if ($target -isnot [string] -or [string]::IsNullOrWhiteSpace($target)) {
          Add-ValidationError "$context.relations.$relationName contains an invalid target"
        } elseif (-not $knownIds.Contains($target)) {
          Add-ValidationError "$context.relations.$relationName targets missing id '$target'"
        }
      }
    }
  }

  $status = $null
  if ($isV02OrLater -or (Has-Property -Object $question -Name 'status')) {
    $status = Require-Text -Object $question -Name 'status' -Context $context
    if ($null -ne $status -and $status -notin $allowedQuestionStatuses) { Add-ValidationError "$context.status '$status' is invalid" }
  }

  $resolution = Get-PropertyValue -Object $question -Name 'resolution'
  if ($isV02OrLater -and $null -eq $resolution) {
    Add-ValidationError "$context.resolution is required for v0.2"
  } elseif ($null -ne $resolution) {
    Assert-KnownProperties -Object $resolution -Allowed @('decision', 'evidence', 'confirmed_at', 'superseded_by') -Context "$context.resolution"
    $decision = Assert-NullableTextProperty -Object $resolution -Name 'decision' -Context "$context.resolution" -Required $isV02OrLater
    Assert-NullableTextProperty -Object $resolution -Name 'evidence' -Context "$context.resolution" -Required $isV02OrLater | Out-Null
    Assert-NullableTimestampProperty -Object $resolution -Name 'confirmed_at' -Context "$context.resolution" -Required $isV02OrLater | Out-Null
    $supersededBy = Assert-NullableTextProperty -Object $resolution -Name 'superseded_by' -Context "$context.resolution" -Required $isV02OrLater
    if ($null -ne $supersededBy -and -not $questionIds.Contains($supersededBy)) {
      Add-ValidationError "$context.resolution.superseded_by targets missing question '$supersededBy'"
    }
    if ($status -eq 'superseded' -and [string]::IsNullOrWhiteSpace($supersededBy)) {
      Add-ValidationError "$context.status superseded requires resolution.superseded_by"
    }
    if ($mode -eq 'discuss' -and $status -eq 'resolved' -and [string]::IsNullOrWhiteSpace($decision)) {
      Add-ValidationWarning "$context is resolved discuss but resolution.decision is empty"
    }
  }

  $verification = Get-PropertyValue -Object $question -Name 'verification'
  if ($isV02OrLater -and $null -eq $verification) {
    Add-ValidationError "$context.verification is required for v0.2"
  } elseif ($null -ne $verification) {
    Assert-KnownProperties -Object $verification -Allowed @('status', 'plan', 'evidence', 'last_run_at') -Context "$context.verification"
    $verificationStatus = Require-Text -Object $verification -Name 'status' -Context "$context.verification"
    if ($null -ne $verificationStatus -and $verificationStatus -notin $allowedVerificationStatuses) {
      Add-ValidationError "$context.verification.status '$verificationStatus' is invalid"
    }
    $verificationPlan = @(Get-ArrayItems -Object $verification -Name 'plan' -Context "$context.verification")
    $verificationEvidence = @(Get-ArrayItems -Object $verification -Name 'evidence' -Context "$context.verification")
    Assert-TextItems -Items $verificationPlan -Context "$context.verification.plan"
    Assert-TextItems -Items $verificationEvidence -Context "$context.verification.evidence"
    Assert-NullableTimestampProperty -Object $verification -Name 'last_run_at' -Context "$context.verification" -Required $isV02OrLater | Out-Null
    if ($verificationStatus -eq 'planned' -and $verificationPlan.Count -eq 0) {
      Add-ValidationWarning "$context verification is planned but plan is empty"
    }
    if ($verificationStatus -in @('running', 'passed', 'failed', 'partial') -and $verificationEvidence.Count -eq 0) {
      Add-ValidationWarning "$context verification status '$verificationStatus' has no execution evidence"
    }
  }
}

for ($index = 0; $index -lt $intents.Count; $index++) {
  Require-Text -Object $intents[$index] -Name 'statement' -Context "design_baseline.intents[$index]" | Out-Null
  Require-Text -Object $intents[$index] -Name 'evidence' -Context "design_baseline.intents[$index]" | Out-Null
}

for ($index = 0; $index -lt $nodes.Count; $index++) {
  $node = $nodes[$index]
  $context = "design_baseline.nodes[$index]"
  Require-Text -Object $node -Name 'title' -Context $context | Out-Null
  Require-Text -Object $node -Name 'rationale' -Context $context | Out-Null
  $status = Require-Text -Object $node -Name 'status' -Context $context
  if ($null -ne $status -and $status -notin $allowedNodeStatuses) { Add-ValidationError "$context.status '$status' is invalid" }
  $nodeIntentIds = @(Get-ArrayItems -Object $node -Name 'intent_ids' -Context $context)
  if ($nodeIntentIds.Count -eq 0) { Add-ValidationError "$context.intent_ids must contain at least one intent" }
  foreach ($intentId in $nodeIntentIds) {
    if ($intentId -isnot [string] -or -not $intentIds.Contains($intentId)) { Add-ValidationError "$context.intent_ids targets missing intent '$intentId'" }
  }
  $parentIds = @(Get-ArrayItems -Object $node -Name 'parent_ids' -Context $context -Required $false)
  foreach ($parentId in $parentIds) {
    if ($parentId -isnot [string] -or -not $nodeIds.Contains($parentId)) { Add-ValidationError "$context.parent_ids targets missing node '$parentId'" }
  }
}

$insights = @(Get-ArrayItems -Object $document -Name 'insights' -Context 'root' -Required $false)
$insightIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$bubbleUpInsights = @()
for ($index = 0; $index -lt $insights.Count; $index++) {
  $insight = $insights[$index]
  $context = "insights[$index]"
  Assert-KnownProperties -Object $insight -Allowed @(
    'id', 'origin', 'raw', 'scope_relation', 'mode', 'relation', 'confidence', 'is_new_intent', 'intent_id', 'rationale'
  ) -Context $context
  $insightId = Require-Text -Object $insight -Name 'id' -Context $context
  Add-UniqueId -Set $insightIds -Id $insightId -Context 'insight'
  $origin = Require-Text -Object $insight -Name 'origin' -Context $context
  if ($null -ne $origin -and -not $knownIds.Contains($origin)) { Add-ValidationError "$context.origin targets missing id '$origin'" }
  Require-Text -Object $insight -Name 'raw' -Context $context | Out-Null
  Require-Text -Object $insight -Name 'rationale' -Context $context | Out-Null
  $scopeRelation = Require-Text -Object $insight -Name 'scope_relation' -Context $context
  if ($null -ne $scopeRelation -and $scopeRelation -notin $scopeRelations) { Add-ValidationError "$context.scope_relation '$scopeRelation' is invalid" }
  if ($scopeRelation -eq 'bubble_up') { $bubbleUpInsights += [pscustomobject]@{ Context = $context; Origin = $origin } }
  $mode = Require-Text -Object $insight -Name 'mode' -Context $context
  if ($null -ne $mode -and $mode -notin $allowedModes) { Add-ValidationError "$context.mode '$mode' is invalid" }
  $confidence = Require-Text -Object $insight -Name 'confidence' -Context $context
  if ($null -ne $confidence -and $confidence -notin $allowedConfidence) { Add-ValidationError "$context.confidence '$confidence' is invalid" }
  $relation = Require-Text -Object $insight -Name 'relation' -Context $context
  if ($null -ne $relation -and $relation -notin $relationNames) { Add-ValidationError "$context.relation '$relation' is invalid" }
  if ($scopeRelation -eq 'build_dependency' -and $relation -ne 'blocks_build') { Add-ValidationError "$context build_dependency must use relation blocks_build" }
  $isNewIntent = Get-PropertyValue -Object $insight -Name 'is_new_intent'
  if ($isNewIntent -isnot [bool]) { Add-ValidationError "$context.is_new_intent must be boolean" }
  elseif ($isNewIntent) {
    $insightIntentId = Require-Text -Object $insight -Name 'intent_id' -Context $context
    if ($null -ne $insightIntentId -and -not $intentIds.Contains($insightIntentId)) { Add-ValidationError "$context.intent_id targets missing intent '$insightIntentId'" }
  }
}

$possibleGaps = @(Get-ArrayItems -Object $document -Name 'possible_gaps' -Context 'root' -Required $isV02OrLater)
$gapIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
for ($index = 0; $index -lt $possibleGaps.Count; $index++) {
  $gap = $possibleGaps[$index]
  $context = "possible_gaps[$index]"
  Assert-KnownProperties -Object $gap -Allowed @('id', 'observation', 'source_refs', 'evidence_type', 'confidence', 'reason_not_open') -Context $context
  $gapId = Require-Text -Object $gap -Name 'id' -Context $context
  Add-UniqueId -Set $gapIds -Id $gapId -Context 'possible_gap'
  Require-Text -Object $gap -Name 'observation' -Context $context | Out-Null
  $sourceRefs = @(Get-ArrayItems -Object $gap -Name 'source_refs' -Context $context)
  Assert-TextItems -Items $sourceRefs -Context "$context.source_refs"
  $evidenceType = Require-Text -Object $gap -Name 'evidence_type' -Context $context
  if ($null -ne $evidenceType -and $evidenceType -ne 'model_inference') { Add-ValidationError "$context.evidence_type must be 'model_inference'" }
  $gapConfidence = Require-Text -Object $gap -Name 'confidence' -Context $context
  if ($null -ne $gapConfidence -and $gapConfidence -notin @('provisional', 'unknown')) { Add-ValidationError "$context.confidence '$gapConfidence' is invalid" }
  Require-Text -Object $gap -Name 'reason_not_open' -Context $context | Out-Null
}

$sourceLineage = @(Get-ArrayItems -Object $document -Name 'source_lineage' -Context 'root' -Required $false)
for ($index = 0; $index -lt $sourceLineage.Count; $index++) {
  $source = $sourceLineage[$index]
  $context = "source_lineage[$index]"
  Assert-KnownProperties -Object $source -Allowed @('source_id', 'source_type', 'source_ref', 'parent_source_ref', 'run_mode', 'tested_slice', 'status', 'active_region_ref', 'brief_ref', 'iteration_number') -Context $context
  Require-Text -Object $source -Name 'source_id' -Context $context | Out-Null
  Require-Text -Object $source -Name 'source_type' -Context $context | Out-Null
  Require-Text -Object $source -Name 'source_ref' -Context $context | Out-Null
  $parentSourceRef = Assert-NullableTextProperty -Object $source -Name 'parent_source_ref' -Context $context
  $runMode = Require-Text -Object $source -Name 'run_mode' -Context $context
  if ($null -ne $runMode -and $runMode -notin @('full', 'changed_slice')) { Add-ValidationError "$context.run_mode '$runMode' is invalid" }
  Require-Text -Object $source -Name 'tested_slice' -Context $context | Out-Null
  $sourceStatus = Require-Text -Object $source -Name 'status' -Context $context
  if ($null -ne $sourceStatus -and $sourceStatus -notin @('draft', 'final')) { Add-ValidationError "$context.status '$sourceStatus' is invalid" }
  if ($sourceStatus -eq 'draft') { Add-ValidationWarning "$context is draft and should not be treated as confirmed provenance" }
  if ($runMode -eq 'changed_slice' -and [string]::IsNullOrWhiteSpace($parentSourceRef)) {
    Add-ValidationError "$context changed_slice requires parent_source_ref"
  }
  if (Has-Property -Object $source -Name 'active_region_ref') {
    $sourceRegionRef = Require-Text -Object $source -Name 'active_region_ref' -Context $context
    if ($null -ne $sourceRegionRef -and -not $knownIds.Contains($sourceRegionRef)) { Add-ValidationError "$context.active_region_ref targets missing id '$sourceRegionRef'" }
  }
  if (Has-Property -Object $source -Name 'brief_ref') {
    Assert-NullableTextProperty -Object $source -Name 'brief_ref' -Context $context | Out-Null
  }
  if (Has-Property -Object $source -Name 'iteration_number') {
    $sourceIteration = Get-PropertyValue -Object $source -Name 'iteration_number'
    if (($sourceIteration -isnot [int] -and $sourceIteration -isnot [long]) -or $sourceIteration -lt 1) {
      Add-ValidationError "$context.iteration_number must be a positive integer"
    }
  }
}

$selectedParentIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
if ($null -ne $mvpSeed) {
  Assert-KnownProperties -Object $mvpSeed -Allowed @('id', 'baseline_ref', 'selected_nodes', 'excluded_nodes') -Context 'mvp_seed'
  Require-Text -Object $mvpSeed -Name 'id' -Context 'mvp_seed' | Out-Null
  $mvpBaselineRef = Require-Text -Object $mvpSeed -Name 'baseline_ref' -Context 'mvp_seed'
  if ($null -ne $expectedBaselineRef -and $mvpBaselineRef -ne $expectedBaselineRef) { Add-ValidationError "mvp_seed.baseline_ref must equal '$expectedBaselineRef'" }
  $selectedNodes = @(Get-ArrayItems -Object $mvpSeed -Name 'selected_nodes' -Context 'mvp_seed')
  if ($selectedNodes.Count -eq 0) { Add-ValidationError 'mvp_seed.selected_nodes must contain at least one slice' }
  for ($index = 0; $index -lt $selectedNodes.Count; $index++) {
    $selected = $selectedNodes[$index]
    $context = "mvp_seed.selected_nodes[$index]"
    Assert-KnownProperties -Object $selected -Allowed @('parent_id', 'slice', 'acceptance') -Context $context
    $parentId = Require-Text -Object $selected -Name 'parent_id' -Context $context
    if ($null -ne $parentId) { $selectedParentIds.Add($parentId) | Out-Null }
    if ($null -ne $parentId -and -not $nodeIds.Contains($parentId)) { Add-ValidationError "$context.parent_id targets missing node '$parentId'" }
    Require-Text -Object $selected -Name 'slice' -Context $context | Out-Null
    Require-Text -Object $selected -Name 'acceptance' -Context $context | Out-Null
  }
  $excludedNodes = @(Get-ArrayItems -Object $mvpSeed -Name 'excluded_nodes' -Context 'mvp_seed' -Required $false)
  foreach ($excludedId in $excludedNodes) {
    if ($excludedId -isnot [string] -or -not $nodeIds.Contains($excludedId)) { Add-ValidationError "mvp_seed.excluded_nodes targets missing node '$excludedId'" }
  }
}

$deltaChanges = @()
if (Has-Property -Object $document -Name 'delta') {
  $delta = Get-PropertyValue -Object $document -Name 'delta'
  if ($null -ne $delta) {
    Assert-KnownProperties -Object $delta -Allowed @('id', 'baseline_ref', 'changes') -Context 'delta'
    Require-Text -Object $delta -Name 'id' -Context 'delta' | Out-Null
    $deltaBaselineRef = Require-Text -Object $delta -Name 'baseline_ref' -Context 'delta'
    if ($null -ne $expectedBaselineRef -and $deltaBaselineRef -ne $expectedBaselineRef) { Add-ValidationError "delta.baseline_ref must equal '$expectedBaselineRef'" }
    $deltaChanges = @(Get-ArrayItems -Object $delta -Name 'changes' -Context 'delta')
    for ($index = 0; $index -lt $deltaChanges.Count; $index++) {
      $change = $deltaChanges[$index]
      $context = "delta.changes[$index]"
      Assert-KnownProperties -Object $change -Allowed @('type', 'target_id', 'before', 'after', 'evidence', 'decision') -Context $context
      $type = Require-Text -Object $change -Name 'type' -Context $context
      if ($null -ne $type -and $type -notin $changeTypes) { Add-ValidationError "$context.type '$type' is invalid" }
      $targetId = Require-Text -Object $change -Name 'target_id' -Context $context
      if ($null -ne $targetId -and -not $knownIds.Contains($targetId)) { Add-ValidationError "$context.target_id targets missing id '$targetId'" }
      Require-Text -Object $change -Name 'before' -Context $context | Out-Null
      Require-Text -Object $change -Name 'after' -Context $context | Out-Null
      Require-Text -Object $change -Name 'evidence' -Context $context | Out-Null
      Require-Text -Object $change -Name 'decision' -Context $context | Out-Null
    }
  }
}

foreach ($bubbleUp in $bubbleUpInsights) {
  $matchingDelta = @($deltaChanges | Where-Object {
    (Get-PropertyValue -Object $_ -Name 'target_id') -eq $bubbleUp.Origin -and
    (Get-PropertyValue -Object $_ -Name 'type') -in @('invalidated', 'scope_change')
  })
  if ($matchingDelta.Count -eq 0) {
    Add-ValidationWarning "$($bubbleUp.Context) is bubble_up but no invalidated/scope_change delta targets '$($bubbleUp.Origin)'"
  }
}

$iteration = Get-PropertyValue -Object $document -Name 'iteration'
if ($isV03 -and $null -eq $iteration) {
  Add-ValidationError 'root.iteration is required for v0.3'
} elseif ($null -ne $iteration) {
  Assert-KnownProperties -Object $iteration -Allowed @(
    'active_region_ref', 'state', 'current_seed_ref', 'last_full_seed_ref', 'parent_seed_ref', 'brief_ref',
    'iteration_number', 'rerun_count', 'recommended_run_mode', 'selected_run_mode', 'recommendation_rationale',
    'recommended_handoff', 'selected_handoff'
  ) -Context 'iteration'
  $activeRegionRef = Require-Text -Object $iteration -Name 'active_region_ref' -Context 'iteration'
  if ($null -ne $activeRegionRef -and -not $knownIds.Contains($activeRegionRef)) { Add-ValidationError "iteration.active_region_ref targets missing id '$activeRegionRef'" }
  $iterationState = Require-Text -Object $iteration -Name 'state' -Context 'iteration'
  if ($null -ne $iterationState -and $iterationState -notin $allowedIterationStates) { Add-ValidationError "iteration.state '$iterationState' is invalid" }
  $currentSeedRef = Require-Text -Object $iteration -Name 'current_seed_ref' -Context 'iteration'
  $lastFullSeedRef = Assert-NullableTextProperty -Object $iteration -Name 'last_full_seed_ref' -Context 'iteration'
  $parentSeedRef = Assert-NullableTextProperty -Object $iteration -Name 'parent_seed_ref' -Context 'iteration'
  $briefRef = Assert-NullableTextProperty -Object $iteration -Name 'brief_ref' -Context 'iteration'
  $iterationNumber = Get-PropertyValue -Object $iteration -Name 'iteration_number'
  if (($iterationNumber -isnot [int] -and $iterationNumber -isnot [long]) -or $iterationNumber -lt 1) { Add-ValidationError 'iteration.iteration_number must be a positive integer' }
  $rerunCount = Get-PropertyValue -Object $iteration -Name 'rerun_count'
  if (($rerunCount -isnot [int] -and $rerunCount -isnot [long]) -or $rerunCount -lt 0) { Add-ValidationError 'iteration.rerun_count must be a non-negative integer' }
  $recommendedRunMode = Assert-NullableTextProperty -Object $iteration -Name 'recommended_run_mode' -Context 'iteration'
  $selectedRunMode = Assert-NullableTextProperty -Object $iteration -Name 'selected_run_mode' -Context 'iteration'
  foreach ($modeValue in @($recommendedRunMode, $selectedRunMode)) {
    if ($null -ne $modeValue -and $modeValue -notin @('full', 'changed_slice')) { Add-ValidationError "iteration run mode '$modeValue' is invalid" }
  }
  $recommendationRationale = Assert-NullableTextProperty -Object $iteration -Name 'recommendation_rationale' -Context 'iteration'
  $recommendedHandoff = Assert-NullableTextProperty -Object $iteration -Name 'recommended_handoff' -Context 'iteration'
  $selectedHandoff = Assert-NullableTextProperty -Object $iteration -Name 'selected_handoff' -Context 'iteration'
  foreach ($handoffValue in @($recommendedHandoff, $selectedHandoff)) {
    if ($null -ne $handoffValue -and $handoffValue -notin @('A', 'B', 'C')) { Add-ValidationError "iteration handoff '$handoffValue' is invalid" }
  }
  $currentSource = @($sourceLineage | Where-Object { (Get-PropertyValue -Object $_ -Name 'source_ref') -eq $currentSeedRef })
  if ($currentSource.Count -ne 1) { Add-ValidationError "iteration.current_seed_ref must match exactly one source_lineage source_ref" }
  elseif ((Get-PropertyValue -Object $currentSource[0] -Name 'status') -ne 'final') { Add-ValidationError 'iteration.current_seed_ref must reference a Final Seed' }
  if ($null -ne $lastFullSeedRef) {
    $lastFullSource = @($sourceLineage | Where-Object { (Get-PropertyValue -Object $_ -Name 'source_ref') -eq $lastFullSeedRef -and (Get-PropertyValue -Object $_ -Name 'run_mode') -eq 'full' -and (Get-PropertyValue -Object $_ -Name 'status') -eq 'final' })
    if ($lastFullSource.Count -ne 1) { Add-ValidationError 'iteration.last_full_seed_ref must reference exactly one Final full Seed' }
  }
  if ($iterationState -eq 'ready_for_rerun') {
    if ($deltaChanges.Count -eq 0) { Add-ValidationError 'iteration ready_for_rerun requires at least one delta change' }
    $hasRelatedDelta = $false
    foreach ($change in $deltaChanges) {
      $targetId = Get-PropertyValue -Object $change -Name 'target_id'
      if ($targetId -eq $activeRegionRef) {
        $hasRelatedDelta = $true
        break
      }
      $targetQuestion = @($questions | Where-Object { (Get-PropertyValue -Object $_ -Name 'id') -eq $targetId })
      if ($targetQuestion.Count -ne 1) { continue }
      $targetRelations = Get-PropertyValue -Object $targetQuestion[0] -Name 'relations'
      foreach ($relationName in $relationNames) {
        if ($activeRegionRef -in @(Get-ArrayItems -Object $targetRelations -Name $relationName -Context "delta target question '$targetId'.relations" -Required $false)) {
          $hasRelatedDelta = $true
          break
        }
      }
      if ($hasRelatedDelta) { break }
    }
    if (-not $hasRelatedDelta) { Add-ValidationError 'iteration ready_for_rerun requires a delta related to the active region' }
    $hasRelatedEvidenceGoal = $false
    foreach ($question in $questions) {
      if ((Get-PropertyValue -Object $question -Name 'mode') -ne 'verify') { continue }
      $evidenceNeeded = Get-PropertyValue -Object $question -Name 'evidence_needed'
      if ($evidenceNeeded -isnot [string] -or [string]::IsNullOrWhiteSpace($evidenceNeeded)) { continue }
      $relations = Get-PropertyValue -Object $question -Name 'relations'
      foreach ($relationName in $relationNames) {
        if ($activeRegionRef -in @(Get-ArrayItems -Object $relations -Name $relationName -Context "question '$((Get-PropertyValue -Object $question -Name 'id'))'.relations" -Required $false)) {
          $hasRelatedEvidenceGoal = $true
          break
        }
      }
      if ($hasRelatedEvidenceGoal) { break }
    }
    if (-not $hasRelatedEvidenceGoal) { Add-ValidationError 'iteration ready_for_rerun requires a Verify evidence goal related to the active region' }
    if ($null -eq $recommendedRunMode) { Add-ValidationError 'iteration ready_for_rerun requires recommended_run_mode' }
    if ($null -eq $recommendationRationale) { Add-ValidationError 'iteration ready_for_rerun requires recommendation_rationale' }
    if ($null -eq $parentSeedRef) { Add-ValidationError 'iteration ready_for_rerun requires parent_seed_ref' }
    if ($null -ne $selectedRunMode -or $null -ne $briefRef -or $null -ne $recommendedHandoff -or $null -ne $selectedHandoff) {
      Add-ValidationError 'iteration ready_for_rerun cannot already contain selected mode, Brief, or handoff'
    }
  }
  if ($null -ne $selectedRunMode -and $null -eq $recommendedRunMode) {
    Add-ValidationError 'iteration.selected_run_mode requires preserved recommended_run_mode'
  }
  if ($iterationState -in @('brief_ready', 'awaiting_seed', 'evidence_received', 'stalled', 'accepted')) {
    if ($null -eq $selectedRunMode) { Add-ValidationError "iteration state '$iterationState' requires selected_run_mode" }
    if ($null -eq $briefRef) { Add-ValidationError "iteration state '$iterationState' requires brief_ref" }
    if ($null -eq $recommendedHandoff) { Add-ValidationError "iteration state '$iterationState' requires recommended_handoff" }
  }
  $briefArtifact = $null
  if ($iterationState -in @('brief_ready', 'awaiting_seed', 'evidence_received', 'stalled', 'accepted') -and $null -ne $briefRef) {
    $briefArtifact = Read-ReferencedMarkdownFields -ReferencedPath $briefRef -Names @(
      'brief_id', 'status', 'active_region_ref', 'parent_seed_ref', 'run_mode', 'iteration_number',
      'checkpoint', 'restored_preconditions', 'changed_slice', 'evidence_goal', 'completion_criteria',
      'appetite', 'coverage_limit'
    ) -Context 'iteration.brief_ref'
    if ($null -ne $briefArtifact) {
      $briefFields = $briefArtifact.Values
      if ($briefFields['status'] -ne 'final') { Add-ValidationError 'iteration Brief must have status final' }
      Assert-MarkdownFieldEquals -Fields $briefFields -Name 'active_region_ref' -Expected $activeRegionRef -Context 'iteration Brief'
      Assert-MarkdownFieldEquals -Fields $briefFields -Name 'parent_seed_ref' -Expected $parentSeedRef -Context 'iteration Brief'
      Assert-MarkdownFieldEquals -Fields $briefFields -Name 'run_mode' -Expected $selectedRunMode -Context 'iteration Brief'
      $briefIterationNumber = 0
      if (-not [int]::TryParse($briefFields['iteration_number'], [ref]$briefIterationNumber) -or $briefIterationNumber -ne $iterationNumber) {
        Add-ValidationError "iteration Brief.iteration_number '$($briefFields['iteration_number'])' does not match '$iterationNumber'"
      }
    }
  }
  if ($iterationState -eq 'brief_ready' -and $null -ne $selectedHandoff) {
    Add-ValidationError 'iteration brief_ready must wait for user handoff selection'
  }
  if ($iterationState -in @('awaiting_seed', 'evidence_received', 'stalled', 'accepted') -and $null -eq $selectedHandoff) {
    Add-ValidationError "iteration state '$iterationState' requires selected_handoff"
  }
  if ($iterationState -in @('evidence_received', 'stalled', 'accepted') -and $currentSource.Count -eq 1) {
    $returnedSource = $currentSource[0]
    if ((Get-PropertyValue -Object $returnedSource -Name 'active_region_ref') -ne $activeRegionRef) { Add-ValidationError 'returned Seed active_region_ref does not match iteration.active_region_ref' }
    if ((Get-PropertyValue -Object $returnedSource -Name 'brief_ref') -ne $briefRef) { Add-ValidationError 'returned Seed brief_ref does not match iteration.brief_ref' }
    if ((Get-PropertyValue -Object $returnedSource -Name 'iteration_number') -ne $iterationNumber) { Add-ValidationError 'returned Seed iteration_number does not match iteration.iteration_number' }
    if ((Get-PropertyValue -Object $returnedSource -Name 'run_mode') -ne $selectedRunMode) { Add-ValidationError 'returned Seed run_mode does not match iteration.selected_run_mode' }
    if ((Get-PropertyValue -Object $returnedSource -Name 'parent_source_ref') -ne $parentSeedRef) { Add-ValidationError 'returned Seed parent_source_ref does not match iteration.parent_seed_ref' }
    $returnedSeedRef = Get-PropertyValue -Object $returnedSource -Name 'source_ref'
    $seedArtifact = Read-ReferencedMarkdownFields -ReferencedPath $returnedSeedRef -Names @(
      'seed_id', 'status', 'parent_seed_ref', 'run_mode', 'tested_slice', 'input_brief_ref',
      'starting_checkpoint', 'restored_preconditions'
    ) -Context 'returned Seed source_ref'
    if ($null -ne $seedArtifact -and $null -ne $briefArtifact) {
      $seedFields = $seedArtifact.Values
      $briefFields = $briefArtifact.Values
      if ($seedFields['status'] -ne 'final') { Add-ValidationError 'returned Seed Markdown must have status final' }
      Assert-MarkdownFieldEquals -Fields $seedFields -Name 'parent_seed_ref' -Expected $parentSeedRef -Context 'returned Seed'
      Assert-MarkdownFieldEquals -Fields $seedFields -Name 'run_mode' -Expected $selectedRunMode -Context 'returned Seed'
      Assert-MarkdownFieldEquals -Fields $seedFields -Name 'input_brief_ref' -Expected $briefRef -Context 'returned Seed'
      Assert-MarkdownFieldEquals -Fields $seedFields -Name 'tested_slice' -Expected $briefFields['changed_slice'] -Context 'returned Seed'
      Assert-MarkdownFieldEquals -Fields $seedFields -Name 'starting_checkpoint' -Expected $briefFields['checkpoint'] -Context 'returned Seed'
      Assert-MarkdownFieldEquals -Fields $seedFields -Name 'restored_preconditions' -Expected $briefFields['restored_preconditions'] -Context 'returned Seed'
      Assert-MarkdownFieldEquals -Fields $seedFields -Name 'tested_slice' -Expected (Get-PropertyValue -Object $returnedSource -Name 'tested_slice') -Context 'source_lineage'
    }
  }
  if ($rerunCount -ge 3) {
    Add-ValidationWarning 'rerun_count reached 3; choose redefine, add_evidence, Park, or continue explicitly'
  }
}

$acceptance = Get-PropertyValue -Object $document -Name 'acceptance'
$acceptanceStatus = $null
$integrationStatus = $null
if ($isV03 -and $null -eq $acceptance) {
  Add-ValidationError 'root.acceptance is required for v0.3'
} elseif ($null -ne $acceptance) {
  Assert-KnownProperties -Object $acceptance -Allowed @('status', 'decision', 'confirmed_at', 'integration') -Context 'acceptance'
  $acceptanceStatus = Require-Text -Object $acceptance -Name 'status' -Context 'acceptance'
  if ($null -ne $acceptanceStatus -and $acceptanceStatus -notin $allowedAcceptanceStatuses) { Add-ValidationError "acceptance.status '$acceptanceStatus' is invalid" }
  $acceptanceDecision = Assert-NullableTextProperty -Object $acceptance -Name 'decision' -Context 'acceptance'
  $acceptanceConfirmedAt = Assert-NullableTimestampProperty -Object $acceptance -Name 'confirmed_at' -Context 'acceptance'
  $integration = Get-PropertyValue -Object $acceptance -Name 'integration'
  if ($null -eq $integration) {
    Add-ValidationError 'acceptance.integration is required'
  } else {
    Assert-KnownProperties -Object $integration -Allowed @('status', 'verification_question_id', 'full_seed_ref', 'last_change_iteration') -Context 'acceptance.integration'
    $integrationStatus = Require-Text -Object $integration -Name 'status' -Context 'acceptance.integration'
    if ($null -ne $integrationStatus -and $integrationStatus -notin $allowedIntegrationStatuses) { Add-ValidationError "acceptance.integration.status '$integrationStatus' is invalid" }
    $integrationQuestionId = Assert-NullableTextProperty -Object $integration -Name 'verification_question_id' -Context 'acceptance.integration'
    if ($null -ne $integrationQuestionId) {
      if (-not $questionIds.Contains($integrationQuestionId)) { Add-ValidationError "acceptance.integration.verification_question_id targets missing question '$integrationQuestionId'" }
      else {
        $integrationQuestion = @($questions | Where-Object { (Get-PropertyValue -Object $_ -Name 'id') -eq $integrationQuestionId })[0]
        if ((Get-PropertyValue -Object $integrationQuestion -Name 'mode') -ne 'verify') { Add-ValidationError "acceptance.integration.verification_question_id '$integrationQuestionId' is not a verify question" }
      }
    }
    $integrationFullSeedRef = Assert-NullableTextProperty -Object $integration -Name 'full_seed_ref' -Context 'acceptance.integration'
    $lastChangeIteration = Get-PropertyValue -Object $integration -Name 'last_change_iteration'
    if (($lastChangeIteration -isnot [int] -and $lastChangeIteration -isnot [long]) -or $lastChangeIteration -lt 1) { Add-ValidationError 'acceptance.integration.last_change_iteration must be a positive integer' }
    if ($acceptanceStatus -in @('not_requested', 'pending') -and ($null -ne $acceptanceDecision -or $null -ne $acceptanceConfirmedAt)) {
      Add-ValidationError "acceptance status '$acceptanceStatus' cannot contain an acceptance decision"
    }
    if ($acceptanceStatus -in @('accepted_with_unverified_integration', 'validated')) {
      if ($null -eq $acceptanceDecision -or $null -eq $acceptanceConfirmedAt) { Add-ValidationError "acceptance status '$acceptanceStatus' requires explicit decision and confirmed_at" }
      if ($null -eq $iteration -or (Get-PropertyValue -Object $iteration -Name 'state') -ne 'accepted') { Add-ValidationError "acceptance status '$acceptanceStatus' requires iteration.state accepted" }
    }
    if ($acceptanceStatus -eq 'accepted_with_unverified_integration') {
      if ($integrationStatus -eq 'passed') { Add-ValidationError 'accepted_with_unverified_integration cannot claim passed integration' }
      if ($null -ne $integrationFullSeedRef) { Add-ValidationError 'accepted_with_unverified_integration must not claim a validating full_seed_ref' }
    }
    if ($acceptanceStatus -eq 'validated') {
      if ($integrationStatus -ne 'passed') { Add-ValidationError 'validated requires acceptance.integration.status passed' }
      if ($null -eq $integrationFullSeedRef) {
        Add-ValidationError 'validated requires acceptance.integration.full_seed_ref'
      } else {
        $integrationFullSources = @($sourceLineage | Where-Object {
          (Get-PropertyValue -Object $_ -Name 'source_ref') -eq $integrationFullSeedRef -and
          (Get-PropertyValue -Object $_ -Name 'run_mode') -eq 'full' -and
          (Get-PropertyValue -Object $_ -Name 'status') -eq 'final'
        })
        if ($integrationFullSources.Count -ne 1) { Add-ValidationError 'validated full_seed_ref must match exactly one Final full Seed' }
        else {
          $fullIteration = Get-PropertyValue -Object $integrationFullSources[0] -Name 'iteration_number'
          if (($fullIteration -isnot [int] -and $fullIteration -isnot [long]) -or $fullIteration -le $lastChangeIteration) {
            Add-ValidationError 'validated full Seed must occur after the last design change iteration'
          }
        }
        if ($null -ne $iteration -and (Get-PropertyValue -Object $iteration -Name 'last_full_seed_ref') -ne $integrationFullSeedRef) {
          Add-ValidationError 'validated full_seed_ref must equal iteration.last_full_seed_ref'
        }
      }
      if ($null -eq $integrationQuestionId) { Add-ValidationError 'validated requires acceptance.integration.verification_question_id' }
      if ($null -ne $integrationQuestionId -and $questionIds.Contains($integrationQuestionId)) {
        $integrationQuestion = @($questions | Where-Object { (Get-PropertyValue -Object $_ -Name 'id') -eq $integrationQuestionId })[0]
        $integrationVerification = Get-PropertyValue -Object $integrationQuestion -Name 'verification'
        $integrationEvidence = @(Get-ArrayItems -Object $integrationVerification -Name 'evidence' -Context "question '$integrationQuestionId'.verification" -Required $false)
        if ((Get-PropertyValue -Object $integrationVerification -Name 'status') -ne 'passed' -or $integrationEvidence.Count -eq 0) {
          Add-ValidationError 'validated requires the integration Verify question to be passed with evidence'
        }
      }
    }
  }
}

if ($isV03 -and $null -ne $iteration -and (Get-PropertyValue -Object $iteration -Name 'state') -eq 'accepted' -and $acceptanceStatus -notin @('accepted_with_unverified_integration', 'validated')) {
  Add-ValidationError 'iteration.state accepted requires an explicit accepted or validated acceptance status'
}

$closure = Get-PropertyValue -Object $document -Name 'closure'
$closureStatus = $null
if ($isV02OrLater -and $null -eq $closure) {
  Add-ValidationError 'root.closure is required for v0.2'
} elseif ($null -ne $closure) {
  Assert-KnownProperties -Object $closure -Allowed @('status', 'rationale', 'remaining_verifications', 'next_skill') -Context 'closure'
  $closureStatus = Require-Text -Object $closure -Name 'status' -Context 'closure'
  if ($null -ne $closureStatus -and $closureStatus -notin $allowedClosureStatuses) { Add-ValidationError "closure.status '$closureStatus' is invalid" }
  Require-Text -Object $closure -Name 'rationale' -Context 'closure' | Out-Null
  $remainingVerifications = @(Get-ArrayItems -Object $closure -Name 'remaining_verifications' -Context 'closure')
  foreach ($questionId in $remainingVerifications) {
    if ($questionId -isnot [string] -or -not $questionIds.Contains($questionId)) {
      Add-ValidationError "closure.remaining_verifications targets missing question '$questionId'"
      continue
    }
    $question = @($questions | Where-Object { (Get-PropertyValue -Object $_ -Name 'id') -eq $questionId })[0]
    if ((Get-PropertyValue -Object $question -Name 'mode') -ne 'verify') {
      Add-ValidationError "closure.remaining_verifications '$questionId' is not a verify question"
    }
  }
  Assert-NullableTextProperty -Object $closure -Name 'next_skill' -Context 'closure' -Required $isV02OrLater | Out-Null
  if ($closureStatus -eq 'fully_verified' -and $remainingVerifications.Count -gt 0) {
    Add-ValidationError 'closure fully_verified requires remaining_verifications to be empty'
  }
  if ($closureStatus -eq 'fully_verified') {
    foreach ($question in $questions) {
      if ((Get-PropertyValue -Object $question -Name 'mode') -ne 'verify') { continue }
      $verification = Get-PropertyValue -Object $question -Name 'verification'
      if ($null -eq $verification -or (Get-PropertyValue -Object $verification -Name 'status') -ne 'passed') {
        Add-ValidationError "closure fully_verified requires verify question '$((Get-PropertyValue -Object $question -Name 'id'))' to be passed"
      }
    }
  }
  if ($isV03 -and $acceptanceStatus -eq 'validated' -and $closureStatus -ne 'fully_verified') {
    Add-ValidationError 'validated acceptance requires closure fully_verified'
  }
  if ($isV03 -and $acceptanceStatus -eq 'accepted_with_unverified_integration' -and $closureStatus -eq 'fully_verified') {
    Add-ValidationError 'accepted_with_unverified_integration cannot use closure fully_verified'
  }
  if ($isV03 -and $closureStatus -eq 'fully_verified' -and $acceptanceStatus -ne 'validated') {
    Add-ValidationError 'v0.3 closure fully_verified requires validated acceptance'
  }
}

foreach ($question in $questions) {
  $questionId = Get-PropertyValue -Object $question -Name 'id'
  $questionStatus = Get-PropertyValue -Object $question -Name 'status'
  if ($null -eq $questionStatus) { $questionStatus = 'legacy_open' }
  $relations = Get-PropertyValue -Object $question -Name 'relations'
  if ($null -eq $relations) { continue }
  $decisionTargets = @(Get-ArrayItems -Object $relations -Name 'blocks_decision' -Context "question '$questionId'.relations" -Required $false)
  $buildTargets = @(Get-ArrayItems -Object $relations -Name 'blocks_build' -Context "question '$questionId'.relations" -Required $false)
  if ($closureStatus -eq 'design_closed' -and $questionStatus -eq 'open' -and $decisionTargets.Count -gt 0) {
    Add-ValidationWarning "closure is design_closed but open question '$questionId' still has blocks_decision targets"
  }
  if ($questionStatus -in @('open', 'deferred', 'legacy_open')) {
    foreach ($target in @($decisionTargets + $buildTargets | Select-Object -Unique)) {
      if ($selectedParentIds.Contains($target)) {
        Add-ValidationWarning "selected MVP node '$target' still depends on unresolved question '$questionId'"
      }
    }
  }
}

foreach ($validationWarning in $script:Warnings) { "WARNING: $validationWarning" }

if ($script:Errors.Count -gt 0) {
  foreach ($validationError in $script:Errors) { [Console]::Error.WriteLine("ERROR: $validationError") }
  [Console]::Error.WriteLine("RESULT: invalid, errors=$($script:Errors.Count), warnings=$($script:Warnings.Count)")
  exit 1
}

'PASS: question map is valid'
"RESULT: questions=$($questions.Count), insights=$($insights.Count), intents=$($intents.Count), nodes=$($nodes.Count), warnings=$($script:Warnings.Count), schema=$(if ($isV03) { 'v0.3' } elseif ($isV02OrLater) { 'v0.2' } else { 'v0.1-legacy' })"

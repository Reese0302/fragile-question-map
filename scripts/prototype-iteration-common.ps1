Set-StrictMode -Version Latest

function Get-MarkdownField {
  param([string]$Text, [string]$Name)
  $pattern = '(?m)^\s*-\s*`' + [regex]::Escape($Name) + '`:\s*(.+?)\s*$'
  $match = [regex]::Match($Text, $pattern)
  if (-not $match.Success) { return $null }
  $match.Groups[1].Value.Trim()
}

function Read-MarkdownFields {
  param([string]$Path, [string[]]$Names)
  $text = Get-Content -LiteralPath $Path -Encoding UTF8 -Raw
  $values = @{}
  foreach ($name in $Names) {
    $values[$name] = Get-MarkdownField -Text $text -Name $name
  }
  [pscustomobject]@{ Text = $text; Values = $values }
}

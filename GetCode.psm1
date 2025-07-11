function getcode ($chosenname, [switch]$help) {# Copies code snippets to clipboard.
$powershell = Split-Path $profile; $basemodulepath = Join-Path $powershell "Modules\GetCode"; $snippetfile = Join-Path $basemodulepath "GetCode.json.gz"

# Modify fields sent to it with proper word wrapping.
function wordwrap ($field, $maximumlinelength) {if ($null -eq $field) {return $null}
$breakchars = ',.;?!\/ '; $wrapped = @()
if (-not $maximumlinelength) {[int]$maximumlinelength = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($maximumlinelength -lt 60) {[int]$maximumlinelength = 60}
if ($maximumlinelength -gt $Host.UI.RawUI.BufferSize.Width) {[int]$maximumlinelength = $Host.UI.RawUI.BufferSize.Width}
foreach ($line in $field -split "`n", [System.StringSplitOptions]::None) {if ($line -eq "") {$wrapped += ""; continue}
$remaining = $line
while ($remaining.Length -gt $maximumlinelength) {$segment = $remaining.Substring(0, $maximumlinelength); $breakIndex = -1
foreach ($char in $breakchars.ToCharArray()) {$index = $segment.LastIndexOf($char)
if ($index -gt $breakIndex) {$breakIndex = $index}}
if ($breakIndex -lt 0) {$breakIndex = $maximumlinelength - 1}
$chunk = $segment.Substring(0, $breakIndex + 1); $wrapped += $chunk; $remaining = $remaining.Substring($breakIndex + 1)}
if ($remaining.Length -gt 0 -or $line -eq "") {$wrapped += $remaining}}
return ($wrapped -join "`n")}

# Display a horizontal line.
function line ($colour, $length, [switch]$pre, [switch]$post, [switch]$double) {if (-not $length) {[int]$length = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($length) {if ($length -lt 60) {[int]$length = 60}
if ($length -gt $Host.UI.RawUI.BufferSize.Width) {[int]$length = $Host.UI.RawUI.BufferSize.Width}}
if ($pre) {Write-Host ""}
$character = if ($double) {"="} else {"-"}
Write-Host -f $colour ($character * $length)
if ($post) {Write-Host ""}}

function help {# Inline help.
function scripthelp ($section) {line yellow 100 -pre; $pattern = "(?ims)^## ($section.*?)(##|\z)"; $match = [regex]::Match($scripthelp, $pattern); $lines = $match.Groups[1].Value.TrimEnd() -split "`r?`n", 2; Write-Host $lines[0] -f yellow; line yellow 100
if ($lines.Count -gt 1) {wordwrap $lines[1] 100| Out-String | Out-Host -Paging}; line yellow 100}

$scripthelp = Get-Content -Raw -Path $PSCommandPath; $sections = [regex]::Matches($scripthelp, "(?im)^## (.+?)(?=\r?\n)")
if ($sections.Count -eq 1) {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help:" -f cyan; scripthelp $sections[0].Groups[1].Value; ""; return}
$selection = $null
do {cls; Write-Host "$([System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)) Help Sections:`n" -f cyan; for ($i = 0; $i -lt $sections.Count; $i++) {"{0}: {1}" -f ($i + 1), $sections[$i].Groups[1].Value}
if ($selection) {scripthelp $sections[$selection - 1].Groups[1].Value}
$input = Read-Host "`nEnter a section number to view"
if ($input -match '^\d+$') {$index = [int]$input
if ($index -ge 1 -and $index -le $sections.Count) {$selection = $index}
else {$selection = $null}} else {""; return}}
while ($true); return}

# External call to help.
if ($help) {help; return}

function copytoclipboard ($chosenname) {$code = $snippets[$chosenname]; Set-Clipboard -Value $code}

function readsavedata ($path) {$compressed = [System.IO.File]::ReadAllBytes($path); $ms = New-Object System.IO.MemoryStream(,$compressed); $gz = New-Object System.IO.Compression.GZipStream($ms, [IO.Compression.CompressionMode]::Decompress); $reader = New-Object System.IO.StreamReader($gz); $json = $reader.ReadToEnd(); $reader.Close(); $gz.Close(); $ms.Close(); return $json | ConvertFrom-Json -AsHashtable}

if (Test-Path $snippetfile) {$snippets = readsavedata $snippetfile} else {$snippets = @{}}

function savesnippets ($snippets, $path) {$json = $snippets | ConvertTo-Json -Depth 5; $bytes = [System.Text.Encoding]::UTF8.GetBytes($json); $msOut = New-Object System.IO.MemoryStream; $gzOut = New-Object System.IO.Compression.GZipStream($msOut, [IO.Compression.CompressionMode]::Compress); $gzOut.Write($bytes, 0, $bytes.Length); $gzOut.Close(); [System.IO.File]::WriteAllBytes($path, $msOut.ToArray()); $msOut.Close()}

# Internal viewer.
function internalviewer ($name, $content) {$searchHits = @(0..($content.Count - 1) | Where-Object {$content[$_] -match $pattern}); $currentSearchIndex = $searchHits | Where-Object {$_ -gt $pos} | Select-Object -First 1; $pos = $currentSearchIndex; $script:coloredContent = @(); $content = $content | ForEach-Object {wordwrap $_ $null} | ForEach-Object {$_ -split "`n"}

# Pre-configure colours.
$content | ForEach-Object {$line = $_
if ($line -match '^<#') {$inBlockComment = $true}
if ($inBlockComment) {$colour = 'darkgray'
if ($line -match "^## ") {$colour = 'gray'}
if ($line -match '^#>') {$inBlockComment = $false}}
else {if ($line -match '^(#|-----)') {$colour = 'yellow'}
elseif ($line -match '(?i)^function\s') {$colour = 'cyan'}
elseif ($line -match '(?i)^sal\s') {$colour = 'green'}
else {$colour = 'white'}}
$script:coloredContent += [PSCustomObject]@{Line = $line; Color = $colour}}

# Set page size and initialize search.
$pageSize = 44; $pos = 0; $script:fileName = [System.IO.Path]::GetFileName($script:file); $searchHits = @(); $currentSearchIndex = -1

# Define paging.
function getbreakpoint {param($start); return [Math]::Min($start + $pageSize - 1, $content.Count - 1)}

# Contextualized display.
function showpage {cls; $start = $pos; $end = getbreakpoint $start; $pageLines = $script:coloredContent[$start..$end]; $highlight = if ($searchTerm) {"$pattern"} else {$null}
foreach ($entry in $pageLines) {$line = $entry.Line; $colour = $entry.Color
if ($highlight -and $line -match $highlight) {$parts = [regex]::Split($line, "($highlight)")
foreach ($part in $parts) {if ($part -match "^$highlight$") {Write-Host -f black -b yellow $part -n}
else {Write-Host -f $colour $part -n}}; ""}
else {Write-Host -f $colour $line}}

# Pad with blank lines if this page has fewer than $pageSize lines
$linesShown = $end - $start + 1
if ($linesShown -lt $pageSize) {for ($i = 1; $i -le ($pageSize - $linesShown); $i++) {Write-Host ""}}}

# Main menu display loop.
$statusmessage = ""; $errormessage = ""; $searchmessage = "Search Commands"
while ($true) {showpage; $pageNum = [math]::Floor($pos / $pageSize) + 1; $totalPages = [math]::Ceiling($content.Count / $pageSize)
if ($searchHits.Count -gt 0) {$currentMatch = [array]::IndexOf($searchHits, $pos); if ($currentMatch -ge 0) {$searchmessage = "Match $($currentMatch + 1) of $($searchHits.Count)"}
else {$searchmessage = "Search active ($($searchHits.Count) matches)"}}
line yellow -double
if (-not $errormessage -or $errormessage.length -lt 1) {$middlecolour = "white"; $middle = $statusmessage} else {$middlecolour = "red"; $middle = $errormessage}
$left = "$name".PadRight(57); $middle = "$middle".PadRight(44); $right = "(Page $pageNum of $totalPages)"
Write-Host -f white $left -n; Write-Host -f $middlecolour $middle -n; Write-Host -f cyan $right
$left = "Page Commands".PadRight(55); $middle = "| $searchmessage ".PadRight(34); $right = "| Exit Commands"
Write-Host -f yellow ($left + $middle + $right)
Write-Host -f yellow "[F]irst [N]ext [+/-]# Lines P[A]ge # [P]revious [L]ast | [<][S]earch[>] [#]Match [C]lear | [Q]uit " -n
$statusmessage = ""; $errormessage = ""; $searchmessage = "Search Commands"

# Define dynamic action keys.
function getaction {[string]$buffer = ""
while ($true) {$key = [System.Console]::ReadKey($true)
switch ($key.Key) {'LeftArrow' {return 'P'}
'UpArrow' {return 'U1L'}
'Backspace' {return 'P'}
'PageUp' {return 'P'}
'RightArrow' {return 'N'}
'DownArrow' {return 'D1L'}
'PageDown' {return 'N'}
'Enter' {if ($buffer) {return $buffer}
else {return 'N'}}
'Home' {return 'F'}
'End' {return 'L'}
default {$char = $key.KeyChar
switch ($char) {',' {return '<'}
'.' {return '>'}
{$_ -match '(?i)[B-Z]'} {return $char.ToString().ToUpper()}
{$_ -match '[A#\+\-\d]'} {$buffer += $char}
default {$buffer = ""}}}}}}

$action = getaction

# Actions.
switch ($action.ToString().ToUpper()) {'F' {$pos = 0}
'N' {$next = getbreakpoint $pos; if ($next -lt $content.Count - 1) {$pos = $next + 1}
else {$pos = [Math]::Min($pos + $pageSize, $content.Count - 1)}}
'P' {$pos = [Math]::Max(0, $pos - $pageSize)}
'L' {$lastPageStart = [Math]::Max(0, [int][Math]::Floor(($content.Count - 1) / $pageSize) * $pageSize); $pos = $lastPageStart}

'<' {$currentSearchIndex = ($searchHits | Where-Object {$_ -lt $pos} | Select-Object -Last 1)
if ($null -eq $currentSearchIndex -and $searchHits -ne @()) {$currentSearchIndex = $searchHits[-1]; $statusmessage = "Wrapped to last match."; $errormessage = $null}
$pos = $currentSearchIndex
if (-not $searchHits -or $searchHits.Count -eq 0) {$errormessage = "No search in progress."; $statusmessage = $null}}
'S' {Write-Host -f green "`n`nKeyword to search forward from this point in the logs" -n; $searchTerm = Read-Host " "
if (-not $searchTerm) {$errormessage = "No keyword entered."; $statusmessage = $null; $searchTerm = $null; $searchHits = @(); continue}
$pattern = "(?i)$searchTerm"; $searchHits = @(0..($content.Count - 1) | Where-Object { $content[$_] -match $pattern })
if ($searchHits.Count -eq 0) {$errormessage = "Keyword not found in file."; $statusmessage = $null; $currentSearchIndex = -1}
else {$currentSearchIndex = $searchHits | Where-Object { $_ -gt $pos } | Select-Object -First 1
if ($null -eq $currentSearchIndex) {Write-Host -f green "No match found after this point. Jump to first match? (Y/N)" -n; $wrap = Read-Host " "
if ($wrap -match '^[Yy]$') {$currentSearchIndex = $searchHits[0]; $statusmessage = "Wrapped to first match."; $errormessage = $null}
else {$errormessage = "Keyword not found further forward."; $statusmessage = $null; $searchHits = @(); $searchTerm = $null}}
$pos = $currentSearchIndex}}
'>' {$currentSearchIndex = ($searchHits | Where-Object {$_ -gt $pos} | Select-Object -First 1)
if ($null -eq $currentSearchIndex -and $searchHits -ne @()) {$currentSearchIndex = $searchHits[0]; $statusmessage = "Wrapped to first match."; $errormessage = $null}
$pos = $currentSearchIndex
if (-not $searchHits -or $searchHits.Count -eq 0) {$errormessage = "No search in progress."; $statusmessage = $null}}
'C' {$searchTerm = $null; $searchHits.Count = 0; $searchHits = @(); $currentSearchIndex = $null}
'Q' {cls; return}
'U1L' {$pos = [Math]::Max($pos - 1, 0)}
'D1L' {$pos = [Math]::Min($pos + 1, $content.Count - $pageSize)}

default {if ($action -match '^[\+\-](\d+)$') {$offset = [int]$action; $newPos = $pos + $offset; $pos = [Math]::Max(0, [Math]::Min($newPos, $content.Count - $pageSize))}

elseif ($action -match '^(\d+)$') {$jump = [int]$matches[1]
if (-not $searchHits -or $searchHits.Count -eq 0) {$errormessage = "No search in progress."; $statusmessage = $null; continue}
$targetIndex = $jump - 1
if ($targetIndex -ge 0 -and $targetIndex -lt $searchHits.Count) {$pos = $searchHits[$targetIndex]
if ($targetIndex -eq 0) {$statusmessage = "Jumped to first match."}
else {$statusmessage = "Jumped to match #$($targetIndex + 1)."}; $errormessage = $null}
else {$errormessage = "Match #$jump is out of range."; $statusmessage = $null}}

elseif ($action -match '^A(\d+)$') {$requestedPage = [int]$matches[1]
if ($requestedPage -lt 1 -or $requestedPage -gt $totalPages) {$errormessage = "Page #$requestedPage is out of range."; $statusmessage = $null}
else {$pos = ($requestedPage - 1) * $pageSize}}

else {$errormessage = "Invalid input."; $statusmessage = $null}}}}}

# Handle key assignments.
function getaction {[string]$buffer = ""
while ($true) {$key = [System.Console]::ReadKey($true)
$char = $key.KeyChar
switch ($key.Key) {'F1' {return 'H'}
'Escape' {return 'Q'}
'Enter'  {if ($buffer) {return $buffer}
else {return 'CLEAR'}}
'Backspace' {return 'CLEAR'}
'UpArrow' {return 'UP'}
'DownArrow' {return 'DOWN'}
'LeftArrow' {return 'LEFT'}
'RightArrow' {return 'Right'}
'Home' {return '1'}
'PageUp' {return '1'}
'End' {return $names.Count}
'PageDown' {return $names.Count}
{$_ -match '(?i)[ACEHRVQ]'} {return $char.ToString().ToUpper()}
{$_ -match '[\d+]'} {$buffer += $char}
default {return 'INVALID'}}}}

# Display menu.
if (-not $chosenname) {while ($true) {cls; Write-Host -f yellow "Available Code Snippets:"; $names = $snippets.Keys | Sort-Object; $half = [math]::Ceiling($names.Count / 2); line yellow 60 -post
for ($i = 0; $i -lt $half; $i++) {$leftIndex = $i; $rightIndex = $i + $half; 
$leftNum = "{0}. " -f ($leftIndex + 1); $leftName = $names[$leftIndex].PadRight(26)
$rightNum = if ($rightIndex -lt $names.Count) {"{0}. " -f ($rightIndex + 1)} else {""}
$rightName = if ($rightIndex -lt $names.Count) {$names[$rightIndex]} else {""}
Write-Host -n -f cyan $leftNum.PadRight(4); Write-Host -n -f white $leftName
if ($rightName) {Write-Host -n -f cyan $rightNum.PadRight(4); Write-Host -f white $rightName}
else {Write-Host ""}}
line yellow 60 -pre

# Display message center.
if ($errormessage) {Write-Host -f red "$errormessage"; line yellow 60}
elseif ($message) {if ($message -eq "copied") {Write-Host -f green "✅ Copied '" -n; Write-Host -f white "$chosenname" -n; Write-Host -f green "' to the clipboard."}
else {Write-Host -f white "$message"}; line yellow 60}
elseif ($view) {$viewName = $names[[int]$num - 1]; copytoclipboard $viewName; Write-Host -f yellow "$viewName`:`n"; wordwrap ($snippets[$viewName].Substring(0, [Math]::Min(1000, $snippets[$viewName].Length))) 60 | Write-Host -f white; line yellow 60; if ($snippets[$viewName].Length -gt 1000) {$message = "copied"; $view = $false; $chosenname = $viewName; internalviewer $viewname $snippets[$viewName]; continue}}
else {"`n"}
Write-Host -f yellow "[#]Copy  [V]iew  [A]dd  [E]dit  [R]emove  [H]elp  [Q]uit " -n; $action = getaction; $errormessage = $null; $message = $null

# Assign instant action keys.
switch ($action.ToString().ToUpper()) {'CLEAR' {$message = $null; $errormessage = $null; continue}

'C' {$message = "Enter the number of the item you wish to copy."; $errormessage = $null}

'V' {Write-Host -f yellow "`n`nEnter the snippet number to view: " -n; $num = Read-Host
if ($num -match '^\d+$' -and [int]$num -gt 0 -and [int]$num -le $names.Count) {$view = $true}
try {$num = [int]$num
if ($num -lt 1 -or $num -gt $names.Count) {$errormessage = "Selection outside of range."}
else {$view = $true}}
catch {$errormessage = "Invalid selection."}
$message = $null}

'A' {Write-Host -f yellow "`n`nEnter a name for the new snippet: " -n; $name = Read-Host
if (-not $name -or $snippets.ContainsKey($name)) {$errormessage = "Invalid or duplicate snippet name."; continue}
Write-Host -f yellow "`nEnter your snippet code. Type 'END' on a new line when done."; line yellow 60; $lines = @()
while ($true) {$line = Read-Host; if ($line -eq 'END') {break}; $lines += $line}
$snippets[$name] = $lines -join "`n"; savesnippets $snippets $snippetfile; $message = "Entry '$name' added."}

'E' {Write-Host -f yellow "`n`nEnter the number of the snippet to edit: " -n; $editNumber = Read-Host
if (-not ($editNumber -match '^\d+$') -or [int]$editNumber -lt 1 -or [int]$editNumber -gt $names.Count) {$errormessage = "Invalid snippet number."; continue}
$editIndex = [int]$editNumber - 1
$match = $names[$editIndex]
Write-Host -f yellow "`nCurrent code for '$match':"; line yellow 60; wordwrap($snippets[$match]) 60 | Out-Host
line yellow 60 -pre; Write-Host -f yellow "Enter the new code. Type 'END' on a new line to finish editing."; line yellow 60
$lines = @(); while ($true) {$line = Read-Host; if ($line -eq 'END') {break}; $lines += $line}
Write-Host -f yellow "`nProceed with the update? " -n; $confirmupdate = Read-Host
if ($confirmupdate -match "^[Yy]") {$snippets[$match] = $lines -join "`n"; savesnippets $snippets $snippetfile; $message = "Snippet '$match' updated."; $errormessage = $null; continue}
else {$errormessage = "Aborted."; $message = $null}}

'R' {Write-Host -f yellow "`n`nEnter the number of the snippet to remove: " -n; $removeNumber = Read-Host
if (-not ($removeNumber -match '^\d+$') -or [int]$removeNumber -lt 1 -or [int]$removeNumber -gt $names.Count) {$errormessage = "Invalid snippet number."; continue}
$removeIndex = [int]$removeNumber - 1; $match = $names[$removeIndex]; Write-Host -f red "`nAre you sure you want to delete '$match'? Type 'yes' to confirm: " -n; $confirmdelete = Read-Host
if ($confirmdelete -match '(?i)^yes$') {$snippets.Remove($match); savesnippets $snippets $snippetfile; $errormessage = "Snippet '$match' removed."}
else {$errormessage = "Deletion cancelled."}}

'H' {help; $message = $null; $errormessage = $null}

'Q' {"`n"; return}

'UP' {$arrow--; if ($arrow -lt 0) {$arrow = $names.Count - 1}; $chosenname = $names[$arrow]; copytoclipboard $chosenname; $message = "copied"}

'DOWN' {$arrow++; if ($arrow -ge $names.Count) {$arrow = 0}; $chosenname = $names[$arrow]; copytoclipboard $chosenname; $message = "copied"}

'LEFT' {$half = [math]::Ceiling($names.Count/2); if ($arrow -ge $half) {$arrow -= $half} else {$arrow += $half; if ($arrow -ge $names.Count) {$arrow = $arrow - $half - ($names.Count % 2)}}; $chosenname = $names[$arrow]; copytoclipboard $chosenname; $message = "copied"}

'RIGHT' {$half = [math]::Ceiling($names.Count/2); if ($arrow -lt $half) {$arrow += $half; if ($arrow -ge $names.Count) {$arrow = $arrow - $half - ($names.Count % 2)}} else {$arrow -= $half}; $chosenname = $names[$arrow]; copytoclipboard $chosenname; $message = "copied"}

# Assign buffered action keys.
default {if ($action -match '^(\d+)$') {$action = [int]$action

if ($action -lt 1 -or $action -gt $names.Count) {$errormessage = "Selection outside of range."; $message = $null}

if ($action -match '^\d+$' -and [int]$action -gt 0 -and [int]$action -le $names.Count) {$action = $action - 1; $chosenname = $names[[int]$action]; copytoclipboard $chosenname; $message = "copied"}}
else {$errormessage = "Invalid selection."}}}}}

if ($chosenname) {$match = $snippets.Keys | Where-Object {$_ -ieq $chosenname} | Select-Object -First 1
if (-not $match) {$match = $snippets.Keys | Where-Object {$_ -match "(?i)$chosenname"} | Sort-Object | Select-Object -First 1
if ($match) {Write-Host -f yellow "`nNo exact match for '$chosenname'. Using closest match."}
else {Write-Host -f yellow "`nInvalid snippet name. Valid names are:`n "; $snippets.Keys | Sort-Object | Write-Host -f white; ""; return}}
$chosenname = $match; copytoclipboard $chosenname; Write-Host -f green "`n✅ Snippet '" -n; Write-Host -f white "$chosenname" -n; Write-Host -f green "' copied to the clipboard.`n"}}

Export-ModuleMember -Function getcode

# Helptext.

<#
## GetCode

GetCode allows you to copy a code snippet to your clipboard.
This is built for programmers, in order to expedite coding.

Without commandline parameters an interactive menu will open.
## License
MIT License

Copyright © 2025 Craig Plath

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
copies of the Software, and to permit persons to whom the Software is 
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in 
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
THE SOFTWARE.
##>

function getcode ($chosenname, [switch]$help) {# Copies code snippets to clipboard.
$powershell = Split-Path $profile; $basemodulepath = Join-Path $powershell "Modules\GetCode"; $snippetfile = Join-Path $basemodulepath "GetCode.json.gz"

function line ($colour, $length, [switch]$pre, [switch]$post) {if (-not $length) {[int]$length = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($length) {if ($length -lt 60) {[int]$length = 60}
if ($length -gt $Host.UI.RawUI.BufferSize.Width) {[int]$length = $Host.UI.RawUI.BufferSize.Width}}
if ($pre) {Write-Host ""}
Write-Host -f $colour ("-" * $length)
if ($post) {Write-Host ""}}

function wordwrap ($field, $maximumlinelength) {if ($null -eq $field -or $field.Length -eq 0) {return $null}
$breakchars = ',.;?!\/ '; $wrapped = @()

if (-not $maximumlinelength) {[int]$maximumlinelength = (100, $Host.UI.RawUI.WindowSize.Width | Measure-Object -Maximum).Maximum}
if ($maximumlinelength) {if ($maximumlinelength -lt 60) {[int]$maximumlinelength = 60}
if ($maximumlinelength -gt $Host.UI.RawUI.BufferSize.Width) {[int]$maximumlinelength = $Host.UI.RawUI.BufferSize.Width}}

foreach ($line in $field -split "`n") {if ($line.Trim().Length -eq 0) {$wrapped += ''; continue}
$remaining = $line.Trim()
while ($remaining.Length -gt $maximumlinelength) {$segment = $remaining.Substring(0, $maximumlinelength); $breakIndex = -1

foreach ($char in $breakchars.ToCharArray()) {$index = $segment.LastIndexOf($char)
if ($index -gt $breakIndex) {$breakChar = $char; $breakIndex = $index}}
if ($breakIndex -lt 0) {$breakIndex = $maximumlinelength - 1; $breakChar = ''}
$chunk = $segment.Substring(0, $breakIndex + 1).TrimEnd(); $wrapped += $chunk; $remaining = $remaining.Substring($breakIndex + 1).TrimStart()}

if ($remaining.Length -gt 0) {$wrapped += $remaining}}
return ($wrapped -join "`n")}

function copytoclipboard ($chosenname) {$code = $snippets[$chosenname]; Set-Clipboard -Value $code}

function readsavedata ($path) {$compressed = [System.IO.File]::ReadAllBytes($path); $ms = New-Object System.IO.MemoryStream(,$compressed); $gz = New-Object System.IO.Compression.GZipStream($ms, [IO.Compression.CompressionMode]::Decompress); $reader = New-Object System.IO.StreamReader($gz); $json = $reader.ReadToEnd(); $reader.Close(); $gz.Close(); $ms.Close(); return $json | ConvertFrom-Json -AsHashtable}

if (Test-Path $snippetfile) {$snippets = readsavedata $snippetfile} else {$snippets = @{}}

function savesnippets ($snippets, $path) {$json = $snippets | ConvertTo-Json -Depth 5; $bytes = [System.Text.Encoding]::UTF8.GetBytes($json); $msOut = New-Object System.IO.MemoryStream; $gzOut = New-Object System.IO.Compression.GZipStream($msOut, [IO.Compression.CompressionMode]::Compress); $gzOut.Write($bytes, 0, $bytes.Length); $gzOut.Close(); [System.IO.File]::WriteAllBytes($path, $msOut.ToArray()); $msOut.Close()}

if ($Help) {Write-Host -f cyan "`nUsage: GetCode 'snippet name'`n"; Write-Host -f white "GetCode allows you to copy a code snippet to your clipboard.`nThis is built for programmers, in order to expedite coding.`n`nWithout commandline parameters an interactive menu will open.`n"; return}

# Handle key assignments.
function getaction {[string]$buffer = ""
while ($true) {$key = [System.Console]::ReadKey($true)
$char = $key.KeyChar
switch ($key.Key) {'F1' {return 'H'}
'Escape' {return 'Q'}
'Enter'  {if ($buffer) {return $buffer}
else {return 'CLEAR'}}
'Backspace' {return 'CLEAR'}
'V' {return 'P'}
{$_ -match '(?i)[CPAERHQ]'} {return $char.ToString().ToUpper()}
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
if ($errormessage) {Write-Host -f red "$errormessage"; line yellow 60}
elseif ($message) {if ($message -eq "copied") {Write-Host -f green "✅ Copied '" -n; Write-Host -f white "$chosenname" -n; Write-Host -f green "' to the clipboard."}
else {Write-Host -f white "$message"}; line yellow 60}
elseif ($view) {$viewName = $names[[int]$num - 1]; copytoclipboard $viewName; Write-Host -f yellow "$viewName`:`n"; wordwrap ($snippets[$viewName].Substring(0, [Math]::Min(500, $snippets[$viewName].Length))) 60 | Write-Host -f white; if ($snippets[$viewName].Length -gt 500) {Write-Host -f white "..."}; Write-Host -f green "`n✅ Copied '" -n; Write-Host -f white "$viewName" -n; Write-Host -f green "' to the clipboard."; $view = $false; line yellow 60}
else {"`n"}

Write-Host -f yellow "[#]Copy  [P]review  [A]dd  [E]dit  [R]emove  [H]elp  [Q]uit " -n; 

$action = getaction
$errormessage = $null; $message = $null

# Assign instant action keys.
switch ($action.ToString().ToUpper()) {'CLEAR' {$message = $null; $errormessage = $null; continue}

'C' {$message = "Enter the number of the item you wish to copy."; $errormessage = $null}

'P' {Write-Host -f yellow "`n`nEnter the snippet number to view: " -n; $num = Read-Host
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
Write-Host -f yellow "`nCurrent code for '$match':"; line yellow 60; $snippets[$match] | Out-Host
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

'H' {$message = "Commandline Usage: GetCode 'snippet name'`n`nGetCode allows you to copy a code snippet to your clipboard.`nThis is built for programmers, in order to expedite coding."; $errormessage = $null}

'Q' {"`n"; return}

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

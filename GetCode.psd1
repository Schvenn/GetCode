@{RootModule = 'GetCode.psm1'
ModuleVersion = '1.1'
GUID = 'c0f73712-37a6-4f93-b96a-fad6620786ee'
Author = 'Craig Plath'
CompanyName = 'Plath Consulting Incorporated'
Copyright = '© Craig Plath. All rights reserved.'
Description = 'A PowerShell module to maintain a library of useful code snippets.'
PowerShellVersion = '5.1'
FunctionsToExport = @('GetCode')
CmdletsToExport = @()
VariablesToExport = @()
AliasesToExport = @()
FileList = @('GetCode.json.gz', 'GetCode.psm1')

PrivateData = @{PSData = @{Tags = @('code', 'development', 'powershell', 'snippets')
LicenseUri = 'https://github.com/Schvenn/GetCode/blob/main/LICENSE'
ProjectUri = 'https://github.com/Schvenn/GetCode'
ReleaseNotes = 'Added inline viewer and improved help.'}}}

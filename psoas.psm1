function New-SwaggerModule
{
    [CmdletBinding(DefaultParameterSetName = 'InMemory')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [uri]$URI,

        [Parameter(Mandatory = $true, ParameterSetName = 'ToFile')]
        [string]$Path,

        [Parameter()]
        [switch]$PassThru
    )

    if($URI.AbsolutePath -notlike '*.json'){
        Write-Error "Expected json URI"
        return
    }

    $schema = Invoke-WebRequest $URI |% Content |ConvertFrom-Json
    $commands = @()
    $verbs = 'Add','Find','Get','Update','Remove','New'
    $verbTranslations = @{
        'Delete' = 'Remove'
        'Create' = 'New'
        'Login'  = 'Connect'
        'Logout' = 'Disconnect'
        'Upload' = 'Send'
        'Place'  = 'Submit'
    }

    foreach($endpoint in $schema.paths.psobject.Properties)
    {
        $epUri = $endpoint.Name
        foreach($op in $endpoint.Value.psobject.Properties){
            $opVerb = $op.Name
            $opId = $op.Value.operationId
            $cmdVerb = $verbs |Sort-Object -Descending -Unique |Where-Object {$opId -like "$_*"} |Select-Object -First 1
            $cmdNoun = $opId -replace "^$cmdVerb"
            if(-not $cmdVerb){
                $cmdVerbTranslation = $verbTranslations.GetEnumerator()|Sort-Object Name -Descending -Unique |Where-Object {$opId -like "$($_.Name)*"} |Select-Object -First 1
                if(-not $cmdVerbTranslation){
                    Write-Warning "No verb found for $opId"
                    continue
                }
                $cmdVerb = $cmdVerbTranslation.Value
                $cmdNoun = $opId -replace "^$($cmdVerbTranslation.Key)"
            }
            $cmdVerb = [cultureinfo]::InvariantCulture.TextInfo.ToTitleCase($cmdVerb)

            $CmdletBinding = '  [CmdletBinding()]'
            $ParamBlock = @"
  param(
$($('    [Parameter(Mandatory)][uri]$BaseUri';if($op.Value.parameters){$op.Value.parameters |%{$s='    [Parameter({0})]'-f$(if($_.in -eq 'Path'){''}else{'Mandatory'}); if($_.schema.type){$s += "[$($_.schema.Type-replace'(?<=int)eger')]"}; $s+='${0}'-f $_.Name;$s}};$(if($opVerb -in 'put','post'){$b=$true;'    [Parameter(Mandatory)]$Body'}))-join",`r`n")
  )
"@
            $relUri = $epUri -replace '\{([^{}}]+)\}','$${$1}'
            $body = @"
  `$params = @{ Method = '$($opVerb.ToUpper())'$(if($b){'; Body = $Body}'}else{'}'})
  `$uri = [uri]::new(`$BaseUri, "`${OASServer}$relUri")
  Write-Host "`$uri" "`$(`$params|oss)"
"@

            $endpointCmd = "function $cmdVerb-$cmdNoun","{", $CmdletBinding,$ParamBlock,$body,"}" -join"`r`n"
            $commands += $endpointCmd
            
            Write-Host $endpointCmd
            Write-Host '' 
        }
    }
    $module = New-Module (
        [scriptblock]::Create($commands)
    )

    @{
        OASServer = $schema.servers.url |Select-Object -First 1
    }.GetEnumerator() |ForEach-Object {
        $module.SessionState.PSVariable.Set(
            [psvariable]::new(
                $_.Key, $_.Value, 'ReadOnly'
            )
        )
    }

    if($PassThru){
        return $module
    }
}
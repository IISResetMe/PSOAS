# PSOAS

OAS 3.0 client generator in pure PowerShell

## Why PSOAS?

OpenAPI/Swagger is a popular set of open specifications for designing, exposing and consuming web APIs. Unfortunately most of the official tooling depends on Node.js, and javascript is the last thing I want running in my shell. Hence this module.

## Usage 

```powershell
# Import PSOAS
Import-Module PSOAS

# Generate PowerShell client module for the petstore sample API
$PetStoreModule = New-SwaggerModule 'https://petstore3.swagger.io/api/v3/openapi.json' -Prefix PetStore

# Either Import and use in current session
Import-Module $PetStoreModule
$PSDefaultParameterValues['*-PetStore*:BaseUri'] = 'https://petstore3.swagger.io'
Connect-PetStoreUser
Find-PetsById -Id 123

# Or save for consumption elsewhere
Save-Module $PetStoreModule -Path C:\path\to\exported\PetStoreSwaggerModule.psm1
```
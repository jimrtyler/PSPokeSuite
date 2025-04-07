# PSPokemon.psd1
@{
    RootModule = 'PSPokemon.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'c7e6dfb2-8c12-4eb3-8d4c-c5a325e047e2'
    Author = 'Jim Tyler'
    CompanyName = '@PowerShellEngineer'
    Copyright = '(c) 2025 Your Name. All rights reserved.'
    Description = 'PowerShell module for accessing Pokemon data from various Pokemon APIs'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Set-PSPokemonAPIKey',
        'Set-PSPokemonDefaultSource',
        'Set-PSPokemonAuthRequirement',
        'Set-PSPokemonCacheOption',
        'Get-Pokemon',
        'Get-PokemonSpecies',
        'Get-PokemonEvolutionChain',
        'Get-PokemonImage'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Pokemon', 'API', 'PokeAPI', 'PokemonTCG', 'Gaming')
            LicenseUri = 'https://github.com/YourUsername/PSPokemon/blob/main/LICENSE'
            ProjectUri = 'https://github.com/YourUsername/PSPokemon'
            ReleaseNotes = 'Initial release of PSPokemon module'
        }
    }
}
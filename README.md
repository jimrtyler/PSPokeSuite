# PSPokemon

PSPokemon is a PowerShell module for accessing Pokémon data from various API sources. Built on the PoshAPI framework, it provides a unified interface to retrieve information about Pokémon from different providers.

## Features

- Query Pokémon data by name or ID
- Access detailed species information
- Retrieve evolution chains
- Download Pokémon images
- Multi-source support (PokeAPI, PokeAPIGraphQL, PokemonTCG, PokemonShowdown)
- Built-in caching system to reduce API calls

## Installation

```powershell
# Clone the repository
git clone https://github.com/JimRTyler/PSPokemon.git

# Import the module
Import-Module .\PSPokemon\PSPokemon.psd1
```

## API Sources

PSPokemon supports the following API sources:

1. **PokeAPI** - The main RESTful API for Pokémon data (https://pokeapi.co/)
2. **PokeAPIGraphQL** - The GraphQL version of PokeAPI (beta)
3. **PokemonTCG** - The Pokémon Trading Card Game API (https://pokemontcg.io/)
4. **PokemonShowdown** - The Pokémon Showdown API for competitive play data

## Basic Usage

### Getting Pokémon Data

```powershell
# Get Pokémon by name
Get-Pokemon -NameOrId "pikachu"

# Get Pokémon by ID number
Get-Pokemon -NameOrId 25

# Get Pokémon from a specific source
Get-Pokemon -Source "PokeAPI" -NameOrId "charizard"

# Get Pokémon by type
Get-Pokemon -Type "fire"

# Bypass cache for fresh data
Get-Pokemon -NameOrId "bulbasaur" -SkipCache
```

### Getting Detailed Species Information

```powershell
# Get species details
Get-PokemonSpecies -NameOrId "eevee"
```

### Retrieving Evolution Chains

```powershell
# Get evolution information
Get-PokemonEvolutionChain -NameOrId "charmander"
```

### Downloading Pokémon Images

```powershell
# Get official artwork URL
Get-PokemonImage -PokemonId 25

# Download sprite to file
Get-PokemonImage -PokemonId "pikachu" -ImageType "front_shiny" -OutputPath "C:\Temp\pikachu_shiny.png"

# Available image types:
# - official-artwork (default)
# - front_default
# - front_shiny
# - front_female
# - front_shiny_female
# - back_default
# - back_shiny
# - back_female
# - back_shiny_female
```

## Configuration Settings

### Setting API Keys (for services that require them)

```powershell
# Set API key for PokemonTCG API
Set-PSPokemonAPIKey -Source "PokemonTCG" -ApiKey "your-api-key-here"
```

### Changing Default Source

```powershell
# Set the default API source
Set-PSPokemonDefaultSource -Source "PokeAPI"
```

### Managing Authentication Requirements

```powershell
# PokeAPI doesn't require authentication (already configured by default)
Set-PSPokemonAuthRequirement -Source "PokeAPI" -RequiresAuthentication $false
```

### Configuring Cache Settings

```powershell
# Enable or disable caching
Set-PSPokemonCacheOption -Enabled $true

# Set cache expiration time (in seconds)
Set-PSPokemonCacheOption -ExpirationSeconds 3600  # 1 hour
```

## Examples

### Example 1: Get Bulbasaur's Data and Evolution Chain

```powershell
# Get basic Pokémon data
$bulbasaur = Get-Pokemon -NameOrId "bulbasaur"
$bulbasaur | Format-List Id, Name, Types, Abilities

# Get full evolution chain
$evoChain = Get-PokemonEvolutionChain -NameOrId "bulbasaur"
$evoChain.Species
```

### Example 2: Find All Legendary Pokémon of Dragon Type

```powershell
# Get dragon type Pokémon
$dragonTypes = Get-Pokemon -Type "dragon"

# Filter for legendary Pokémon
$dragonTypes | ForEach-Object {
    $species = Get-PokemonSpecies -NameOrId $_.Id
    if ($species.IsLegendary) {
        [PSCustomObject]@{
            Id = $_.Id
            Name = $_.Name
            IsLegendary = $species.IsLegendary
            Generation = $species.Generation
        }
    }
}
```

### Example 3: Download Sprites for the Original Starters

```powershell
$starters = @("bulbasaur", "charmander", "squirtle")
$outputDir = "C:\Pokemon\Sprites"

foreach ($starter in $starters) {
    Get-PokemonImage -PokemonId $starter -OutputPath "$outputDir\$starter.png"
    Get-PokemonImage -PokemonId $starter -ImageType "front_shiny" -OutputPath "$outputDir\${starter}_shiny.png"
}
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [PokeAPI](https://pokeapi.co/) for providing the comprehensive Pokémon data
- [PokemonTCG API](https://pokemontcg.io/) for trading card game data
- Based on the PoshAPI template for PowerShell API modules

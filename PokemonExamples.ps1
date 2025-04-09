# Import the module
Import-Module .\PSPokeSuite.psd1

# Example 1: Basic Pokémon information retrieval
Write-Host "Getting information for Pikachu..." -ForegroundColor Yellow
$pikachu = Get-Pokemon -NameOrId "pikachu"

# Display basic information
Write-Host "`nBasic Pikachu Information:" -ForegroundColor Cyan
Write-Host "------------------------"
Write-Host "ID: $($pikachu.Id)"
Write-Host "Name: $($pikachu.Name)"
Write-Host "Height: $($pikachu.Height) m"
Write-Host "Weight: $($pikachu.Weight) kg"
Write-Host "Types: $($pikachu.Types -join ', ')"
Write-Host "Abilities: $($pikachu.Abilities -join ', ')"

# Display stats
Write-Host "`nStats:" -ForegroundColor Cyan
Write-Host "------"
foreach ($stat in $pikachu.Stats) {
    Write-Host "$($stat.Name): $($stat.Value)"
}

# Example 2: Get species information
Write-Host "`nGetting species information for Pikachu..." -ForegroundColor Yellow
$pikachuSpecies = Get-PokemonSpecies -NameOrId "pikachu"

Write-Host "`nPikachu Species Information:" -ForegroundColor Cyan
Write-Host "----------------------------"
Write-Host "Generation: $($pikachuSpecies.Generation)"
Write-Host "Color: $($pikachuSpecies.Color)"
Write-Host "Habitat: $($pikachuSpecies.Habitat)"
Write-Host "Growth Rate: $($pikachuSpecies.GrowthRate)"
Write-Host "Capture Rate: $($pikachuSpecies.CaptureRate)"
Write-Host "Base Happiness: $($pikachuSpecies.BaseHappiness)"
Write-Host "Is Baby: $($pikachuSpecies.IsBaby)"
Write-Host "Is Legendary: $($pikachuSpecies.IsLegendary)"
Write-Host "Is Mythical: $($pikachuSpecies.IsMythical)"

# Display egg groups
Write-Host "`nEgg Groups:" -ForegroundColor Cyan
Write-Host "----------"
foreach ($eggGroup in $pikachuSpecies.EggGroups) {
    Write-Host "- $eggGroup"
}

# Display a flavor text entry
Write-Host "`nPokédex Entry:" -ForegroundColor Cyan
Write-Host "-------------"
Write-Host $pikachuSpecies.FlavorTexts[0]

# Example 3: Get evolution chain
Write-Host "`nGetting evolution chain for Pikachu..." -ForegroundColor Yellow
$evoChain = Get-PokemonEvolutionChain -NameOrId "pikachu"

# Helper function to recursively display evolution chain
function Show-EvolutionChain {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Species,
        
        [Parameter(Mandatory = $false)]
        [int]$Level = 0
    )
    
    $indent = "  " * $Level
    Write-Host "$indent→ $($Species.Name)" -ForegroundColor Green
    
    foreach ($evolution in $Species.EvolvesTo) {
        $evoDetails = $evolution.EvolutionDetails[0]
        $method = ""
        
        if ($evoDetails.trigger.name -eq "level-up") {
            if ($evoDetails.min_level) {
                $method = "Level $($evoDetails.min_level)"
            } elseif ($evoDetails.min_happiness) {
                $method = "Happiness: $($evoDetails.min_happiness)"
            } elseif ($evoDetails.item) {
                $method = "Use $($evoDetails.item.name)"
            } elseif ($evoDetails.known_move) {
                $method = "Learn $($evoDetails.known_move.name)"
            } elseif ($evoDetails.location) {
                $method = "At $($evoDetails.location.name)"
            } elseif ($evoDetails.time_of_day) {
                $method = "During $($evoDetails.time_of_day)"
            }
        } elseif ($evoDetails.trigger.name -eq "use-item") {
            $method = "Use $($evoDetails.item.name)"
        } elseif ($evoDetails.trigger.name -eq "trade") {
            $method = "Trade"
            if ($evoDetails.held_item) {
                $method += " (holding $($evoDetails.held_item.name))"
            }
        }
        
        if ($method) {
            Write-Host "$indent  ($method)" -ForegroundColor Gray
        }
        
        Show-EvolutionChain -Species $evolution -Level ($Level + 1)
    }
}

Write-Host "`nEvolution Chain:" -ForegroundColor Cyan
Write-Host "---------------"
Show-EvolutionChain -Species $evoChain.Species

# Example 4: Get Pokémon image
Write-Host "`nGetting Pikachu image..." -ForegroundColor Yellow
$imageUrl = Get-PokemonImage -PokemonId "pikachu"
Write-Host "Image URL: $imageUrl"

# Example 5: Find Pokémon by type
Write-Host "`nGetting Fire-type Pokémon (first 5)..." -ForegroundColor Yellow
$fireTypes = Get-Pokemon -Type "fire" | Select-Object -First 5

Write-Host "`nFire-type Pokémon:" -ForegroundColor Cyan
Write-Host "----------------"
foreach ($pokemon in $fireTypes) {
    Write-Host "$($pokemon.Id): $($pokemon.Name)"
}

# Example 6: Get a Pokémon card
Write-Host "`nGetting a Pikachu card from PokemonTCG API..." -ForegroundColor Yellow
# Note: This might require an API key
try {
    $pikachuCard = Get-Pokemon -Source "PokemonTCG" -NameOrId "pikachu" | Select-Object -First 1
    
    Write-Host "`nPikachu Card Information:" -ForegroundColor Cyan
    Write-Host "------------------------"
    Write-Host "Name: $($pikachuCard.Name)"
    Write-Host "ID: $($pikachuCard.Id)"
    Write-Host "Set: $($pikachuCard.Set)"
    Write-Host "Number: $($pikachuCard.Number)"
    Write-Host "Rarity: $($pikachuCard.Rarity)"
    Write-Host "HP: $($pikachuCard.HP)"
    Write-Host "Types: $($pikachuCard.Types -join ', ')"
} catch {
    Write-Host "Could not retrieve card information. You might need to set up an API key." -ForegroundColor Red
    Write-Host "Use: Set-PSPokemonAPIKey -Source 'PokemonTCG' -ApiKey 'your-api-key'" -ForegroundColor Yellow
}

# Example 7: Configure caching
Write-Host "`nConfiguring cache settings..." -ForegroundColor Yellow
Set-PSPokemonCacheOption -Enabled $true -ExpirationSeconds 3600
Write-Host "Cache enabled with 1 hour expiration."

# Example 8: Compare same Pokémon from different sources
Write-Host "`nComparing Charizard data from different sources..." -ForegroundColor Yellow

try {
    $charizardPokeAPI = Get-Pokemon -Source "PokeAPI" -NameOrId "charizard"
    $charizardGraphQL = Get-Pokemon -Source "PokeAPIGraphQL" -NameOrId "charizard"
    
    Write-Host "`nCharizard from PokeAPI:" -ForegroundColor Cyan
    Write-Host "ID: $($charizardPokeAPI.Id)"
    Write-Host "Types: $($charizardPokeAPI.Types -join ', ')"
    
    Write-Host "`nCharizard from GraphQL API:" -ForegroundColor Cyan
    Write-Host "ID: $($charizardGraphQL[0].Id)"
    Write-Host "Types: $($charizardGraphQL[0].Types -join ', ')"
} catch {
    Write-Host "Could not compare data from multiple sources. Some sources might need authentication." -ForegroundColor Red
}

Write-Host "`nDemonstration Complete!" -ForegroundColor Green
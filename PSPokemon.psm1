# PSPokemon.psm1

# Module variables
$script:ConfigPath = Join-Path -Path $env:USERPROFILE -ChildPath '.pspokemon'
$script:ConfigFile = Join-Path -Path $script:ConfigPath -ChildPath 'config.json'
$script:APISourceNames = @('PokeAPI', 'PokeAPIGraphQL', 'PokemonTCG', 'PokemonShowdown')

#region Helper Functions

function Initialize-Configuration {
    [CmdletBinding()]
    param()
    
    if (-not (Test-Path -Path $script:ConfigPath)) {
        New-Item -Path $script:ConfigPath -ItemType Directory -Force | Out-Null
    }
    
    if (-not (Test-Path -Path $script:ConfigFile)) {
        $defaultConfig = @{
            DefaultSource = $script:APISourceNames[0]
            ApiKeys = @{}
            RequiresAuth = @{}
            CacheEnabled = $true
            CacheExpiration = 86400  # 24 hours in seconds
        }
        
        $script:APISourceNames | ForEach-Object {
            $defaultConfig.ApiKeys[$_] = ''
            # Set PokeAPI to not require authentication
            if ($_ -eq 'PokeAPI') {
                $defaultConfig.RequiresAuth[$_] = $false
            } else {
                $defaultConfig.RequiresAuth[$_] = $true
            }
        }
        
        $defaultConfig | ConvertTo-Json | Out-File -FilePath $script:ConfigFile -Force
    }
}

function Get-Configuration {
    [CmdletBinding()]
    param()
    
    if (-not (Test-Path -Path $script:ConfigFile)) {
        Initialize-Configuration
    }
    
    Get-Content -Path $script:ConfigFile -Raw | ConvertFrom-Json
}

function Set-Configuration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Config
    )
    
    $Config | ConvertTo-Json | Out-File -FilePath $script:ConfigFile -Force
}

function Get-CachedData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key
    )
    
    $config = Get-Configuration
    if (-not $config.CacheEnabled) {
        return $null
    }
    
    $cachePath = Join-Path -Path $script:ConfigPath -ChildPath 'cache'
    $cacheFile = Join-Path -Path $cachePath -ChildPath "$Key.json"
    
    if (-not (Test-Path -Path $cacheFile)) {
        return $null
    }
    
    $cacheData = Get-Content -Path $cacheFile -Raw | ConvertFrom-Json
    $expirationTime = [DateTime]::Parse($cacheData.ExpirationTime)
    
    if ([DateTime]::Now -gt $expirationTime) {
        # Cache expired
        Remove-Item -Path $cacheFile -Force
        return $null
    }
    
    return $cacheData.Data
}

function Set-CachedData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,
        
        [Parameter(Mandatory = $true)]
        [object]$Data
    )
    
    $config = Get-Configuration
    if (-not $config.CacheEnabled) {
        return
    }
    
    $cachePath = Join-Path -Path $script:ConfigPath -ChildPath 'cache'
    if (-not (Test-Path -Path $cachePath)) {
        New-Item -Path $cachePath -ItemType Directory -Force | Out-Null
    }
    
    $cacheFile = Join-Path -Path $cachePath -ChildPath "$Key.json"
    $expirationTime = [DateTime]::Now.AddSeconds($config.CacheExpiration)
    
    $cacheData = @{
        ExpirationTime = $expirationTime.ToString('o')
        Data = $Data
    }
    
    $cacheData | ConvertTo-Json -Depth 10 | Out-File -Path $cacheFile -Force
}

function Invoke-ApiRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        
        [Parameter(Mandatory = $true)]
        [string]$Endpoint,
        
        [Parameter(Mandatory = $false)]
        [string]$Method = 'GET',
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Headers = @{},
        
        [Parameter(Mandatory = $false)]
        [hashtable]$QueryParameters = @{},
        
        [Parameter(Mandatory = $false)]
        [object]$Body,
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipCache
    )
    
    $config = Get-Configuration
    
    # Check if this source requires authentication
    $requiresAuth = $config.RequiresAuth.$Source
    $apiKey = $config.ApiKeys.$Source
    
    # Only validate API key if authentication is required
    if ($requiresAuth -eq $true -and [string]::IsNullOrEmpty($apiKey)) {
        throw "API key for $Source is not configured. Please use Set-PSPokemonAPIKey -Source $Source -ApiKey <your-api-key>"
    }
    
    # Define base URLs for each source
    $baseUrls = @{
        'PokeAPI' = 'https://pokeapi.co/api/v2'
        'PokeAPIGraphQL' = 'https://beta.pokeapi.co/graphql/v1beta'
        'PokemonTCG' = 'https://api.pokemontcg.io/v2'
        'PokemonShowdown' = 'https://pokemonshowdown.com/api'
    }
    
    # Add API key to headers or query parameters based on the source (if authentication is required)
    if ($requiresAuth -eq $true) {
        switch ($Source) {
            'PokeAPIGraphQL' { $Headers['Authorization'] = "Bearer $apiKey" }
            'PokemonTCG' { $Headers['X-Api-Key'] = $apiKey }
            'PokemonShowdown' { $QueryParameters['api_key'] = $apiKey }
        }
    }
    
    $uri = "$($baseUrls[$Source])/$Endpoint"
    
    # Check cache for GET requests if caching is enabled and not explicitly skipped
    $cacheKey = $null
    if ($Method -eq 'GET' -and -not $SkipCache) {
        $cacheKey = "$Source-$uri-$($QueryParameters | ConvertTo-Json -Compress)"
        $cachedData = Get-CachedData -Key ($cacheKey | Get-Hash)
        if ($cachedData) {
            return $cachedData
        }
    }
    
    # Build query string if parameters are provided
    if ($QueryParameters.Count -gt 0) {
        $queryString = [System.Web.HttpUtility]::ParseQueryString([string]::Empty)
        foreach ($param in $QueryParameters.GetEnumerator()) {
            $queryString.Add($param.Key, $param.Value)
        }
        $uriBuilder = New-Object System.UriBuilder($uri)
        $uriBuilder.Query = $queryString.ToString()
        $uri = $uriBuilder.Uri.ToString()
    }
    
    $params = @{
        Uri     = $uri
        Method  = $Method
        Headers = $Headers
    }
    
    # Add body if provided
    if ($Body) {
        $params['Body'] = if ($Body -is [hashtable] -or $Body -is [PSCustomObject]) {
            $Body | ConvertTo-Json -Depth 5
        } else {
            $Body
        }
        
        # Default content type if not specified
        if (-not $Headers.ContainsKey('Content-Type')) {
            $params.Headers['Content-Type'] = 'application/json'
        }
    }
    
    try {
        $response = Invoke-RestMethod @params
        
        # Cache the response for GET requests
        if ($Method -eq 'GET' -and -not $SkipCache -and $cacheKey) {
            Set-CachedData -Key ($cacheKey | Get-Hash) -Data $response
        }
        
        return $response
    }
    catch {
        Write-Error "API request failed: $_"
        throw $_
    }
}

function Get-Hash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$InputString
    )
    
    process {
        $stringAsStream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($InputString))
        $hash = Get-FileHash -InputStream $stringAsStream -Algorithm MD5
        return $hash.Hash
    }
}

#endregion

#region Public Functions

function Set-PSPokemonAPIKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('PokeAPI', 'PokeAPIGraphQL', 'PokemonTCG', 'PokemonShowdown')]
        [string]$Source,
        
        [Parameter(Mandatory = $true)]
        [string]$ApiKey
    )
    
    $config = Get-Configuration
    $config.ApiKeys[$Source] = $ApiKey
    Set-Configuration -Config $config
    
    Write-Output "API key for $Source has been set."
}

function Set-PSPokemonDefaultSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('PokeAPI', 'PokeAPIGraphQL', 'PokemonTCG', 'PokemonShowdown')]
        [string]$Source
    )
    
    $config = Get-Configuration
    $config.DefaultSource = $Source
    Set-Configuration -Config $config
    
    Write-Output "Default API source set to $Source."
}

function Set-PSPokemonAuthRequirement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('PokeAPI', 'PokeAPIGraphQL', 'PokemonTCG', 'PokemonShowdown')]
        [string]$Source,
        
        [Parameter(Mandatory = $true)]
        [bool]$RequiresAuthentication
    )
    
    $config = Get-Configuration
    
    # Create RequiresAuth property if it doesn't exist
    if (-not $config.PSObject.Properties.Name -contains 'RequiresAuth') {
        $config | Add-Member -MemberType NoteProperty -Name 'RequiresAuth' -Value @{}
    }
    
    $config.RequiresAuth[$Source] = $RequiresAuthentication
    Set-Configuration -Config $config
    
    if ($RequiresAuthentication) {
        Write-Output "Authentication requirement for $Source has been set to REQUIRED."
    } else {
        Write-Output "Authentication requirement for $Source has been set to NOT REQUIRED."
    }
}

function Set-PSPokemonCacheOption {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$Enabled,
        
        [Parameter(Mandatory = $false)]
        [int]$ExpirationSeconds
    )
    
    $config = Get-Configuration
    
    if ($PSBoundParameters.ContainsKey('Enabled')) {
        $config.CacheEnabled = $Enabled
    }
    
    if ($PSBoundParameters.ContainsKey('ExpirationSeconds')) {
        $config.CacheExpiration = $ExpirationSeconds
    }
    
    Set-Configuration -Config $config
    
    Write-Output "Cache settings updated. Enabled: $($config.CacheEnabled), Expiration: $($config.CacheExpiration) seconds"
}

function Get-Pokemon {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('PokeAPI', 'PokeAPIGraphQL', 'PokemonTCG', 'PokemonShowdown')]
        [string]$Source,
        
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByNameOrId')]
        [string]$NameOrId,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'ByType')]
        [string]$Type,
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipCache
    )
    
    if (-not $Source) {
        $config = Get-Configuration
        $Source = $config.DefaultSource
    }
    
    # Define endpoint and parameters based on the source and parameter set
    switch ($Source) {
        'PokeAPI' {
            if ($PSCmdlet.ParameterSetName -eq 'ByNameOrId') {
                # Convert name to lowercase for PokeAPI
                $NameOrId = $NameOrId.ToLower()
                $endpoint = "pokemon/$NameOrId"
                $response = Invoke-ApiRequest -Source $Source -Endpoint $endpoint -SkipCache:$SkipCache
                return Format-PokemonResponse -Source $Source -Response $response
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'ByType') {
                $Type = $Type.ToLower()
                $endpoint = "type/$Type"
                $response = Invoke-ApiRequest -Source $Source -Endpoint $endpoint -SkipCache:$SkipCache
                
                # For type search, we need to get details for each Pokemon
                $pokemonList = New-Object System.Collections.ArrayList
                
                foreach ($pokemonEntry in $response.pokemon) {
                    $pokemonUrl = $pokemonEntry.pokemon.url
                    $pokemonId = $pokemonUrl -replace '.+/(\d+)/$', '$1'
                    
                    $pokemonDetails = Invoke-ApiRequest -Source $Source -Endpoint "pokemon/$pokemonId" -SkipCache:$SkipCache
                    $formattedPokemon = Format-PokemonResponse -Source $Source -Response $pokemonDetails
                    [void]$pokemonList.Add($formattedPokemon)
                }
                
                return $pokemonList
            }
        }
        'PokeAPIGraphQL' {
            # GraphQL query for Pokemon by name or ID
            if ($PSCmdlet.ParameterSetName -eq 'ByNameOrId') {
                $isNumber = $NameOrId -match '^\d+$'
                
                if ($isNumber) {
                    $query = @"
{
  pokemon_v2_pokemon(where: {id: {_eq: $NameOrId}}) {
    id
    name
    height
    weight
    pokemon_v2_pokemontypes {
      pokemon_v2_type {
        name
      }
    }
    pokemon_v2_pokemonabilities {
      pokemon_v2_ability {
        name
      }
    }
    pokemon_v2_pokemonstats {
      base_stat
      pokemon_v2_stat {
        name
      }
    }
  }
}
"@
                } else {
                    $nameToSearch = $NameOrId.ToLower()
                    $query = @"
{
  pokemon_v2_pokemon(where: {name: {_eq: "$nameToSearch"}}) {
    id
    name
    height
    weight
    pokemon_v2_pokemontypes {
      pokemon_v2_type {
        name
      }
    }
    pokemon_v2_pokemonabilities {
      pokemon_v2_ability {
        name
      }
    }
    pokemon_v2_pokemonstats {
      base_stat
      pokemon_v2_stat {
        name
      }
    }
  }
}
"@
                }
                
                $body = @{
                    query = $query
                }
                
                $response = Invoke-ApiRequest -Source $Source -Endpoint "" -Method POST -Body $body -SkipCache:$SkipCache
                return Format-PokemonResponse -Source $Source -Response $response
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'ByType') {
                $typeToSearch = $Type.ToLower()
                $query = @"
{
  pokemon_v2_pokemon(where: {pokemon_v2_pokemontypes: {pokemon_v2_type: {name: {_eq: "$typeToSearch"}}}}) {
    id
    name
    height
    weight
    pokemon_v2_pokemontypes {
      pokemon_v2_type {
        name
      }
    }
    pokemon_v2_pokemonabilities {
      pokemon_v2_ability {
        name
      }
    }
    pokemon_v2_pokemonstats {
      base_stat
      pokemon_v2_stat {
        name
      }
    }
  }
}
"@
                
                $body = @{
                    query = $query
                }
                
                $response = Invoke-ApiRequest -Source $Source -Endpoint "" -Method POST -Body $body -SkipCache:$SkipCache
                return Format-PokemonResponse -Source $Source -Response $response
            }
        }
        'PokemonTCG' {
            if ($PSCmdlet.ParameterSetName -eq 'ByNameOrId') {
                # Check if ID format (e.g., sm1-1)
                if ($NameOrId -match '^[a-z0-9]+-\d+$') {
                    $endpoint = "cards/$NameOrId"
                    $response = Invoke-ApiRequest -Source $Source -Endpoint $endpoint -SkipCache:$SkipCache
                } else {
                    # Search by name
                    $endpoint = "cards"
                    $queryParams = @{
                        q = "name:$NameOrId"
                    }
                    $response = Invoke-ApiRequest -Source $Source -Endpoint $endpoint -QueryParameters $queryParams -SkipCache:$SkipCache
                }
                return Format-PokemonResponse -Source $Source -Response $response
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'ByType') {
                $endpoint = "cards"
                $queryParams = @{
                    q = "types:$Type"
                }
                $response = Invoke-ApiRequest -Source $Source -Endpoint $endpoint -QueryParameters $queryParams -SkipCache:$SkipCache
                return Format-PokemonResponse -Source $Source -Response $response
            }
        }
        'PokemonShowdown' {
            # PokemonShowdown has limited API capabilities
            if ($PSCmdlet.ParameterSetName -eq 'ByNameOrId') {
                $endpoint = "data/pokemon/$($NameOrId.ToLower())"
                $response = Invoke-ApiRequest -Source $Source -Endpoint $endpoint -SkipCache:$SkipCache
                return Format-PokemonResponse -Source $Source -Response $response
            }
            else {
                Write-Error "Searching by type is not supported for PokemonShowdown API."
            }
        }
    }
}

function Format-PokemonResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        
        [Parameter(Mandatory = $true)]
        [object]$Response
    )
    
    switch ($Source) {
        'PokeAPI' {
            # Transform PokeAPI response to a standard format
            $pokemon = [PSCustomObject]@{
                Id = $Response.id
                Name = $Response.name
                Height = $Response.height / 10  # Convert to meters
                Weight = $Response.weight / 10  # Convert to kilograms
                Types = $Response.types | ForEach-Object { $_.type.name }
                Abilities = $Response.abilities | ForEach-Object { $_.ability.name }
                Stats = $Response.stats | ForEach-Object {
                    [PSCustomObject]@{
                        Name = $_.stat.name
                        Value = $_.base_stat
                    }
                }
                Source = 'PokeAPI'
                OriginalData = $Response
            }
            return $pokemon
        }
        'PokeAPIGraphQL' {
            # Transform GraphQL response
            if ($Response.data.pokemon_v2_pokemon.Count -gt 0) {
                $pokemonList = $Response.data.pokemon_v2_pokemon | ForEach-Object {
                    $pokemon = $_
                    [PSCustomObject]@{
                        Id = $pokemon.id
                        Name = $pokemon.name
                        Height = $pokemon.height / 10  # Convert to meters
                        Weight = $pokemon.weight / 10  # Convert to kilograms
                        Types = $pokemon.pokemon_v2_pokemontypes | ForEach-Object { $_.pokemon_v2_type.name }
                        Abilities = $pokemon.pokemon_v2_pokemonabilities | ForEach-Object { $_.pokemon_v2_ability.name }
                        Stats = $pokemon.pokemon_v2_pokemonstats | ForEach-Object {
                            [PSCustomObject]@{
                                Name = $_.pokemon_v2_stat.name
                                Value = $_.base_stat
                            }
                        }
                        Source = 'PokeAPIGraphQL'
                        OriginalData = $pokemon
                    }
                }
                return $pokemonList
            } else {
                Write-Warning "No Pokemon found in the GraphQL response."
                return $null
            }
        }
        'PokemonTCG' {
            # Transform Pokemon TCG API response
            if ($Response.data) {
                $pokemonList = $Response.data | ForEach-Object {
                    $card = $_
                    [PSCustomObject]@{
                        Id = $card.id
                        Name = $card.name
                        Set = $card.set.name
                        Number = $card.number
                        Types = $card.types
                        Rarity = $card.rarity
                        HP = [int]($card.hp)
                        Source = 'PokemonTCG'
                        OriginalData = $card
                    }
                }
                return $pokemonList
            } elseif ($Response.card) {
                # Single card response
                $card = $Response.card
                return [PSCustomObject]@{
                    Id = $card.id
                    Name = $card.name
                    Set = $card.set.name
                    Number = $card.number
                    Types = $card.types
                    Rarity = $card.rarity
                    HP = [int]($card.hp)
                    Source = 'PokemonTCG'
                    OriginalData = $card
                }
            } else {
                Write-Warning "No Pokemon cards found in the response."
                return $null
            }
        }
        'PokemonShowdown' {
            # Transform Pokemon Showdown API response
            if ($Response) {
                return [PSCustomObject]@{
                    Id = $Response.num
                    Name = $Response.species
                    Types = $Response.types
                    Abilities = $Response.abilities
                    BaseStats = [PSCustomObject]@{
                        HP = $Response.baseStats.hp
                        Attack = $Response.baseStats.atk
                        Defense = $Response.baseStats.def
                        SpecialAttack = $Response.baseStats.spa
                        SpecialDefense = $Response.baseStats.spd
                        Speed = $Response.baseStats.spe
                    }
                    Source = 'PokemonShowdown'
                    OriginalData = $Response
                }
            } else {
                Write-Warning "No Pokemon found in the Showdown response."
                return $null
            }
        }
    }
}

function Get-PokemonSpecies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('PokeAPI')]
        [string]$Source = 'PokeAPI',
        
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$NameOrId,
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipCache
    )
    
    # PokeAPI is the only supported source for species information
    if ($Source -ne 'PokeAPI') {
        Write-Error "Only PokeAPI supports detailed species information."
        return
    }
    
    # Convert name to lowercase for PokeAPI
    $NameOrId = $NameOrId.ToLower()
    $endpoint = "pokemon-species/$NameOrId"
    
    $response = Invoke-ApiRequest -Source $Source -Endpoint $endpoint -SkipCache:$SkipCache
    
    # Format species response
    $speciesInfo = [PSCustomObject]@{
        Id = $response.id
        Name = $response.name
        Generation = $response.generation.name
        IsBaby = $response.is_baby
        IsLegendary = $response.is_legendary
        IsMythical = $response.is_mythical
        GrowthRate = $response.growth_rate.name
        Color = $response.color.name
        Habitat = $response.habitat.name
        Shape = $response.shape.name
        BaseHappiness = $response.base_happiness
        CaptureRate = $response.capture_rate
        EggGroups = $response.egg_groups | ForEach-Object { $_.name }
        FlavorTexts = $response.flavor_text_entries | 
            Where-Object { $_.language.name -eq 'en' } | 
            Select-Object -ExpandProperty flavor_text
        Genera = $response.genera | 
            Where-Object { $_.language.name -eq 'en' } | 
            Select-Object -ExpandProperty genus
        EvolutionChainUrl = $response.evolution_chain.url
        Source = 'PokeAPI'
        OriginalData = $response
    }
    
    return $speciesInfo
}

function Get-PokemonEvolutionChain {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('PokeAPI')]
        [string]$Source = 'PokeAPI',
        
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$NameOrId,
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipCache
    )
    
    # First, get the species data to find the evolution chain URL
    $species = Get-PokemonSpecies -Source $Source -NameOrId $NameOrId -SkipCache:$SkipCache
    
    # Extract evolution chain ID from URL
    $evolutionChainId = $species.EvolutionChainUrl -replace '.+/(\d+)/$', '$1'
    $endpoint = "evolution-chain/$evolutionChainId"
    
    $response = Invoke-ApiRequest -Source $Source -Endpoint $endpoint -SkipCache:$SkipCache
    
    # Process the evolution chain
    $evolutionData = [PSCustomObject]@{
        Id = $response.id
        Species = @()
        Source = 'PokeAPI'
        OriginalData = $response
    }
    
    # Recursive function to process the chain
    function Process-EvolutionChain {
        param(
            [Parameter(Mandatory = $true)]
            [object]$Chain
        )
        
        $speciesInfo = [PSCustomObject]@{
            Name = $Chain.species.name
            EvolvesTo = @()
            EvolutionDetails = $Chain.evolution_details
        }
        
        foreach ($evolution in $Chain.evolves_to) {
            $speciesInfo.EvolvesTo += (Process-EvolutionChain -Chain $evolution)
        }
        
        return $speciesInfo
    }
    
    $evolutionData.Species = Process-EvolutionChain -Chain $response.chain
    
    return $evolutionData
}

function Get-PokemonImage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$PokemonId,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('front_default', 'front_shiny', 'front_female', 'front_shiny_female', 
                     'back_default', 'back_shiny', 'back_female', 'back_shiny_female', 'official-artwork')]
        [string]$ImageType = 'official-artwork',
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$SkipCache
    )
    
    # Get Pokemon data to find sprite URLs
    $pokemon = Get-Pokemon -Source 'PokeAPI' -NameOrId $PokemonId -SkipCache:$SkipCache
    
    $imageUrl = $null
    
    if ($ImageType -eq 'official-artwork') {
        $imageUrl = $pokemon.OriginalData.sprites.other.'official-artwork'.front_default
    } else {
        $imageUrl = $pokemon.OriginalData.sprites.$ImageType
    }
    
    if (-not $imageUrl) {
        Write-Error "No image found for the specified Pokemon and image type."
        return
    }
    
    # Download the image
    try {
        if ($OutputPath) {
            # Ensure the directory exists
            $directory = Split-Path -Path $OutputPath -Parent
            if (-not [string]::IsNullOrEmpty($directory) -and -not (Test-Path -Path $directory)) {
                New-Item -Path $directory -ItemType Directory -Force | Out-Null
            }
            
            # Download image to file
            Invoke-WebRequest -Uri $imageUrl -OutFile $OutputPath
            Write-Output "Image saved to $OutputPath"
            return $OutputPath
        } else {
            # Return the image URL
            return $imageUrl
        }
    }
    catch {
        Write-Error "Failed to download or save the image: $_"
    }
}

#endregion

# Initialize module on import
Initialize-Configuration

# Export functions
Export-ModuleMember -Function @(
    'Set-PSPokemonAPIKey',
    'Set-PSPokemonDefaultSource',
    'Set-PSPokemonAuthRequirement',
    'Set-PSPokemonCacheOption',
    'Get-Pokemon',
    'Get-PokemonSpecies',
    'Get-PokemonEvolutionChain',
    'Get-PokemonImage'
)
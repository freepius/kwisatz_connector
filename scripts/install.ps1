# ============================================
# Kwisatz Connector - Bootstrap/Update Script
# ============================================
# - Télécharge l'archive GitHub (branche main)
# - Compare la somme SHA-256 à la précédente
# - Décompresse dans C:\kwisatz_connector (préserve .env si présent)
# - Lance le script d'install interne si dispo, sinon fallback générique
# - (Option) lance l'API avec uvicorn
# --------------------------------------------

# ----- Paramètres repo / chemins -----
$RepoOwner   = "freepius"
$RepoName    = "kwisatz_connector"
$Branch      = "main"
$ZipUrl      = "https://github.com/$RepoOwner/$RepoName/archive/refs/heads/$Branch.zip"

$InstallRoot = "C:\kwisatz_connector"             # Dossier d'installation cible
$TmpRoot     = "$env:TEMP\kwisatz_dl"             # Dossier temporaire
$ZipPath     = "$TmpRoot\kwisatz_connector.zip"   # Archive téléchargée
$HashFile    = "$InstallRoot\.last_download.sha256"

# ----- Fonctions utilitaires -----
function Ensure-Directory($path) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
    }
}

function Download-Archive {
    Write-Host "Téléchargement depuis $ZipUrl ..."
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing
}

function Get-FileSha256($filePath) {
    return (Get-FileHash -Algorithm SHA256 -Path $filePath).Hash
}

function Preserve-File($sourcePath, $targetPath) {
    # Ne copie PAS si la cible existe déjà (préserve .env, etc.)
    if (-not (Test-Path $targetPath)) {
        Copy-Item -Path $sourcePath -Destination $targetPath -Force
    }
}

function Copy-RepoTo-Install($extractedRoot, $installRoot) {
    # 1) Crée le dossier d'install s'il manque
    Ensure-Directory $installRoot

    # 2) Préserve .env s'il existe déjà
    $envExisting = Join-Path $installRoot ".env"
    $envTemp     = Join-Path $extractedRoot ".env"

    # 3) Copie tout le contenu extrait vers le dossier d'install
    #    -Start par effacer tout sauf .env existant (pour éviter le fouillis)
    Get-ChildItem -Path $installRoot -Force | Where-Object {
        $_.Name -ne ".env" -and $_.Name -ne ".last_download.sha256"
    } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    # Copie tous les fichiers/dossiers provenant de la racine extraite
    Get-ChildItem -Path $extractedRoot -Force | ForEach-Object {
        $dest = Join-Path $installRoot $_.Name
        Copy-Item -Path $_.FullName -Destination $dest -Recurse -Force
    }

    # 4) Si .env n’existait pas, copie celui du repo (s’il existe)
    if (-not (Test-Path $envExisting) -and (Test-Path $envTemp)) {
        Copy-Item $envTemp $envExisting -Force
    }
}

function Ensure-Python {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) {
        Write-Host "Python introuvable. Installation silencieuse en cours..."
        $installer = "$env:TEMP\python-installer.exe"
        $pyUrl     = "https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe"
        Invoke-WebRequest -Uri $pyUrl -OutFile $installer -UseBasicParsing
        Start-Process -FilePath $installer -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0" -Wait
        Remove-Item $installer -Force
        Write-Host "✅ Python installé."
    } else {
        Write-Host "✅ Python déjà présent."
    }
}

function Generic-Install($root) {
    # Active exécution script pour cette session si besoin
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -ErrorAction Stop
    } catch {}

    Push-Location $root

    # Création/activation venv
    if (-not (Test-Path ".\venv\Scripts\Activate.ps1")) {
        Write-Host "Création de l'environnement virtuel..."
        python -m venv venv
    } else {
        Write-Host "Environnement virtuel déjà présent."
    }

    & ".\venv\Scripts\Activate.ps1"

    # Install deps via requirements.txt si dispo, sinon fallback
    if (Test-Path ".\requirements.txt") {
        Write-Host "Installation via requirements.txt ..."
        pip install --upgrade pip
        pip install -r requirements.txt
    } else {
        Write-Host "Installation minimale (FastAPI, Uvicorn, pyodbc, python-dotenv) ..."
        pip install --upgrade pip
        pip install fastapi uvicorn pyodbc python-dotenv
    }

    Pop-Location
}

function Try-Run-InternalInstaller($root) {
    $internal = @(
        Join-Path $root "scripts\windows\install.ps1"
        Join-Path $root "install-windows.ps1"
        Join-Path $root "setup-windows.ps1"
    ) | Where-Object { Test-Path $_ }

    if ($internal.Count -gt 0) {
        Write-Host "Exécution du script interne: $($internal[0])"
        & $internal[0]
        return $true
    }
    return $false
}

# ----- Début -----
Write-Host "=== Kwisatz Connector - Installation / Mise à jour ==="

Ensure-Directory $TmpRoot
Ensure-Directory $InstallRoot

# 1) Téléchargement
Download-Archive

# 2) Calcul hash et comparaison
$zipHash = Get-FileSha256 $ZipPath
$needUpdate = $true
if (Test-Path $HashFile) {
    $prevHash = Get-Content $HashFile -ErrorAction SilentlyContinue
    if ($prevHash -and ($prevHash.Trim() -eq $zipHash.Trim())) {
        $needUpdate = $false
    }
}

if (-not $needUpdate) {
    Write-Host "Aucune mise à jour: l’archive distante est identique à la dernière install. ✅"
} else {
    Write-Host "Nouvelle archive détectée. Mise à jour en cours..."

    # 3) Extraction en dossier temp unique
    $ExtractTo = Join-Path $TmpRoot "extract_$([Guid]::NewGuid().ToString('N'))"
    Ensure-Directory $ExtractTo
    Expand-Archive -Path $ZipPath -DestinationPath $ExtractTo -Force

    # 4) La racine extraite contient un dossier de type 'kwisatz_connector-main'
    $rootFolder = Get-ChildItem $ExtractTo | Where-Object { $_.PSIsContainer } | Select-Object -First 1
    if (-not $rootFolder) {
        Write-Error "Impossible de déterminer le dossier racine extrait."
        exit 1
    }

    # 5) Copie vers dossier d'install (préserve .env)
    Copy-RepoTo-Install -extractedRoot $rootFolder.FullName -installRoot $InstallRoot

    # 6) Sauvegarde du nouveau hash
    $zipHash | Out-File -Encoding ascii $HashFile

    Write-Host "✅ Code mis à jour dans $InstallRoot"
}

# 7) Installation/MAJ dépendances
Write-Host "Vérification / installation de Python..."
Ensure-Python

Write-Host "Recherche d'un script d'installation interne..."
$ranInternal = Try-Run-InternalInstaller $InstallRoot
if (-not $ranInternal) {
    Write-Host "Aucun script interne trouvé. Procédure générique."
    Generic-Install $InstallRoot
}

# 8) (Option) Lancer l’API (commenter si vous avez un service Windows dédié)
#    NB: on ne garde PAS le processus attaché si ce script est lancé en tache planifiée.
#    Pour un service, utilisez NSSM ou un Task Scheduler séparé.
$AutoStart = $true
if ($AutoStart) {
    Write-Host "Démarrage de l'API en local sur http://localhost:8081 ..."
    Push-Location $InstallRoot
    & ".\venv\Scripts\Activate.ps1"
    Start-Process -NoNewWindow -FilePath "uvicorn" -ArgumentList "app.main:app","--host","0.0.0.0","--port","8000","--workers","1"
    Pop-Location
    Write-Host "✅ Uvicorn lancé (processus en arrière-plan)."
}

Write-Host "=== Terminé ==="

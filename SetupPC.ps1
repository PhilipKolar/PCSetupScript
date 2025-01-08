<#
.SYNOPSIS
    Set up development environment on a fresh Windows 11 installation.

.DESCRIPTION
    1) Installs Chocolatey if not present.
    2) Installs a list of software packages with Chocolatey (if not already installed).
    3) Configures Git aliases for convenience.
    4) Installs extensions for Visual Studio Code and (optionally) Cursor.
    5) Provides info on installing Visual Studio extensions and browser extensions.
    6) Optionally clones Git repositories from a text file (default location c:\repos\).

.NOTES
    You must run this script as administrator (elevated PowerShell).
    Also, your PowerShell ExecutionPolicy may need to be set to RemoteSigned or Bypass
    in order to run scripts. For example:

        Set-ExecutionPolicy Bypass -Scope Process -Force

    Then you can run this script:

        .\SetupEnvironment.ps1
#>

# Requires elevated privileges
if (-not (net session 2>$null)) {
    Write-Host "This script must be run as an administrator. Exiting..."
    exit 1
}

# Ensure TLS 1.2 for web requests
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ConfigFilePath = ".\config.psd1"

function Load-PrivateConfig {
    param(
        [string]$FilePath
    )
    
    if (Test-Path $FilePath) {
        Write-Host "Loading private config from $FilePath..."
        return Import-PowerShellDataFile -Path $FilePath
    } else {
        Write-Warning "No config file found at $FilePath. Proceeding without it."
        return $null
    }
}

$config = Load-PrivateConfig -FilePath $ConfigFilePath
if ($config) {
    $GitUserName  = $config.GitUserName
    $GitUserEmail = $config.GitUserEmail
}


#------------------------------------------------
# 1) Install Chocolatey if not present
#------------------------------------------------

function Install-Chocolatey {
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Chocolatey not found. Installing Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        $ChocoInstallScript = "https://chocolatey.org/install.ps1"
        iex ((New-Object System.Net.WebClient).DownloadString($ChocoInstallScript))
    }
    else {
        Write-Host "Chocolatey is already installed."
    }
}

Install-Chocolatey

#------------------------------------------------
# 2) Install required software packages via Choco
#    (only if not found in PATH / or quick check)
#------------------------------------------------

# Some notes on certain Chocolatey packages:
#   - For Docker, the common package is 'docker-desktop'.
#   - For Node.js (with npm), we can use 'nodejs-lts'.
#   - Cursor might not be a recognized package name; adjust if needed.
#   - Visual Studio Professional is typically 'visualstudio2022professional'.
#
# Adjust as you see fit:
$packages = @(
    @{ name = "Git";                            chocoName = "git";                             checkCmd = "git" },
    @{ name = "LINQPad";                        chocoName = "linqpad";                         checkCmd = "linqpad" },
    @{ name = "Visual Studio Professional";     chocoName = "visualstudio2022professional";    checkCmd = "devenv" },
    @{ name = "Firefox";                        chocoName = "firefox";                         checkCmd = "firefox" },
    @{ name = "Chrome";                         chocoName = "googlechrome";                    checkCmd = "chrome" },
    #@{ name = "Cursor";                         chocoName = "cursor";                          checkCmd = "cursor" }, # Might not exist in Chocolatey
    @{ name = "Spotify";                        chocoName = "spotify";                         checkCmd = "spotify" },
    @{ name = "VS Code";                        chocoName = "vscode";                          checkCmd = "code" },
    @{ name = "7Zip";                           chocoName = "7zip";                            checkCmd = "7z" },
    @{ name = "Google Drive";                   chocoName = "googledrive";                     checkCmd = "googledrive" },
    @{ name = "MPC-HC";                         chocoName = "mpc-hc";                          checkCmd = "mpc-hc" },
    @{ name = "FileZilla";                      chocoName = "filezilla";                       checkCmd = "filezilla" },
    @{ name = "Gimp";                           chocoName = "gimp";                            checkCmd = "gimp" },
    @{ name = "WinDirStat";                     chocoName = "windirstat";                      checkCmd = "windirstat" },
    @{ name = "IrfanView";                      chocoName = "irfanview";                       checkCmd = "i_view64" },
    @{ name = "ChatGPT Desktop App";            chocoName = "chatgpt";                         checkCmd = "chatgpt" },
    @{ name = "IIS";                            chocoName = "iis";                             checkCmd = "InetMgr" },
    @{ name = "SQL Server Developer";           chocoName = "sql-server-developer";            checkCmd = "sqlservr" },
    @{ name = "SQL Server Management Studio";   chocoName = "sql-server-management-studio";    checkCmd = "ssms" },
    @{ name = "Docker Desktop";                 chocoName = "docker-desktop";                  checkCmd = "docker" },
    @{ name = "Node.js (with npm)";            chocoName = "nodejs-lts";                       checkCmd = "npm" }
)

function Test-CommandExists($cmd) {
    # Quick check if something is in PATH
    return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

foreach ($pkg in $packages) {
    $appName = $pkg.name
    $chocoName = $pkg.chocoName
    $checkCmd = $pkg.checkCmd

    Write-Host "`nChecking if [$appName] is installed..."

    if (Test-CommandExists $checkCmd) {
        Write-Host "    $appName found in PATH, skipping Chocolatey install."
    }
    else {
        Write-Host "    Installing $appName using Chocolatey package: $chocoName ..."
        choco install $chocoName -y
    }
}

#------------------------------------------------
# 3) Configure Git aliases
#------------------------------------------------

Write-Host "`nConfiguring Git aliases..."
if (Test-CommandExists "git") {
    Write-Host "Git is installed. Setting name/email..."
    if ($GitUserName -and $GitUserEmail) {
        Write-Host "Configuring git user.name and user.email..."
        git config --global user.name  $GitUserName
        git config --global user.email $GitUserEmail
    } else {
        Write-Warning "Git username/email not set. Please provide them in config.psd1."
    }

    Set-Alias g git
    git config --global alias.cb "rev-parse --abbrev-ref HEAD"
    git config --global alias.b "branch"
    git config --global alias.a "add"
    git config --global alias.c "commit"
    git config --global alias.p "push"
    git config --global alias.f "fetch"
    git config --global alias.l "log"
    git config --global alias.co "checkout"
    git config --global alias.s "status"
    git config --global alias.d "diff"
}
else {
    Write-Warning "Git not found! Aliases not configured."
}

#------------------------------------------------
# 4) Install VS Code and Cursor extensions
#------------------------------------------------

# Note: We assume the user wants these extensions in both VS Code and Cursor.
#       If Cursor supports "cursor --install-extension <extensionId>" similarly,
#       this *might* work. Otherwise, remove or adapt the Cursor block.

# List of extension IDs for VS Code Marketplace
# The "friendly" names are shown in parentheses but we need extension identifiers.
# Adjust the extension IDs if they differ from the official ones.
$vsCodeExtensions = @(
    "ms-dotnettools.csdevkit",            # C# Dev Kit
    "ms-dotnettools.csharp",              # C#
    "ms-dotnettools.vscodeintellicodecsdevkit", # IntelliCode for C# Dev Kit
    "GitHub.copilot",                     # GitHub Copilot
    "GitHub.copilot-chat",                # GitHub Copilot Chat
    "ms-azuretools.vscode-docker",        # Docker
    "dbaeumer.vscode-eslint",             # ES Lint
    "christian-kohler.npm-intellisense",  # npm Intellisense
    "christian-kohler.path-intellisense", # Path Intellisense
    "kevinmcgowan.TypeScript-Importer"    # TypeScript Importer
)

function Install-CodeExtensions {
    param(
        [Parameter(Mandatory=$true)]
        [string]$EditorCmd,   # e.g. "code" or "cursor"
        [string[]]$Extensions
    )

    if (Test-CommandExists $EditorCmd) {
        Write-Host "`nInstalling $($Extensions.Count) extensions for '$EditorCmd':"
        foreach ($ext in $Extensions) {
            Write-Host "    Installing extension: $ext"
            & $EditorCmd --install-extension $ext --force
        }
    }
    else {
        Write-Warning "`n$EditorCmd CLI not found. Skipping extension installs."
    }
}

# Install extensions for VS Code
Install-CodeExtensions -EditorCmd "code" -Extensions $vsCodeExtensions

# Install the same set of extensions for Cursor
Install-CodeExtensions -EditorCmd "cursor" -Extensions $vsCodeExtensions

#------------------------------------------------
# 5) Install Visual Studio extensions
#------------------------------------------------

Write-Host "`nVisual Studio extensions are next. This typically requires .vsix files or the VS extension installer."

# Example list of Visual Studio extensions you want:
$vsExtensions = @(
    "Make The Sound",
    "Rainbow Braces",
    "Colorized Tabs",
    "OzCodeReview",
    "NCrunch for Visual Studio",
    "File Icons",
    "Trailing Whitespace Visualizer"
)

Write-Host "The following extensions are desired for Visual Studio Professional:"
$vsExtensions | ForEach-Object { Write-Host "  - $_" }

Write-Host @"
Automated Visual Studio extension installs often require:
    1) Downloading each .vsix from the Visual Studio Marketplace
       e.g. https://marketplace.visualstudio.com
    2) Using vsixinstaller.exe or 'Visual Studio Installer' command lines
       Example:
         & "C:\Program Files (x86)\Microsoft Visual Studio\2022\Professional\Common7\IDE\VSIXInstaller.exe" /quiet /skuName:Pro /skuVersion:17.0 "<path to .vsix>"

If Chocolatey or other package managers have these extensions, you can automate further.
Otherwise, download them manually or script the .vsix retrieval.
"@

#------------------------------------------------
# 6) Install Firefox & Chrome extensions
#------------------------------------------------

Write-Host "`nInstalling Firefox and Chrome extensions automatically can be tricky..."
Write-Host "Extensions desired: uBlock Origin, LastPass, SponsorBlock, React DevTools, Redux DevTools"

Write-Host @"
Firefox:
  - In enterprise environments, you can set ExtensionInstallForcelist via Group Policy or a policies.json file in the Firefox profile.
  - For instance, you'd set:
      {
        "policies": {
          "ExtensionSettings": {
            "uBlock0@raymondhill.net": {
              "install_url": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/addon-ublock-origin-latest.xpi",
              "installation_mode": "force_installed"
            },
            ...
          }
        }
      }

Chrome:
  - Similar approach with group policies or registry-based approach.
  - For each extension, you need the extension ID and update URL from the Chrome Web Store.
  - Example: 
      Windows Registry path:
      HKLM\Software\Policies\Google\Chrome\ExtensionInstallForcelist
      Or
      HKCU\Software\Policies\Google\Chrome\ExtensionInstallForcelist
  - The value might look like:
      "extension_id;https://clients2.google.com/service/update2/crx"

This is typically how enterprises force-install browser extensions.

For personal machines, often it's easier to install them manually from the store.
"@

#------------------------------------------------
# 7) Clone repositories from a text file
#    (default location: c:\repos)
#------------------------------------------------

$DefaultClonePath = "C:\repos"
$ReposListPath    = ".\repos.txt"

function Clone-Repositories {
    param(
        [string]$RepoListFile = $ReposListPath,
        [string]$CloneFolder = $DefaultClonePath
    )

    if (!(Test-Path $RepoListFile)) {
        Write-Host "No repos.txt file found at $RepoListFile. Skipping clone."
        return
    }

    if (-not (Test-Path $CloneFolder)) {
        Write-Host "Directory $CloneFolder does not exist. Creating..."
        New-Item -ItemType Directory -Path $CloneFolder | Out-Null
    }

    $repos = Get-Content $RepoListFile | Where-Object { $_ -and $_.Trim() -ne "" }
    foreach ($repo in $repos) {
        Write-Host "Cloning $repo ..."
        git clone $repo (Join-Path $CloneFolder (Split-Path $repo -LeafBase))
    }
}

# Uncomment the following line if you want to automatically clone the repositories
# Clone-Repositories

Write-Host "`nDevelopment environment setup is complete (with caveats for the steps requiring manual input)!"

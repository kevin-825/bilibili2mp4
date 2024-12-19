# Windows PowerShell script to process .m4s files

# Function to process a file
function Process-File {
    param (
        [string]$FilePath
    )

    $chunkSize = 4096  # Define the chunk size for reading and writing

    # Use a temporary file for modifications
    $tempPath = [System.IO.Path]::GetTempFileName()

    $fsInput = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
    $fsOutput = [System.IO.File]::Open($tempPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)

    try {
        $skipCount = 0

        # Skip up to 15 leading 0x30 bytes
        while ($skipCount -lt 15 -and $fsInput.Position -lt $fsInput.Length) {
            $byte = $fsInput.ReadByte()
            if ($byte -eq 0x30) {
                $skipCount++
            } else {
                # Write the byte to the output file if it doesn't match 0x30
                $fsOutput.WriteByte([byte]$byte)
                break
            }
        }

        # Copy the remaining content
        $buffer = New-Object byte[] $chunkSize
        while ($bytesRead = $fsInput.Read($buffer, 0, $buffer.Length)) {
            $fsOutput.Write($buffer, 0, $bytesRead)
        }
    } finally {
        $fsInput.Close()
        $fsOutput.Close()
    }

    # Replace the original file with the temporary file
    Move-Item -Path $tempPath -Destination $FilePath -Force
    Write-Host "Byte deletion operation completed for $FilePath."
}

# Main script logic
Write-Host "Scanning current directory for .m4s files..."

# Find all .m4s files in the current directory
$m4sFiles = Get-ChildItem -Path . -Filter "*.m4s" -File | Select-Object -ExpandProperty FullName

if ($m4sFiles.Count -lt 2) {
    Write-Host "Error: Less than two .m4s files found. Exiting."
    exit 1
} elseif ($m4sFiles.Count -gt 2) {
    Write-Host "More than two .m4s files found. Please select two files to process:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $m4sFiles.Count; $i++) {
        Write-Host "$($i + 1): $($m4sFiles[$i])"
    }
    $selection1 = Read-Host "Enter the number of the first file to process"
    $selection2 = Read-Host "Enter the number of the second file to process"

    if (-not ($selection1 -as [int]) -or -not ($selection2 -as [int]) -or $selection1 -eq $selection2 -or $selection1 -lt 1 -or $selection2 -lt 1 -or $selection1 -gt $m4sFiles.Count -or $selection2 -gt $m4sFiles.Count) {
        Write-Host "Invalid selection. Exiting."
        exit 1
    }

    $files = @($m4sFiles[$selection1 - 1], $m4sFiles[$selection2 - 1])
} else {
    $files = $m4sFiles
}

Write-Host "Copying selected files to 1.m4s and 2.m4s..."
Copy-Item -Path $files[0] -Destination "1.m4s" -Force
if (-not (Test-Path "1.m4s")) {
    Write-Host "Error: Failed to copy $($files[0]) to 1.m4s. Exiting."
    exit 1
}
Write-Host "File $($files[0]) successfully copied to 1.m4s."

Copy-Item -Path $files[1] -Destination "2.m4s" -Force
if (-not (Test-Path "2.m4s")) {
    Write-Host "Error: Failed to copy $($files[1]) to 2.m4s. Exiting."
    exit 1
}
Write-Host "File $($files[1]) successfully copied to 2.m4s."

# Files to process
$filesToProcess = @("1.m4s", "2.m4s")

# Process each file
foreach ($file in $filesToProcess) {
    if (Test-Path $file) {
        Write-Host "Processing $file..."
        Process-File -FilePath $file
    } else {
        Write-Host "File $file not found, skipping."
    }
}

Write-Host "Done."

# Ask user for output file name
$outputFileName = Read-Host "Enter the output file name (without extension)"

# Invoke ffmpeg command
$ffmpegCommand = "ffmpeg.exe -i ./1.m4s -i ./2.m4s -codec copy $outputFileName.mp4"
Write-Host "Executing: $ffmpegCommand"
Invoke-Expression $ffmpegCommand
Write-Host "Done."
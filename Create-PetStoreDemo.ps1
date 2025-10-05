param(
    [switch]$Cleanup
)

$Env:AWS_REGION = "us-east-1"

if ($Cleanup) {
    Write-Host "=== Destroying PetStore demo ===" -ForegroundColor Cyan
    terraform destroy -auto-approve
    exit
}

Write-Host "=== Building PetStore demo ===" -ForegroundColor Cyan

# Ensure function.zip exists
if (-not (Test-Path ".\function.zip")) {
    Write-Host "Zipping Lambda code..." -ForegroundColor Yellow
    Compress-Archive -Path .\lambda_function.py -DestinationPath .\function.zip -Force
}

terraform init
terraform apply -auto-approve

Write-Host "=== PetStore demo created successfully! ===" -ForegroundColor Green

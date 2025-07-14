# CI/CD Pipeline POC for Datto RMM Components

This proof of concept demonstrates a complete CI/CD pipeline for deploying PowerShell components to Datto RMM using GitHub Actions.

## 🚀 Features

- **Automated Testing**: Components are validated before deployment
- **Multi-Environment Support**: Separate staging and production environments
- **API Integration**: Direct integration with Datto RMM API
- **Validation Engine**: Comprehensive validation of PowerShell components
- **Deployment Tracking**: Detailed reports and notifications
- **Security**: Secure handling of API keys and credentials

## 📁 Structure

```
├── .github/workflows/
│   └── datto-rmm-deploy.yml     # GitHub Actions workflow
├── scripts/
│   ├── DattoRMMAPI.psm1         # Datto RMM API module
│   ├── deploy-to-datto.ps1      # Deployment script
│   └── validate-components.ps1   # Validation script
├── components/
│   └── Get-SystemInfo.ps1       # Sample component
└── README-CICD-POC.md           # This file
```

## 🔧 Setup

### 1. Repository Secrets

Configure these secrets in your GitHub repository:

- `DATTO_API_KEY_STAGING`: API key for staging environment
- `DATTO_API_KEY_PRODUCTION`: API key for production environment
- `TEAMS_WEBHOOK_URL`: (Optional) Microsoft Teams webhook for notifications

### 2. Environment Configuration

The pipeline supports two environments:

- **Staging**: For testing components before production
- **Production**: For live deployment

### 3. Component Structure

Components must follow this structure:

```powershell
<#
.SYNOPSIS
    Brief description of what the component does
.DESCRIPTION
    Detailed description of the component functionality
.EXAMPLE
    Example of how to use the component
#>

param(
    # Component parameters
)

try {
    # Component logic here
    Write-Host "Component executed successfully" -ForegroundColor Green
}
catch {
    Write-Error "Component failed: $($_.Exception.Message)"
    throw
}
```

## 🔄 Workflow

### Trigger Conditions

The pipeline triggers on:
- Push to `main` branch (production deployment)
- Pull requests to `main` branch (staging deployment)
- Manual workflow dispatch

### Pipeline Stages

1. **Test**: Validates PowerShell syntax and structure
2. **Validate**: Checks component compliance with standards
3. **Deploy Staging**: Deploys to staging environment (PRs only)
4. **Deploy Production**: Deploys to production environment (main branch only)
5. **Notify**: Sends deployment notifications

## 🛠️ Scripts

### DattoRMMAPI.psm1

PowerShell module providing functions to interact with Datto RMM API:

- `Initialize-DattoRMMAPI`: Setup authentication
- `Get-DattoComponents`: List existing components
- `New-DattoComponent`: Create new components
- `Update-DattoComponent`: Update existing components
- `Invoke-DattoComponent`: Execute components on devices
- `Get-DattoJobStatus`: Check job execution status

### deploy-to-datto.ps1

Main deployment script that:
- Validates components before deployment
- Creates or updates components in Datto RMM
- Generates deployment reports
- Handles errors gracefully

### validate-components.ps1

Validation script that checks:
- PowerShell syntax correctness
- Required documentation comments
- Forbidden dangerous commands
- Code structure compliance
- File size and encoding

## 📊 Validation Rules

Components must meet these criteria:

- **Required Comments**: SYNOPSIS, DESCRIPTION, EXAMPLE
- **Forbidden Commands**: Remove-Item, Format-Volume, etc.
- **Structure Requirements**: param block, try-catch blocks, error handling
- **File Constraints**: Maximum 50KB, UTF-8 encoding
- **Security**: No hardcoded paths or sensitive information

## 🚀 Usage

### Adding a New Component

1. Create a new `.ps1` file in the `components/` directory
2. Follow the component structure guidelines
3. Commit and push to a feature branch
4. Create a pull request (triggers staging deployment)
5. Merge to main (triggers production deployment)

### Manual Deployment

You can also run the deployment script manually:

```powershell
# Deploy to staging
.\scripts\deploy-to-datto.ps1 -Environment staging -ApiKey "your-api-key"

# Deploy to production
.\scripts\deploy-to-datto.ps1 -Environment production -ApiKey "your-api-key"
```

### Component Validation

Validate components before deployment:

```powershell
# Basic validation
.\scripts\validate-components.ps1 -ComponentPath "components"

# Detailed validation
.\scripts\validate-components.ps1 -ComponentPath "components" -Detailed
```

## 🔐 Security Considerations

- API keys are stored as GitHub repository secrets
- Components are validated for dangerous commands
- Deployment requires appropriate permissions
- All API calls use HTTPS encryption
- Deployment logs are sanitized

## 📈 Monitoring

The pipeline provides:
- Deployment status notifications
- Detailed validation reports
- Component execution tracking
- Error logging and alerting

## 🔄 Rollback

To rollback a deployment:
1. Revert the commit in the main branch
2. The pipeline will automatically redeploy the previous version
3. Or manually update components via the Datto RMM API

## 📝 Example Component

See `components/Get-SystemInfo.ps1` for a complete example of a properly structured component.

## 🎯 Next Steps

1. Set up repository secrets
2. Configure environment-specific settings
3. Add your first component
4. Test the pipeline with a pull request
5. Monitor deployment results

## 🤝 Contributing

When contributing new components:
1. Follow the component structure guidelines
2. Include comprehensive documentation
3. Add appropriate error handling
4. Test thoroughly before submission
5. Update documentation as needed

## 📚 Resources

- [Datto RMM API Documentation](https://concord-api.centrastage.net/api/swagger-ui/index.html)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [PowerShell Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/writing-portable-modules)

---

This POC demonstrates the complete automation of Datto RMM component deployment using modern DevOps practices. The pipeline ensures code quality, security, and reliable deployment to multiple environments.
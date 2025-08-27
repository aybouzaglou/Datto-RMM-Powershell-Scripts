# Datto RMM Component Categories

## Overview

Datto RMM has three component categories with different characteristics:

## Applications
- **Purpose**: Software deployment and installation
- **Timeout**: Up to 30 minutes
- **Changeable**: Yes (can convert to Scripts)
- **Exit Codes**: 0=success, 3010=reboot required, 1641=reboot initiated

## Monitors
- **Purpose**: System health monitoring
- **Timeout**: <3 seconds
- **Changeable**: No (immutable)
- **Exit Codes**: 0=healthy, non-zero=alert
- **Output Requirements**: Must use `<-Start Result->` and `<-End Result->` markers
- **Deployment**: Direct deployment only (no launchers for optimal performance)
- **Design Pattern**: Diagnostic-first with single output stream (Write-Host only)

## Scripts
- **Purpose**: General automation and maintenance
- **Timeout**: Flexible
- **Changeable**: Yes (can convert to Applications)
- **Exit Codes**: 0=success, 1=warnings, 2=errors
## Usage Guidelines

### Applications
- Use for software installation and deployment
- Can be converted to Scripts category later

### Monitors
- Use for system health checks and alerting
- Must use `<-Start Result->` and `<-End Result->` markers
- Cannot be converted to other categories

### Scripts
- Use for general automation and maintenance
- Can be converted to Applications category later

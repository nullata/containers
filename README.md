

#  <img src="images/logo.png" alt="logo" width="24"> Nullata Container Build Automation

A comprehensive framework for building, testing, and maintaining containerized applications with automated version tracking and release management.

## Overview

This repository provides an automated system for building and maintaining container images. Originally inspired by Bitnami's container repository before it transitioned from open source to a corporate model, this project aims to fill the gap for community-maintained, production-ready container images.

The framework handles the complete lifecycle of container builds:
- Automated version detection for upstream components
- Smart build directory creation with version management
- Comprehensive testing with multiple deployment profiles
- Docker Hub integration with automated README updates
- Standardized build and deployment workflows

## Project Structure

```
.
├── apps/                    # Application definitions
│   └── <app-name>/         # e.g., mariadb-galera
│       ├── VERSION         # Master version tracking
│       └── <version>/      # e.g., 12.0.2
│           ├── Dockerfile
│           ├── docker-compose.yml
│           ├── VERSION     # Build metadata
│           └── setup.sh    # Environment setup/cleanup
├── lib/                    # Core libraries
│   ├── common.sh          # Utility functions
│   ├── docker.sh          # Docker operations
│   ├── logging.sh         # Logging framework
│   └── versioning.sh      # Version detection and management
├── check-releases.sh      # Automated update checker
├── composer.sh            # Build/test/deployment orchestration
└── set-env.sh            # Environment configuration
```

## Requirements

### System Dependencies
- **Docker** - Container runtime (daemon must be running)
- **bash** - Version 4.0 or higher
- **jq** - JSON processor
- **yq** - YAML processor
- **curl** - HTTP client for API calls

### Optional
- Docker Hub credentials for pushing images (set via environment variables)

## Quick Start

### Clone and Setup

```bash
git clone <repository-url>
cd containers
chmod +x composer.sh check-releases.sh
```

### Build and Test an Application

```bash
# Build the container image
./composer.sh build apps/mariadb-galera/12.0.2/docker-compose.yml

# Start a specific profile
./composer.sh start apps/mariadb-galera/12.0.2/docker-compose.yml test-single

# Check status
./composer.sh status apps/mariadb-galera/12.0.2/docker-compose.yml test-single

# View logs
./composer.sh logs apps/mariadb-galera/12.0.2/docker-compose.yml test-single

# Stop and cleanup
./composer.sh stop apps/mariadb-galera/12.0.2/docker-compose.yml test-single
```

### Run Automated Tests (docker-compose & profiles required)

```bash
# Test all profiles for an application
./composer.sh test apps/mariadb-galera/12.0.2/docker-compose.yml
```

### Check for Updates

```bash
# Scan all applications for version updates
./check-releases.sh
```

## Adding New Applications

### Directory Structure

Create a new application directory under `apps/`:

```bash
apps/
└── <app-name>/
    ├── VERSION                    # Master version file
    └── <initial-version>/
        ├── Dockerfile
        ├── docker-compose.yml
        ├── VERSION               # Build metadata
        ├── setup.sh              # Optional: custom environment setup script for volumes & other
        └── rootfs/               # Optional: runtime files
```

### Master VERSION File

Create `apps/<app-name>/VERSION` with component tracking:

```json
{
  "app_name": "your-app-name",
  "components": [
    {
      "name": "primary-component",
      "primary": true,
      "latest_version": "1.0.0",
      "version_source": {
        "type": "github_latest_release",
        "url": "https://api.github.com/repos/owner/repo/releases/latest",
        "field": "tag_name",
        "pattern": "v([0-9.]+)"
      }
    },
    {
      "name": "dependency",
      "primary": false,
      "latest_version": "2.5.0",
      "version_source": {
        "type": "github_tags",
        "url": "https://api.github.com/repos/owner/repo/tags",
        "field": "name",
        "pattern": "release_([0-9.]+)"
      }
    }
  ]
}
```

#### Version Source Types

**github_latest_release** - For projects using GitHub Releases:
```json
{
  "type": "github_latest_release",
  "url": "https://api.github.com/repos/owner/repo/releases/latest",
  "field": "tag_name",
  "pattern": "v([0-9.]+)"
}
```

**github_tags** - For projects using Git tags:
```json
{
  "type": "github_tags",
  "url": "https://api.github.com/repos/owner/repo/tags",
  "field": "name",
  "pattern": "release_([0-9.]+)"
}
```

**github_releases** - For paginated release listings:
```json
{
  "type": "github_releases",
  "url": "https://api.github.com/repos/owner/repo/releases",
  "field": "tag_name",
  "pattern": "([0-9.]+)"
}
```

### Build VERSION File

Create `apps/<app-name>/<version>/VERSION`:

```json
{
  "build_version": "1.0.0",
  "component1": "1.0.0",
  "component2": "2.5.0",
  "build_date": "2025-10-28",
  "status": "untested"
}
```

**Status values:**
- `untested` - Newly created, not yet validated
- `tested` - Passed automated health checks
- `failed` - Did not pass health checks

### Dockerfile Requirements

Your Dockerfile must:
1. Use `ARG` declarations for component versions matching the uppercase component name:
   ```dockerfile
   ARG COMPONENT1_VERSION=1.0.0
   ARG COMPONENT2_VERSION=2.5.0
   ```

2. Include health check support (test script or command)

3. Follow best practices for the base image and runtime user

### Docker Compose Configuration

The `docker-compose.yml` must:
1. Use profiles to define different deployment scenarios:
   ```yaml
   services:
     app-single:
       profiles: ["test-single"]
       image: namespace/app:${VERSION}
       # ...
   ```

2. Include health checks:
   ```yaml
   healthcheck:
     test: ["CMD", "/path/to/healthcheck.sh"]
     interval: 15s
     timeout: 5s
     retries: 6
   ```

3. Use the `${VERSION}` environment variable for image tags

### Setup Script (Optional)

Create `apps/<app-name>/<version>/setup.sh` for profile-specific initialization:

```bash
#!/usr/bin/env bash

action=$1
profile=$2

if [[ -z ${action} ]] || [[ -z ${profile} ]]; then
    logError "$0: Action and profile must be specified"
fi

key="${action}:${profile}"
case "${key}" in
    init:test-single)
        mkDirs "${NULLATA_TEST_BUILD_DIR}/app-data"
        ;;
    clear:test-single)
        rmDirs "${NULLATA_TEST_BUILD_DIR}/app-data"
        ;;
    *)
        logError "$0: Unsupported: ${key}"
        ;;
esac
```

The script receives two arguments:
- `action`: Either `init` or `clear`
- `profile`: The docker-compose profile name

## Manual Workflows

### composer.sh

The main orchestration script for building, testing, and managing containers.

#### Usage

```bash
./composer.sh <command> <compose-file> <profile> [options]
```

#### Commands

**build** - Build the container image
```bash
./composer.sh build apps/mariadb-galera/12.0.2/docker-compose.yml
```
- Does not require a profile
- Updates build_date in VERSION file upon success

**start** - Start containers with a specific profile
```bash
./composer.sh start apps/mariadb-galera/12.0.2/docker-compose.yml test-single
```
- Runs setup.sh init if present
- Starts containers in detached mode

**stop** - Stop and __remove__ containers
```bash
./composer.sh stop apps/mariadb-galera/12.0.2/docker-compose.yml test-single
```
- Runs setup.sh clear if present
- __Removes__ containers and networks

**restart** - Stop (without removing) and start containers
```bash
./composer.sh restart apps/mariadb-galera/12.0.2/docker-compose.yml test-single
```

**status** - Show running container status
```bash
./composer.sh status apps/mariadb-galera/12.0.2/docker-compose.yml test-single
```

**logs** - Display container logs
```bash
./composer.sh logs apps/mariadb-galera/12.0.2/docker-compose.yml test-single
```

**test** - Run comprehensive automated tests
```bash
./composer.sh test apps/mariadb-galera/12.0.2/docker-compose.yml
```
- Tests all available profiles sequentially
- Performs health checks with configurable timeout
- Updates status in VERSION file
- Automatically cleans up after each profile test

**push** - Push image to Docker Hub
```bash
./composer.sh push apps/mariadb-galera/12.0.2/docker-compose.yml
```
- Pushes versioned tag
- Updates and pushes `latest` tag
- Updates Docker Hub README with component versions
- Requires Docker Hub authentication

#### Environment Variables

**NULLATA_DEBUG** - Enable debug logging
```bash
export NULLATA_DEBUG=true
```

**NULLATA_TEST_BUILD_DIR** - Base directory for test data
```bash
export NULLATA_TEST_BUILD_DIR=/opt/services/database
```

**TEST_STACK_TIMEOUT_PD_S** - Health check timeout in seconds (default: 90)
```bash
export TEST_STACK_TIMEOUT_PD_S=120
```

## Automated Workflows

### check-releases.sh

Automatically detects upstream version updates and creates new build directories.

#### How It Works

1. Scans all applications in `apps/` directory
2. Reads each master VERSION file
3. Fetches latest versions from configured sources
4. Compares with current versions
5. Creates new build directory if updates are found
6. Updates Dockerfile ARG values
7. Updates VERSION files
8. Triggers automated testing via composer.sh

#### Update Triggers

New builds are created when:
- **Any component** has an available update
- **Primary component** determines the directory version number
- **Secondary component** updates create suffixed versions (e.g., `12.0.2-1`, `12.0.2-2`)

#### Running Manually

```bash
./check-releases.sh
```

#### Automated Execution

Add to crontab for monthly checks:

```bash
# Check for updates on the 1st of each month at 2 AM
0 2 1 * * /path/to/containers/check-releases.sh
```

#### What Gets Updated

When a new version is detected:

1. **New build directory** created by copying latest version
2. **Dockerfile** - ARG values updated to new versions
3. **Build VERSION file** - Component versions updated, status set to "untested"
4. **Master VERSION file** - latest_version fields updated for all components
5. **Automated tests** - Runs `composer.sh test` on new build

## Testing

### Health Checks

All containers must implement health checks. The framework validates:
- Container starts successfully
- Health check passes within timeout period (default 90s)
- All containers in a profile are healthy

### Test Profiles

Define multiple deployment scenarios in docker-compose.yml:
- **test-single** - Single node deployment
- **test-cluster** - Multi-node cluster
- **test-seed** - Seed and join topology

Each profile is tested independently with automatic cleanup.

### Test Process

1. Pre-clear any existing test deployments
2. Run setup.sh init for the profile
3. Start containers
4. Wait for health checks to pass (with timeout)
5. Stop containers on success or log errors on failure
6. Run setup.sh clear for cleanup
7. Update VERSION status field

### Manual Testing

```bash
# Test all profiles
./composer.sh test apps/mariadb-galera/12.0.2/docker-compose.yml

# Test specific profile manually
./composer.sh start apps/mariadb-galera/12.0.2/docker-compose.yml test-single
# ... perform manual tests ...
./composer.sh stop apps/mariadb-galera/12.0.2/docker-compose.yml test-single
```

## Docker Hub Integration

### README Generation

When pushing images, the framework automatically generates and updates Docker Hub README files with:
- Current version information
- Component versions with build date
- Usage instructions
- Links to available tags

### Publishing Workflow

```bash
# Build the image
./composer.sh build apps/mariadb-galera/12.0.2/docker-compose.yml

# Test all profiles
./composer.sh test apps/mariadb-galera/12.0.2/docker-compose.yml

# Push to Docker Hub (requires authentication)
./composer.sh push apps/mariadb-galera/12.0.2/docker-compose.yml
```

## Configuration

### Global Settings

Edit `set-env.sh` to configure:

```bash
# Repository root (auto-detected)
export NULLATA_REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test build directory
export NULLATA_TEST_BUILD_DIR="${NULLATA_TEST_BUILD_DIR:-/opt/services/database}"

# Logging directory
export NULLATA_LOG_DIR="${NULLATA_LOG_DIR:-/var/log/nullata-builds}"

# Health check timeout
export TEST_STACK_TIMEOUT_PD_S=90
```

### Per-Application Settings

Each application's master VERSION file controls:
- Component tracking
- Version source endpoints
- Update detection patterns

## Troubleshooting

### Build Failures

```bash
# Check build logs
./composer.sh build apps/your-app/1.0.0/docker-compose.yml

# Verify Dockerfile ARG names match component names
grep "ARG.*_VERSION" apps/your-app/1.0.0/Dockerfile
```

### Health Check Failures

```bash
# Check container logs
./composer.sh logs apps/your-app/1.0.0/docker-compose.yml test-single

# Increase health check timeout
export TEST_STACK_TIMEOUT_PD_S=120
```

### Version Detection Issues

```bash
# Test version source manually
curl -s "https://api.github.com/repos/owner/repo/releases/latest" | jq .

# Verify pattern matches
echo "v1.2.3" | grep -oP 'v([0-9.]+)'
```

### Update Check Failures

If network issues occur during update checks:
- Script aborts update for affected application
- Does not continue checking other applications
- Logs clear error messages
- Does not corrupt VERSION files

## Best Practices

### Version Numbering

- Use semantic versioning (MAJOR.MINOR.PATCH)
- Primary component version determines directory name
- Secondary updates append suffix: `12.0.2-1`, `12.0.2-2`

### Testing

- Always run `composer.sh test` before pushing
- Create multiple test profiles for different scenarios
- Implement comprehensive health checks
- Use realistic test data volumes

### Documentation

- Document build-specific requirements in Dockerfile comments
- Include usage examples in docker-compose.yml
- Add troubleshooting notes to application README files

### Security

- Use specific base image tags, not `latest`
- Run containers as non-root user
- Apply security hardening in Dockerfile
- Keep components updated via automated checks

## Contributing

Contributions are welcome! When adding new applications:

1. Follow the directory structure guidelines
2. Include comprehensive test profiles
3. Implement health checks
4. Document any special requirements
5. Test thoroughly before submitting

## License

See LICENSE file for details.

## Acknowledgments

This project was inspired by Bitnami's container repository and aims to continue providing high-quality, community-maintained container images after Bitnami's transition to a corporate model.
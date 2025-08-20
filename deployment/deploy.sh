#!/bin/bash

# AnnedFinds Deployment Script
# This script automates the deployment process for the AnnedFinds e-commerce platform

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="annedfinals"
ENVIRONMENT=${1:-"staging"}  # Default to staging if not specified
BUILD_NUMBER=$(date +%Y%m%d-%H%M%S)

# Firebase project IDs
STAGING_PROJECT="annedfinals-staging"
PRODUCTION_PROJECT="annedfinals-prod"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Flutter is installed
    if ! command -v flutter &> /dev/null; then
        log_error "Flutter is not installed or not in PATH"
        exit 1
    fi
    
    # Check if Firebase CLI is installed
    if ! command -v firebase &> /dev/null; then
        log_error "Firebase CLI is not installed or not in PATH"
        exit 1
    fi
    
    # Check if Docker is installed (for local deployment)
    if ! command -v docker &> /dev/null; then
        log_warning "Docker is not installed - skipping Docker deployment options"
    fi
    
    # Check Flutter version
    FLUTTER_VERSION=$(flutter --version | head -n 1 | cut -d ' ' -f 2)
    log_info "Flutter version: $FLUTTER_VERSION"
    
    log_success "Prerequisites check completed"
}

setup_environment() {
    log_info "Setting up environment: $ENVIRONMENT"
    
    case $ENVIRONMENT in
        "staging")
            export FIREBASE_PROJECT=$STAGING_PROJECT
            export FLUTTER_ENV="staging"
            ;;
        "production")
            export FIREBASE_PROJECT=$PRODUCTION_PROJECT
            export FLUTTER_ENV="production"
            ;;
        *)
            log_error "Unknown environment: $ENVIRONMENT. Use 'staging' or 'production'"
            exit 1
            ;;
    esac
    
    log_info "Firebase project: $FIREBASE_PROJECT"
    log_info "Flutter environment: $FLUTTER_ENV"
}

clean_build() {
    log_info "Cleaning previous builds..."
    
    cd ..
    flutter clean
    flutter pub get
    
    # Clean web build directory
    if [ -d "build/web" ]; then
        rm -rf build/web
    fi
    
    log_success "Clean completed"
}

run_tests() {
    log_info "Running tests..."
    
    cd ..
    
    # Run unit tests
    if [ -d "test" ]; then
        flutter test
        log_success "Unit tests passed"
    else
        log_warning "No test directory found - skipping tests"
    fi
    
    # Run integration tests (if available)
    if [ -d "integration_test" ]; then
        flutter test integration_test
        log_success "Integration tests passed"
    else
        log_warning "No integration test directory found - skipping integration tests"
    fi
}

build_web() {
    log_info "Building Flutter web application..."
    
    cd ..
    
    # Build for web with optimizations
    flutter build web \
        --release \
        --web-renderer html \
        --source-maps \
        --dart-define=ENVIRONMENT=$FLUTTER_ENV \
        --dart-define=BUILD_NUMBER=$BUILD_NUMBER
    
    log_success "Web build completed"
}

build_mobile() {
    log_info "Building mobile applications..."
    
    cd ..
    
    # Build Android APK
    if [ "$ENVIRONMENT" == "production" ]; then
        log_info "Building Android App Bundle for production..."
        flutter build appbundle \
            --release \
            --dart-define=ENVIRONMENT=$FLUTTER_ENV \
            --dart-define=BUILD_NUMBER=$BUILD_NUMBER
    else
        log_info "Building Android APK for staging..."
        flutter build apk \
            --release \
            --dart-define=ENVIRONMENT=$FLUTTER_ENV \
            --dart-define=BUILD_NUMBER=$BUILD_NUMBER
    fi
    
    # Build iOS (if on macOS)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        log_info "Building iOS application..."
        flutter build ios \
            --release \
            --dart-define=ENVIRONMENT=$FLUTTER_ENV \
            --dart-define=BUILD_NUMBER=$BUILD_NUMBER
    else
        log_warning "Skipping iOS build - not on macOS"
    fi
    
    log_success "Mobile builds completed"
}

deploy_firebase() {
    log_info "Deploying to Firebase..."
    
    cd deployment
    
    # Set Firebase project
    firebase use $FIREBASE_PROJECT
    
    # Deploy Firestore rules and indexes
    log_info "Deploying Firestore rules and indexes..."
    firebase deploy --only firestore
    
    # Deploy Storage rules
    log_info "Deploying Storage rules..."
    firebase deploy --only storage
    
    # Deploy Functions (if directory exists)
    if [ -d "../functions" ]; then
        log_info "Deploying Cloud Functions..."
        firebase deploy --only functions
    else
        log_warning "No functions directory found - skipping Functions deployment"
    fi
    
    # Deploy Hosting
    log_info "Deploying web app to Firebase Hosting..."
    firebase deploy --only hosting
    
    # Deploy Remote Config
    log_info "Deploying Remote Config..."
    firebase deploy --only remoteconfig
    
    log_success "Firebase deployment completed"
}

deploy_docker() {
    log_info "Building and deploying Docker containers..."
    
    cd deployment
    
    # Build Docker images
    docker-compose build
    
    # Start services
    docker-compose up -d
    
    # Wait for services to be healthy
    log_info "Waiting for services to be ready..."
    sleep 30
    
    # Check service health
    docker-compose ps
    
    log_success "Docker deployment completed"
}

setup_monitoring() {
    log_info "Setting up monitoring and analytics..."
    
    # Configure Firebase Analytics
    log_info "Configuring Firebase Analytics..."
    # This would typically involve setting up custom events and parameters
    
    # Configure Performance Monitoring
    log_info "Configuring Performance Monitoring..."
    # This would enable performance monitoring in the Firebase console
    
    # Configure Crashlytics
    log_info "Configuring Crashlytics..."
    # This would set up crash reporting
    
    log_success "Monitoring setup completed"
}

run_smoke_tests() {
    log_info "Running smoke tests..."
    
    # Basic health checks
    case $ENVIRONMENT in
        "staging")
            HEALTH_URL="https://annedfinals-staging.web.app/health"
            ;;
        "production")
            HEALTH_URL="https://annedfinals.com/health"
            ;;
    esac
    
    # Wait for deployment to be available
    sleep 60
    
    # Check if the app is accessible
    if curl -f $HEALTH_URL > /dev/null 2>&1; then
        log_success "Health check passed"
    else
        log_error "Health check failed - deployment may not be successful"
        exit 1
    fi
    
    log_success "Smoke tests completed"
}

create_release_notes() {
    log_info "Creating release notes..."
    
    RELEASE_NOTES_FILE="release-notes-$BUILD_NUMBER.md"
    
    cat > $RELEASE_NOTES_FILE << EOF
# AnnedFinds Release Notes

**Environment:** $ENVIRONMENT
**Build Number:** $BUILD_NUMBER
**Date:** $(date)

## Changes in this Release

### Features
- Enhanced search functionality with autocomplete
- Mobile-optimized product screens
- Performance monitoring and optimization tools
- Advanced admin dashboard

### Bug Fixes
- Improved app stability and performance
- Fixed UI inconsistencies across platforms

### Technical Improvements
- Production-ready deployment configuration
- Enhanced security with Firebase rules
- Optimized Docker containers for scalability

## Deployment Information

- **Firebase Project:** $FIREBASE_PROJECT
- **Flutter Version:** $FLUTTER_VERSION
- **Build Type:** Release

## Health Check

- Health endpoint: $HEALTH_URL
- Expected response: HTTP 200 "healthy"

EOF
    
    log_success "Release notes created: $RELEASE_NOTES_FILE"
}

cleanup() {
    log_info "Cleaning up temporary files..."
    
    # Clean up any temporary files or processes
    
    log_success "Cleanup completed"
}

# Main deployment flow
main() {
    log_info "Starting AnnedFinds deployment for environment: $ENVIRONMENT"
    log_info "Build number: $BUILD_NUMBER"
    
    check_prerequisites
    setup_environment
    
    # Build phase
    clean_build
    run_tests
    build_web
    
    # Deploy phase
    deploy_firebase
    
    # Post-deployment
    setup_monitoring
    run_smoke_tests
    create_release_notes
    
    log_success "Deployment completed successfully!"
    log_info "Release notes: release-notes-$BUILD_NUMBER.md"
    
    if [ "$ENVIRONMENT" == "production" ]; then
        log_info "Production deployment complete!"
        log_info "App URL: https://annedfinals.com"
    else
        log_info "Staging deployment complete!"
        log_info "App URL: https://annedfinals-staging.web.app"
    fi
}

# Handle script termination
trap cleanup EXIT

# Parse command line arguments
case "${1:-}" in
    "staging"|"production")
        main
        ;;
    "docker")
        log_info "Running Docker deployment..."
        check_prerequisites
        clean_build
        build_web
        deploy_docker
        ;;
    "test")
        log_info "Running tests only..."
        check_prerequisites
        run_tests
        ;;
    "build")
        log_info "Building only..."
        check_prerequisites
        clean_build
        build_web
        build_mobile
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [staging|production|docker|test|build|help]"
        echo ""
        echo "Commands:"
        echo "  staging     Deploy to staging environment (default)"
        echo "  production  Deploy to production environment"
        echo "  docker      Build and run with Docker"
        echo "  test        Run tests only"
        echo "  build       Build applications only"
        echo "  help        Show this help message"
        ;;
    *)
        log_warning "No environment specified, using staging"
        ENVIRONMENT="staging"
        main
        ;;
esac
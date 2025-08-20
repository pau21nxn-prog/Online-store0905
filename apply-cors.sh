#!/bin/bash

# Firebase Storage CORS Configuration Script for AnnedFinds
# This script applies CORS configuration to your Firebase Storage bucket

echo "🔧 Applying CORS configuration to Firebase Storage..."
echo "📦 Bucket: annedfinds.firebasestorage.app"
echo ""

# Check if gsutil is installed
if ! command -v gsutil &> /dev/null; then
    echo "❌ gsutil not found. Please install Google Cloud SDK or use Cloud Shell."
    echo "📋 Installation: https://cloud.google.com/sdk/docs/install"
    echo "🌐 Cloud Shell: https://console.cloud.google.com/"
    exit 1
fi

# Check if authenticated
echo "🔐 Checking authentication..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "."; then
    echo "❌ Not authenticated. Running authentication..."
    gcloud auth login
fi

# Apply CORS configuration
echo "📝 Applying CORS configuration..."
if gsutil cors set cors.json gs://annedfinds.firebasestorage.app; then
    echo "✅ CORS configuration applied successfully!"
    echo ""
    
    # Verify the configuration
    echo "🔍 Verifying CORS configuration..."
    gsutil cors get gs://annedfinds.firebasestorage.app
    echo ""
    
    echo "🎉 CORS configuration complete!"
    echo "⏰ Changes may take 5-10 minutes to propagate."
    echo "🧹 Clear your browser cache and test your application."
else
    echo "❌ Failed to apply CORS configuration."
    echo "💡 Try using Google Cloud Shell: https://console.cloud.google.com/"
    exit 1
fi
// Firebase setup script for AnnedFinds home screen redesign
// Run this in Firebase Console or via Firebase Functions

const samplePromotionalMessages = [
  {
    message: "Checkout mo na. Dasurb mo yan mima ko! 💖",
    isActive: true,
    priority: 1,
    backgroundColor: 0xFFFF6B35, // AppTheme.primaryOrange
    textColor: 0xFFFFFFFF, // Colors.white
  },
  {
    message: "New arrivals daily! Check mo to Mhie! 🛍️",
    isActive: true,
    priority: 2,
    backgroundColor: 0xFFE91E63, // AppTheme.secondaryPink
    textColor: 0xFFFFFFFF, // Colors.white
  },
  {
    message: "Free shipping nationwide! NCR and Luzon! 🚚",
    isActive: true,
    priority: 3,
    backgroundColor: 0xFF4CAF50, // AppTheme.successGreen
    textColor: 0xFFFFFFFF, // Colors.white
  },
  {
    message: "24/7 customer support! Nandito kami para sa'yo! 💬",
    isActive: true,
    priority: 4,
    backgroundColor: 0xFFF7931E, // AppTheme.secondaryOrange
    textColor: 0xFFFFFFFF, // Colors.white
  },
  {
    message: "Quality guaranteed! Your satisfaction is our priority! ⭐",
    isActive: true,
    priority: 5,
    backgroundColor: 0xFFFF9800, // AppTheme.warningYellow
    textColor: 0xFFFFFFFF, // Colors.white
  }
];

const sampleReviews = [
  {
    customerName: "Maria Santos",
    rating: 5,
    comment: "Amazing quality products! Fast delivery and excellent customer service. Will definitely order again!",
    productId: "sample-product-1",
    isVerified: true,
    createdAt: new Date()
  },
  {
    customerName: "Juan dela Cruz",
    rating: 5,
    comment: "Super bait ng prices at mabilis ang shipping. Recommended talaga ang AnnedFinds!",
    productId: "sample-product-2",
    isVerified: true,
    createdAt: new Date()
  },
  {
    customerName: "Ana Reyes",
    rating: 4,
    comment: "Great shopping experience! Products are exactly as described. Keep it up!",
    productId: "sample-product-3",
    isVerified: true,
    createdAt: new Date()
  },
  {
    customerName: "Carlos Martinez",
    rating: 5,
    comment: "Sobrang satisfied ako sa purchase ko. Quality products at mabait yung customer service.",
    productId: "sample-product-4",
    isVerified: true,
    createdAt: new Date()
  },
  {
    customerName: "Linda Garcia",
    rating: 5,
    comment: "First time buyer here and I'm impressed! Will recommend to my friends. Thank you AnnedFinds!",
    productId: "sample-product-5",
    isVerified: true,
    createdAt: new Date()
  }
];

console.log('Sample promotional messages to add to Firebase:');
console.log(JSON.stringify(samplePromotionalMessages, null, 2));

console.log('\nSample reviews to add to Firebase:');
console.log(JSON.stringify(sampleReviews, null, 2));

console.log('\nInstructions:');
console.log('1. Go to Firebase Console > Firestore Database');
console.log('2. Create collection "promotional_messages" and add the promotional message documents');
console.log('3. Create collection "reviews" and add the review documents');
console.log('4. Update existing products with "isPromoted: true" field for featured section');